import AVFoundation
import CoreHaptics
import GameController
import simd

/// What the player hears and feels of a fight (ADR 0008): each event plays as a sound from where
/// it happened, and what the leader does or suffers as a vibration on the phone or the
/// controller. A DualSense's R2 uses the active weapon's resistance while it can fire. Nothing
/// starts until the first frame of play asks for it, so headless tests stay silent and still.
@MainActor
final class CombatFeedback {
  /// What vibrates: nothing, the phone in the player's hands, or their controller.
  enum Device {
    case none, phone
    case controller(GCController)
  }

  /// The app's one player of sounds and vibrations.
  static let shared = CombatFeedback()

  private let audio = CombatAudio()
  private let haptics = CombatHaptics()
  /// Whether sound has been asked to start since play last began or resumed.
  private var audioStarted = false

  /// One frame: plays `events`, heard from `listener` on the ground with the screen's right
  /// along `right`, felt on `device`; `triggerWeapon` supplies R2's feel, nil while unavailable.
  /// Sound and vibration start on the first frame of play, not on the first shot, so a shot
  /// never waits for them.
  func play(
    _ events: [CombatEvent], listener: SIMD2<Float>, right: SIMD2<Float>, device: Device,
    triggerWeapon: Weapon.Kind?
  ) {
    if !audioStarted {
      audioStarted = true
      audio.prepare()
    }
    haptics.prepare(device)
    haptics.setTrigger(weapon: triggerWeapon, on: device)
    for event in events {
      if let sound = CombatSound.of(event) {
        let mix = CombatAudio.mix(at: event.position, listener: listener, right: right)
        audio.play(sound, pan: mix.pan, volume: mix.volume)
      }
      if let cue = HapticCue.of(event) { haptics.play(cue, on: device) }
    }
  }

  /// Out of the foreground: sounds stop, vibration stops, R2 goes slack.
  func suspend() {
    audioStarted = false
    audio.suspend()
    haptics.suspend()
  }
}

/// The fight's sounds (ADR 0008): WAV files that `apple/scripts/make-sounds.py` generates.
/// Recordings can replace them under the same names.
enum CombatSound: String, CaseIterable, Sendable {
  case carbine
  case lightBurst = "light-burst"
  case closeScatter = "close-scatter"
  case rifle
  case strikeBody = "strike-body"
  case strikeBlock = "strike-block"
  case emptyClick = "empty-click"

  /// What an event sounds like: each weapon a shot, a strike on a body or a block, and an
  /// empty click. Until the paired weapons get sounds of their own, each borrows the nearest
  /// existing shot (ADR 0021); a sword's swing is silent and its strikes are heard. A hit on the
  /// leader is heard as the strike on her body.
  static func of(_ event: CombatEvent) -> CombatSound? {
    switch event {
    case .fired(let kind, _, _):
      switch kind {
      case .longRifle: .carbine
      case .assaultRifle, .minigun: .lightBurst
      case .shotgun: .closeScatter
      case .rifle: .rifle
      case .energySword, .shieldDome: nil
      }
    case .struckBody: .strikeBody
    case .struckBlock: .strikeBlock
    case .empty: .emptyClick
    case .leaderHit: nil
    }
  }

  /// The file in the app's bundle.
  var url: URL? { Bundle.main.url(forResource: rawValue, withExtension: "wav") }
}

/// Plays the fight's sounds through a few voices, the oldest giving way to a new sound
/// (ADR 0008). Every voice keeps playing from the start, and a new sound interrupts what its
/// voice was playing: starting a stopped voice costs most of a frame, interrupting a playing one
/// almost nothing. All of it runs on its own queue, so neither starting the engine nor playing a
/// sound holds up a frame. The audio session is ambient: the Silent switch mutes the game, and
/// other audio keeps playing.
final class CombatAudio: @unchecked Sendable {
  /// How many sounds play at once.
  static let voiceCount = 8
  /// How far to the side a sound pans fully, and how far away it is at half volume, in metres.
  static let panDistance: Float = 12
  static let halfVolumeDistance: Float = 15
  /// The quietest a distant sound plays.
  static let quietest: Float = 0.25

  /// The only place the state below is touched, which makes this safe to share.
  private let queue = DispatchQueue(label: "lauder.combat-audio", qos: .userInitiated)
  private var engine: AVAudioEngine?
  private var voices: [AVAudioPlayerNode] = []
  private var buffers: [CombatSound: AVAudioPCMBuffer] = [:]
  private var next = 0
  private var unavailable = false
  /// After a failed start, such as during a phone call, when to try again.
  private var retryAt = ContinuousClock.now

  /// How a sound at `position` plays, heard from `listener` with the screen's right along
  /// `right`: panned by how far to the side it is, and quieter the farther away.
  static func mix(at position: SIMD2<Float>, listener: SIMD2<Float>, right: SIMD2<Float>)
    -> (pan: Float, volume: Float)
  {
    let offset = position - listener
    let pan = max(-1, min(1, simd_dot(offset, right) / panDistance))
    let volume = max(quietest, 1 / (1 + simd_length(offset) / halfVolumeDistance))
    return (pan, volume)
  }

  /// Loads the sounds and starts the engine and its voices, unless they run already.
  func prepare() {
    queue.async { _ = self.ready() }
  }

  func play(_ sound: CombatSound, pan: Float, volume: Float) {
    queue.async {
      guard self.ready(), let buffer = self.buffers[sound] else { return }
      let voice = self.voices[self.next]
      self.next = (self.next + 1) % self.voices.count
      voice.pan = pan
      voice.volume = volume
      voice.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
    }
  }

  func suspend() {
    queue.async { self.engine?.pause() }
  }

  /// The engine running, with every sound loaded and every voice playing; false when sound
  /// cannot play, such as without the files. Only on the queue.
  private func ready() -> Bool {
    guard !unavailable else { return false }
    if engine == nil { load() }
    guard let engine else { return false }
    if !engine.isRunning {
      guard ContinuousClock.now >= retryAt else { return false }
      do {
        try engine.start()
      } catch {
        retryAt = .now + .seconds(1)
        return false
      }
    }
    for voice in voices where !voice.isPlaying { try? voice.playAudio() }
    return true
  }

  /// The sounds read into memory, the session set, and the voices made and connected. Only on
  /// the queue.
  private func load() {
    var buffers: [CombatSound: AVAudioPCMBuffer] = [:]
    for sound in CombatSound.allCases {
      guard let url = sound.url, let file = try? AVAudioFile(forReading: url),
        let buffer = AVAudioPCMBuffer(
          pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
        (try? file.read(into: buffer)) != nil
      else {
        unavailable = true
        return
      }
      buffers[sound] = buffer
    }
    guard let format = buffers[.carbine]?.format else {
      unavailable = true
      return
    }
    try? AVAudioSession.sharedInstance().setCategory(.ambient)
    try? AVAudioSession.sharedInstance().setActive(true)
    let engine = AVAudioEngine()
    var voices: [AVAudioPlayerNode] = []
    for _ in 0..<Self.voiceCount {
      let voice = AVAudioPlayerNode()
      engine.attach(voice)
      guard (try? engine.connectNode(voice, to: engine.mainMixerNode, format: format)) != nil
      else {
        unavailable = true
        return
      }
      voices.append(voice)
    }
    self.buffers = buffers
    self.voices = voices
    self.engine = engine
  }
}

/// The leader's vibrations (ADR 0008): one pattern for each cause, matched to its sound.
enum HapticCue: CaseIterable, Sendable {
  /// A firm tap for each shot of Miki's long rifle.
  case carbineShot
  /// A light tick for each shot of a rapid-fire gun: the assault rifle or the minigun.
  case lightBurstShot
  /// A heavier, longer pulse for Laura's shotgun blast.
  case closeScatterShot
  /// A sharp, heavier jolt when a hostile's shot hits the leader.
  case leaderHit
  /// A light tick for Fire with no rounds.
  case emptyClick

  /// What the leader feels of an event; nothing for a companion's or hostile's weapon.
  static func of(_ event: CombatEvent) -> HapticCue? {
    switch event {
    case .fired(.longRifle, _, true): .carbineShot
    case .fired(.assaultRifle, _, true), .fired(.minigun, _, true): .lightBurstShot
    case .fired(.shotgun, _, true): .closeScatterShot
    case .leaderHit: .leaderHit
    case .empty: .emptyClick
    default: nil
    }
  }

  /// The pattern: sharp taps, with a short low rumble under the heavier ones.
  func pattern() throws -> CHHapticPattern {
    func tap(_ intensity: Float, _ sharpness: Float, at time: TimeInterval = 0) -> CHHapticEvent {
      CHHapticEvent(
        eventType: .hapticTransient,
        parameters: [
          CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
          CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
        ], relativeTime: time)
    }
    func rumble(_ intensity: Float, _ sharpness: Float, for duration: TimeInterval)
      -> CHHapticEvent
    {
      CHHapticEvent(
        eventType: .hapticContinuous,
        parameters: [
          CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
          CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
        ], relativeTime: 0, duration: duration)
    }
    let events =
      switch self {
      case .carbineShot: [tap(0.8, 0.65), rumble(0.35, 0.2, for: 0.05)]
      case .lightBurstShot: [tap(0.45, 0.8)]
      case .closeScatterShot: [tap(1, 0.5), rumble(0.65, 0.2, for: 0.09)]
      case .leaderHit: [tap(1, 0.9), tap(0.6, 0.4, at: 0.06), rumble(0.5, 0.3, for: 0.12)]
      case .emptyClick: [tap(0.35, 1)]
      }
    return try CHHapticPattern(events: events, parameters: [])
  }
}

/// Plays the leader's vibrations on the phone or on the controller, and sets a DualSense's R2
/// (ADR 0008). Each engine is made when first needed and started without waiting, again after
/// the system stops it, and each cue's player is made once for each engine.
@MainActor
final class CombatHaptics {
  /// Where R2's resistance begins and breaks, as shares of its travel, and how strong it is.
  /// These are tuning values; physical-controller feel still needs a phone session.
  struct TriggerProfile: Equatable, Sendable {
    let start: Float
    let end: Float
    let strength: Float
  }

  static func triggerProfile(for weapon: Weapon.Kind) -> TriggerProfile {
    switch weapon {
    case .longRifle: TriggerProfile(start: 0.35, end: 0.6, strength: 0.75)
    case .rifle: TriggerProfile(start: 0.3, end: 0.55, strength: 0.6)
    case .assaultRifle: TriggerProfile(start: 0.18, end: 0.38, strength: 0.3)
    case .shotgun: TriggerProfile(start: 0.4, end: 0.7, strength: 0.85)
    case .minigun: TriggerProfile(start: 0.1, end: 0.3, strength: 0.45)
    // The sword and the shield have no trigger to feel.
    case .energySword, .shieldDome: TriggerProfile(start: 0, end: 0, strength: 0)
    }
  }

  private var phone: CHHapticEngine?
  private var phoneUnavailable = false
  private var pad: (controller: GCController, engine: CHHapticEngine)?
  private var running = Set<ObjectIdentifier>()
  private var starting = Set<ObjectIdentifier>()
  private var players: [ObjectIdentifier: [HapticCue: any CHHapticPatternPlayer]] = [:]
  /// After a failed start, when to try again.
  private var retryAt = ContinuousClock.now
  /// The DualSense whose R2 is set and which weapon it matches. Kind is part of the cache so
  /// a leader switch updates resistance even when both weapons are ready to fire.
  private var trigger: (controller: GCController, weapon: Weapon.Kind?)?

  func play(_ cue: HapticCue, on device: CombatFeedback.Device) {
    guard let engine = prepare(device), let player = player(for: cue, on: engine) else { return }
    do {
      try player.start(atTime: CHHapticTimeImmediate)
    } catch {
      // The system stopped the engine; it starts again on the next frame.
      forget(ObjectIdentifier(engine))
    }
  }

  /// The engine for `device` once it runs, starting it without waiting the first time and
  /// after the system stops it; nil while it starts, or when nothing vibrates.
  @discardableResult
  func prepare(_ device: CombatFeedback.Device) -> CHHapticEngine? {
    guard let engine = engine(for: device) else { return nil }
    let key = ObjectIdentifier(engine)
    if running.contains(key) { return engine }
    guard !starting.contains(key), ContinuousClock.now >= retryAt else { return nil }
    starting.insert(key)
    engine.start { @Sendable [weak self] error in
      let started = error == nil
      Task { @MainActor in self?.finishStarting(key, started: started) }
    }
    return nil
  }

  /// R2 uses the ready weapon's trigger break on a DualSense; nil makes it slack.
  func setTrigger(weapon: Weapon.Kind?, on device: CombatFeedback.Device) {
    var wanted: (controller: GCController, weapon: Weapon.Kind?)?
    if case .controller(let controller) = device, controller.extendedGamepad is GCDualSenseGamepad {
      wanted = (controller, weapon)
    }
    if let trigger, let wanted, trigger.controller === wanted.controller,
      trigger.weapon == wanted.weapon
    {
      return
    }
    if trigger == nil, wanted == nil { return }
    if let trigger, trigger.controller !== wanted?.controller {
      Self.dualSense(trigger.controller)?.rightTrigger.setModeOff()
    }
    if let wanted, let dualSense = Self.dualSense(wanted.controller) {
      if let weapon = wanted.weapon, Self.triggerProfile(for: weapon).strength > 0 {
        let profile = Self.triggerProfile(for: weapon)
        dualSense.rightTrigger.setModeWeaponWithStartPosition(
          profile.start, endPosition: profile.end, resistiveStrength: profile.strength
        )
      } else {
        dualSense.rightTrigger.setModeOff()
      }
    }
    trigger = wanted
  }

  func suspend() {
    setTrigger(weapon: nil, on: .none)
    for engine in [phone, pad?.engine].compactMap({ $0 }) {
      engine.stop(completionHandler: nil)
      forget(ObjectIdentifier(engine))
    }
  }

  private static func dualSense(_ controller: GCController) -> GCDualSenseGamepad? {
    controller.extendedGamepad as? GCDualSenseGamepad
  }

  private func finishStarting(_ key: ObjectIdentifier, started: Bool) {
    starting.remove(key)
    if started {
      running.insert(key)
    } else {
      retryAt = .now + .seconds(1)
    }
  }

  /// The engine stopped, or gave way to another: it starts again when next needed, with fresh
  /// players. A start still under way is forgotten too; if it finishes, the next cue that fails
  /// on the stopped engine forgets it again.
  private func forget(_ key: ObjectIdentifier) {
    running.remove(key)
    starting.remove(key)
    players[key] = nil
  }

  /// The cue's player on `engine`, made the first time.
  private func player(for cue: HapticCue, on engine: CHHapticEngine) -> (any CHHapticPatternPlayer)?
  {
    let key = ObjectIdentifier(engine)
    if let player = players[key]?[cue] { return player }
    guard let pattern = try? cue.pattern(), let player = try? engine.makePlayer(with: pattern)
    else { return nil }
    players[key, default: [:]][cue] = player
    return player
  }

  /// The engine for `device`, made the first time: the phone's own, or the controller's.
  private func engine(for device: CombatFeedback.Device) -> CHHapticEngine? {
    switch device {
    case .none:
      return nil
    case .phone:
      if let phone { return phone }
      guard !phoneUnavailable, CHHapticEngine.capabilitiesForHardware().supportsHaptics,
        let engine = try? CHHapticEngine()
      else {
        phoneUnavailable = true
        return nil
      }
      engine.playsHapticsOnly = true
      watch(engine)
      phone = engine
      return engine
    case .controller(let controller):
      if let pad, pad.controller === controller { return pad.engine }
      if let old = pad {
        old.engine.stop(completionHandler: nil)
        forget(ObjectIdentifier(old.engine))
      }
      pad = nil
      guard let engine = controller.haptics?.createEngine(withLocality: .default) else {
        return nil
      }
      watch(engine)
      pad = (controller, engine)
      return engine
    }
  }

  /// When the system stops or resets an engine, it starts again when next needed.
  private func watch(_ engine: CHHapticEngine) {
    let key = ObjectIdentifier(engine)
    let forget: @Sendable () -> Void = { [weak self] in
      Task { @MainActor in self?.forget(key) }
    }
    engine.stoppedHandler = { @Sendable _ in forget() }
    engine.resetHandler = { @Sendable in forget() }
  }
}
