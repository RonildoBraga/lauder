import Testing
import simd

@testable import Lauder

/// Both levels are well-formed content, and the navigation grid built from them matches the
/// rule it is meant to apply.
@MainActor
struct LevelTests {
  @Test(arguments: Level.ID.allCases)
  func levelContentIsWellFormed(id: Level.ID) {
    let level = Level.level(id)
    #expect(level.id == id)
    #expect(!level.party.isEmpty)
    let bounds = level.bounds
    let obstacles = level.obstacles(passageOpen: false)
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
  @Test(arguments: Level.ID.allCases)
  func gridMatchesTheClearanceRule(id: Level.ID) {
    let level = Level.level(id)
    let grid = NavigationGrid(level: level, passageOpen: false)
    let obstacles = level.obstacles(passageOpen: false)
    let clearance = PartyBody.radius + PartyMotion.skin + 0.03
    let origin = level.bounds.minimum + grid.cellSize / 2
    // Every cell at Relay House; every seventh along each axis on the much larger bridge.
    let stride = id == .relayHouse ? 1 : 7
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
    let grid = NavigationGrid(level: level, passageOpen: false)
    let start = level.spawn(.miki)
    let end: SIMD2<Float> = [-7, -108]
    #expect(grid.region(at: start) != nil)
    #expect(grid.region(at: start) == grid.region(at: end))
    #expect(grid.route(from: start, to: end) != nil)
    // The bus closes the east roadway, so the east lanes beyond it are reached only round the
    // far end, and the gap in the divider is open.
    let gap: SIMD2<Float> = [0, -30]
    #expect(grid.isWalkable(gap))
    let motion = PartyMotion(
      radius: PartyBody.radius, obstacles: level.obstacles(passageOpen: true))
    #expect(!motion.canTraverse(from: [7, -38], to: [7, -46]))
    // The arches are open on both roadways at both towers.
    for z in [BrooklynBridge.brooklynTower, BrooklynBridge.manhattanTower] {
      #expect(motion.canTraverse(from: [7, z + 7], to: [7, z - 7]))
      #expect(motion.canTraverse(from: [-7, z + 7], to: [-7, z - 7]))
    }
  }

  @Test
  func relayHouseKeepsItsLayout() {
    let level = RelayHouse.level
    #expect(level.party == [.miki, .laura, .tom])
    #expect(level.triggers.isEmpty)
    #expect(level.passage != nil)
    #expect(level.obstacles(passageOpen: true).count == RelayHouse.boxes.count - 1 + 2)
    #expect(
      level.obstacles(passageOpen: false).count == level.obstacles(passageOpen: true).count + 1)
    #expect(level.objective == nil && level.lookAround == nil)
  }

  private func distance(from point: SIMD2<Float>, to box: PartyMotion.Box) -> Float {
    let nearest = simd_clamp(point, box.minimum, box.maximum)
    return simd_distance(point, nearest)
  }
}
