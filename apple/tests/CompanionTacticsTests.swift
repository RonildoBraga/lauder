import Testing
import simd

@testable import Lauder

struct CompanionTacticsTests {
  @Test
  func leaderInactiveRetreatAndFinishedFightRetainOrdinaryFollowing() {
    for input in [
      input(leader: .miki), input(active: false), input(leaderPosition: [20, 0]),
      input(position: [9, 0]), input(phase: .hidden), input(phase: .down),
      input(phase: .cleared), input(stage: .complete),
    ] {
      var planner = CompanionTactics()
      let result = plan(&planner, input)
      #expect(result == .init(activity: .following))
    }
  }

  @Test
  func goAndHoldKeepTheirExplicitPositionAuthority() {
    var planner = CompanionTactics()
    let going = plan(&planner, input(order: .going([3, 2])))
    #expect(going == .init(activity: .ordered))
    let holding = plan(&planner, input(order: .holding([0, -6])))
    #expect(holding.position == nil && holding.fire && holding.activity == .attacking)
    let blocked = plan(
      &planner, input(order: .holding([0, -6])), canFire: { _, _, _ in false },
      isThreatened: { _ in true })
    #expect(blocked.position == nil && !blocked.fire && blocked.activity == .holding)
  }

  @Test
  func onlyCurrentSpecialistChoosesItsRequiredWeapon() {
    for (member, stage, weapon) in [
      (PartyMember.miki, GuardStrategy.Phase.sensor, Weapon.Kind.longRifle),
      (.laura, .coupling, .energySword), (.tom, .reactor, .minigun),
    ] {
      var planner = CompanionTactics()
      let result = plan(
        &planner, input(member: member, leader: member == .miki ? .laura : .miki, stage: stage))
      #expect(result.weapon == weapon && result.fire && result.activity == .attacking)
      for other in PartyMember.allCases where other != member {
        let support = plan(
          &planner, input(member: other, leader: member, stage: stage))
        #expect(support.weapon == nil && !support.fire)
      }
    }
  }

  @Test
  func closedPartKeepsPhysicalFiringPositionButNeverFiresUntilExposed() {
    var planner = CompanionTactics()
    let waiting = plan(&planner, input(exposed: false))
    #expect(waiting.position == [0, -6] && waiting.activity == .waiting && !waiting.fire)
    let opening = plan(&planner, input(exposed: true))
    #expect(opening.fire && opening.activity == .attacking)
    let closedAgain = plan(&planner, input(exposed: false))
    #expect(!closedAgain.fire && closedAgain.activity == .waiting)
  }

  @Test
  func blockedShotsDoNotInventDamageAndCandidatesRespectLeaderLeash() {
    var planner = CompanionTactics()
    let result = plan(
      &planner, input(), canStand: { position in position.x > 0 },
      canFire: { _, _, _ in false })
    #expect(!result.fire)
    if let goal = result.position {
      #expect(goal.x > 0 && simd_distance(goal, [0, -6]) <= CompanionTactics.leaderLeash)
    }
    let leashed = plan(
      &planner, input(position: [0, -7], leaderPosition: [0, -14]),
      canFire: { position, _, _ in position.y > 0 })
    #expect(leashed.position.map { simd_distance($0, [0, -14]) <= 8 } != false)
    #expect(!leashed.fire)
  }

  @Test
  func blockedFarFlankUsesLegalShortOrbitInsteadOfCrossingHull() throws {
    var planner = CompanionTactics()
    let actor = SIMD2<Float>(-3, 0)
    let result = plan(
      &planner,
      input(
        member: .laura, leader: .miki, position: actor, leaderPosition: [0, -4], stage: .coupling,
        points: [weakpoint(.coupling, ground: [1.45, 0])]),
      canTraverse: { start, end in
        // A chord crossing the living body is illegal, even on otherwise open ground.
        let delta = end - start
        let fraction = min(
          1, max(0, -simd_dot(start, delta) / max(0.0001, simd_length_squared(delta))))
        return simd_length(start + delta * fraction) > 2.4
      },
      canFire: { position, _, _ in position.x > 2.4 })
    let goal = try #require(result.position)
    #expect(result.activity == .approaching && !result.fire)
    #expect(simd_distance(goal, actor) < 1.1 && abs(simd_length(goal) - 3) < 0.0001)
    #expect(goal.x < -2.4 && abs(goal.y) > 0.9)
  }

  @Test
  func illegalPierPathsNeverBecomeOrbitOrFiringTargets() {
    var planner = CompanionTactics()
    let result = plan(
      &planner, input(member: .laura, leader: .miki, stage: .coupling),
      canTraverse: { _, _ in false }, canFire: { _, _, _ in false })
    #expect(result.position == nil && result.activity == .following && !result.fire)
  }

  @Test
  func committedFireMakesFollowingCompanionSeekRealNearbyCoverBeforeAttacking() throws {
    var planner = CompanionTactics()
    let start = SIMD2<Float>(0, -6)
    let result = plan(
      &planner, input(), isCovered: { $0.x > 2 },
      isThreatened: { $0.x <= 2 })
    let goal = try #require(result.position)
    #expect(result.activity == .avoiding && !result.fire)
    #expect(goal.x > 2 && simd_distance(start, goal) <= CompanionTactics.localRadius)
    let noEscape = plan(
      &planner, input(), canTraverse: { _, _ in false }, isThreatened: { _ in true })
    #expect(noEscape.position == start && noEscape.activity == .avoiding && !noEscape.fire)
  }

  @Test
  func nonSpecialistSupportsFromNearbyCoverWithoutFiringAtArmour() throws {
    var planner = CompanionTactics()
    let result = plan(
      &planner, input(member: .tom), isCovered: { $0.x > 1 })
    let goal = try #require(result.position)
    #expect(result.activity == .waiting && result.weapon == nil && !result.fire)
    #expect(goal.x > 1 && simd_distance(goal, [0, -6]) <= 3)
  }

  @Test
  func cachedGoalsSurviveSmallChangesButInvalidationReactsImmediately() throws {
    var planner = CompanionTactics()
    let original = plan(
      &planner, input(position: [0, -4]), canFire: { position, _, _ in position.x > 0.1 })
    let goal = try #require(original.position)
    let cached = plan(
      &planner, input(position: [0.1, -4], dt: 0.05),
      canFire: { position, _, _ in position.x < -0.1 })
    #expect(cached.position == goal)
    let due = plan(
      &planner, input(position: [0.1, -4], dt: 0.3),
      canFire: { position, _, _ in position.x < -0.1 })
    #expect(try #require(due.position).x < 0)
    let phaseChanged = plan(
      &planner, input(position: [0.1, -4], phase: .burst, dt: 0.01),
      canFire: { position, _, _ in position.x > 0.1 })
    #expect(try #require(phaseChanged.position).x > 0)
    let nowLeader = plan(&planner, input(leader: .miki))
    #expect(nowLeader == .init(activity: .following))
  }

  @Test
  func blockedCachedLegAndNewThreatDiscardGoalImmediately() throws {
    var planner = CompanionTactics()
    let initial = plan(
      &planner, input(position: [0, -4]), canFire: { position, _, _ in position.x > 0 })
    #expect(initial.position != nil)
    let invalid = plan(
      &planner, input(position: [0, -4]), canTraverse: { _, _ in false },
      canFire: { position, _, _ in position.x > 0 })
    #expect(invalid.position == nil)
    let danger = plan(
      &planner, input(position: [0, -4]), isThreatened: { $0.x < 1 })
    #expect(danger.activity == .avoiding && !danger.fire)
    #expect(try #require(danger.position).x >= 1)
  }

  @Test
  func defendNeverAimsDrawsOrFiresAtAnyRoleOrStage() {
    for member in PartyMember.allCases {
      for stage in [GuardStrategy.Phase.sensor, .coupling, .reactor] {
        var planner = CompanionTactics()
        let result = plan(
          &planner,
          input(
            member: member, leader: member == .miki ? .laura : .miki, stance: .defend, stage: stage),
          canFire: { _, _, _ in
            Issue.record("Defend must not request a combat ray")
            return true
          })
        #expect(!result.fire && result.weapon == nil && result.lookAt == nil)
      }
    }
  }

  @Test
  func defendReturnsToLegalNearbyLeaderCover() throws {
    var planner = CompanionTactics()
    let result = plan(
      &planner,
      input(position: [0, -3.5], leaderPosition: .zero, baseTarget: [0, -0.9], stance: .defend),
      canTraverse: { _, end in end.x >= 0 },
      isCovered: { simd_distance($0, [0, -0.9]) < 0.1 })
    let goal = try #require(result.position)
    #expect(simd_distance(goal, [0, -0.9]) < 0.1)
    #expect(simd_distance(goal, [0, -3.5]) <= CompanionTactics.localRadius)
    #expect(!result.fire && result.weapon == nil && result.lookAt == nil)
  }

  @Test
  func defendDoesNotCampRemoteCoverOrTakeAnIllegalShortcutBack() {
    var planner = CompanionTactics()
    let start = SIMD2<Float>(0, -7)
    let recalled = plan(
      &planner,
      input(position: start, leaderPosition: .zero, baseTarget: [0, -0.9], stance: .defend),
      isCovered: { simd_distance($0, start) < 0.1 })
    #expect(recalled.position == nil && recalled.activity == .following)
    let blocked = plan(
      &planner,
      input(position: [0, -3.5], leaderPosition: .zero, baseTarget: [0, -0.9], stance: .defend),
      canTraverse: { _, _ in false }, isCovered: { _ in true })
    #expect(blocked.position == nil && blocked.activity == .following)
  }

  @Test
  func defendImmediatelyInvalidatesAnAttackGoalAndKeepsNewExplicitOrders() {
    var planner = CompanionTactics()
    let attack = plan(&planner, input())
    #expect(attack.fire && attack.position != nil)
    let defend = plan(&planner, input(stance: .defend, dt: 0.001))
    #expect(defend == .init(activity: .following))
    let holding = plan(&planner, input(order: .holding([0, -6]), stance: .defend))
    #expect(holding == .init(activity: .holding))
    let going = plan(&planner, input(order: .going([1, -5]), stance: .defend))
    #expect(going == .init(activity: .ordered))
  }

  private func input(
    member: PartyMember = .miki, leader: PartyMember = .laura,
    position: SIMD2<Float> = [0, -6], leaderPosition: SIMD2<Float> = [0, -6],
    baseTarget: SIMD2<Float>? = nil, order: GameSession.Order = .following,
    stance: GameSession.CombatStance = .attack, active: Bool = true,
    phase: RobotGuard.Phase = .recovering, stage: GuardStrategy.Phase = .sensor,
    exposed: Bool = true, points: [GuardWeakpoint]? = nil, dt: Float = 1 / 60
  ) -> CompanionTactics.Input {
    let part: GuardStrategy.Part =
      stage == .sensor ? .sensor : stage == .coupling ? .coupling : .reactor
    return .init(
      member: member, leader: leader, position: position, leaderPosition: leaderPosition,
      baseTarget: baseTarget ?? position, order: order, stance: stance, active: active,
      guardPosition: .zero,
      guardFacing: [0, -1], phase: phase, stage: stage,
      weakpoints: points ?? [weakpoint(part, exposed: exposed)], dt: dt)
  }

  private func weakpoint(
    _ part: GuardStrategy.Part, ground: SIMD2<Float> = [0, -1.45], exposed: Bool = true
  ) -> GuardWeakpoint {
    .init(
      id: "guard.\(part)", hostileID: "guard", part: part,
      centre: [ground.x, 1.5, ground.y], radius: 0.4, exposed: exposed)
  }

  private func plan(
    _ planner: inout CompanionTactics, _ input: CompanionTactics.Input,
    canStand: (SIMD2<Float>) -> Bool = { _ in true },
    canTraverse: (SIMD2<Float>, SIMD2<Float>) -> Bool = { _, _ in true },
    canFire: (SIMD2<Float>, GuardWeakpoint, Weapon.Kind) -> Bool = { _, _, _ in true },
    isCovered: (SIMD2<Float>) -> Bool = { _ in false },
    isThreatened: (SIMD2<Float>) -> Bool = { _ in false }
  ) -> CompanionTactics.Intent {
    planner.plan(
      input: input, canStand: canStand, canTraverse: canTraverse, canFire: canFire,
      isCovered: isCovered, isThreatened: isThreatened)
  }
}
