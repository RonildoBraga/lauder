import Testing
import simd

@testable import Lauder

/// The actual planner, range/cover queries and weapon executor share a native firing stance.
/// Figure positions are fixture inputs, not movement, health, timer or immunity injections.
@MainActor
struct LauraSupportTests {
  @Test(arguments: [PartyMember.miki, .tom])
  func closeSupportFiresRealShotgunRoundsWithoutSwordOrLegDamage(controlled: PartyMember) throws {
    let trial = try Trial(controlled: controlled)
    try #require(trial.bodyIsClear && trial.isEngaged)
    let health = trial.strategy.health
    let loaded = trial.fight.status(for: .laura).loaded
    var shots = 0
    var damage = 0
    for _ in 0..<240 {
      let before = trial.strategy.health
      let intent = trial.step()
      #expect(intent.position == trial.origin && intent.weapon == .shotgun && intent.targetsBody)
      #expect(intent.fire && intent.activity == .attacking)
      let fired = trial.fight.shots.filter { $0.actor == .laura }
      shots += fired.count
      let hits = trial.takeDamage()
      #expect(hits.allSatisfy { $0.attacker == .laura && $0.weapon == .shotgun && $0.amount > 0 })
      let accepted = hits.reduce(0) { $0 + $1.amount }
      #expect(before - trial.strategy.health == accepted)
      damage += accepted
    }
    #expect(shots >= 2 && damage > 0)
    #expect(loaded - trial.fight.status(for: .laura).loaded == shots)
    #expect(health - trial.strategy.health == damage)
    #expect(trial.strategy.swordHits.isEmpty && trial.strategy.detachedLegs.isEmpty)
    #expect(trial.session.leader == controlled && trial.session.combatStance == .attack)
  }

  @Test(arguments: Blocker.allCases)
  func aRealWallOrAllyBlocksSupportWithoutAnExposedFiringApproach(blocker: Blocker) throws {
    let trial = try Trial(blocker: blocker)
    try #require(!trial.bodyIsClear && trial.isEngaged)
    let loaded = trial.fight.status(for: .laura).loaded
    for _ in 0..<240 {
      let intent = trial.step()
      #expect(!intent.fire && intent.activity != .approaching)
      try trial.requireCloseLegalDestination(intent)
      #expect(!trial.fight.shots.contains { $0.actor == .laura })
      #expect(trial.takeDamage().isEmpty)
    }
    #expect(trial.fight.status(for: .laura).loaded == loaded)
    #expect(trial.strategy.health == GuardStrategy.maximumHealth)
    #expect(trial.strategy.swordHits.isEmpty && trial.strategy.detachedLegs.isEmpty)
  }

  @Test
  func aDistantClearShotDoesNotMakeLauraLeaveTheLeaderForALeg() throws {
    let trial = try Trial(placement: .distant)
    try #require(trial.isEngaged && trial.bodyIsClear)
    try #require(simd_distance(trial.origin, trial.leader) > CompanionTactics.supportRadius)
    let loaded = trial.fight.status(for: .laura).loaded
    for _ in 0..<120 {
      let intent = trial.step()
      #expect(!intent.fire && !intent.engaged && intent.activity == .following)
      try trial.requireCloseLegalDestination(intent)
      #expect(!trial.fight.shots.contains { $0.actor == .laura })
      #expect(trial.takeDamage().isEmpty)
    }
    #expect(trial.fight.status(for: .laura).loaded == loaded)
    #expect(trial.strategy.health == GuardStrategy.maximumHealth)
  }

  @Test
  func defendRevokesRealSupportFireAndQuietAttackCannotInitiateCombat() throws {
    let defending = try Trial()
    try #require(defending.isEngaged && defending.bodyIsClear)
    defending.session.setCombatStance(.defend)
    let quiet = try Trial(placement: .quiet)
    try #require(!quiet.isEngaged && quiet.bodyIsClear)
    for trial in [defending, quiet] {
      let loaded = trial.fight.status(for: .laura).loaded
      for _ in 0..<120 {
        let intent = trial.step()
        #expect(!intent.fire && !intent.engaged)
        #expect(!trial.fight.shots.contains { $0.actor == .laura })
        #expect(trial.takeDamage().isEmpty)
      }
      #expect(trial.fight.status(for: .laura).loaded == loaded)
      #expect(trial.strategy.health == GuardStrategy.maximumHealth)
    }
    #expect(!quiet.isEngaged && quiet.fight.hostiles["guard"]?.robot?.shotSerial == 0)
  }

  @Test
  func anAutomaticSwordRequestStillExecutesOnlyLaurasRangedSupportWeapon() throws {
    let trial = try Trial()
    var damage = 0
    for _ in 0..<180 {
      trial.nativeStep(
        intent: .init(
          lookAt: trial.guardPosition, engaged: true, weapon: .energySword, targetsBody: true,
          fire: true, activity: .attacking))
      #expect(trial.fight.weapon(of: .laura).kind == .shotgun)
      let hits = trial.takeDamage()
      #expect(hits.allSatisfy { $0.attacker == .laura && $0.weapon == .shotgun })
      damage += hits.reduce(0) { $0 + $1.amount }
    }
    #expect(damage > 0 && trial.strategy.health == GuardStrategy.maximumHealth - damage)
    #expect(trial.strategy.swordHits.isEmpty && trial.strategy.detachedLegs.isEmpty)
  }

  enum Blocker: CaseIterable, Sendable, Equatable { case wall, ally }
  private enum Placement: Equatable { case close, distant, quiet }

  @MainActor
  private final class Trial {
    let session: GameSession
    let fight: EncounterSimulation
    let figures: [PartyMember: SIMD2<Float>]
    let origin: SIMD2<Float>
    let leader: SIMD2<Float>
    let controlled: PartyMember
    private let motion: PartyMotion
    private var planner = CompanionTactics()

    var strategy: GuardStrategy { fight.guardStrategies["guard"] ?? GuardStrategy() }
    var guardPosition: SIMD2<Float> { fight.hostiles["guard"]?.position ?? .zero }
    var isEngaged: Bool { fight.companionGuard(near: leader) != nil }
    var bodyIsClear: Bool {
      fight.companionCanFireAtBody(
        .laura, from: origin, at: "guard", weapon: .shotgun, figures: figures)
    }

    init(
      blocker: Blocker? = nil, placement: Placement = .close, controlled: PartyMember = .miki
    ) throws {
      self.controlled = controlled
      leader = placement == .quiet ? [0, -6] : [0, 6]
      origin = placement == .distant ? [-4, 2] : leader + [1.5, 0]
      let other: PartyMember = controlled == .miki ? .tom : .miki
      figures = [
        controlled: leader, .laura: origin,
        other: blocker == .ally ? [0.75, 3] : leader + [-6, 0],
      ]
      let boxes: [Level.Box] =
        blocker == .wall ? [.box("screen", at: [0.75, 1.5, 3], size: [0.25, 3, 2])] : []
      let hostile = Level.Hostile(
        id: "guard", name: "Guard", hiddenAt: .zero, standAt: .zero, hits: 6,
        attack: .robot, strategicGuard: true)
      let encounter = Level.Encounter(
        beat: .stranger, start: .area(.init(minimum: [-20, -20], maximum: [20, 20])),
        retryAt: nil, hostiles: [hostile],
        cues: [(0, .reveal("guard")), (0, .engage("guard"))])
      let level = Level(
        id: "laura-ranged-support", ground: .box("floor", at: [0, -0.15, 0], size: [60, 0.3, 60]),
        boxes: boxes, triggers: [], encounters: [encounter], party: [controlled, other, .laura],
        spawns: figures, heading: [0, -1], cameraOffset: BrooklynBridge.cameraOffset,
        fieldOfView: 22, opening: "Test", objective: "Test", lookAround: "Test", restartNote: "Test"
      )
      motion = PartyMotion(radius: PartyBody.radius, obstacles: level.obstacles)
      session = GameSession(level: level)
      session.setCombatStance(.attack)
      fight = EncounterSimulation(level: level)
      let began = session.beginEncounter(.stranger)
      try #require(began)
      fight.begin(encounter)
      nativeStep(intent: nil)
      _ = fight.takeEvents()
    }

    @discardableResult
    func step() -> CompanionTactics.Intent {
      let robot = fight.hostiles["guard"]?.robot ?? RobotGuard(home: .zero)
      let intent = planner.plan(
        input: .init(
          member: .laura, leader: controlled, position: origin, leaderPosition: leader,
          baseTarget: leader + [1.5, 0], order: session.order(of: .laura),
          stance: session.combatStance, active: isEngaged,
          guardPosition: robot.position, guardFacing: robot.facing, phase: robot.phase,
          stage: strategy.phase, weakpoints: fight.weakpoints(for: "guard"), dt: 1 / 120),
        canStand: canStand, canTraverse: canTraverse,
        canFire: { [self] point, part, kind in
          fight.companionCanFire(.laura, from: point, at: part, weapon: kind, figures: figures)
        },
        canFireAtBody: { [self] point, kind in
          fight.companionCanFireAtBody(
            .laura, from: point, at: "guard", weapon: kind, figures: figures)
        },
        isCovered: { [self] in fight.companionHasCover(at: $0, from: robot) },
        isThreatened: { [self] in fight.companionIsThreatened(at: $0, by: robot) },
        isSpaced: { [self] point in
          figures.filter { $0.key != .laura }.values.allSatisfy {
            simd_distance($0, point) >= CompanionTactics.minimumSpacing
          }
        })
      nativeStep(intent: intent)
      return intent
    }

    func nativeStep(intent: CompanionTactics.Intent?) {
      let towards = guardPosition - origin
      let facing = simd_length(towards) > 0.001 ? simd_normalize(towards) : SIMD2<Float>(0, -1)
      _ = fight.step(
        dt: 1 / 120, leader: leader, facing: [0, -1], aiming: false, fireHeld: false,
        firePressed: false, figures: figures, session: session,
        companionIntents: intent.map { [PartyMember.laura: $0] } ?? [:], facings: [.laura: facing])
    }

    func takeDamage() -> [DamageHit] {
      fight.takeEvents().compactMap {
        if case .damaged(let hit) = $0 { hit } else { nil }
      }
    }

    func requireCloseLegalDestination(_ intent: CompanionTactics.Intent) throws {
      guard let point = intent.position else { return }
      #expect(simd_distance(point, leader) <= CompanionTactics.supportRadius)
      #expect(simd_distance(point, origin) <= CompanionTactics.localRadius)
      #expect(canStand(point) && canTraverse(origin, point))
    }

    private func canStand(_ point: SIMD2<Float>) -> Bool {
      motion.canTraverse(from: point, to: point)
        && simd_distance(point, guardPosition) >= RobotModelGeometry.navigationRadius
          + PartyBody.radius
    }

    private func canTraverse(_ start: SIMD2<Float>, _ end: SIMD2<Float>) -> Bool {
      let resolved = GuardCollision.resolve(
        start: start, delta: end - start, centre: guardPosition,
        radius: RobotModelGeometry.navigationRadius + PartyBody.radius)
      return motion.canTraverse(from: start, to: end) && simd_distance(resolved, end) < 0.0001
    }
  }
}
