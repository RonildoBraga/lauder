/// The first guard's three-character sequence. Contact geometry belongs to the encounter;
/// this value accepts only the required character, weapon, part and opening.
struct GuardStrategy: Equatable, Sendable {
  enum Part: CaseIterable, Sendable {
    case sensor, coupling, reactor
  }

  enum Phase: Equatable, Sendable {
    case sensor, coupling, reactor, complete
  }

  enum Result: Equatable, Sendable {
    case blocked, progressed, damaged, defeated
  }

  static let windowDuration: Float = 4
  static let reactorDamageRequired = 12

  private(set) var sensorDisabled = false
  private(set) var couplingBreached = false
  private(set) var reactorDamage = 0
  private(set) var windowRemaining: Float = 0
  private var wasRecovering = false

  /// Structural progress survives a closed window, retreat and a leader or weapon switch.
  var phase: Phase {
    if reactorDamage == Self.reactorDamageRequired { return .complete }
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

  /// The adapter has already resolved an actual unobstructed contact on this part. Damage
  /// counts contacts, not a weapon's generic damage bonus, so every role remains necessary.
  mutating func accept(
    member: PartyMember, weapon: Weapon.Kind, part: Part, recovering: Bool
  ) -> Result {
    guard isExposed(part, recovering: recovering) else { return .blocked }
    switch part {
    case .sensor:
      guard member == .miki, weapon == .longRifle else { return .blocked }
      sensorDisabled = true
      return .progressed
    case .coupling:
      guard member == .laura, weapon == .energySword else { return .blocked }
      couplingBreached = true
      // Breaching late in recovery still gives the player the complete independent window.
      wasRecovering = recovering
      if recovering { windowRemaining = Self.windowDuration }
      return .progressed
    case .reactor:
      guard member == .tom, weapon == .minigun else { return .blocked }
      reactorDamage += 1
      if reactorDamage == Self.reactorDamageRequired {
        windowRemaining = 0
        return .defeated
      }
      return .damaged
    }
  }
}
