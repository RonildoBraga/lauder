import simd

/// A deliberately larger, repeatable greybox combat test, outside the story. Two broad
/// approaches climb a west deck or descend an east trench; the central yard has several
/// sight-breaking clusters. Authored arrival slots are reused instead of creating actors.
enum CombatYard {
  static let spawns: [PartyMember: SIMD2<Float>] = [
    .miki: [0, 6], .laura: [-0.9, 6.9], .tom: [0.9, 6.9],
  ]

  static let terrain = Terrain(patches: [
    .flat(minimum: [-21, -35], maximum: [-9, -10], height: 2.4),
    .ramp(minimum: [-21, -43], maximum: [-9, -35], axis: .z, from: 0, to: 2.4),
    .ramp(minimum: [-21, -10], maximum: [-9, -2], axis: .z, from: 2.4, to: 0),
    .flat(minimum: [9, -35], maximum: [21, -10], height: -1.8),
    .ramp(minimum: [9, -43], maximum: [21, -35], axis: .z, from: 0, to: -1.8),
    .ramp(minimum: [9, -10], maximum: [21, -2], axis: .z, from: -1.8, to: 0),
  ])

  static let boxes: [Level.Box] = [
    // A safe entrance, with space to go around either side rather than a single doorway.
    .box("wall", at: [0, 1.5, -1], size: [9, 3, 0.5]),
    .box("block-west", at: [-7.5, 0.55, -4], size: [1.6, 1.1, 1.2], look: .teal),
    .box("block-east", at: [8, 0.55, -4.5], size: [1.6, 1.1, 1.2], look: .rust),
    // Low shelters and tall hiding places break the central route into short crossings.
    .box("centre-low-south", at: [0, 0.55, -11], size: [3.2, 1.1, 1]),
    .box("centre-tall-west", at: [-6, 1.35, -18], size: [0.7, 2.7, 5]),
    .box("centre-low-west", at: [-5, 0.55, -23], size: [2.2, 1.1, 1]),
    .box("centre-tall-east", at: [6, 1.35, -28], size: [0.7, 2.7, 5]),
    .box("centre-tall-north", at: [0, 1.25, -34], size: [6, 2.5, 0.7]),
    .box("centre-low-north", at: [5, 0.55, -37], size: [3, 1.1, 1]),
    .box("far-screen", at: [0, 1.25, -39], size: [6, 2.5, 0.7]),
    // These boxes sit on their actual local floors; the coloured terraces are walkable.
    .box("enemy-cover", at: [-16, 2.95, -14], size: [3.6, 1.1, 1], look: .teal),
    .box("deck-low-north", at: [-17, 2.95, -30], size: [3.6, 1.1, 1], look: .teal),
    .box("deck-screen", at: [-12.5, 3.75, -24], size: [0.8, 2.7, 5]),
    .box("trench-low-south", at: [15, -1.25, -12], size: [3.6, 1.1, 1], look: .rust),
    .box("trench-low-north", at: [16, -1.25, -31], size: [3.6, 1.1, 1], look: .rust),
    .box("trench-screen", at: [12.5, -0.45, -23], size: [0.8, 2.7, 5]),
  ]

  /// Rifle profiles differ in burst length and recovery, rather than simply taking more hits.
  static let leftShooter = shooter(
    id: "left-shooter", name: "The deck rifle", at: [-16, -16], behavior: .takeCover)
  static let rightShooter = shooter(
    id: "right-shooter", name: "The trench flanker", at: [15, -14], behavior: .flank)
  static let rusher = rusher(id: "rusher", name: "The south rusher", at: [3, -15])
  static let thrower = grenadier(id: "thrower", name: "The yard grenadier", at: [-4, -26])
  static let northRifle = shooter(
    id: "north-rifle", name: "The north rifle", at: [16, -33], behavior: .takeCover)
  static let northFlanker = shooter(
    id: "north-flanker", name: "The north flanker", at: [-16, -33], behavior: .flank)
  static let northRusher = rusher(id: "north-rusher", name: "The north rusher", at: [4, -36])
  static let northThrower = grenadier(
    id: "north-thrower", name: "The north grenadier", at: [0, -42])
  /// A long lane from the upper deck; the ramp remains the squad's route to its position.
  static let marksman = Level.Hostile(
    id: "marksman", name: "The deck marksman", hiddenAt: [-17, -20], standAt: [-17, -20], hits: 4,
    weapon: .marksman, behavior: .keepDistance, reactionDelay: 1.1,
    burst: 1, windUp: 2.4, recovery: 2.5, range: 45,
    inView: true, targetsAnyone: true, targetFromWindUp: true)
  /// Volume and an exposed recovery window distinguish this role from an armoured sponge.
  static let supportGunner = Level.Hostile(
    id: "support-gunner", name: "The support gunner", hiddenAt: [7.1, -26], standAt: [7.1, -26],
    hits: 5,
    weapon: .supportGun, behavior: .takeCover, reactionDelay: 0.9,
    burst: 6, burstGap: 0.14, windUp: 1.8, recovery: 3, range: 22,
    inView: true, targetsAnyone: true, targetFromWindUp: true)

  static let hostiles = [
    leftShooter, rightShooter, rusher, thrower, northRifle, northFlanker, northRusher, northThrower,
    marksman, supportGunner,
  ]
  static let waves = ArenaWaves.Configuration(
    slots: hostiles.map { ArenaWaves.Slot(id: $0.id, point: $0.standAt) })

  /// The encounter establishes the test's combat rules. ArenaWaves supplies every engagement
  /// after a visible, rechecked arrival warning; the finite story director has no spawn cues.
  static let fight = Level.Encounter(
    beat: .stranger,
    start: .area(PartyMotion.Box(minimum: [-25, -47], maximum: [25, -1.5])),
    retryAt: spawns[.miki], hostiles: hostiles, cues: [])

  /// Shared squad rules, also used by the small relay mission. Repeated waves belong only to
  /// this level's arena configuration, so borrowing combat does not change story encounters.
  static let combat = Level.Combat(
    companionWeapons: [.miki: .carbine, .laura: .lightBurst, .tom: .closeScatter],
    fallsBack: true, disrupt: true, combatPositioning: true, leaderCover: true)

  static let level = Level(
    id: "combat-yard", ground: .box("ground", at: [0, -0.15, -18], size: [52, 0.3, 60]),
    terrain: terrain, boxes: boxes, interactions: [], triggers: [], encounters: [fight],
    startingAmmo: 60, party: [.miki, .tom, .laura], spawns: spawns, heading: [0, -1],
    cameraOffset: BrooklynBridge.layout.camera.offset,
    fieldOfView: BrooklynBridge.layout.camera.fieldOfView, lights: BrooklynBridge.layout.lights,
    opening: "Combat test: marked arrivals, mixed waves, and fresh resources after each clear.",
    objective: "Test the squad; survive repeated waves.",
    lookAround:
      "Upper deck, lower trench, and covered crossings. Watch arrivals, scoped rifles and support guns.",
    restartNote: "Restart begins the combat test at wave one.", combat: combat, arena: waves)

  private static func shooter(
    id: String, name: String, at point: SIMD2<Float>, behavior: Level.Hostile.Behavior
  ) -> Level.Hostile {
    let flanker = behavior == .flank
    return Level.Hostile(
      id: id, name: name, hiddenAt: point, standAt: point, hits: flanker ? 4 : 6,
      weapon: flanker ? .submachineGun : .rifle,
      behavior: behavior, reactionDelay: flanker ? 0.5 : 0.7,
      burst: flanker ? 4 : 3, burstGap: flanker ? 0.1 : 0.16,
      windUp: flanker ? 1.2 : 1.7, recovery: flanker ? 1.7 : 2.4, range: 18,
      inView: true, targetsAnyone: true, targetFromWindUp: true)
  }

  private static func rusher(id: String, name: String, at point: SIMD2<Float>) -> Level.Hostile {
    Level.Hostile(
      id: id, name: name, hiddenAt: point, standAt: point, hits: 4,
      weapon: .closeScatter, behavior: .advance, reactionDelay: 0.6, burst: 1,
      windUp: 0.8, recovery: 1.2, range: 7,
      inView: true, targetsAnyone: true, targetFromWindUp: true)
  }

  private static func grenadier(id: String, name: String, at point: SIMD2<Float>) -> Level.Hostile {
    Level.Hostile(
      id: id, name: name, hiddenAt: point, standAt: point, hits: 5,
      attack: .throwGrenade, reactionDelay: 1, windUp: 2.2, recovery: 5, range: 19,
      inView: true, targetsAnyone: true, targetFromWindUp: true)
  }
}
