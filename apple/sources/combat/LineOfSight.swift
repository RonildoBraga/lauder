import simd

/// Sight lines on the flat floor: a shot is a straight line against the same blocker footprints
/// that movement uses, so a tower's pier or legs give cover to whoever stands behind them, on
/// either side.
enum LineOfSight {
  /// Whether nothing is in the way, stopping at the first blocker without building a list.
  static func isClear(
    from start: SIMD2<Float>, to end: SIMD2<Float>, obstacles: [PartyMotion.Box]
  ) -> Bool {
    let delta = end - start
    return !obstacles.contains {
      entry(from: start, along: delta, minimum: $0.minimum, maximum: $0.maximum, limit: 1) != nil
    }
  }

  /// How far along `delta` from `start`, in multiples of it, a line first enters the box from
  /// `minimum` to `maximum`, by the slab method: from 0, when it starts inside, up to `limit`,
  /// which is 1 for a segment that ends at `start + delta` and infinity for a ray; nil when it
  /// misses. A line that only touches a face enters there, and along an axis where `delta` is
  /// next to nothing, the line enters only if `start` lies between the faces.
  static func entry<Vector: SIMD>(
    from start: Vector, along delta: Vector, minimum: Vector, maximum: Vector, limit: Float
  ) -> Float? where Vector.Scalar == Float {
    var near: Float = 0
    var far = limit
    for axis in delta.indices {
      if abs(delta[axis]) < 0.000001 {
        guard start[axis] >= minimum[axis], start[axis] <= maximum[axis] else { return nil }
        continue
      }
      let first = (minimum[axis] - start[axis]) / delta[axis]
      let second = (maximum[axis] - start[axis]) / delta[axis]
      near = max(near, min(first, second))
      far = min(far, max(first, second))
      guard near <= far else { return nil }
    }
    return near
  }
}
