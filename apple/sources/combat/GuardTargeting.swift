/// One guard's bounded retaliation memory. The encounter supplies actual attack events and
/// real sight/range eligibility; intentions and the selected player are not attack events.
struct GuardTargeting {
  static let attackMemory: Float = 8

  private(set) var member: PartyMember?
  private(set) var isRetaliation = false
  private var attackAges: [PartyMember: Float] = [:]

  /// Record an accepted native discharge during the fight, or an actual sword/guard contact.
  mutating func recordAttack(by member: PartyMember) {
    attackAges[member] = 0
  }

  /// Pausing the simulation also pauses this memory. Expired attacks cannot acquire a target.
  mutating func advance(dt: Float) {
    guard dt.isFinite, dt > 0 else { return }
    attackAges = attackAges.compactMapValues {
      let age = $0 + dt
      return age < Self.attackMemory ? age : nil
    }
  }

  /// Call before stepping the guard. A selected member stays fixed for the entire warned
  /// cycle, even after losing sight or changing leader. The encounter must pass that member's
  /// actual sight result, rather than substitute another actor midway through a warning.
  @discardableResult
  mutating func select(
    leader: PartyMember, phase: RobotGuard.Phase, engaged: Bool,
    eligible: Set<PartyMember>
  ) -> PartyMember? {
    switch phase {
    case .hidden, .down, .cleared:
      reset()
    case .notice, .tracking, .committed, .burst, .recovering:
      break
    case .patrol, .searching:
      // Quiet acquisition remains leader-only. Merely exposing a companion or ordering
      // Attack must not wake the machine or close the existing west-arch bypass.
      guard engaged else {
        member = leader
        isRetaliation = false
        return member
      }
      let attacker =
        PartyMember.allCases.filter { eligible.contains($0) && attackAges[$0] != nil }
        .min {
          let first = attackAges[$0] ?? .infinity
          let second = attackAges[$1] ?? .infinity
          // allCases supplies the stable tie order, independent of dictionary/set order.
          return first < second
        }
      member = attacker ?? leader
      isRetaliation = attacker != nil
    }
    return member
  }

  mutating func reset() {
    self = GuardTargeting()
  }
}
