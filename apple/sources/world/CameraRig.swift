import simd

/// Fixed elevated perspective for the small duel. The camera owns projection, never combat.
struct CameraRig {
  let offset: SIMD3<Float>
  let fieldOfView: Float
  private(set) var target: SIMD3<Float>

  init(offset: SIMD3<Float>, fieldOfView: Float, over point: SIMD2<Float>) {
    self.offset = offset
    self.fieldOfView = fieldOfView
    target = [point.x, 0.85, point.y]
  }

  var eye: SIMD3<Float> { target + offset }

  func projection(aspect: Float) -> CameraProjection {
    CameraProjection(eye: eye, target: target, fieldOfView: fieldOfView, aspect: aspect)
  }
}
