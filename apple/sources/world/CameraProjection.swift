import simd

/// Perspective or parallel mapping between the screen and world geometry. Projection stays independent
/// of scene entities, actor selection and combat rules.
struct CameraProjection {
  let eye: SIMD3<Float>
  let target: SIMD3<Float>
  /// The vertical field of view, in degrees.
  let fieldOfView: Float
  /// The screen's width over its height.
  let aspect: Float
  /// Full vertical world span for a parallel view; nil keeps perspective projection.
  let orthographicHeight: Float?

  struct Ray {
    let origin: SIMD3<Float>
    let direction: SIMD3<Float>
  }

  init(
    eye: SIMD3<Float>, target: SIMD3<Float>, fieldOfView: Float, aspect: Float,
    orthographicHeight: Float? = nil
  ) {
    self.eye = eye
    self.target = target
    self.fieldOfView = fieldOfView
    self.aspect = aspect
    self.orthographicHeight = orthographicHeight
  }

  private var axes: (forward: SIMD3<Float>, right: SIMD3<Float>, up: SIMD3<Float>) {
    let forward = simd_normalize(target - eye)
    let right = simd_normalize(simd_cross(forward, [0, 1, 0]))
    return (forward, right, simd_cross(right, forward))
  }

  private var halfHeight: Float {
    orthographicHeight.map { $0 / 2 } ?? tan(fieldOfView * .pi / 360)
  }

  private var isValid: Bool {
    guard eye.indices.allSatisfy({ eye[$0].isFinite && target[$0].isFinite }),
      aspect.isFinite, aspect > 0, simd_distance_squared(eye, target) > 0.000001,
      simd_length_squared(simd_cross(target - eye, [0, 1, 0])) > 0.000001
    else { return false }
    if let orthographicHeight { return orthographicHeight.isFinite && orthographicHeight > 0 }
    return fieldOfView.isFinite && fieldOfView > 0 && fieldOfView < 180
  }

  /// The ray through a viewport point. Parallel rays have different origins and the same
  /// direction; perspective rays share the eye and one unit of direction spans one unit of depth.
  func ray(atScreen point: SIMD2<Float>) -> Ray? {
    guard isValid, point.x.isFinite, point.y.isFinite else { return nil }
    let (forward, right, up) = axes
    let across = (point.x * 2 - 1) * halfHeight * aspect
    let upwards = (1 - point.y * 2) * halfHeight
    let shift = right * across + up * upwards
    if orthographicHeight != nil { return Ray(origin: eye + shift, direction: forward) }
    return Ray(origin: eye, direction: forward + shift)
  }

  /// The ground under a point on the screen; nil when the ray from the camera through it does
  /// not come down to the ground.
  func ground(atScreen point: SIMD2<Float>) -> SIMD2<Float>? {
    guard let ray = ray(atScreen: point), ray.direction.y < -0.0001, ray.origin.y > 0 else {
      return nil
    }
    let hit = ray.origin + ray.direction * (-ray.origin.y / ray.direction.y)
    return SIMD2(hit.x, hit.z)
  }

  /// How far along a viewport ray it enters a box; nil when it misses or starts inside.
  func entry(
    along ray: Ray, minimum: SIMD3<Float>, maximum: SIMD3<Float>
  ) -> Float? {
    let origin = ray.origin
    let direction = ray.direction
    guard
      simd_length_squared(direction) > 0.000001,
      origin.indices.allSatisfy({
        origin[$0].isFinite && direction[$0].isFinite && minimum[$0].isFinite
          && maximum[$0].isFinite && minimum[$0] <= maximum[$0]
      })
    else { return nil }
    var near = -Float.infinity
    var far = Float.infinity
    for axis in 0..<3 {
      if abs(direction[axis]) < 0.000001 {
        guard origin[axis] >= minimum[axis], origin[axis] <= maximum[axis] else { return nil }
      } else {
        let first = (minimum[axis] - origin[axis]) / direction[axis]
        let last = (maximum[axis] - origin[axis]) / direction[axis]
        near = max(near, min(first, last))
        far = min(far, max(first, last))
        if near > far { return nil }
      }
    }
    return near > 0 && near.isFinite ? near : nil
  }

  /// Where a point on the ground shows on the screen, from 0 to 1 across and down; nil when it
  /// is behind the camera.
  func screen(ofGround point: SIMD2<Float>) -> SIMD2<Float>? {
    screen(ofWorld: [point.x, 0, point.y])
  }

  /// A real three-dimensional impact in the same full viewport as the scene. Offscreen
  /// coordinates stay offscreen; callers decide whether to display them.
  func screen(ofWorld point: SIMD3<Float>) -> SIMD2<Float>? {
    guard isValid, point.indices.allSatisfy({ point[$0].isFinite })
    else { return nil }
    let (forward, right, up) = axes
    let offset = point - eye
    let depth = simd_dot(offset, forward)
    guard depth.isFinite, depth > 0.0001 else { return nil }
    let scale = orthographicHeight == nil ? depth : 1
    let across = simd_dot(offset, right) / scale / (halfHeight * aspect)
    let upwards = simd_dot(offset, up) / scale / halfHeight
    guard across.isFinite, upwards.isFinite else { return nil }
    return SIMD2((across + 1) / 2, (1 - upwards) / 2)
  }
}
