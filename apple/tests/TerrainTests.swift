import RealityKit
import Testing
import simd

@testable import Lauder

/// Floors, movement, picking and presentation must agree about the same actual elevation.
@MainActor
struct TerrainTests {
  private static let terrain = Terrain(patches: [
    .flat(minimum: [-6, -6], maximum: [-2, 2], height: 2),
    .ramp(minimum: [-6, 2], maximum: [-2, 6], axis: .z, from: 2, to: 0),
    .flat(minimum: [2, -6], maximum: [6, 2], height: -1.5),
    .ramp(minimum: [2, 2], maximum: [6, 6], axis: .z, from: -1.5, to: 0),
  ])
  private static var level: Level { yard() }

  private static func yard(spawn: SIMD2<Float> = [0, 7]) -> Level {
    return Level(
      id: "terrain-test", ground: TestYard.level.ground, terrain: terrain, boxes: [],
      interactions: [],
      triggers: [], party: [.miki, .laura, .tom],
      spawns: [.miki: spawn, .laura: [-1, 7], .tom: [1, 7]], heading: [0, -1],
      cameraOffset: [0, 10, 10], fieldOfView: 42, opening: "A terraced yard.",
      objective: "Explore.", lookAround: "Terraces.", restartNote: "Restart.")
  }

  @Test
  func flatLevelsKeepTheirOriginalFloorAndCliffs() {
    let flat = Terrain()
    #expect(flat.height(at: [4, 5]) == 0)
    #expect(flat.cliffs.isEmpty)
    #expect(BrooklynBridge.level.terrain == flat)
    #expect(SalvageYard.level.terrain == flat)
    #expect(RelayRun.level.terrain == flat)
  }

  @Test
  func rampsJoinBothTerracesToTheSharedFloor() {
    for (x, height): (Float, Float) in [(-4, 2), (4, -1.5)] {
      #expect(Self.terrain.height(at: [x, 0]) == height)
      #expect(Self.terrain.height(at: [x, 2]) == height)
      #expect(Self.terrain.height(at: [x, 4]) == height / 2)
      #expect(Self.terrain.height(at: [x, 6]) == 0)
      #expect(Self.terrain.height(at: [x, 7]) == 0)
    }
  }

  @Test
  func motionStopsAtBothCliffsButCanTraverseBothRamps() throws {
    let level = Self.level
    let navigation = WorldNavigation(level: level)
    let motion = navigation.start.motion
    let grid = navigation.start.grid
    for x: Float in [-4, 4] {
      #expect(motion.canTraverse(from: [x, 7], to: [x, 0]))
      #expect(!motion.canTraverse(from: [0, 0], to: [x, 0]))
      #expect(!motion.canTraverse(from: [x, 0], to: [0, 0]))
      let path = try #require(grid.route(from: [0, 0], to: [x, 0]))
      #expect(path.contains { $0.y > 5.5 }, "the route must reach the ramp entrance")
      var before: SIMD2<Float> = [0, 0]
      for point in path {
        #expect(motion.canTraverse(from: before, to: point))
        before = point
      }
    }
    let stopped = motion.resolve(start: [0, 0], delta: [-4, 0])
    #expect(stopped.x > -2 + PartyBody.radius)
    // A diagonal shortcut beside the ramp/terrace seam cannot cut either cliff corner.
    #expect(!motion.canTraverse(from: [-2.4, 1.6], to: [-1.6, 2.4]))
    #expect(!motion.canTraverse(from: [2.4, 1.6], to: [1.6, 2.4]))
  }

  @Test
  func shotsMeetRampsRisersAndTheLowerFloorWithinBounds() throws {
    let terrain = Self.terrain
    let bounds = Self.level.bounds
    let raised = try #require(
      terrain.firstIntersection(from: [0, 1, 0], to: [-4, 1, 0], within: bounds))
    #expect(abs(raised - 0.5) < 0.0001)
    let low = try #require(
      terrain.firstIntersection(from: [4, 4, 0], to: [4, -4, 0], within: bounds))
    #expect(abs(low - 0.6875) < 0.0001, "the old y=0 floor must not cover the lower court")
    let ramp = try #require(
      terrain.firstIntersection(from: [-4, 1, 7], to: [-4, 1, 1], within: bounds))
    #expect(abs(ramp - 0.5) < 0.0001)
    #expect(terrain.firstIntersection(from: [20, 4, 0], to: [20, -4, 0], within: bounds) == nil)
    #expect(terrain.firstIntersection(from: [0, 3, 0], to: [-4, 3, 0], within: bounds) == nil)
  }

  @Test
  func renderMeshHasTheLowerFloorAndSlopedTopNormals() {
    let mesh = TerrainMesh.geometry(terrain: Self.terrain, bounds: Self.level.bounds)
    #expect(mesh.tops.positions.contains { $0.y == -1.5 })
    #expect(mesh.tops.positions.contains { $0.y == 2 })
    #expect(mesh.tops.normals.contains { $0.y > 0.8 && $0.y < 0.99 })
    #expect(!mesh.risers.triangles.isEmpty)
    #expect(mesh.tops.triangles.count < 2_000)
    #expect(mesh.tops.positions.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite })
  }

  @Test
  func touchPickingAndTheBodiesFollowTheSurface() throws {
    let level = Self.level
    let camera = CameraProjection(
      eye: [0, 12, 13], target: [0, 0, 0], fieldOfView: 42, aspect: 2,
      terrain: level.terrain, bounds: level.bounds)
    for point: SIMD2<Float> in [[-4, 0], [4, 0], [-4, 4], [4, 4]] {
      let screen = try #require(camera.screen(ofGround: point))
      let hit = try #require(camera.ground(atScreen: screen))
      #expect(simd_distance(hit, point) < 0.01)
    }
    let world = GameWorld(level: level)
    let body = try #require(world.root.findEntity(named: "party.miki"))
    #expect(body.position.y == PartyBody.height / 2)
    // A fresh world on a terrace uses the same surface for body and camera, without a frame at 0.
    let upper = GameWorld(level: Self.yard(spawn: [-4, 0]))
    let upperBody = try #require(upper.root.findEntity(named: "party.miki"))
    #expect(upperBody.position.y == 2 + PartyBody.height / 2)
    #expect(upper.projection(aspect: 2).target.y > 2)
  }

  @Test
  func changingOnlyElevationCannotReuseOldNavigation() {
    let cache = NavigationCache()
    var level = Self.level
    let first = cache.prepare(for: level)
    level.terrain = Terrain(patches: [
      .flat(minimum: [-6, -6], maximum: [-2, 2], height: 3),
      .ramp(minimum: [-6, 2], maximum: [-2, 6], axis: .z, from: 3, to: 0),
    ])
    #expect(cache.prepare(for: level) !== first)
  }

  @Test
  func lowCoverUsesTheCharactersFloorAndPeeksCannotCrossCliffs() throws {
    let upper = Level.Box(name: "upper", position: [-4, 2.5, 0], size: [2, 1, 1])
    let lower = Level.Box(name: "lower", position: [4, -1, 0], size: [2, 1, 1])
    let rules = LeaderCover(
      boxes: [upper, lower], ground: Self.level.bounds, terrain: Self.terrain)
    for point: SIMD2<Float> in [[-4, 1.2], [4, 1.2]] {
      let shelter = try #require(rules.shelter(at: point, facing: [0, -1]))
      #expect(shelter.isLow)
      #expect(rules.firingPoint(from: point, in: shelter, facing: [0, -1]) == point)
    }
    #expect(rules.shelter(at: [0, 0], facing: [1, 0]) == nil)
  }
}
