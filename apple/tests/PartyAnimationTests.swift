import RealityKit
import Testing
import simd

@testable import Lauder

/// Real exported skins, rather than animation names alone, establish grounding and grip contact.
@MainActor
struct PartyAnimationTests {
  @MainActor private struct Fixture {
    let body: Entity
    let visual: Entity
    let model: ModelEntity
    let profile: PartyModelClips.Profile
    let geometryBind: simd_float4x4
    let animation: PartyAnimation

    init(_ member: PartyMember) throws {
      body = Entity()
      body.position.y = PartyBody.height / 2
      visual = SceneStyle().partyMember(member)
      body.addChild(visual)
      func find(_ entity: Entity) -> ModelEntity? {
        if let model = entity as? ModelEntity, !model.jointNames.isEmpty { return model }
        return entity.children.compactMap(find).first
      }
      model = try #require(find(visual))
      let profile = try #require(PartyModelClips.profile(for: model.jointNames))
      self.profile = profile
      // The approved Miki intake retains FBX vertices before its USD geomBind. The older
      // simple party meshes store vertices directly in skeleton space.
      geometryBind =
        profile == .miki47
        ? simd_float4x4(
          columns: (
            [1.800879359, 0, 0, 0], [0, 0.000000135963, 1.800879359, 0],
            [0, -1.800879359, 0.000000135963, 0],
            [0, -0.000000067088, 0.000000016630, 1]
          )) : matrix_identity_float4x4
      animation = PartyAnimation(visual: visual)
    }

    func globals() throws -> [simd_float4x4] {
      let skeleton = try #require(model.model?.mesh.contents.skeletons.first)
      var global: [simd_float4x4] = []
      for (index, joint) in skeleton.joints.enumerated() {
        let local = model.jointTransforms[index].matrix
        global.append(joint.parentIndex.map { global[$0] * local } ?? local)
      }
      return global
    }

    func joint(_ name: String, global: [simd_float4x4]) throws -> SIMD3<Float> {
      let index = try #require(model.jointNames.firstIndex { $0.hasSuffix("/" + name) })
      let point = global[index].columns.3
      return model.convert(position: SIMD3(point.x, point.y, point.z), to: visual)
    }

    func grip(left: Bool) -> SIMD3<Float> {
      PartyModelClips.handGrip(left: left, profile: profile)?.offset
        ?? (left ? [-0.07, -0.05, -0.02] : [0, 0, 0.06])
    }

    func bound(_ point: SIMD3<Float>) -> SIMD4<Float> {
      geometryBind * SIMD4(point.x, point.y, point.z, 1)
    }

    func minimumSkinHeight(global: [simd_float4x4]) throws -> Float {
      let mesh = try #require(model.model?.mesh)
      var minimum: Float = .greatestFiniteMagnitude
      for part in mesh.contents.models.flatMap({ Array($0.parts) }) {
        guard let influences = part.jointInfluences else { continue }
        let skeleton = try #require(part.skeletonID.flatMap { mesh.contents.skeletons[$0] })
        let skin = try skeleton.joints.map { joint in
          let index = try #require(model.jointNames.firstIndex(of: joint.name))
          return global[index] * joint.inverseBindPoseMatrix
        }
        let positions = part.positions.elements
        let weights = influences.influences.elements
        let count = weights.count / positions.count
        for (index, position) in positions.enumerated() {
          var point = SIMD4<Float>.zero
          let boundPosition = bound(position)
          for weight in weights[(index * count)..<((index + 1) * count)] {
            point +=
              weight.weight
              * (skin[weight.jointIndex] * boundPosition)
          }
          minimum = min(
            minimum,
            model.convert(position: SIMD3(point.x, point.y, point.z), to: nil).y)
        }
      }
      return minimum
    }

    func bootIntervals(global: [simd_float4x4]) throws -> [(minimum: Float, maximum: Float)] {
      let mesh = try #require(model.model?.mesh)
      let names = ["foot_L", "foot_R"]
      var bounds = Array(
        repeating: (
          minimum: Float.greatestFiniteMagnitude,
          maximum: -Float.greatestFiniteMagnitude
        ), count: 2)
      for part in mesh.contents.models.flatMap({ Array($0.parts) }) {
        guard let influences = part.jointInfluences else { continue }
        let skeleton = try #require(part.skeletonID.flatMap { mesh.contents.skeletons[$0] })
        let feet = try names.map { name -> (index: Int, skin: simd_float4x4)? in
          guard let joint = skeleton.joints.firstIndex(where: { $0.name.hasSuffix("/" + name) })
          else {
            return nil
          }
          let modelJoint = try #require(
            model.jointNames.firstIndex(of: skeleton.joints[joint].name))
          return (joint, global[modelJoint] * skeleton.joints[joint].inverseBindPoseMatrix)
        }
        let positions = part.positions.elements
        let weights = influences.influences.elements
        let count = weights.count / positions.count
        for (index, point) in positions.enumerated() {
          let boundPosition = bound(point)
          for (foot, binding) in feet.enumerated() {
            guard let binding,
              weights[(index * count)..<((index + 1) * count)].contains(where: {
                $0.jointIndex == binding.index && $0.weight > 0.999
              })
            else { continue }
            let p = binding.skin * boundPosition
            let x = model.convert(position: SIMD3(p.x, p.y, p.z), to: visual).x
            bounds[foot].minimum = min(bounds[foot].minimum, x)
            bounds[foot].maximum = max(bounds[foot].maximum, x)
          }
        }
      }
      return bounds
    }
  }

  @Test
  func animationProfilesRequireTheExactNamedSkeletonRatherThanOnlyItsSize() throws {
    for member in PartyMember.allCases {
      let fixture = try Fixture(member)
      let names = fixture.model.jointNames
      #expect(PartyModelClips.profile(for: Array(names.reversed())) == fixture.profile)
      #expect(PartyModelClips.profile(for: Array(names.dropLast())) == nil)
      var unrelated = names
      unrelated[unrelated.count - 1] = "unrelated-joint"
      #expect(PartyModelClips.profile(for: unrelated) == nil)
      #expect(PartyModelClips.profile(for: names + [names[0]]) == nil)
    }
  }

  @Test
  func sourceFramesAreSharedButPoseClocksAndResetAreIndependent() throws {
    let first = try Fixture(.miki)
    let second = try Fixture(.miki)
    #expect(first.model.model?.mesh === second.model.model?.mesh)
    let idle = first.model.jointTransforms
    for _ in 0..<80 {
      first.animation.update(
        velocity: [0, -2.6], facing: 0, weapon: nil,
        fired: false, hit: false, dt: 1 / 120)
    }
    #expect(first.model.jointTransforms != idle)
    #expect(second.model.jointTransforms == idle)
    let frozen = first.model.jointTransforms
    first.animation.update(
      velocity: [2.6, 0], facing: 1, weapon: WeaponPose(),
      fired: true, hit: true, dt: 0)
    #expect(first.model.jointTransforms == frozen)
    first.animation.reset()
    #expect(first.model.jointTransforms == idle)
    #expect(first.body.position == second.body.position)
    #expect(first.visual.transform == second.visual.transform)
  }

  @Test(arguments: [false, true])
  func acceptedFireAndHitsMoveTheTorsoWithinTwoFixedSteps(isHit: Bool) throws {
    let reacting = try Fixture(.laura)
    let control = try Fixture(.laura)
    var weapon = WeaponPose(kind: .lightBurst)
    weapon.fired()
    for frame in 0..<2 {
      // Both figures have the same authoritative weapon kick: only the accepted event differs.
      reacting.animation.update(
        velocity: .zero, facing: 0, weapon: weapon,
        fired: !isHit && frame == 0, hit: isHit && frame == 0, dt: 1 / 120)
      control.animation.update(
        velocity: .zero, facing: 0, weapon: weapon,
        fired: false, hit: false, dt: 1 / 120)
    }
    let chest = try #require(reacting.model.jointNames.firstIndex { $0.hasSuffix("/chest") })
    let reaction = Transform(matrix: try reacting.globals()[chest]).rotation
    let baseline = Transform(matrix: try control.globals()[chest]).rotation
    let difference = reaction * baseline.inverse
    let angle = 2 * atan2(simd_length(difference.imag), abs(difference.real))
    #expect(angle > 0.001)
    #expect(try reacting.minimumSkinHeight(global: reacting.globals()) > -0.002)
    let held = weapon.transform
    #expect(
      simd_distance(
        try reacting.joint("hand_R", global: reacting.globals()),
        held.position + held.orientation.act(reacting.grip(left: false))) < 0.001)
  }

  @Test
  func carbineDrawAndCompleteLoweringKeepMikisMeasuredRightGripReachable() throws {
    let fixture = try Fixture(.miki)
    for velocity: SIMD2<Float> in [.zero, [0, -2.6], [0, -0.65]] {
      fixture.animation.reset()
      var weapon = WeaponPose(kind: .carbine)
      for frame in 0..<390 {
        let aiming = (60..<120).contains(frame) || (240..<300).contains(frame)
        weapon.step(dt: 1 / 60, aiming: aiming)
        fixture.animation.update(
          velocity: velocity, facing: 0, weapon: weapon, fired: false, hit: frame % 79 == 0,
          sneaking: velocity.y == -0.65, dt: 1 / 60)
        let held = weapon.transform
        #expect(
          simd_distance(
            try fixture.joint("hand_R", global: fixture.globals()),
            held.position + held.orientation.act(fixture.grip(left: false))) < 0.001)
      }
      #expect(weapon.raise == 0)
    }
  }

  @Test(arguments: PartyMember.allCases)
  func directionalBlendsAndWeaponTransitionsKeepTheActualSkinGrounded(member: PartyMember) throws {
    let fixture = try Fixture(member)
    let kind = Weapon.forMember(member).kind
    var weapon = WeaponPose(kind: kind)
    let originalBody = fixture.body.transform
    let originalVisual = fixture.visual.transform
    let directions: [SIMD2<Float>] = [
      [0, -2.6], [2.6, 0], [0, 2.6], [-2.6, 0], [1.84, -1.84], [-1.84, 1.84], .zero,
    ]
    for frame in 0..<420 {
      weapon.step(dt: 1 / 120, aiming: (frame / 30) % 2 == 0)
      let fired = frame % 79 == 0
      if fired { weapon.fired() }
      fixture.animation.update(
        velocity: directions[(frame / 60) % directions.count],
        facing: Float(frame) / 150, weapon: weapon, fired: fired, hit: frame % 113 == 0,
        dt: 1 / 120)
      let global = try fixture.globals()
      #expect(try fixture.minimumSkinHeight(global: global) > -0.002)
      let held = weapon.transform
      let wrist = try fixture.joint("hand_R", global: global)
      #expect(
        simd_distance(wrist, held.position + held.orientation.act(fixture.grip(left: false)))
          < 0.001)
      if weapon.raise == 1 {
        let support = try fixture.joint("hand_L", global: global)
        #expect(
          simd_distance(support, held.position + held.orientation.act(fixture.grip(left: true)))
            < 0.001)
      }
    }
    #expect(fixture.body.transform == originalBody)
    #expect(fixture.visual.transform == originalVisual)
  }

  @Test(arguments: PartyMember.allCases)
  func sneakingStaysCrouchedOnReleaseAndCanAimInEveryMovementDirection(member: PartyMember) throws {
    let fixture = try Fixture(member)
    let standing = try fixture.joint("pelvis", global: fixture.globals()).y
    var weapon = WeaponPose(kind: Weapon.forMember(member).kind)
    weapon.fired()
    let directions: [SIMD2<Float>] = [[0, -0.65], [0.65, 0], [0, 0.65], [-0.65, 0], .zero]
    for frame in 0..<300 {
      weapon.step(dt: 1 / 120, aiming: true)
      fixture.animation.update(
        velocity: directions[frame / 60], facing: 0, weapon: weapon,
        fired: false, hit: frame % 79 == 0, sneaking: true, dt: 1 / 120)
      let global = try fixture.globals()
      #expect(try fixture.minimumSkinHeight(global: global) > -0.002)
      if frame > 30 {
        #expect(try fixture.joint("pelvis", global: global).y < standing - 0.1)
      }
      let held = weapon.transform
      #expect(
        simd_distance(
          try fixture.joint("hand_R", global: global),
          held.position + held.orientation.act(fixture.grip(left: false))) < 0.001)
      #expect(
        simd_distance(
          try fixture.joint("hand_L", global: global),
          held.position + held.orientation.act(fixture.grip(left: true))) < 0.001)
    }
    let settled = fixture.model.jointTransforms
    for _ in 0..<30 {
      fixture.animation.update(
        velocity: .zero, facing: 0, weapon: nil,
        fired: false, hit: false, sneaking: true, dt: 1 / 120)
    }
    #expect(try fixture.joint("pelvis", global: fixture.globals()).y < standing - 0.1)
    #expect(fixture.model.jointTransforms != settled)  // the weapon was lowered, not the crouch
    fixture.animation.reset()
    #expect(abs(try fixture.joint("pelvis", global: fixture.globals()).y - standing) < 0.001)
  }

  @Test
  func aWalksPlantedFootCancelsTheActualBodyTravel() throws {
    let fixture = try Fixture(.miki)
    let speed = PartyModelClips.take(for: .walk, profile: fixture.profile).nominalSpeed
    for _ in 0..<60 {
      fixture.animation.update(
        velocity: [0, -speed], facing: 0, weapon: nil,
        fired: false, hit: false, dt: 1 / 120)
    }
    var previous = try fixture.globals()
    for _ in 0..<120 {
      fixture.body.position.z -= speed / 120
      fixture.animation.update(
        velocity: [0, -speed], facing: 0, weapon: nil,
        fired: false, hit: false, dt: 1 / 120)
      let current = try fixture.globals()
      // Coordinates relative to visual exclude body travel; add that accepted displacement.
      let motion = try ["foot_L", "foot_R"].map { name in
        let now = try fixture.joint(name, global: current)
        let before = try fixture.joint(name, global: previous)
        return simd_distance(now + SIMD3(0, 0, -speed / 120), before)
      }
      #expect(try #require(motion.min()) < 0.001)
      previous = current
    }
  }

  @Test(arguments: PartyMember.allCases)
  func sidewaysAndDiagonalSneakStepsKeepTheExportedBootsApart(member: PartyMember) throws {
    let fixture = try Fixture(member)
    for direction in [
      SIMD2<Float>(1, 0), [-1, 0], [0.707, 0.707], [-0.707, -0.707],
      [0.707, -0.707], [-0.707, 0.707],
    ] {
      fixture.animation.reset()
      for frame in 0..<180 {
        fixture.animation.update(
          velocity: direction * 0.65, facing: 0, weapon: nil,
          fired: false, hit: false, sneaking: true, dt: 1 / 120)
        if frame > 30 && frame % 3 == 0 {
          let boots = try fixture.bootIntervals(global: fixture.globals())
          #expect(boots[0].maximum < boots[1].minimum || boots[1].maximum < boots[0].minimum)
        }
      }
    }
  }
}
