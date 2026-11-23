// Generated from blender/assets/spider-bot-heavy/spider-bot-heavy.blend. Do not edit.
import simd

enum RobotModelGeometry {
  struct Leg: Sendable {
    let name: String
    let hip: SIMD3<Float>
    let foot: SIMD3<Float>
    let angle: Float
  }

  // Combat offsets use game axes, facing -z. Gun 0 is the source's left gun.
  static let bodyRadius: Float = 1.107744
  static let halfHeight: Float = 1.234272
  static let navigationRadius: Float = 2.067892
  static let footRadius: Float = 0.375559
  static let gunMounts: [SIMD3<Float>] = [
    [0.78, 1.52, -0.28],
    [-0.78, 1.52, -0.28],
  ]
  static let muzzles: [SIMD3<Float>] = [
    [0.78, 1.52, -0.8608],
    [-0.78, 1.52, -0.8608],
  ]

  // Rigid-joint calculations retain Blender's local x/y ground plane and z up.
  static let upperLength: Float = 1.01
  static let lowerLength: Float = 0.57
  static let stepLift: Float = 0.119938
  static let braceDepth: Float = 0.045
  static let legs: [Leg] = [
    Leg(
      name: "front-left", hip: [-0.58, -0.42, 1.13],
      foot: [-1.226398, -0.987247, 0.15], angle: -2.42132),
    Leg(
      name: "front-right", hip: [0.58, -0.42, 1.13],
      foot: [1.226398, -0.987247, 0.15], angle: -0.720273),
    Leg(
      name: "rear-left", hip: [-0.58, 0.42, 1.13],
      foot: [-1.226398, 0.987247, 0.15], angle: 2.42132),
    Leg(
      name: "rear-right", hip: [0.58, 0.42, 1.13],
      foot: [1.226398, 0.987247, 0.15], angle: 0.720273),
  ]
}
