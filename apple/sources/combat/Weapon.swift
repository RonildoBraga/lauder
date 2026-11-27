/// A weapon's timing and reach (ADR 0004), and how its shots scatter (ADR 0008). Plain values:
/// the world times shots with them.
struct Weapon: Sendable {
  /// Which weapon it is, for how it works and how its shots sound and feel (ADR 0008, ADR 0021).
  /// The hostiles' rifle has no timing of its own here: their wind-ups time its shots.
  enum Kind: Hashable, Sendable {
    /// Miki's: long reach and heavy hits, slow to fire.
    case longRifle
    /// Miki's: rapid fire at middle range.
    case assaultRifle
    /// Laura's: a wide blast at close range.
    case shotgun
    /// Laura's: a glowing blade that strikes close by and turns shots from in front of her.
    case energySword
    /// Tom's: a heavy rotary gun that spins up, then fires very fast.
    case minigun
    /// Tom's: a dome round him that stops hostile shots while Fire is held.
    case shieldDome
    case rifle

    var name: String {
      switch self {
      case .longRifle: "Long rifle"
      case .assaultRifle: "Assault rifle"
      case .shotgun: "Shotgun"
      case .energySword: "Energy sword"
      case .minigun: "Minigun"
      case .shieldDome: "Shield"
      case .rifle: "Rifle"
      }
    }

    /// Whether it fires shots: every weapon but the sword and the shield.
    var shoots: Bool { self != .energySword && self != .shieldDome }
  }

  let kind: Kind
  /// Effective stopping reach, in metres; a sword's reach. Fired rounds still travel across the
  /// whole level.
  let range: Float
  /// Seconds between shots or swings while Fire is held, or between bursts.
  let interval: Float
  /// Seconds from the first Fire press until a holstered weapon can shoot.
  let drawTime: Float
  /// Consecutive discharges before the automatic reload. Rounds are not counted beyond the
  /// magazine: every weapon reloads by itself, without limit (ADR 0021).
  var capacity = 12
  /// Seconds to ready a fresh magazine, overlapping the normal interval after its last shot.
  var reloadTime: Float = 1.2
  /// Shots in each burst, `burstGap` seconds apart; one for single shots.
  var burst = 1
  var burstGap: Float = 0
  /// Health damage each shot or swing deals, before an exposed weak-point bonus.
  var damage = 1
  /// How far its shots scatter when the player fires it (ADR 0008).
  var spread = Spread.none
  /// Seconds Fire must be held before the first shot, as a rotary gun spins up.
  var spinUp: Float = 0
  /// How fast the leader walks while using it, as a share of the usual speed.
  var walking: Float = 1

  /// Whether shots or swings spend a magazine: the sword and the shield have none.
  var usesMagazine: Bool { kind.shoots }

  /// Miki's long rifle: long reach and heavy hits, one slow shot at a time. Standing still its
  /// shot lands where it is aimed; firing on the move or quickly scatters (ADR 0008).
  static let longRifle = Weapon(
    kind: .longRifle, range: 22, interval: 1, drawTime: 0.45, capacity: 5, reloadTime: 1.8,
    damage: 48,
    spread: Spread(
      rest: Spread.degrees(0.2), perShot: Spread.degrees(2.5), widest: Spread.degrees(6),
      recovery: Spread.degrees(2), moving: Spread.degrees(3), turning: Spread.degrees(3)))
  /// Miki's assault rifle: rapid fire while Fire is held, reaching middle range.
  static let assaultRifle = Weapon(
    kind: .assaultRifle, range: 12, interval: 0.1, drawTime: 0.3, capacity: 30, reloadTime: 1.6,
    damage: 5,
    spread: Spread(
      rest: Spread.degrees(1.5), perShot: Spread.degrees(0.8), widest: Spread.degrees(9),
      recovery: Spread.degrees(4), moving: Spread.degrees(2), turning: Spread.degrees(2)))
  /// Laura's shotgun: one slow, scattered heavy hit, strongest at close range.
  static let shotgun = Weapon(
    kind: .shotgun, range: 8, interval: 0.9, drawTime: 0.45, capacity: 6, reloadTime: 2,
    damage: 45,
    spread: Spread(
      rest: Spread.degrees(5), perShot: Spread.degrees(2), widest: Spread.degrees(9),
      recovery: Spread.degrees(4), moving: Spread.degrees(2), turning: Spread.degrees(1)))
  /// Laura's energy sword: a heavy swing that strikes every hostile within reach in front of
  /// her. While it is out, shots from in front of her glance off it (ADR 0021).
  static let energySword = Weapon(
    kind: .energySword, range: 1.6, interval: 0.55, drawTime: 0.25, damage: 30)
  /// Tom's minigun: it spins up for half a second, then fires very fast, with a wide scatter,
  /// and he walks slowly while it runs.
  static let minigun = Weapon(
    kind: .minigun, range: 14, interval: 0.06, drawTime: 0.6, capacity: 120, reloadTime: 3,
    damage: 3,
    spread: Spread(
      rest: Spread.degrees(3), perShot: Spread.degrees(0.4), widest: Spread.degrees(10),
      recovery: Spread.degrees(5), moving: Spread.degrees(3), turning: Spread.degrees(3)),
    spinUp: 0.5, walking: 0.6)
  /// Tom's shield: held, a dome round him stops hostile shots for anyone inside, while he walks
  /// slowly and cannot shoot. It runs down while held and recharges after (ADR 0021).
  static let shieldDome = Weapon(
    kind: .shieldDome, range: 0, interval: 0, drawTime: 0, walking: 0.5)

  /// The original enemy rifle keeps its prior accuracy profile; encounter specs time it.
  static let rifle = Weapon(
    kind: .rifle, range: 18, interval: 0.4, drawTime: 0.35,
    spread: Spread(
      rest: Spread.degrees(2.5), perShot: Spread.degrees(1), widest: Spread.degrees(8),
      recovery: Spread.degrees(3), moving: Spread.degrees(2), turning: Spread.degrees(4)))

  /// A long-travelling round loses its stopping bonus beyond its effective reach.
  func damage(at distance: Float) -> Int {
    distance.isFinite && distance > range ? min(1, damage) : damage
  }

  /// Each traveller's two weapons, the first in hand when a run starts (ADR 0021).
  static func pair(for member: PartyMember) -> [Weapon] {
    switch member {
    case .miki: [.longRifle, .assaultRifle]
    case .laura: [.shotgun, .energySword]
    case .tom: [.minigun, .shieldDome]
    }
  }
}

/// Tom's shield dome (ADR 0021): how long it can still be held, and how it recharges.
struct ShieldDome: Sendable {
  /// The dome's radius on the ground, round Tom: the Close formation's places fit inside.
  static let radius: Float = 2.6
  /// Seconds of holding from full.
  static let duration: Float = 6
  /// Seconds after letting go before it starts to recharge, then seconds to refill from empty.
  static let rechargeDelay: Float = 1
  static let rechargeTime: Float = 6
  /// Seconds of holding left when its sound warns that it is running down.
  static let warning: Float = 1.5

  /// Seconds of holding left.
  private(set) var remaining = ShieldDome.duration
  private(set) var isUp = false
  private var sinceDown: Float = 0
  /// Run down while held: it stays down until Fire is let go, rather than flickering back up.
  private var spent = false

  /// One fixed step: held, the dome stays up while it lasts; otherwise it recharges.
  mutating func step(dt: Float, held: Bool) {
    guard dt.isFinite, dt > 0 else { return }
    if !held { spent = false }
    if held, !spent, remaining > 0 {
      isUp = true
      remaining = max(0, remaining - dt)
      sinceDown = 0
      if remaining == 0 {
        isUp = false
        spent = true
      }
      return
    }
    isUp = false
    sinceDown += dt
    if sinceDown > Self.rechargeDelay {
      remaining = min(Self.duration, remaining + dt * Self.duration / Self.rechargeTime)
    }
  }

  /// Down at once, as a roll, a scene or a switch takes Tom's hands off it.
  mutating func drop() {
    isUp = false
  }
}
