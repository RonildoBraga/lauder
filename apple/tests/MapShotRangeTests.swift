import Testing
import simd

@testable import Lauder

/// A fired round crosses the actual map, independently of assistance or enemy perception.
@MainActor
struct MapShotRangeTests {
  @Test
  func anUnobstructedRoundReachesTheMapEdgeWithoutAnInvisibleImpact() {
    let ballistics = Ballistics(level: level())
    let shot = ballistics.traceAcrossLevel(
      from: [0, 1.25, 6], direction: [0, 0, -1], targets: [])
    #expect(shot.strike == .nothing)
    #expect(simd_distance(shot.end, [0, 1.25, -48]) < 0.0001)
    #expect(simd_distance(shot.start, shot.end) > Weapon.longRifle.range)
  }

  @Test
  func aSlopedDiagonalStopsAtTheFirstGroundBoundary() {
    let ballistics = Ballistics(level: level())
    let shot = ballistics.traceAcrossLevel(
      from: [0, 1.25, -18], direction: [1, 0.1, -1], targets: [])
    #expect(shot.strike == .nothing)
    #expect(simd_distance(shot.end, [26, 3.85, -44]) < 0.0001)
  }

  @Test
  func theBridgeIsNotTruncatedAtASmallerMapsDiagonal() {
    let ground = BrooklynBridge.level.ground
    let ballistics = Ballistics(level: level(ground: ground))
    let bounds = ground.footprint
    let start = SIMD3<Float>((bounds.minimum.x + bounds.maximum.x) / 2, 1.25, bounds.maximum.y - 1)
    let shot = ballistics.traceAcrossLevel(from: start, direction: [0, 0, -1], targets: [])
    #expect(shot.strike == .nothing)
    #expect(start.z - shot.end.z > 100)
    #expect(abs(shot.end.z - bounds.minimum.y) < 0.001)
  }

  @Test
  func aDistantBodyCanBeStruckAndACloserWallStillWins() {
    let body = Ballistics.Target(id: "far", centre: [0, 1.25, -40])
    let start = SIMD3<Float>(0, 1.25, 6)
    let clear = Ballistics(level: level()).traceAcrossLevel(
      from: start, direction: [0, 0, -1], targets: [body])
    #expect(clear.strike == .body("far"))
    #expect(abs(clear.end.z - (-40 + Aim.bodyRadius)) < 0.001)
    let walls: [Level.Box] = [
      .box("far-wall", at: [0, 1.5, -35], size: [4, 3, 1]),
      .box("near-wall", at: [0, 1.5, -10], size: [4, 3, 1]),
    ]
    let blocked = Ballistics(level: level(boxes: walls)).traceAcrossLevel(
      from: start, direction: [0, 0, -1], targets: [body])
    #expect(blocked.strike == .scenery)
    #expect(abs(blocked.end.z + 9.5) < 0.0001)
  }

  @Test
  func theMapBoundaryExcludesBodiesBeyondThePlayableGround() {
    let shot = Ballistics(level: level()).traceAcrossLevel(
      from: [0, 1.25, 6], direction: [0, 0, -1],
      targets: [.init(id: "outside", centre: [0, 1.25, -60])])
    #expect(shot.strike == .nothing && abs(shot.end.z + 48) < 0.0001)
  }

  @Test
  func invalidAndOutwardBoundaryRaysCannotEscapeAsUnboundedShots() {
    let ballistics = Ballistics(level: level())
    for direction: SIMD3<Float> in [.zero, [0, 1, 0], [.nan, 0, 0], [.infinity, 0, 0]] {
      let shot = ballistics.traceAcrossLevel(
        from: [0, 1.25, 6], direction: direction, targets: [])
      #expect(shot.strike == .nothing && shot.start == shot.end)
    }
    for start: SIMD3<Float> in [[26, 1.25, 0], [30, 1.25, 0]] {
      let shot = ballistics.traceAcrossLevel(from: start, direction: [1, 0, 0], targets: [])
      #expect(shot.strike == .nothing && shot.start == shot.end)
    }
  }

  private func level(
    ground: Level.Box? = nil, boxes: [Level.Box] = []
  ) -> Level {
    Level(
      id: "map-shot-range",
      ground: ground ?? .box("floor", at: [0, -0.15, -18], size: [52, 0.3, 60]),
      boxes: boxes, triggers: [],
      party: [.miki], spawns: [.miki: [0, 6]], heading: [0, -1],
      cameraOffset: [0, 10, 10], fieldOfView: 42,
      opening: "Range.", objective: "Range.", lookAround: "Range.", restartNote: "Restart.")
  }
}
