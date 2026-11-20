import Testing
import simd

@testable import Lauder

/// The camera's mapping between the screen and the ground, which touch orders use to mark the
/// ground under the finger (ADR 0003, phase S3).
struct CameraProjectionTests {
  /// The bridge's camera over a leader at mid-span.
  private static let camera = CameraProjection(
    eye: [-7, 10.95, -260.1], target: [-7, 0.95, -270], fieldOfView: 42, aspect: 2.16)

  @Test
  func theMiddleOfTheScreenLooksAtTheTarget() throws {
    let camera = Self.camera
    let direction = try #require(camera.direction(atScreen: [0.5, 0.5]))
    let wanted = simd_normalize(camera.target - camera.eye)
    #expect(simd_distance(simd_normalize(direction), wanted) < 0.0001)
    // The ground behind the target, on the same line from the camera.
    let ground = try #require(camera.ground(atScreen: [0.5, 0.5]))
    #expect(abs(ground.x + 7) < 0.001 && ground.y < -270)
  }

  @Test(arguments: [Float(1), 1.5, 2.16])
  func groundPointsComeBackFromWhereTheyShow(aspect: Float) throws {
    let camera = CameraProjection(
      eye: Self.camera.eye, target: Self.camera.target, fieldOfView: 42, aspect: aspect)
    for point: SIMD2<Float> in [[-7, -270], [-9.5, -277], [-3, -266], [-11, -284]] {
      let screen = try #require(camera.screen(ofGround: point))
      let back = try #require(camera.ground(atScreen: screen))
      #expect(simd_distance(back, point) < 0.001, "\(point) at \(screen)")
    }
  }

  @Test
  func rightAndDownOnTheScreenAreRightAndNearerOnTheGround() throws {
    let camera = Self.camera
    let middle = try #require(camera.ground(atScreen: [0.5, 0.5]))
    let right = try #require(camera.ground(atScreen: [0.8, 0.5]))
    let lower = try #require(camera.ground(atScreen: [0.5, 0.8]))
    #expect(right.x > middle.x, "the camera looks north, so screen right is east")
    #expect(lower.y > middle.y, "lower on the screen is nearer the camera, to the south")
  }

  @Test
  func aRayAboveTheHorizonMarksNothing() {
    let level = CameraProjection(eye: [0, 2, 0], target: [0, 2, -10], fieldOfView: 42, aspect: 2)
    #expect(level.ground(atScreen: [0.5, 0.1]) == nil)
    #expect(level.ground(atScreen: [0.5, 0.9]) != nil)
    #expect(level.ground(atScreen: [.nan, 0.5]) == nil)
  }

  @Test
  func aRayEntersABoxAtItsNearFace() throws {
    let camera = CameraProjection(eye: [0, 1, 10], target: [0, 1, 0], fieldOfView: 42, aspect: 2)
    let direction = try #require(camera.direction(atScreen: [0.5, 0.5]))
    let entry = try #require(
      camera.entry(along: direction, minimum: [-1, 0, -1], maximum: [1, 2, 1]))
    #expect(abs((camera.eye + direction * entry).z - 1) < 0.0001)
    #expect(camera.entry(along: direction, minimum: [3, 0, -1], maximum: [4, 2, 1]) == nil)
  }
}
