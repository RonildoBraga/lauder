import simd

/// A rifle hostile's handling, separate from its encounter and tactical decisions. A wind-up
/// starts a short sequence; each discharge follows the finite-turn barrel with seeded spread.
/// The fight traces the resulting ray and decides what it actually meets.
struct HostileHandling: Sendable {
  struct Discharge: Equatable, Sendable {
    let direction: SIMD2<Float>
    /// The opening's authored warning must never damage a member, even if another crosses it.
    let deliberateMiss: Bool
  }

  /// Slower than the leader's turn: moving across the barrel can outrun its tracking.
  static let turnRate: Float = 1.5 * .pi
  /// Tunable prototype spread. Standing still helps; turning, moving and sustained fire widen it.
  static let spread = Spread(
    rest: Spread.degrees(2.5), perShot: Spread.degrees(1), widest: Spread.degrees(8),
    recovery: Spread.degrees(3), moving: Spread.degrees(2), turning: Spread.degrees(4))

  private let burst: Int
  private let burstGap: Float
  private var yaw: Float
  private var scatter = Scatter()
  private var remaining = 0
  private var cooldown: Float = 0
  private var deliberateMiss = false
  private var moving = false
  private var turning: Float = 0
  private var targetDistance: Float = 1
  private(set) var pose = WeaponPose(kind: .rifle)

  init(facing: SIMD2<Float>, burst: Int = 1, burstGap: Float = 0.16) {
    precondition(burst > 0 && burstGap.isFinite && burstGap > 0)
    self.burst = burst
    self.burstGap = burstGap
    yaw = Self.isDirection(facing) ? Movement.yaw(towards: facing) : 0
  }

  var facing: SIMD2<Float> { Movement.facing(yaw: yaw) }
  var isBursting: Bool { remaining > 0 }

  /// Advance once per exploring fixed step. `direction` is the full offset to the chosen
  /// target, so the deliberate opening miss can clear them even at close range. Running
  /// pauses the burst's gap and lowers the rifle; the caller also withholds `takeShot` then.
  mutating func advance(
    dt: Float, toward direction: SIMD2<Float>, aiming: Bool, moving: Bool = false
  ) {
    guard dt.isFinite, dt > 0 else { return }
    self.moving = moving
    if !moving { cooldown = max(0, cooldown - dt) }
    scatter.settle(dt: dt, spread: Self.spread)
    turning = 0
    if Self.isDirection(direction) {
      targetDistance = simd_length(direction)
      let before = yaw
      yaw = Movement.turn(
        from: yaw, towards: Movement.yaw(towards: direction), limit: Self.turnRate * dt)
      turning = min(1, abs(yaw - before) / (Self.turnRate * dt))
    }
    pose.step(dt: dt, aiming: !moving && (aiming || isBursting))
  }

  /// The encounter's timer supplies one permission, not a guaranteed hit. A new permission
  /// cannot overwrite a burst already in progress, and the authored first miss stays single.
  mutating func begin(deliberateMiss: Bool = false) {
    guard !isBursting else { return }
    remaining = deliberateMiss ? 1 : burst
    cooldown = 0
    self.deliberateMiss = deliberateMiss
  }

  /// Consume at most one ready discharge. Repeated queries in a step cannot bypass the gap,
  /// and the caller's generator makes identical inputs and seeds replay the same rays.
  mutating func takeShot(using generator: inout some RandomNumberGenerator) -> Discharge? {
    guard isBursting, cooldown <= 0, !moving else { return nil }
    let angle: Float
    if deliberateMiss {
      angle = max(Spread.degrees(7), atan2(Aim.bodyRadius + 0.6, targetDistance))
    } else {
      let cone = scatter.angle(
        spread: Self.spread, speed: moving ? 1 : 0, turning: turning)
      angle = Scatter.deviation(within: cone, using: &generator)
    }
    let direction = facing
    let result = Discharge(
      direction: [
        direction.x * cos(angle) - direction.y * sin(angle),
        direction.x * sin(angle) + direction.y * cos(angle),
      ], deliberateMiss: deliberateMiss)
    remaining -= 1
    cooldown = remaining > 0 ? burstGap : 0
    scatter.fired(spread: Self.spread)
    pose.fired()
    return result
  }

  /// Disruption, defeat or breaking contact cannot leave delayed rounds waiting to replay.
  /// The pose and spread settle naturally rather than snapping as the pending shots disappear.
  mutating func cancel() {
    remaining = 0
    cooldown = 0
    deliberateMiss = false
  }

  private static func isDirection(_ value: SIMD2<Float>) -> Bool {
    value.x.isFinite && value.y.isFinite && simd_length_squared(value) > 0.000001
  }
}
