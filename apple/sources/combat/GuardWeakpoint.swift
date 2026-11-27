import simd

/// Generous prototype component volumes, shared by aim, physical hits and presentation.
/// These are visible combat markers on the C model's hull, not invisible role-only hit checks.
struct GuardWeakpoint {
  let id: String
  let hostileID: String
  let part: GuardStrategy.Part
  let centre: SIMD3<Float>
  let radius: Float
  let exposed: Bool

  var ground: SIMD2<Float> { [centre.x, centre.z] }
  var target: Ballistics.Target {
    Ballistics.Target(
      id: id, centre: centre, halfHeight: radius, radius: radius, acceptsInteriorHits: false)
  }

  static func make(id: String, robot: RobotGuard, strategy: GuardStrategy) -> [Self] {
    let part: GuardStrategy.Part
    let offsets: [SIMD3<Float>]
    switch strategy.phase {
    case .sensor:
      part = .sensor
      offsets = [[0, 1.65, -1.45]]
    case .coupling:
      part = .coupling
      offsets = [[-1.45, 1.25, 0], [1.45, 1.25, 0]]
    case .reactor:
      part = .reactor
      offsets = [[-1.45, 1.65, 0], [1.45, 1.65, 0]]
    case .complete:
      return []
    }
    let rotation = simd_quatf(angle: Movement.yaw(towards: robot.facing), axis: [0, 1, 0])
    return offsets.enumerated().map { index, offset in
      let centre =
        SIMD3(robot.position.x, -RobotModelGeometry.braceDepth * robot.brace, robot.position.y)
        + rotation.act(offset)
      return Self(
        id: "\(id).\(part).\(index)", hostileID: id, part: part, centre: centre,
        radius: part == .sensor ? 0.35 : 0.4,
        exposed: strategy.isExposed(part, recovering: robot.phase == .recovering))
    }
  }
}
