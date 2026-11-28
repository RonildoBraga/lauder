import Testing
import simd

@testable import Lauder

/// Native contact tests isolate incoming injuries, never outgoing contact, health, cadence or
/// part progress. Rendered routes separately exercise survival and ordinary shared inputs.
@MainActor
struct StrategicGuardIntegrationTests {
  @Test(arguments: [Weapon.Kind.longRifle, .assaultRifle, .shotgun, .minigun])
  func eachGunCanCriticallyHitTheActualEyeRepeatedlyWithoutAStageWindow(kind: Weapon.Kind) throws {
    let trial = try Trial()
    for _ in 0..<120 * 20 {
      trial.step(weapon: kind, front: true)
      if trial.hits.filter({ $0.effectiveness == .weakpoint }).count >= 2 { break }
    }
    let criticals = trial.hits.filter { $0.effectiveness == .weakpoint }
    #expect(criticals.count >= 2)
    #expect(criticals.allSatisfy { $0.weapon == kind && !$0.brokeComponent })
    #expect(trial.strategy.detachedLegs.isEmpty)
    #expect(trial.strategy.phase == .active)
    #expect(trial.hits.allSatisfy { $0.amount > 0 })
    #expect(
      trial.hits.reduce(0) { $0 + $1.amount } == GuardStrategy.maximumHealth - trial.strategy.health
    )
  }

  @Test(arguments: [Weapon.Kind.longRifle, .assaultRifle, .shotgun, .energySword, .minigun])
  func everyWeaponCanStillWinThroughRealOrdinaryBodyContacts(kind: Weapon.Kind) throws {
    let trial = try Trial()
    for _ in 0..<120 * 100 where trial.strategy.phase != .complete {
      trial.step(weapon: kind, front: false)
    }
    #expect(trial.strategy.health == 0 && trial.session.defeated == [Trial.id])
    #expect(trial.hits.reduce(0) { $0 + $1.amount } == GuardStrategy.maximumHealth)
    #expect(trial.hits.allSatisfy { $0.weapon == kind && $0.effectiveness == .normal })
    #expect(trial.fight.hostiles[Trial.id]?.isDown == true)
    #expect(trial.fight.weakpoints(for: Trial.id).isEmpty)
  }

  @Test
  func threeNativeSwordContactsRemoveOnlyThatLegAndThreeMoreCanRemoveAnother() throws {
    let trial = try Trial()
    for leg in [0, 2] {
      let before = trial.hits.count
      for _ in 0..<120 * 8 {
        trial.step(weapon: .energySword, leg: leg)
        if trial.strategy.detachedLegs.contains(leg) { break }
      }
      #expect(trial.strategy.detachedLegs.contains(leg))
      #expect(trial.strategy.swordHits[leg] == 3)
      #expect(trial.hits.count - before == 3)
      #expect(trial.robot?.phase == .staggered && trial.robot?.committedPoint == nil)
      #expect(trial.legBreaks.count == trial.strategy.detachedLegs.count)
      #expect(!trial.fight.weakpoints(for: Trial.id).contains { $0.part == .leg(leg) })
    }
    #expect(trial.strategy.detachedLegs == [0, 2] && trial.strategy.speedMultiplier == 0.5)
    #expect(trial.hits.filter(\.brokeComponent).count == 2)
    #expect(
      trial.hits.allSatisfy {
        $0.effectiveness == .normal && $0.amount == Weapon.energySword.damage
      })
    #expect(trial.strategy.health == GuardStrategy.maximumHealth - 6 * Weapon.energySword.damage)
  }

  @Test
  func onlyTheThirdNonlethalSwordContactStartsOneStaggerAndPauseDoesNotReplayIt() throws {
    let trial = try Trial()
    for wanted in 1...3 {
      for _ in 0..<120 * 5 {
        trial.step(weapon: .energySword, leg: 0)
        if trial.hits.count == wanted { break }
      }
      try #require(trial.hits.count == wanted)
      #expect(trial.legBreaks.count == (wanted == 3 ? 1 : 0))
      #expect((trial.robot?.phase == .staggered) == (wanted == 3))
    }
    let before = try #require(trial.robot)
    #expect(trial.fight.guardTarget == nil)
    trial.session.togglePause()
    for _ in 0..<120 { trial.step(weapon: .energySword, leg: 0) }
    #expect(trial.robot?.elapsed == before.elapsed && trial.robot?.phase == .staggered)
    #expect(trial.legBreaks.count == 1 && trial.hits.count == 3)
    trial.session.togglePause()
    // Ordinary gun contacts remain useful through the opening; they cannot restart it.
    for _ in 0..<120 * 3 {
      trial.step(weapon: .minigun, front: false)
      if trial.hits.count > 3 { break }
    }
    #expect(trial.hits.count > 3 && trial.legBreaks.count == 1)
    #expect(trial.strategy.detachedLegs == [0])
    trial.fight.reset()
    #expect(trial.strategy == GuardStrategy() && trial.robot?.phase == .hidden)
  }

  @Test
  func aLethalThirdLegContactDefeatsInsteadOfStartingAReaction() throws {
    let trial = try Trial()
    for _ in 0..<120 * 8 {
      trial.step(weapon: .energySword, leg: 0)
      if trial.strategy.swordHits[0] == 2 { break }
    }
    try #require(trial.strategy.swordHits[0] == 2 && trial.legBreaks.isEmpty)
    for _ in 0..<120 * 80 {
      trial.step(weapon: .minigun, front: false)
      if trial.strategy.health <= Weapon.energySword.damage { break }
    }
    try #require(trial.strategy.health > 0 && trial.strategy.health <= Weapon.energySword.damage)
    for _ in 0..<120 * 5 {
      trial.step(weapon: .energySword, leg: 0)
      if trial.strategy.phase == .complete { break }
    }
    #expect(trial.strategy.health == 0 && trial.strategy.detachedLegs == [0])
    #expect(trial.hits.last?.brokeComponent == true && trial.legBreaks.isEmpty)
    #expect(trial.robot?.phase == .down && trial.session.defeated == [Trial.id])
  }

  @Test
  func nativeSwordLegLossAlsoReducesTheRealHostilesTurnRate() throws {
    let trial = try Trial()
    let rates: [Float] = [0.52, 0.32, 0.16, 0.08]
    for leg in 0..<4 {
      for _ in 0..<120 * 8 {
        trial.step(weapon: .energySword, leg: leg)
        if trial.strategy.detachedLegs.contains(leg) { break }
      }
      try #require(trial.strategy.detachedLegs.count == leg + 1)
      var peak: Float = 0
      for _ in 0..<120 * 20 {
        let before = try #require(trial.robot)
        let flank = before.position + SIMD2(-before.facing.y, before.facing.x) * 8
        trial.step(weapon: .energySword, fire: false, fixedOrigin: flank)
        let after = try #require(trial.robot)
        let angle = abs(
          (Movement.yaw(towards: after.facing) - Movement.yaw(towards: before.facing))
            .remainder(dividingBy: 2 * .pi))
        let rate = angle * 120
        #expect(rate <= rates[leg] + 0.0001)
        #expect(
          simd_distance(before.position, after.position)
            <= RobotGuard.speed * trial.strategy.speedMultiplier / 120 + 0.00001)
        peak = max(peak, rate)
      }
      #expect(peak > rates[leg] * 0.9, "The real encounter must still permit a bounded pivot")
    }
    trial.fight.reset()
    #expect(trial.strategy.turnMultiplier == 1 && trial.strategy.speedMultiplier == 1)
  }

  @Test
  func sceneryBlocksAnEyeLockAndCreatesNoCriticalOrDamageEvent() throws {
    let wall = Level.Box.box("wall", at: [0, 1.5, 3], size: [8, 3, 0.5])
    let trial = try Trial(boxes: [wall])
    trial.fight.selectLock(
      from: [0, 6], facing: [0, -1], up: [0, -1], right: [1, 0], advancing: false)
    // The ordinary contact fixture follows the robot's front. Here the shooter must remain
    // behind the actual wall while the blocked guard turns and patrols on its other side.
    for _ in 0..<120 * 3 { trial.step(weapon: .longRifle, fixedOrigin: [0, 6]) }
    #expect(!trial.shots.isEmpty && trial.shots.allSatisfy { $0.path.strike == .scenery })
    #expect(trial.shots.allSatisfy { $0.path.start == [0, 6] })
    #expect(trial.hits.isEmpty && trial.strategy.health == GuardStrategy.maximumHealth)
  }

  @Test
  func theEyeRefinementCannotPassAnAllyAnotherEnemyOrTheBackOfTheHull() throws {
    let trial = try Trial()
    let eye = try #require(trial.fight.weakpoints(for: Trial.id).first { $0.part == .eye })
    let robot = try #require(trial.robot)
    let start = SIMD3<Float>(0, 1.25, 6)
    let body = Ballistics.Target(
      id: Trial.id, centre: [0, RobotModelGeometry.halfHeight, 0],
      halfHeight: RobotModelGeometry.halfHeight, radius: RobotModelGeometry.bodyRadius)
    let targets = [body, eye.target]
    let clear = trial.fight.traceCombat(
      from: start, direction: eye.centre - start, targets: targets)
    #expect(clear.strike == .body(eye.id))
    let side = SIMD2(-robot.facing.y, robot.facing.x)
    // A clear oblique contact within 60° of the guard's facing still finds the eye. From
    // further round, where the recessed eye can't be seen, the body takes the hit (#200).
    for (ahead, across, struck) in [(Float(6), Float(4), eye.id), (3, 8, Trial.id)] {
      let obliqueGround = robot.position + robot.facing * ahead + side * across
      let oblique = SIMD3(obliqueGround.x, 1.25, obliqueGround.y)
      #expect(
        trial.fight.traceCombat(
          from: oblique, direction: eye.centre - oblique, targets: targets
        ).strike == .body(struck))
    }
    for id in ["ally.laura", "other-enemy"] {
      let blocker = Ballistics.Target(id: id, centre: [0, 1.4, 3])
      let stopped = trial.fight.traceCombat(
        from: start, direction: eye.centre - start, targets: targets + [blocker])
      #expect(stopped.strike == .body(id))
    }
    let behind = SIMD3<Float>(-robot.facing.x * 6, 1.25, -robot.facing.y * 6)
    let rear = trial.fight.traceCombat(
      from: behind, direction: eye.centre - behind, targets: targets)
    #expect(rear.strike == .body(Trial.id))
  }

  @Test
  func pauseAndRetreatPreserveEyeLegProgressWhileResetRestoresEveryLeg() throws {
    let trial = try Trial()
    for _ in 0..<120 * 8 {
      trial.step(weapon: .energySword, leg: 1)
      if trial.strategy.detachedLegs.contains(1) { break }
    }
    try #require(trial.strategy.detachedLegs == [1])
    let before = trial.strategy
    trial.session.togglePause()
    for _ in 0..<120 { trial.step(weapon: .energySword, leg: 1) }
    #expect(trial.strategy == before)
    trial.session.togglePause()
    for _ in 0..<120 * 5 { trial.step(weapon: .longRifle, front: false, fire: false, distance: 29) }
    #expect(trial.strategy == before)
    trial.fight.reset()
    #expect(trial.strategy == GuardStrategy())
  }

  @MainActor
  private final class Trial {
    static let id = "guard"
    let fight: EncounterSimulation
    let session: GameSession
    private let level: Level
    private var figures: [PartyMember: SIMD2<Float>] = [
      .miki: [0, 6], .tom: [-20, 20], .laura: [20, 20],
    ]
    private(set) var hits: [DamageHit] = []
    private(set) var shots: [EncounterSimulation.Shot] = []
    private(set) var legBreaks: [SIMD2<Float>] = []
    var strategy: GuardStrategy { fight.guardStrategies[Self.id] ?? GuardStrategy() }
    var robot: RobotGuard? { fight.hostiles[Self.id]?.robot }

    init(boxes: [Level.Box] = []) throws {
      let hostile = Level.Hostile(
        id: Self.id, name: "Guard", hiddenAt: .zero, standAt: .zero, hits: 6,
        attack: .robot, strategicGuard: true, range: 12)
      let encounter = Level.Encounter(
        beat: .stranger, start: .area(.init(minimum: [-40, -40], maximum: [40, 40])),
        retryAt: [0, 6], hostiles: [hostile],
        cues: [(0, .reveal(Self.id)), (0, .engage(Self.id))])
      level = Level(
        id: "eye-leg-fixture", ground: .box("floor", at: [0, -0.15, 0], size: [100, 0.3, 100]),
        boxes: boxes, triggers: [], encounters: [encounter], party: [.miki, .tom, .laura],
        spawns: figures, heading: [0, -1], cameraOffset: BrooklynBridge.cameraOffset,
        fieldOfView: 22, opening: "Range", objective: "Test", lookAround: "Range",
        restartNote: "Restart")
      fight = EncounterSimulation(level: level)
      session = GameSession(level: level)
      try #require(session.beginEncounter(encounter.beat))
      fight.begin(encounter)
      step(weapon: .longRifle, fire: false)
    }

    func step(
      weapon: Weapon.Kind, front: Bool = true, leg: Int? = nil, fire: Bool = true,
      distance: Float? = nil, fixedOrigin: SIMD2<Float>? = nil
    ) {
      let member: PartyMember =
        switch weapon {
        case .longRifle, .assaultRifle: .miki
        case .shotgun, .energySword: .laura
        default: .tom
        }
      while session.leader != member { session.cycleLeader() }
      if fight.weapon(of: member).kind != weapon { fight.swapWeapon(for: member) }
      let robot = self.robot ?? RobotGuard(home: .zero)
      let reach = distance ?? (weapon == .energySword ? 2.65 : weapon == .shotgun ? 3.5 : 6)
      let side: SIMD2<Float>
      if let leg,
        let point = fight.weakpoints(for: Self.id).first(where: { $0.part == .leg(leg) })
      {
        side = simd_normalize(point.ground - robot.position)
      } else {
        side = robot.facing * (front ? 1 : -1)
      }
      let origin = fixedOrigin ?? robot.position + side * reach
      figures[member] = origin
      let points = fight.weakpoints(for: Self.id)
      let contact =
        leg.flatMap { index in points.first { $0.part == .leg(index) } }
        ?? points.first { $0.part == .eye }
      let facing = simd_normalize((contact?.ground ?? robot.position) - origin)
      _ = fight.step(
        dt: 1 / 120, leader: origin, facing: facing, aiming: fire, fireHeld: fire,
        firePressed: fire, figures: figures, session: session,
        untouchable: Set(PartyMember.allCases))
      shots += fight.shots.filter { $0.actor == member }
      for event in fight.takeEvents() {
        if case .damaged(let hit) = event { hits.append(hit) }
        if case .guardLegBroken(let position) = event { legBreaks.append(position) }
      }
    }
  }
}
