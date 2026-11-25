import simd

@testable import Lauder

/// A test-only flat range for ordinary weapon practice, with no story or alternate scene.
enum TestRange {
  static let practice = Level(
    id: "practice-fixture",
    ground: .box("ground", at: [0, -0.15, 0], size: [40, 0.3, 40]),
    boxes: [.box("wall", at: [0, 1.5, -5], size: [16, 3, 1])],
    triggers: [], party: [.miki, .tom, .laura],
    spawns: [.miki: [0, 2], .tom: [-1, 3], .laura: [1, 3]], heading: [0, -1],
    cameraOffset: TestYard.cameraOffset, fieldOfView: 42,
    opening: "A range.", objective: "Test.", lookAround: "Snow.", restartNote: "Restart.")

  /// The same range with Miki alone at the start, for the rules that wait until others join:
  /// formations and orders need two companions.
  static let mikiAlone = Level(
    id: "alone-fixture",
    ground: .box("ground", at: [0, -0.15, 0], size: [40, 0.3, 40]),
    boxes: [], triggers: [], party: [.miki],
    spawns: [.miki: [0, 2], .tom: [-1, 3], .laura: [1, 3]], heading: [0, -1],
    cameraOffset: TestYard.cameraOffset, fieldOfView: 42,
    opening: "A range.", objective: "Test.", lookAround: "Snow.", restartNote: "Restart.")
}
