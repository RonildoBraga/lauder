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
  func mikiAndTomPreferThePersistentEyeWhileLauraTakesTheNearestIntactLeg() {
    for (member, weapon) in [(PartyMember.miki, Weapon.Kind.longRifle), (.tom, .minigun)] {
      var planner = CompanionTactics()
      let result = plan(
        &planner, input(member: member, leader: .laura), canFireAtBody: { _, _ in true })
      #expect(result.weapon == weapon && result.fire && !result.targetsBody)
      #expect(result.lookAt == [0, -1.45])
    }
    var planner = CompanionTactics()
    let near = weakpoint(.leg(2), ground: [1.45, 0])
    let far = weakpoint(.leg(0), ground: [-1.45, 0])
    let result = plan(
      &planner,
      input(member: .laura, leader: .miki, position: [3, 0], points: [far, near]))
    #expect(result.weapon == .energySword && result.fire && !result.targetsBody)
    #expect(result.lookAt == near.ground)
    // Detaching that leg removes its volume. Even within the replan interval the next
    // surviving leg becomes authoritative instead of retaining the old cached contact.
    let next = plan(
      &planner,
      input(member: .laura, leader: .miki, position: [3, 0], points: [far], dt: 0.001))
    #expect(next.lookAt == far.ground && next.weapon == .energySword)
    let fallback = plan(
      &planner, input(member: .laura, leader: .miki, points: []),
      canFireAtBody: { _, weapon in weapon == .shotgun })
    #expect(fallback.weapon == .shotgun && fallback.targetsBody && fallback.fire)
  }

  @Test
  func withoutItsPartACompanionFiresOrdinarilyAndThePartRestoresTheSpecialistPreference() {
    var planner = CompanionTactics()
    let ordinary = plan(
      &planner, input(points: []), canFireAtBody: { _, _ in true })
    #expect(ordinary.position == [0, -6] && ordinary.targetsBody && ordinary.fire)
    let opening = plan(
      &planner, input(), canFireAtBody: { _, _ in true })
    #expect(opening.fire && !opening.targetsBody && opening.activity == .attacking)
    let goneAgain = plan(
      &planner, input(points: []), canFireAtBody: { _, _ in true })
    #expect(goneAgain.fire && goneAgain.targetsBody && goneAgain.activity == .attacking)
  }

  @Test(arguments: [PartyMember.miki, .tom])
  func aBlockedExposedEyeAllowsUsefulBodyFireBeforeAnotherCriticalPosition(member: PartyMember) {
    var planner = CompanionTactics()
    let start = SIMD2<Float>(0, -6)
    let weapon: Weapon.Kind = member == .miki ? .longRifle : .minigun
    // The eye still exists and other legal eye positions remain available. Ordinary fire
    // cannot depend on an empty component list or on forbidding every alternative route.
    for frame in 0..<120 {
      let result = plan(
        &planner, input(member: member, dt: frame % 20 == 0 ? 0.31 : 0.001),
        canFire: { point, _, _ in point.x > 0.1 },
        canFireAtBody: { point, kind in point == start && kind == weapon })
      #expect(result.position == start && result.lookAt == .zero)
      #expect(result.weapon == weapon && result.targetsBody && result.fire)
    }
    let critical = plan(
      &planner, input(member: member, dt: 0.001), canFireAtBody: { _, _ in true })
    #expect(critical.fire && !critical.targetsBody && critical.lookAt == [0, -1.45])
  }

  @Test(arguments: [PartyMember.miki, .tom])
  func aNewBodyLaneCancelsACachedEyeApproachWithoutKeepingStaleFire(member: PartyMember) throws {
    var planner = CompanionTactics()
    let start = SIMD2<Float>(0, -6)
    let seeking = plan(
      &planner, input(member: member), canFire: { point, _, _ in point.x > 0.1 })
    #expect(try #require(seeking.position) != start)
    #expect(seeking.activity == .approaching && !seeking.fire)
    let firing = plan(
      &planner, input(member: member, dt: 0.001),
      canFire: { point, _, _ in point.x > 0.1 },
      canFireAtBody: { point, _ in point == start })
    #expect(firing.position == start && firing.targetsBody && firing.fire)
    let blocked = plan(
      &planner, input(member: member, dt: 0.001),
      canFire: { point, _, _ in point.x > 0.1 })
    #expect(!blocked.fire)
    let critical = plan(&planner, input(member: member, dt: 0.001))
    #expect(critical.fire && !critical.targetsBody)
  }

  @Test(arguments: [PartyMember.miki, .tom])
  func aClearBodyCannotOverrideThreatOrAnIllegalCurrentFiringPlace(member: PartyMember) {
    let start = SIMD2<Float>(0, -6)
    var threatened = CompanionTactics()
    let avoiding = plan(
      &threatened, input(member: member), canFire: { _, _, _ in false },
      canFireAtBody: { _, _ in true }, isThreatened: { _ in true })
    #expect(avoiding.activity == .avoiding && !avoiding.fire)
    var crowded = CompanionTactics()
    let spacing = plan(
      &crowded, input(member: member), canFire: { point, _, _ in point.x > 0.1 },
      canFireAtBody: { _, _ in true },
      isSpaced: { simd_distance($0, start) >= CompanionTactics.minimumSpacing })
    #expect(!spacing.fire && spacing.position != start)
    var obstructed = CompanionTactics()
    let illegal = plan(
      &obstructed, input(member: member), canStand: { $0 != start },
      canFire: { point, _, _ in point.x > 0.1 }, canFireAtBody: { _, _ in true })
    #expect(!illegal.fire && illegal.position != start)
  }

  @Test
  func lauraStillClosesForAnIntactLegInsteadOfChoosingAConvenientShotgunBodyHit() throws {
    var planner = CompanionTactics()
    let result = plan(
      &planner, input(member: .laura, leader: .miki),
      canFire: { point, _, _ in point.x > 0.1 }, canFireAtBody: { _, _ in true })
    #expect(try #require(result.position) != [0, -6])
    #expect(result.weapon == .energySword && !result.targetsBody && !result.fire)
    #expect(result.activity == .approaching)
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
        member: .laura, leader: .miki, position: actor, leaderPosition: [0, -4], stage: .active,
        points: [weakpoint(.leg(0), ground: [1.45, 0])]),
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
      &planner, input(member: .laura, leader: .miki, stage: .active),
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
  func aBlockedOrdinaryAttackStillSupportsFromNearbyCover() throws {
    var planner = CompanionTactics()
    let result = plan(
      &planner, input(member: .tom, points: []), isCovered: { $0.x > 1 })
    let goal = try #require(result.position)
    #expect(result.activity == .waiting && result.weapon == nil && !result.fire)
    #expect(goal.x > 1 && simd_distance(goal, [0, -6]) <= 3)
  }

  @Test
  func ordinaryAttackRepositionsToARealClearLaneAndInvalidatesAnOccupiedGoal() throws {
    var planner = CompanionTactics()
    let start = SIMD2<Float>(0, -6)
    let approach = plan(
      &planner, input(member: .tom, points: []), canFireAtBody: { point, _ in point.x > 0.1 })
    let goal = try #require(approach.position)
    #expect(approach.targetsBody && approach.weapon == .minigun && !approach.fire)
    #expect(approach.activity == .approaching && goal.x > 0.1)
    #expect(simd_distance(goal, start) <= CompanionTactics.localRadius)
    let replaced = plan(
      &planner, input(member: .tom, points: [], dt: 0.001),
      canFireAtBody: { point, _ in point.x > 0.1 },
      isSpaced: { simd_distance($0, goal) >= CompanionTactics.minimumSpacing })
    #expect(
      simd_distance(try #require(replaced.position), goal) >= CompanionTactics.minimumSpacing)
    #expect(replaced.targetsBody && !replaced.fire)
    let stopped = plan(
      &planner, input(member: .tom, points: []), canTraverse: { _, _ in false },
      canFireAtBody: { point, _ in point.x > 0.1 })
    #expect(stopped.position == nil && !stopped.fire)
  }

  @Test
  func aThreatenedNonSpecialistAvoidsBeforeTakingAnOrdinaryShot() throws {
    var planner = CompanionTactics()
    let result = plan(
      &planner, input(member: .tom, points: []), canFireAtBody: { _, _ in true },
      isCovered: { $0.x > 2 }, isThreatened: { $0.x <= 2 })
    #expect(result.activity == .avoiding && !result.fire)
    #expect(try #require(result.position).x > 2)
  }

  @Test
  func blockedOrdinaryFireDoesNotRescanEveryNearbyCandidateOnEveryFixedStep() {
    for hasCover in [false, true] {
      var planner = CompanionTactics()
      _ = plan(
        &planner, input(member: .tom, points: []), isCovered: { _ in hasCover })
      var queries = 0
      for _ in 0..<10 {
        let result = plan(
          &planner, input(member: .tom, points: [], dt: 0.01),
          canFireAtBody: { _, _ in
            queries += 1
            return false
          }, isCovered: { _ in hasCover })
        #expect(!result.fire)
      }
      // Current place and any retained cover place can be reconsidered immediately;
      // a full candidate search still follows the ordinary bounded replanning interval.
      #expect(queries <= 20)
    }
  }

  @Test
  func anUnavailableSpecialistLegCanStillUseASafeOrdinaryShotFromTheCurrentPlace() {
    var planner = CompanionTactics()
    // Keep the fallback stable across cache and replan steps, long enough to draw the gun.
    // Rebuilding a specialist intent on cached steps used to swap it back to the sword.
    for _ in 0..<120 {
      let result = plan(
        &planner, input(member: .laura, leader: .miki, stage: .active),
        canTraverse: { simd_distance($0, $1) < 0.01 }, canFire: { _, _, _ in false },
        canFireAtBody: { _, weapon in weapon == .shotgun })
      #expect(result.targetsBody && result.weapon == .shotgun && result.fire)
      #expect(result.position == [0, -6] && result.lookAt == .zero)
    }
  }

  @Test
  func aHeldNonSpecialistCanFireOrdinarilyButGoAndDefendCannot() {
    var planner = CompanionTactics()
    let held = plan(
      &planner, input(member: .tom, order: .holding([0, -6])),
      canFire: { _, _, _ in false },
      canFireAtBody: { _, _ in true },
      isSpaced: { _ in
        Issue.record("Spacing must not override a Hold anchor")
        return false
      })
    #expect(held.position == nil && held.targetsBody && held.weapon == .minigun && held.fire)
    for command in [
      input(member: .tom, order: .going([2, -4])),
      input(member: .tom, stance: .defend),
    ] {
      let result = plan(
        &planner, command,
        canFireAtBody: { _, _ in
          Issue.record("A Go or Defend order must not query an attack")
          return true
        })
      #expect(!result.fire && !result.targetsBody && result.weapon == nil)
    }
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
      for stage in [GuardStrategy.Phase.active, .complete] {
        var planner = CompanionTactics()
        let result = plan(
          &planner,
          input(
            member: member, leader: member == .miki ? .laura : .miki, stance: .defend, stage: stage),
          canFire: { _, _, _ in
            Issue.record("Defend must not request a combat ray")
            return true
          },
          canFireAtBody: { _, _ in
            Issue.record("Defend must not request an ordinary combat ray")
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
  func defendUsesReachableShelterBehindAFormationFacingTheGuard() throws {
    var planner = CompanionTactics()
    let leader = SIMD2<Float>.zero
    let start = SIMD2<Float>(0, -1.3)
    let base = SIMD2<Float>(0, -1.6)
    let shelter = SIMD2<Float>(0, 1.4)
    let result = plan(
      &planner,
      input(position: start, leaderPosition: leader, baseTarget: base, stance: .defend),
      // The world has found a route around the block to this protected rear place.
      canTraverse: { _, end in simd_distance(end, shelter) < 0.1 },
      isCovered: { simd_distance($0, shelter) < 0.1 },
      isSpaced: { simd_distance($0, leader) >= CompanionTactics.minimumSpacing })
    let goal = try #require(result.position)
    #expect(simd_distance(goal, shelter) < 0.1)
    #expect(simd_distance(goal, leader) <= 2.6)
    #expect(simd_distance(goal, base) > simd_distance(start, base))
    #expect(result.activity == .avoiding)
    #expect(!result.fire && result.weapon == nil && result.lookAt == nil)
  }

  @Test
  func distantShelterStillRequiresProgressTowardsTheFormation() {
    var planner = CompanionTactics()
    let start = SIMD2<Float>(0, -4)
    let base = SIMD2<Float>(0, -4.5)
    let shelter = SIMD2<Float>(0, -2.75)
    let result = plan(
      &planner,
      input(position: start, leaderPosition: .zero, baseTarget: base, stance: .defend),
      isCovered: { simd_distance($0, shelter) < 0.1 })
    // This place approaches the leader, but is outside nearby recall and retreats from base.
    #expect(simd_length(shelter) > 2.6 && simd_length(shelter) < simd_length(start) - 0.25)
    #expect(result == .init(activity: .following))
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

  @Test
  func recallingCompanionsReserveSeparateCoveredPlacesNearTheirLeader() throws {
    var first = CompanionTactics()
    var second = CompanionTactics()
    let leader = SIMD2<Float>.zero
    let base = SIMD2<Float>(0, -1.6)
    let chosen = plan(
      &first,
      input(position: [-1, -2], leaderPosition: leader, baseTarget: base, stance: .defend),
      isCovered: { _ in true },
      isSpaced: { simd_distance($0, leader) >= CompanionTactics.minimumSpacing })
    let firstGoal = try #require(chosen.position)
    let next = plan(
      &second,
      input(
        member: .tom, position: [1, -2], leaderPosition: leader, baseTarget: base, stance: .defend
      ),
      isCovered: { _ in true },
      isSpaced: {
        simd_distance($0, leader) >= CompanionTactics.minimumSpacing
          && simd_distance($0, firstGoal) >= CompanionTactics.minimumSpacing
      })
    let secondGoal = try #require(next.position)
    #expect(simd_distance(firstGoal, secondGoal) >= CompanionTactics.minimumSpacing)
    #expect(simd_distance(firstGoal, leader) <= 2.6 && simd_distance(secondGoal, leader) <= 2.6)
    #expect(chosen.activity == .avoiding && next.activity == .avoiding)
    #expect(!chosen.fire && !next.fire && chosen.weapon == nil && next.weapon == nil)
  }

  @Test
  func aReservedPlaceImmediatelyInvalidatesACachedCoverGoal() throws {
    var planner = CompanionTactics()
    let initial = plan(
      &planner,
      input(position: [0, -3.5], leaderPosition: .zero, baseTarget: [0, -1.6], stance: .defend),
      isCovered: { _ in true },
      isSpaced: { simd_length($0) >= CompanionTactics.minimumSpacing })
    let reserved = try #require(initial.position)
    let replaced = plan(
      &planner,
      input(
        position: [0, -3.5], leaderPosition: .zero, baseTarget: [0, -1.6], stance: .defend,
        dt: 0.001), isCovered: { _ in true },
      isSpaced: {
        simd_length($0) >= CompanionTactics.minimumSpacing
          && simd_distance($0, reserved) >= CompanionTactics.minimumSpacing
      })
    #expect(
      simd_distance(try #require(replaced.position), reserved) >= CompanionTactics.minimumSpacing)
    #expect(!replaced.fire && replaced.weapon == nil)
  }

  @Test
  func aCrowdedFiringPlaceUsesALocalClearStepAndThenStaysPut() throws {
    var planner = CompanionTactics()
    let start = SIMD2<Float>(0, -6)
    let moved = plan(
      &planner, input(),
      isSpaced: { simd_distance($0, start) >= CompanionTactics.minimumSpacing })
    let goal = try #require(moved.position)
    #expect(simd_distance(goal, start) >= CompanionTactics.minimumSpacing)
    #expect(simd_distance(goal, start) <= CompanionTactics.localRadius)
    #expect(!moved.fire && moved.activity == .approaching)
    let arrived = plan(
      &planner, input(position: goal, leaderPosition: start, baseTarget: start, dt: 0.31),
      isSpaced: { simd_distance($0, start) >= CompanionTactics.minimumSpacing })
    #expect(arrived.position == goal && arrived.fire && arrived.activity == .attacking)
  }

  @Test
  func openRecallAndSupportSettleApartWhenTheNormalFormationPlaceIsOccupied() throws {
    for stance in [GameSession.CombatStance.attack, .defend] {
      var planner = CompanionTactics()
      let base = SIMD2<Float>(0, -0.9)
      let result = plan(
        &planner,
        input(
          member: .tom, position: [0, -1], leaderPosition: .zero, baseTarget: base,
          stance: stance, points: []),
        isSpaced: { simd_length($0) >= CompanionTactics.minimumSpacing })
      let goal = try #require(result.position)
      #expect(simd_length(goal) >= CompanionTactics.minimumSpacing && simd_length(goal) <= 2.6)
      #expect(!result.fire && result.weapon == nil)
      let settled = plan(
        &planner,
        input(
          member: .tom, position: goal, leaderPosition: .zero, baseTarget: base, stance: stance,
          points: [], dt: 0.31),
        isSpaced: { simd_length($0) >= CompanionTactics.minimumSpacing })
      #expect(settled.position == goal && !settled.fire)
    }
  }

  @Test
  func spacingCannotOverrideHardOrdersOrInactiveFollowing() {
    for stance in [GameSession.CombatStance.attack, .defend] {
      var planner = CompanionTactics()
      let going = plan(
        &planner, input(order: .going([2, -4]), stance: stance),
        isSpaced: { _ in
          Issue.record("Spacing must not override a Go order")
          return false
        })
      #expect(going == .init(activity: .ordered))
      let held = plan(
        &planner, input(order: .holding([0, -6]), stance: stance),
        isSpaced: { _ in
          Issue.record("Spacing must not override a Hold order")
          return false
        })
      #expect(held.position == nil && held.fire == (stance == .attack))
      let inactive = plan(
        &planner, input(stance: stance, active: false),
        isSpaced: { _ in
          Issue.record("Inactive tactics must retain ordinary following")
          return false
        })
      #expect(inactive == .init(activity: .following))
    }
  }

  @Test
  func anUnavailableRecallPlaceDoesNotCreateAnIllegalDestination() {
    var planner = CompanionTactics()
    let blocked = plan(
      &planner,
      input(position: [0, -1], leaderPosition: .zero, baseTarget: [0, -0.9], stance: .defend),
      isCovered: { _ in true }, isSpaced: { _ in false })
    #expect(blocked == .init(activity: .following))
  }

  private func input(
    member: PartyMember = .miki, leader: PartyMember = .laura,
    position: SIMD2<Float> = [0, -6], leaderPosition: SIMD2<Float> = [0, -6],
    baseTarget: SIMD2<Float>? = nil, order: GameSession.Order = .following,
    stance: GameSession.CombatStance = .attack, active: Bool = true,
    phase: RobotGuard.Phase = .recovering, stage: GuardStrategy.Phase = .active,
    points: [GuardWeakpoint]? = nil, dt: Float = 1 / 60
  ) -> CompanionTactics.Input {
    let part: GuardStrategy.Part = member == .laura ? .leg(0) : .eye
    return .init(
      member: member, leader: leader, position: position, leaderPosition: leaderPosition,
      baseTarget: baseTarget ?? position, order: order, stance: stance, active: active,
      guardPosition: .zero,
      guardFacing: [0, -1], phase: phase, stage: stage,
      weakpoints: points ?? [weakpoint(part)], dt: dt)
  }

  private func weakpoint(_ part: GuardStrategy.Part, ground: SIMD2<Float> = [0, -1.45])
    -> GuardWeakpoint
  {
    .init(
      id: "guard.\(part)", hostileID: "guard", part: part,
      centre: [ground.x, 1.5, ground.y], radius: 0.4)
  }

  private func plan(
    _ planner: inout CompanionTactics, _ input: CompanionTactics.Input,
    canStand: (SIMD2<Float>) -> Bool = { _ in true },
    canTraverse: (SIMD2<Float>, SIMD2<Float>) -> Bool = { _, _ in true },
    canFire: (SIMD2<Float>, GuardWeakpoint, Weapon.Kind) -> Bool = { _, _, _ in true },
    canFireAtBody: (SIMD2<Float>, Weapon.Kind) -> Bool = { _, _ in false },
    isCovered: (SIMD2<Float>) -> Bool = { _ in false },
    isThreatened: (SIMD2<Float>) -> Bool = { _ in false },
    isSpaced: (SIMD2<Float>) -> Bool = { _ in true }
  ) -> CompanionTactics.Intent {
    planner.plan(
      input: input, canStand: canStand, canTraverse: canTraverse, canFire: canFire,
      canFireAtBody: canFireAtBody,
      isCovered: isCovered, isThreatened: isThreatened, isSpaced: isSpaced)
  }
}
