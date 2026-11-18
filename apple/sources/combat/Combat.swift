import simd

/// A weapon's timing and reach (ADR 0004). Plain values: the world times shots with them.
struct Weapon: Sendable {
  /// The farthest an assisted shot reaches, in metres.
  let range: Float
  /// Seconds between shots while Fire is held.
  let interval: Float
  /// Seconds from the first Fire press until a holstered weapon can shoot.
  let drawTime: Float

  /// Miki's precision carbine. Starting values for playtests; the range is about what the
  /// camera shows ahead of her during a fight, so she never shoots at something off screen.
  static let carbine = Weapon(range: 14, interval: 0.4, drawTime: 0.35)
}

/// Sight lines on the flat floor: a shot is a straight line against the same blocker footprints
/// that movement uses, so a car gives cover to whoever stands behind it, on either side.
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
    obstacles.compactMap { entry(from: start, to: end, box: $0) }.min()
  }

  /// Where a segment enters an axis-aligned box, by the slab method; nil if it misses.
  static func entry(from start: SIMD2<Float>, to end: SIMD2<Float>, box: PartyMotion.Box) -> Float?
  {
    let delta = end - start
    var low: Float = 0
    var high: Float = 1
    for axis in 0..<2 {
      if abs(delta[axis]) < 0.000001 {
        guard start[axis] >= box.minimum[axis], start[axis] <= box.maximum[axis] else {
          return nil
        }
        continue
      }
      var near = (box.minimum[axis] - start[axis]) / delta[axis]
      var far = (box.maximum[axis] - start[axis]) / delta[axis]
      if near > far { swap(&near, &far) }
      low = max(low, near)
      high = min(high, far)
      if low > high { return nil }
    }
    return low
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
