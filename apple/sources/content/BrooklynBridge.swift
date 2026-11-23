import simd

/// The opening: a compressed, flat greybox of the Brooklyn Bridge (ADR 0004), buried in snow.
/// Brooklyn is at +z and Manhattan at -z. The road and everything on it lie under a white plain
/// level with the old deck, and only the two towers stand above it. The party keeps to the line
/// of the buried road, inside an invisible edge at its width. The towers are the only cover: the
/// machine guards the first tower; a knife attacker later runs out of its west arch.
///
/// Where everything stands, the decoration, the camera and the lights are in `layout`
/// (BrooklynBridgeLayout.swift), which Blender exports (ADR 0002). This file adds the words: what
/// each place is called and what it says.
enum BrooklynBridge {
  /// Where each tower's centre stands along the deck. Since this file names the piers, Blender's
  /// export refuses to drop them.
  static var brooklynTower: Float { layout.box(named: "brooklyn-tower-pier").position.z }
  static var manhattanTower: Float { layout.box(named: "manhattan-tower-pier").position.z }
  /// The camera stands high and far, as the visual direction sets out, and looks straight along
  /// the deck, so pushing up walks towards Manhattan. Blender edits it with the rest of the layout.
  static var cameraOffset: SIMD3<Float> { layout.camera.offset }

  /// Each shows its line the first time the leader walks in, once per run.
  static let triggers: [Level.Trigger] = [
    trigger("buried-road", "Snow covers the road and everything left on it."),
    trigger("first-tower", "The first tower. Its arches still stand."),
    trigger("mid-span", "Mid-span. The wind is stronger out here."),
    trigger("second-tower", "The second tower. Manhattan is close now."),
    trigger("manhattan-end", "The Manhattan end. The city lies buried beyond it."),
  ]

  /// C guards the outgoing side of the first tower. The stable "stranger" identifiers retain
  /// the existing authored marker and progression references; the visible encounter is a robot.
  /// It warns, commits its aim and fires a short burst, with the tower's stone as real cover.
  static let stranger = Level.Hostile(
    id: "stranger", name: "The guard robot", hiddenAt: layout.marker(named: "stranger.stand"),
    standAt: layout.marker(named: "stranger.stand"), hits: 6, attack: .robot,
    windUp: 1, recovery: 1.8, range: 12)

  static let supplyCaseID = "bridge-supply-case"
  static let supplies = Level.Loot(rounds: 6, medicalKits: 1)
  static var supplyCasePosition: SIMD2<Float> { layout.marker(named: "supply.case") }

  /// The first fight, as Miki walks through the first tower. A retry starts just outside its
  /// area, in the east arch.
  static let strangerEncounter = Level.Encounter(
    beat: .stranger, start: .area(layout.area(named: "stranger")),
    retryAt: layout.marker(named: "stranger.retry"), hostiles: [stranger],
    cues: [
      (0, .reveal(stranger.id)),
      (0, .engage(stranger.id)),
      (0.6, .say(speaker: "Miki", line: "Still guarding something.")),
    ], safeExit: layout.area(named: "robot.exit"))

  /// A nonblocking supply case on the safe outgoing side. Defeating or bypassing the guard
  /// offers the same one-time supplies and starts Tom's existing ambush scene.
  static let searchStranger = Level.Interaction(
    id: .searchStranger, name: "Search case",
    approach: layout.area(named: "search.stranger"), result: "Miki opens the supply case.",
    repeated: "The case is empty.", early: "Get clear of the guard first.")

  /// The man who runs at Miki out of the tower's west arch while she searches (M3).
  static let attacker = Level.Hostile(
    id: "attacker", name: "The attacker", hiddenAt: layout.marker(named: "attacker.hidden"),
    standAt: layout.marker(named: "attacker.stand"), hits: 1, attack: .charge(speed: 5))

  /// The ambush (M3), a short scene that plays the same way every time: the search begins it
  /// and holds Miki still. The attacker steps out of the west arch and runs at her round the
  /// pier; she finishes the search; Tom appears beyond the tower and drops the attacker before he
  /// reaches her. They turn to each other, and the exchange that follows ends with Tom joining.
  static let ambush = Level.Encounter(
    beat: .ambush, start: .action(.searchStranger), retryAt: nil, hostiles: [attacker],
    cues: [
      (0.2, .reveal(attacker.id)),
      (0.6, .engage(attacker.id)),
      (1.5, .supplies(id: supplyCaseID, loot: supplies)),
      (2.0, .appear(.tom)),
      (2.6, .shot(by: .tom, at: attacker.id)),
      (3.0, .face(.miki, .tom)),
      (3.4, .talk(.metTom)),
    ],
    holdsParty: true)

  /// Laura (M4) lies hurt in the snow beyond mid-span. Once Tom has joined, the party's approach
  /// finds her: she calls out, the camera leans towards her so that she shows clear of the HUD,
  /// Miki answers, and Help is offered at her side.
  static let lauraFound = Level.Encounter(
    beat: .lauraFound, start: .area(layout.area(named: "laura.found")), retryAt: nil,
    hostiles: [],
    cues: [
      (0.3, .say(speaker: "A woman", line: "Please. Over here.")),
      (2.4, .say(speaker: "Miki", line: "Hold on. We're coming.")),
    ],
    focus: layout.marker(named: "spawn.laura"))

  /// Helping Laura uses the medical kit from the supply case. Whoever leads can help.
  static let helpLaura = Level.Interaction(
    id: .helpLaura, name: "Help", approach: layout.area(named: "help.laura"),
    result: "She gets the medical kit.", repeated: "She's on her feet now.",
    early: "She needs a medical kit.")

  /// A short scene that holds the leader: with the medical kit Laura stands, she and Miki turn
  /// to each other, and the exchange that follows ends with Laura joining.
  static let helping = Level.Encounter(
    beat: .helpingLaura, start: .action(.helpLaura), retryAt: nil, hostiles: [],
    cues: [
      (1.5, .stand(.laura)),
      (1.8, .face(.miki, .laura)),
      (2.2, .talk(.metLaura)),
    ],
    holdsParty: true)

  /// The end of the opening (M4): the three reach the Manhattan end together, the party stops,
  /// and a short exchange closes the slice. It waits until all three are there, so companions
  /// holding elsewhere must be called back first.
  static let arrival = Level.Encounter(
    beat: .arrived, start: .area(layout.area(named: "manhattan-end")), retryAt: nil,
    hostiles: [], cues: [(0.5, .talk(.arrival))], holdsParty: true, gathersParty: true)

  /// What the compass points to: the Manhattan end while crossing, the woman while she waits
  /// for help, the Manhattan end again for the three, and nothing once they are there.
  static let goals: [(beat: StoryBeat, goal: Level.Goal?)] = [
    (.alone, manhattan),
    (.lauraFound, Level.Goal(name: "The woman", point: layout.marker(named: "spawn.laura"))),
    (.withLaura, manhattan),
    (.arrived, nil),
  ]

  /// The Manhattan end's area, where the opening ends.
  private static var manhattan: Level.Goal {
    let end = layout.area(named: "manhattan-end")
    return Level.Goal(name: "Manhattan", point: (end.minimum + end.maximum) / 2)
  }

  static let level = Level(
    id: "brooklyn-bridge", ground: layout.ground, boxes: layout.boxes,
    // What the player sees, exported by Blender with the layout file from the level's own file.
    scene: "BrooklynBridge",
    interactions: [searchStranger, helpLaura], triggers: triggers,
    encounters: [strangerEncounter, ambush, lauraFound, helping, arrival],
    startingAmmo: 12,
    // Miki crosses alone. Tom waits hidden where his scene will be, and Laura lies hurt at
    // hers.
    party: [.miki],
    spawns: [
      .miki: layout.marker(named: "spawn.miki"), .tom: layout.marker(named: "spawn.tom"),
      .laura: layout.marker(named: "spawn.laura"),
    ],
    lying: [.laura],
    heading: [0, -1], cameraOffset: cameraOffset, fieldOfView: layout.camera.fieldOfView,
    lights: layout.lights,
    opening: "The Brooklyn end of the bridge. Manhattan is on the far side.",
    objective: "Cross the bridge to Manhattan.",
    objectiveChanges: [
      (.lauraFound, "Help the woman in the snow."),
      (.withLaura, "Cross to Manhattan together."),
      (.arrived, "Manhattan, together."),
    ],
    goals: goals,
    lookAround: "Manhattan is ahead, across the bridge.",
    restartNote: "Restart begins a new run at the Brooklyn end.")

  /// A trigger area from the layout, with the line it shows.
  private static func trigger(_ id: String, _ line: String) -> Level.Trigger {
    Level.Trigger(id: id, area: layout.area(named: id), line: line)
  }
}
