import simd

/// A compact, standalone exploration mission: leave the shelter, choose a route to the depot,
/// recover a compatible regulator and return. It borrows the Relay House repair's mechanics,
/// but does not place that scene in the story or establish anyone's history.
enum RelayRun {
  static let spawns: [PartyMember: SIMD2<Float>] = [
    .miki: [0, 11], .tom: [0.9, 11.9], .laura: [-0.9, 11.9],
  ]

  /// Authored approach markers, kept clear of the things the party uses.
  static let fork: SIMD2<Float> = [0, 5]
  static let gateOutside: SIMD2<Float> = [0, -26.5]
  static let gateInside: SIMD2<Float> = [0, -30]
  static let latchPoint: SIMD2<Float> = [-1.8, -26.9]
  static let panelPoint: SIMD2<Float> = [1.9, -26.9]
  static let transmitterPoint: SIMD2<Float> = [-3, 8.8]

  /// The west lane has room for the whole party, including Spread. Its service wall blocks
  /// the guard's ground-level sight; its northern turn stays beyond the defended perimeter.
  static let safeRoute: [SIMD2<Float>] = [
    spawns[.miki]!, fork, [-12.5, 5], [-12.5, -25.5], gateOutside,
  ]

  /// The shorter route passes the service wall's east end and the visible guard. It is a
  /// choice, not a gate on the repair: either direction can be abandoned for the west lane.
  static let shortcutRoute: [SIMD2<Float>] = [
    spawns[.miki]!, fork, [5, 1], [5, -7], [0, -24.5], gateOutside,
  ]

  /// A square enclosing the stationary guard's ten-metre reach. Outside its north, south and
  /// east edges the guard is out of range; the west lane is also behind a full-height wall.
  static let guardArea = PartyMotion.Box(minimum: [-8, -23], maximum: [12, -3])
  static let guardPosts: [SIMD2<Float>] = [[-7, -3], [-7, -22], [11.7, -3], [11.7, -22]]

  static let guardHostile = Level.Hostile(
    id: "relay-guard", name: "The yard guard", hiddenAt: [2, -13], standAt: [2, -13], hits: 6,
    reactionDelay: 0.35, windUp: 1.5, recovery: 1.8, range: 10,
    inView: true, targetsAnyone: true, targetFromWindUp: true)

  static let fight: Level.Encounter = {
    var encounter = Level.Encounter(
      beat: .stranger, start: .area(guardArea), retryAt: spawns[.miki],
      hostiles: [guardHostile],
      cues: [
        (0, .say(speaker: "The yard guard", line: "Keep outside the service yard.")),
        (0.9, .engage(guardHostile.id)),
      ],
      clearedLine: "The guard is down. The shortcut is clear.")
    encounter.guardArea = guardArea
    return encounter
  }()

  static let cabinets: [Level.Salvage.Cabinet] = [
    cabinet("relay-cabinet-west", x: -4.5, holding: .otherModel),
    cabinet("relay-cabinet-middle", x: 0, holding: .live),
    cabinet("relay-cabinet-east", x: 4.5, holding: .compatible),
  ]

  static let transmitter = Level.Box.box(
    "relay-transmitter", at: [-3, 0.5, 10], size: [1, 1, 0.8], look: .teal)

  static let salvage: Level.Salvage = {
    var task = Level.Salvage(
      gate: .box("relay-gate", at: [0, 1.1, -28], size: [2.4, 2.2, 0.3], look: .rust),
      latch: PartyMotion.Box(minimum: [-2.8, -27.7], maximum: [-1.2, -26.2]),
      panel: PartyMotion.Box(minimum: [1.2, -27.7], maximum: [2.8, -26.2]),
      latchMark: .box("relay-latch", at: [-1.5, 1.85, -27.8], size: [0.4, 0.3, 0.1]),
      panelMark: .box("relay-panel", at: [1.9, 0.75, -27.81], size: [1, 1.2, 0.08]),
      cabinets: cabinets, transmitter: transmitter,
      aerial: [
        .box("relay-aerial-long", at: [-3.38, 1.7, 9.72], size: [0.07, 1.4, 0.07]),
        .box("relay-aerial-short", at: [-2.62, 1.4, 9.72], size: [0.07, 0.8, 0.07]),
      ],
      transmitterApproach: PartyMotion.Box(minimum: [-4.5, 8.4], maximum: [-1.5, 11.4]),
      doneObjective: "Signal restored. The trio can travel on together.")
    task.depotGoal = Level.Goal(name: "Depot gate", point: gateOutside)
    task.returnGoal = Level.Goal(name: "Transmitter", point: transmitterPoint)
    task.returnObjective = "Return to the shelter and repair the transmitter."
    task.completion = .relayRestored
    return task
  }()

  static let boxes: [Level.Box] =
    [
      // An open-front shelter. Its transmitter remains visible from the approach home.
      .box("shelter-west", at: [-6, 1.1, 10], size: [0.4, 2.2, 6], look: .teal),
      .box("shelter-east", at: [6, 1.1, 10], size: [0.4, 2.2, 6], look: .teal),
      .box("shelter-back", at: [0, 1.1, 14], size: [12.4, 2.2, 0.4], look: .teal),
      // The west lane and the court are genuinely separated by sight-blocking scenery.
      .box("service-wall-west", at: [-7, 1.5, -13], size: [0.6, 3, 22]),
      .box("service-wall-front", at: [0, 1.5, -2], size: [8, 3, 0.6], look: .rust),
      .box("collapsed-east-block", at: [15, 1.2, -13], size: [6, 2.4, 26]),
      .box("court-low-cover", at: [-1, 0.5, -8], size: [1.8, 1, 1.2]),
      // One shared service gate, opened from either of its two approaches.
      .box("depot-front-west", at: [-4.6, 1.1, -28], size: [6.8, 2.2, 0.3]),
      .box("depot-front-east", at: [4.6, 1.1, -28], size: [6.8, 2.2, 0.3]),
      .box("depot-west", at: [-8, 1.1, -33], size: [0.3, 2.2, 10.3]),
      .box("depot-east", at: [8, 1.1, -33], size: [0.3, 2.2, 10.3]),
      .box("depot-back", at: [0, 1.1, -38], size: [16.3, 2.2, 0.3]),
    ] + cabinets.map(\.box) + [transmitter]
    + [-1, -11, -22].map { z in
      .box(
        "west-route-post-\(-z)", at: [-16, 0.6, Float(z)], size: [0.2, 1.2, 0.2], look: .signal)
    }
    + guardPosts.enumerated().map { index, point in
      .box(
        "guard-warning-post-\(index)", at: [point.x, 0.8, point.y], size: [0.2, 1.6, 0.2],
        look: .rust)
    }

  static let triggers: [Level.Trigger] = [
    Level.Trigger(
      id: "relay-fork", area: PartyMotion.Box(minimum: [-3, 2.5], maximum: [3, 7]),
      line: "Laura: The covered west lane goes around. The shorter cut is guarded."),
    Level.Trigger(
      id: "relay-guard-warning", area: PartyMotion.Box(minimum: [4.1, -2], maximum: [8, 2]),
      line: "A rifle watches the service yard. The wall and the west lane give us another way."),
    Level.Trigger(
      id: "relay-west-lane", area: PartyMotion.Box(minimum: [-15, -23], maximum: [-10, -17]),
      line: "Tom: Around the wall, then the depot gate. There is room for all of us."),
    Level.Trigger(
      id: "relay-depot", area: PartyMotion.Box(minimum: [-7.5, -34], maximum: [7.5, -30]),
      line: "Miki: Check the regulator model. Leave anything still feeding a shelter connected."),
  ]

  static let level = Level(
    id: "relay-run",
    ground: .box("ground", at: [0, -0.15, -13], size: [36, 0.3, 58]),
    boxes: boxes, interactions: [], triggers: triggers, encounters: [fight], startingAmmo: 36,
    party: [.miki, .tom, .laura], spawns: spawns, heading: [0, -1],
    cameraOffset: BrooklynBridge.layout.camera.offset,
    fieldOfView: BrooklynBridge.layout.camera.fieldOfView, lights: BrooklynBridge.layout.lights,
    opening: "Miki: The transmitter needs a regulator. The depot is ahead; we come back together.",
    objective: "Find a compatible regulator in the depot.",
    goals: [(.alone, Level.Goal(name: "Depot gate", point: gateOutside))],
    lookAround: "The depot is north: the covered west lane, or the guarded service-yard shortcut.",
    restartNote: "Restart begins the relay mission again.",
    combat: CombatYard.combat, salvage: salvage)

  private static func cabinet(
    _ id: String, x: Float, holding contents: Level.Salvage.Contents
  ) -> Level.Salvage.Cabinet {
    Level.Salvage.Cabinet(
      id: id, box: .box(id, at: [x, 0.8, -36.6], size: [1.2, 1.6, 0.8]),
      approach: PartyMotion.Box(minimum: [x - 0.9, -36.2], maximum: [x + 0.9, -35]),
      contents: contents)
  }
}
