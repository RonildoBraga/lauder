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
    guard strategy.phase == .active else { return [] }
    let rotation = simd_quatf(angle: Movement.yaw(towards: robot.facing), axis: [0, 1, 0])
    let base = SIMD3(
      robot.position.x, -robot.bodyDrop, robot.position.y)
    func point(_ part: GuardStrategy.Part, suffix: String, offset: SIMD3<Float>, radius: Float)
      -> Self
    {
      let centre = base + rotation.act(offset)
      return Self(
        id: "\(id).\(suffix)", hostileID: id, part: part, centre: centre,
        radius: radius, exposed: true)
    }
    // The red sensor's actual exported centre; the previous marker sat well in front of it.
    var points = [point(.eye, suffix: "eye", offset: [0, 1.53, -0.7045], radius: 0.2)]
    for (index, leg) in RobotModelGeometry.legs.enumerated()
    where !strategy.detachedLegs.contains(index) {
      // A generous lower-leg contact follows the generated foot direction rather than the
      // old invisible side coupling. Blender source +z is game +y, and source +x is game -x.
      let source = simd_mix(leg.hip, leg.foot, SIMD3(repeating: 0.7))
      let offset = SIMD3(-source.x, source.z, source.y)
      points.append(point(.leg(index), suffix: "leg.\(index)", offset: offset, radius: 0.35))
    }
    return points
  }
}
