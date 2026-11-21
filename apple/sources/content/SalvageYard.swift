import simd

/// The salvage yard: a temporary greybox venue for the first salvage and exploration experiment
/// (ADR 0006), outside the story, which the pause menu reaches while the experiments last. It has
/// no Blender file and no scene file, so the game draws it as plain blocks on snow, under the
/// bridge's camera and lights, and all of it lies within the roughly 19 m that the camera shows
/// ahead of the entrance.
///
/// The whole trio starts recruited at the entrance, beside a broken transmitter. Beyond it, a
/// fenced depot is shut except for a service gate, which Laura opens from its latch or Tom by
/// shifting its loose panel. Inside, three cabinets look alike: one holds the regulator the
/// transmitter needs, one a regulator of a different model, and one still feeds a neighbouring
/// shelter, so it stays connected. Each run deals those contents to the cabinets afresh, so only
/// an inspection tells them apart. There are no hostiles.
enum SalvageYard {
  /// The entrance: where each member starts.
  static let spawns: [PartyMember: SIMD2<Float>] = [
    .miki: [0, 6], .laura: [-0.9, 6.9], .tom: [0.9, 6.9],
  ]

  /// The depot's fence, taller than anyone, around a yard 12 m wide and 8 m deep, with a 2 m
  /// gap in its front for the gate; the three cabinets inside; and the transmitter at the
  /// entrance.
  static let boxes: [Level.Box] =
    [
      .box("fence-south-west", at: [-3.5, 1.1, -4], size: [5, 2.2, 0.3]),
      .box("fence-south-east", at: [3.5, 1.1, -4], size: [5, 2.2, 0.3]),
      .box("fence-west", at: [-6, 1.1, -8], size: [0.3, 2.2, 8.3]),
      .box("fence-east", at: [6, 1.1, -8], size: [0.3, 2.2, 8.3]),
      .box("fence-north", at: [0, 1.1, -12], size: [12.3, 2.2, 0.3]),
    ] + cabinets.map(\.box) + [transmitter]

  /// The cabinets along the depot's back fence. As authored, from west to east, they hold the
  /// wrong model, the live equipment and the right one; each run deals these afresh.
  static let cabinets: [Level.Salvage.Cabinet] = [
    cabinet("cabinet-west", x: -3.5, holding: .otherModel),
    cabinet("cabinet-middle", x: 0, holding: .live),
    cabinet("cabinet-east", x: 3.5, holding: .compatible),
  ]

  /// The transmitter: low enough that a leader standing behind it, come from the depot, still
  /// shows over it.
  static let transmitter = Level.Box.box("transmitter", at: [-3, 0.5, 5], size: [1, 1, 0.8])

  /// The gate, rust-red like the world's other barriers, hangs in the fence's gap. The latch, high
  /// on the fence beside it, and the loose panel on its other side show in amber, as things to
  /// use. The transmitter's two aerials rise from its back corners, and its approach reaches back
  /// towards the depot, so a leader who arrives from there can fit a regulator straight away.
  static let salvage = Level.Salvage(
    gate: .box("gate", at: [0, 1.1, -4], size: [2, 2.2, 0.3]),
    latch: PartyMotion.Box(minimum: [-2.4, -3.75], maximum: [-1, -2.6]),
    panel: PartyMotion.Box(minimum: [1, -3.75], maximum: [2.4, -2.6]),
    latchMark: .box("latch", at: [-1.4, 1.85, -3.8], size: [0.4, 0.3, 0.1]),
    panelMark: .box("panel", at: [1.7, 0.75, -3.81], size: [1, 1.2, 0.08]),
    cabinets: cabinets, transmitter: transmitter,
    aerial: [
      .box("aerial-long", at: [-3.38, 1.7, 4.72], size: [0.07, 1.4, 0.07]),
      .box("aerial-short", at: [-2.62, 1.4, 4.72], size: [0.07, 0.8, 0.07]),
    ],
    transmitterApproach: PartyMotion.Box(minimum: [-4.4, 3.2], maximum: [-1.6, 6.3]),
    doneObjective: "The transmitter works. Restart to try again.")

  static let level = Level(
    id: "salvage-yard",
    ground: .box("ground", at: [0, -0.15, -2], size: [30, 0.3, 28]),
    boxes: boxes, interactions: [], triggers: [],
    party: [.miki, .tom, .laura], spawns: spawns, heading: [0, -1],
    cameraOffset: BrooklynBridge.layout.camera.offset,
    fieldOfView: BrooklynBridge.layout.camera.fieldOfView, lights: BrooklynBridge.layout.lights,
    opening: "The salvage yard, a test of salvage outside the story.",
    objective: "Fix the transmitter.",
    lookAround: "A broken transmitter, and a fenced depot with a service gate.",
    restartNote: "Restart begins the salvage yard again.", salvage: salvage)

  /// A cabinet against the depot's back fence, with its approach in front of it.
  private static func cabinet(
    _ id: String, x: Float, holding contents: Level.Salvage.Contents
  ) -> Level.Salvage.Cabinet {
    Level.Salvage.Cabinet(
      id: id, box: .box(id, at: [x, 0.8, -10.9], size: [1.2, 1.6, 0.8]),
      approach: PartyMotion.Box(minimum: [x - 0.9, -10.5], maximum: [x + 0.9, -9.3]),
      contents: contents)
  }
}
