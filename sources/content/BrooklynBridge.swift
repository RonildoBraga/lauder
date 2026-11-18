import simd

/// The opening: a compressed, flat greybox of the Brooklyn Bridge (ADR 0004). Brooklyn is at +z
/// and Manhattan at -z. Two roadways run either side of the raised walkway's base, which has
/// collapsed at mid-span; a bus jammed across the east roadway sends the route through that gap.
/// Vehicles stand where the later scenes need them: cover before the first tower, a van beside
/// it, and a car on the west roadway near the gap.
enum BrooklynBridge {
  /// The deck runs from z = +125 at the Brooklyn end to -125 at the Manhattan end.
  static let deckLength: Float = 250
  static let deckWidth: Float = 24
  /// Where each tower's centre stands along the deck.
  static let brooklynTower: Float = 20
  static let manhattanTower: Float = -80
  static let towerThickness: Float = 10
  /// The arches are tall enough for the camera to pass through them behind the party.
  static let archHeight: Float = 14
  /// The camera keeps the accepted height and distance but looks straight along the deck, so
  /// pushing up walks towards Manhattan.
  static let cameraOffset: SIMD3<Float> = [0, 10, 9.9]

  static let ground = Level.Box(
    name: "deck", position: [0, -0.15, 0], size: [deckWidth, 0.3, deckLength], surface: .asphalt)

  static let structure: [Level.Box] = [
    Level.Box(
      name: "railing-west", position: [-11.8, 0.55, 0], size: [0.4, 1.1, deckLength],
      surface: .steel),
    Level.Box(
      name: "railing-east", position: [11.8, 0.55, 0], size: [0.4, 1.1, deckLength],
      surface: .steel),
    Level.Box(
      name: "brooklyn-barricade", position: [0, 0.6, 123.6], size: [23.2, 1.2, 0.8],
      surface: .hazard),
    // The raised walkway's base, from z = 108 to -24 and from -36 to -110. The roadways meet
    // at both ends and through the collapsed section between.
    Level.Box(
      name: "divider-south", position: [0, 0.5, 42], size: [5, 1, 132], surface: .steel),
    Level.Box(
      name: "divider-north", position: [0, 0.5, -73], size: [5, 1, 74], surface: .steel),
  ]

  /// Each tower: a central pier between the arches and two outer piers that narrow the deck.
  static let towers: [Level.Box] = [("brooklyn", brooklynTower), ("manhattan", manhattanTower)]
    .flatMap { name, z in
      [
        Level.Box(
          name: "\(name)-tower-pier", position: [0, archHeight / 2, z],
          size: [6, archHeight, towerThickness], surface: .granite),
        Level.Box(
          name: "\(name)-tower-west", position: [-12.6, archHeight / 2, z],
          size: [3.2, archHeight, towerThickness], surface: .granite),
        Level.Box(
          name: "\(name)-tower-east", position: [12.6, archHeight / 2, z],
          size: [3.2, archHeight, towerThickness], surface: .granite),
      ]
    }

  static let vehicles: [Level.Box] = [
    // East roadway, from the Brooklyn end.
    car("car-a1", x: 9.6, z: 100),
    car("car-a2", x: 4.4, z: 92),
    car("car-a4", x: 9.8, z: 80),
    car("car-b1", x: 4.4, z: 62),
    car("car-b2", x: 9.8, z: 56),
    car("car-b3", x: 4.6, z: 48),
    car("car-b4", x: 9.4, z: 44, across: true),
    Level.Box(name: "van-b", position: [9.6, 1.1, 30], size: [2.2, 2.2, 5.5], surface: .vehicle),
    car("car-d1", x: 9.8, z: 2),
    car("car-d2", x: 4.4, z: -8),
    Level.Box(
      name: "truck-d", position: [7.6, 1.6, -50], size: [2.5, 3.2, 8], surface: .vehicle),
    car("car-d5", x: 4.6, z: -60),
    // West roadway.
    car("car-a3", x: -9.6, z: 96),
    car("car-b5", x: -4.4, z: 58),
    car("car-b6", x: -9.8, z: 40),
    car("car-c1", x: -4.6, z: 6),
    car("car-d3", x: -9.6, z: -40),
    car("car-d4", x: -4.4, z: -56),
    car("car-e1", x: -9.8, z: -95),
    car("car-e2", x: -4.4, z: -102),
  ]

  static let debris: [Level.Box] = [
    Level.Box(
      name: "debris-a1", position: [5, 0.4, 75], size: [1.4, 0.8, 1.2], surface: .concrete),
    Level.Box(
      name: "debris-a2", position: [-5, 0.4, 84], size: [1.4, 0.8, 1.2], surface: .concrete),
    Level.Box(
      name: "debris-d1", position: [-9.4, 0.4, -64], size: [1.4, 0.8, 1.2], surface: .concrete),
  ]

  static let points: [Level.PointOfInterest] = [
    Level.PointOfInterest(
      id: "bridge.booth", name: "Checkpoint booth", position: [0, 0, 113], size: [2.4, 2.6, 2.4],
      observation: "A checkpoint booth, its window shattered. Nobody has staffed it in years."),
    Level.PointOfInterest(
      id: "bridge.bus", name: "Bus", position: [7.05, 0, -42], size: [9.3, 3, 2.6],
      observation: "A bus jammed across the lanes. Beside it, the divider has given way."),
    Level.PointOfInterest(
      id: "bridge.manhattan-barricade", name: "Barricade", position: [0, 0, -123.6],
      size: [23.2, 1.6, 0.8], observation: "Cars and wire close off the Manhattan end."),
  ]

  /// Each shows its line the first time the leader walks in, once per run.
  static let triggers: [Level.Trigger] = [
    trigger("cars-ahead", z: 66...72, "Cars stand where they stopped, doors still open."),
    trigger("first-tower", z: 26...32, "The first tower. Its arches still stand."),
    trigger("mid-span", z: -12 ... -6, "Mid-span. The wind is stronger out here."),
    trigger(
      "blocked-lanes", x: 3...12, z: -32 ... -26,
      "The lanes ahead are blocked. The divider has given way here."),
    trigger("second-tower", z: -72 ... -66, "The second tower. Manhattan is close now."),
    trigger(
      "manhattan-end", z: -112 ... -106, "The Manhattan end. The way into the city is barricaded."),
  ]

  static let level = Level(
    id: .brooklynBridge, ground: ground, boxes: structure + towers + vehicles + debris,
    points: points, interactions: [], triggers: triggers, passage: nil,
    // Miki crosses alone. Tom and Laura wait, hidden, where their scenes will be.
    party: [.miki],
    spawns: [.miki: [6.5, 116], .tom: [4.6, 12.5], .laura: [-7.6, -38]],
    heading: [0, -1], cameraOffset: cameraOffset,
    opening: "The Brooklyn end of the bridge. Manhattan is on the far side.",
    objective: "Cross the bridge to Manhattan.",
    lookAround: "Manhattan is ahead, across the bridge.",
    restartNote: "Restart begins a new run at the Brooklyn end.")

  /// A car parked along its lane, or turned across it.
  private static func car(_ name: String, x: Float, z: Float, across: Bool = false) -> Level.Box {
    Level.Box(
      name: name, position: [x, 0.75, z], size: across ? [4, 1.5, 2] : [2, 1.5, 4.6],
      surface: .vehicle)
  }

  private static func trigger(
    _ id: String, x: ClosedRange<Float> = -12...12, z: ClosedRange<Float>, _ line: String
  ) -> Level.Trigger {
    Level.Trigger(
      id: id,
      area: PartyMotion.Box(
        minimum: [x.lowerBound, z.lowerBound], maximum: [x.upperBound, z.upperBound]),
      line: line)
  }
}
