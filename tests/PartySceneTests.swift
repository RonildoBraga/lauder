import RealityKit
import Testing
import simd

@testable import Lauder

@MainActor
struct PartySceneTests {
  @Test
  func renderedSceneryAndMovementUseTheSameAuthoredFootprints() throws {
    let world = GameWorld(level: RelayHouse.level)
    let bodies = try PartyMember.allCases.map { member in
      try #require(world.root.findEntity(named: "party.\(member.rawValue)"))
    }
    // Peers, ground and decoration are excluded structurally from the authored obstacle list.
    for body in bodies {
      #expect(body.components[CharacterControllerComponent.self] == nil)
      #expect(body.components[CollisionComponent.self] == nil)
      #expect(body.components[PhysicsBodyComponent.self] == nil)
    }
    for box in RelayHouse.boxes {
      let entity = try #require(world.root.findEntity(named: box.name))
      #expect(entity.components[CollisionComponent.self] == nil)
      #expect(entity.components[PhysicsBodyComponent.self] == nil)
      #expect(entity.position == box.position)
      if box.name == RelayHouse.BoxID.ground.rawValue { continue }
      let centre = SIMD2(box.position.x, box.position.z)
      let half = SIMD2(box.size.x, box.size.z) / 2
      #expect(
        RelayHouse.obstacles.contains {
          $0.minimum == centre - half && $0.maximum == centre + half
        })
    }
    #expect(world.root.components[PhysicsSimulationComponent.self] == nil)
    #expect(RelayHouse.obstacles.count == RelayHouse.boxes.count - 1 + 2)
    for point in RelayHouse.points {
      let entity = try #require(world.root.findEntity(named: point.id))
      let size = point.size
      let centre = SIMD2(entity.position.x, entity.position.z)
      let half = SIMD2(size.x, size.z) / 2
      #expect(
        RelayHouse.obstacles.contains {
          $0.minimum == centre - half && $0.maximum == centre + half
        })
    }
    #expect(world.root.findEntity(named: "relay.tom") == nil)
    #expect(world.root.findEntity(named: "relay.transmitter") != nil)
    #expect(world.root.findEntity(named: "depot.regulator") != nil)

    let initialPositions = bodies.map(\.position)
    world.session.cycleLeader()
    #expect(world.session.leader == .laura)
    #expect(bodies.map(\.position) == initialPositions)
  }
}
