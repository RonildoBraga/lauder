import Testing
import simd

@testable import Lauder

/// The bridge, and the yard that the squad-movement tests use, are well-formed content, and the
/// navigation grid built from them matches the rule it is meant to apply.
@MainActor
struct LevelTests {
  @Test(arguments: ["brooklyn-bridge", "test-yard"])
  func levelContentIsWellFormed(name: String) {
    let level = Self.level(named: name)
    #expect(level.id == name)
    #expect(!level.party.isEmpty)
    let bounds = level.bounds
    let obstacles = level.obstacles
    for member in PartyMember.allCases {
      let spawn = level.spawn(member)
      #expect(bounds.contains(spawn), "\(member.rawValue)")
      // Every body, including those who join later, starts clear of the scenery.
      #expect(
        obstacles.allSatisfy {
          distance(from: spawn, to: $0) >= PartyBody.radius + PartyMotion.skin
        }, "\(member.rawValue)")
    }
    for box in [level.ground] + level.boxes {
      #expect(box.size.x > 0 && box.size.y > 0 && box.size.z > 0, "\(box.name)")
    }
    #expect(Set(level.boxes.map(\.name)).count == level.boxes.count)
    #expect(Set(level.points.map(\.id)).count == level.points.count)
    #expect(Set(level.triggers.map(\.id)).count == level.triggers.count)
    for trigger in level.triggers {
      #expect(bounds.contains(trigger.area.minimum), "\(trigger.id)")
      #expect(bounds.contains(trigger.area.maximum), "\(trigger.id)")
      #expect(!trigger.line.isEmpty)
    }
    #expect(simd_length(level.heading) > 0.99)
  }

  /// Checking each obstacle against only the cells near it gives exactly the grid that testing
  /// every cell against every obstacle would.
  @Test(arguments: ["brooklyn-bridge", "test-yard"])
  func gridMatchesTheClearanceRule(name: String) {
    let level = Self.level(named: name)
    let grid = NavigationGrid(level: level)
    let obstacles = level.obstacles
    let clearance = PartyBody.radius + PartyMotion.skin + 0.03
    let origin = level.bounds.minimum + grid.cellSize / 2
    // Every cell in the yard; every seventh along each axis on the much larger bridge.
    let stride = name == TestYard.level.id ? 1 : 7
    for row in Swift.stride(from: 0, to: grid.rows, by: stride) {
      for column in Swift.stride(from: 0, to: grid.columns, by: stride) {
        let centre = origin + SIMD2(Float(column), Float(row)) * grid.cellSize
        let expected = obstacles.allSatisfy { distance(from: centre, to: $0) >= clearance }
        #expect(grid.isWalkable(centre) == expected, "(\(column), \(row))")
      }
    }
  }

  @Test
  func theBridgeConnectsBrooklynToManhattanThroughTheCollapsedDivider() throws {
    let level = BrooklynBridge.level
    let grid = NavigationGrid(level: level)
    let start = level.spawn(.miki)
    let end: SIMD2<Float> = [-7, -502.3]
    #expect(grid.region(at: start) != nil)
    #expect(grid.region(at: start) == grid.region(at: end))
    #expect(grid.route(from: start, to: end) != nil)
    // The bus closes the east roadway from the divider to the railing, so the east lanes beyond
    // it are reached only round the far end, and the gap in the divider is open.
    let gap: SIMD2<Float> = [0, -227.15]
    #expect(grid.isWalkable(gap))
    let motion = PartyMotion(radius: PartyBody.radius, obstacles: level.obstacles)
    let bus = BrooklynBridge.layout.landmark(named: "bridge.bus")
    let divider = BrooklynBridge.layout.box(named: "divider-north")
    let railing = BrooklynBridge.layout.box(named: "railing-east")
    let across = stride(
      from: divider.position.x + divider.size.x / 2,
      through: railing.position.x - railing.size.x / 2, by: 0.05)
    for x in across {
      #expect(
        !motion.canTraverse(from: [x, bus.position.z + 4], to: [x, bus.position.z - 4]),
        "a way past the bus at x = \(x)")
    }
    // The arches are open on both roadways at both towers.
    for z in [BrooklynBridge.brooklynTower, BrooklynBridge.manhattanTower] {
      #expect(motion.canTraverse(from: [7, z + 7], to: [7, z - 7]))
      #expect(motion.canTraverse(from: [-7, z + 7], to: [-7, z - 7]))
    }
  }

  private static func level(named name: String) -> Level {
    name == TestYard.level.id ? TestYard.level : BrooklynBridge.level
  }

  private func distance(from point: SIMD2<Float>, to box: PartyMotion.Box) -> Float {
    let nearest = simd_clamp(point, box.minimum, box.maximum)
    return simd_distance(point, nearest)
  }
}
