import simd

/// The ground the standing shooters can see, for moving in a fight: ADR 0003's sight-aware
/// routes, from phase S4, tried in the combat yard. A route pays more for each cell a shooter
/// sees, and a companion takes no long straight way across seen ground while the grid offers
/// another. Sight is the same as for shots, a straight line against the blockers' footprints;
/// The Quiet Yard's proposal that low barriers block only movement is not used.
struct OpenGround {
  /// How much more crossing a cell in a shooter's sight costs: four times as much in all.
  static let extraCost: Float = 3
  /// A step no longer than this never counts as crossing open ground, such as out of cover to
  /// fire and back.
  static let shortStep: Float = 1.5
  /// How far apart the way is sampled, and how far from either end the samples start.
  static let sampleSpacing: Float = 0.5

  let threats: [CoverPlanner.Threat]
  let obstacles: [PartyMotion.Box]
  /// What earlier routes found the shooters see, for the cells they reached.
  var memo: SightMemo?

  /// Whether a standing shooter can see and reach `point`.
  func isSeen(_ point: SIMD2<Float>) -> Bool {
    threats.contains {
      simd_distance($0.position, point) <= $0.range
        && LineOfSight.isClear(from: $0.position, to: point, obstacles: obstacles)
    }
  }

  /// What crossing a navigation cell at `point`, its centre, costs per metre beyond its length.
  func extraCost(at point: SIMD2<Float>) -> Float {
    let seen = memo?.isSeen(point) { isSeen(point) } ?? isSeen(point)
    return seen ? Self.extraCost : 0
  }

  /// Whether the straight way from `start` to `end` crosses seen ground away from both ends.
  /// A short step never does.
  func crosses(from start: SIMD2<Float>, to end: SIMD2<Float>) -> Bool {
    let length = simd_distance(start, end)
    guard length > Self.shortStep else { return false }
    var along = Self.sampleSpacing
    while along < length - Self.sampleSpacing {
      if isSeen(start + (end - start) * (along / length)) { return true }
      along += Self.sampleSpacing
    }
    return false
  }
}

/// What the standing shooters see from where they stand, remembered for each cell centre that
/// a route reached, until a shooter moves, falls or is out of the fight. Routes in a fight are
/// planned again and again, and each would otherwise work out sight for thousands of cells.
final class SightMemo {
  private var shooters: [SIMD3<Float>] = []
  private var seen: [SIMD2<Float>: Bool] = [:]

  /// Forget what was seen if the shooters are not where, or as many as, they were.
  func prepare(for threats: [CoverPlanner.Threat]) {
    let current = threats.map { SIMD3($0.position, $0.range) }
    guard current != shooters else { return }
    shooters = current
    seen = [:]
  }

  /// Whether `point` is seen, as worked out by `look` the first time it is asked.
  func isSeen(_ point: SIMD2<Float>, look: () -> Bool) -> Bool {
    if let known = seen[point] { return known }
    let found = look()
    seen[point] = found
    return found
  }
}
