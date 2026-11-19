import simd

/// The opening: a compressed, flat greybox of the Brooklyn Bridge (ADR 0004). Brooklyn is at +z
/// and Manhattan at -z. Two roadways run either side of the raised walkway's base, which has
/// collapsed at mid-span; a bus jammed across the east roadway sends the route through that gap.
/// Vehicles stand where the later scenes need them: cover before the first tower, a van beside
/// it, and a car on the west roadway near the gap.
///
/// Where everything stands, the decoration, the camera and the lights are in `layout`
/// (BrooklynBridgeLayout.swift), which Blender edits (ADR 0005). This file adds the words: what
/// each place is called and what it says.
enum BrooklynBridge {
  /// Where each tower's centre stands along the deck.
  static var brooklynTower: Float { layout.box(named: "brooklyn-tower-pier").position.z }
  static var manhattanTower: Float { layout.box(named: "manhattan-tower-pier").position.z }
  /// The camera keeps the accepted height and distance but looks straight along the deck, so
  /// pushing up walks towards Manhattan. Blender edits it with the rest of the layout.
  static var cameraOffset: SIMD3<Float> { layout.camera.offset }

  static let points: [Level.PointOfInterest] = [
    point(
      "bridge.booth", "Checkpoint booth",
      "A checkpoint booth, its window shattered. Nobody has staffed it in years."),
    point(
      "bridge.bus", "Bus", "A bus jammed across the lanes. Beside it, the divider has given way."),
    point(
      "bridge.manhattan-barricade", "Barricade", "Cars and wire close off the Manhattan end."),
  ]

  /// Each shows its line the first time the leader walks in, once per run.
  static let triggers: [Level.Trigger] = [
    trigger("cars-ahead", "Cars stand where they stopped, doors still open."),
    trigger("first-tower", "The first tower. Its arches still stand."),
    trigger("mid-span", "Mid-span. The wind is stronger out here."),
    trigger("blocked-lanes", "The lanes ahead are blocked. The divider has given way here."),
    trigger("second-tower", "The second tower. Manhattan is close now."),
    trigger("manhattan-end", "The Manhattan end. The way into the city is barricaded."),
  ]

  /// The stranger (M2). He waits unseen behind the car turned across the east roadway, steps
  /// into the lane as Miki comes within about 10 m, and after her "Friendly!" opens fire. His
  /// first shot is a deliberate miss. Miki can take cover behind the car to her left; the turned
  /// car covers him from her right. His reach, like her carbine's, is about what the camera shows
  /// ahead of her, so neither is hit from off screen.
  static let stranger = Level.Hostile(
    id: "stranger", name: "The stranger", hiddenAt: layout.marker(named: "stranger.hidden"),
    standAt: layout.marker(named: "stranger.stand"), hits: 2, windUp: 1.5, recovery: 1.4,
    range: 14, firstShotMisses: true, missLine: "He opened fire. Fire back, or take cover.",
    loot: Level.Loot(rounds: 6, medicalKits: 1))

  /// The first fight, as Miki nears the first tower. A retry starts just outside its area.
  static let strangerEncounter = Level.Encounter(
    beat: .stranger, start: .area(layout.area(named: "stranger")),
    retryAt: layout.marker(named: "stranger.retry"), hostiles: [stranger],
    cues: [
      (0, .reveal(stranger.id)),
      (0.6, .say(speaker: "Miki", line: "Friendly!")),
      (1.6, .engage(stranger.id)),
    ])

  /// Searching the stranger once he is down (M3). It takes the time the ambush's cues give it.
  static let searchStranger = Level.Interaction(
    id: .searchStranger, name: "Search",
    approach: layout.area(named: "search.stranger"), result: "Miki searches the stranger.",
    repeated: "Nothing more on him.", early: "Not while he's standing.")

  /// The man who runs at Miki from behind the van while she searches (M3).
  static let attacker = Level.Hostile(
    id: "attacker", name: "The attacker", hiddenAt: layout.marker(named: "attacker.hidden"),
    standAt: layout.marker(named: "attacker.stand"), hits: 1, attack: .charge(speed: 5))

  /// The ambush (M3), a short scene that plays the same way every time: the search begins it
  /// and holds Miki still. The attacker steps out from behind the van and runs at her; she
  /// finishes the search; Tom appears and drops the attacker before he reaches her. They turn to
  /// each other, and the exchange that follows ends with Tom joining.
  static let ambush = Level.Encounter(
    beat: .ambush, start: .action(.searchStranger), retryAt: nil, hostiles: [attacker],
    cues: [
      (0.2, .reveal(attacker.id)),
      (0.6, .engage(attacker.id)),
      (1.5, .loot(stranger.id)),
      (2.0, .appear(.tom)),
      (2.6, .shot(by: .tom, at: attacker.id)),
      (3.0, .face(.miki, .tom)),
      (3.4, .talk(.metTom)),
    ],
    holdsParty: true)

  /// Laura (M4) lies hurt beside a car just past the gap in the divider. Once Tom has joined, the
  /// party's approach finds her: she calls out, the camera leans towards her so that she shows
  /// clear of the HUD, Miki answers, and Help is offered at her side.
  static let lauraFound = Level.Encounter(
    beat: .lauraFound, start: .area(layout.area(named: "laura.found")), retryAt: nil,
    hostiles: [],
    cues: [
      (0.3, .say(speaker: "A woman", line: "Please. Over here.")),
      (2.4, .say(speaker: "Miki", line: "Hold on. We're coming.")),
    ],
    focus: layout.marker(named: "spawn.laura"))

  /// Helping Laura uses the medical kit from the stranger's body. Whoever leads can help.
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
  /// and a short exchange closes the slice.
  static let arrival = Level.Encounter(
    beat: .arrived, start: .area(layout.area(named: "manhattan-end")), retryAt: nil,
    hostiles: [], cues: [(0.5, .talk(.arrival))], holdsParty: true)

  static let level = Level(
    id: "brooklyn-bridge", ground: layout.ground, boxes: layout.boxes, pieces: layout.pieces,
    // What the player sees, exported by Blender from the layout file and the palette.
    scene: "BrooklynBridge", points: points,
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
      (.lauraFound, "Help the woman between the cars."),
      (.withLaura, "Cross to Manhattan together."),
      (.arrived, "Manhattan, together."),
    ],
    lookAround: "Manhattan is ahead, across the bridge.",
    restartNote: "Restart begins a new run at the Brooklyn end.")

  /// A landmark from the layout, with what it is called and what a look shows.
  private static func point(_ id: String, _ name: String, _ observation: String)
    -> Level.PointOfInterest
  {
    let landmark = layout.landmark(named: id)
    return Level.PointOfInterest(
      id: id, name: name, position: landmark.position, size: landmark.size,
      observation: observation)
  }

  /// A trigger area from the layout, with the line it shows.
  private static func trigger(_ id: String, _ line: String) -> Level.Trigger {
    Level.Trigger(id: id, area: layout.area(named: id), line: line)
  }
}
