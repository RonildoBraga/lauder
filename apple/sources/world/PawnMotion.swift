import simd

/// How a pawn shows the movement the game has already resolved (the visual direction's pawns
/// have no rig): it bobs once per step, waddles from side to side and leans into its speed.
/// Only the figure moves; the body that collides, aims and is hit stays where it was resolved.
struct PawnGait: Sendable {
  /// Metres walked per step; each step is one bob and one rock to a side.
  static let stepLength: Float = 0.42
  /// How high a step lifts the pawn at walking speed, in metres.
  static let bobHeight: Float = 0.045
  /// How far it rocks to each side at walking speed.
  static let waddle: Float = 5 * .pi / 180
  /// How far it leans into its movement at walking speed.
  static let lean: Float = 6 * .pi / 180
  /// How quickly the shown speed follows the movement: about two thirds of the way in this time.
  static let followTime: Float = 0.08
  /// A move longer than this in one step puts the pawn somewhere new, such as a retry; it does
  /// not walk there.
  static let largestStep: Float = 1

  /// Steps walked, from 0 up to 2: one step to each side.
  private(set) var phase: Float = 0
  /// The movement shown, in metres per second on the ground, following the resolved movement.
  private(set) var velocity: SIMD2<Float> = .zero

  /// One fixed step in which the body moved `moved` on the ground.
  mutating func step(moved: SIMD2<Float>, dt: Float) {
    guard dt > 0, moved.x.isFinite, moved.y.isFinite else { return }
    let distance = simd_length(moved)
    guard distance <= Self.largestStep else {
      self = PawnGait()
      return
    }
    phase = (phase + distance / Self.stepLength).truncatingRemainder(dividingBy: 2)
    velocity += (moved / dt - velocity) * (1 - exp(-dt / Self.followTime))
    if simd_length_squared(velocity) < 0.0001 { velocity = .zero }
  }

  /// How fast it moves, against walking speed: 0 standing, 1 walking.
  var pace: Float { min(simd_length(velocity) / PartyBody.speed, 1) }

  /// The lean, as `BodyJolt` measures one: the direction on the ground its top moves, times the
  /// angle. A figure facing `facing` leans along its movement and rocks across its facing.
  func lean(facing: SIMD2<Float>) -> SIMD2<Float> {
    let pace = self.pace
    guard pace > 0 else { return .zero }
    let ahead = simd_normalize(velocity) * Self.lean * pace
    let side = SIMD2(-facing.y, facing.x) * Self.waddle * pace * sin(.pi * phase)
    return ahead + side
  }

  /// How far the step lifts it now.
  var lift: Float { Self.bobHeight * pace * abs(sin(.pi * phase)) }
}

/// The leader's dodge roll: a quick tumble a few metres along the ground, during which hostile
/// shots pass through them. A roll goes the way the player is moving, or the way the leader
/// faces with no movement held; the next one waits a moment after the last ends.
struct DodgeRoll: Sendable {
  /// Seconds a roll takes, how far it goes, and the wait after it before the next.
  static let duration: Float = 0.45
  static let distance: Float = 3
  static let cooldown: Float = 0.5
  /// How small the pawn tucks at the middle of the roll: its height, and its width.
  static let tuckedHeight: Float = 0.55
  static let tuckedWidth: Float = 1.15

  let member: PartyMember
  /// The way it rolls, a unit direction on the ground.
  let direction: SIMD2<Float>
  private(set) var elapsed: Float = 0

  init(member: PartyMember, direction: SIMD2<Float>) {
    self.member = member
    self.direction =
      simd_length_squared(direction) > 0.000001 ? simd_normalize(direction) : SIMD2(0, -1)
  }

  var isFinished: Bool { elapsed >= Self.duration }
  /// From 0 as the roll starts to 1 as it ends.
  var progress: Float { min(elapsed / Self.duration, 1) }

  /// The share of the distance covered at `progress`: fast at first, slowing as it ends.
  static func travel(at progress: Float) -> Float {
    let left = 1 - min(max(progress, 0), 1)
    return 1 - left * left
  }

  /// One fixed step of the roll: how far it moves the body on the ground.
  mutating func advance(dt: Float) -> SIMD2<Float> {
    let before = Self.travel(at: progress)
    elapsed = min(Self.duration, elapsed + max(dt, 0))
    return direction * (Self.travel(at: progress) - before) * Self.distance
  }

  /// The figure's tumble, applied after its turn: one turn forward over the way it rolls, tucked
  /// small through the middle and lowered so that it stays on the ground, for a figure `height`
  /// tall whose centre is its origin.
  func pose(height: Float) -> (tilt: simd_quatf, offset: SIMD3<Float>, scale: SIMD3<Float>) {
    let progress = self.progress
    let eased = progress * progress * (3 - 2 * progress)
    let tuck = sin(.pi * progress)
    let tall = 1 - (1 - Self.tuckedHeight) * tuck
    let wide = 1 + (Self.tuckedWidth - 1) * tuck
    let tilt = simd_quatf(angle: 2 * .pi * eased, axis: SIMD3(direction.y, 0, -direction.x))
    return (tilt, [0, -height / 2 * (1 - tall), 0], [wide, tall, wide])
  }
}
