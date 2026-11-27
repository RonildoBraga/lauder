import simd

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

  /// The leader's shot from `start`: at the `locked` hostile when there is a lock, or else along
  /// the stick's `aim` when there is one, or else at the assisted target or along `facing`: nil
  /// when it would meet a hostile who is not yet a target. `hostiles` are those standing in
  /// view, and `blockers` what stops a shot.
  static func shot(
    from start: SIMD2<Float>, aim: SIMD2<Float>?, locked: String? = nil, facing: SIMD2<Float>,
    range: Float, hostiles: [Hostile], blockers: [PartyMotion.Box]
  ) -> ShotPath? {
    let isClear = { LineOfSight.isClear(from: $0, to: $1, obstacles: blockers) }
    let targets = hostiles.filter {
      $0.isTarget
    }.map {
      Targeting.Candidate(id: $0.id, position: $0.position)
    }
    if let locked {
      // A lock takes its hostile while they are a target in reach and in sight. Otherwise the
      // shot flies the way the leader faces, which turns towards them (ADR 0020).
      if let target = targets.first(where: { $0.id == locked }),
        simd_distance(target.position, start) <= range, isClear(start, target.position)
      {
        return ShotPath(start: start, end: target.position, strike: .body(locked))
      }
      return ray(from: start, along: facing, range: range, hostiles: hostiles, blockers: blockers)
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
  /// Distance from a projected body, in screen points, rather than world units or pixels.
  static let touchRadius: Float = 30

  /// The nearest on-screen body to a tap. Projection and body heights come from the world;
  /// this value-only query neither changes the lock nor decides whether a shot is allowed.
  static func touched(
    at point: SIMD2<Float>, viewHeight: Float, projection: CameraProjection,
    candidates: [Candidate], height: (String) -> Float
  ) -> String? {
    let scale = SIMD2(projection.aspect * viewHeight, viewHeight)
    guard point.x.isFinite, point.y.isFinite,
      (0...1).contains(point.x), (0...1).contains(point.y),
      scale.x.isFinite, scale.y.isFinite, scale.x > 0, scale.y > 0
    else { return nil }
    return candidates.compactMap { candidate -> (id: String, distance: Float)? in
      let height = height(candidate.id)
      guard height.isFinite, height > 0,
        let feet = projection.screen(ofGround: candidate.position),
        let head = projection.screen(
          ofWorld: [candidate.position.x, height, candidate.position.y]),
        let segment = visibleSegment(from: feet, to: head)
      else { return nil }
      let start = segment.0 * scale
      let along = (segment.1 - segment.0) * scale
      let offset = point * scale - start
      let length = simd_length_squared(along)
      let fraction = length > 0 ? min(1, max(0, simd_dot(offset, along) / length)) : 0
      let distance = simd_length_squared(offset - along * fraction)
      guard distance.isFinite, distance <= touchRadius * touchRadius else { return nil }
      return (candidate.id, distance)
    }.min {
      $0.distance == $1.distance ? $0.id < $1.id : $0.distance < $1.distance
    }?.id
  }

  /// Clip to the viewport, so a nearby but entirely off-screen body is not a tap target.
  private static func visibleSegment(
    from start: SIMD2<Float>, to end: SIMD2<Float>
  ) -> (SIMD2<Float>, SIMD2<Float>)? {
    let delta = end - start
    var first: Float = 0
    var last: Float = 1
    for axis in 0..<2 {
      if abs(delta[axis]) < 0.000001 {
        guard (0...1).contains(start[axis]) else { return nil }
      } else {
        let low = -start[axis] / delta[axis]
        let high = (1 - start[axis]) / delta[axis]
        first = max(first, min(low, high))
        last = min(last, max(low, high))
        guard first <= last else { return nil }
      }
    }
    return (start + delta * first, start + delta * last)
  }

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

  /// Whom a lock press takes first: the hostile Fire would take, or else the nearest
  /// (ADR 0020). `candidates` are those that can be locked.
  static func firstLock(
    from position: SIMD2<Float>, facing: SIMD2<Float>, candidates: [Candidate],
    isClear: (SIMD2<Float>, SIMD2<Float>) -> Bool
  ) -> String? {
    target(
      from: position, facing: facing, candidates: candidates, range: .infinity, isClear: isClear)
      ?? candidates.min {
        simd_distance_squared($0.position, position) < simd_distance_squared($1.position, position)
      }?.id
  }

  /// Whom a lock press moves the lock to: the next candidate clockwise round `centre` as the
  /// screen shows the ground, with `up` and `right` its directions there, and `current` again
  /// when nobody else can be locked; nil when `current` cannot be locked (ADR 0020).
  static func nextLock(
    after current: String, around centre: SIMD2<Float>, candidates: [Candidate],
    up: SIMD2<Float>, right: SIMD2<Float>
  ) -> String? {
    func bearing(_ candidate: Candidate) -> Float {
      let offset = candidate.position - centre
      let angle = atan2(simd_dot(offset, right), simd_dot(offset, up))
      return angle < 0 ? angle + 2 * .pi : angle
    }
    let round = candidates.map { (id: $0.id, bearing: bearing($0)) }.sorted {
      $0.bearing == $1.bearing ? $0.id < $1.id : $0.bearing < $1.bearing
    }
    guard let index = round.firstIndex(where: { $0.id == current }) else { return nil }
    return round[(index + 1) % round.count].id
  }
}
