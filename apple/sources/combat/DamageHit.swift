import simd

/// An accepted enemy-health change. Presentation consumes the resolved amount, never guesses
/// damage from a shot, an intention or an impact that might have met scenery.
struct DamageHit: Equatable, Sendable {
  enum Effectiveness: Equatable, Sendable {
    case normal, weakpoint
  }

  let target: String
  let attacker: PartyMember
  let weapon: Weapon.Kind?
  let amount: Int
  let position: SIMD3<Float>
  let effectiveness: Effectiveness
  let brokeComponent: Bool
}
