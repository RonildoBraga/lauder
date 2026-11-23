import simd

/// Fixed-step foot anchors and a spring-supported body. The inverse solve uses the same full
/// body transform as the visible joints and authoritative weapons.
struct RobotMotion {
  struct LegPose {
    let swivel: Float
    let upper: Float
    let lower: Float
    let ankle: simd_quatf
  }

  struct BodyPose {
    /// Game axes local to the heading; the vertical offset includes combat bracing.
    var offset = SIMD3<Float>.zero
    var rotation = simd_quatf(angle: 0, axis: [0, 1, 0])
    var sourceOffset: SIMD3<Float> { [-offset.x, offset.z, offset.y] }
    var sourceRotation: simd_quatf {
      simd_quatf(ix: -rotation.imag.x, iy: rotation.imag.z, iz: rotation.imag.y, r: rotation.real)
    }
  }

  private struct Foot {
    var point: SIMD3<Float>
    var yaw: Float
    var start: SIMD3<Float>
    var end: SIMD3<Float>
    var startYaw: Float
    var endYaw: Float
    var progress: Float = 1
    var duration: Float = RobotMotion.stepTime
  }
  private var feet: [Foot] = []
  private var previous: SIMD2<Float>?
  private var previousYaw: Float = 0
  private var previousBrace: Float = 0
  private var next = 0
  private var stepping: Int?
  private var dwell: Float = 0
  private var velocitySpring = RobotDynamics(frequency: 2, damping: 1)
  private var bodySpring = RobotDynamics(frequency: 3.8, damping: 0.9, initialResponse: 0.35)
  private static let order = [0, 3, 1, 2]
  static let stepTime: Float = 0.24
  private static let plantDwell: Float = 0.05
  private static let reachMargin: Float = 0.07
  // The source-derived boot radius covers every foot yaw, not only its neutral projection.
  private static let footRadius =
    RobotModelGeometry.navigationRadius - RobotModelGeometry.footRadius - 0.005
  private(set) var bodyPose = BodyPose()
  private(set) var legPoses: [LegPose] = []
  private(set) var maximumReach: Float = 0
  private(set) var isReachable = true
  var footPositions: [SIMD3<Float>] { feet.map(\.point) }

  mutating func reset(position: SIMD2<Float>, facing: SIMD2<Float>, brace: Float = 0) {
    let yaw = Movement.yaw(towards: facing)
    feet = RobotModelGeometry.legs.map { leg in
      let point = Self.goal(leg, at: position, yaw: yaw)
      let angle = yaw + leg.angle
      return Foot(
        point: point, yaw: angle, start: point, end: point, startYaw: angle, endYaw: angle)
    }
    previous = position
    previousYaw = yaw
    previousBrace = max(0, min(1, brace))
    next = 0
    stepping = nil
    dwell = 0
    velocitySpring.reset()
    bodySpring.reset(to: [0, 0, -RobotModelGeometry.braceDepth * previousBrace])
    bodyPose = BodyPose(offset: [0, bodySpring.value.z, 0])
    pose(position: position, yaw: yaw)
  }

  /// Gate both translation and yaw. Advancing while the body is held still progresses the
  /// active step, so a reach refusal does not deadlock the crawl.
  func canPlaceBody(position: SIMD2<Float>, facing: SIMD2<Float>, brace: Float) -> Bool {
    guard position.x.isFinite, position.y.isFinite, facing.x.isFinite, facing.y.isFinite else {
      return false
    }
    let yaw = Movement.yaw(towards: facing)
    return feet.indices.allSatisfy { index in
      // A reversal must not move the body away from a still-flying foot's committed landing.
      let targets = index == stepping ? [feet[index].point, feet[index].end] : [feet[index].point]
      return targets.allSatisfy { point in
        let d = simd_length(
          Self.local(point, position: position, yaw: yaw, body: bodyPose)
            - RobotModelGeometry.legs[index].hip)
        return d > abs(RobotModelGeometry.upperLength - RobotModelGeometry.lowerLength) + 0.02
          && d < RobotModelGeometry.upperLength + RobotModelGeometry.lowerLength - Self.reachMargin
          && simd_length(SIMD2(point.x, point.z) - position) < Self.footRadius
      }
    }
  }

  @discardableResult
  mutating func advance(position: SIMD2<Float>, facing: SIMD2<Float>, brace: Float, dt: Float)
    -> [LegPose]
  {
    if feet.isEmpty { reset(position: position, facing: facing, brace: brace) }
    guard dt.isFinite, dt > 0, position.x.isFinite, position.y.isFinite, facing.x.isFinite,
      facing.y.isFinite
    else { return legPoses }
    let yaw = Movement.yaw(towards: facing)
    let elapsed = min(dt, 1 / 15)
    let start = previous ?? position
    let turn = Self.wrap(yaw - previousYaw)
    if simd_length(position - start) > 0.3 || abs(turn) > 0.4 {
      reset(position: position, facing: facing, brace: brace)
      return legPoses
    }
    let velocity = (position - start) / elapsed
    let turning = turn / elapsed
    let count = max(1, Int(ceil(elapsed * 120)))
    let h = elapsed / Float(count)
    let startYaw = previousYaw
    let startBrace = previousBrace
    let finalBrace = max(0, min(1, brace))
    for index in 1...count {
      let amount = Float(index) / Float(count)
      let here = start + (position - start) * amount
      let heading = startYaw + turn * amount
      let bracing = startBrace + (finalBrace - startBrace) * amount
      advanceFeet(position: here, yaw: heading, velocity: velocity, turning: turning, dt: h)
      let filtered = velocitySpring.advance(to: [velocity.x, 0, velocity.y], dt: h)
      let lag = simd_quatf(angle: -heading, axis: [0, 1, 0]).act(
        SIMD3(velocity.x, 0, velocity.y) - filtered)
      let target = SIMD3(
        max(-0.025, min(0.025, -lag.z * 0.07)), max(-0.025, min(0.025, lag.x * 0.07)),
        -RobotModelGeometry.braceDepth * bracing)
      let settled = bodySpring.advance(to: target, dt: h)
      let height = max(target.z - 0.025, min(target.z + 0.005, settled.z))
      bodyPose = BodyPose(
        offset: [0, height, 0],
        rotation:
          simd_quatf(angle: max(-0.03, min(0.03, settled.x)), axis: [1, 0, 0])
          * simd_quatf(angle: max(-0.03, min(0.03, settled.y)), axis: [0, 0, 1]))
      pose(position: here, yaw: heading)
    }
    previous = position
    previousYaw = yaw
    previousBrace = finalBrace
    return legPoses
  }

  private mutating func advanceFeet(
    position: SIMD2<Float>, yaw: Float, velocity: SIMD2<Float>, turning: Float, dt: Float
  ) {
    let pressure = feet.indices.map { urgency(index: $0, position: position, yaw: yaw) }.max() ?? 0
    if let index = stepping {
      if pressure > 0.997 { feet[index].duration = min(feet[index].duration, 0.16) }
      feet[index].progress = min(1, feet[index].progress + dt / feet[index].duration)
      let u = feet[index].progress
      let amount = Self.smooth(u)
      feet[index].point = simd_mix(feet[index].start, feet[index].end, SIMD3(repeating: amount))
      let lift =
        u < 0.45 ? Self.smooth(u / 0.45) : (u <= 0.6 ? 1 : max(0, 1 - pow((u - 0.6) / 0.4, 2)))
      feet[index].point.y += min(0.1, RobotModelGeometry.stepLift) * lift
      feet[index].yaw =
        feet[index].startYaw + Self.wrap(feet[index].endYaw - feet[index].startYaw) * amount
      if u >= 1 {
        stepping = nil
        dwell = Self.plantDwell
        bodySpring.impulse([0, 0, -0.9])
      }
    } else {
      dwell = max(0, dwell - dt)
    }
    guard stepping == nil else { return }
    let ranked = (0..<Self.order.count).map { (next + $0) % Self.order.count }
    let urgent = ranked.max {
      urgency(index: Self.order[$0], position: position, yaw: yaw)
        < urgency(index: Self.order[$1], position: position, yaw: yaw)
    }!
    let stressed = pressure > 0.993
    guard dwell <= 0 || stressed else { return }
    let candidates = stressed ? [urgent] + ranked.filter { $0 != urgent } : ranked
    for orderIndex in candidates {
      let index = Self.order[orderIndex]
      let leg = RobotModelGeometry.legs[index]
      let wanted = Self.goal(leg, at: position, yaw: yaw)
      guard
        simd_distance(wanted, feet[index].point) > 0.045
          || abs(Self.wrap(yaw + leg.angle - feet[index].yaw)) > 0.045
      else { continue }
      let proposed = Self.goal(leg, at: position + velocity * 0.58, yaw: yaw + turning * 0.3)
      feet[index].start = feet[index].point
      feet[index].end = landing(
        proposed, neutral: wanted, index: index, position: position, yaw: yaw)
      feet[index].startYaw = feet[index].yaw
      feet[index].endYaw = yaw + leg.angle + turning * 0.3
      feet[index].duration = stressed ? 0.16 : Self.stepTime
      feet[index].progress = 0
      stepping = index
      next = (orderIndex + 1) % Self.order.count
      break
    }
  }

  private func landing(
    _ proposed: SIMD3<Float>, neutral: SIMD3<Float>, index: Int, position: SIMD2<Float>, yaw: Float
  ) -> SIMD3<Float> {
    func legal(_ point: SIMD3<Float>) -> Bool {
      let delta =
        Self.local(point, position: position, yaw: yaw, body: bodyPose)
        - RobotModelGeometry.legs[index].hip
      return simd_length(delta) < RobotModelGeometry.upperLength + RobotModelGeometry.lowerLength
        - 0.1
        && simd_length(SIMD2(point.x, point.z) - position) < Self.footRadius
    }
    if legal(proposed) { return proposed }
    var low: Float = 0
    var high: Float = 1
    for _ in 0..<12 {
      let mid = (low + high) / 2
      if legal(neutral + (proposed - neutral) * mid) { low = mid } else { high = mid }
    }
    return neutral + (proposed - neutral) * low
  }

  private func reach(index: Int, position: SIMD2<Float>, yaw: Float) -> Float {
    simd_length(
      Self.local(feet[index].point, position: position, yaw: yaw, body: bodyPose)
        - RobotModelGeometry.legs[index].hip)
  }

  private func urgency(index: Int, position: SIMD2<Float>, yaw: Float) -> Float {
    max(
      reach(index: index, position: position, yaw: yaw)
        / (RobotModelGeometry.upperLength + RobotModelGeometry.lowerLength - Self.reachMargin),
      simd_length(SIMD2(feet[index].point.x, feet[index].point.z) - position) / Self.footRadius)
  }

  private mutating func pose(position: SIMD2<Float>, yaw: Float) {
    maximumReach = feet.indices.map { reach(index: $0, position: position, yaw: yaw) }.max() ?? 0
    isReachable = feet.indices.allSatisfy {
      let d = reach(index: $0, position: position, yaw: yaw)
      return d < RobotModelGeometry.upperLength + RobotModelGeometry.lowerLength - 0.0001
        && d > abs(RobotModelGeometry.upperLength - RobotModelGeometry.lowerLength) + 0.0001
    }
    legPoses = feet.enumerated().map { index, foot in
      Self.solve(
        RobotModelGeometry.legs[index], foot: foot.point, footYaw: foot.yaw, position: position,
        yaw: yaw, body: bodyPose)
    }
  }

  private static func goal(_ leg: RobotModelGeometry.Leg, at position: SIMD2<Float>, yaw: Float)
    -> SIMD3<Float>
  {
    simd_quatf(angle: yaw, axis: [0, 1, 0]).act([-leg.foot.x, leg.foot.z, leg.foot.y])
      + SIMD3(position.x, 0, position.y)
  }

  private static func local(
    _ foot: SIMD3<Float>, position: SIMD2<Float>, yaw: Float, body: BodyPose
  ) -> SIMD3<Float> {
    let relative =
      simd_quatf(angle: -yaw, axis: [0, 1, 0]).act(foot - SIMD3(position.x, 0, position.y))
      - body.offset
    let p = body.rotation.inverse.act(relative)
    return [-p.x, p.z, p.y]
  }

  private static func solve(
    _ leg: RobotModelGeometry.Leg, foot: SIMD3<Float>, footYaw: Float, position: SIMD2<Float>,
    yaw: Float, body: BodyPose
  ) -> LegPose {
    let delta = local(foot, position: position, yaw: yaw, body: body) - leg.hip
    let radial = simd_length(SIMD2(delta.x, delta.y))
    let l1 = RobotModelGeometry.upperLength
    let l2 = RobotModelGeometry.lowerLength
    // Roundoff protection only: isReachable exposes unsupported anchors and navigation gates
    // reject them. Tests independently reconstruct endpoints instead of trusting this clamp.
    let d = max(abs(l1 - l2) + 0.00001, min(l1 + l2 - 0.00001, simd_length(delta)))
    let p = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
    let h = sqrt(max(0, l1 * l1 - p * p))
    let kneeX = p * radial / d - h * delta.z / d
    let kneeZ = p * delta.z / d + h * radial / d
    let azimuth = atan2(delta.y, delta.x)
    let upper = atan2(kneeX, kneeZ)
    let lower = atan2(radial - kneeX, delta.z - kneeZ)
    let chain =
      simd_quatf(angle: yaw, axis: [0, 0, 1]) * body.sourceRotation
      * simd_quatf(angle: azimuth, axis: [0, 0, 1]) * simd_quatf(angle: lower, axis: [0, 1, 0])
    return LegPose(
      swivel: wrap(azimuth - leg.angle), upper: upper, lower: wrap(lower - upper),
      ankle: chain.inverse * simd_quatf(angle: footYaw, axis: [0, 0, 1]))
  }

  private static func smooth(_ t: Float) -> Float { t * t * t * (t * (t * 6 - 15) + 10) }
  private static func wrap(_ value: Float) -> Float { value.remainder(dividingBy: 2 * .pi) }
}
