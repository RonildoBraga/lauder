import simd

/// Something in a fight that the player hears or feels (ADR 0008). The world reports each one as
/// it happens, at its place on the ground, and the interface plays it as a sound, and, for what
/// the leader does or suffers, as a vibration.
enum CombatEvent: Equatable, Sendable {
  /// How Tom's shield dome changed (ADR 0021): each has its own sound.
  enum DomeChange: Equatable, Sendable {
    /// Raised round him as Fire is held.
    case raised
    /// Still up, with little holding time left.
    case fading
    /// Let go, or dropped by a switch, a roll or a scene, with charge left.
    case lowered
    /// Run out while held.
    case collapsed
    /// Full again while it is in his hands.
    case recharged
  }

  /// A weapon fired; `byLeader` when the player fired it.
  case fired(Weapon.Kind, at: SIMD2<Float>, byLeader: Bool)
  /// A minigun began to spin up as Fire was held; `byLeader` when the player holds it.
  case spinUp(at: SIMD2<Float>, byLeader: Bool)
  /// Tom's dome changed; only the leader holds it up.
  case dome(DomeChange, at: SIMD2<Float>)
  /// A shot struck someone.
  case struckBody(at: SIMD2<Float>)
  /// A shot struck a block.
  case struckBlock(at: SIMD2<Float>)
  /// The leader pressed Fire with no rounds left.
  case empty(at: SIMD2<Float>)
  /// A hostile's shot hit the leader.
  case leaderHit(at: SIMD2<Float>)
  /// The guard began a new warned cycle against this member, once on entering notice.
  case guardTargeted(PartyMember, at: SIMD2<Float>)
  /// A newly detached guard leg began a nonlethal stagger, once at its physical position.
  case guardLegBroken(at: SIMD2<Float>)
  /// Enemy health actually changed, with the accepted amount and physical impact.
  case damaged(DamageHit)

  /// Where it happened.
  var position: SIMD2<Float> {
    switch self {
    case .fired(_, let point, _), .spinUp(let point, _), .dome(_, let point),
      .struckBody(let point), .struckBlock(let point), .empty(let point), .leaderHit(let point),
      .guardTargeted(_, let point), .guardLegBroken(let point):
      point
    case .damaged(let hit):
      SIMD2(hit.position.x, hit.position.z)
    }
  }
}
