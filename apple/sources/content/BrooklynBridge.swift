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
      (3.0, .face(.tom)),
      (3.4, .talk(.metTom)),
    ],
    holdsLeader: true)

  static let level = Level(
    id: "brooklyn-bridge", ground: layout.ground, boxes: layout.boxes, pieces: layout.pieces,
    points: points,
    interactions: [searchStranger], triggers: triggers, encounters: [strangerEncounter, ambush],
    startingAmmo: 12,
    // Miki crosses alone. Tom and Laura wait, hidden, where their scenes will be.
    party: [.miki],
    spawns: [
      .miki: layout.marker(named: "spawn.miki"), .tom: layout.marker(named: "spawn.tom"),
      .laura: layout.marker(named: "spawn.laura"),
    ],
    heading: [0, -1], cameraOffset: cameraOffset, fieldOfView: layout.camera.fieldOfView,
    lights: layout.lights,
    opening: "The Brooklyn end of the bridge. Manhattan is on the far side.",
    objective: "Cross the bridge to Manhattan.",
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
