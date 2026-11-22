/// A weapon's timing and reach (ADR 0004), and how its shots scatter (ADR 0008). Plain values:
/// the world times shots with them.
struct Weapon: Sendable {
  /// Which weapon it is, for how its shots sound and feel (ADR 0008). The hostiles' rifle has
  /// no timing of its own here: their wind-ups time its shots.
  enum Kind: Hashable, Sendable {
    case carbine, lightBurst, closeScatter, rifle

    var name: String {
      switch self {
      case .carbine: "Carbine"
      case .lightBurst: "Burst weapon"
      case .closeScatter: "Scatter weapon"
      case .rifle: "Rifle"
      }
    }
  }

  let kind: Kind
  /// Effective stopping reach, in metres. Fired rounds still travel across the whole level.
  let range: Float
  /// Seconds between shots while Fire is held, or between bursts.
  let interval: Float
  /// Seconds from the first Fire press until a holstered weapon can shoot.
  let drawTime: Float
  /// Consecutive discharges before the automatic reload. This is a handling limit, not
  /// another inventory: the session still counts the party's remaining player-fired rounds.
  var capacity = 12
  /// Seconds to ready a fresh magazine, overlapping the normal interval after its last shot.
  var reloadTime: Float = 1.2
  /// Shots in each burst, `burstGap` seconds apart; one for single shots.
  var burst = 1
  var burstGap: Float = 0
  /// Hits each shot deals: a scatter weapon's blast counts for more than one.
  var damage = 1
  /// How far its shots scatter when the player fires it (ADR 0008).
  var spread = Spread.none

  /// Miki's precision carbine. The range limits assistance, not the fired bullet's travel.
  /// Standing still, its first shot lands within 10 cm at assisted reach; a long burst, or
  /// firing on the move, scatters (ADR 0008).
  static let carbine = Weapon(
    kind: .carbine, range: 14, interval: 0.4, drawTime: 0.35, capacity: 12, reloadTime: 1.2,
    spread: Spread(
      rest: Spread.degrees(0.4), perShot: Spread.degrees(1.6), widest: Spread.degrees(6),
      recovery: Spread.degrees(2.5), moving: Spread.degrees(2.5), turning: Spread.degrees(2)))
  /// Laura's light burst weapon (ADR 0005): bursts of three quick shots, reaching a little
  /// less far than the carbine. Starting values, to tune in play.
  static let lightBurst = Weapon(
    kind: .lightBurst, range: 12, interval: 1.8, drawTime: 0.5, capacity: 18, reloadTime: 1.4,
    burst: 3, burstGap: 0.12,
    spread: Spread(
      rest: Spread.degrees(1.2), perShot: Spread.degrees(1.1), widest: Spread.degrees(8),
      recovery: Spread.degrees(3.5), moving: Spread.degrees(2), turning: Spread.degrees(2)))
  /// Tom's close scatter weapon (ADR 0005): a slow blast that counts as two hits, only at close
  /// range. Starting values, to tune in play.
  static let closeScatter = Weapon(
    kind: .closeScatter, range: 7, interval: 0.8, drawTime: 0.55, capacity: 4, reloadTime: 1.8,
    damage: 2,
    spread: Spread(
      rest: Spread.degrees(6), perShot: Spread.degrees(2), widest: Spread.degrees(10),
      recovery: Spread.degrees(4), moving: Spread.degrees(2), turning: Spread.degrees(1)))

  /// The original enemy rifle keeps its prior accuracy profile; encounter specs time it.
  static let rifle = Weapon(
    kind: .rifle, range: 18, interval: 0.4, drawTime: 0.35,
    spread: Spread(
      rest: Spread.degrees(2.5), perShot: Spread.degrees(1), widest: Spread.degrees(8),
      recovery: Spread.degrees(3), moving: Spread.degrees(2), turning: Spread.degrees(4)))

  /// A long-travelling scatter round loses its stopping bonus beyond its effective reach.
  func damage(at distance: Float) -> Int {
    distance.isFinite && distance > range ? min(1, damage) : damage
  }

  /// Each traveller's weapon.
  static func forMember(_ member: PartyMember) -> Weapon {
    switch member {
    case .miki: .carbine
    case .laura: .lightBurst
    case .tom: .closeScatter
    }
  }
}
