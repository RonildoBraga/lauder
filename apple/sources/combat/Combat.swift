import simd

/// A weapon's timing and reach (ADR 0004). Plain values: the world times shots with them.
struct Weapon: Sendable {
  /// The farthest an assisted shot reaches, in metres.
  let range: Float
  /// Seconds between shots while Fire is held.
  let interval: Float
  /// Seconds from the first Fire press until a holstered weapon can shoot.
  let drawTime: Float

  /// Miki's precision carbine. Starting values for playtests; the range is less than the 19 m
  /// or so that the camera shows ahead of her, so she never shoots at something off screen
  /// ahead.
  static let carbine = Weapon(range: 14, interval: 0.4, drawTime: 0.35)
}

/// Sight lines on the flat floor: a shot is a straight line against the same blocker footprints
/// that movement uses, so a tower's pier or legs give cover to whoever stands behind them, on
/// either side.
enum LineOfSight {
  static func isClear(
    from start: SIMD2<Float>, to end: SIMD2<Float>, obstacles: [PartyMotion.Box]
  ) -> Bool {
    firstBlock(from: start, to: end, obstacles: obstacles) == nil
  }

  /// How far along the line, from 0 at the start to 1 at the end, it first enters a blocker;
  /// nil when nothing is in the way.
  static func firstBlock(
    from start: SIMD2<Float>, to end: SIMD2<Float>, obstacles: [PartyMotion.Box]
  ) -> Float? {
    obstacles.compactMap {
      entry(from: start, along: end - start, minimum: $0.minimum, maximum: $0.maximum, limit: 1)
    }.min()
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

/// Assisted aim for a phone: no manual aiming. Fire picks the nearest hostile within range and
/// in sight, preferring one ahead of the shooter.
enum Targeting {
  struct Candidate {
    let id: String
    let position: SIMD2<Float>
  }

  /// Within this angle of the shooter's facing, a hostile counts as ahead.
  static let aheadAngle: Float = 75 * .pi / 180

  static func target(
    from position: SIMD2<Float>, facing: SIMD2<Float>, candidates: [Candidate], range: Float,
    isClear: (SIMD2<Float>, SIMD2<Float>) -> Bool
  ) -> String? {
    let visible = candidates.filter {
      simd_distance($0.position, position) <= range && isClear(position, $0.position)
    }
    let ahead = visible.filter {
      let offset = $0.position - position
      guard simd_length(offset) > 0.001 else { return true }
      return simd_dot(simd_normalize(offset), facing) >= cos(aheadAngle)
    }
    let pool = ahead.isEmpty ? visible : ahead
    return pool.min {
      simd_distance_squared($0.position, position) < simd_distance_squared($1.position, position)
    }?.id
  }
}
