import Testing
import simd

@testable import Lauder

/// Native companion contacts, geometry and ordinary session transitions exercise target
/// ownership. No test writes targeting policy, component progress, HP, ammunition or timers.
@MainActor
struct GuardRetaliationTests {
  @Test
  func aRealCompanionContactEarnsTheNextNamedWarning() throws {
    let trial = try Trial()
    try trial.awaitMikiWarning()
    #expect(
      trial.partyShots.contains { $0.actor == .miki && $0.path.strike == .body("guard.sensor.0") })
    #expect(trial.fight.guardStrategies["guard"]?.sensorDisabled == true)
    #expect(trial.fight.guardStrategies["guard"]?.couplingBreached == false)
    #expect(trial.warned.prefix(2).elementsEqual([.tom, .miki]))
    #expect(trial.warned.filter { $0 == .miki }.count == 1)
    #expect(trial.fight.guardTarget(for: "guard") == .miki)
    #expect(trial.fight.threat?.contains(PartyMember.miki.displayName) == true)
    #expect(!trial.retried)
  }

  @Test
  func switchingAndDefendCannotTransferTheWarnedActorOrCommittedPoint() throws {
    let trial = try Trial()
    try trial.awaitMikiWarning()
    let loaded = trial.fight.status(for: .miki).loaded
    trial.session.cycleLeader()
    trial.step()
    #expect(trial.fight.guardTarget(for: "guard") == .miki)
    trial.session.cycleLeader()
    trial.session.setCombatStance(.defend)
    #expect(trial.session.leader == .laura)
    for _ in 0..<120 * 8 {
      trial.step()
      #expect(trial.fight.guardTarget(for: "guard") == .miki)
      if trial.robot?.phase == .committed { break }
    }
    try #require(trial.robot?.phase == .committed)
    let committed = try #require(trial.robot?.committedPoint)
    var sawBurst = false
    var sawRecovery = false
    for _ in 0..<240 {
      // A continuous legal-speed displacement is a new observed target position, not a
      // mutation of the robot's committed point or its chosen actor.
      trial.figures[.miki, default: .zero] += [PartyBody.speed / 120, 0]
      trial.step()
      #expect(trial.fight.guardTarget(for: "guard") == .miki)
      #expect(trial.robot?.committedPoint == committed)
      #expect(!trial.fight.shots.contains { $0.actor == .miki })
      sawBurst = sawBurst || trial.robot?.phase == .burst
      sawRecovery = sawRecovery || trial.robot?.phase == .recovering
    }
    #expect(sawBurst && sawRecovery)
    #expect(trial.fight.status(for: .miki).loaded == loaded)
    #expect(trial.warned.filter { $0 == .miki }.count == 1)
    #expect(trial.fight.guardStrategies["guard"]?.reactorDamage == 0 && !trial.retried)
  }

  @Test
  func unfiredIntentAndDefaultDefendDoNotManufactureAnAttackingCompanion() throws {
    for attack in [false, true] {
      let trial = try Trial(attack: attack)
      for _ in 0..<120 * 10 { trial.step(companionFire: !attack) }
      #expect(trial.partyShots.isEmpty)
      #expect(!trial.warned.contains(.miki))
      #expect(trial.warned.allSatisfy { $0 == .tom })
      #expect(trial.fight.guardStrategies["guard"]?.sensorDisabled == false)
      #expect(!trial.retried)
    }
  }

  @Test
  func aRealAttackBehindLowCoverDoesNotMakeAnUnseenCompanionEligible() throws {
    let wall = Level.Box.box("low-screen", at: [0, 0.725, 3], size: [1.5, 1.45, 0.4])
    let trial = try Trial(
      boxes: [wall], figures: [.tom: [6, 6], .miki: [0, 6], .laura: [-6, 6]])
    for _ in 0..<120 * 15 {
      trial.step(companionFire: true)
      if trial.fight.guardStrategies["guard"]?.sensorDisabled == true,
        trial.warned.count >= 2
      {
        break
      }
    }
    #expect(
      trial.partyShots.contains { $0.actor == .miki && $0.path.strike == .body("guard.sensor.0") })
    #expect(trial.fight.guardStrategies["guard"]?.sensorDisabled == true)
    #expect(trial.warned.count >= 2 && !trial.warned.contains(.miki))
    #expect(trial.warned.allSatisfy { $0 == .tom } && !trial.retried)
  }

  @Test
  func aContinuouslyFiringCompanionBeyondAttackRangeCannotPinTheGuardAwayFromTheLeader() throws {
    let trial = try Trial(figures: [.tom: [4, 7], .miki: [0, 13.5], .laura: [-6, 6]])
    for _ in 0..<120 * 14 { trial.step(ordinaryCompanionFire: true) }
    let robot = try #require(trial.robot)
    let strategy = try #require(trial.fight.guardStrategies["guard"])
    let miki = try #require(trial.figures[.miki])
    #expect(trial.partyShots.filter { $0.actor == .miki }.count >= 8)
    #expect(strategy.health < GuardStrategy.maximumHealth)
    #expect(simd_distance(miki, robot.position) > RobotGuard.attackRange)
    #expect(trial.warned.count >= 2 && trial.warned.allSatisfy { $0 == .tom })
    #expect(robot.shotSerial >= 8 && !trial.retried)
  }

  @Test
  func aFiringLeaderAtThirteenMetresGetsNoRepeatedFalseWarnings() throws {
    let trial = try Trial(
      attack: false, figures: [.tom: [0, 13], .miki: [-8, 13], .laura: [8, 13]])
    for _ in 0..<120 * 30 {
      let robot = try #require(trial.robot)
      // Follow the guard's bounded walking at its slow speed, remaining 13 m away. Fire
      // outwards so real native discharges cannot finish the guard during this observation.
      trial.figures[.tom] = robot.position + [0, 13]
      trial.step(leaderFire: true, leaderFacing: [0, 1])
    }
    #expect(trial.partyShots.filter { $0.actor == .tom }.count > 100)
    #expect(trial.warned == [.tom])
    #expect(trial.robot?.shotSerial == 0 && !trial.retried)
    var remaining: Float = 13
    for _ in 0..<120 * 4 {
      let robot = try #require(trial.robot)
      remaining = max(8, remaining - (PartyBody.speed - RobotGuard.speed) / 120)
      trial.figures[.tom] = robot.position + [0, remaining]
      trial.step(leaderFire: true, leaderFacing: [0, 1])
      if trial.warned.count == 2 { break }
    }
    try #require(trial.warned == [.tom, .tom] && trial.robot?.phase == .notice)
    var elapsed: Float = 0
    for _ in 0..<120 * 5 where trial.robot?.shotSerial == 0 {
      trial.step(leaderFire: true, leaderFacing: [0, 1])
      elapsed += 1 / 120
    }
    #expect(trial.robot?.shotSerial == 1)
    #expect(
      elapsed >= RobotGuard.noticeTime + RobotGuard.trackingTime + RobotGuard.commitTime - 0.02)
  }

  @Test
  func aWarnedCompanionMovingBeyondAttackRangeKeepsTheWarningThenReleasesAcquisition() throws {
    let trial = try Trial(figures: [.tom: [4, 7], .miki: [0, 11.9], .laura: [-6, 6]])
    try trial.awaitMikiWarning()
    let warned = try #require(trial.robot)
    let shotsBefore = warned.shotSerial
    var elapsed: Float = 0
    var trackedOutsideRange = false
    for _ in 0..<120 * 6 {
      let before = try #require(trial.robot)
      if let point = trial.figures[.miki],
        simd_distance(point, before.position) < 13
      {
        trial.figures[.miki] = point + [0, PartyBody.speed / 120]
      }
      trial.step(ordinaryCompanionFire: true)
      elapsed += 1 / 120
      let current = try #require(trial.robot)
      let position = try #require(trial.figures[.miki])
      if current.phase == .searching { break }
      #expect(trial.fight.guardTarget(for: "guard") == .miki)
      #expect(current.shotSerial == shotsBefore && current.committedPoint == nil)
      if current.phase == .tracking,
        simd_distance(position, current.position) > RobotGuard.attackRange
      {
        trackedOutsideRange = true
      }
    }
    let searching = try #require(trial.robot)
    #expect(trackedOutsideRange && searching.phase == .searching)
    #expect(elapsed >= RobotGuard.noticeTime + warned.pattern.trackingTime - 0.02)
    #expect(searching.shotSerial == shotsBefore && searching.committedPoint == nil)
    // Continuous native fire outside range cannot immediately win the next acquisition.
    trial.step(ordinaryCompanionFire: true)
    #expect(trial.robot?.phase == .notice)
    #expect(trial.fight.guardTarget(for: "guard") == .tom && trial.warned.last == .tom)
    for _ in 0..<120 * 8 {
      trial.step(ordinaryCompanionFire: true)
      if let count = trial.robot?.shotSerial, count > shotsBefore { break }
    }
    #expect(try #require(trial.robot).shotSerial > shotsBefore && !trial.retried)
  }

  @Test
  func pauseFreezesTheWarningAndBypassOrRetryClearsItsTargetMemory() throws {
    let trial = try Trial()
    try trial.awaitMikiWarning()
    let elapsed = try #require(trial.robot?.elapsed)
    let warned = trial.warned
    trial.session.togglePause()
    for _ in 0..<240 { trial.step() }
    #expect(trial.robot?.elapsed == elapsed && trial.warned == warned)
    #expect(trial.fight.guardTarget(for: "guard") == .miki)
    trial.session.togglePause()
    #expect(trial.fight.resolveRobotBypass(id: "guard", session: trial.session))
    #expect(trial.fight.guardTarget(for: "guard") == nil && trial.fight.guardTarget == nil)
    for _ in 0..<120 {
      trial.step()
      #expect(trial.fight.shots.isEmpty)
    }
    #expect(trial.warned == warned && trial.session.defeated.isEmpty)

    let retry = try Trial()
    try retry.awaitMikiWarning()
    retry.session.retryEncounter()
    retry.fight.reset()
    #expect(retry.fight.guardTarget(for: "guard") == nil && retry.fight.guardTarget == nil)
    #expect(retry.fight.guardStrategies["guard"]?.sensorDisabled == false)
    try retry.begin()
    let before = retry.warned.count
    for _ in 0..<120 * 3 {
      retry.step()
      if retry.warned.count > before { break }
    }
    #expect(retry.warned.last == .tom)
  }

  @MainActor
  private final class Trial {
    let session: GameSession
    let fight: EncounterSimulation
    var figures: [PartyMember: SIMD2<Float>]
    private let encounter: Level.Encounter
    private(set) var partyShots: [EncounterSimulation.Shot] = []
    private(set) var warned: [PartyMember] = []
    private(set) var retried = false
    var robot: RobotGuard? { fight.hostiles["guard"]?.robot }

    init(
      attack: Bool = true, boxes: [Level.Box] = [],
      figures: [PartyMember: SIMD2<Float>] = [.tom: [0, 8], .miki: [1.4, 6], .laura: [-6, 6]]
    ) throws {
      self.figures = figures
      let hostile = Level.Hostile(
        id: "guard", name: "Guard", hiddenAt: .zero, standAt: .zero, hits: 6,
        attack: .robot, strategicGuard: true, range: 12)
      encounter = Level.Encounter(
        beat: .stranger, start: .area(.init(minimum: [-20, -20], maximum: [20, 20])),
        retryAt: [0, 12], hostiles: [hostile],
        cues: [(0, .reveal("guard")), (0, .engage("guard"))])
      let level = Level(
        id: "retaliation-range", ground: .box("floor", at: [0, -0.15, 0], size: [60, 0.3, 60]),
        boxes: boxes, triggers: [], encounters: [encounter], party: [.tom, .miki, .laura],
        spawns: figures, heading: [0, -1], cameraOffset: BrooklynBridge.cameraOffset,
        fieldOfView: 22, opening: "Range", objective: "Test", lookAround: "Range",
        restartNote: "Restart")
      session = GameSession(level: level)
      if attack { session.setCombatStance(.attack) }
      fight = EncounterSimulation(level: level)
      try begin()
      step()
    }

    func begin() throws {
      try #require(session.beginEncounter(encounter.beat))
      fight.begin(encounter)
    }

    func awaitMikiWarning() throws {
      for _ in 0..<120 * 20 {
        step(companionFire: true)
        if fight.guardTarget == .miki, robot?.phase == .notice { return }
      }
      Issue.record("a real sensor shot did not produce a later visible Miki warning")
      throw FixtureFailure.missingWarning
    }

    func step(
      companionFire: Bool = false, ordinaryCompanionFire: Bool = false,
      leaderFire: Bool = false, leaderFacing: SIMD2<Float> = [0, -1]
    ) {
      let leader = figures[session.leader] ?? .zero
      let point = fight.weakpoints(for: "guard").first
      let target = ordinaryCompanionFire ? robot?.position ?? .zero : point?.ground ?? .zero
      let miki = figures[.miki] ?? .zero
      let direction = target - miki
      let outcome = fight.step(
        dt: 1 / 120, leader: leader, facing: leaderFacing, aiming: leaderFire,
        fireHeld: leaderFire, firePressed: false, figures: figures, session: session,
        companionIntents: [
          .miki: .init(
            lookAt: target, weapon: .longRifle,
            targetsBody: ordinaryCompanionFire,
            fire: ordinaryCompanionFire
              || (companionFire && point?.part == .sensor && point?.exposed == true),
            activity: .attacking)
        ], facings: [.miki: simd_length(direction) > 0.001 ? simd_normalize(direction) : [0, -1]])
      retried = retried || outcome.retry
      partyShots += fight.shots.filter { $0.actor != nil }
      for event in fight.takeEvents() {
        if case .guardTargeted(let member, _) = event { warned.append(member) }
      }
    }
  }

  private enum FixtureFailure: Error { case missingWarning }
}
