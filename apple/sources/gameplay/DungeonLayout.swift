import simd

/// One authored flat route. Collision, presentation and encounter triggers share these metres.
enum DungeonLayout {
  struct Wall: Sendable {
    let bounds: PartyMotion.Box
    let height: Float
  }

  struct Encounter: Sendable {
    let id: Int
    let home: SIMD2<Float>
    let activation: PartyMotion.Box
    let leash: Float
    let firstAttack: DuelAction.Kind
  }

  struct Doorway: Sendable {
    let name: String
    let centre: SIMD2<Float>
    let width: Float
    let alongX: Bool
  }

  static let heroSpawn = SIMD2<Float>(0, 10.5)
  static let firstEntry = SIMD2<Float>(0, 1.2)
  static let secondEntry = SIMD2<Float>(-11.5, -1.8)
  static let healingPosition = SIMD2<Float>(-8.5, 1)
  static let healingArea = box(-9.4, 0.1, -7.6, 1.9)
  static let shortcutOpening = box(-4, 6.3, -2.3, 7.7)
  static let exitArea = box(-21.5, -4, -20, -2)
  static let exitPosition = SIMD2<Float>(-20.75, -3)

  static let floors: [PartyMotion.Box] = [
    box(-2, 8, 2, 12),  // Safe entry/checkpoint.
    box(-1.5, 6.5, 1.5, 8),  // Two turns before the first chamber's eastern doorway.
    box(-1.5, 4, 4.5, 6.5),
    box(2, -0.5, 4.5, 5),
    box(-6, -5, 2, 2),
    box(-11, -3, -6, -0.5),
    box(-10, -0.5, -7, 2),  // Optional recovery alcove, between encounters.
    box(-18, -7, -11, 1),
    box(-16, 1, -13, 7),  // Return corridor opens the shortcut from its far side.
    box(-16, 6, 0, 8),
    box(-22, -7, -18, 1),  // Exit beyond the second room.
  ]

  static let encounters: [Encounter] = [
    Encounter(
      id: 0, home: [-2, -1.5], activation: box(-5.6, -4.6, 1.6, 1.6), leash: 5.5,
      firstAttack: .sweep),
    Encounter(
      id: 1, home: [-14.5, -3], activation: box(-17.6, -6.6, -11.4, 0.6), leash: 5.5,
      firstAttack: .thrust),
  ]

  /// Camera-near (+X/+Z) edges are cut away visually; all walls retain their full footprint.
  static let walls: [Wall] = [
    wall(-2.3, 8, -2, 12), wall(2, 8, 2.3, 12, near: true),
    wall(-2, 12, 2, 12.3, near: true),
    wall(-2, 7.7, -1.5, 8), wall(1.5, 7.7, 2, 8),
    wall(-1.8, 4, -1.5, 6, near: true), wall(1.5, 6.5, 1.8, 8, near: true),
    wall(1.5, 6.5, 4.5, 6.8, near: true), wall(-1.5, 3.7, 2, 4),
    wall(4.5, -0.5, 4.8, 6.5, near: true), wall(1.7, 2, 2, 4, near: true),
    wall(2, -0.8, 4.5, -0.5, near: true),
    wall(-6, -5.3, 2, -5), wall(2, -5, 2.3, -0.5, near: true),
    wall(-6, 2, 2, 2.3, near: true),
    wall(-6.3, -5, -6, -3), wall(-6.3, -0.5, -6, 2, near: true),
    wall(-11, -3.3, -6, -3),
    wall(-11, -0.5, -10, -0.2, near: true), wall(-7, -0.5, -6, -0.2, near: true),
    wall(-10.3, -0.5, -10, 2), wall(-7, -0.5, -6.7, 2, near: true),
    wall(-10, 2, -7, 2.3, near: true),
    wall(-11, -7, -10.7, -3, near: true), wall(-11, -0.5, -10.7, 1, near: true),
    wall(-22, -7.3, -11, -7),
    wall(-18, 1, -16, 1.3, near: true), wall(-13, 1, -11, 1.3, near: true),
    wall(-18.3, -7, -18, -4.5), wall(-18.3, -1.5, -18, 1, near: true),
    wall(-22.3, -7, -22, 1), wall(-22, 1, -18, 1.3, near: true),
    wall(-16.3, 1, -16, 8), wall(-13, 1, -12.7, 6, near: true),
    wall(-13, 5.7, -1.5, 6), wall(-16, 8, -2, 8.3, near: true),
  ]

  static let shortcutGate = Wall(bounds: box(-1.8, 6, -1.5, 8), height: 1.6)

  static let doorways: [Doorway] = [
    Doorway(name: "first-room", centre: [2, 0.75], width: 2.5, alongX: false),
    Doorway(name: "western-passage", centre: [-6, -1.75], width: 2.5, alongX: false),
    Doorway(name: "second-room", centre: [-11, -1.75], width: 2.5, alongX: false),
    Doorway(name: "exit-room", centre: [-18, -3], width: 3, alongX: false),
    Doorway(name: "shortcut", centre: [-1.65, 7], width: 2, alongX: false),
  ]

  static func obstacles(shortcutOpen: Bool) -> [PartyMotion.Box] {
    walls.map(\.bounds) + (shortcutOpen ? [] : [shortcutGate.bounds])
  }

  private static func box(_ x0: Float, _ z0: Float, _ x1: Float, _ z1: Float) -> PartyMotion.Box {
    PartyMotion.Box(minimum: [x0, z0], maximum: [x1, z1])
  }

  private static func wall(
    _ x0: Float, _ z0: Float, _ x1: Float, _ z1: Float, near: Bool = false
  ) -> Wall {
    Wall(bounds: box(x0, z0, x1, z1), height: near ? 0.22 : 2)
  }
}
