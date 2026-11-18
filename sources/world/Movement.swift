import simd

enum Movement {
  /// Stick or touch movement smaller than this counts as none.
  static let deadZone: Float = 0.15

  static func direction(
    for input: SIMD2<Float>, cameraOffset: SIMD3<Float>
  ) -> SIMD3<Float> {
    guard input.x.isFinite, input.y.isFinite else { return .zero }
    let magnitude = simd_length(input)
    guard magnitude > deadZone else { return .zero }
    let forward = simd_normalize(SIMD3(-cameraOffset.x, 0, -cameraOffset.z))
    let right = SIMD3(-forward.z, 0, forward.x)
    let strength = (min(magnitude, 1) - deadZone) / (1 - deadZone)
    return (right * input.x + forward * input.y) / magnitude * strength
  }
}
