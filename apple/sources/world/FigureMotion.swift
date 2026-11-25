import simd

/// How a figure's body moves for a moment when it fires or is hit (ADR 0008): it rocks back from
/// its own shot and away from a shot that hits it, then settles. The figures have no rig, so the
/// whole figure leans, turning about its feet.
struct BodyJolt: Sendable {
  /// How far a shot rocks its shooter back, and a hit rocks its target, in radians.
  static let recoil: Float = 3 * .pi / 180
  static let hit: Float = 12 * .pi / 180
  /// The most it leans however many shots land together.
  static let most: Float = 18 * .pi / 180
  /// How quickly it settles: the lean falls to about a third in this many seconds.
  static let settleTime: Float = 0.08

  /// The lean: the direction on the ground that the figure's top moves, times its angle.
  private(set) var lean: SIMD2<Float> = .zero

  var isSettled: Bool { lean == .zero }

  /// Rocks the figure's top towards `direction` on the ground by `angle`.
  mutating func push(towards direction: SIMD2<Float>, by angle: Float) {
    guard simd_length_squared(direction) > 0.000001 else { return }
    lean += simd_normalize(direction) * angle
    let size = simd_length(lean)
    if size > Self.most { lean *= Self.most / size }
  }

  /// One step: the lean settles, and stops once it is too small to see.
  mutating func settle(dt: Float) {
    lean *= exp(-dt / Self.settleTime)
    if simd_length_squared(lean) < 0.0000001 { lean = .zero }
  }

  /// The tilt to apply after the figure's turn, and how far its centre moves so that its feet
  /// stay where they stand, for a figure `height` tall whose centre is its origin.
  func pose(height: Float) -> (tilt: simd_quatf, offset: SIMD3<Float>) {
    Self.pose(lean: lean, height: height)
  }

  /// The same for any lean, such as a jolt's added to a pawn's walk (`PawnGait`).
  static func pose(lean: SIMD2<Float>, height: Float) -> (tilt: simd_quatf, offset: SIMD3<Float>) {
    let angle = simd_length(lean)
    guard angle > 0 else { return (simd_quatf(angle: 0, axis: [0, 1, 0]), .zero) }
    let direction = lean / angle
    let half = height / 2
    return (
      simd_quatf(angle: angle, axis: SIMD3(direction.y, 0, -direction.x)),
      SIMD3(
        direction.x * half * sin(angle), half * (cos(angle) - 1), direction.y * half * sin(angle))
    )
  }
}

/// A downed hostile falling away from the shot that downed it (ADR 0008), faster as it goes,
/// until it lies on the ground.
struct Fall: Sendable {
  /// Seconds the fall takes.
  static let duration: Float = 0.4
  /// How far the figure's centre comes down by the end, lying on the ground.
  static let drop: Float = 0.6

  /// The way its head goes, on the ground, as a unit vector.
  let direction: SIMD2<Float>
  /// The turn it had when it fell.
  let yaw: Float
  private(set) var elapsed: Float = 0

  init(away direction: SIMD2<Float>, yaw: Float, finished: Bool = false) {
    self.direction =
      simd_length_squared(direction) > 0.000001 ? simd_normalize(direction) : SIMD2(0, 1)
    self.yaw = yaw
    elapsed = finished ? Self.duration : 0
  }

  var isFinished: Bool { elapsed >= Self.duration }

  mutating func advance(dt: Float) {
    elapsed = min(Self.duration, elapsed + dt)
  }

  /// The figure's turn and where its centre sits now.
  var pose: (orientation: simd_quatf, position: SIMD3<Float>) {
    let progress = elapsed / Self.duration
    let eased = progress * progress
    let turn = simd_quatf(angle: yaw, axis: [0, 1, 0])
    let tip = simd_quatf(angle: .pi / 2 * eased, axis: SIMD3(direction.y, 0, -direction.x))
    return (tip * turn, [0, -Self.drop * eased, 0])
  }
}

/// How a party member holds a drawn weapon (ADR 0008, ADR 0010): low across the body while not
/// using it, raised to the shoulder along their facing while aiming or firing, and kicked back and up by
/// each shot. Positions are in the figure, whose centre is the origin, facing -z with +x to its
/// right; the weapon's own origin is its grip, with the barrel along its -z.
struct WeaponPose: Sendable {
  /// The grip and barrel shared by the pose, prop and shot's muzzle. Recoil is a starting
  /// value for each weapon's feel, without changing the character's movement or aim rules.
  struct Profile: Sendable {
    let lowGrip: SIMD3<Float>
    let raisedGrip: SIMD3<Float>
    let barrel: Float
    let kickBack: Float
    let kickLift: Float
  }

  let kind: Weapon.Kind
  /// Seconds the weapon stays raised after she last aims or fires.
  static let holdTime: Float = 0.8
  /// Seconds to raise it, and to lower it again.
  static let raiseTime: Float = 0.1
  static let lowerTime: Float = 0.25
  /// Seconds for a shot's kick to settle to about a third.
  static let kickTime: Float = 0.04
  /// The grip, held low and raised to the shoulder: at the raised grip, the barrel is at
  /// shoulder height.
  static let lowGrip = SIMD3<Float>(0.16, -0.02, -0.1)
  static let raisedGrip = SIMD3<Float>(0.15, 0.4, -0.14)
  /// How far ahead of the grip the muzzle is.
  static let barrel: Float = 0.475
  /// Held low, the barrel turns across the body and tips down.
  static let lowTurn: Float = 35 * .pi / 180
  static let lowTip: Float = -40 * .pi / 180
  /// A shot's kick, at its strongest: the grip back towards the shoulder and the muzzle up.
  static let kickBack: Float = 0.1
  static let kickLift: Float = 10 * .pi / 180

  /// From 0, held low, to 1, raised.
  private(set) var raise: Float = 0
  /// From 1 as a shot fires, settling to 0.
  private(set) var kick: Float = 0
  private var held: Float = 0
  init(kind: Weapon.Kind = .carbine) {
    self.kind = kind
  }

  static func profile(for kind: Weapon.Kind) -> Profile {
    switch kind {
    case .carbine, .rifle:
      Profile(
        lowGrip: lowGrip, raisedGrip: raisedGrip, barrel: barrel,
        kickBack: kickBack, kickLift: kickLift)
    case .lightBurst:
      Profile(
        lowGrip: [0.14, -0.02, -0.08], raisedGrip: [0.14, 0.4, -0.12], barrel: 0.32,
        kickBack: 0.055, kickLift: 6 * .pi / 180)
    case .closeScatter:
      Profile(
        lowGrip: [0.18, -0.05, -0.12], raisedGrip: [0.17, 0.4, -0.16], barrel: 0.5,
        kickBack: 0.16, kickLift: 16 * .pi / 180)
    }
  }

  /// One step: while she aims or holds Fire the weapon rises and stays up; a short while after,
  /// it lowers; a kick settles.
  mutating func step(dt: Float, aiming: Bool) {
    held = aiming ? Self.holdTime : max(0, held - dt)
    let goal: Float = held > 0 ? 1 : 0
    let rate = goal > raise ? 1 / Self.raiseTime : 1 / Self.lowerTime
    raise = goal > raise ? min(goal, raise + rate * dt) : max(goal, raise - rate * dt)
    kick *= exp(-dt / Self.kickTime)
    if kick < 0.001 { kick = 0 }
  }

  /// A shot: the weapon is up at once, stays up a while, and kicks.
  mutating func fired() {
    raise = 1
    held = Self.holdTime
    kick = 1
  }

  /// Holstered: the next draw starts held low.
  mutating func holster() {
    self = WeaponPose(kind: kind)
  }

  /// Where the weapon's grip is in the figure now, and which way the barrel points.
  var transform: (position: SIMD3<Float>, orientation: simd_quatf) {
    let profile = Self.profile(for: kind)
    let low =
      simd_quatf(angle: Self.lowTurn, axis: [0, 1, 0])
      * simd_quatf(angle: Self.lowTip, axis: [1, 0, 0])
    let held = simd_slerp(low, simd_quatf(angle: 0, axis: [0, 1, 0]), raise)
    let lift = simd_quatf(angle: profile.kickLift * kick, axis: [1, 0, 0])
    let grip = simd_mix(profile.lowGrip, profile.raisedGrip, SIMD3(repeating: raise))
    return (grip + SIMD3(0, 0, profile.kickBack * kick), held * lift)
  }

  /// Where the raised weapon's muzzle is on the ground, for a figure at `position` facing
  /// `facing`: where the leader's shots start.
  static func muzzle(
    from position: SIMD2<Float>, facing: SIMD2<Float>, kind: Weapon.Kind = .carbine
  ) -> SIMD2<Float> {
    let profile = Self.profile(for: kind)
    let right = SIMD2(-facing.y, facing.x)
    return position + facing * (profile.barrel - profile.raisedGrip.z) + right
      * profile.raisedGrip.x
  }
}
