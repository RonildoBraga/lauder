import simd

/// The opening: a compressed, flat greybox of the Brooklyn Bridge (ADR 0004). Brooklyn is at +z
/// and Manhattan at -z. Two roadways run either side of the raised walkway's base, which has
/// collapsed at mid-span; a bus jammed across the east roadway sends the route through that gap.
/// Vehicles stand where the later scenes need them: cover before the first tower, a van beside
/// it, and a car on the west roadway near the gap.
///
/// Where everything stands is in `layout` (BrooklynBridgeLayout.swift), which Blender edits
/// (ADR 0005). This file adds the words: what each place is called and what it says.
enum BrooklynBridge {
  /// The deck runs from the Brooklyn end at +z to the Manhattan end at -z.
  static var deckLength: Float { layout.ground.size.z }
  static var deckWidth: Float { layout.ground.size.x }
  /// Where each tower's centre stands along the deck.
  static var brooklynTower: Float { layout.box(named: "brooklyn-tower-pier").position.z }
  static var manhattanTower: Float { layout.box(named: "manhattan-tower-pier").position.z }
  static var towerThickness: Float { layout.box(named: "brooklyn-tower-pier").size.z }
  /// The arches are tall enough for the camera to pass through them behind the party.
  static var archHeight: Float { layout.box(named: "brooklyn-tower-pier").size.y }
  /// The camera keeps the accepted height and distance but looks straight along the deck, so
  /// pushing up walks towards Manhattan.
  static let cameraOffset: SIMD3<Float> = [0, 10, 9.9]

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
    range: 14, firstShotMisses: true, missLine: "He opened fire. Fire back, or take cover.")

  /// The first fight, as Miki nears the first tower. A retry starts just outside its area.
  static let strangerEncounter = Level.Encounter(
    beat: .stranger, area: layout.area(named: "stranger"),
    retryAt: layout.marker(named: "stranger.retry"), hostiles: [stranger],
    cues: [
      (0, .reveal(stranger.id)),
      (0.6, .say(speaker: "Miki", line: "Friendly!")),
      (1.6, .engage(stranger.id)),
    ])

  static let level = Level(
    id: .brooklynBridge, ground: layout.ground, boxes: layout.boxes, points: points,
    interactions: [], triggers: triggers, encounters: [strangerEncounter], startingAmmo: 12,
    passage: nil,
    // Miki crosses alone. Tom and Laura wait, hidden, where their scenes will be.
    party: [.miki],
    spawns: [
      .miki: layout.marker(named: "spawn.miki"), .tom: layout.marker(named: "spawn.tom"),
      .laura: layout.marker(named: "spawn.laura"),
    ],
    heading: [0, -1], cameraOffset: cameraOffset,
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
