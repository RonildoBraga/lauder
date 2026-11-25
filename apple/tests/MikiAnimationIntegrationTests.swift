import RealityKit
import Testing
import simd

@testable import Lauder

/// Exercise the promoted Miki skin through the ordinary world/input path. Shared resources
/// must not share mutable joint or garment state with another actor or world.
@MainActor
struct MikiAnimationIntegrationTests {
  @Test
  func mixedSkeletonPartyRetainsSkinBoundFingersAcrossLeaderChanges() throws {
    let world = GameWorld(level: TestRange.practice)
    let miki = try skin(.miki, in: world)
    #expect(miki.jointNames.count == 47)
    for member in [PartyMember.tom, .laura] {
      #expect(try skin(member, in: world).jointNames.count == 17)
    }

    let expectedDigits = Set(
      ["L", "R"].flatMap { side in
        ["thumb", "index", "middle", "ring", "pinky"].flatMap { digit in
          (1...3).map { "\(digit)_0\($0)_\(side)" }
        }
      })
    let mesh = try #require(miki.model?.mesh)
    var influenced = Set<String>()
    for part in mesh.contents.models.flatMap({ Array($0.parts) }) {
      guard let influences = part.jointInfluences else { continue }
      let skeletonID = try #require(part.skeletonID)
      let skeleton = try #require(mesh.contents.skeletons[skeletonID])
      for influence in influences.influences.elements where influence.weight > 0.00001 {
        try #require(skeleton.joints.indices.contains(influence.jointIndex))
        influenced.insert(leaf(skeleton.joints[influence.jointIndex].name))
      }
    }
    #expect(expectedDigits.isSubset(of: influenced))

    step(world, frames: 3)
    step(world, raw: InputRules.Raw(keyboardSwitch: true))
    #expect(world.session.leader == .tom)
    step(world)
    step(world, raw: InputRules.Raw(up: true), frames: 15)
    let tom = try skin(.tom, in: world)
    #expect(tom.jointTransforms.count == 17)
    #expect(tom.jointTransforms.allSatisfy(finite))
    step(world)
    step(world, raw: InputRules.Raw(keyboardPrevious: true))
    #expect(world.session.leader == .miki)
    #expect(miki.jointTransforms.count == 47)
    #expect(miki.jointTransforms.allSatisfy(finite))
  }

  @Test
  func keyboardSneakUpdatesOnlyItsOwnGarmentAndPauseAndRestartPreserveAuthority() throws {
    let world = GameWorld(level: TestYard.level)
    let untouchedWorld = GameWorld(level: TestYard.level)
    let miki = try skin(.miki, in: world)
    let untouched = try skin(.miki, in: untouchedWorld)
    let originalPose = miki.jointTransforms
    let originalGarment = try garment(of: miki)
    let untouchedPose = untouched.jointTransforms
    let untouchedGarment = try garment(of: untouched)
    #expect(originalGarment.count == 4)
    #expect(miki.model?.mesh === untouched.model?.mesh)

    step(world, frames: 3)
    step(world, raw: InputRules.Raw(up: true, keyboardSneak: true), frames: 60)
    let movingGarment = try garment(of: miki)
    #expect(movingGarment.values.contains { $0 > 0.1 })
    #expect(movingGarment.values.allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 })
    #expect(untouched.jointTransforms == untouchedPose)
    #expect(try garment(of: untouched) == untouchedGarment)

    step(world, raw: InputRules.Raw(keyboardPause: true))
    #expect(world.session.mode == .paused)
    let frozenPose = miki.jointTransforms
    let frozenGarment = try garment(of: miki)
    _ = world.takeCombatEvents()
    step(
      world, raw: InputRules.Raw(up: true, keyboardSneak: true, keyboardFire: true),
      frames: 45)
    #expect(miki.jointTransforms == frozenPose)
    #expect(try garment(of: miki) == frozenGarment)
    #expect(world.takeCombatEvents().isEmpty)

    step(world, frames: 3)
    step(world, raw: InputRules.Raw(keyboardPause: true))
    #expect(world.session.mode == .exploring)
    step(world, frames: 3)
    world.restart()
    #expect(miki.jointTransforms == originalPose)
    #expect(try garment(of: miki) == originalGarment)
    #expect(untouched.jointTransforms == untouchedPose)
    #expect(try garment(of: untouched) == untouchedGarment)
  }

  @Test
  func anAcceptedNativeShotArticulatesTheIndexComparedWithTheSameAimWithoutFire() throws {
    let firing = GameWorld(level: TestRange.practice)
    let aiming = GameWorld(level: TestRange.practice)
    let firingSkin = try skin(.miki, in: firing)
    let aimingSkin = try skin(.miki, in: aiming)
    let index = try #require(firingSkin.jointNames.firstIndex { leaf($0) == "index_01_R" })
    #expect(aimingSkin.jointNames == firingSkin.jointNames)
    for world in [firing, aiming] {
      step(world, frames: 3)
      step(world, raw: InputRules.Raw(aimUp: true), frames: 45)
      _ = world.takeCombatEvents()
    }

    var acceptedShots = 0
    var maximumIndexDifference: Float = 0
    for _ in 0..<30 {
      step(firing, raw: InputRules.Raw(keyboardFire: true, aimUp: true))
      step(aiming, raw: InputRules.Raw(aimUp: true))
      acceptedShots +=
        firing.takeCombatEvents().filter {
          if case .fired(.carbine, _, true) = $0 { true } else { false }
        }.count
      #expect(aiming.takeCombatEvents().isEmpty)
      let alignment = abs(
        simd_dot(
          aimingSkin.jointTransforms[index].rotation.vector,
          firingSkin.jointTransforms[index].rotation.vector))
      maximumIndexDifference = max(maximumIndexDifference, 2 * acos(min(1, alignment)))
    }
    #expect(acceptedShots > 0)
    #expect(maximumIndexDifference > .pi / 180)
  }

  @Test
  func measuredPalmsFaceAndTouchTheActualCarbineThroughCarryAimAndAcceptedRecoil() throws {
    let world = GameWorld(level: TestRange.practice)
    let model = try skin(.miki, in: world)
    let weapon = try #require(world.root.findEntity(named: "leader.carbine"))
    let palms = try palmSamples(of: model)
    #expect(palms.left.count > 3 && palms.right.count > 3)
    step(world, frames: 3)
    step(world, raw: InputRules.Raw(aimUp: true), frames: 60)
    try #require(world.weaponDrawn && weapon.isEnabled)
    try expectPalmContact(model, weapon: weapon, samples: palms.right, side: "R")
    try expectPalmContact(model, weapon: weapon, samples: palms.left, side: "L")

    // A never-drawn weapon is hidden and has no grip to verify. Inspect low carry only after
    // ordinary draw, the weapon's hold interval and its complete lowering transition.
    step(world, frames: 90)
    try #require(weapon.isEnabled)
    try expectPalmContact(model, weapon: weapon, samples: palms.right, side: "R")
    step(world, raw: InputRules.Raw(aimUp: true), frames: 60)

    var accepted = false
    for _ in 0..<18 {
      step(world, raw: InputRules.Raw(keyboardFire: true, aimUp: true))
      accepted =
        accepted
        || world.takeCombatEvents().contains {
          if case .fired(.carbine, _, true) = $0 { true } else { false }
        }
      if accepted {
        try expectPalmContact(model, weapon: weapon, samples: palms.right, side: "R")
        try expectPalmContact(model, weapon: weapon, samples: palms.left, side: "L")
      }
    }
    #expect(accepted)
  }

  private struct PalmSample {
    let bound: SIMD4<Float>
    let influences: [(index: Int, weight: Float)]
    let skeleton: MeshResource.Skeleton
  }

  /// Independent measurements from approved source 899ebf7f, not the runtime grip helper.
  /// Native position buffers retain FBX coordinates: its measured geomBind precedes LBS.
  private var approvedGeometryBind: simd_float4x4 {
    simd_float4x4(
      columns: (
        [1.800879359, 0, 0, 0], [0, 0.000000135963, 1.800879359, 0],
        [0, -1.800879359, 0.000000135963, 0],
        [0, -0.000000067088, 0.000000016630, 1]
      ))
  }

  private func palmSamples(of model: ModelEntity) throws -> (
    left: [PalmSample], right: [PalmSample]
  ) {
    let mesh = try #require(model.model?.mesh)
    var left: [PalmSample] = []
    var right: [PalmSample] = []
    for part in mesh.contents.models.flatMap({ Array($0.parts) }) {
      guard let influences = part.jointInfluences else { continue }
      let skeletonID = try #require(part.skeletonID)
      let skeleton = try #require(mesh.contents.skeletons[skeletonID])
      let positions = part.positions.elements
      let weights = influences.influences.elements
      try #require(!positions.isEmpty && weights.count.isMultiple(of: positions.count))
      let count = weights.count / positions.count
      for (index, position) in positions.enumerated() {
        let bound = approvedGeometryBind * SIMD4(position.x, position.y, position.z, 1)
        guard abs(bound.x) > 0.25 && bound.z > 0.89 && bound.z < 0.955 else { continue }
        let skinWeights = weights[(index * count)..<((index + 1) * count)].map {
          (index: $0.jointIndex, weight: $0.weight)
        }.filter { $0.weight > 0 }
        try #require(skinWeights.allSatisfy { skeleton.joints.indices.contains($0.index) })
        let side = bound.x > 0 ? "L" : "R"
        let handWeight = skinWeights.reduce(Float(0)) { total, influence in
          total
            + (leaf(skeleton.joints[influence.index].name) == "hand_\(side)"
              ? influence.weight : 0)
        }
        guard handWeight > 0.75 else { continue }
        let sample = PalmSample(bound: bound, influences: skinWeights, skeleton: skeleton)
        if side == "L" { left.append(sample) } else { right.append(sample) }
      }
    }
    return (left, right)
  }

  private func expectPalmContact(
    _ model: ModelEntity, weapon: Entity, samples: [PalmSample], side: String
  ) throws {
    let skeleton = try #require(samples.first?.skeleton)
    try #require(samples.allSatisfy { $0.skeleton.id == skeleton.id })
    var current: [simd_float4x4] = []
    for joint in skeleton.joints {
      let index = try #require(model.jointNames.firstIndex { $0 == joint.name })
      let local = model.jointTransforms[index].matrix
      current.append(joint.parentIndex.map { current[$0] * local } ?? local)
    }
    let hand = try #require(skeleton.joints.firstIndex { leaf($0.name) == "hand_\(side)" })
    // Imported rest transforms can describe an authored idle pose rather than the bind pose.
    // The actual skin derivative, also used for the vertices below, transports these measured
    // bound-space glove directions; using an inverse rest pose would falsely invert the thumb.
    let rotation = current[hand] * skeleton.joints[hand].inverseBindPoseMatrix
    // These normals and index-to-pinky directions were measured on the actual approved glove.
    let palm = SIMD3<Float>(side == "R" ? 0.9476937 : -0.9476937, -0.0252304, -0.3181824)
    let across = SIMD3<Float>(side == "R" ? 0.0356781 : -0.0356781, 0.9989972, 0.0270500)
    func direction(_ vector: SIMD3<Float>) -> SIMD3<Float> {
      let v = rotation * SIMD4(vector.x, vector.y, vector.z, 0)
      return simd_normalize(model.convert(direction: SIMD3(v.x, v.y, v.z), to: weapon))
    }
    let normal = direction(palm)
    let thumbSide = direction(-across)
    if side == "R" {
      #expect(simd_dot(normal, [-1, 0, 0]) > 0.9)
      #expect(simd_dot(thumbSide, [0, 1, 0]) > 0.5)
    } else {
      #expect(simd_dot(normal, [0, 1, 0]) > 0.9)
      #expect(simd_dot(thumbSide, [0, 0, -1]) > 0.5)
    }

    let bounds = weapon.visualBounds(relativeTo: weapon)
    var closest: Float = .greatestFiniteMagnitude
    var deepest: Float = 0
    for sample in samples {
      var point = SIMD4<Float>.zero
      for influence in sample.influences where influence.weight > 0 {
        point +=
          influence.weight
          * (current[influence.index]
            * sample.skeleton.joints[influence.index].inverseBindPoseMatrix * sample.bound)
      }
      let local = model.convert(position: SIMD3(point.x, point.y, point.z), to: weapon)
      let nearest = simd_clamp(local, bounds.min, bounds.max)
      closest = min(closest, simd_distance(local, nearest))
      let inset = simd_min(local - bounds.min, bounds.max - local)
      deepest = max(deepest, min(inset.x, min(inset.y, inset.z)))
    }
    #expect(closest < 0.015, "\(side) palm is \(closest) m from the actual carbine bounds")
    #expect(deepest < 0.003, "\(side) palm penetrates the solid carbine by \(deepest) m")
  }

  private func step(
    _ world: GameWorld, raw: InputRules.Raw = InputRules.Raw(), frames: Int = 1
  ) {
    for _ in 0..<frames {
      let mode = world.session.mode
      world.update(
        with: world.controls.resolve(raw, mode: mode), sampledIn: mode, deltaTime: 1 / 60)
    }
  }

  private func skin(_ member: PartyMember, in world: GameWorld) throws -> ModelEntity {
    var pending = [try #require(world.root.findEntity(named: "party.\(member.rawValue)"))]
    while let entity = pending.popLast() {
      if let model = entity as? ModelEntity, !model.jointNames.isEmpty { return model }
      pending.append(contentsOf: entity.children)
    }
    throw MissingSkin()
  }

  private func garment(of model: ModelEntity) throws -> [String: Float] {
    let component = try #require(model.components[BlendShapeWeightsComponent.self])
    var values: [String: Float] = [:]
    for set in component.weightSet {
      for (name, value) in zip(set.weightNames, set.weights) { values[name] = value }
    }
    return values
  }

  private func leaf(_ name: String) -> String {
    name.split(separator: "/").last.map(String.init) ?? name
  }

  private func finite(_ transform: Transform) -> Bool {
    let matrix = transform.matrix
    return (0..<4).allSatisfy { column in
      (0..<4).allSatisfy { row in matrix[column][row].isFinite }
    }
  }

  private struct MissingSkin: Error {}
}
