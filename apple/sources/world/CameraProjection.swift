import simd

/// The game camera's mapping between the screen and the ground, so a touch
/// order can mark the ground, or a block, under the finger (ADR 0003, phase S3). The camera
/// looks at `target` from `eye` with world up as its up, and a vertical field of view, as
/// GameWorld places it.
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

  /// What the ray from the camera through a point on the screen meets first: one of these
  /// blocks, or the ground; nil when it meets neither.
  func firstHit(
    atScreen point: SIMD2<Float>, blocks: [(centre: SIMD3<Float>, size: SIMD3<Float>)]
  ) -> SIMD3<Float>? {
    guard let direction = direction(atScreen: point) else { return nil }
    var nearest = ground(along: direction) ?? .infinity
    for block in blocks {
      if let distance = entry(
        along: direction, minimum: block.centre - block.size / 2,
        maximum: block.centre + block.size / 2),
        distance < nearest
      {
        nearest = distance
      }
    }
    return nearest.isFinite ? eye + direction * nearest : nil
  }

  /// How far along `direction` from the camera a ray enters a box; nil when it misses, or the
  /// camera is inside it.
  func entry(
    along direction: SIMD3<Float>, minimum: SIMD3<Float>, maximum: SIMD3<Float>
  ) -> Float? {
    let near = LineOfSight.entry(
      from: eye, along: direction, minimum: minimum, maximum: maximum, limit: .infinity)
    return near.flatMap { $0 > 0 ? $0 : nil }
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
