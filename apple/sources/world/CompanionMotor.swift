import simd

/// Steers one companion towards their target (ADR 0003, phase S1). It proposes a movement for
/// each fixed step; PartyMotion resolves it, and `absorb` reports what actually happened.
struct CompanionMotor {
  static let settleDistance: Float = 0.25
  static let reengageDistance: Float = 0.6
  static let catchUpFactor: Float = 1.25
  static let gain: Float = 2.5
  static let acceleration: Float = 12
  static let personalSpace: Float = 0.75
  static let avoidRadius: Float = 0.8
  static let avoidHorizon: Float = 0.6
  static let replanInterval: Float = 0.25
  static let replanDrift: Float = 0.5
  static let waypointReach: Float = 0.3
  static let stallLimit: Float = 1
  static let retryInterval: Float = 1

  private(set) var isSettled = false
  /// Set from the first give-up until the companion has moved freely again for a second;
  /// the HUD names the companion meanwhile.
  private(set) var cannotReach = false
  /// Delay before moving off from a settled stop; a little personality (ADR 0003).
  private let reactionDelay: Float
  private var velocity: SIMD2<Float> = .zero
  /// Gave up after repeated failed routes and waits before trying again.
  private var isHolding = false
  private var wait: Float = 0
  private var route: [SIMD2<Float>] = []
  private var routeGoal: SIMD2<Float>?
  private var sincePlan = Float.infinity
  private var intended: SIMD2<Float> = .zero
  private var stalled: Float = 0
  private var moving: Float = 0
  private var failures = 0
  private var sinceRetry: Float = 0

  /// A motor with the member's own reaction delay.
  init(for member: PartyMember) {
    reactionDelay =
      switch member {
      case .laura: 0.1
      case .miki: 0.15
      case .tom: 0.2
      }
  }

  struct Context {
    let target: SIMD2<Float>
    let leaderPosition: SIMD2<Float>
    let leaderVelocity: SIMD2<Float>
    let others: [SIMD2<Float>]
    let speed: Float
    let dt: Float
    /// How the target moves: with the leader for a formation place, not at all for a point an
    /// order marked (ADR 0003, phase S3).
    let targetMoves: Bool
  }

  /// The movement this companion asks for in this step.
  mutating func step(
    from position: SIMD2<Float>, context: Context, grid: NavigationGrid,
    isClear: (SIMD2<Float>, SIMD2<Float>) -> Bool
  ) -> SIMD2<Float> {
    let dt = context.dt
    let toTarget = context.target - position
    let distance = simd_length(toTarget)
    // A formation place moves with the leader; a marked point stays where it is.
    let targetVelocity = context.targetMoves ? context.leaderVelocity : .zero
    let targetSpeed = simd_length(targetVelocity)
    let crowded = context.others.contains { simd_distance($0, position) < 0.5 }
    sincePlan += dt
    intended = .zero

    if isHolding {
      sinceRetry += dt
      guard sinceRetry >= Self.retryInterval else { return .zero }
      // Try again; one more stall returns to holding.
      isHolding = false
      failures = 2
      route = []
      sincePlan = .infinity
    }
    let dodge = leaderAvoidance(position, context)
    if isSettled {
      guard distance > Self.reengageDistance || crowded || dodge != nil else { return .zero }
      isSettled = false
      // Getting out of the leader's way is immediate; ordinary moving off is not.
      wait = dodge == nil ? reactionDelay : 0
    }
    if wait > 0 && dodge == nil {
      wait -= dt
      return .zero
    }
    wait = 0
    // A static order must not settle us again while making way for the leader.
    if dodge == nil && targetSpeed < 0.1 && distance < Self.settleDistance
      && simd_length(velocity) < 0.3 && !crowded
    {
      isSettled = true
      velocity = .zero
      route = []
      routeGoal = nil
      return .zero
    }

    let cap =
      context.speed * (1 + (Self.catchUpFactor - 1) * min(1, max(0, (distance - 0.1) / 1.4)))
    var desired: SIMD2<Float>
    if isClear(position, context.target) {
      route = []
      routeGoal = nil
      // Match the target's movement and close the gap, so a companion keeps pace with a moving
      // slot instead of trailing it by a slowing-down distance.
      desired = targetVelocity + toTarget * Self.gain
    } else {
      let drifted = routeGoal.map { simd_distance($0, context.target) > Self.replanDrift } ?? true
      if (route.isEmpty || drifted) && sincePlan >= Self.replanInterval {
        plan(
          from: position, to: context.target, grid: grid, isClear: isClear)
      }
      while let next = route.first,
        simd_distance(next, position) < Self.waypointReach
          || (route.count > 1 && isClear(position, route[1]))
      {
        route.removeFirst()
      }
      let aim = route.first ?? context.target
      let offset = aim - position
      desired = simd_length(offset) > 0.0001 ? simd_normalize(offset) * cap : .zero
    }
    desired = Self.limited(desired, to: cap)

    // Personal space and making way for the leader; party bodies do not collide.
    for other in context.others {
      let away = position - other
      let gap = simd_length(away)
      if gap < Self.personalSpace && gap > 0.0001 {
        desired += away / gap * (1 - gap / Self.personalSpace) * 2.5
      }
    }
    if let dodge, simd_length(dodge) > 0.0001 {
      // While the leader is bearing down, never move towards their line of travel, even if
      // the companion's place is on the far side; cross only once the leader has passed.
      let away = simd_normalize(dodge)
      desired -= away * min(0, simd_dot(desired, away))
      desired += dodge
    }
    desired = Self.limited(desired, to: context.speed * Self.catchUpFactor)

    velocity += Self.limited(desired - velocity, to: Self.acceleration * dt)
    intended = velocity * dt
    return intended
  }

  /// Something is about to strike it, so it moves off at once rather than after its usual
  /// reaction delay, as it does to make way for the leader (a crawler's ram line, issue #208).
  mutating func hurry() {
    isSettled = false
    wait = 0
  }

  /// A new order: a settled companion moves off to its point however near it is, after their
  /// usual reaction, rather than waiting until it is `reengageDistance` away as a formation
  /// place must be (ADR 0003, phase S3).
  mutating func wake() {
    guard isSettled else { return }
    isSettled = false
    wait = reactionDelay
  }

  /// Record what PartyMotion allowed, so speed into a wall is not kept, and watch for stalls.
  mutating func absorb(_ actual: SIMD2<Float>, dt: Float) {
    guard dt > 0 else { return }
    velocity = actual / dt
    let wanted = simd_length(intended)
    guard wanted > 0.25 * dt else { return }
    if simd_length(actual) < 0.1 * wanted {
      stalled += dt
      moving = 0
    } else {
      stalled = max(0, stalled - dt)
      moving += dt
      if moving >= 1 {
        failures = 0
        cannotReach = false
      }
    }
    guard stalled >= Self.stallLimit else { return }
    stalled = 0
    route = []
    sincePlan = .infinity
    failures += 1
    if failures >= 3 {
      isHolding = true
      cannotReach = true
      sinceRetry = 0
      velocity = .zero
    }
  }

  private mutating func plan(
    from position: SIMD2<Float>, to target: SIMD2<Float>, grid: NavigationGrid,
    isClear: (SIMD2<Float>, SIMD2<Float>) -> Bool
  ) {
    sincePlan = 0
    routeGoal = target
    guard let cells = grid.route(from: position, to: target) else {
      route = []
      return
    }
    var points = cells
    if let last = points.last, isClear(last, target) { points.append(target) }
    route = NavigationGrid.straightened(points, isClear: isClear)
  }

  /// A sideways step when the leader will pass within `avoidRadius` in the next
  /// `avoidHorizon` seconds, judged from both current velocities; nil when they will not.
  private func leaderAvoidance(_ position: SIMD2<Float>, _ context: Context) -> SIMD2<Float>? {
    let leaderSpeed = simd_length(context.leaderVelocity)
    guard leaderSpeed > 0.3 else { return nil }
    let offset = position - context.leaderPosition
    let closing = velocity - context.leaderVelocity
    let rate = simd_length_squared(closing)
    let time = rate > 0.0001 ? min(Self.avoidHorizon, max(0, -simd_dot(offset, closing) / rate)) : 0
    let closest = offset + closing * time
    let gap = simd_length(closest)
    guard gap < Self.avoidRadius else { return nil }
    // Step away from the leader's line of travel, on the side the companion is already on.
    let direction = context.leaderVelocity / leaderSpeed
    let lateral = SIMD2(-direction.y, direction.x)
    let side: Float = simd_dot(offset, lateral) >= 0 ? 1 : -1
    // Keep the full side step while predicted bodies overlap; taper only once their full
    // diameter clears. Tapering from zero gap left too little speed to clear a static anchor.
    let urgency = min(1, (Self.avoidRadius - gap) / (Self.avoidRadius - 2 * PartyBody.radius))
    return lateral * side * 3 * urgency
  }

  private static func limited(_ vector: SIMD2<Float>, to maximum: Float) -> SIMD2<Float> {
    let length = simd_length(vector)
    return length > maximum && length > 0 ? vector / length * maximum : vector
  }
}
