import RealityKit
import Testing
import simd

@testable import Lauder

/// Exercise the real exported skins through GameWorld, rather than a second animation clock.
@MainActor
struct PartyAnimationIntegrationTests {
  @Test
  func worldsShareResourcesButKeepIndependentJointPoses() throws {
    let moving = GameWorld(level: TestYard.level)
    let still = GameWorld(level: TestYard.level)
    let first = try skin(.miki, in: moving)
    let second = try skin(.miki, in: still)
    let untouched = second.jointTransforms
    #expect(first.jointNames.count == 17 && second.jointNames == first.jointNames)
    #expect(first.model?.mesh === second.model?.mesh)
    for member in PartyMember.allCases {
      #expect(try skin(member, in: moving).jointNames.count == 17)
    }
    let input = stick(moving, towards: [0, -1])
    for _ in 0..<24 { moving.advanceParty(movement: input, deltaTime: 1 / 60) }
    #expect(first.jointTransforms != untouched)
    #expect(second.jointTransforms == untouched)
  }

  @Test
  func pauseReleaseGateAndStoppedPresentationHaveNoAnimationCatchUp() throws {
    let world = GameWorld(level: TestYard.level)
    let model = try skin(.miki, in: world)
    let initial = model.jointTransforms
    let input = stick(world, towards: [0, -1])
    for _ in 0..<18 { world.advanceParty(movement: input, deltaTime: 1 / 60) }
    pressPause(world)
    let frozen = model.jointTransforms
    for _ in 0..<60 {
      world.advanceParty(movement: input, deltaTime: 1 / 60)
      world.update(with: .neutral, sampledIn: .paused, deltaTime: 1 / 60)
    }
    #expect(model.jointTransforms == frozen)
    pressPause(world)
    for _ in 0..<60 {
      world.update(with: .neutral, sampledIn: .exploring, deltaTime: 1 / 60, inputReady: false)
    }
    #expect(model.jointTransforms == frozen)
    world.setApplicationActive(false)
    world.stop()
    world.step(deltaTime: 30)
    #expect(model.jointTransforms == frozen)
    world.restart()
    #expect(model.jointTransforms == initial)
  }

  @Test
  func heldMovementAgainstARealWallDoesNotKeepCyclingTheFeet() throws {
    let world = GameWorld(level: TestYard.level)
    #expect(world.session.holdAll())
    walk(world, to: [-8, 0.45])
    let input = stick(world, towards: [0, -1])
    for _ in 0..<120 { world.advanceParty(movement: input, deltaTime: 1 / 60) }
    let stopped = position(world, .miki)
    let model = try skin(.miki, in: world)
    let planted = try feet(of: model)
    for _ in 0..<60 {
      world.advanceParty(movement: input, deltaTime: 1 / 60)
      #expect(simd_distance(position(world, .miki), stopped) < 0.0001)
      let current = try feet(of: model)
      #expect(zip(current, planted).allSatisfy { simd_distance($0, $1) < 0.001 })
    }
  }

  @Test
  func lightInputMovesCautiouslyAndKeepsTheCrouchUntilFirmMovement() throws {
    let world = GameWorld(level: TestYard.level)
    #expect(world.session.holdAll())
    let model = try skin(.miki, in: world)
    let initialPelvis = try joint("pelvis", of: model)
    let start = position(world, .miki)
    let input = stick(world, towards: [0, -1])
    for _ in 0..<60 { world.advanceParty(movement: input * 0.3, deltaTime: 1 / 60) }
    #expect(simd_distance(position(world, .miki), start) < Movement.sneakSpeed + 0.01)
    #expect(simd_distance(position(world, .miki), start) > 0.3)
    for _ in 0..<30 { world.advanceParty(movement: .zero, deltaTime: 1 / 60) }
    let crouched = try joint("pelvis", of: model)
    #expect(crouched.y < initialPelvis.y - 0.05)
    for _ in 0..<30 { world.advanceParty(movement: input, deltaTime: 1 / 60) }
    // Running also compresses the legs during its stride. Check the settled standing pose,
    // rather than treating one arbitrary running frame as the character's standing height.
    for _ in 0..<30 { world.advanceParty(movement: .zero, deltaTime: 1 / 60) }
    #expect(try joint("pelvis", of: model).y > crouched.y + 0.05)
  }

  private func skin(_ member: PartyMember, in world: GameWorld) throws -> ModelEntity {
    var pending = [try #require(world.root.findEntity(named: "party.\(member.rawValue)"))]
    while let entity = pending.popLast() {
      if let model = entity as? ModelEntity, !model.jointNames.isEmpty { return model }
      pending.append(contentsOf: entity.children)
    }
    throw MissingSkin()
  }

  private func feet(of model: ModelEntity) throws -> [SIMD3<Float>] {
    try [joint("foot_L", of: model), joint("foot_R", of: model)]
  }

  private func joint(_ name: String, of model: ModelEntity) throws -> SIMD3<Float> {
    let skeleton = try #require(model.model?.mesh.contents.skeletons.first)
    let index = try #require(model.jointNames.firstIndex { $0 == name || $0.hasSuffix("/\(name)") })
    var transforms: [simd_float4x4] = []
    for (index, joint) in skeleton.joints.enumerated() {
      let local = model.jointTransforms[index].matrix
      transforms.append(joint.parentIndex.map { transforms[$0] * local } ?? local)
    }
    let origin = transforms[index].columns.3
    return model.convert(position: SIMD3(origin.x, origin.y, origin.z), to: nil)
  }

  private struct MissingSkin: Error {}
}
