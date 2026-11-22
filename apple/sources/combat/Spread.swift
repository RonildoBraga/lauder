/// How a weapon's shots scatter (ADR 0008): each goes within a cone either side of where it is
/// aimed. Each shot widens the cone, up to the widest, and it narrows again with time; moving
/// and turning widen it while they last. Angles are in radians, either side of the aim.
struct Spread: Sendable {
  /// The cone at rest, standing still.
  var rest: Float
  /// What each shot adds.
  var perShot: Float
  /// The widest it can be.
  var widest: Float
  /// How fast it narrows again, in radians a second.
  var recovery: Float
  /// What moving adds at full speed, and turning at full turning speed.
  var moving: Float
  var turning: Float

  /// No spread at all: every shot goes exactly where it is aimed.
  static let none = Spread(rest: 0, perShot: 0, widest: 0, recovery: 0, moving: 0, turning: 0)

  static func degrees(_ value: Float) -> Float { value * .pi / 180 }
}

/// A weapon's spread as the shooter fires, moves and turns (ADR 0008): the widening its shots
/// have built up, which narrows again with time.
struct Scatter: Sendable {
  private(set) var bloom: Float = 0

  /// One simulation step: the widening narrows.
  mutating func settle(dt: Float, spread: Spread) {
    bloom = max(0, bloom - spread.recovery * dt)
  }

  /// A shot widens it, up to the widest.
  mutating func fired(spread: Spread) {
    bloom = min(max(0, spread.widest - spread.rest), bloom + spread.perShot)
  }

  /// The cone now, either side of the aim, for a shooter moving at `speed` and turning at
  /// `turning`, each a share of full speed from 0 to 1.
  func angle(spread: Spread, speed: Float, turning: Float) -> Float {
    let movement = spread.moving * min(max(speed, 0), 1) + spread.turning * min(max(turning, 0), 1)
    return min(spread.widest, spread.rest + bloom + movement)
  }

  /// How far one shot turns from its aim within a cone of `angle` either side: anywhere in it,
  /// more often near the middle.
  static func deviation(within angle: Float, using generator: inout some RandomNumberGenerator)
    -> Float
  {
    guard angle > 0 else { return 0 }
    let first = Float.random(in: 0...1, using: &generator)
    let second = Float.random(in: 0...1, using: &generator)
    return (first + second - 1) * angle
  }
}

/// A small, repeatable source of random numbers (SplitMix64): the same seed gives the same shots,
/// so tests and playtests replay exactly.
struct SeededRandom: RandomNumberGenerator, Sendable {
  private var state: UInt64

  init(seed: UInt64) {
    state = seed
  }

  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var value = state
    value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
    value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
    return value ^ (value >> 31)
  }
}
