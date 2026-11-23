import simd

/// An analytic spring/damper for three independent channels. Frequency is in hertz; damping
/// is the damping ratio. Initial response controls the target-velocity force: zero follows
/// without anticipation, positive values respond sooner and negative values initially resist.
/// For a linear target segment we solve y'' + 2ζω y' + ω²y = ω²x + rζω x' exactly.
struct RobotDynamics {
  let frequency: Float
  let damping: Float
  let initialResponse: Float
  private(set) var value: SIMD3<Float>
  private(set) var velocity = SIMD3<Float>.zero
  private var previousTarget: SIMD3<Float>

  init(
    frequency: Float, damping: Float, initialResponse: Float = 0,
    value: SIMD3<Float> = .zero
  ) {
    precondition(frequency.isFinite && frequency > 0)
    precondition(damping.isFinite && damping >= 0)
    precondition(initialResponse.isFinite)
    self.frequency = frequency
    self.damping = damping
    self.initialResponse = initialResponse
    self.value = value
    previousTarget = value
  }

  mutating func reset(to value: SIMD3<Float> = .zero) {
    self.value = value
    velocity = .zero
    previousTarget = value
  }

  mutating func impulse(_ change: SIMD3<Float>) {
    guard Self.finite(change) else { return }
    velocity += change
  }

  @discardableResult
  mutating func advance(to target: SIMD3<Float>, dt: Float) -> SIMD3<Float> {
    guard dt.isFinite, dt > 0, Self.finite(target) else { return value }
    let elapsed = min(dt, 1 / 15)
    let omega = 2 * Float.pi * frequency
    let rate = (target - previousTarget) / elapsed
    let lag = (initialResponse - 2) * damping / omega
    let displacement = value - previousTarget - lag * rate
    let derivative = velocity - rate
    let decay = damping * omega
    let next: SIMD3<Float>
    let speed: SIMD3<Float>
    if abs(damping - 1) < 0.0001 {
      let exponential = exp(-omega * elapsed)
      let coefficient = derivative + omega * displacement
      next = exponential * (displacement + coefficient * elapsed)
      speed = exponential * (derivative - omega * coefficient * elapsed)
    } else if damping < 1 {
      let oscillation = omega * sqrt(1 - damping * damping)
      let exponential = exp(-decay * elapsed)
      let cosine = cos(oscillation * elapsed)
      let sine = sin(oscillation * elapsed) / oscillation
      next = exponential * (displacement * cosine + (derivative + decay * displacement) * sine)
      speed =
        exponential
        * (derivative * cosine - (decay * derivative + omega * omega * displacement) * sine)
    } else {
      let root = sqrt(damping * damping - 1)
      let slow = -omega / (damping + root)
      let fast = -omega * (damping + root)
      let first = (derivative - fast * displacement) / (slow - fast)
      let second = displacement - first
      let a = first * exp(slow * elapsed)
      let b = second * exp(fast * elapsed)
      next = a + b
      speed = slow * a + fast * b
    }
    value = target + lag * rate + next
    velocity = rate + speed
    previousTarget = target
    return value
  }

  private static func finite(_ value: SIMD3<Float>) -> Bool {
    value.x.isFinite && value.y.isFinite && value.z.isFinite
  }
}
