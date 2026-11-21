import Testing
import simd

@testable import Lauder

/// Where companions take cover in a fight: ADR 0003's cover near the slot, tried in the combat
/// yard (ADR 0005). The planner alone, on open snow with one wall and a shooter beyond it.
@Suite("Cover")
struct CoverTests {
  /// Open snow 30 m across, a wall 2 m wide across z = -1, and the party far from it.
  private static let level = Level(
    id: "cover-test", ground: .box("ground", at: [0, -0.15, 0], size: [30, 0.3, 30]),
    boxes: [.box("wall", at: [0, 1.5, -1], size: [2, 3, 0.5])], interactions: [], triggers: [],
    party: [.miki, .laura, .tom], spawns: [.miki: [5, 5], .laura: [5, 6], .tom: [6, 6]],
    heading: [0, -1], cameraOffset: CombatYard.level.cameraOffset,
    fieldOfView: CombatYard.level.fieldOfView, opening: "Snow.", objective: "Test.",
    lookAround: "A wall.", restartNote: "Restart.")
  private static let grid = NavigationGrid(level: level)
  /// A shooter 7 m beyond the wall, with the yard's reach.
  private static let shooter = CoverPlanner.Threat(position: [0, -8], range: 14)
  /// Beside the wall's east end, in the shooter's sight.
  private static let besideTheWall: SIMD2<Float> = [1.6, 0.3]

  @Test
  func aCompanionInSightTakesTheSpotBehindTheWallAndStepsOutToFire() throws {
    #expect(sees(Self.shooter.position, Self.besideTheWall))
    var planner = CoverPlanner(obstacles: Self.level.obstacles)
    // While the shooter aims at Laura, she goes to a spot near her place, hidden from it.
    var aiming = Self.shooter
    aiming.aimingAt = .laura
    let spot = try #require(plan(&planner, [.laura: Self.besideTheWall], threats: [aiming])[.laura])
    #expect(simd_distance(spot, Self.besideTheWall) <= CoverPlanner.reach(in: .close))
    #expect(isHidden(spot))
    // Otherwise she steps out to a firing position close by, in sight and reach of it.
    let firing = try #require(plan(&planner, [.laura: Self.besideTheWall])[.laura])
    #expect(simd_distance(firing, spot) > 0.3)
    #expect(simd_distance(firing, spot) <= CoverPlanner.peekReach + 0.001)
    #expect(sees(Self.shooter.position, firing))
    #expect(simd_distance(firing, Self.shooter.position) <= Weapon.lightBurst.range)
    // Aimed at again, she goes back to the same spot.
    #expect(plan(&planner, [.laura: Self.besideTheWall], threats: [aiming])[.laura] == spot)
  }

  @Test
  func withoutAShooterOrCoverInReachCompanionsKeepToTheirPlaces() {
    var planner = CoverPlanner(obstacles: Self.level.obstacles)
    let places: [PartyMember: SIMD2<Float>] = [.laura: Self.besideTheWall, .tom: [6, 1]]
    #expect(plan(&planner, places, threats: []) == places)
    // Tom's place is in the open, more than 1.5 m from any spot the wall hides, so he keeps to
    // it, and follows it as it moves with the leader.
    #expect(plan(&planner, [.tom: [6, 1]])[.tom] == [6, 1])
    #expect(!planner.isTakingCover(.tom))
    #expect(plan(&planner, [.tom: [6.5, 1]])[.tom] == [6.5, 1])
  }

  @Test
  func spreadLooksForCoverFurtherFromThePlace() throws {
    // 1.7 m from the nearest spot the wall hides: beyond Close's reach, within Spread's.
    let place: SIMD2<Float> = [2.4, 0.3]
    var close = CoverPlanner(obstacles: Self.level.obstacles)
    #expect(plan(&close, [.laura: place])[.laura] == place)
    var spread = CoverPlanner(obstacles: Self.level.obstacles)
    var aiming = Self.shooter
    aiming.aimingAt = .laura
    let spot = try #require(
      plan(&spread, [.laura: place], formation: .spread, threats: [aiming])[.laura])
    #expect(isHidden(spot))
    #expect(simd_distance(spot, place) <= CoverPlanner.reach(in: .spread))
  }

  @Test
  func aSpotIsKeptForTwoSecondsThenWeighedAgain() throws {
    var planner = CoverPlanner(obstacles: Self.level.obstacles)
    var aiming = Self.shooter
    aiming.aimingAt = .laura
    let spot = try #require(plan(&planner, [.laura: Self.besideTheWall], threats: [aiming])[.laura])
    // The leader walks off and Laura's place moves into the open, far from the wall: she keeps
    // her spot for two seconds.
    let moved: SIMD2<Float> = [6, 1]
    for _ in 0..<230 {
      #expect(
        plan(&planner, [.laura: moved], positions: [.laura: spot], threats: [aiming])[.laura]
          == spot)
    }
    // Then she weighs the spots again, and goes with her place.
    var target = spot
    for _ in 0..<20 {
      target = try #require(
        plan(&planner, [.laura: moved], positions: [.laura: spot], threats: [aiming])[.laura])
    }
    #expect(target == moved)
  }

  @Test
  func twoCompanionsTakeSeparateSpotsClearOfTheLeader() throws {
    var planner = CoverPlanner(obstacles: Self.level.obstacles)
    var aiming = Self.shooter
    aiming.aimingAt = .laura
    let leader: SIMD2<Float> = [0.7, 1.5]
    let places: [PartyMember: SIMD2<Float>] = [.laura: Self.besideTheWall, .tom: [-1.6, 0.3]]
    let spots = plan(&planner, places, leader: leader, threats: [aiming])
    let laura = try #require(spots[.laura])
    let tom = try #require(spots[.tom])
    #expect(isHidden(laura) && isHidden(tom))
    #expect(simd_distance(laura, tom) >= CoverPlanner.spacing)
    #expect(simd_distance(laura, leader) >= CoverPlanner.spacing)
    #expect(simd_distance(tom, leader) >= CoverPlanner.spacing)
    // Out to fire, neither steps onto the other's spot.
    let firing = plan(&planner, places, leader: leader)
    for member in [PartyMember.laura, .tom] {
      let point = try #require(firing[member])
      let other = try #require(spots[member == .laura ? .tom : .laura])
      #expect(simd_distance(point, other) >= CoverPlanner.spacing)
    }
  }

  // MARK: - Helpers

  /// One planning step of 1/120 s, with Laura's and Tom's weapons.
  private func plan(
    _ planner: inout CoverPlanner, _ places: [PartyMember: SIMD2<Float>],
    positions: [PartyMember: SIMD2<Float>]? = nil, leader: SIMD2<Float> = [5, 5],
    formation: GameSession.Formation = .close, threats: [CoverPlanner.Threat] = [shooter]
  ) -> [PartyMember: SIMD2<Float>] {
    planner.targets(
      for: CoverPlanner.Input(
        places: places, positions: positions ?? places, leaderPosition: leader,
        formation: formation, threats: threats,
        weaponRanges: [.laura: Weapon.lightBurst.range, .tom: Weapon.closeScatter.range],
        dt: 1 / 120),
      grid: Self.grid)
  }

  private func sees(_ from: SIMD2<Float>, _ to: SIMD2<Float>) -> Bool {
    LineOfSight.isClear(from: from, to: to, obstacles: Self.level.obstacles)
  }

  /// Hidden from the shooter, even a little to either side.
  private func isHidden(_ spot: SIMD2<Float>) -> Bool {
    let offset = spot - Self.shooter.position
    let side = simd_normalize(SIMD2(-offset.y, offset.x)) * 0.25
    return [spot, spot + side, spot - side].allSatisfy { !sees(Self.shooter.position, $0) }
  }
}
