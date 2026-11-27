/// The first guard's health and optional dismantling opportunities. The encounter resolves
/// actual contact; every damaging hit counts, while a matched exposed part rewards its weapon.
struct GuardStrategy: Equatable, Sendable {
  enum Part: CaseIterable, Sendable {
    case sensor, coupling, reactor
  }

  enum Phase: Equatable, Sendable {
    case sensor, coupling, reactor, complete
  }

  struct Hit: Equatable, Sendable {
    let amount: Int
    let effectiveness: DamageHit.Effectiveness
    let brokeComponent: Bool
    let defeated: Bool
  }

  static let windowDuration: Float = 4
  static let maximumHealth = 1500
  static let weakpointMultiplier = 3

  private(set) var health = Self.maximumHealth
  private(set) var sensorDisabled = false
  private(set) var couplingBreached = false
  /// Actual health lost to matched exposed-core contacts; this is not a defeat requirement.
  private(set) var reactorDamage = 0
  private(set) var windowRemaining: Float = 0
  private var wasRecovering = false

  /// Structural progress survives a closed window, retreat and a leader or weapon switch.
  var phase: Phase {
    if health == 0 { return .complete }
    if couplingBreached { return .reactor }
    return sensorDisabled ? .coupling : .sensor
  }

  /// Advance once per accepted simulation step. A recovery entry opens a fresh reactor
  /// window; remaining in recovery cannot keep refreshing one that has expired.
  mutating func advance(delta: Float, recovering: Bool) {
    guard delta.isFinite, delta > 0 else { return }
    let enteredRecovery = recovering && !wasRecovering
    wasRecovering = recovering
    guard phase != .complete else { return }
    if couplingBreached && enteredRecovery {
      windowRemaining = Self.windowDuration
    } else {
      windowRemaining = max(0, windowRemaining - delta)
    }
  }

  func isExposed(_ part: Part, recovering: Bool) -> Bool {
    guard phase != .complete else { return false }
    switch part {
    case .sensor: return !sensorDisabled && recovering
    case .coupling: return sensorDisabled && !couplingBreached
    case .reactor: return couplingBreached && windowRemaining > 0
    }
  }

  /// The adapter has resolved a real unobstructed enemy contact. Closed or unmatched parts
  /// still take ordinary damage. Only the exposed weapon match earns the bonus and progress.
  mutating func accept(
    weapon: Weapon.Kind, part: Part?, damage: Int, recovering: Bool
  ) -> Hit? {
    guard damage > 0, health > 0 else { return nil }
    let matched =
      part.map { part in
        guard isExposed(part, recovering: recovering) else { return false }
        switch (weapon, part) {
        case (.longRifle, .sensor), (.energySword, .coupling), (.minigun, .reactor): return true
        default: return false
        }
      } ?? false
    // Bound before multiplying, so even an oversized external contact cannot overflow.
    let base = min(damage, health)
    let amount = matched ? min(health, base * Self.weakpointMultiplier) : base
    health -= amount
    var brokeComponent = false
    if matched {
      switch part {
      case .sensor:
        sensorDisabled = true
        brokeComponent = true
      case .coupling:
        couplingBreached = true
        brokeComponent = true
        // Breaching late in recovery still supplies a complete independent bonus window.
        wasRecovering = recovering
        if recovering { windowRemaining = Self.windowDuration }
      case .reactor:
        reactorDamage += amount
      case nil:
        break
      }
    }
    if health == 0 { windowRemaining = 0 }
    return Hit(
      amount: amount, effectiveness: matched ? .weakpoint : .normal,
      brokeComponent: brokeComponent, defeated: health == 0)
  }
}
