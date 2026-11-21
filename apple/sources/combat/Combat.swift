import simd

/// A weapon's timing and reach (ADR 0004). Plain values: the world times shots with them.
struct Weapon: Sendable {
  /// The farthest an assisted shot reaches, in metres.
  let range: Float
  /// Seconds between shots while Fire is held, or between a companion's bursts.
  let interval: Float
  /// Seconds from the first Fire press until a holstered weapon can shoot; for a companion's,
  /// from the moment a fight is under way until they first fire.
  let drawTime: Float
  /// Shots in each of a companion's bursts, `burstGap` seconds apart; one for single shots.
  var burst = 1
  var burstGap: Float = 0
  /// Hits each shot deals: a scatter weapon's blast counts for more than one.
  var damage = 1

  /// Miki's precision carbine. Starting values for playtests; the range is less than the 19 m
  /// or so that the camera shows ahead of her, so she never shoots at something off screen
  /// ahead.
  static let carbine = Weapon(range: 14, interval: 0.4, drawTime: 0.35)
  /// Laura's light burst weapon (ADR 0005): bursts of three quick shots, reaching a little
  /// less far than the carbine. Starting values, to tune in play.
  static let lightBurst = Weapon(
    range: 12, interval: 1.8, drawTime: 0.5, burst: 3, burstGap: 0.12)
  /// Tom's close scatter weapon (ADR 0005): a slow blast that counts as two hits, only at close
  /// range. Starting values, to tune in play.
  static let closeScatter = Weapon(range: 7, interval: 1.5, drawTime: 0.7, damage: 2)
}

/// When a weapon that fires by itself shoots, as a companion's does once a fight is under way
/// (ADR 0005): first after its draw time, then each shot of a burst a short gap apart, with the
/// weapon's interval between bursts. It holds fire while there is nothing to shoot at, and a
/// burst whose target is gone stops there.
struct AutoFire {
  private var wait: Float
  private var shotsLeft = 0

  init(weapon: Weapon) {
    wait = weapon.drawTime
  }

  /// One simulation step: true when a shot fires now.
  mutating func step(dt: Float, weapon: Weapon, hasTarget: Bool) -> Bool {
    wait = max(0, wait - dt)
    guard hasTarget else {
      if shotsLeft > 0 {
        shotsLeft = 0
        wait = weapon.interval
      }
      return false
    }
    guard wait <= 0 else { return false }
    if shotsLeft == 0 { shotsLeft = weapon.burst }
    shotsLeft -= 1
    wait = shotsLeft > 0 ? weapon.burstGap : weapon.interval
    return true
  }
}

/// Miki's signature (ADR 0005): a precise shot that cancels one hostile's wind-up within her
/// reach and in her clear sight, after which the hostile recovers before it can aim again.
enum Disrupt {
  /// How far it reaches: the carbine's range. A starting value for playtests.
  static let reach = Weapon.carbine.range

  /// The wind-up a Disrupt from `position` cancels: of the hostiles aiming within reach and in
  /// sight, the one nearest its shot; nil when there is none.
  static func target(
    from position: SIMD2<Float>, hostiles: [HostileState],
    isClear: (SIMD2<Float>, SIMD2<Float>) -> Bool
  ) -> String? {
    hostiles.compactMap { hostile -> (id: String, remaining: Float)? in
      guard case .aiming(let remaining) = hostile.phase,
        simd_distance(hostile.position, position) <= reach, isClear(position, hostile.position)
      else { return nil }
      return (hostile.spec.id, remaining)
    }.min { $0.remaining < $1.remaining }?.id
  }
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

  /// The nearest candidate within range and in sight, whichever way the shooter faces: a
  /// companion's own target, and whom a hostile that can aim at anyone aims at (ADR 0005).
  static func nearest(
    from position: SIMD2<Float>, candidates: [Candidate], range: Float,
    isClear: (SIMD2<Float>, SIMD2<Float>) -> Bool
  ) -> String? {
    candidates.filter {
      simd_distance($0.position, position) <= range && isClear(position, $0.position)
    }.min {
      simd_distance_squared($0.position, position) < simd_distance_squared($1.position, position)
    }?.id
  }
}
