import simd

/// The stranger's rifle handling. Its authored wind-up permits one discharge; finite barrel
/// tracking and seeded spread decide the direction, and the fight traces what it actually hits.
struct HostileHandling: Sendable {
  struct Discharge: Equatable, Sendable {
    let direction: SIMD2<Float>
    /// The opening's warning cannot damage anyone, even if another member crosses the ray.
    let deliberateMiss: Bool
  }

  static let turnRate: Float = 1.5 * .pi
  private var yaw: Float
  private var scatter = Scatter()
  private var pending = false
  private var deliberateMiss = false
  private var turning: Float = 0
  private var targetDistance: Float = 1
  private(set) var pose = WeaponPose(kind: .rifle)

  init(facing: SIMD2<Float>) {
    yaw = Self.isDirection(facing) ? Movement.yaw(towards: facing) : 0
  }

  var facing: SIMD2<Float> { Movement.facing(yaw: yaw) }

  mutating func advance(dt: Float, toward direction: SIMD2<Float>, aiming: Bool) {
    guard dt.isFinite, dt > 0 else { return }
    scatter.settle(dt: dt, spread: Weapon.rifle.spread)
    turning = 0
    if Self.isDirection(direction) {
      targetDistance = simd_length(direction)
      let before = yaw
      yaw = Movement.turn(
        from: yaw, towards: Movement.yaw(towards: direction), limit: Self.turnRate * dt)
      turning = min(1, abs(yaw - before) / (Self.turnRate * dt))
    }
    pose.step(dt: dt, aiming: aiming)
  }

  /// The encounter supplies one permission. It cannot queue or duplicate an unread shot.
  mutating func begin(deliberateMiss: Bool = false) {
    guard !pending else { return }
    pending = true
    self.deliberateMiss = deliberateMiss
  }

  mutating func takeShot(using generator: inout some RandomNumberGenerator) -> Discharge? {
    guard pending else { return nil }
    let angle: Float
    if deliberateMiss {
      angle = max(Spread.degrees(7), atan2(Aim.bodyRadius + 0.6, targetDistance))
    } else {
      let cone = scatter.angle(spread: Weapon.rifle.spread, speed: 0, turning: turning)
      angle = Scatter.deviation(within: cone, using: &generator)
    }
    let direction = facing
    let result = Discharge(
      direction: [
        direction.x * cos(angle) - direction.y * sin(angle),
        direction.x * sin(angle) + direction.y * cos(angle),
      ], deliberateMiss: deliberateMiss)
    pending = false
    scatter.fired(spread: Weapon.rifle.spread)
    pose.fired()
    return result
  }

  mutating func cancel() {
    pending = false
    deliberateMiss = false
  }

  private static func isDirection(_ value: SIMD2<Float>) -> Bool {
    value.x.isFinite && value.y.isFinite && simd_length_squared(value) > 0.000001
  }
}
