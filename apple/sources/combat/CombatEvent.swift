import simd

/// Something in a fight that the player hears or feels (ADR 0008). The world reports each one as
/// it happens, at its place on the ground, and the interface plays it as a sound, and, for what
/// the leader does or suffers, as a vibration.
enum CombatEvent: Equatable, Sendable {
  /// A weapon fired; `byLeader` when the player fired it.
  case fired(Weapon.Kind, at: SIMD2<Float>, byLeader: Bool)
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

  /// Where it happened.
  var position: SIMD2<Float> {
    switch self {
    case .fired(_, let point, _), .struckBody(let point), .struckBlock(let point),
      .empty(let point), .leaderHit(let point), .guardTargeted(_, let point):
      point
    }
  }
}
