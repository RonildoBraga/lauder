import simd

/// Bounded tactical movement in the combat yard. Plans are deterministic and infrequent;
/// the existing navigation grid proposes routes and PartyMotion resolves every small step.
/// The fight still owns engagement, firing, exposure, damage and the actors' actual positions.
struct EnemyTactics {
  static let speed: Float = 1.7
  static let homeReach: Float = 6
  static let coverReach: Float = 3
  static let coverInterval: Float = 2
  static let flankInterval: Float = 3
  static let arrival: Float = 0.08
  static let spacing: Float = 0.7
  static let blockedRetry: Float = 0.75
  static let travelLimit: Float = 10

  struct Step {
    /// Legal positions for this step, applied through HostileState.reposition(to:).
    var positions: [String: SIMD2<Float>] = [:]
    /// Actors that actually moved this step hold their weapon timers instead of shooting.
    var moving: Set<String> = []
  }

  private struct Plan {
    let goal: SIMD2<Float>
    var route: [SIMD2<Float>]
    var remaining: Float
    var travelling: Float = 0
    var blocked: Float = 0
  }

  private let grid: NavigationGrid?
  private let motion: PartyMotion
  private let ground: PartyMotion.Box
  private let cover: LeaderCover
  private let shotBlockers: [PartyMotion.Box]
  private var plans: [String: Plan] = [:]

  /// The world can supply its grid. A separate grid is made only for a level that actually
  /// contains tactical shooters, so the long bridge pays no new navigation setup cost.
  init(level: Level, grid: NavigationGrid? = nil) {
    let tactical = level.encounters.flatMap(\.hostiles).contains {
      $0.attack == .shoot && $0.behavior != .stationary
    }
    self.grid = tactical ? (grid ?? NavigationGrid(level: level)) : nil
    motion = PartyMotion(radius: PartyBody.radius, obstacles: level.obstacles)
    ground = level.bounds
    cover = LeaderCover(boxes: level.boxes, ground: level.bounds)
    shotBlockers = Aim.blockers(level.boxes, above: LeaderCover.lowHeight)
  }

  /// The committed destinations, useful for the Simulator's diagnostics and focused tests.
  var goals: [String: SIMD2<Float>] { plans.mapValues(\.goal) }

  mutating func reset() { plans = [:] }

  mutating func step(
    hostiles: [String: HostileState], party: [PartyMember: SIMD2<Float>], dt: Float
  ) -> Step {
    guard dt.isFinite, dt > 0, let grid else { return Step() }
    let targets = party.sorted { $0.key.rawValue < $1.key.rawValue }.map(\.value).filter(finite)
    guard !targets.isEmpty else {
      reset()
      return Step()
    }
    let actors = hostiles.filter { id, state in
      guard state.spec.attack == .shoot, state.spec.behavior != .stationary,
        state.isTargetable, !state.isDown
      else { return false }
      // Reaction must reach its first aim before movement can hold weapon timing. Waiting
      // after a fallback is not an engagement even though the actor remains targetable.
      switch state.phase {
      case .aiming: return true
      case .recovering: return plans[id] != nil
      default: return false
      }
    }
    plans = plans.filter { actors[$0.key] != nil }
    var result = Step()
    for id in actors.keys.sorted() {
      guard let actor = actors[id], let target = nearest(to: actor.position, among: targets)
      else { continue }
      var plan = plans[id]
      if let old = plan {
        if !old.route.isEmpty && simd_distance(old.goal, actor.position) > Self.arrival {
          // Finish the committed trip before choosing another angle. Its firing interval
          // starts on arrival, so a long route cannot keep the weapon paused forever.
          plan?.travelling += dt
          if old.blocked >= Self.blockedRetry || old.travelling >= Self.travelLimit { plan = nil }
        } else {
          plan?.remaining = old.remaining - dt
        }
      }
      if plan == nil || plan!.remaining <= 0 {
        let taken =
          hostiles.compactMap { other, state in
            other != id && state.isVisible && !state.isDown ? state.position : nil
          } + plans.compactMap { other, plan in other != id ? plan.goal : nil }
        let goal = destination(for: actor, target: target, party: targets, taken: taken, grid: grid)
        let route = route(from: actor.position, to: goal, home: actor.spec.standAt, grid: grid)
        plan = Plan(
          goal: goal, route: route,
          remaining: actor.spec.behavior == .flank ? Self.flankInterval : Self.coverInterval)
      }
      guard var current = plan else { continue }
      var moved = false
      while let next = current.route.first,
        simd_distance(next, actor.position) <= Self.arrival
          || (current.route.count > 1
            && motion.canTraverse(from: actor.position, to: current.route[1]))
      {
        current.route.removeFirst()
      }
      if let next = current.route.first {
        let offset = next - actor.position
        let distance = simd_length(offset)
        if distance > Self.arrival {
          let proposed = motion.resolve(
            start: actor.position, delta: offset / distance * min(Self.speed * dt, distance))
          // A route is advisory. Reject a step that clips the floor, leaves the home area or
          // crowds another actor; a later scheduled plan may choose a different route.
          let occupied = hostiles.contains { other, state in
            other != id && state.isVisible && !state.isDown
              && simd_distance(proposed, result.positions[other] ?? state.position) < Self.spacing
          }
          if fits(proposed), simd_distance(proposed, actor.spec.standAt) <= Self.homeReach,
            !occupied, targets.allSatisfy({ simd_distance($0, proposed) >= Self.spacing })
          {
            result.positions[id] = proposed
            if simd_distance_squared(proposed, actor.position) > 0.0000001 {
              result.moving.insert(id)
              moved = true
            }
          }
        }
      }
      current.blocked = moved || current.route.isEmpty ? 0 : current.blocked + dt
      plans[id] = current
    }
    return result
  }

  private func destination(
    for actor: HostileState, target: SIMD2<Float>, party: [SIMD2<Float>],
    taken: [SIMD2<Float>], grid: NavigationGrid
  ) -> SIMD2<Float> {
    let home = actor.spec.standAt
    let centre = actor.spec.behavior == .flank ? home : actor.position
    let reach = actor.spec.behavior == .flank ? Self.homeReach : Self.coverReach
    let region = grid.region(at: actor.position)
    let candidates = grid.roomySpots(within: reach, of: centre, stride: 3).filter {
      fits($0) && simd_distance($0, home) <= Self.homeReach
        && (region == nil || grid.region(at: $0) == region)
    }
    var best: (cost: Float, point: SIMD2<Float>)?
    for point in candidates {
      guard taken.allSatisfy({ simd_distance($0, point) >= Self.spacing }),
        party.allSatisfy({ simd_distance($0, point) >= 2 }),
        simd_distance(point, target) <= actor.spec.range
      else { continue }
      let cost: Float
      if actor.spec.behavior == .takeCover {
        guard let shelter = cover.shelter(at: point, facing: target - point),
          let firing = cover.firingPoint(from: point, in: shelter, facing: target - point),
          !LineOfSight.isClear(
            from: target, to: point, obstacles: cover.incomingBlockers(in: shelter, exposed: false)),
          LineOfSight.isClear(from: firing, to: target, obstacles: shotBlockers)
        else { continue }
        let visible = party.filter {
          LineOfSight.isClear(
            from: $0, to: point, obstacles: cover.incomingBlockers(in: shelter, exposed: false))
        }.count
        cost = Float(visible) * 8 + simd_distance(point, actor.position)
      } else {
        guard LineOfSight.isClear(from: point, to: target, obstacles: shotBlockers) else {
          continue
        }
        let fromHome = home - target
        let fromPoint = point - target
        let first = simd_length(fromHome) > 0.001 ? simd_normalize(fromHome) : SIMD2<Float>(0, -1)
        let second = simd_normalize(fromPoint)
        let angle = abs(first.x * second.y - first.y * second.x)
        cost = -angle * 8 + simd_distance(point, actor.position) * 0.25
      }
      if best == nil || cost < best!.cost - 0.00001 { best = (cost, point) }
    }
    return best?.point ?? actor.position
  }

  private func route(
    from point: SIMD2<Float>, to goal: SIMD2<Float>, home: SIMD2<Float>, grid: NavigationGrid
  ) -> [SIMD2<Float>] {
    guard simd_distance(point, goal) > Self.arrival else { return [] }
    if motion.canTraverse(from: point, to: goal) { return [goal] }
    guard
      let cells = grid.route(
        from: point, to: goal,
        extraCost: { simd_distance($0, home) <= Self.homeReach && fits($0) ? 0 : .infinity })
    else { return [] }
    var points = [point] + cells
    if let last = points.last, motion.canTraverse(from: last, to: goal) { points.append(goal) }
    return NavigationGrid.straightened(points) { motion.canTraverse(from: $0, to: $1) }
  }

  private func nearest(to point: SIMD2<Float>, among targets: [SIMD2<Float>]) -> SIMD2<Float>? {
    targets.min { simd_distance_squared($0, point) < simd_distance_squared($1, point) }
  }

  private func fits(_ point: SIMD2<Float>) -> Bool {
    let radius = PartyBody.radius + PartyMotion.skin
    return finite(point) && point.x - radius >= ground.minimum.x
      && point.x + radius <= ground.maximum.x && point.y - radius >= ground.minimum.y
      && point.y + radius <= ground.maximum.y
      && motion.canTraverse(from: point, to: point)
  }

  private func finite(_ point: SIMD2<Float>) -> Bool { point.x.isFinite && point.y.isFinite }
}
