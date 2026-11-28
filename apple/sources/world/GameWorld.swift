import Foundation
import Observation
import RealityKit
import simd

#if DEBUG
  import UIKit
#endif

@MainActor
@Observable
final class GameWorld {
  /// Party movement advances in whole steps of this length inside the scene update.
  static let simulationStep: Float = 1 / 120
  /// How many events a world keeps for the frame to play (ADR 0008): headless runs play none.
  static let keptEvents = 64

  let level: Level
  let root = Entity()
  let controls = GameControls()
  let session: GameSession
  /// The latest line the HUD shows: a place's words, an action's result, a beat's line. Every
  /// line counts as new, even one that repeats the last, so it shows again in the status panel.
  private(set) var observation: String {
    get { shownLine }
    set {
      shownLine = newValue
      lineCount &+= 1
    }
  }
  private var shownLine: String
  @ObservationIgnored private var lineCount = 0
  private(set) var diagnostic: String?
  /// A hostile winding up a shot, such as "The stranger is aiming."
  private(set) var threat: String?
  private(set) var guardTarget: PartyMember?
  private(set) var guardHint: String?
  private(set) var guardHealth: Int?
  private(set) var damageFeedback = DamageFeedback()
  #if DEBUG
    @ObservationIgnored private var damageTally = PlaytestRunner.DamageTally()
    @ObservationIgnored private var shieldStops = 0
  #endif
  private(set) var companionStatus = ""
  /// Whether the leader's weapon is drawn.
  private(set) var weaponDrawn = false
  /// The hostile the aim is locked on, by id, or nil (ADR 0020).
  private(set) var lockedHostile: String?
  /// How dark the screen is while an encounter starts again, from 0 to 1.
  private(set) var fade: Float = 0
  /// The compass to the level's current goal; nil when there is none.
  private(set) var compass: Compass?
  /// Whether the player has hidden the status panel with the pause menu's Status panel choice.
  /// It stays hidden or shown across Restart.
  private(set) var panelHidden = false
  /// Whether the phone or the controller vibrates in play (ADR 0008): the pause menu's choice,
  /// on until the player turns it off.
  private(set) var vibrationEnabled = true
  /// Every input source can hide the panel and show it again from Pause.
  var showsPanel: Bool { !panelHidden }
  /// Whether the latest line and the objective are new enough to show in the status panel.
  private(set) var lineIsFresh = true
  private(set) var objectiveIsFresh = true

  /// What the HUD's compass shows: the goal's name, how far away it is, and which way, as an
  /// angle clockwise from straight up the screen.
  struct Compass: Equatable {
    let name: String
    let metres: Int
    /// Radians, to the nearest degree.
    let angle: Float
  }

  @ObservationIgnored private var bodies: [PartyMember: Entity] = [:]
  @ObservationIgnored private var visuals: [PartyMember: Entity] = [:]
  @ObservationIgnored private var markers: [PartyMember: Entity] = [:]
  /// Rings where going companions are heading, in their colours (ADR 0003, phase S3).
  @ObservationIgnored private var orderMarkers: [PartyMember: Entity] = [:]
  /// The brief cross where an order's point could not be reached.
  @ObservationIgnored private var refusalCross = Entity()
  @ObservationIgnored private var crossRemaining: Float = 0
  /// Orders refused in this run because nobody could reach their point. Tests read it.
  @ObservationIgnored private(set) var refusedOrders = 0
  /// Whether the leader has been told, on this visit to a gathering area, who is missing.
  @ObservationIgnored private var toldWhoIsMissing = false
  /// What the touch order menu marked as it opened: its point on the screen, and what the ray
  /// through it met then. The order that follows uses it, though the camera has moved since.
  @ObservationIgnored private var touchMark: (screen: InputRules.ScreenPoint, hit: SIMD3<Float>?)?
  @ObservationIgnored private let camera: WorldCamera
  /// Movement against the bridge's blockers.
  @ObservationIgnored private let motion: PartyMotion
  @ObservationIgnored private let grid: NavigationGrid
  @ObservationIgnored private var route: RouteMemory
  @ObservationIgnored private var planner: SquadPlanner
  @ObservationIgnored private var motors: [PartyMember: CompanionMotor]
  @ObservationIgnored private var tactics: [PartyMember: CompanionTactics] = [:]
  @ObservationIgnored private var companionIntents: [PartyMember: CompanionTactics.Intent] = [:]
  /// Where companions are stepping aside to from a crawler's ram line, kept between steps so a
  /// companion holds its choice (issue #208).
  @ObservationIgnored private var crawlerAsides: [PartyMember: SIMD2<Float>] = [:]
  @ObservationIgnored private var formationTargets: [PartyMember: SIMD2<Float>] = [:]
  @ObservationIgnored private var regroupRemaining: Float = 0
  @ObservationIgnored private var regrouping = false
  @ObservationIgnored private var retreatRemaining: Float = 0
  @ObservationIgnored private var squadLeader: PartyMember
  @ObservationIgnored private var yaw: [PartyMember: Float] = [:]
  /// Where each companion is heading in the latest step. Tests read it.
  @ObservationIgnored private(set) var companionTargets: [PartyMember: SIMD2<Float>] = [:]
  #if DEBUG
    /// A scripted Simulator playtest (`apple/scripts/playtest`), started by the launch argument
    /// `-LauderPlaytest <scenario>`. Debug builds only.
    @ObservationIgnored private(set) var playtest: PlaytestRunner?
    @ObservationIgnored private var targetMarkers: [PartyMember: Entity] = [:]
  #endif
  @ObservationIgnored private var subscription: EventSubscription?
  @ObservationIgnored private var isPresented = false
  @ObservationIgnored private var isApplicationActive = false
  @ObservationIgnored private var skipNextStep = true
  @ObservationIgnored private var wasRunning = false
  /// The line and objective the status panel last saw change, and for how long they have shown.
  @ObservationIgnored private var agedLineCount = 0
  @ObservationIgnored private var agedObjective = ""
  @ObservationIgnored private var lineAge: Float = 0
  @ObservationIgnored private var objectiveAge: Float = 0
  @ObservationIgnored private var unsimulatedTime: Float = 0
  /// The level's fight rules and presentation, kept separate (ADR 0004, ADR 0008).
  @ObservationIgnored private let fight: EncounterSimulation
  @ObservationIgnored private let stage: EncounterStage
  private(set) var grenadeStatus = "Grenade"
  @ObservationIgnored private var fireHeld = false
  /// Where the right stick aims, in the stick's terms, and where that is on the ground while the
  /// leader is armed to aim (ADR 0007).
  @ObservationIgnored private var aimStick: SIMD2<Float>?
  @ObservationIgnored private var aimDirection: SIMD2<Float>?
  /// Where the fight last asked the leader to turn, such as towards the assisted target while
  /// Fire is held, until she faces it (ADR 0008).
  @ObservationIgnored private var facingGoal: SIMD2<Float>?
  /// Members still rocking from a shot or a hit in the latest step (ADR 0008).
  @ObservationIgnored private var joltedMembers: Set<PartyMember> = []
  /// How each pawn shows its walk, from the movement resolved in each step (the visual
  /// direction's pawns have no rig).
  @ObservationIgnored private var gaits: [PartyMember: PawnGait] = [:]
  /// The leader's dodge roll while it lasts, and the wait before the next. Tests read the roll.
  @ObservationIgnored private(set) var roll: DodgeRoll?
  @ObservationIgnored private var rollCooldown: Float = 0
  @ObservationIgnored private var dodgePressPending = false
  @ObservationIgnored private var grenadePressPending: PartyMember?
  /// A lock press waiting for the next fixed step (ADR 0020).
  @ObservationIgnored private var lockPressPending = false
  /// Tom's dome, shown round him while he leads with it raised (ADR 0021).
  @ObservationIgnored private let shieldDome: ModelEntity
  /// What players hear and feel, waiting for the frame to play it (ADR 0008). Headless runs,
  /// which play nothing, keep only the latest.
  @ObservationIgnored private var combatEvents: [CombatEvent] = []
  /// Source cancellation invalidates an undrained leg cue even if neutral input clears before
  /// the next frame. Ordinary completed shots and impacts remain event history.
  @ObservationIgnored private var legBreakGeneration = 0
  @ObservationIgnored private var firePressPending = false
  /// Where the current encounter's retry places the leader.
  @ObservationIgnored private var retrySpot: SIMD2<Float>?
  /// Time into an encounter's retry: the fade out, the reset, the fade back in.
  @ObservationIgnored private var retryElapsed: Float?
  static let retryFadeOut: Float = 0.6
  static let retryFadeIn: Float = 0.4
  /// How far ahead of the leader the D-pad marks its point, before a wall shortens it (ADR 0003).
  static let orderReach: Float = 6
  /// How far a marked point may move to reach somewhere a companion can stand.
  static let orderSnap: Float = 1
  /// How far apart two companions sent together stand.
  static let spotSpacing: Float = 1
  /// How close a going companion comes to their point before they hold there.
  static let arrivalDistance: Float = 0.35
  /// How long the cross shows where an order could not go.
  static let crossTime: Float = 1
  /// How close every companion must be before a scene that gathers the party begins.
  static let gatherRadius: Float = 5
  /// How long a new line or objective shows in the status panel, in seconds of play.
  static let lineTime: Float = 6
  var isPaused: Bool { session.isPaused }
  /// Every member of the playable party carries a weapon (ADR 0010).
  var showsWeapon: Bool { session.party.contains(session.leader) }

  /// The weapon in the leader's hand and how it stands: its magazine or reload, how long Tom's
  /// dome lasts, or just the sword. Rounds are not counted beyond the magazine (ADR 0021).
  private(set) var weaponStatus = ""
  /// The leader's other weapon, which the switch brings into hand.
  private(set) var otherWeaponName = ""

  private func updateWeaponStatus() {
    grenadeStatus =
      fight.grenadeCooldown > 0
      ? "Grenade \(Int(ceil(fight.grenadeCooldown)))s" : "Grenade"
    let state = fight.status(for: session.leader)
    let name = state.kind.name
    let practice = session.inEncounter ? "" : " · Practice"
    let text: String
    switch state.kind {
    case .energySword:
      text = name + practice
    case .shieldDome:
      let remaining = state.shieldRemaining ?? 0
      if fight.shieldIsUp {
        text = String(format: "%@ · Up %.1f s", name, ceil(remaining * 10) / 10)
      } else if remaining < ShieldDome.duration {
        text = String(format: "%@ · Recharging %.0f%%", name, remaining / ShieldDome.duration * 100)
      } else {
        text = "\(name) · Ready"
      }
    default:
      if state.reloadRemaining > 0 {
        text =
          String(format: "%@ · Reloading %.1f s", name, ceil(state.reloadRemaining * 10) / 10)
          + practice
      } else {
        text = "\(name) · \(state.loaded) loaded" + practice
      }
    }
    if weaponStatus != text { weaponStatus = text }
    let other = fight.otherWeapon(of: session.leader).kind.name
    if otherWeaponName != other { otherWeaponName = other }
  }

  var weaponKind: Weapon.Kind? { canFire ? fight.weapon(of: session.leader).kind : nil }
  /// Whether weapon readiness and shared rounds show: during a fight, or while drawn.
  var showsAmmo: Bool { session.inEncounter || weaponDrawn }
  /// Whether an encounter's retry is under way.
  var isRetrying: Bool { retryElapsed != nil }
  /// How many shots' marks show on blocks now (ADR 0007). Tests and playtests read it.
  var shotMarks: Int { stage.effects.marksShown }
  /// The camera's lens now, in degrees (ADR 0007). Tests read it.
  var cameraLens: Float { camera.lens }
  /// The direction on the ground a member faces. Tests read it.
  func facing(of member: PartyMember) -> SIMD2<Float> { Movement.facing(yaw: yaw[member] ?? 0) }
  /// The HUD's objective changes with the story's current beat.
  var objective: String {
    level.objectiveChanges.last { $0.beat <= session.beat }?.text ?? level.objective
  }

  init(level: Level = BrooklynBridge.level) {
    self.level = level
    session = GameSession(level: level)
    shownLine = level.opening
    motion = PartyMotion(radius: PartyBody.radius, obstacles: level.obstacles)
    grid = NavigationGrid(level: level)
    squadLeader = level.party[0]
    route = RouteMemory(start: level.spawn(level.party[0]))
    planner = SquadPlanner(heading: level.heading)
    motors = Self.freshMotors()
    let spawn = level.spawn(level.party[0])
    camera = WorldCamera(level: level, over: spawn)
    let style = SceneStyle(
      markerScale: SceneStyle.markerScale(
        cameraOffset: level.cameraOffset, fieldOfView: level.fieldOfView))
    fight = EncounterSimulation(level: level)
    stage = EncounterStage(level: level, style: style)
    stage.reset(fight)
    shieldDome = style.shieldDome()
    root.name = level.id
    if let scene = level.scene {
      root.addChild(Self.loadScene(named: scene, for: level))
    } else {
      // Plain test geometry; the playable bridge loads its authored scene.
      for box in [level.ground] + level.boxes {
        let material: any Material =
          box.name == level.ground.name ? style.snow : style.scenery
        let entity = style.block(size: box.size, at: box.position, material: material)
        entity.name = box.name
        root.addChild(entity)
      }
    }
    camera.attach(to: root)
    root.addChild(stage.container)
    style.addLights(level.lights, to: root)
    for member in PartyMember.allCases {
      let body = Entity()
      body.name = "party.\(member.rawValue)"
      let visual = style.partyMember(member)
      body.addChild(visual)
      let marker = style.leaderMarker()
      marker.name = "\(member.rawValue).marker"
      body.addChild(marker)
      bodies[member] = body
      visuals[member] = visual
      markers[member] = marker
      root.addChild(body)
      let ring = style.orderMarker(for: member)
      ring.name = "order.\(member.rawValue)"
      ring.isEnabled = false
      orderMarkers[member] = ring
      root.addChild(ring)
    }
    refusalCross = style.refusalCross()
    refusalCross.name = "order.refused"
    refusalCross.isEnabled = false
    root.addChild(refusalCross)
    for (member, weapons) in stage.weaponProps {
      for weapon in weapons.values { visuals[member]?.addChild(weapon) }
    }
    // Tom's dome stands round him, centred on the ground under his body.
    shieldDome.position.y = -PartyBody.height / 2
    shieldDome.isEnabled = false
    bodies[.tom]?.addChild(shieldDome)
    placeParty()
    updateCamera(deltaTime: 0)
    updateCompass()
    updateWeaponStatus()
  }

  /// Everything the player sees of the level, from its scene file in the app's bundle (ADR
  /// 0002). Restart retains the loaded scene.
  private static func loadScene(named name: String, for level: Level) -> Entity {
    do {
      let scene = try SceneStyle.scene(named: name)
      scene.name = "\(level.id).scene"
      return scene
    } catch {
      preconditionFailure("\(level.id)'s scene file, \(name).usdz, did not load: \(error)")
    }
  }

  func attach(_ subscription: EventSubscription) {
    self.subscription?.cancel()
    self.subscription = subscription
    isPresented = true
    updateActivity()
  }

  func setApplicationActive(_ active: Bool) {
    guard active != isApplicationActive else { return }
    isApplicationActive = active
    updateActivity()
  }

  func stop() {
    isPresented = false
    subscription?.cancel()
    subscription = nil
    updateActivity()
  }

  /// The pause menu's Vibration choice (ADR 0008).
  func toggleVibration() {
    vibrationEnabled.toggle()
  }

  /// Lets go of the lock on a hostile, so the stick aims again (ADR 0020).
  func releaseLock() {
    fight.releaseLock()
    lockedHostile = nil
  }

  /// What players have heard and felt since the last call, which empties the list (ADR 0008).
  /// The frame plays them; tests read them.
  func takeCombatEvents() -> [CombatEvent] {
    defer { combatEvents.removeAll(keepingCapacity: true) }
    return combatEvents.filter { event in
      switch event {
      case .guardTargeted(let member, _):
        // Several fixed steps may precede one presented frame. Do not announce a target
        // whose attack ended, was bypassed, or was interrupted before feedback drained.
        return guardTarget == member && session.mode == .exploring
          && !controls.needsNeutralInput && !isRetrying
      case .guardLegBroken:
        return legBreakGeneration == controls.touchGeneration && session.mode == .exploring
          && !controls.needsNeutralInput && !isRetrying
      case .droneWarning, .crawlerWarning:
        // A pack member's warning, like the guard's, is not heard once its moment has passed.
        return session.mode == .exploring && !controls.needsNeutralInput && !isRetrying
      default:
        return true
      }
    }
  }

  /// The frame's feedback context. Only the interface plays the events; headless simulation
  /// keeps no sound, vibration or controller-trigger dependency.
  var listenerPoint: SIMD2<Float> { SIMD2(camera.target.x, camera.target.z) }
  var screenRight: SIMD2<Float> { Movement.axes(cameraOffset: level.cameraOffset).right }
  var canFire: Bool {
    session.mode == .exploring && showsWeapon && !fight.holdsParty
      && fight.status(for: session.leader).reloadRemaining <= 0
  }
  var isActive: Bool { isPresented && isApplicationActive }

  /// The scene's update: this frame's input, sampled in the session's mode, then `update`. Each
  /// active step starts from the body positions that the one before checked against collisions.
  func step(deltaTime: TimeInterval) {
    MainActor.preconditionIsolated()
    guard isPresented, isApplicationActive else { return }
    #if DEBUG
      if playtest != nil {
        playtest?.tick(dt: Float(deltaTime))
        controls.scriptedRaw = playtest?.input(playtestSnapshot)
      }
    #endif
    let mode = session.mode
    let input = controls.sample(mode: mode)
    update(
      with: input, sampledIn: mode, deltaTime: Float(deltaTime),
      inputReady: controls.status == .ready)
  }

  /// One frame after sampling: the command the input means in the mode it was sampled in, then
  /// party movement while exploring, then the leader's action. Headless tests call it directly.
  func update(
    with input: InputRules.Input, sampledIn mode: GameSession.Mode, deltaTime: Float,
    inputReady: Bool = true
  ) {
    respond(to: input, in: mode)
    if retryElapsed != nil {
      // An encounter is starting again; Pause holds the fade where it is.
      if session.mode == .exploring { advanceRetry(deltaTime: deltaTime) }
      return
    }
    let running = session.mode == .exploring && inputReady && !controls.needsNeutralInput
    if running != wasRunning {
      wasRunning = running
      skipNextStep = true
    }
    guard running else { return }
    guard !skipNextStep else {
      // Time owed from before an interruption is not replayed afterwards, and nor is a Fire or
      // dodge press that no step took up before it.
      skipNextStep = false
      unsimulatedTime = 0
      firePressPending = false
      dodgePressPending = false
      grenadePressPending = nil
      lockPressPending = false
      return
    }
    if mode == .exploring, let command = input.targetCommand {
      target(command)
    }
    #if DEBUG
      let started = DispatchTime.now().uptimeNanoseconds
    #endif
    let grenadeTakesHands = advanceParty(
      movement: input.movement, aim: input.aim, fireHeld: input.fireHeld,
      firePressed: input.firePressed, dodgePressed: input.dodgePressed,
      grenadePressed: input.grenadePressed, lockPressed: input.lockPressed, deltaTime: deltaTime)
    #if DEBUG
      recordPlaytest(
        dt: deltaTime,
        milliseconds: Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000)
    #endif
    if mode == .exploring, input.actionPressed, !grenadeTakesHands { performAction() }
  }

  /// Dialogue and Pause controls stay distinct from world actions: in those modes the action
  /// press shows the next line or confirms the pause menu's choice, and nothing else.
  private func respond(to input: InputRules.Input, in mode: GameSession.Mode) {
    switch mode {
    case .paused:
      if input.pausePressed {
        togglePause()
      } else if input.restartPressed {
        restart()
      } else if input.vibrationPressed {
        toggleVibration()
      } else if input.panelPressed, session.mode == .paused {
        panelHidden.toggle()
      } else if input.actionPressed {
        switch session.pauseChoice {
        case .resume: togglePause()
        case .restart: restart()
        case .vibration: toggleVibration()
        case .statusPanel: panelHidden.toggle()
        }
      } else if input.menuMove != 0 {
        session.movePauseChoice(by: input.menuMove)
      }
    case .dialogue:
      if input.pausePressed {
        togglePause()
      } else if input.actionPressed {
        session.advanceDialogue()
        // What a finished conversation settles has just taken effect.
        if session.mode != .dialogue { updateCompass() }
      }
    case .exploring:
      if input.pausePressed {
        togglePause()
      } else if input.switchPressed, session.nextLeader != nil {
        session.cycleLeader()
        followNewLeader()
      }
      // The leader's other weapon comes into hand (ADR 0021).
      if input.swapPressed {
        fight.swapWeapon(for: session.leader)
        updateWeaponStatus()
      }
      // The squad's planner takes the new formation in the next step (ADR 0003, phase S2). After
      // an order the button calls everyone back instead.
      if input.formationPressed {
        if !companionIntents.isEmpty {
          regrouping = true
          regroupRemaining = 2
          companionIntents = [:]
          crawlerAsides = [:]
          tactics = [:]
        }
        session.pressFormation()
        showOrders()
      }
      if let mark = input.markPoint { touchMark = (mark, firstHit(at: mark)) }
      if let command = input.command { give(command, at: input.commandPoint) }
    }
  }

  private func togglePause() {
    session.togglePause()
    if session.mode == .paused {
      combatEvents.removeAll { if case .guardLegBroken = $0 { true } else { false } }
    }
    controls.requireNeutralInput()
  }

  /// Target taps are consumed in this allowed frame, never queued behind a pause or source
  /// transition. The encounter retains native candidate, lock and firing authority.
  private func target(_ command: InputRules.TargetCommand) {
    guard session.mode == .exploring, let leader = position(of: session.leader) else { return }
    let axes = Movement.axes(cameraOffset: level.cameraOffset)
    switch command {
    case .tap(let tap):
      fight.tapLock(
        at: [tap.point.x, tap.point.y], viewHeight: tap.viewHeight,
        projection: projection(aspect: tap.point.aspect), from: leader)
    case .acquire, .next:
      fight.selectLock(
        from: leader, facing: Movement.facing(yaw: yaw[session.leader] ?? 0),
        up: axes.forward, right: axes.right, advancing: command == .next)
    case .release:
      fight.releaseLock()
    }
    if lockedHostile != fight.lock { lockedHostile = fight.lock }
  }

  /// After a switch: the camera eases to the new leader, and a previous leader who joins a
  /// holding squad holds where they stand.
  private func followNewLeader() {
    grenadePressPending = nil
    pinHolds()
    camera.switchLeader()
    showLeaderMarker()
    updateCompass()
  }

  /// The leader's action press while exploring: the bridge has nothing to search or help with
  /// any more, so the leader looks around.
  func performAction() {
    guard session.mode == .exploring, !fight.holdsParty else { return }
    observation = level.lookAround
  }

  /// The in-place Restart: the same scene, bodies and update subscription, returned to the
  /// beginning of a run. Nothing is rebuilt or reloaded.
  func restart() {
    session.restart()
    retryElapsed = nil
    retrySpot = nil
    fade = 0
    placeParty()
    diagnostic = nil
    refusedOrders = 0
    touchMark = nil
    crossRemaining = 0
    refusalCross.isEnabled = false
    toldWhoIsMissing = false
    showOrders()
    skipNextStep = true
    observation = level.opening
    lineAge = 0
    objectiveAge = 0
    lineIsFresh = true
    objectiveIsFresh = true
    resetPlay(around: level.spawn(session.leader))
    // Like Resume, the new run waits for every button, key and finger to be released.
    controls.requireNeutralInput()
  }

  /// What Restart and an encounter's retry both put back, once the leader stands at `spot`:
  /// the fights as they began, with the weapon holstered, the squad's movement around the
  /// leader, and the camera settled behind them.
  private func resetPlay(around spot: SIMD2<Float>) {
    clearDamageFeedback()
    fight.reset()
    stage.reset(fight)
    gaits = [:]
    roll = nil
    rollCooldown = 0
    dodgePressPending = false
    grenadePressPending = nil
    lockPressPending = false
    lockedHostile = nil
    for member in PartyMember.allCases { showPose(member) }
    joltedMembers = []
    updateWeaponStatus()
    resetSquad(around: spot)
  }

  /// Reset squad movement and the camera around `spot`, with the weapon holstered.
  private func resetSquad(around spot: SIMD2<Float>) {
    threat = nil
    guardTarget = nil
    guardHint = nil
    guardHealth = nil
    companionStatus = ""
    companionIntents = [:]
    crawlerAsides = [:]
    formationTargets = [:]
    tactics = [:]
    regrouping = false
    regroupRemaining = 0
    retreatRemaining = 0
    weaponDrawn = false
    fireHeld = false
    aimStick = nil
    aimDirection = nil
    facingGoal = nil
    firePressPending = false
    squadLeader = session.leader
    route = RouteMemory(start: spot)
    planner = SquadPlanner(heading: level.heading)
    motors = Self.freshMotors()
    companionTargets = [:]
    unsimulatedTime = 0
    camera.reset(over: spot)
    updateCamera(deltaTime: 0)
    updateCompass()
  }

  /// Every body at its spawn point, facing the level's starting direction. Members who have
  /// not joined yet stay out of the squad and hidden.
  private func placeParty() {
    let facing = Movement.yaw(towards: level.heading)
    for member in PartyMember.allCases {
      place(member, at: level.spawn(member))
      setYaw(member, facing)
      bodies[member]?.isEnabled = session.party.contains(member)
    }
    showLeaderMarker()
  }

  /// The party's movement, the fight, the camera and the HUD's lines for one frame of play, as in
  /// production; deterministic route and soak tests drive it too. Input availability, Pause and
  /// fresh-edge handling remain in `step` and InputRules.
  /// Returns whether an eligible queued grenade takes the leader's hands for this frame.
  @discardableResult
  func advanceParty(
    movement: SIMD2<Float>, aim: SIMD2<Float>? = nil, fireHeld: Bool = false,
    firePressed: Bool = false, dodgePressed: Bool = false, grenadePressed: Bool = false,
    lockPressed: Bool = false, deltaTime: Float
  ) -> Bool {
    guard session.mode == .exploring, deltaTime.isFinite, deltaTime > 0 else { return false }
    if grenadePressPending != session.leader { grenadePressPending = nil }
    let canThrow =
      roll == nil && !dodgePressed && !dodgePressPending
      && fight.canThrowGrenade(by: session.leader)
    if grenadePressed, canThrow { grenadePressPending = session.leader }
    // An eligible request can wait less than one fixed step. Keep its hands priority until
    // that step, without banking refused requests through recharge, a roll or a scene.
    let grenadeTakesHands = grenadePressPending == session.leader && canThrow
    self.fireHeld = fireHeld && !grenadeTakesHands
    aimStick = aim
    if grenadeTakesHands {
      firePressPending = false
    } else if firePressed {
      firePressPending = true
    }
    if dodgePressed { dodgePressPending = true }
    if lockPressed { lockPressPending = true }
    let elapsed = min(deltaTime, 1 / 30)
    // Equal steps keep party movement independent of the display's frame times (#28). The
    // remainder, always under one step, carries to the next frame. A retry, or a conversation a
    // cue has just begun, stops the rest.
    unsimulatedTime += elapsed
    while unsimulatedTime >= Self.simulationStep, retryElapsed == nil, session.mode == .exploring {
      unsimulatedTime -= Self.simulationStep
      simulateStep(movement: movement, dt: Self.simulationStep)
    }
    updateCamera(deltaTime: elapsed)
    ageLines(by: elapsed)
    updateCompass()
    checkTriggers()
    if crossRemaining > 0 {
      crossRemaining -= elapsed
      if crossRemaining <= 0 { refusalCross.isEnabled = false }
    }
    return grenadeTakesHands
  }

  private func simulateStep(movement: SIMD2<Float>, dt: Float) {
    if squadLeader != session.leader { changeLeader() }
    pinHolds()
    let before = positions
    defer { showWalks(from: before, dt: dt) }
    let leader = session.leader
    guard let leaderStart = position(of: leader) else { return }
    let grid = self.grid
    // A scripted scene holds the party where they stand, whoever leads; only its cues place and
    // turn anyone, and switching leader during it moves no one.
    let held = fight.holdsParty
    let movement = held ? .zero : movement
    let direction = Movement.direction(for: movement, cameraOffset: level.cameraOffset)
    let walking = SIMD2(direction.x, direction.z)
    // A roll belongs to the leader who began it and stops when a scene holds the party; either
    // way the next waits for its cooldown (ADR 0019).
    rollCooldown = max(0, rollCooldown - dt)
    if let rolling = roll, held || rolling.member != leader {
      roll = nil
      rollCooldown = DodgeRoll.cooldown
    }
    if dodgePressPending {
      dodgePressPending = false
      startRoll(leader, moving: walking, held: held)
    }
    let leaderDelta: SIMD2<Float>
    if var rolling = roll {
      leaderDelta = rolling.advance(dt: dt)
      roll = rolling
    } else {
      // A running minigun or a raised dome slows the leader (ADR 0021).
      leaderDelta = walking * PartyBody.speed * fight.leaderWalking * dt
    }
    let isRolling = roll != nil
    let leaderEnd = resolvePartyMotion(start: leaderStart, delta: leaderDelta)
    place(leader, at: leaderEnd)
    if lockPressPending {
      lockPressPending = false
      let screen = Movement.axes(cameraOffset: level.cameraOffset)
      fight.pressLock(
        from: leaderEnd, facing: Movement.facing(yaw: yaw[leader] ?? 0), up: screen.forward,
        right: screen.right)
      lockedHostile = fight.lock
    }
    // Each leader aims their own weapon, whichever way they move. A scripted scene still
    // holds fire, and so does a roll; facing and turn-rate rules are shared by all three
    // (ADR 0010). A lock aims for the player, at the locked hostile, and the stick waits until
    // it lets go (ADR 0020).
    let armed = !held && !isRolling
    if !armed {
      aimDirection = nil
    } else if let locked = fight.lockPoint {
      let offset = locked - leaderEnd
      aimDirection = simd_length_squared(offset) > 0.000001 ? simd_normalize(offset) : nil
    } else {
      aimDirection = aimStick.map { Movement.aim(for: $0, cameraOffset: level.cameraOffset) }
    }
    let moving = simd_length_squared(leaderDelta) > 0.000001 ? leaderDelta : nil
    if !isRolling, let wanted = aimDirection ?? facingGoal ?? moving {
      turnLeader(leader, towards: wanted, dt: dt)
    }
    let leaderVelocity = (leaderEnd - leaderStart) / dt
    route.record(leaderEnd)
    planCompanions(leader: leaderEnd, velocity: leaderVelocity, dt: dt)
    stepStage(
      leader: leader, at: leaderEnd, armed: armed, untouchable: isRolling ? [leader] : [], dt: dt)
    if roll?.isFinished == true {
      roll = nil
      rollCooldown = DodgeRoll.cooldown
    }
    if retryElapsed != nil { return }
    // The hold lasts through the step whose cue ends the scene and begins its exchange.
    if held || session.mode != .exploring {
      companionTargets = [:]
      return
    }

    // Companions choose their own routes to formation slots (ADR 0003); every movement is
    // still resolved against the authored footprints. A companion with an order keeps to its
    // point, and the others share the formation's places (phase S3).
    let current = positions
    let isClear: (SIMD2<Float>, SIMD2<Float>) -> Bool = { from, to in
      self.canTraverseParty(from: from, to: to)
    }
    let session = self.session
    let following = current.filter { member, _ in
      member == leader || session.order(of: member) == .following
    }
    var targets = planner.targets(
      for: SquadPlanner.Input(
        leader: leader, leaderPosition: leaderEnd, leaderVelocity: leaderVelocity,
        positions: following, route: route, formation: session.formation, dt: dt),
      grid: grid, isClear: isClear)
    for member in session.party where member != leader {
      if let point = Self.point(of: session.order(of: member)) { targets[member] = point }
    }
    formationTargets = targets
    var fixedTargets: Set<PartyMember> = []
    for member in session.companions {
      if session.order(of: member) == .following,
        let target = companionIntents[member]?.position
      {
        targets[member] = target
        fixedTargets.insert(member)
      }
      if let start = current[member], let target = targets[member],
        let detour = guardWaypoint(from: start, towards: target)
      {
        targets[member] = detour
        fixedTargets.insert(member)
      }
    }
    companionTargets = targets
    for member in session.party where member != leader {
      guard let start = current[member], let target = targets[member],
        var motor = motors[member]
      else { continue }
      let order = session.order(of: member)
      let context = CompanionMotor.Context(
        target: target, leaderPosition: leaderEnd, leaderVelocity: leaderVelocity,
        others: current.compactMap { $0.key == member ? nil : $0.value },
        speed: PartyBody.speed, dt: dt,
        targetMoves: order == .following && !fixedTargets.contains(member))
      if crawlerAsides[member] != nil { motor.hurry() }
      let delta = motor.step(from: start, context: context, grid: grid, isClear: isClear)
      let end = resolvePartyMotion(start: start, delta: delta)
      motor.absorb(end - start, dt: dt)
      motors[member] = motor
      place(member, at: end)
      if let look = companionIntents[member]?.lookAt, simd_distance(look, end) > 0.001 {
        let current = yaw[member] ?? 0
        setYaw(
          member,
          Movement.turn(
            from: current, towards: Movement.yaw(towards: look - end),
            limit: Movement.companionTurnRate * dt))
      } else {
        turn(member, moved: end - start, dt: dt)
      }
      // A going companion holds once they reach their ordered point.
      if case .going(let point) = order,
        simd_distance(end, point) <= Self.arrivalDistance
      {
        session.arrived(member)
      }
    }
    showOrders()
    let stuck = session.party.first { $0 != leader && motors[$0]?.cannotReach == true }
    let message = stuck.map {
      session.order(of: $0) == .following
        ? "\($0.displayName) can't reach you" : "\($0.displayName) can't get there"
    }
    if diagnostic != message { diagnostic = message }
  }

  /// The bridge owns static cover; a living strategic guard adds its solid hull. Recheck the
  /// slid segment against scenery so avoiding the machine never pushes a pawn through a pier.
  private func resolvePartyMotion(start: SIMD2<Float>, delta: SIMD2<Float>) -> SIMD2<Float> {
    var end = motion.resolve(start: start, delta: delta)
    for state in fight.hostiles.values where state.blocksParty {
      end = GuardCollision.resolve(
        start: start, delta: end - start, centre: state.position,
        radius: GuardCollision.pawnClearance)
    }
    return motion.canTraverse(from: start, to: end) ? end : start
  }

  private func canStandParty(_ point: SIMD2<Float>) -> Bool {
    grid.isWalkable(point)
      && fight.hostiles.values.allSatisfy { state in
        !state.blocksParty
          || simd_distance(point, state.position)
            >= GuardCollision.pawnClearance + PartyMotion.skin
      }
  }

  private func canTraverseParty(from start: SIMD2<Float>, to end: SIMD2<Float>) -> Bool {
    guard motion.canTraverse(from: start, to: end) else { return false }
    return clearsGuard(from: start, to: end)
  }

  private func clearsGuard(from start: SIMD2<Float>, to end: SIMD2<Float>) -> Bool {
    return fight.hostiles.values.allSatisfy { state in
      guard state.blocksParty else { return true }
      let resolved = GuardCollision.resolve(
        start: start, delta: end - start, centre: state.position,
        radius: GuardCollision.pawnClearance)
      return simd_distance(resolved, end) < 0.001
    }
  }

  /// Admit connected cover destinations without building paths in the policy's hot loop.
  /// The motor owns route construction and checks physical clearance while walking it.
  private func canReachParty(from start: SIMD2<Float>, to end: SIMD2<Float>) -> Bool {
    if canTraverseParty(from: start, to: end) { return true }
    guard let startRegion = region(near: start), grid.region(at: end) == startRegion,
      canStandParty(end)
    else { return false }
    return clearsGuard(from: start, to: end)
  }

  /// Static grid routes also need short legal legs round a living machine's dynamic hull.
  private func guardWaypoint(from start: SIMD2<Float>, towards target: SIMD2<Float>) -> SIMD2<
    Float
  >? {
    for state in fight.hostiles.values where state.blocksParty {
      let end = GuardCollision.resolve(
        start: start, delta: target - start, centre: state.position,
        radius: GuardCollision.pawnClearance)
      guard simd_distance(end, target) > 0.01 else { continue }
      let radial = start - state.position
      guard simd_length(radial) > 0.001 else { return nil }
      let direction = simd_normalize(radial)
      let radius = min(4, max(2.5, simd_length(radial)))
      return [Float(0.4), -0.4, 0.8, -0.8].map { angle in
        let rotated = SIMD2(
          direction.x * cos(angle) - direction.y * sin(angle),
          direction.x * sin(angle) + direction.y * cos(angle))
        return state.position + rotated * radius
      }.filter { canStandParty($0) && canTraverseParty(from: start, to: $0) }
        .min { simd_distance_squared($0, target) < simd_distance_squared($1, target) }
    }
    return nil
  }

  /// A crawler's ram line is fixed as it winds up, so a companion free to move steps out of it,
  /// or waits where it is clear rather than cross it, in either stance. A Go or Hold order keeps
  /// its place, as it does under the guard's burst (issue #208). Nil when nothing is in its way.
  private func crawlerSidestep(
    for member: PartyMember, at position: SIMD2<Float>, heading destination: SIMD2<Float>,
    leader: SIMD2<Float>, occupied: [SIMD2<Float>], guardian: RobotGuard?
  ) -> SIMD2<Float>? {
    guard case .following = session.order(of: member),
      fight.crawlerThreatens(from: position, to: destination)
    else { return nil }
    return fight.crawlerAside(from: position, keeping: crawlerAsides[member]) { point in
      let clear =
        !(guardian.map { self.fight.companionIsThreatened(at: point, by: $0) } ?? false)
        && !self.fight.droneThreatens(point)
      guard point != position else { return clear }
      return clear && simd_distance(point, leader) <= CompanionTactics.leaderLeash
        && simd_distance(point, leader) >= CompanionTactics.minimumSpacing
        && occupied.allSatisfy { simd_distance(point, $0) >= CompanionTactics.minimumSpacing }
        && self.canStandParty(point) && self.canReachParty(from: position, to: point)
    }
  }

  private func planCompanions(leader: SIMD2<Float>, velocity: SIMD2<Float>, dt: Float) {
    let current = positions
    guard let guardState = fight.companionGuard(near: leader), !fight.holdsParty else {
      tactics = [:]
      if !companionStatus.isEmpty { companionStatus = "" }
      // Beyond the guard's reach its crawlers can still chase the party, and their lines still
      // move a companion aside.
      var sidesteps: [PartyMember: CompanionTactics.Intent] = [:]
      var asides: [PartyMember: SIMD2<Float>] = [:]
      if !fight.holdsParty {
        for member in session.companions {
          guard let position = current[member] else { continue }
          let occupied = session.companions.filter { $0 != member }.compactMap {
            sidesteps[$0]?.position ?? Self.point(of: session.order(of: $0))
              ?? formationTargets[$0] ?? current[$0]
          }
          if let aside = crawlerSidestep(
            for: member, at: position, heading: formationTargets[member] ?? position,
            leader: leader, occupied: occupied, guardian: nil)
          {
            sidesteps[member] = CompanionTactics.Intent(
              position: aside, activity: aside == position ? .following : .avoiding)
            if aside != position { asides[member] = aside }
          }
        }
      }
      companionIntents = sidesteps
      crawlerAsides = asides
      return
    }
    let away = leader - guardState.robot.position
    if simd_length(away) > 0.001, simd_dot(velocity, simd_normalize(away)) > 1 {
      retreatRemaining = 1
    } else {
      retreatRemaining = max(0, retreatRemaining - dt)
    }
    if regrouping {
      regroupRemaining = max(0, regroupRemaining - dt)
      if regroupRemaining == 0,
        session.companions.allSatisfy({
          current[$0].map { simd_distance($0, leader) < 2.6 } ?? false
        })
      {
        regrouping = false
      }
    }
    var next: [PartyMember: CompanionTactics.Intent] = [:]
    var asides: [PartyMember: SIMD2<Float>] = [:]
    // Reserve intended places, rather than transient moving bodies. A later companion
    // cannot claim the same cover/escape slot; existing orders keep their own anchors.
    var reserved: [PartyMember: SIMD2<Float>] = [:]
    for member in session.companions {
      reserved[member] =
        Self.point(of: session.order(of: member)) ?? companionIntents[member]?.position
        ?? formationTargets[member] ?? current[member]
    }
    for member in session.companions {
      guard let position = current[member] else { continue }
      var policy = tactics[member] ?? CompanionTactics()
      let base = formationTargets[member] ?? position
      reserved[member] = nil
      let occupied = Array(reserved.values)
      var intent = policy.plan(
        input: CompanionTactics.Input(
          member: member, leader: session.leader, position: position, leaderPosition: leader,
          baseTarget: base, order: session.order(of: member),
          stance: session.combatStance,
          active: session.combatStance == .defend || (!regrouping && retreatRemaining == 0),
          guardPosition: guardState.robot.position, guardFacing: guardState.robot.facing,
          phase: guardState.robot.phase, stage: guardState.strategy.phase,
          weakpoints: fight.weakpoints(for: guardState.id), dt: dt),
        canStand: { self.canStandParty($0) },
        canTraverse: { self.canReachParty(from: $0, to: $1) },
        canFire: {
          self.fight.companionCanFire(member, from: $0, at: $1, weapon: $2, figures: current)
        },
        canFireAtBody: {
          self.fight.companionCanFireAtBody(
            member, from: $0, at: guardState.id, weapon: $1, figures: current)
        },
        isCovered: { self.fight.companionHasCover(at: $0, from: guardState.robot) },
        isThreatened: {
          self.fight.companionIsThreatened(at: $0, by: guardState.robot)
            || self.fight.droneThreatens($0) || self.fight.crawlerThreatens($0)
        },
        isSpaced: { point in
          simd_distance(point, leader) >= CompanionTactics.minimumSpacing
            && occupied.allSatisfy {
              simd_distance(point, $0) >= CompanionTactics.minimumSpacing
            }
        })
      if let aside = crawlerSidestep(
        for: member, at: position, heading: intent.position ?? base, leader: leader,
        occupied: occupied, guardian: guardState.robot)
      {
        intent.position = aside
        if aside != position {
          intent.activity = .avoiding
          intent.fire = false
          asides[member] = aside
        }
      }
      // A scout drone on its dive, then a crawler closing in or winding up, takes the fire of a
      // companion whose plan engages, after any step out of a ram's line (issues #201, #208).
      intent = CompanionTactics.preferringPack(intent, stance: session.combatStance) {
        if let drone = self.fight.companionDrone(for: member, from: position, figures: current) {
          return .init(kind: .drone, id: drone.id, position: drone.position, weapon: drone.weapon)
        }
        return self.fight.companionCrawler(for: member, from: position, figures: current).map {
          .init(kind: .crawler, id: $0.id, position: $0.position, weapon: $0.weapon)
        }
      }
      tactics[member] = policy
      next[member] = intent
      reserved[member] = Self.point(of: session.order(of: member)) ?? intent.position ?? base
    }
    companionIntents = next
    crawlerAsides = asides
    let status = session.companions.compactMap { member -> String? in
      guard let activity = next[member]?.activity else { return nil }
      let action =
        switch activity {
        case .following: "following"
        case .ordered: "moving to order"
        case .holding: "holding"
        case .approaching: "repositioning"
        case .waiting: "ready"
        case .attacking: "attacking"
        case .avoiding: "seeking safety"
        }
      return "\(member.displayName): \(action)"
    }.joined(separator: " · ")
    if companionStatus != status { companionStatus = status }
  }

  // MARK: - Squad orders

  /// The point an order keeps a companion to; nil while following, or while a hold waits
  /// for its place to be recorded.
  private static func point(of order: GameSession.Order) -> SIMD2<Float>? {
    switch order {
    case .following: nil
    case .going(let point): point
    case .holding(let point): point
    }
  }

  /// A squad order (ADR 0003, phase S3). The D-pad's point lies up to 6 m ahead of the leader,
  /// shortened by the first wall; a touch order's is the ground under the finger. Either moves
  /// up to a metre to somewhere the companions can reach, or shows a brief cross and does
  /// nothing.
  private func give(_ command: GameSession.Command, at screen: InputRules.ScreenPoint?) {
    guard session.mode == .exploring, session.ordersAvailable, !fight.holdsParty,
      let leader = position(of: session.leader)
    else { return }
    if command == .attack || command == .defend {
      guard session.setCombatStance(command == .attack ? .attack : .defend) else { return }
      companionIntents = [:]
      crawlerAsides = [:]
      tactics = [:]
      formationTargets = [:]
      companionStatus = ""
      touchMark = nil
      // Defend has its own persistent cease-fire and cover/recall policy. A temporary
      // Formation/Follow interval must not prevent that policy from choosing safe return legs.
      regrouping = false
      regroupRemaining = 0
      if command == .attack { retreatRemaining = 0 }
      for member in session.companions { motors[member]?.wake() }
      showOrders()
      return
    }
    if command == .hold {
      guard session.holdAll() else { return }
      // A new explicit position order replaces a temporary Formation/Follow request.
      regrouping = false
      regroupRemaining = 0
      pinHolds()
      showOrders()
      return
    }
    // A touch marks what the finger's ray met first, a block or the ground, as the menu opened;
    // a touch above the ground marks nothing.
    let pressed: SIMD3<Float>?
    if let screen {
      pressed = touchMark?.screen == screen ? touchMark?.hit : firstHit(at: screen)
      touchMark = nil
    } else {
      let ahead = pointAhead(of: leader)
      pressed = SIMD3(ahead.x, 0, ahead.y)
    }
    guard let pressed else { return }
    let marked = SIMD2(pressed.x, pressed.z)
    guard let region = region(near: leader), let point = reachable(near: marked, in: region)
    else {
      refuse(at: pressed)
      return
    }
    switch command {
    case .bothGo:
      guard let spots = spots(around: point, from: leader, in: region) else {
        refuse(at: pressed)
        return
      }
      // Each takes the spot that makes the least walking in total, so their ways do not cross.
      let members = session.companions
      guard members.count == 2, let first = position(of: members[0]),
        let second = position(of: members[1])
      else { return }
      let kept =
        simd_distance(first, spots[0]) + simd_distance(second, spots[1])
        <= simd_distance(first, spots[1]) + simd_distance(second, spots[0])
      session.send(members[0], to: kept ? spots[0] : spots[1])
      session.send(members[1], to: kept ? spots[1] : spots[0])
      for member in members { motors[member]?.wake() }
    case .leftGoes, .rightGoes:
      guard
        let member = command == .leftGoes ? session.leftCompanion : session.rightCompanion
      else { return }
      var target = point
      // Not onto the other companion's own point, where neither could settle: beside it, on
      // the side the order names, so neither walks through the other.
      if let other = session.companions.first(where: { $0 != member }),
        let taken = Self.point(of: session.order(of: other)),
        simd_distance(taken, point) < Self.spotSpacing,
        let beside = spot(
          beside: taken, from: leader, onRight: command == .rightGoes, in: region)
      {
        target = beside
      }
      session.send(member, to: target)
      motors[member]?.wake()
    case .hold, .attack, .defend:
      break
    }
    regrouping = false
    regroupRemaining = 0
    showOrders()
  }

  /// Up to `orderReach` ahead along the leader's facing, shortened by scenery or a live hull.
  private func pointAhead(of leader: SIMD2<Float>) -> SIMD2<Float> {
    let heading = Movement.facing(yaw: yaw[session.leader] ?? 0)
    let far = leader + heading * Self.orderReach
    if canTraverseParty(from: leader, to: far) { return far }
    var clear: Float = 0
    var blocked = Self.orderReach
    for _ in 0..<12 {
      let middle = (clear + blocked) / 2
      if canTraverseParty(from: leader, to: leader + heading * middle) {
        clear = middle
      } else {
        blocked = middle
      }
    }
    return leader + heading * clear
  }

  /// The connected area the leader stands in, from the nearest walkable cell.
  private func region(near point: SIMD2<Float>) -> Int32? {
    grid.nearestWalkable(to: point, within: 0.6).flatMap { grid.region(at: $0) }
  }

  /// The marked point, or the nearest place within `orderSnap` of it in the leader's area,
  /// out of doorways where there is a choice.
  private func reachable(near point: SIMD2<Float>, in region: Int32) -> SIMD2<Float>? {
    if canStandParty(point), grid.isRoomy(point), grid.region(at: point) == region { return point }
    return grid.nearestWalkable(
      to: point, within: Self.orderSnap, region: region,
      where: { grid.isRoomy($0) && canStandParty($0) })
      ?? grid.nearestWalkable(
        to: point, within: Self.orderSnap, region: region, where: { canStandParty($0) })
  }

  /// Two spots `spotSpacing` apart around a point: side by side across the line from the
  /// leader, else one behind the other, else the point and the nearest place far enough away.
  private func spots(around point: SIMD2<Float>, from leader: SIMD2<Float>, in region: Int32)
    -> [SIMD2<Float>]?
  {
    let (along, across) = axes(of: point, from: leader)
    let half = Self.spotSpacing / 2
    for axis in [across, along] {
      let pair = [point + axis * half, point - axis * half]
      if pair.allSatisfy({ fits($0, near: point, in: region) }) { return pair }
    }
    let second = grid.nearestWalkable(
      to: point, within: Self.orderSnap + Self.spotSpacing, region: region,
      where: { simd_distance($0, point) >= Self.spotSpacing && fits($0, near: point, in: region) })
    guard fits(point, near: point, in: region), let second else { return nil }
    return [point, second]
  }

  /// A spot `spotSpacing` beside another companion's point: on the named side of the line from
  /// the leader where it fits, else the other side, else the nearest place far enough away.
  private func spot(
    beside taken: SIMD2<Float>, from leader: SIMD2<Float>, onRight: Bool, in region: Int32
  ) -> SIMD2<Float>? {
    let across = axes(of: taken, from: leader).across * (onRight ? 1 : -1)
    for candidate in [taken + across * Self.spotSpacing, taken - across * Self.spotSpacing]
    where fits(candidate, near: taken, in: region) {
      return candidate
    }
    return grid.nearestWalkable(
      to: taken, within: Self.orderSnap + Self.spotSpacing, region: region,
      where: { simd_distance($0, taken) >= Self.spotSpacing && fits($0, near: taken, in: region) })
  }

  /// The line from the leader to a point, and the direction to its right, which is screen right
  /// under a camera behind the leader. A point at the leader's feet takes the leader's facing.
  private func axes(of point: SIMD2<Float>, from leader: SIMD2<Float>)
    -> (along: SIMD2<Float>, across: SIMD2<Float>)
  {
    let offset = point - leader
    let along =
      simd_length(offset) > 0.01
      ? simd_normalize(offset) : Movement.facing(yaw: yaw[session.leader] ?? 0)
    return (along, SIMD2(-along.y, along.x))
  }

  /// Somewhere a companion can stand, in the leader's area, reached straight from `origin`.
  private func fits(_ spot: SIMD2<Float>, near origin: SIMD2<Float>, in region: Int32) -> Bool {
    canStandParty(spot) && grid.region(at: spot) == region
      && canTraverseParty(from: origin, to: spot)
  }

  /// Show the cross where an order could not go, briefly: standing where the finger pressed,
  /// or where the D-pad marked, and facing the camera so it reads on a block's side too.
  private func refuse(at point: SIMD3<Float>) {
    refusedOrders += 1
    crossRemaining = Self.crossTime
    let eye = camera.eye
    let toCamera = simd_normalize(eye - point)
    let standing = point + toCamera * 0.3 + [0, point.y < 0.01 ? 0.4 : 0, 0]
    refusalCross.look(at: eye, from: standing, relativeTo: nil)
    refusalCross.isEnabled = true
  }

  /// What the ray through a touch order's point meets first: one of the level's blocks, or the
  /// ground; nil when it meets neither.
  private func firstHit(at screen: InputRules.ScreenPoint) -> SIMD3<Float>? {
    let blocks = level.boxes.map { (centre: $0.position, size: $0.size) }
    return projection(aspect: screen.aspect).firstHit(
      atScreen: [screen.x, screen.y], blocks: blocks)
  }

  /// Companions told to hold where they are hold where they stand now.
  private func pinHolds() {
    for member in session.party where session.order(of: member) == .holding(nil) {
      if let point = position(of: member) { session.pin(member, at: point) }
    }
  }

  /// A ring at each going companion's point, until they arrive.
  private func showOrders() {
    for (member, ring) in orderMarkers {
      if member != session.leader, case .going(let point) = session.order(of: member) {
        ring.position = [point.x, SceneStyle.groundMarkerHeight, point.y]
        ring.isEnabled = true
      } else {
        ring.isEnabled = false
      }
    }
  }

  /// The camera's mapping between the screen and the ground, for a screen of this shape, through
  /// its lens as it is now.
  func projection(aspect: Float) -> CameraProjection {
    camera.projection(aspect: aspect)
  }

  /// Where a member's body stands on the ground.
  private func position(of member: PartyMember) -> SIMD2<Float>? {
    bodies[member].map { SIMD2($0.position.x, $0.position.z) }
  }

  /// A trigger area shows its line the first time the leader walks into it in a run, and an
  /// encounter's area begins its fight once its beat is next.
  private func checkTriggers() {
    guard retryElapsed == nil, let position = self.position(of: session.leader) else { return }
    for trigger in level.triggers where trigger.area.contains(position) {
      if session.fire(trigger.id) { observation = trigger.line }
    }
    var inGatheringArea = false
    for encounter in level.encounters {
      guard case .area(let area) = encounter.start else { continue }
      guard area.contains(position) else { continue }
      // A scene for the whole party, such as the end of the opening, waits until everyone is
      // close; companions holding elsewhere must be called back first.
      if encounter.gathersParty, encounter.beat == session.nextBeat {
        inGatheringArea = true
        let missing = session.companions.filter { member in
          guard let point = self.position(of: member) else { return true }
          return simd_distance(point, position) > Self.gatherRadius
        }
        if !missing.isEmpty {
          if !toldWhoIsMissing, missing.contains(where: { session.order(of: $0) != .following }) {
            toldWhoIsMissing = true
            let names = missing.map(\.displayName).joined(separator: " and ")
            observation = "\(names) \(missing.count == 1 ? "is" : "are") not with you yet."
          }
          continue
        }
      }
      if session.beginEncounter(encounter.beat) {
        fight.begin(encounter)
        retrySpot = encounter.retryAt
      }
    }
    if !inGatheringArea { toldWhoIsMissing = false }
  }

  // MARK: - Fights

  /// Advance the bridge fight, its cues, feedback and retry.
  private func stepStage(
    leader: PartyMember, at position: SIMD2<Float>, armed: Bool,
    untouchable: Set<PartyMember> = [], dt: Float
  ) {
    // The authored west-side exit lies beyond the entire guard's acquisition envelope. Close
    // the encounter before another fixed-step shot or supply-case action can begin the ambush.
    if session.inEncounter,
      let encounter = level.encounters.first(where: { $0.beat == session.beat }),
      let exit = encounter.safeExit, exit.contains(position),
      let robot = encounter.hostiles.first(where: { $0.attack == .robot }),
      fight.resolveRobotBypass(id: robot.id, session: session)
    {
      observation = "Clear of the guard."
    }
    if !damageFeedback.labels.isEmpty { damageFeedback.advance(dt: dt) }
    let figures = Dictionary(
      uniqueKeysWithValues: PartyMember.allCases.compactMap { member in
        bodies[member]?.isEnabled == true ? self.position(of: member).map { (member, $0) } : nil
      })
    let outcome = fight.step(
      dt: dt, leader: position, facing: Movement.facing(yaw: yaw[leader] ?? 0),
      aiming: aimDirection != nil, fireHeld: armed && fireHeld,
      firePressed: armed && firePressPending, figures: figures, session: session,
      grenadePressed: grenadePressPending == leader && !fight.holdsParty && untouchable.isEmpty,
      untouchable: untouchable, companionIntents: companionIntents,
      facings: Dictionary(
        uniqueKeysWithValues: figures.keys.map {
          ($0, Movement.facing(yaw: yaw[$0] ?? 0))
        }))
    stage.update(fight, dt: dt)
    updateWeaponStatus()
    firePressPending = false
    grenadePressPending = nil
    // The leader turns there in the steps to come, at her turn rate (ADR 0008).
    if let facing = outcome.facing { facingGoal = facing }
    // Members still rocking from a shot or a hit show it, and those that just settled stand
    // straight again.
    let jolted = Set(fight.jolts.keys)
    for member in jolted.union(joltedMembers) {
      showPose(member)
    }
    joltedMembers = jolted
    let events = fight.takeEvents()
    #if DEBUG
      // Observe resolved fixed-step rounds before a slower rendered frame can skip them.
      if fight.shieldIsUp, let tom = figures[.tom] {
        shieldStops +=
          fight.shots.filter { shot in
            guard shot.side == .hostile, let trace = shot.trace, trace.strike == .scenery
            else { return false }
            let start = SIMD2(trace.start.x, trace.start.z)
            let end = SIMD2(trace.end.x, trace.end.z)
            return simd_distance(start, tom) > ShieldDome.radius
              && abs(simd_distance(end, tom) - ShieldDome.radius) < 0.02
          }.count
      }
    #endif
    let damage = events.compactMap { event -> DamageHit? in
      if case .damaged(let hit) = event { return hit }
      return nil
    }
    for hit in damage {
      damageFeedback.receive(hit)
      #if DEBUG
        damageTally.record(hit)
      #endif
    }
    stage.showDamage(damage)
    if legBreakGeneration != controls.touchGeneration {
      combatEvents.removeAll { if case .guardLegBroken = $0 { true } else { false } }
      legBreakGeneration = controls.touchGeneration
    }
    combatEvents.append(contentsOf: events)
    if combatEvents.count > Self.keptEvents {
      combatEvents.removeFirst(combatEvents.count - Self.keptEvents)
    }
    if let line = outcome.line { observation = line }
    if let shooter = outcome.shooter {
      setYaw(shooter.member, Movement.yaw(towards: shooter.facing))
    }
    let threat = fight.threat
    if self.threat != threat { self.threat = threat }
    if guardTarget != fight.guardTarget { guardTarget = fight.guardTarget }
    let guardHint = fight.guardHint
    if self.guardHint != guardHint { self.guardHint = guardHint }
    if guardHealth != fight.guardHealth { guardHealth = fight.guardHealth }
    if weaponDrawn != fight.isDrawn { weaponDrawn = fight.isDrawn }
    if lockedHostile != fight.lock { lockedHostile = fight.lock }
    shieldDome.isEnabled = fight.shieldIsUp
    if outcome.retry {
      clearDamageFeedback()
      retryElapsed = 0
    }
  }

  /// The encounter starts again after the leader's last allowed hit: the screen fades out,
  /// the fight is put back as it began with the leader just outside its area, and the screen
  /// fades back in. Like Resume, play then waits for every control to be released.
  private func advanceRetry(deltaTime: Float) {
    guard let before = retryElapsed, deltaTime.isFinite, deltaTime > 0 else { return }
    let elapsed = before + min(deltaTime, 1 / 30)
    if before < Self.retryFadeOut, elapsed >= Self.retryFadeOut { performRetry() }
    guard elapsed < Self.retryFadeOut + Self.retryFadeIn else {
      retryElapsed = nil
      fade = 0
      skipNextStep = true
      controls.requireNeutralInput()
      return
    }
    retryElapsed = elapsed
    fade =
      elapsed < Self.retryFadeOut
      ? elapsed / Self.retryFadeOut : 1 - (elapsed - Self.retryFadeOut) / Self.retryFadeIn
  }

  private func performRetry() {
    session.retryEncounter()
    let spot = retrySpot ?? level.spawn(session.leader)
    place(session.leader, at: spot)
    setYaw(session.leader, Movement.yaw(towards: level.heading))
    resetPlay(around: spot)
    observation = "Try again."
  }

  private func changeLeader() {
    let previous = squadLeader
    let leader = session.leader
    squadLeader = leader
    formationTargets = [:]
    updateWeaponStatus()
    facingGoal = nil
    if let point = position(of: leader) { route.reset(to: point) }
    planner.reset()
    for member in [previous, leader] { motors[member] = CompanionMotor(for: member) }
    showLeaderMarker()
  }

  private func showLeaderMarker() {
    for member in PartyMember.allCases {
      markers[member]?.isEnabled = member == session.leader
    }
  }

  private func place(_ member: PartyMember, at point: SIMD2<Float>) {
    bodies[member]?.position = [
      point.x, PartyBody.height / 2, point.y,
    ]
  }

  /// Companions turn towards their movement or the formation heading, at a limited rate.
  private func turn(_ member: PartyMember, moved delta: SIMD2<Float>, dt: Float) {
    let wanted: Float
    if simd_length(delta) > 0.2 * dt {
      wanted = Movement.yaw(towards: delta)
    } else if motors[member]?.isSettled == true {
      wanted = Movement.yaw(towards: planner.heading)
    } else {
      return
    }
    let current = yaw[member] ?? wanted
    setYaw(
      member,
      Movement.turn(from: current, towards: wanted, limit: Movement.companionTurnRate * dt))
  }

  /// The leader turns towards `direction` at her turn rate (ADR 0008). Once she faces where the
  /// fight asked her to turn, that request is done.
  private func turnLeader(_ leader: PartyMember, towards direction: SIMD2<Float>, dt: Float) {
    let wanted = Movement.yaw(towards: direction)
    let current = yaw[leader] ?? wanted
    let turned = Movement.turn(from: current, towards: wanted, limit: Movement.leaderTurnRate * dt)
    setYaw(leader, turned)
    if let goal = facingGoal, simd_length_squared(goal) > 0.000001,
      simd_dot(Movement.facing(yaw: turned), simd_normalize(goal)) > 0.99995
    {
      facingGoal = nil
    }
  }

  private func setYaw(_ member: PartyMember, _ angle: Float) {
    yaw[member] = angle
    showPose(member)
  }

  /// A member's facing, and how they rock for a moment after firing or being hit (ADR 0008).
  private func showPose(_ member: PartyMember) {
    let facing = simd_quatf(angle: yaw[member] ?? 0, axis: [0, 1, 0])
    if let roll, roll.member == member {
      let tumble = roll.pose(height: PartyBody.height)
      visuals[member]?.scale = tumble.scale
      visuals[member]?.orientation = tumble.tilt * facing
      visuals[member]?.position = tumble.offset
      return
    }
    // A pawn's walk and a jolt both lean the figure about its feet; the walk also lifts it.
    let gait = gaits[member] ?? PawnGait()
    let lean =
      (fight.jolts[member]?.lean ?? .zero)
      + gait.lean(facing: Movement.facing(yaw: yaw[member] ?? 0))
    let pose = BodyJolt.pose(lean: lean, height: PartyBody.height)
    visuals[member]?.scale = [1, 1, 1]
    visuals[member]?.orientation = pose.tilt * facing
    visuals[member]?.position = pose.offset + [0, gait.lift, 0]
  }

  /// Each pawn shows the step it has just taken: a bob, a rock to the side and a lean, drawn
  /// from where its body moved.
  private func showWalks(from before: [PartyMember: SIMD2<Float>], dt: Float) {
    for member in session.party {
      guard let start = before[member], let end = position(of: member) else { continue }
      gaits[member, default: PawnGait()].step(moved: end - start, dt: dt)
      showPose(member)
    }
  }

  /// The leader's dodge roll begins, the way they move, or the way they face with no movement
  /// held. A scene that holds the party, a roll under way or its cooldown stops it.
  private func startRoll(_ leader: PartyMember, moving: SIMD2<Float>, held: Bool) {
    guard !held, roll == nil, rollCooldown <= 0, session.party.contains(leader) else { return }
    let way = simd_length_squared(moving) > 0.000001 ? moving : facing(of: leader)
    roll = DodgeRoll(member: leader, direction: way)
    facingGoal = nil
    setYaw(leader, Movement.yaw(towards: way))
  }

  /// Where each member of the party stands. Members who have not joined are not included.
  private var positions: [PartyMember: SIMD2<Float>] {
    Dictionary(
      uniqueKeysWithValues: session.party.compactMap { member in
        position(of: member).map { (member, $0) }
      })
  }

  private func updateActivity() {
    clearDamageFeedback()
    combatEvents.removeAll {
      switch $0 {
      case .guardTargeted, .guardLegBroken, .droneWarning, .crawlerWarning, .damaged: true
      default: false
      }
    }
    controls.setActive(isPresented && isApplicationActive)
    controls.requireNeutralInput()
    skipNextStep = true
  }

  private func clearDamageFeedback() {
    if !damageFeedback.labels.isEmpty { damageFeedback.clear() }
    stage.clearDamage()
    combatEvents.removeAll {
      switch $0 {
      case .damaged, .guardLegBroken: true
      default: false
      }
    }
  }

  private func updateCamera(deltaTime: Float) {
    guard let leader = position(of: session.leader) else { return }
    let close = (session.inEncounter && !fight.holdsParty) || aimDirection != nil
    let party = ([session.leader] + session.companions).compactMap { bodies[$0]?.position }
    camera.update(
      over: leader, lean: fight.cameraLean(leader: leader), close: close, party: party,
      deltaTime: deltaTime)
  }

  /// A new line or objective shows in the status panel for `lineTime` seconds of play, then
  /// leaves it to the essentials; Pause and conversations hold the time.
  private func ageLines(by dt: Float) {
    if lineCount != agedLineCount {
      agedLineCount = lineCount
      lineAge = 0
    } else {
      lineAge += dt
    }
    if objective != agedObjective {
      agedObjective = objective
      objectiveAge = 0
    } else {
      objectiveAge += dt
    }
    if (lineAge < Self.lineTime) != lineIsFresh { lineIsFresh.toggle() }
    if (objectiveAge < Self.lineTime) != objectiveIsFresh { objectiveIsFresh.toggle() }
  }

  /// The compass to the goal for the story's beat: its name, the distance from the leader, and
  /// its direction on screen, turned from up the screen towards its right.
  private func updateCompass() {
    let goal = level.goals.last(where: { $0.beat <= session.beat })?.goal
    guard let goal,
      let leader = position(of: session.leader)
    else {
      if compass != nil { compass = nil }
      return
    }
    let toward = goal.point - leader
    let (forward, right) = Movement.axes(cameraOffset: level.cameraOffset)
    let degrees = (atan2(simd_dot(toward, right), simd_dot(toward, forward)) * 180 / .pi).rounded()
    let next = Compass(
      name: goal.name, metres: Int(simd_length(toward).rounded()), angle: degrees * .pi / 180)
    if next != compass { compass = next }
  }

  #if DEBUG
    /// What a scripted playtest can see each frame.
    var playtestSnapshot: PlaytestRunner.Snapshot {
      let robot = fight.hostiles["stranger"]?.robot
      let current = positions
      let guardState = current[session.leader].flatMap { fight.companionGuard(near: $0) }
      let covered = Set(
        current.compactMap { member, point -> PartyMember? in
          guard let guardState, fight.companionHasCover(at: point, from: guardState.robot)
          else { return nil }
          return member
        })
      return PlaytestRunner.Snapshot(
        level: level, leader: session.leader, party: session.party, positions: positions,
        mode: session.mode, firedTriggers: session.firedTriggers.count, beat: session.beat,
        hitsTaken: session.hitsTaken, hitsAllowed: GameSession.hitsAllowed,
        defeated: session.defeated.filter { fight.hostiles[$0]?.spec.isPack != true }.count,
        formation: session.formation, orders: session.orders, refusedOrders: refusedOrders,
        camera: projection(aspect: PlaytestRunner.screenAspect),
        weapon: fight.status(for: session.leader),
        robotPhase: robot?.phase, robotShots: robot?.shotSerial ?? 0, locked: fight.lock != nil,
        guardStrategy: fight.guardStrategies["stranger"],
        guardPoints: fight.weakpoints(for: "stranger"),
        robotPosition: robot?.position, robotFacing: robot?.facing, isRetrying: isRetrying,
        companionActivities: companionIntents.mapValues(\.activity),
        combatStance: session.combatStance,
        partyWeapons: Dictionary(
          uniqueKeysWithValues: session.party.map { ($0, fight.status(for: $0)) }),
        guardTarget: fight.guardTarget(for: "stranger"), robotCommittedPoint: robot?.committedPoint,
        partyHits: Dictionary(
          uniqueKeysWithValues: session.party.map { ($0, session.hits(of: $0)) }),
        companionTargets: companionTargets, coveredMembers: covered,
        damage: damageTally, damageLabelCount: damageFeedback.labels.count, showsPanel: showsPanel,
        grenadeCooldown: fight.grenadeCooldown, grenadeInFlight: fight.grenade != nil,
        shieldRaised: fight.shieldIsUp, shieldStops: shieldStops,
        dronesDown: session.defeated.filter { fight.hostiles[$0]?.drone != nil }.count,
        drones: fight.hostiles.values.compactMap { state in
          state.drone.map {
            PlaytestRunner.Snapshot.Drone(
              id: state.spec.id, position: $0.position, phase: $0.phase,
              watching: fight.droneTarget(for: state.spec.id), committedPoint: $0.committedPoint)
          }
        }.sorted { $0.id < $1.id },
        crawlersDown: session.defeated.filter { fight.hostiles[$0]?.crawler != nil }.count,
        crawlers: fight.hostiles.values.compactMap { state in
          state.crawler.map {
            PlaytestRunner.Snapshot.CrawlerView(
              id: state.spec.id, position: $0.position, phase: $0.phase,
              watching: fight.crawlerTarget(for: state.spec.id), ramStart: $0.ramStart,
              ramEnd: $0.ramEnd)
          }
        }.sorted { $0.id < $1.id })
    }

    /// Start a scripted playtest; an unknown scenario name is reported on the HUD.
    func startPlaytest(_ scenario: String) {
      guard let runner = PlaytestRunner(scenario: scenario) else {
        observation =
          "Unknown playtest \"\(scenario)\". Try: "
          + PlaytestRunner.scenarioNames.joined(separator: ", ") + "."
        return
      }
      install(runner)
    }

    private func install(_ runner: PlaytestRunner) {
      if runner.name == "touch-fight" { controls.useTouchControls() }
      playtest = runner
      observation = runner.status
      // Small discs at each companion's target, so screenshots show where they are heading.
      let style = SceneStyle()
      for member in PartyMember.allCases {
        let disc = ModelEntity(
          mesh: .generateCylinder(height: 0.01, radius: 0.12), materials: [style.signal])
        disc.name = "playtest.target.\(member.rawValue)"
        disc.position.y = SceneStyle.groundMarkerHeight
        disc.isEnabled = false
        root.addChild(disc)
        targetMarkers[member] = disc
      }
    }

    private func recordPlaytest(dt: Float, milliseconds: Double) {
      guard playtest != nil else { return }
      if playtest?.orientation == "unknown",
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
      {
        playtest?.orientation =
          switch scene.effectiveGeometry.interfaceOrientation {
          case .landscapeLeft: "landscapeLeft"
          case .landscapeRight: "landscapeRight"
          case .portrait, .portraitUpsideDown: "portrait"
          default: "unknown"
          }
      }
      playtest?.record(
        PlaytestRunner.Frame(
          dt: dt, leader: session.leader, positions: positions, targets: companionTargets,
          warning: diagnostic, simulationMilliseconds: milliseconds))
      for (member, disc) in targetMarkers {
        let target = companionTargets[member]
        disc.isEnabled = target != nil && member != session.leader
        if let target {
          disc.position = [target.x, SceneStyle.groundMarkerHeight, target.y]
        }
      }
      // The playtest's progress takes the status line while a scripted run is active.
      if let status = playtest?.status, shownLine != status {
        shownLine = status
        lineCount &+= 1
      }
    }
  #endif

  private static func freshMotors() -> [PartyMember: CompanionMotor] {
    Dictionary(uniqueKeysWithValues: PartyMember.allCases.map { ($0, CompanionMotor(for: $0)) })
  }
}
