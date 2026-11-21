import simd

/// Where companions take cover once a fight is under way: ADR 0003's cover near the slot, from
/// phase S4, tried in the combat yard (ADR 0005). Each companion weighs the spots near their
/// place, which is their formation slot or the point their order keeps them to, against keeping
/// to the place itself, and keeps their choice for at least two seconds. From a spot they step
/// out to a firing position close by while it has a target in sight, and back while a shooter's
/// wind-up aims at them.
///
/// A spot scores for being hidden from the shooters, the most dangerous first, for having a
/// firing position close by, for being near the place, and for being reachable without crossing
/// open ground. Each member's own preference weighs the choice too: Miki likes 6–10 m from her
/// target, Laura an angle off a threat's facing, and Tom a place between a close threat and a
/// teammate. Orders still win: cover is only ever sought near the place an order gives.
struct CoverPlanner {
  /// How long a companion keeps a choice before weighing the spots again.
  static let commitTime: Float = 2
  /// How far from its spot a firing position may be.
  static let peekReach: Float = 1
  /// Spots are weighed every this many navigation cells: about 40 cm apart.
  static let stride = 2
  /// Half a body's width: cover must also block the sight lines this far to either side of a
  /// spot, so that a companion who settles a little off it stays hidden.
  static let margin: Float = 0.3
  /// How close two companions' spots, or a spot and the leader, may be.
  static let spacing: Float = 0.8
  /// How much less another choice must cost to replace the one kept.
  static let switchSaving: Float = 1

  // What a choice costs; the cheapest wins.
  /// In reach and sight of the most dangerous shooter: whoever aims at the companion, or else
  /// the nearest.
  static let seenByDanger: Float = 10
  /// In reach and sight of each other shooter.
  static let seenByOther: Float = 5
  /// No firing position close by.
  static let noFiringPosition: Float = 4
  /// Each metre from the place.
  static let perMetreFromPlace: Float = 1
  /// Each metre walked to the spot.
  static let perMetreWalked: Float = 0.5
  /// Each point along the way there, at these shares of it, that a shooter can see.
  static let perOpenCrossing: Float = 1
  static let crossings: [Float] = [0.25, 0.5, 0.75]

  // Each member's own preference (ADR 0003), which only weighs the choice.
  /// Miki likes this far between her firing position and the target she would shoot from it.
  static let mikisRange: ClosedRange<Float> = 6...10
  /// What each metre outside that range costs her.
  static let perMetreOutsideMikisRange: Float = 0.5
  /// Laura likes to stand off the most dangerous threat's facing: straight in front of it costs
  /// her this much, and at its side or behind it nothing.
  static let inFrontForLaura: Float = 2
  /// Tom likes to stand between a close threat, one within this distance, and the teammate
  /// nearest it.
  static let closeThreatForTom: Float = 10
  /// What each metre off the line between them costs him, up to three metres.
  static let perMetreOffTomsLine: Float = 0.5

  /// A standing hostile, as cover sees it.
  struct Threat {
    let position: SIMD2<Float>
    /// How far its shots reach.
    let range: Float
    /// The companion its current wind-up aims at, if any.
    var aimingAt: PartyMember?
    /// Whether companions may shoot at it yet.
    var isTarget = true
    /// Which way it faces, as a unit vector, if known.
    var facing: SIMD2<Float>?
  }

  struct Input {
    /// Each companion's place: their formation slot, or the point their order keeps them to.
    let places: [PartyMember: SIMD2<Float>]
    let positions: [PartyMember: SIMD2<Float>]
    let leaderPosition: SIMD2<Float>
    let formation: GameSession.Formation
    let threats: [Threat]
    /// How far each companion's weapon reaches; a companion without one never steps out.
    let weaponRanges: [PartyMember: Float]
    let dt: Float
  }

  /// A companion's choice, and how long they have kept it.
  private struct Cover {
    /// The spot they take cover at; nil while they keep to their place, which moves with the
    /// leader as a formation slot does.
    let spot: SIMD2<Float>?
    /// Where they step out to fire from that spot, if anywhere.
    let firing: SIMD2<Float>?
    var kept: Float = 0
  }

  private let obstacles: [PartyMotion.Box]
  private var covers: [PartyMember: Cover] = [:]

  /// A planner whose sight lines meet the given blockers.
  init(obstacles: [PartyMotion.Box]) {
    self.obstacles = obstacles
  }

  /// How far from their place a companion looks for cover: about 1.5 m in Close and Column,
  /// and 2.5 m in Spread (ADR 0003).
  static func reach(in formation: GameSession.Formation) -> Float {
    formation == .spread ? 2.5 : 1.5
  }

  /// Whether the companion holds a spot of cover, rather than keeping to their place.
  func isTakingCover(_ member: PartyMember) -> Bool {
    covers[member]?.spot != nil
  }

  /// Where each companion with a place goes in this step: their spot, its firing position, or
  /// their place. With no shooter standing, everyone keeps to their place.
  mutating func targets(for input: Input, grid: NavigationGrid) -> [PartyMember: SIMD2<Float>] {
    guard !input.threats.isEmpty else {
      covers = [:]
      return input.places
    }
    covers = covers.filter { input.places[$0.key] != nil }
    var result: [PartyMember: SIMD2<Float>] = [:]
    for member in PartyMember.allCases {
      guard let place = input.places[member] else { continue }
      let weaponRange = input.weaponRanges[member] ?? 0
      var cover: Cover
      if var kept = covers[member], kept.kept + input.dt < Self.commitTime {
        kept.kept += input.dt
        cover = kept
      } else {
        let teammates =
          [input.leaderPosition] + input.positions.filter { $0.key != member }.map(\.value)
        cover = Scoring(
          member: member, place: place, position: input.positions[member] ?? place,
          threats: input.threats, weaponRange: weaponRange,
          taken: taken(by: member, input: input), teammates: teammates, obstacles: obstacles,
          grid: grid
        ).choose(within: Self.reach(in: input.formation), keeping: covers[member])
      }
      covers[member] = cover
      guard let spot = cover.spot else {
        result[member] = place
        continue
      }
      let aimedAt = input.threats.contains { $0.aimingAt == member }
      if !aimedAt, let firing = cover.firing,
        Self.canShoot(
          from: firing, threats: input.threats, weaponRange: weaponRange, obstacles: obstacles)
      {
        result[member] = firing
      } else {
        result[member] = spot
      }
    }
    return result
  }

  /// Everyone gives up their cover, as when the fight ends or the leader changes.
  mutating func reset() {
    covers = [:]
  }

  /// Where a companion's spot must stay clear of: the leader, and each other companion's spot
  /// and firing position, or their place while they keep to it.
  private func taken(by member: PartyMember, input: Input) -> [SIMD2<Float>] {
    var points = [input.leaderPosition]
    for (other, cover) in covers where other != member {
      if let spot = cover.spot {
        points.append(spot)
        if let firing = cover.firing { points.append(firing) }
      } else if let place = input.places[other] {
        points.append(place)
      }
    }
    return points
  }

  /// Whether a companion at `point` can shoot at a target within their weapon's reach.
  private static func canShoot(
    from point: SIMD2<Float>, threats: [Threat], weaponRange: Float, obstacles: [PartyMotion.Box]
  ) -> Bool {
    target(from: point, threats: threats, weaponRange: weaponRange, obstacles: obstacles) != nil
  }

  /// Where the shooter stands that a companion at `point` would fire at, chosen as the stage
  /// chooses a companion's target: the nearest that is a target, within their weapon's reach
  /// and in clear sight; nil when there is none.
  static func target(
    from point: SIMD2<Float>, threats: [Threat], weaponRange: Float, obstacles: [PartyMotion.Box]
  ) -> SIMD2<Float>? {
    var nearest: (distance: Float, position: SIMD2<Float>)?
    for threat in threats where threat.isTarget {
      let distance = simd_distance(point, threat.position)
      guard distance <= weaponRange, nearest.map({ distance < $0.distance }) ?? true,
        LineOfSight.isClear(from: threat.position, to: point, obstacles: obstacles)
      else { continue }
      nearest = (distance, threat.position)
    }
    return nearest?.position
  }

  /// Each member's own preference in a fight (ADR 0003), which only weighs the choice:
  /// - Miki likes 6–10 m between her firing position and `target`, the shooter she would fire
  ///   at from there (see `target(from:threats:weaponRange:obstacles:)`);
  /// - Laura likes to stand, or step out to fire, off the most dangerous threat's facing;
  /// - Tom likes to stand between a close threat and the teammate nearest it.
  static func personality(
    of member: PartyMember, at spot: SIMD2<Float>, firing: SIMD2<Float>?, target: SIMD2<Float>?,
    threats: [Threat], danger: Int?, teammates: [SIMD2<Float>]
  ) -> Float {
    switch member {
    case .miki:
      guard let firing, let target else { return 0 }
      let range = simd_distance(firing, target)
      let outside = max(0, mikisRange.lowerBound - range, range - mikisRange.upperBound)
      return outside * perMetreOutsideMikisRange
    case .laura:
      guard let danger, let facing = threats[danger].facing else { return 0 }
      let offset = (firing ?? spot) - threats[danger].position
      guard simd_length(offset) > 0.001 else { return inFrontForLaura }
      return max(0, simd_dot(simd_normalize(offset), facing)) * inFrontForLaura
    case .tom:
      guard
        let threat = threats.map(\.position).filter({
          simd_distance($0, spot) <= closeThreatForTom
        }).min(by: { simd_distance($0, spot) < simd_distance($1, spot) }),
        let teammate = teammates.min(by: {
          simd_distance($0, threat) < simd_distance($1, threat)
        })
      else { return 0 }
      return min(3, distance(from: spot, toSegment: teammate, threat)) * perMetreOffTomsLine
    }
  }

  /// How far `point` lies from the segment from `start` to `end`.
  private static func distance(
    from point: SIMD2<Float>, toSegment start: SIMD2<Float>, _ end: SIMD2<Float>
  ) -> Float {
    let along = end - start
    let lengthSquared = simd_length_squared(along)
    guard lengthSquared > 0.000001 else { return simd_distance(point, start) }
    let share = max(0, min(1, simd_dot(point - start, along) / lengthSquared))
    return simd_distance(point, start + along * share)
  }

  /// Weighs one companion's choices.
  private struct Scoring {
    let member: PartyMember
    let place: SIMD2<Float>
    let position: SIMD2<Float>
    let threats: [Threat]
    let weaponRange: Float
    let taken: [SIMD2<Float>]
    /// The leader and the other companion, for Tom's preference.
    let teammates: [SIMD2<Float>]
    let obstacles: [PartyMotion.Box]
    let grid: NavigationGrid
    /// What the shooters see.
    let ground: OpenGround
    /// The most dangerous shooter: whoever aims at the companion, or else the nearest.
    let danger: Int?
    /// Where the companion can walk: the area they stand in, or else their place's.
    let region: Int32?

    init(
      member: PartyMember, place: SIMD2<Float>, position: SIMD2<Float>, threats: [Threat],
      weaponRange: Float, taken: [SIMD2<Float>], teammates: [SIMD2<Float>],
      obstacles: [PartyMotion.Box], grid: NavigationGrid
    ) {
      self.member = member
      self.place = place
      self.position = position
      self.threats = threats
      self.weaponRange = weaponRange
      self.taken = taken
      self.teammates = teammates
      self.obstacles = obstacles
      self.grid = grid
      ground = OpenGround(threats: threats, obstacles: obstacles)
      danger =
        threats.firstIndex { $0.aimingAt == member }
        ?? threats.indices.min {
          simd_distance_squared(threats[$0].position, position)
            < simd_distance_squared(threats[$1].position, position)
        }
      region = grid.region(at: position) ?? grid.region(at: place)
    }

    /// The cheapest choice: keeping to the place, which wins a tie, or a spot within `reach` of
    /// it. The choice kept stays, a spot only while it is within reach, unless another costs at
    /// least `switchSaving` less.
    func choose(within reach: Float, keeping kept: Cover?) -> Cover {
      // Keeping to the place: no stepping out, since the place moves.
      let placeCost =
        baseCost(of: place) + extraCost(at: place, firing: canShoot(from: place) ? place : nil)
      var best = (cost: placeCost, cover: Cover(spot: nil, firing: nil))
      // Spots in order of their cost before a firing position, the costliest part to find, and
      // the member's preference, which depends on it: once that alone reaches the best so far,
      // no later spot can win.
      let spots = grid.roomySpots(within: reach, of: place, stride: CoverPlanner.stride)
        .filter(isOpen).map { (spot: $0, cost: baseCost(of: $0)) }.sorted { $0.cost < $1.cost }
      for (spot, base) in spots {
        guard base < best.cost else { break }
        let firing = firingPosition(near: spot)
        let cost = base + extraCost(at: spot, firing: firing)
        if cost < best.cost { best = (cost, Cover(spot: spot, firing: firing)) }
      }
      guard let kept else { return best.cover }
      guard let spot = kept.spot else {
        return placeCost <= best.cost + CoverPlanner.switchSaving
          ? Cover(spot: nil, firing: nil) : best.cover
      }
      guard simd_distance(spot, place) <= reach, isOpen(spot) else { return best.cover }
      let firing = firingPosition(near: spot)
      let cost = baseCost(of: spot) + extraCost(at: spot, firing: firing)
      return cost <= best.cost + CoverPlanner.switchSaving
        ? Cover(spot: spot, firing: firing) : best.cover
    }

    /// Whether the companion may stand at `spot`: somewhere to settle, in the area they can
    /// walk, and clear of the leader and the other companion.
    private func isOpen(_ spot: SIMD2<Float>) -> Bool {
      grid.isRoomy(spot) && (region == nil || grid.region(at: spot) == region)
        && taken.allSatisfy { simd_distance($0, spot) >= CoverPlanner.spacing }
    }

    /// What a firing position, or the lack of one, and the member's own preference add to a
    /// spot's cost.
    private func extraCost(at spot: SIMD2<Float>, firing: SIMD2<Float>?) -> Float {
      // Only Miki's preference depends on whom she would fire at.
      let target =
        member == .miki
        ? firing.flatMap {
          CoverPlanner.target(
            from: $0, threats: threats, weaponRange: weaponRange, obstacles: obstacles)
        } : nil
      return (firing == nil ? CoverPlanner.noFiringPosition : 0)
        + CoverPlanner.personality(
          of: member, at: spot, firing: firing, target: target, threats: threats, danger: danger,
          teammates: teammates)
    }

    /// What standing at `spot` costs, before any firing position: in the shooters' sight, away
    /// from the place, and on the way there.
    private func baseCost(of spot: SIMD2<Float>) -> Float {
      var cost =
        simd_distance(spot, place) * CoverPlanner.perMetreFromPlace
        + simd_distance(position, spot) * CoverPlanner.perMetreWalked
      for (index, threat) in threats.enumerated() where !isHidden(spot, from: threat) {
        cost += index == danger ? CoverPlanner.seenByDanger : CoverPlanner.seenByOther
      }
      for share in CoverPlanner.crossings where isSeen(position + (spot - position) * share) {
        cost += CoverPlanner.perOpenCrossing
      }
      return cost
    }

    /// The nearest point to `spot`, within `peekReach`, from which the companion can shoot,
    /// even where they stop on the way to it; nil when there is none.
    private func firingPosition(near spot: SIMD2<Float>) -> SIMD2<Float>? {
      guard weaponRange > 0 else { return nil }
      if canShoot(arrivingAt: spot, from: position) { return spot }
      return grid.roomySpots(within: CoverPlanner.peekReach, of: spot, stride: CoverPlanner.stride)
        .sorted { simd_distance_squared($0, spot) < simd_distance_squared($1, spot) }
        .first { isOpen($0) && canShoot(arrivingAt: $0, from: spot) }
    }

    /// Whether the companion can shoot from `point`, and from where the motor may settle on the
    /// way there from `origin`: up to `CompanionMotor.settleDistance` short of it. A point that
    /// only just clears a wall's end would leave them settled behind the wall, unable to fire.
    private func canShoot(arrivingAt point: SIMD2<Float>, from origin: SIMD2<Float>) -> Bool {
      let offset = point - origin
      let distance = simd_length(offset)
      let short =
        distance > CompanionMotor.settleDistance
        ? point - offset / distance * CompanionMotor.settleDistance : origin
      return canShoot(from: point) && canShoot(from: short)
    }

    private func canShoot(from point: SIMD2<Float>) -> Bool {
      CoverPlanner.canShoot(
        from: point, threats: threats, weaponRange: weaponRange, obstacles: obstacles)
    }

    /// Whether a body at `spot` is beyond the shooter's reach, or hidden from it: the sight
    /// lines to the spot and to either side of it, `margin` away, are all blocked.
    private func isHidden(_ spot: SIMD2<Float>, from threat: Threat) -> Bool {
      let offset = spot - threat.position
      let distance = simd_length(offset)
      guard distance <= threat.range else { return true }
      guard distance > 0.001 else { return false }
      let side = SIMD2(-offset.y, offset.x) / distance * CoverPlanner.margin
      return !sees(threat.position, spot) && !sees(threat.position, spot + side)
        && !sees(threat.position, spot - side)
    }

    /// Whether any shooter can see and reach `point`.
    private func isSeen(_ point: SIMD2<Float>) -> Bool {
      ground.isSeen(point)
    }

    private func sees(_ from: SIMD2<Float>, _ to: SIMD2<Float>) -> Bool {
      LineOfSight.isClear(from: from, to: to, obstacles: obstacles)
    }
  }
}
