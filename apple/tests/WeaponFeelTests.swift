import AVFoundation
import RealityKit
import Testing
import simd

@testable import Lauder

/// ADR 0008: no aim line, a pose that shows the aim, turning at a limited rate, shots that leave
/// along the leader's facing within a spread, enemies that flinch and fall, and the sounds and
/// vibrations each event plays.
@MainActor
struct WeaponFeelTests {
  // MARK: - Spread

  @Test
  func theSpreadWidensWithEachShotAndNarrowsAgainWithTime() {
    let spread = Weapon.carbine.spread
    var scatter = Scatter()
    #expect(scatter.angle(spread: spread, speed: 0, turning: 0) == spread.rest)
    // Standing still, the first shot lands within 10 cm at the carbine's full reach.
    #expect(Weapon.carbine.range * tan(spread.rest) < 0.1)
    for _ in 0..<3 { scatter.fired(spread: spread) }
    #expect(
      abs(scatter.angle(spread: spread, speed: 0, turning: 0) - (spread.rest + 3 * spread.perShot))
        < 0.0001)
    // It never passes the widest, however long the burst.
    for _ in 0..<20 { scatter.fired(spread: spread) }
    #expect(abs(scatter.angle(spread: spread, speed: 0, turning: 0) - spread.widest) < 0.0001)
    #expect(scatter.angle(spread: spread, speed: 1, turning: 1) == spread.widest)
    // A few seconds' rest brings it back.
    for _ in 0..<600 { scatter.settle(dt: 1 / 120, spread: spread) }
    #expect(scatter.angle(spread: spread, speed: 0, turning: 0) == spread.rest)
    // Moving and turning widen it while they last.
    #expect(
      abs(scatter.angle(spread: spread, speed: 1, turning: 0) - (spread.rest + spread.moving))
        < 0.0001)
    #expect(
      abs(
        scatter.angle(spread: spread, speed: 0, turning: 0.5) - (spread.rest + spread.turning / 2))
        < 0.0001)
  }

  @Test
  func eachShotGoesWithinItsConeMostOftenNearTheMiddle() {
    var random = SeededRandom(seed: 1)
    let cone: Float = 0.1
    let deviations = (0..<2000).map { _ in Scatter.deviation(within: cone, using: &random) }
    #expect(deviations.allSatisfy { abs($0) <= cone })
    let middle = deviations.filter { abs($0) <= cone / 2 }.count
    #expect(middle > 1400)
    #expect(Scatter.deviation(within: 0, using: &random) == 0)
    // The same seed scatters the same way.
    var first = SeededRandom(seed: 7)
    var second = SeededRandom(seed: 7)
    #expect(first.next() == second.next())
  }

  @Test
  func aScatteredShotCanMissItsTargetButNeverHitsSomeoneNotYetATarget() throws {
    let target = Aim.Hostile(id: "target", position: [0, -10], isTarget: true)
    let aimed = try #require(
      Aim.shot(
        from: .zero, aim: [0, -1], facing: [0, -1], range: 14, hostiles: [target], blockers: []))
    #expect(Aim.scattered(aimed, by: 0, range: 14, hostiles: [target], blockers: []) == aimed)
    // A little off still meets the body; 4° off at 10 m passes 0.7 m wide and flies on.
    let near = Aim.scattered(
      aimed, by: Spread.degrees(1), range: 14, hostiles: [target], blockers: [])
    #expect(near.strike == .body("target"))
    let wide = Aim.scattered(
      aimed, by: Spread.degrees(4), range: 14, hostiles: [target], blockers: [])
    #expect(wide.strike == .nothing && simd_distance(wide.end, .zero) > 13.9)
    // A wall beside the target catches the stray shot.
    let wall = PartyMotion.Box(minimum: [-3, -12], maximum: [3, -11])
    let walled = Aim.scattered(
      aimed, by: Spread.degrees(-4), range: 14, hostiles: [target], blockers: [wall])
    #expect(walled.strike == .scenery)
    // A stranger beside the target, where the stray shot would go, is never hit by it: it
    // keeps to the aim.
    let stranger = Aim.Hostile(id: "stranger", position: [-0.7, -10], isTarget: false)
    let kept = Aim.scattered(
      aimed, by: Spread.degrees(-4), range: 14, hostiles: [target, stranger], blockers: [])
    #expect(kept == aimed)
  }

  // MARK: - Enemies react

  @Test
  func aHitDuringAWindUpDelaysTheShotUpToALimit() throws {
    var state = HostileState(spec: CombatYard.rightShooter)
    state.engage()
    let windUp = CombatYard.rightShooter.windUp
    #expect(state.phase == .aiming(remaining: windUp))
    state.flinch()
    #expect(state.phase == .aiming(remaining: windUp + HostileState.flinchDelay))
    for _ in 0..<5 { state.flinch() }
    #expect(state.phase == .aiming(remaining: windUp + HostileState.flinchLimit))
    // Out of a wind-up, a hit delays nothing.
    var shot: HostileState.Shot?
    for _ in 0..<400 where shot == nil {
      shot = state.step(dt: 1 / 120, canHit: true, toward: .zero)
    }
    #expect(shot == .hit)
    let recovering = state.phase
    state.flinch()
    #expect(state.phase == recovering)
    // The next wind-up can be delayed afresh.
    for _ in 0..<400 {
      if case .aiming = state.phase { break }
      _ = state.step(dt: 1 / 120, canHit: true, toward: .zero)
    }
    guard case .aiming(let remaining) = state.phase else {
      Issue.record("no second wind-up")
      return
    }
    state.flinch()
    #expect(state.phase == .aiming(remaining: remaining + HostileState.flinchDelay))
  }

  @Test
  func aJoltRocksAFigureAboutItsFeetAndSettles() {
    var jolt = BodyJolt()
    #expect(jolt.isSettled)
    jolt.push(towards: [1, 0], by: BodyJolt.hit)
    let pose = jolt.pose(height: PartyBody.height)
    // Its top moves the way it was pushed, and its feet stay where they stand.
    let top = pose.tilt.act([0, PartyBody.height / 2, 0]) + pose.offset
    let feet = pose.tilt.act([0, -PartyBody.height / 2, 0]) + pose.offset
    #expect(top.x > 0.1)
    #expect(simd_distance(feet, [0, -PartyBody.height / 2, 0]) < 0.0001)
    // However many shots land together, it leans only so far.
    for _ in 0..<10 { jolt.push(towards: [1, 0], by: BodyJolt.hit) }
    #expect(abs(simd_length(jolt.lean) - BodyJolt.most) < 0.0001)
    for _ in 0..<120 { jolt.settle(dt: 1 / 120) }
    #expect(jolt.isSettled)
  }

  @Test
  func aDownedHostileFallsAwayFromTheShotOverAMoment() {
    var fall = Fall(away: [0, -1], yaw: 0)
    #expect(fall.pose.orientation.act([0, 1, 0]).y > 0.999)
    fall.advance(dt: Fall.duration / 2)
    let halfway = fall.pose.orientation.act([0, 1, 0])
    #expect(halfway.y < 0.999 && halfway.y > 0.5)
    fall.advance(dt: Fall.duration)
    #expect(fall.isFinished)
    // Lying, its head points away from whoever shot it, and it lies on the ground.
    let head = fall.pose.orientation.act([0, 1, 0])
    #expect(simd_distance(head, [0, 0, -1]) < 0.001)
    #expect(abs(fall.pose.position.y + Fall.drop) < 0.0001)
  }

  // MARK: - The pose shows the aim

  @Test
  func theCarbineRisesToAimAndLowersAWhileAfterAndAShotKicksIt() {
    var pose = WeaponPose()
    #expect(pose.raise == 0 && simd_distance(pose.transform.position, WeaponPose.lowGrip) < 0.0001)
    // Held low, the barrel points down and across the body.
    let lowBarrel = pose.transform.orientation.act([0, 0, -1])
    #expect(lowBarrel.y < -0.5 && lowBarrel.x < 0)
    for _ in 0..<13 { pose.step(dt: 1 / 120, aiming: true) }
    #expect(pose.raise == 1)
    #expect(simd_distance(pose.transform.orientation.act([0, 0, -1]), [0, 0, -1]) < 0.0001)
    // It stays up a while after the aim lets go, then lowers.
    for _ in 0..<Int(WeaponPose.holdTime * 120) - 1 { pose.step(dt: 1 / 120, aiming: false) }
    #expect(pose.raise == 1)
    for _ in 0..<Int((WeaponPose.lowerTime + 0.05) * 120) { pose.step(dt: 1 / 120, aiming: false) }
    #expect(pose.raise == 0)
    // A shot raises it at once and kicks the muzzle up and the grip back.
    pose.fired()
    let kicked = pose.transform
    #expect(pose.raise == 1 && kicked.orientation.act([0, 0, -1]).y > 0.1)
    #expect(kicked.position.z > WeaponPose.raisedGrip.z + 0.05)
    for _ in 0..<36 { pose.step(dt: 1 / 120, aiming: false) }
    #expect(pose.kick == 0)
    // The muzzle is ahead of the figure and to its right, where the leader's shots start.
    let muzzle = WeaponPose.muzzle(from: .zero, facing: [0, -1])
    #expect(
      simd_distance(muzzle, [WeaponPose.raisedGrip.x, WeaponPose.raisedGrip.z - WeaponPose.barrel])
        < 0.0001)
  }

  @Test
  func noLineShowsTheLeadersAim() {
    let world = GameWorld(level: SalvageYard.level)
    run(world, upTo: 0.5, aim: stick(world, towards: [1, 0]))
    #expect(world.weaponDrawn)
    #expect(world.root.findEntity(named: "leader.aim") == nil)
    let carbine = world.root.findEntity(named: "leader.carbine")
    #expect(carbine?.isEnabled == true)
  }

  @Test
  func theLeaderTurnsTowardsHerAimAtALimitedRate() {
    let world = GameWorld(level: SalvageYard.level)
    let start = world.facing(of: .miki)
    let behind = stick(world, towards: -start)
    // Two full turns a second: a half turn takes a quarter of a second, never a frame.
    run(world, upTo: 6 / 60, aim: behind)
    #expect(simd_dot(world.facing(of: .miki), -start) < 0.5)
    run(world, upTo: 0.25, aim: behind)
    #expect(simd_distance(world.facing(of: .miki), -start) < 0.01)
  }

  @Test
  func onTouchFireTurnsMikiToTheTargetBeforeSheShoots() throws {
    // One shooter in the open ahead of Miki; the companions hold where they stand.
    let world = GameWorld(level: range(shooterAt: [0, -6], hits: 50))
    #expect(world.session.holdAll())
    #expect(run(world, upTo: 1) { world.threat != nil })
    // The stick draws her carbine while she faces away from the shooter, then lets go.
    run(world, upTo: 0.6, aim: stick(world, towards: [0, 1]))
    #expect(world.weaponDrawn && simd_dot(world.facing(of: .miki), [0, 1]) > 0.99)
    let ammo = world.session.ammo
    // Fire alone turns her round first: no shot leaves while she faces away.
    run(world, upTo: 6 / 60, fire: true)
    #expect(world.session.ammo == ammo)
    #expect(run(world, upTo: 0.5, fire: true) { world.session.ammo < ammo })
    #expect(simd_dot(world.facing(of: .miki), [0, 1]) < 0)
  }

  // MARK: - Events: what is heard and felt

  @Test
  func aShotOutsideAFightIsHeardAndStrikesTheGate() {
    let world = GameWorld(level: SalvageYard.level)
    var events: [CombatEvent] = []
    run(world, upTo: 1.2, fire: true, aim: stick(world, towards: [0, -1])) {
      events += world.takeCombatEvents()
      return false
    }
    #expect(events.contains { if case .fired(.carbine, _, true) = $0 { true } else { false } })
    #expect(events.contains { if case .struckBlock = $0 { true } else { false } })
    #expect(!events.contains { if case .leaderHit = $0 { true } else { false } })
  }

  @Test
  func aFightIsHeardFromEveryWeapon() {
    // A shooter close enough for Tom's scatter weapon, with the companions beside Miki.
    let world = GameWorld(level: range(shooterAt: [0, -2.5], hits: 50))
    var events: [CombatEvent] = []
    run(world, upTo: 4) {
      events += world.takeCombatEvents()
      return false
    }
    for kind in [Weapon.Kind.rifle, .lightBurst, .closeScatter] {
      #expect(events.contains { $0 == .fired(kind, at: $0.position, byLeader: false) }, "\(kind)")
    }
    #expect(events.contains { if case .struckBody = $0 { true } else { false } })
  }

  @Test
  func theStrangersHitOnTheLeaderIsFelt() {
    let world = GameWorld(level: BrooklynBridge.level)
    walk(world, to: [6.5, 15])
    var events: [CombatEvent] = []
    let hit = run(world, upTo: 10) {
      events += world.takeCombatEvents()
      return events.contains { if case .leaderHit = $0 { true } else { false } }
    }
    #expect(hit)
    #expect(events.contains { if case .fired(.rifle, _, false) = $0 { true } else { false } })
  }

  @Test
  func aHostileHitRocksAndOneDownedFallsOverAMoment() throws {
    // A shooter that takes three hits, ahead of Miki; the companions hold where they stand.
    let world = GameWorld(level: range(shooterAt: [0, -6], hits: 3))
    #expect(world.session.holdAll())
    let visual = try #require(world.root.findEntity(named: "hostile.a")?.children.first)
    func upright() -> Float { visual.orientation.act([0, 1, 0]).y }
    // Aimed at it, the first hit leans it over.
    let atIt = stick(world, towards: [0, -1])
    var leaned: Float = 1
    run(world, upTo: 4, fire: true, aim: atIt) {
      leaned = min(leaned, upright())
      return world.session.defeated.contains("a")
    }
    #expect(leaned < 0.999)
    #expect(world.session.defeated.contains("a"))
    // Once down, it falls over a moment, not at once, and ends lying.
    #expect(upright() > 0.1)
    run(world, upTo: 0.5, aim: atIt)
    #expect(abs(upright()) < 0.05)
  }

  @Test
  func eachEventHasItsSoundAndTheLeadersOwnAVibration() {
    let point = SIMD2<Float>(1, 2)
    #expect(CombatSound.of(.fired(.carbine, at: point, byLeader: true)) == .carbine)
    #expect(CombatSound.of(.fired(.lightBurst, at: point, byLeader: false)) == .lightBurst)
    #expect(CombatSound.of(.fired(.closeScatter, at: point, byLeader: false)) == .closeScatter)
    #expect(CombatSound.of(.fired(.rifle, at: point, byLeader: false)) == .rifle)
    #expect(CombatSound.of(.struckBody(at: point)) == .strikeBody)
    #expect(CombatSound.of(.struckBlock(at: point)) == .strikeBlock)
    #expect(CombatSound.of(.empty(at: point)) == .emptyClick)
    #expect(CombatSound.of(.leaderHit(at: point)) == nil)
    #expect(HapticCue.of(.fired(.carbine, at: point, byLeader: true)) == .carbineShot)
    #expect(HapticCue.of(.fired(.carbine, at: point, byLeader: false)) == nil)
    #expect(HapticCue.of(.fired(.rifle, at: point, byLeader: false)) == nil)
    #expect(HapticCue.of(.leaderHit(at: point)) == .leaderHit)
    #expect(HapticCue.of(.empty(at: point)) == .emptyClick)
    #expect(HapticCue.of(.struckBody(at: point)) == nil)
    for cue in HapticCue.allCases { #expect((try? cue.pattern()) != nil) }
  }

  @Test
  func everySoundIsInTheAppAsShortMonoAudio() throws {
    for sound in CombatSound.allCases {
      let url = try #require(sound.url, "\(sound.rawValue).wav is not in the app")
      let file = try AVAudioFile(forReading: url)
      #expect(file.fileFormat.channelCount == 1 && file.fileFormat.sampleRate == 44100)
      let seconds = Double(file.length) / file.fileFormat.sampleRate
      #expect(seconds > 0.05 && seconds < 1.5, "\(sound.rawValue) lasts \(seconds) s")
    }
  }

  @Test
  func aSoundPansAcrossTheScreenAndQuietensWithDistance() {
    let right = SIMD2<Float>(1, 0)
    let here = CombatAudio.mix(at: .zero, listener: .zero, right: right)
    #expect(here.pan == 0 && here.volume == 1)
    let aside = CombatAudio.mix(at: [6, 0], listener: .zero, right: right)
    #expect(aside.pan > 0.4 && aside.volume < 1)
    let left = CombatAudio.mix(at: [-30, 0], listener: .zero, right: right)
    #expect(left.pan == -1)
    let far = CombatAudio.mix(at: [0, -200], listener: .zero, right: right)
    #expect(far.pan == 0 && far.volume == CombatAudio.quietest)
  }

  // MARK: - The switch

  @Test
  func thePauseMenusVibrationChoiceTurnsItOffAndOnAndCarriesOver() {
    let world = GameWorld(level: BrooklynBridge.level)
    #expect(world.vibrationEnabled)
    pressPause(world)
    for _ in 0..<3 { world.session.movePauseChoice(by: 1) }
    #expect(world.session.pauseChoice == .vibration)
    let confirm = InputRules.Input(
      movement: .zero, actionPressed: true, pausePressed: false, switchPressed: false)
    world.update(with: confirm, sampledIn: .paused, deltaTime: 1 / 60)
    #expect(!world.vibrationEnabled && world.isPaused)
    let other = GameWorld(level: CombatYard.level)
    other.takePreferences(from: world)
    #expect(!other.vibrationEnabled)
    world.update(with: confirm, sampledIn: .paused, deltaTime: 1 / 60)
    #expect(world.vibrationEnabled)
  }

  /// A small open range with the combat yard's rules: Miki in the open with the companions just
  /// behind her, and one shooter, "a", in the open, which fights at once.
  private func range(shooterAt point: SIMD2<Float>, hits: Int) -> Level {
    let shooter = Level.Hostile(
      id: "a", name: "Shooter A", hiddenAt: point, standAt: point, hits: hits, windUp: 1.5,
      recovery: 1.4, range: 14, inView: true, targetsAnyone: true, targetFromWindUp: true)
    let fight = Level.Encounter(
      beat: .stranger, start: .area(PartyMotion.Box(minimum: [-15, -15], maximum: [15, 15])),
      retryAt: [0, 2], hostiles: [shooter], cues: [(at: 0, cue: .engage("a"))])
    return Level(
      id: "test-range",
      ground: Level.Box(name: "ground", position: [0, -0.15, 0], size: [40, 0.3, 40]),
      boxes: [], interactions: [], triggers: [], encounters: [fight], startingAmmo: 60,
      party: [.miki, .tom, .laura], spawns: [.miki: [0, 2], .tom: [-1, 3], .laura: [1, 3]],
      heading: [0, -1], cameraOffset: CombatYard.level.cameraOffset,
      fieldOfView: CombatYard.level.fieldOfView, opening: "A range.", objective: "Test.",
      lookAround: "Snow.", restartNote: "Restart.", combat: CombatYard.combat)
  }
}
