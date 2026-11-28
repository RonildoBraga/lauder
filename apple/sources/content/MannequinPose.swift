import Foundation
import simd

/// Generated poses retain the original Blender bone-local axes; ROOT changes to game axes.
struct MannequinJointPose: Equatable, Sendable {
  var position: SIMD3<Float>
  var rotation: simd_quatf

  init(_ values: [Float]) {
    precondition(values.count == 7)
    position = SIMD3(values[0], values[1], values[2])
    rotation = simd_normalize(simd_quatf(vector: SIMD4(values[3], values[4], values[5], values[6])))
  }

  init(position: SIMD3<Float>, rotation: simd_quatf) {
    self.position = position
    self.rotation = simd_normalize(rotation)
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.position == rhs.position && lhs.rotation.vector == rhs.rotation.vector
  }

  func applying(_ child: Self) -> Self {
    Self(position: position + rotation.act(child.position), rotation: rotation * child.rotation)
  }

  func relative(to parent: Self) -> Self {
    let inverse = parent.rotation.inverse
    return Self(position: inverse.act(position - parent.position), rotation: inverse * rotation)
  }

  func interpolated(to other: Self, fraction: Float) -> Self {
    Self(
      position: position + (other.position - position) * fraction,
      rotation: simd_slerp(rotation, other.rotation, fraction))
  }
}

struct MannequinLibrary: Decodable, Sendable {
  struct Bone: Decodable, Sendable {
    let name: String
    let parent: Int
    let length: Float
    let rest: [Float]
  }
  struct Proxy: Decodable, Sendable {
    let name: String
    let bone: Int
    let position: [Float]
    let rotation: [Float]
    let size: [Float]
    let accent: Bool
  }
  struct Phases: Decodable, Sendable {
    let windup: Float
    let active: Float
    let recovery: Float
    let end: Float
  }
  struct Clip: Decodable, Sendable {
    let duration: Float
    let loop: Bool
    let nominalSpeed: Float
    let eventStart: Float
    let phases: Phases?
    let frames: [[[Float]]]
  }
  let version: Int
  let sourceSHA256: String
  let fps: Int
  let bones: [Bone]
  let proxies: [Proxy]
  let clips: [String: Clip]
  let sockets: [String: [Float]]

  static let shared: Self = {
    guard let url = Bundle.main.url(forResource: "mannequin", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let library = try? JSONDecoder().decode(Self.self, from: data)
    else { preconditionFailure("The checked mannequin animation resource is missing or invalid") }
    precondition(library.version == 1 && library.bones.count == 17)
    return library
  }()

  func index(_ name: String) -> Int {
    guard let index = bones.firstIndex(where: { $0.name == name }) else {
      preconditionFailure("Missing mannequin bone: \(name)")
    }
    return index
  }

  func sample(_ name: String, time: Float) -> [MannequinJointPose] {
    guard let clip = clips[name] else { preconditionFailure("Missing mannequin clip: \(name)") }
    let seconds =
      clip.loop
      ? max(0, time).truncatingRemainder(dividingBy: clip.duration)
      : max(0, min(clip.duration, time))
    let frame = seconds / clip.duration * Float(clip.frames.count - 1)
    let lower = min(clip.frames.count - 1, Int(frame))
    let upper = min(clip.frames.count - 1, lower + 1)
    return zip(clip.frames[lower], clip.frames[upper]).map {
      MannequinJointPose($0).interpolated(
        to: MannequinJointPose($1), fraction: frame - Float(lower))
    }
  }

  /// Game profiles may be retuned independently of the authored pose-segment lengths.
  func actionTime(_ name: String, phase: DuelAction.Phase, progress: Float) -> Float {
    guard let markers = clips[name]?.phases else {
      preconditionFailure("Missing mannequin action phase markers: \(name)")
    }
    let range: (Float, Float) =
      switch phase {
      case .windup: (markers.windup, markers.active)
      case .active: (markers.active, markers.recovery)
      case .recovery: (markers.recovery, markers.end)
      }
    return range.0 + (range.1 - range.0) * max(0, min(1, progress))
  }

  func hitTime(remaining: Float, duration: Float) -> Float {
    let clip = clips["hit"]!
    let progress = max(0, min(1, 1 - remaining / max(duration, 0.0001)))
    return clip.eventStart + (clip.duration - clip.eventStart) * progress
  }

  func world(_ local: [MannequinJointPose]) -> [MannequinJointPose] {
    var result = local
    for index in bones.indices where bones[index].parent >= 0 {
      result[index] = result[bones[index].parent].applying(local[index])
    }
    return result
  }

  /// Fits a plain rigid hand with natural bone lengths. The returned gap is never hidden by stretching.
  func fitArm(
    side: String, target: SIMD3<Float>, world: inout [MannequinJointPose]
  ) -> Float {
    let upper = index("upper_arm.\(side)")
    let fore = index("forearm.\(side)")
    let hand = index("hand.\(side)")
    let reference = self.world(bones.map { MannequinJointPose($0.rest) })
    let start = world[upper].position
    let offset = target - start
    let actual = simd_length(offset)
    let axis = actual > 0.00001 ? offset / actual : SIMD3<Float>(0, -1, 0)
    let first = bones[upper].length
    let second = bones[fore].length
    let distance = min(first + second, max(abs(first - second) + 0.00001, actual))
    let pole = SIMD3<Float>(side == "R" ? 1 : -1, -0.3, 0.25)
    var bend = pole - axis * simd_dot(pole, axis)
    if simd_length_squared(bend) < 0.00001 { bend = simd_cross(axis, [0, 1, 0]) }
    bend = simd_normalize(bend)
    let along = (first * first - second * second + distance * distance) / (2 * distance)
    let elbow = start + axis * along + bend * sqrt(max(0, first * first - along * along))
    let end = start + axis * distance
    for (bone, a, b) in [(upper, start, elbow), (fore, elbow, end)] {
      let restAxis = reference[bone].rotation.act([0, 1, 0])
      let delta = simd_quatf(from: restAxis, to: simd_normalize(b - a))
      world[bone] = MannequinJointPose(position: a, rotation: delta * reference[bone].rotation)
    }
    world[hand] = MannequinJointPose(
      position: end,
      rotation: world[fore].rotation * reference[fore].rotation.inverse * reference[hand].rotation)
    return simd_distance(end, target)
  }

  /// Local-pose interpolation can dip a box toe slightly below the flat floor between samples.
  /// This small presentation lift preserves all joints; it never moves the gameplay actor.
  @discardableResult
  func ground(_ world: inout [MannequinJointPose]) -> Float {
    var minimum: Float = 0
    for proxy in proxies where proxy.name.hasPrefix("foot.") {
      let local = MannequinJointPose(proxy.position + proxy.rotation)
      let transform = world[proxy.bone].applying(local)
      for x in [Float(-0.5), 0.5] {
        for y in [Float(-0.5), 0.5] {
          for z in [Float(-0.5), 0.5] {
            let point =
              transform.position
              + transform.rotation.act(
                [proxy.size[0] * x, proxy.size[1] * y, proxy.size[2] * z])
            minimum = min(minimum, point.y)
          }
        }
      }
    }
    if minimum < 0 {
      for index in world.indices { world[index].position.y -= minimum }
    }
    return -minimum
  }

  /// Restrained body recoil uses the historical hit pose without taking over an owed action.
  func recoil(_ local: inout [MannequinJointPose], remainingFlash: Float) {
    let hit = sample(
      "hit", time: hitTime(remaining: remainingFlash, duration: DuelSimulation.hitFlashDuration))
    let neutral = sample("idle", time: 0)
    for name in ["spine", "head"] {
      let bone = index(name)
      let delta = hit[bone].rotation * neutral[bone].rotation.inverse
      local[bone].rotation = simd_normalize(
        local[bone].rotation * simd_slerp(simd_quatf(), delta, 0.4))
    }
  }

  /// Guard keeps its authored upper-body brace while the existing locomotion drives the legs.
  func brace(_ world: inout [MannequinJointPose]) {
    let reference = self.world(sample("guard", time: 0))
    let spine = index("spine")
    let parent = bones[spine].parent
    let local = reference[spine].relative(to: reference[parent])
    world[spine] = MannequinJointPose(
      position: world[parent].applying(local).position, rotation: reference[spine].rotation)
    for name in [
      "chest", "head", "upper_arm.L", "forearm.L", "hand.L", "upper_arm.R", "forearm.R", "hand.R",
    ] {
      let bone = index(name)
      let parent = bones[bone].parent
      world[bone] = world[parent].applying(reference[bone].relative(to: reference[parent]))
    }
  }

  func local(_ world: [MannequinJointPose]) -> [MannequinJointPose] {
    bones.indices.map { index in
      let parent = bones[index].parent
      return parent < 0 ? world[index] : world[index].relative(to: world[parent])
    }
  }
}
