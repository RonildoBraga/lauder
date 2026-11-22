import Testing
import simd

@testable import Lauder

/// Aiming assistance cannot override a real wall or the body's vertical extent.
@MainActor
struct BallisticsTests {
  @Test
  func aWallExactlyAtTheEndOfReachStillGetsTheImpact() {
    let wall = Level.Box(name: "limit", position: [0, 1.5, -0.5], size: [4, 3, 1])
    let ballistics = Ballistics(level: yard(boxes: [wall]))
    let shot = ballistics.trace(
      from: [0, 1.25, 5], direction: [0, 0, -1], range: 5, targets: [])
    #expect(shot.strike == .scenery)
    #expect(shot.end == [0, 1.25, 0])
  }

  @Test
  func invalidDirectionsCannotCreateANonfiniteTrace() {
    let ballistics = Ballistics(level: yard())
    let start: SIMD3<Float> = [0, 1.25, 5]
    for direction: SIMD3<Float> in [.zero, [.nan, 0, 0], [.infinity, 0, 0], [0, -.infinity, 0]] {
      let shot = ballistics.trace(from: start, direction: direction, range: 15, targets: [])
      #expect(shot.start == start && shot.end == start && shot.strike == .nothing)
    }
  }

  @Test
  func aTallBlockStillStopsAnElevatedShot() {
    let wall = Level.Box(name: "tall", position: [0, 2, 0], size: [4, 4, 1])
    let ballistics = Ballistics(level: yard(boxes: [wall]))
    let start: SIMD3<Float> = [0, 3.25, 7]
    let destination: SIMD3<Float> = [0, 1.25, -7]
    let shot = ballistics.trace(
      from: start, direction: destination - start, range: 20,
      targets: [.init(id: "behind", centre: destination)])
    #expect(shot.strike == .scenery)
    #expect(abs(shot.end.z - 0.5) < 0.001)
  }

  @Test(arguments: [Float(0.1), 2.5, 3.5])
  func aGroundPlaneCrossingCannotHitAboveOrBelowTheActualCylinder(height: Float) {
    let ballistics = Ballistics(level: yard())
    let shot = ballistics.trace(
      from: [0, height, 5], direction: [0, 0, -1], range: 15,
      targets: [.init(id: "body", centre: [0, 1.25, -5])])
    #expect(shot.strike == .nothing)
    #expect(shot.end.z == -10)
  }

  @Test
  func aShotCrossingTheBodyAtItsHeightUsesTheCircularRadius() {
    let ballistics = Ballistics(level: yard())
    let target = Ballistics.Target(id: "body", centre: [0, 1.25, -5])
    let hit = ballistics.trace(
      from: [0, 1.25, 5], direction: [0, 0, -1], range: 15, targets: [target])
    #expect(hit.strike == .body("body"))
    #expect(abs(hit.end.z - (-5 + target.radius)) < 0.001)
    let miss = ballistics.trace(
      from: [target.radius + 0.01, 1.25, 5], direction: [0, 0, -1], range: 15,
      targets: [target])
    #expect(miss.strike == .nothing)
  }

  private func yard(boxes: [Level.Box] = []) -> Level {
    Level(
      id: "ballistics-test", ground: TestYard.ground, boxes: boxes,
      interactions: [], triggers: [], party: [.miki],
      spawns: [.miki: .zero, .laura: [-1, 1], .tom: [1, 1]], heading: [0, -1],
      cameraOffset: [0, 10, 10], fieldOfView: 42, opening: "A yard.", objective: "Explore.",
      lookAround: "Ground.", restartNote: "Restart.")
  }
}
