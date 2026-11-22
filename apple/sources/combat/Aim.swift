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
