import simd

@testable import Lauder

/// A small walled yard for the squad-movement tests: open ground with low walls and scattered
/// blocks, and a room entered only through a 1.8 m opening, where companions must fall into
/// single file. The bridge has no doorway that narrow. This is the geometry of the former Relay
/// House level, kept for these tests when the level was removed, with all three members from the
/// start and nothing to do.
enum TestYard {
  static let cameraOffset: SIMD3<Float> = [5.25, 10, 8.4]

  static let ground = Level.Box(name: "ground", position: [0, -0.15, 0], size: [28, 0.3, 20])

  /// The walls and blocks. Low walls keep the party in view from the elevated camera.
  static let boxes: [Level.Box] = [
    box("south-wall", [0, 0.45, 9.7], [28, 0.9, 0.6]),
    box("north-wall", [0, 0.45, -9.7], [28, 0.9, 0.6]),
    box("west-wall", [-13.7, 0.45, 0], [0.6, 0.9, 20]),
    box("east-wall", [13.7, 0.45, 0], [0.6, 0.9, 20]),
    box("shelter-back", [-9, 0.5, 0], [7, 1, 0.35]),
    box("shelter-side", [-12.3, 0.5, 2.5], [0.35, 1, 5]),
    box("wreck", [-1.5, 0.4, 1], [2.5, 0.8, 1.2]),
    box("fallen-panel", [1, 0.3, -2], [1.2, 0.6, 2.5]),
    // The room: its front is blocked, and its west wall leaves a 1.8 m opening around the corner.
    box("room-back", [7, 0.55, -7], [6.4, 1.1, 0.35]),
    box("room-east", [10, 0.55, -4], [0.35, 1.1, 6]),
    box("room-west-back", [4, 0.55, -6.2], [0.35, 1.1, 1.6]),
    box("room-west-front", [4, 0.55, -2.3], [0.35, 1.1, 2.6]),
    box("room-front-west", [5, 0.55, -1], [2, 1.1, 0.35]),
    box("room-front-east", [9, 0.55, -1], [2, 1.1, 0.35]),
    box("blocked-entrance", [7, 0.45, -0.7], [2.2, 0.9, 1]),
  ]

  /// Two blocks that can be looked at, which block movement too: one in the shelter and one in
  /// the room.
  static let points: [Level.PointOfInterest] = [
    Level.PointOfInterest(
      id: "yard.radio", name: "Radio", position: [-10, 0, 1.5], size: [0.8, 1, 0.6],
      observation: "A radio that can receive but cannot answer."),
    Level.PointOfInterest(
      id: "yard.housing", name: "Housing", position: [7, 0, -4.5], size: [0.5, 0.5, 0.5],
      observation: "An empty housing."),
  ]

  static let level = Level(
    id: "test-yard", ground: ground, boxes: boxes, points: points, interactions: [],
    triggers: [], party: [.miki, .laura, .tom],
    spawns: [.miki: [-8, 3], .laura: [-8, 3.8], .tom: [-8, 4.6]], heading: [0, -1],
    cameraOffset: cameraOffset, fieldOfView: 42, opening: "A walled yard.",
    objective: "Move together.", lookAround: "Low walls, and a room with one way in.",
    restartNote: "Restart.")

  static let obstacles = level.obstacles

  /// The start of the yard's open lane, between the wreck and the south wall: wide enough for
  /// Spread from end to end.
  static let laneStart: SIMD2<Float> = [-6, 6]

  /// Inside the room's walls.
  static func isInRoom(_ point: SIMD2<Float>) -> Bool {
    point.x > 4.2 && point.x < 9.8 && point.y > -6.8 && point.y < -1.2
  }

  private static func box(_ name: String, _ position: SIMD3<Float>, _ size: SIMD3<Float>)
    -> Level.Box
  {
    Level.Box(name: name, position: position, size: size)
  }
}
