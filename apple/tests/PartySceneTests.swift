import RealityKit
import Testing
import simd

@testable import Lauder

@MainActor
struct PartySceneTests {
  @Test
  func renderedSceneryAndMovementUseTheSameAuthoredFootprints() throws {
    let level = BrooklynBridge.level
    let world = GameWorld(level: level)
    let bodies = try PartyMember.allCases.map { member in
      try #require(world.root.findEntity(named: "party.\(member.rawValue)"))
    }
    // Peers, ground and decoration are excluded structurally from the authored obstacle list.
    for body in bodies {
      #expect(body.components[CharacterControllerComponent.self] == nil)
      #expect(body.components[CollisionComponent.self] == nil)
      #expect(body.components[PhysicsBodyComponent.self] == nil)
    }
    // The scenery comes from the bridge's scene file, which BridgeTests checks against the layout
    // file. None of it takes part in physics: movement uses the boxes' authored footprints.
    var scenery = [try #require(world.root.findEntity(named: "brooklyn-bridge.scene"))]
    while let part = scenery.popLast() {
      #expect(part.components[CollisionComponent.self] == nil, "\(part.name) has no collision")
      #expect(part.components[PhysicsBodyComponent.self] == nil, "\(part.name) has no body")
      scenery.append(contentsOf: part.children)
    }
    for box in level.boxes {
      let centre = SIMD2(box.position.x, box.position.z)
      let half = SIMD2(box.size.x, box.size.z) / 2
      #expect(
        level.obstacles.contains {
          $0.minimum == centre - half && $0.maximum == centre + half
        })
    }
    #expect(world.root.components[PhysicsSimulationComponent.self] == nil)
    #expect(level.obstacles.count == level.boxes.count + level.points.count)
    for point in level.points {
      let centre = SIMD2(point.position.x, point.position.z)
      let half = SIMD2(point.size.x, point.size.z) / 2
      #expect(
        level.obstacles.contains {
          $0.minimum == centre - half && $0.maximum == centre + half
        })
    }

    // Changing the leader moves no one.
    let initialPositions = bodies.map(\.position)
    world.session.recruit(.tom)
    world.session.cycleLeader()
    #expect(world.session.leader == .tom)
    #expect(bodies.map(\.position) == initialPositions)
  }
}
