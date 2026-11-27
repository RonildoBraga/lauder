import simd

/// The C model's four-beat crawl. Feet live in world space while planted; the two rigid links
/// solve towards them using the joint lengths exported from Blender. This changes no gameplay.
struct RobotMotion {
  struct LegPose {
    let swivel: Float
    let upper: Float
    let lower: Float
    let ankle: simd_quatf
  }

  private struct Foot {
    var point: SIMD3<Float>
    var yaw: Float
    var start: SIMD3<Float>
    var end: SIMD3<Float>
    var startYaw: Float
    var endYaw: Float
    var progress: Float = 1
  }

  private var feet: [Foot] = []
  private var previous: SIMD2<Float>?
  private var previousYaw: Float = 0
  private var next = 0
  private var stepping: Int?
  private var detachedLegs: Set<Int> = []
  private static let order = [0, 3, 1, 2]
  static let stepTime: Float = 0.12

  var footPositions: [SIMD3<Float>] { feet.map(\.point) }

  mutating func reset(position: SIMD2<Float>, facing: SIMD2<Float>) {
    let yaw = Movement.yaw(towards: facing)
    feet = RobotModelGeometry.legs.map { leg in
      let point = Self.goal(leg, at: position, yaw: yaw)
      let angle = yaw + leg.angle
      return Foot(
        point: point, yaw: angle, start: point, end: point, startYaw: angle, endYaw: angle)
    }
    previous = position
    previousYaw = yaw
    next = 0
    stepping = nil
    detachedLegs.removeAll()
  }

  mutating func advance(
    position: SIMD2<Float>, facing: SIMD2<Float>, brace: Float,
    detachedLegs missing: Set<Int> = [], bodyDrop: Float? = nil, dt: Float
  ) -> [LegPose] {
    let detached = detachedLegs.union(
      missing.filter { RobotModelGeometry.legs.indices.contains($0) })
    let yaw = Movement.yaw(towards: facing)
    if feet.isEmpty { reset(position: position, facing: facing) }
    let elapsed = max(0, min(dt, 1 / 15))
    let change = position - (previous ?? position)
    let turn = Self.wrap(yaw - previousYaw)
    // Retry/Restart and discontinuous placement start a fresh planted stance.
    if simd_length(change) > 0.3 || abs(turn) > 0.4 {
      reset(position: position, facing: facing)
    }
    detachedLegs = detached
    if let index = stepping, detachedLegs.contains(index) { stepping = nil }
    // A missing foot must not make the remaining support cycle quicker. The body already
    // moves more slowly; lengthen each surviving swing and its lookahead by the same ratio.
    let duration =
      Self.stepTime * Float(Self.order.count)
      / Float(max(1, Self.order.count - detachedLegs.count))
    let velocity = elapsed > 0 ? change / elapsed : .zero
    let turning = elapsed > 0 ? turn / elapsed : 0
    previous = position
    previousYaw = yaw

    if elapsed > 0 {
      if let index = stepping {
        feet[index].progress = min(1, feet[index].progress + elapsed / duration)
        let progress = feet[index].progress
        let amount = Self.smooth(progress)
        feet[index].point = simd_mix(feet[index].start, feet[index].end, SIMD3(repeating: amount))
        feet[index].point.y += RobotModelGeometry.stepLift * pow(sin(.pi * progress), 2)
        feet[index].yaw =
          feet[index].startYaw + Self.wrap(feet[index].endYaw - feet[index].startYaw) * amount
        if progress >= 1 { stepping = nil }
      }
      if stepping == nil {
        for offset in 0..<Self.order.count {
          let orderIndex = (next + offset) % Self.order.count
          let index = Self.order[orderIndex]
          guard !detachedLegs.contains(index) else { continue }
          let leg = RobotModelGeometry.legs[index]
          let wanted = Self.goal(leg, at: position, yaw: yaw)
          let distance = simd_length(wanted - feet[index].point)
          guard distance > 0.06 || abs(Self.wrap(yaw + leg.angle - feet[index].yaw)) > 0.045
          else { continue }
          let ahead = position + velocity * duration
          feet[index].start = feet[index].point
          feet[index].end = Self.goal(leg, at: ahead, yaw: yaw + turning * duration)
          feet[index].startYaw = feet[index].yaw
          feet[index].endYaw = yaw + turning * duration + leg.angle
          feet[index].progress = 0
          stepping = index
          next = (orderIndex + 1) % Self.order.count
          break
        }
      }
    }
    return RobotModelGeometry.legs.enumerated().map { index, leg in
      Self.solve(
        leg, foot: feet[index].point, footYaw: feet[index].yaw,
        position: position, yaw: yaw,
        bodyDrop: bodyDrop ?? RobotModelGeometry.braceDepth * brace)
    }
  }

  private static func goal(
    _ leg: RobotModelGeometry.Leg, at position: SIMD2<Float>, yaw: Float
  ) -> SIMD3<Float> {
    let canonical = SIMD3(-leg.foot.x, leg.foot.z, leg.foot.y)
    return simd_quatf(angle: yaw, axis: [0, 1, 0]).act(canonical)
      + SIMD3(position.x, 0, position.y)
  }

  private static func solve(
    _ leg: RobotModelGeometry.Leg, foot: SIMD3<Float>, footYaw: Float,
    position: SIMD2<Float>, yaw: Float, bodyDrop: Float
  ) -> LegPose {
    let local = simd_quatf(angle: -yaw, axis: [0, 1, 0])
      .act(foot - SIMD3(position.x, -bodyDrop, position.y))
    let delta = SIMD3(-local.x, local.z, local.y) - leg.hip
    let radial = simd_length(SIMD2(delta.x, delta.y))
    let l1 = RobotModelGeometry.upperLength
    let l2 = RobotModelGeometry.lowerLength
    let distance = max(abs(l1 - l2) + 0.0001, min(l1 + l2 - 0.0001, simd_length(delta)))
    let projection = (l1 * l1 - l2 * l2 + distance * distance) / (2 * distance)
    let height = sqrt(max(0, l1 * l1 - projection * projection))
    let kneeX = projection * radial / distance - height * delta.z / distance
    let kneeZ = projection * delta.z / distance + height * radial / distance
    let azimuth = atan2(delta.y, delta.x)
    let upper = atan2(kneeX, kneeZ)
    let lower = atan2(radial - kneeX, delta.z - kneeZ)
    let chain =
      simd_quatf(angle: yaw + azimuth, axis: [0, 0, 1])
      * simd_quatf(angle: lower, axis: [0, 1, 0])
    return LegPose(
      swivel: wrap(azimuth - leg.angle), upper: upper, lower: wrap(lower - upper),
      ankle: chain.inverse * simd_quatf(angle: footYaw, axis: [0, 0, 1]))
  }

  private static func smooth(_ t: Float) -> Float { t * t * t * (t * (t * 6 - 15) + 10) }
  private static func wrap(_ value: Float) -> Float { value.remainder(dividingBy: 2 * .pi) }
}
