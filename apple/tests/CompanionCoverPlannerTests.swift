import Testing
import simd

@testable import Lauder

/// Shared cover keeps the movement anchor hidden; the fight poses the temporary firing peek.
struct CompanionCoverPlannerTests {
  @Test
  func aLowShelterKeepsTheSameAnchorWhileItsShooterRecovers() throws {
    let level = Self.level(height: 1)
    let grid = NavigationGrid(level: level)
    let geometry = LeaderCover(boxes: level.boxes, ground: level.bounds)
    var planner = CoverPlanner(obstacles: level.obstacles, coverRules: geometry)
    var threat = CoverPlanner.Threat(position: [0, -6], range: 14, aimingAt: .laura)
    let place: SIMD2<Float> = [1.6, 0.9]
    let spot = try #require(plan(&planner, grid: grid, place: place, threats: [threat]))
    #expect(planner.isTakingCover(.laura))
    let shelter = try #require(geometry.shelter(at: spot, facing: threat.position - spot))
    #expect(shelter.isLow)
    #expect(hidden(spot, from: threat, geometry: geometry))
    #expect(simd_distance(spot, place) <= CoverPlanner.reach(in: .close))
    #expect(geometry.firingPoint(from: spot, in: shelter, facing: threat.position - spot) == spot)
    #expect(
      LineOfSight.isClear(
        from: spot, to: threat.position,
        obstacles: geometry.incomingBlockers(in: shelter, exposed: true)))
    // Unlike legacy physical stepping-out, a recovering shooter does not move this anchor.
    threat.aimingAt = nil
    #expect(plan(&planner, grid: grid, place: place, threats: [threat]) == spot)
  }

  @Test
  func tallCoverPrefersAValidPeekInsteadOfTheMiddleOfTheWall() throws {
    let level = Self.level(height: 3)
    let grid = NavigationGrid(level: level)
    let geometry = LeaderCover(boxes: level.boxes, ground: level.bounds)
    var planner = CoverPlanner(obstacles: level.obstacles, coverRules: geometry)
    let threat = CoverPlanner.Threat(position: [0, -6], range: 14)
    let place: SIMD2<Float> = [0, 0.9]
    let middle = try #require(geometry.shelter(at: place, facing: threat.position - place))
    #expect(geometry.firingPoint(from: place, in: middle, facing: threat.position - place) == nil)
    let spot = try #require(plan(&planner, grid: grid, place: place, threats: [threat]))
    let shelter = try #require(geometry.shelter(at: spot, facing: threat.position - spot))
    #expect(!shelter.isLow && hidden(spot, from: threat, geometry: geometry))
    let peek = try #require(
      geometry.firingPoint(from: spot, in: shelter, facing: threat.position - spot))
    #expect(peek != spot)
    #expect(
      LineOfSight.isClear(
        from: peek, to: threat.position,
        obstacles: geometry.incomingBlockers(in: shelter, exposed: true)))
    #expect(simd_distance(spot, place) <= CoverPlanner.reach(in: .close))
  }

  @Test
  func aNewlyVisibleFlankReplansBeforeTheOrdinaryCommitmentExpires() throws {
    let level = Self.level(height: 1)
    let grid = NavigationGrid(level: level)
    let geometry = LeaderCover(boxes: level.boxes, ground: level.bounds)
    var planner = CoverPlanner(obstacles: level.obstacles, coverRules: geometry)
    let place: SIMD2<Float> = [0, 0.9]
    let ahead = CoverPlanner.Threat(position: [0, -6], range: 14)
    let first = try #require(
      plan(&planner, grid: grid, place: place, formation: .spread, threats: [ahead]))
    #expect(hidden(first, from: ahead, geometry: geometry))
    let flank = CoverPlanner.Threat(position: [6, 0.9], range: 14)
    #expect(!hidden(first, from: flank, geometry: geometry))
    let next = try #require(
      plan(&planner, grid: grid, place: place, formation: .spread, threats: [flank]))
    #expect(next != first && hidden(next, from: flank, geometry: geometry))
    #expect(simd_distance(next, place) <= CoverPlanner.reach(in: .spread))
    // The stable threat then keeps this choice; it does not bounce among equally safe spots.
    for _ in 0..<100 {
      #expect(
        plan(&planner, grid: grid, place: place, formation: .spread, threats: [flank]) == next)
    }
  }

  @Test
  func sharedCoverNeverClaimsAnOpenPositionAndKeepsOrderBounds() throws {
    let level = Self.level(height: 1)
    let grid = NavigationGrid(level: level)
    let geometry = LeaderCover(boxes: level.boxes, ground: level.bounds)
    var planner = CoverPlanner(obstacles: level.obstacles, coverRules: geometry)
    let threat = CoverPlanner.Threat(position: [0, -6], range: 14)
    let place: SIMD2<Float> = [1.6, 0.9]
    let first = try #require(plan(&planner, grid: grid, place: place, threats: [threat]))
    #expect(geometry.shelter(at: first, facing: threat.position - first) != nil)
    let newOrder: SIMD2<Float> = [6, 4]
    #expect(plan(&planner, grid: grid, place: newOrder, threats: [threat]) == newOrder)
    #expect(!planner.isTakingCover(.laura))
    #expect(plan(&planner, grid: grid, place: place, threats: []) == place)
    #expect(!planner.isTakingCover(.laura))
  }

  private static func level(height: Float) -> Level {
    Level(
      id: "shared-cover-planner", ground: .box("ground", at: [0, -0.15, 0], size: [30, 0.3, 30]),
      boxes: [.box("shelter", at: [0, height / 2, 0], size: [2, height, 1])],
      interactions: [], triggers: [], party: [.miki, .laura, .tom],
      spawns: [.miki: [5, 5], .laura: [1.6, 0.9], .tom: [6, 6]], heading: [0, -1],
      cameraOffset: CombatYard.level.cameraOffset, fieldOfView: CombatYard.level.fieldOfView,
      opening: "Snow.", objective: "Test.", lookAround: "A block.", restartNote: "Restart.")
  }

  private func plan(
    _ planner: inout CoverPlanner, grid: NavigationGrid, place: SIMD2<Float>,
    formation: GameSession.Formation = .close, threats: [CoverPlanner.Threat]
  ) -> SIMD2<Float>? {
    planner.targets(
      for: CoverPlanner.Input(
        places: [.laura: place], positions: [.laura: place], leaderPosition: [5, 5],
        formation: formation, threats: threats, weaponRanges: [.laura: Weapon.lightBurst.range],
        dt: 1 / 120), grid: grid)[.laura]
  }

  private func hidden(
    _ point: SIMD2<Float>, from threat: CoverPlanner.Threat, geometry: LeaderCover
  ) -> Bool {
    let shelter = geometry.shelter(at: point, facing: threat.position - point)
    return !LineOfSight.isClear(
      from: threat.position, to: point,
      obstacles: geometry.incomingBlockers(in: shelter, exposed: false))
  }
}
