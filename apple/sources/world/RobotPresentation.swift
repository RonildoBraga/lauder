import RealityKit
import simd

/// The loaded C model's named rigid joints. Its meshes and dimensions come from Blender; this
/// presenter supplies a crawl from actual movement and keeps the visible barrels on the rays.
@MainActor
final class RobotPresentation {
  private struct Leg {
    let swivel: Entity
    let upper: Entity
    let lower: Entity
    let ankle: Entity
  }

  private let visual: Entity
  private let root: Entity
  private let legs: [Leg]
  private let guns: [Entity]
  private let gunPositions: [SIMD3<Float>]
  private let sensor: Entity
  private var motion = RobotMotion()

  init(visual: Entity) {
    self.visual = visual
    func part(_ label: String) -> Entity {
      let name =
        "spider_bot_heavy_"
        + label.replacingOccurrences(of: "-", with: "_")
        .replacingOccurrences(of: " ", with: "_")
      guard let entity = visual.findEntity(named: name) else {
        preconditionFailure("The Blender robot export lacks \(name). Export the model again.")
      }
      return entity
    }
    root = part("root")
    legs = RobotModelGeometry.legs.map {
      Leg(
        swivel: part("\($0.name) hip pivot"), upper: part("\($0.name) upper pivot"),
        lower: part("\($0.name) lower pivot"), ankle: part("\($0.name) ankle pivot"))
    }
    guns = [part("gun-left recoil"), part("gun-right recoil")]
    gunPositions = guns.map(\.position)
    sensor = part("square sensor")
  }

  func reset(position: SIMD2<Float>, facing: SIMD2<Float>) {
    motion.reset(position: position, facing: facing)
    update(
      position: position, facing: facing, brace: 0, gunDirections: [], gunRecoil: .zero,
      down: false, dt: 0)
  }

  func update(
    position: SIMD2<Float>, facing: SIMD2<Float>, brace: Float,
    gunDirections: [SIMD3<Float>], gunRecoil: SIMD2<Float>, down: Bool, dt: Float
  ) {
    let bodyYaw = Movement.yaw(towards: facing)
    visual.orientation = simd_quatf(angle: bodyYaw, axis: [0, 1, 0])
    visual.position = .zero
    let lowered = down ? 1 : max(0, min(1, brace))
    root.position.z = -RobotModelGeometry.braceDepth * lowered
    let poses = motion.advance(
      position: position, facing: facing, brace: lowered, dt: down ? 0 : dt)
    for (leg, pose) in zip(legs, poses) {
      leg.swivel.orientation = simd_quatf(angle: pose.swivel, axis: [0, 0, 1])
      leg.upper.orientation = simd_quatf(angle: pose.upper, axis: [0, 1, 0])
      leg.lower.orientation = simd_quatf(angle: pose.lower, axis: [0, 1, 0])
      leg.ankle.orientation = pose.ankle
    }
    for index in guns.indices {
      let direction =
        gunDirections.indices.contains(index) ? gunDirections[index] : SIMD3<Float>.zero
      let yaw =
        simd_length(direction) > 0.001
        ? Movement.yaw(towards: [direction.x, direction.z]) - bodyYaw : 0
      let pitch = simd_length(direction) > 0.001 ? asin(max(-1, min(1, direction.y))) : 0
      // Source +z maps to game +y; source +x maps to game -x.
      let rotation =
        simd_quatf(angle: yaw, axis: [0, 0, 1])
        * simd_quatf(angle: -pitch, axis: [1, 0, 0])
      let recoil = gunRecoil[index]
      guns[index].orientation = rotation
      guns[index].position = gunPositions[index] + rotation.act([0, max(0, recoil), 0])
    }
    sensor.isEnabled = !down
  }
}
