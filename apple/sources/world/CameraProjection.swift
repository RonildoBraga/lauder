import simd

/// Perspective mapping between the screen and world geometry. Projection stays independent
/// of scene entities, actor selection and combat rules.
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
    guard let direction = direction(atScreen: point), let distance = ground(along: direction)
    else { return nil }
    let hit = eye + direction * distance
    return SIMD2(hit.x, hit.z)
  }

  /// How far along `direction` from the camera a ray enters a box; nil when it misses, or the
  /// camera is inside it.
  func entry(
    along direction: SIMD3<Float>, minimum: SIMD3<Float>, maximum: SIMD3<Float>
  ) -> Float? {
    guard
      eye.indices.allSatisfy({
        eye[$0].isFinite && direction[$0].isFinite && minimum[$0].isFinite
          && maximum[$0].isFinite && minimum[$0] <= maximum[$0]
      })
    else { return nil }
    var near = -Float.infinity
    var far = Float.infinity
    for axis in 0..<3 {
      if abs(direction[axis]) < 0.000001 {
        guard eye[axis] >= minimum[axis], eye[axis] <= maximum[axis] else { return nil }
      } else {
        let first = (minimum[axis] - eye[axis]) / direction[axis]
        let last = (maximum[axis] - eye[axis]) / direction[axis]
        near = max(near, min(first, last))
        far = min(far, max(first, last))
        if near > far { return nil }
      }
    }
    return near > 0 && near.isFinite ? near : nil
  }

  /// How far along `direction` from the camera a ray comes down to the ground; nil when it
  /// does not.
  private func ground(along direction: SIMD3<Float>) -> Float? {
    return direction.y < -0.0001 && eye.y > 0 ? -eye.y / direction.y : nil
  }

  /// Where a point on the ground shows on the screen, from 0 to 1 across and down; nil when it
  /// is behind the camera.
  func screen(ofGround point: SIMD2<Float>) -> SIMD2<Float>? {
    screen(ofWorld: [point.x, 0, point.y])
  }

  /// A real three-dimensional impact in the same full viewport as the scene. Offscreen
  /// coordinates stay offscreen; callers decide whether to display them.
  func screen(ofWorld point: SIMD3<Float>) -> SIMD2<Float>? {
    guard point.indices.allSatisfy({ point[$0].isFinite }),
      eye.indices.allSatisfy({ eye[$0].isFinite }),
      target.indices.allSatisfy({ target[$0].isFinite }),
      fieldOfView.isFinite, fieldOfView > 0, fieldOfView < 180,
      aspect.isFinite, aspect > 0
    else { return nil }
    let (forward, right, up) = axes
    let offset = point - eye
    let depth = simd_dot(offset, forward)
    guard depth.isFinite, depth > 0.0001 else { return nil }
    let across = simd_dot(offset, right) / depth / (halfHeight * aspect)
    let upwards = simd_dot(offset, up) / depth / halfHeight
    guard across.isFinite, upwards.isFinite else { return nil }
    return SIMD2((across + 1) / 2, (1 - upwards) / 2)
  }
}
