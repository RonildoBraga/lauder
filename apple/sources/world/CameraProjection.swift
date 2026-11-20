import simd

/// The game camera's mapping between the screen and the ground, the plane y = 0, so a touch
/// order can mark the ground under the finger (ADR 0003, phase S3). The camera looks at
/// `target` from `eye` with world up as its up, and a vertical field of view, as GameWorld
/// places it.
struct CameraProjection {
  let eye: SIMD3<Float>
  let target: SIMD3<Float>
  /// The vertical field of view, in degrees.
  let fieldOfView: Float
  /// The screen's width over its height.
  let aspect: Float

  private var axes: (forward: SIMD3<Float>, right: SIMD3<Float>, up: SIMD3<Float>) {
    let forward = simd_normalize(target - eye)
    let right = simd_normalize(simd_cross(forward, [0, 1, 0]))
    return (forward, right, simd_cross(right, forward))
  }

  private var halfHeight: Float { tan(fieldOfView * .pi / 360) }

  /// The direction from the camera through a point on the screen, given from 0 to 1 across
  /// and down. It is not normalised: one unit along it is one unit along the view.
  func direction(atScreen point: SIMD2<Float>) -> SIMD3<Float>? {
    guard point.x.isFinite, point.y.isFinite, aspect.isFinite, aspect > 0 else { return nil }
    let (forward, right, up) = axes
    let across = (point.x * 2 - 1) * halfHeight * aspect
    let upwards = (1 - point.y * 2) * halfHeight
    return forward + right * across + up * upwards
  }

  /// The ground under a point on the screen; nil when the ray from the camera through it does
  /// not come down to the ground.
  func ground(atScreen point: SIMD2<Float>) -> SIMD2<Float>? {
    guard let direction = direction(atScreen: point), direction.y < -0.0001, eye.y > 0 else {
      return nil
    }
    let hit = eye + direction * (-eye.y / direction.y)
    return SIMD2(hit.x, hit.z)
  }

  /// How far along `direction` from the camera a ray enters a box; nil when it misses, or the
  /// camera is inside it.
  func entry(
    along direction: SIMD3<Float>, minimum: SIMD3<Float>, maximum: SIMD3<Float>
  ) -> Float? {
    var near: Float = 0
    var far = Float.infinity
    for axis in 0..<3 {
      if abs(direction[axis]) < 0.000001 {
        guard eye[axis] >= minimum[axis], eye[axis] <= maximum[axis] else { return nil }
        continue
      }
      let first = (minimum[axis] - eye[axis]) / direction[axis]
      let second = (maximum[axis] - eye[axis]) / direction[axis]
      near = max(near, min(first, second))
      far = min(far, max(first, second))
      guard near <= far else { return nil }
    }
    return near > 0 ? near : nil
  }

  /// Where a point on the ground shows on the screen, from 0 to 1 across and down; nil when it
  /// is behind the camera.
  func screen(ofGround point: SIMD2<Float>) -> SIMD2<Float>? {
    let (forward, right, up) = axes
    let offset = SIMD3(point.x, 0, point.y) - eye
    let depth = simd_dot(offset, forward)
    guard depth > 0.0001, aspect > 0 else { return nil }
    let across = simd_dot(offset, right) / depth / (halfHeight * aspect)
    let upwards = simd_dot(offset, up) / depth / halfHeight
    return SIMD2((across + 1) / 2, (1 - upwards) / 2)
  }
}
