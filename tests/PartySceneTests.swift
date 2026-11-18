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
    for box in [level.ground] + level.boxes {
      let entity = try #require(world.root.findEntity(named: box.name))
      #expect(entity.components[CollisionComponent.self] == nil)
      #expect(entity.components[PhysicsBodyComponent.self] == nil)
      #expect(entity.position == box.position)
      if box.name == level.ground.name { continue }
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
      let entity = try #require(world.root.findEntity(named: point.id))
      let size = point.size
      let centre = SIMD2(entity.position.x, entity.position.z)
      let half = SIMD2(size.x, size.z) / 2
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
