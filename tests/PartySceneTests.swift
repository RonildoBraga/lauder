import RealityKit
import Testing

@testable import Lauder

@MainActor
struct PartySceneTests {
  @Test
  func partyBodiesStayOutOfTheScenerySweep() throws {
    let world = GameWorld()
    let bodies = try PartyMember.allCases.map { member in
      try #require(world.root.findEntity(named: "party.\(member.rawValue)"))
    }
    // Plain body transforms never enter a sweep against world colliders, so peer exclusion
    // does not depend on CharacterController's runtime character-pair filtering.
    for body in bodies {
      #expect(body.components[CharacterControllerComponent.self] == nil)
      #expect(body.components[CollisionComponent.self] == nil)
      #expect(body.components[PhysicsBodyComponent.self] == nil)
    }
    for box in PrototypeLayout.boxes {
      let entity = try #require(world.root.findEntity(named: box.name))
      let collision = try #require(entity.components[CollisionComponent.self])
      #expect(
        collision.filter.group.intersection(GameWorld.obstacleGroup).isEmpty
          == (box.id == .ground))
      if box.id != .ground {
        #expect(box.position.y - box.size.y / 2 <= PrototypeLayout.obstacleSweepHeight)
        #expect(box.position.y + box.size.y / 2 >= PrototypeLayout.obstacleSweepHeight)
      }
    }
    #expect(world.root.findEntity(named: "relay.tomas") == nil)
    #expect(world.root.findEntity(named: "relay.transmitter") != nil)
    #expect(world.root.findEntity(named: "depot.regulator") != nil)

    let initialPositions = bodies.map(\.position)
    world.session.cycleLeader()
    #expect(world.session.leader == .lara)
    #expect(bodies.map(\.position) == initialPositions)
  }
}
