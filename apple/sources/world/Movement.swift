import simd

/// Directions on the ground: from the stick under the camera, and between a figure's facing and
/// its turn.
enum Movement {
  /// Stick or touch movement smaller than this counts as none.
  static let deadZone: Float = 0.15

  /// The direction on the ground that stick or touch movement moves the leader, and how fast,
  /// from none at the dead zone to 1 at full tilt.
  static func direction(
    for input: SIMD2<Float>, cameraOffset: SIMD3<Float>
  ) -> SIMD3<Float> {
    guard input.x.isFinite, input.y.isFinite else { return .zero }
    let magnitude = simd_length(input)
    guard magnitude > deadZone else { return .zero }
    let (forward, right) = axes(cameraOffset: cameraOffset)
    let strength = (min(magnitude, 1) - deadZone) / (1 - deadZone)
    let ground = (right * input.x + forward * input.y) / magnitude * strength
    return SIMD3(ground.x, 0, ground.y)
  }

  /// The full-tilt stick input that moves the leader along a direction on the ground: the
  /// inverse of `direction(for:cameraOffset:)`. None for no direction.
  static func stick(towards direction: SIMD2<Float>, cameraOffset: SIMD3<Float>) -> SIMD2<Float> {
    guard simd_length(direction) > 0.0001 else { return .zero }
    let (forward, right) = axes(cameraOffset: cameraOffset)
    let unit = simd_normalize(direction)
    return SIMD2(simd_dot(unit, right), simd_dot(unit, forward))
  }

  /// The ground directions of up and right on the screen. The camera looks along its offset's
  /// ground direction, so up the screen is that direction, and right a quarter turn clockwise
  /// from it; a camera straight above looks up the screen towards -z.
  static func axes(cameraOffset: SIMD3<Float>) -> (forward: SIMD2<Float>, right: SIMD2<Float>) {
    let ground = SIMD2(cameraOffset.x, cameraOffset.z)
    let forward = simd_length(ground) > 0.001 ? -simd_normalize(ground) : SIMD2<Float>(0, -1)
    return (forward, SIMD2(-forward.y, forward.x))
  }

  /// The turn about the vertical that faces a figure, which faces -z unturned, along a direction
  /// on the ground.
  static func yaw(towards direction: SIMD2<Float>) -> Float {
    atan2(-direction.x, -direction.y)
  }

  /// The direction on the ground that a figure turned by `yaw` faces.
  static func facing(yaw: Float) -> SIMD2<Float> {
    SIMD2(-sin(yaw), -cos(yaw))
  }
}
