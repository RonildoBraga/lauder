/// Shared health, a persistent eye critical and independent sword damage to four legs.
/// Actual contact belongs to the encounter; these rules never manufacture a hit.
struct GuardStrategy: Equatable, Sendable {
  enum Part: Hashable, Sendable {
    case eye
    case leg(Int)
  }

  enum Phase: Equatable, Sendable {
    case active, complete
  }

  struct Hit: Equatable, Sendable {
    let amount: Int
    let effectiveness: DamageHit.Effectiveness
    let detachedLeg: Int?
    let defeated: Bool

    var brokeComponent: Bool { detachedLeg != nil }
  }

  static let maximumHealth = 1500
  static let weakpointMultiplier = 3
  static let legCount = 4
  static let swordHitsToDetach = 3
  /// Preserve the guard's existing time between volleys; it no longer gates critical damage.
  static let recoveryDuration: Float = 4

  private(set) var health = Self.maximumHealth
  private(set) var detachedLegs: Set<Int> = []
  private(set) var swordHits: [Int: Int] = [:]

  var phase: Phase { health == 0 ? .complete : .active }
  var speedMultiplier: Float { max(0, 1 - Float(detachedLegs.count) * 0.25) }

  /// Every actual enemy contact deals health damage. Every weapon's eye hit is critical;
  /// three sword contacts on one intact leg detach it, without multiplying ordinary damage.
  mutating func accept(weapon: Weapon.Kind?, part: Part?, damage: Int) -> Hit? {
    guard damage > 0, health > 0 else { return nil }
    let critical = weapon != nil && part == .eye
    let base = min(damage, health)
    let amount = critical ? min(health, base * Self.weakpointMultiplier) : base
    health -= amount
    var detached: Int?
    if weapon == .energySword, let part, case .leg(let index) = part,
      (0..<Self.legCount).contains(index), !detachedLegs.contains(index)
    {
      swordHits[index, default: 0] += 1
      if swordHits[index] == Self.swordHitsToDetach {
        detachedLegs.insert(index)
        detached = index
      }
    }
    return Hit(
      amount: amount, effectiveness: critical ? .weakpoint : .normal,
      detachedLeg: detached, defeated: health == 0)
  }
}
