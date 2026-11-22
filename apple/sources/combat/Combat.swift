import simd

/// A weapon's timing and reach (ADR 0004), and how its shots scatter (ADR 0008). Plain values:
/// the world times shots with them.
struct Weapon: Sendable {
  /// Which weapon it is, for how its shots sound and feel (ADR 0008). The hostiles' rifle has
  /// no timing of its own here: their wind-ups time its shots.
  enum Kind: Hashable, Sendable {
    case carbine, lightBurst, closeScatter, rifle

    var name: String {
      switch self {
      case .carbine: "Carbine"
      case .lightBurst: "Burst weapon"
      case .closeScatter: "Scatter weapon"
      case .rifle: "Rifle"
      }
    }
  }

  let kind: Kind
  /// Effective stopping reach, in metres. Fired rounds still travel across the whole level.
  let range: Float
  /// Seconds between shots while Fire is held, or between bursts.
  let interval: Float
  /// Seconds from the first Fire press until a holstered weapon can shoot.
  let drawTime: Float
  /// Consecutive discharges before the automatic reload. This is a handling limit, not
  /// another inventory: the session still counts the party's remaining player-fired rounds.
  var capacity = 12
  /// Seconds to ready a fresh magazine, overlapping the normal interval after its last shot.
  var reloadTime: Float = 1.2
  /// Shots in each burst, `burstGap` seconds apart; one for single shots.
  var burst = 1
  var burstGap: Float = 0
  /// Hits each shot deals: a scatter weapon's blast counts for more than one.
  var damage = 1
  /// How far its shots scatter when the player fires it (ADR 0008).
  var spread = Spread.none

  /// Miki's precision carbine. The range limits assistance, not the fired bullet's travel.
  /// Standing still, its first shot lands within 10 cm at assisted reach; a long burst, or
  /// firing on the move, scatters (ADR 0008).
  static let carbine = Weapon(
    kind: .carbine, range: 14, interval: 0.4, drawTime: 0.35, capacity: 12, reloadTime: 1.2,
    spread: Spread(
      rest: Spread.degrees(0.4), perShot: Spread.degrees(1.6), widest: Spread.degrees(6),
      recovery: Spread.degrees(2.5), moving: Spread.degrees(2.5), turning: Spread.degrees(2)))
  /// Laura's light burst weapon (ADR 0005): bursts of three quick shots, reaching a little
  /// less far than the carbine. Starting values, to tune in play.
  static let lightBurst = Weapon(
    kind: .lightBurst, range: 12, interval: 1.8, drawTime: 0.5, capacity: 18, reloadTime: 1.4,
    burst: 3, burstGap: 0.12,
    spread: Spread(
      rest: Spread.degrees(1.2), perShot: Spread.degrees(1.1), widest: Spread.degrees(8),
      recovery: Spread.degrees(3.5), moving: Spread.degrees(2), turning: Spread.degrees(2)))
  /// Tom's close scatter weapon (ADR 0005): a slow blast that counts as two hits, only at close
  /// range. Starting values, to tune in play.
  static let closeScatter = Weapon(
    kind: .closeScatter, range: 7, interval: 0.8, drawTime: 0.55, capacity: 4, reloadTime: 1.8,
    damage: 2,
    spread: Spread(
      rest: Spread.degrees(6), perShot: Spread.degrees(2), widest: Spread.degrees(10),
      recovery: Spread.degrees(4), moving: Spread.degrees(2), turning: Spread.degrees(1)))

  /// The original enemy rifle keeps its prior accuracy profile; encounter specs time it.
  static let rifle = Weapon(
    kind: .rifle, range: 18, interval: 0.4, drawTime: 0.35,
    spread: Spread(
      rest: Spread.degrees(2.5), perShot: Spread.degrees(1), widest: Spread.degrees(8),
      recovery: Spread.degrees(3), moving: Spread.degrees(2), turning: Spread.degrees(4)))

  /// A long-travelling scatter round loses its stopping bonus beyond its effective reach.
  func damage(at distance: Float) -> Int {
    distance.isFinite && distance > range ? min(1, damage) : damage
  }

  /// Each traveller's weapon.
  static func forMember(_ member: PartyMember) -> Weapon {
    switch member {
    case .miki: .carbine
    case .laura: .lightBurst
    case .tom: .closeScatter
    }
  }
}

/// How a weapon's shots scatter (ADR 0008): each goes within a cone either side of where it is
/// aimed. Each shot widens the cone, up to the widest, and it narrows again with time; moving
/// and turning widen it while they last. Angles are in radians, either side of the aim.
struct Spread: Sendable {
  /// The cone at rest, standing still.
  var rest: Float
  /// What each shot adds.
  var perShot: Float
  /// The widest it can be.
  var widest: Float
  /// How fast it narrows again, in radians a second.
  var recovery: Float
  /// What moving adds at full speed, and turning at full turning speed.
  var moving: Float
  var turning: Float

  /// No spread at all: every shot goes exactly where it is aimed.
  static let none = Spread(rest: 0, perShot: 0, widest: 0, recovery: 0, moving: 0, turning: 0)

  static func degrees(_ value: Float) -> Float { value * .pi / 180 }
}

/// A weapon's spread as the shooter fires, moves and turns (ADR 0008): the widening its shots
/// have built up, which narrows again with time.
struct Scatter: Sendable {
  private(set) var bloom: Float = 0

  /// One simulation step: the widening narrows.
  mutating func settle(dt: Float, spread: Spread) {
    bloom = max(0, bloom - spread.recovery * dt)
  }

  /// A shot widens it, up to the widest.
  mutating func fired(spread: Spread) {
    bloom = min(max(0, spread.widest - spread.rest), bloom + spread.perShot)
  }

  /// The cone now, either side of the aim, for a shooter moving at `speed` and turning at
  /// `turning`, each a share of full speed from 0 to 1.
  func angle(spread: Spread, speed: Float, turning: Float) -> Float {
    let movement = spread.moving * min(max(speed, 0), 1) + spread.turning * min(max(turning, 0), 1)
    return min(spread.widest, spread.rest + bloom + movement)
  }

  /// How far one shot turns from its aim within a cone of `angle` either side: anywhere in it,
  /// more often near the middle.
  static func deviation(within angle: Float, using generator: inout some RandomNumberGenerator)
    -> Float
  {
    guard angle > 0 else { return 0 }
    let first = Float.random(in: 0...1, using: &generator)
    let second = Float.random(in: 0...1, using: &generator)
    return (first + second - 1) * angle
  }
}

/// A small, repeatable source of random numbers (SplitMix64): the same seed gives the same shots,
/// so tests and playtests replay exactly.
struct SeededRandom: RandomNumberGenerator, Sendable {
  private var state: UInt64

  init(seed: UInt64) {
    state = seed
  }

  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var value = state
    value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
    value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
    return value ^ (value >> 31)
  }
}

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

/// Where one shot goes (ADR 0007): from the shooter to where it strikes, or to the end of its
/// reach.
struct ShotPath: Equatable, Sendable {
  enum Strike: Equatable, Sendable {
    /// A body, by its id: a hostile the leader or a companion hits, or a member a hostile hits.
    case body(String)
    /// A block in the way.
    case scenery
    /// Nothing within reach.
    case nothing
  }

  let start: SIMD2<Float>
  let end: SIMD2<Float>
  let strike: Strike
}

/// Aiming the leader's weapon (ADR 0007). With the right stick, a shot goes where the stick
/// points, and the help picks a hostile only within a narrow cone of it. Without it, as on
/// touch, Fire shoots the assisted target, or straight ahead when there is none. A shot that
/// hits no hostile flies on until a block stops it or its reach runs out, so it can strike a
/// wall with nobody about. The leader never fires first at someone: a shot that would meet a
/// hostile who is not yet a target holds.
enum Aim {
  /// Within this angle of the stick's aim, the help picks a hostile.
  static let helpAngle: Float = 8 * .pi / 180
  /// How close to a standing figure's centre a shot must pass to meet them.
  static let bodyRadius: Float = 0.35

  /// A hostile as a shot sees them: where they stand, and whether they are a target yet.
  struct Hostile {
    let id: String
    let position: SIMD2<Float>
    let isTarget: Bool
  }

  /// The leader's shot from `start`, along the stick's `aim` when there is one, or else at the
  /// assisted target or along `facing`: nil when it would meet a hostile who is not yet a target.
  /// `hostiles` are those standing in view, and `blockers` what stops a shot.
  static func shot(
    from start: SIMD2<Float>, aim: SIMD2<Float>?, facing: SIMD2<Float>, range: Float,
    hostiles: [Hostile], blockers: [PartyMotion.Box]
  ) -> ShotPath? {
    let isClear = { LineOfSight.isClear(from: $0, to: $1, obstacles: blockers) }
    let targets = hostiles.filter {
      $0.isTarget
    }.map {
      Targeting.Candidate(id: $0.id, position: $0.position)
    }
    let direction: SIMD2<Float>
    let chosen: String?
    if let aim, simd_length(aim) > 0.0001 {
      direction = simd_normalize(aim)
      chosen = Targeting.aimed(
        along: direction, within: helpAngle, from: start, candidates: targets, range: range,
        isClear: isClear)
    } else {
      direction = facing
      chosen = Targeting.target(
        from: start, facing: facing, candidates: targets, range: range, isClear: isClear)
    }
    if let chosen, let target = targets.first(where: { $0.id == chosen }) {
      return ShotPath(start: start, end: target.position, strike: .body(chosen))
    }
    return ray(from: start, along: direction, range: range, hostiles: hostiles, blockers: blockers)
  }

  /// A shot straight along `direction`: it meets the first hostile it passes close to before
  /// any block, holding when they are not yet a target, or else strikes the first block, or
  /// runs out at `range`.
  static func ray(
    from start: SIMD2<Float>, along direction: SIMD2<Float>, range: Float,
    hostiles: [Hostile], blockers: [PartyMotion.Box]
  ) -> ShotPath? {
    guard simd_length(direction) > 0.0001 else { return nil }
    let unit = simd_normalize(direction)
    let block = blockers.compactMap {
      LineOfSight.entry(
        from: start, along: unit, minimum: $0.minimum, maximum: $0.maximum, limit: range)
    }.min()
    let reach = block ?? range
    let met = hostiles.compactMap { hostile -> (hostile: Hostile, distance: Float)? in
      let offset = hostile.position - start
      let along = simd_dot(offset, unit)
      let aside = simd_length(offset - unit * along)
      guard along > 0, along <= reach, aside <= bodyRadius else { return nil }
      return (hostile, along)
    }.min { $0.distance < $1.distance }
    if let met {
      guard met.hostile.isTarget else { return nil }
      return ShotPath(start: start, end: met.hostile.position, strike: .body(met.hostile.id))
    }
    return ShotPath(
      start: start, end: start + unit * reach, strike: block == nil ? .nothing : .scenery)
  }

  /// What stops a shot fired at `height`: blocks that reach that height or rise above it, so a
  /// shot flies over a low block.
  static func blockers(_ boxes: [Level.Box], above height: Float) -> [PartyMotion.Box] {
    boxes.filter { $0.position.y + $0.size.y / 2 >= height }.map(\.footprint)
  }
}

/// Assisted aim: Fire picks the nearest hostile within range and in sight, preferring one ahead
/// of the shooter; the right stick's help picks one only near where it aims (ADR 0007).
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

  /// The candidate within `angle` of an aimed shot's `direction`, within range and in sight,
  /// nearest that direction: the help for a shot aimed with the right stick (ADR 0007).
  static func aimed(
    along direction: SIMD2<Float>, within angle: Float, from position: SIMD2<Float>,
    candidates: [Candidate], range: Float, isClear: (SIMD2<Float>, SIMD2<Float>) -> Bool
  ) -> String? {
    candidates.compactMap { candidate -> (id: String, cosine: Float)? in
      let offset = candidate.position - position
      let distance = simd_length(offset)
      guard distance > 0.001, distance <= range else { return nil }
      let cosine = simd_dot(offset / distance, direction)
      guard cosine >= cos(angle), isClear(position, candidate.position) else { return nil }
      return (candidate.id, cosine)
    }.max { $0.cosine < $1.cosine }?.id
  }

}
