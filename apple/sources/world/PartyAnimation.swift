import Foundation
import RealityKit
import simd

/// A party member's presentation, driven only by accepted simulation steps. The exported clips
/// supply the body motion; neither an animation player nor root motion can move the character.
@MainActor
final class PartyAnimation {
  private typealias Clip = PartyModelClips.Clip
  private static let movement: [Clip] = [
    .idle, .walk, .jog, .run, .backward, .strafeLeft, .strafeRight, .sneak,
  ]
  private static var sources: [ObjectIdentifier: Source] = [:]
  private let visual: Entity
  private let model: ModelEntity
  private let source: Source
  private var weights: [Float] = [1, 0, 0, 0, 0, 0, 0, 0]
  private var phase: Double = 0
  private var elapsed: Double = 0
  private var fireTime: Double?
  private var hitTime: Double?
  private var sneakDirection = SIMD2<Float>(0, 1)
  private var sneakMovement: Float = 0

  init(visual: Entity) {
    self.visual = visual
    guard let model = Self.skeletalModel(in: visual), let mesh = model.model?.mesh else {
      fatalError("The party model has no skeletal mesh")
    }
    self.model = model
    let key = ObjectIdentifier(mesh)
    if let source = Self.sources[key] {
      self.source = source
    } else {
      let source = Source(model: model)
      Self.sources[key] = source
      self.source = source
    }
    reset()
  }

  /// Also used while Laura is lying down: the outer figure owns that pose, with no gait clock.
  func reset() {
    weights = [1, 0, 0, 0, 0, 0, 0, 0]
    phase = 0
    elapsed = 0
    fireTime = nil
    hitTime = nil
    sneakDirection = [0, 1]
    sneakMovement = 0
    model.jointTransforms = source.pose(.idle, time: 0)
  }

  /// Velocity is the final resolved world-ground [x,z] displacement per second, facing is the
  /// figure's yaw. A zero-duration update is deliberately inert, including one-shot events.
  func update(
    velocity: SIMD2<Float>, facing: Float, weapon: WeaponPose?, fired: Bool, hit: Bool,
    sneaking: Bool = false, dt: Float
  ) {
    guard dt > 0, dt.isFinite, velocity.x.isFinite, velocity.y.isFinite, facing.isFinite else {
      return
    }
    let forward = SIMD2<Float>(-sin(facing), -cos(facing))
    let right = SIMD2(-forward.y, forward.x)
    let local = SIMD2(simd_dot(velocity, right), simd_dot(velocity, forward))
    let speed = simd_length(local)
    if sneaking && speed > 0.001 { sneakDirection = local / speed }
    let moving = min(1, speed / 0.12)
    sneakMovement += max(-dt / 0.1, min(dt / 0.1, moving - sneakMovement))
    let target = Self.movementWeights(velocity: local, sneaking: sneaking)
    // Bounded steps reach a settled pose in finite time, including an actual blocked stop.
    for index in weights.indices {
      let difference = target[index] - weights[index]
      weights[index] += max(-dt / 0.14, min(dt / 0.14, difference))
    }
    let total = weights.reduce(0, +)
    weights = weights.map { $0 / total }
    let stride = zip(Self.movement, target).reduce(Float(0)) { sum, item in
      let take = PartyModelClips.take(for: item.0)
      return sum + item.1 * take.nominalSpeed * Float(take.duration)
    }
    if stride > 0.0001 {
      phase = (phase + Double(speed * dt / stride)).truncatingRemainder(dividingBy: 1)
    }
    elapsed += Double(dt)
    if fired { fireTime = PartyModelClips.take(for: .fire).eventStart }
    if hit { hitTime = PartyModelClips.take(for: .hit).eventStart }
    var samples: [([Transform], Float)] = []
    for (index, clip) in Self.movement.enumerated() where weights[index] > 0 {
      let time = clip == .idle ? elapsed : phase * PartyModelClips.take(for: clip).duration
      var sampled = source.pose(clip, time: time)
      if clip == .sneak {
        let resting = source.pose(.sneak, time: 0)
        let restFeet = source.globals(resting)
        let movingFeet = source.globals(sampled)
        sampled = Self.blend([
          (resting, 1 - sneakMovement),
          (sampled, sneakMovement),
        ])
        let direction = source.right * sneakDirection.x + source.forward * sneakDirection.y
        for leg in source.legs {
          let rest = source.restGlobal[leg.end]
          let planted = simd_mix(
            Self.position(restFeet[leg.end]),
            Self.position(movingFeet[leg.end]), SIMD3(repeating: sneakMovement))
          let delta = planted - rest.translation
          let side: Float = simd_dot(rest.translation, source.right) > 0 ? 1 : -1
          // Projecting a forward sneak sideways would cross the other boot. Widen the lateral
          // stance enough for Tom's boots without changing either foot's floor height.
          let spacing = source.right * side * 0.12 * abs(sneakDirection.x)
          let ankle =
            rest.translation + spacing + direction * simd_dot(delta, source.forward)
            + source.up * simd_dot(delta, source.up)
          source.solve(
            leg, target: ankle, endRotation: rest.rotation,
            pole: source.forward, pose: &sampled)
        }
      }
      samples.append((sampled, weights[index]))
    }
    var pose = Self.blend(samples)
    // Blending joint rotations alone shortens a planted leg. Preserve the sampled ankle
    // positions instead, then solve the same two rigid segments with the imported rest lengths.
    let globals = samples.map { (source.globals($0.0), $0.1) }
    for leg in source.legs {
      let ankle = globals.reduce(SIMD3<Float>.zero) { $0 + Self.position($1.0[leg.end]) * $1.1 }
      source.solve(
        leg, target: ankle, endRotation: source.restGlobal[leg.end].rotation,
        pole: source.forward, pose: &pose)
    }
    if let weapon {
      let aim = source.pose(.aim, time: elapsed)
      let first = source.pose(.aim, time: 0)
      for index in source.arms {
        pose[index] = Self.mix(pose[index], aim[index], amount: weapon.raise)
      }
      // Retain the gait's torso lean: straightening a low sneak would lose support-arm reach.
      for index in source.torso {
        let delta = first[index].rotation.inverse * aim[index].rotation
        pose[index].rotation *= simd_slerp(simd_quatf(), delta, weapon.raise)
      }
    }
    applyReaction(.fire, time: fireTime, pose: &pose)
    applyReaction(.hit, time: hitTime, pose: &pose)
    if let weapon { hold(weapon, pose: &pose) }
    model.jointTransforms = pose
    fireTime = advanced(fireTime, clip: .fire, dt: dt)
    hitTime = advanced(hitTime, clip: .hit, dt: dt)
  }

  private func advanced(_ time: Double?, clip: Clip, dt: Float) -> Double? {
    guard let time, time + Double(dt) < PartyModelClips.take(for: clip).duration else { return nil }
    return time + Double(dt)
  }

  private func applyReaction(_ clip: Clip, time: Double?, pose: inout [Transform]) {
    guard let time else { return }
    let first = source.pose(clip, time: 0)
    let reaction = source.pose(clip, time: time)
    // Reactions affect the torso, never the grounded legs or the gameplay-owned weapon.
    for index in source.torso {
      pose[index].rotation *= first[index].rotation.inverse * reaction[index].rotation
    }
  }

  private func hold(_ weapon: WeaponPose, pose: inout [Transform]) {
    let held = weapon.transform
    func point(_ offset: SIMD3<Float>) -> SIMD3<Float> {
      model.convert(position: held.position + held.orientation.act(offset), from: visual)
    }
    let forward = simd_normalize(
      model.convert(direction: held.orientation.act([0, 0, -1]), from: visual))
    let up = simd_normalize(
      model.convert(direction: held.orientation.act([0, 1, 0]), from: visual))
    let hand = Self.frame(direction: forward, hint: up)
    // The wrist sits behind the grip so the palm, rather than the wrist joint, meets it.
    source.solve(
      source.rightArm, target: point([0, 0, 0.06]), endRotation: hand,
      pole: source.right - source.up * 0.5 - source.forward * 0.05, pose: &pose)
    // A hip-height rifle cannot have a cross-body support grip with these human arm lengths.
    // Carry it one-handed low; join the reachable foreend smoothly over the final 30% of raising.
    let joining = max(0, min(1, (weapon.raise - 0.7) / 0.3))
    if joining > 0 {
      let amount = joining * joining * (3 - 2 * joining)
      let current = source.globals(pose)
      let wrist = Self.position(current[source.leftArm.end])
      source.solve(
        source.leftArm,
        target: simd_mix(wrist, point([-0.07, -0.05, -0.02]), SIMD3(repeating: amount)),
        endRotation: simd_slerp(
          Transform(matrix: current[source.leftArm.end]).rotation, hand, amount),
        pole: -source.right - source.up * 0.5 - source.forward * 0.05, pose: &pose)
    }
  }

  /// Positive local y means forward; positive x means the character's right, independent of
  /// camera orientation. Diagonals blend the two neighbouring authored gaits at one phase.
  private static func movementWeights(velocity: SIMD2<Float>, sneaking: Bool) -> [Float] {
    if sneaking { return [0, 0, 0, 0, 0, 0, 0, 1] }
    let speed = simd_length(velocity)
    guard speed > 0.001 else { return [1, 0, 0, 0, 0, 0, 0, 0] }
    let moving = min(1, speed / 0.35)
    let direction = velocity / (abs(velocity.x) + abs(velocity.y))
    let jog = max(0, min(1, (speed - 1.15) / 0.75))
    let run = max(0, min(1, (speed - 2.15) / 0.35))
    let forward = max(0, direction.y) * moving
    return [
      1 - moving, forward * (1 - jog), forward * jog * (1 - run), forward * run,
      max(0, -direction.y) * moving, max(0, -direction.x) * moving,
      max(0, direction.x) * moving, 0,
    ]
  }

  private static func skeletalModel(in entity: Entity) -> ModelEntity? {
    if let model = entity as? ModelEntity, !model.jointNames.isEmpty { return model }
    for child in entity.children {
      if let model = skeletalModel(in: child) { return model }
    }
    return nil
  }

  private static func mix(_ first: Transform, _ second: Transform, amount: Float) -> Transform {
    Transform(
      scale: simd_mix(first.scale, second.scale, SIMD3(repeating: amount)),
      rotation: simd_slerp(first.rotation, second.rotation, amount),
      translation: simd_mix(first.translation, second.translation, SIMD3(repeating: amount)))
  }

  private static func blend(_ samples: [([Transform], Float)]) -> [Transform] {
    let active = samples.filter { $0.1 > 0 }
    var pose = active[0].0
    var weight = active[0].1
    for (next, amount) in active.dropFirst() {
      weight += amount
      for index in pose.indices {
        pose[index] = mix(pose[index], next[index], amount: amount / weight)
      }
    }
    return pose
  }

  private static func position(_ matrix: simd_float4x4) -> SIMD3<Float> {
    SIMD3(matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z)
  }

  private static func frame(direction: SIMD3<Float>, hint: SIMD3<Float>) -> simd_quatf {
    let y = simd_normalize(direction)
    let z = simd_normalize(hint - y * simd_dot(hint, y))
    let x = simd_normalize(simd_cross(y, z))
    return simd_quatf(simd_float3x3(columns: (x, y, simd_cross(x, y))))
  }

  private struct Limb {
    let upper: Int
    let lower: Int
    let end: Int
    let first: Float
    let second: Float
  }

  /// Shared immutable source frames and skeleton data; phases belong to each presenter.
  @MainActor private struct Source {
    // Retain the resource whose identity keys the cache, even if a figure is later removed.
    let mesh: MeshResource
    let frames: [JointTransforms]
    let interval: Double
    let start: Double
    let order: [Int]
    let parents: [Int?]
    let restGlobal: [Transform]
    let legs: [Limb]
    let rightArm: Limb
    let leftArm: Limb
    let arms: [Int]
    let torso: [Int]
    let up: SIMD3<Float>
    let forward: SIMD3<Float>
    let right: SIMD3<Float>

    init(model: ModelEntity) {
      guard
        let sampled = model.availableAnimations.compactMap({
          $0.definition as? SampledAnimation<JointTransforms>
        }).first, let mesh = model.model?.mesh, let skeleton = mesh.contents.skeletons.first
      else {
        fatalError("The party model has no imported sampled animation or rest skeleton")
      }
      self.mesh = mesh
      frames = sampled.frames
      interval = Double(sampled.frameInterval)
      start = sampled.start
      precondition(!frames.isEmpty && interval > 0)
      order = model.jointNames.map { name in
        guard let index = sampled.jointNames.firstIndex(of: name) else {
          fatalError("The party animation does not contain joint \(name)")
        }
        return index
      }
      let joints = model.jointNames.map { name in
        guard let joint = skeleton.joints.first(where: { $0.name == name }) else {
          fatalError("The party mesh has no rest joint \(name)")
        }
        return joint
      }
      parents = joints.map { joint in
        joint.parentIndex.map { parent in
          guard let index = model.jointNames.firstIndex(of: skeleton.joints[parent].name) else {
            fatalError("The party mesh has no parent joint")
          }
          return index
        }
      }
      var global: [Transform] = []
      for (index, joint) in joints.enumerated() {
        let local = joint.restPoseTransform.matrix
        precondition(parents[index] == nil || parents[index]! < index)
        global.append(Transform(matrix: parents[index].map { global[$0].matrix * local } ?? local))
      }
      restGlobal = global
      func index(_ name: String) -> Int {
        guard
          let index = model.jointNames.firstIndex(where: {
            $0.split(separator: "/").last.map(String.init) == name
          })
        else {
          fatalError("The party rig is missing \(name)")
        }
        return index
      }
      func limb(_ upper: String, _ lower: String, _ end: String) -> Limb {
        let a = index(upper)
        let b = index(lower)
        let c = index(end)
        return Limb(
          upper: a, lower: b, end: c,
          first: simd_distance(global[a].translation, global[b].translation),
          second: simd_distance(global[b].translation, global[c].translation))
      }
      legs = [limb("thigh_L", "shin_L", "foot_L"), limb("thigh_R", "shin_R", "foot_R")]
      leftArm = limb("upper_arm_L", "forearm_L", "hand_L")
      rightArm = limb("upper_arm_R", "forearm_R", "hand_R")
      torso = [index("spine"), index("chest"), index("head")]
      arms = [
        leftArm.upper, leftArm.lower, leftArm.end,
        rightArm.upper, rightArm.lower, rightArm.end,
      ]
      up = simd_normalize(global[index("head")].translation - global[index("pelvis")].translation)
      let toe = global[index("foot_L")].rotation.act([0, 1, 0])
      forward = simd_normalize(toe - up * simd_dot(toe, up))
      right = simd_normalize(simd_cross(forward, up))
      precondition(
        PartyModelClips.Clip.allCases.allSatisfy {
          PartyModelClips.take(for: $0).end <= sampled.end + 0.0001
        }, "The imported party animation ends before its declared clips")
    }

    func pose(_ clip: Clip, time: Double) -> [Transform] {
      let take = PartyModelClips.take(for: clip)
      let local =
        take.loop
        ? time.truncatingRemainder(dividingBy: take.duration)
        : min(take.duration, max(0, time))
      let frame = max(0, min(Double(frames.count - 1), (take.start + local - start) / interval))
      let first = Int(frame)
      let second = min(first + 1, frames.count - 1)
      return order.map {
        PartyAnimation.mix(
          frames[first][$0], frames[second][$0], amount: Float(frame - Double(first)))
      }
    }

    func globals(_ pose: [Transform]) -> [simd_float4x4] {
      var global: [simd_float4x4] = []
      for index in pose.indices {
        let local = pose[index].matrix
        global.append(parents[index].map { global[$0] * local } ?? local)
      }
      return global
    }

    func solve(
      _ limb: Limb, target: SIMD3<Float>, endRotation: simd_quatf,
      pole: SIMD3<Float>, pose: inout [Transform]
    ) {
      let global = globals(pose)
      let shoulder = PartyAnimation.position(global[limb.upper])
      let delta = target - shoulder
      let distance = simd_length(delta)
      precondition(
        distance < limb.first + limb.second + 0.001
          && distance > abs(limb.first - limb.second) + 0.00001,
        "Party limb \(limb.upper) target \(target) from \(shoulder): \(distance)m exceeds \(limb.first + limb.second)m reach"
      )
      let along = delta / distance
      let bend = simd_normalize(pole - along * simd_dot(pole, along))
      let projection =
        (limb.first * limb.first - limb.second * limb.second + distance * distance)
        / (2 * distance)
      let height = sqrt(max(0, limb.first * limb.first - projection * projection))
      let elbow = shoulder + along * projection + bend * height
      let oldElbow = PartyAnimation.position(global[limb.lower])
      let oldWrist = PartyAnimation.position(global[limb.end])
      let upperTurn = simd_quatf(
        from: simd_normalize(oldElbow - shoulder),
        to: simd_normalize(elbow - shoulder))
      let lowerTurn = simd_quatf(
        from: simd_normalize(oldWrist - oldElbow),
        to: simd_normalize(target - elbow))
      let upper = Transform(
        rotation: upperTurn * Transform(matrix: global[limb.upper]).rotation, translation: shoulder)
      let lower = Transform(
        rotation: lowerTurn * Transform(matrix: global[limb.lower]).rotation, translation: elbow)
      let end = Transform(rotation: endRotation, translation: target)
      pose[limb.upper] = Transform(
        matrix: parents[limb.upper].map { global[$0].inverse * upper.matrix } ?? upper.matrix)
      pose[limb.lower] = Transform(matrix: upper.matrix.inverse * lower.matrix)
      pose[limb.end] = Transform(matrix: lower.matrix.inverse * end.matrix)
    }
  }
}
