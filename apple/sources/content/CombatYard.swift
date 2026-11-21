import simd

/// The combat yard: a temporary greybox venue for the first squad combat experiment (ADR 0005),
/// outside the story, which the pause menu reaches only while the experiment lasts. It has no
/// Blender file and no scene file, so the game draws its snow ground, its one full-height wall and
/// its two small blocks as plain blocks, under the bridge's camera and lights. All of it lies
/// within the roughly 19 m that the camera shows ahead of the entrance.
///
/// The whole trio starts recruited at the entrance, in the Close formation, with Laura on the
/// left and Tom on the right, as the HUD orders them at the end of the opening. Two shooters of
/// the stranger's type wait in view beyond the wall, out of the party's clear sight, so the party
/// approaches; the fight begins once the leader comes level with the wall.
///
/// The experiment's rules are the yard's own, and the bridge keeps the opening's: the shooters
/// aim at anyone in clear sight within reach and are targets from their first wind-up, the
/// companions fire by themselves once the fight is under way, everyone can take three hits and
/// the third on anyone falls the party back to the entrance, and Miki can Disrupt. Since the
/// first session the companions also take cover near their places in a fight.
enum CombatYard {
  /// The entrance: where each member starts, and where the party falls back to.
  static let spawns: [PartyMember: SIMD2<Float>] = [
    .miki: [0, 6], .laura: [-0.9, 6.9], .tom: [0.9, 6.9],
  ]

  /// The wall across the yard, taller than anyone, and two small blocks beyond its ends, each
  /// cover for whoever keeps it between them and a shooter.
  static let boxes: [Level.Box] = [
    .box("wall", at: [0, 1.5, -1], size: [9, 3, 0.5]),
    .box("block-west", at: [-7.5, 0.5, -4], size: [1.6, 1, 1.2]),
    .box("block-east", at: [8, 0.5, -4.5], size: [1.6, 1, 1.2]),
  ]

  /// The shooter beyond the wall's west end, the further of the two.
  static let leftShooter = shooter(id: "left-shooter", name: "The left shooter", at: [-3, -8])
  /// The shooter beyond the wall's east end, the nearer of the two.
  static let rightShooter = shooter(id: "right-shooter", name: "The right shooter", at: [4, -5.5])

  /// The fight begins as the leader comes level with the wall, wherever they cross, and the two
  /// shooters open fire a moment apart, so that their wind-ups alternate. The yard has no story:
  /// its one fight takes the beat after the start, as any level's first encounter must.
  static let fight = Level.Encounter(
    beat: .stranger, start: .area(PartyMotion.Box(minimum: [-15, -16], maximum: [15, 1])),
    retryAt: spawns[.miki], hostiles: [leftShooter, rightShooter],
    cues: [(0.4, .engage(rightShooter.id)), (1.1, .engage(leftShooter.id))],
    clearedLine: "The yard is clear. Restart to fight again.")

  /// The experiment's rules. While someone else leads, each member fires by themselves, Miki
  /// with her carbine, Laura with her light burst weapon and Tom with his close scatter weapon,
  /// and takes cover near their place.
  static let combat = Level.Combat(
    companionWeapons: [.miki: .carbine, .laura: .lightBurst, .tom: .closeScatter],
    fallsBack: true, disrupt: true, takesCover: true)

  static let level = Level(
    id: "combat-yard",
    ground: .box("ground", at: [0, -0.15, -2], size: [30, 0.3, 28]),
    boxes: boxes, interactions: [], triggers: [], encounters: [fight],
    // Enough rounds that ammunition does not decide the experiment.
    startingAmmo: 60,
    party: [.miki, .tom, .laura], spawns: spawns, heading: [0, -1],
    cameraOffset: BrooklynBridge.layout.camera.offset,
    fieldOfView: BrooklynBridge.layout.camera.fieldOfView, lights: BrooklynBridge.layout.lights,
    opening: "The combat yard, a test of squad fighting outside the story.",
    objective: "Clear the yard.", lookAround: "A wall, two blocks, and two shooters beyond.",
    restartNote: "Restart begins the yard again.", combat: combat)

  /// The pause menu's third choice while the experiment lasts: from any other level it reads
  /// Combat test and starts the yard, and in the yard it reads Bridge and returns to a new run of
  /// the opening.
  static func pauseChoice(leaving level: Level) -> (name: String, note: String, level: Level) {
    level.id == Self.level.id
      ? ("Bridge", "Bridge returns to a new run of the opening.", BrooklynBridge.level)
      : ("Combat test", "Combat test opens the combat yard, outside the story.", Self.level)
  }

  /// A shooter of the stranger's type, waiting in view where it fights, that aims at anyone and
  /// is a target from its first wind-up. Starting values for playtests: the stranger's wind-up,
  /// recovery and reach, and six hits to take down, since three members can fire at it.
  private static func shooter(id: String, name: String, at point: SIMD2<Float>) -> Level.Hostile {
    Level.Hostile(
      id: id, name: name, hiddenAt: point, standAt: point, hits: 6, windUp: 1.5, recovery: 1.4,
      range: 14, inView: true, targetsAnyone: true, targetFromWindUp: true)
  }
}
