import simd

@testable import Lauder

/// A test-only flat range for ordinary weapon practice, with no story or alternate scene.
enum TestRange {
  static let practice = Level(
    id: "practice-fixture",
    ground: .box("ground", at: [0, -0.15, 0], size: [40, 0.3, 40]),
    boxes: [.box("wall", at: [0, 1.5, -5], size: [16, 3, 1])],
    interactions: [], triggers: [], party: [.miki, .tom, .laura],
    spawns: [.miki: [0, 2], .tom: [-1, 3], .laura: [1, 3]], heading: [0, -1],
    cameraOffset: TestYard.cameraOffset, fieldOfView: 42,
    opening: "A range.", objective: "Test.", lookAround: "Snow.", restartNote: "Restart.")
}
