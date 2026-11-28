import Testing
import simd

@testable import Lauder

/// The camera's mapping between the screen and the ground, which touch orders use to mark the
/// ground under the finger (ADR 0003, phase S3).
struct CameraProjectionTests {
  /// The bridge's earlier camera, 14 m from its target with a 42° lens, the one the world
  /// markers were made for (SceneStyle.markerCamera), over a leader at mid-span.
  private static let camera = CameraProjection(
    eye: [-7, 10.95, -260.1], target: [-7, 0.95, -270], fieldOfView: 42, aspect: 2.16)

  @Test
  func theMiddleOfTheScreenLooksAtTheTarget() throws {
    let camera = Self.camera
    let ray = try #require(camera.ray(atScreen: [0.5, 0.5]))
    let wanted = simd_normalize(camera.target - camera.eye)
    #expect(simd_distance(simd_normalize(ray.direction), wanted) < 0.0001)
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
    let ray = try #require(camera.ray(atScreen: [0.5, 0.5]))
    let entry = try #require(
      camera.entry(along: ray, minimum: [-1, 0, -1], maximum: [1, 2, 1]))
    #expect(abs((ray.origin + ray.direction * entry).z - 1) < 0.0001)
    #expect(camera.entry(along: ray, minimum: [3, 0, -1], maximum: [4, 2, 1]) == nil)
  }

  @Test
  func elevatedImpactsProjectAtTheirActualHeightAndBackOntoTheSameViewingRay() throws {
    let camera = Self.camera
    let point: SIMD3<Float> = [-6, 2.5, -270]
    let screen = try #require(camera.screen(ofWorld: point))
    let ground = try #require(camera.screen(ofGround: [point.x, point.z]))
    #expect(screen.y < ground.y - 0.01)
    let ray = try #require(camera.ray(atScreen: screen))
    #expect(
      simd_distance(simd_normalize(ray.direction), simd_normalize(point - ray.origin)) < 0.0001)
    let middle = try #require(camera.screen(ofWorld: camera.target))
    #expect(simd_distance(middle, [0.5, 0.5]) < 0.0001)
  }

  @Test
  func damageProjectionRejectsInvalidAndBehindCameraPointsWithoutPinningOffscreenHits() throws {
    let camera = Self.camera
    #expect(camera.screen(ofWorld: camera.eye + (camera.eye - camera.target)) == nil)
    #expect(camera.screen(ofWorld: [.nan, 1, 2]) == nil)
    let far = try #require(camera.screen(ofWorld: [100, 0, -270]))
    #expect(far.x > 1, "the overlay hides an offscreen hit instead of pinning it over the controls")
    let degenerate = CameraProjection(eye: .zero, target: .zero, fieldOfView: 42, aspect: 2)
    #expect(degenerate.screen(ofWorld: [1, 1, 1]) == nil)
  }

  @Test(arguments: [Float(1), 1.5, 2.16])
  func parallelGroundProjectionRoundTripsWithShiftedRayOrigins(aspect: Float) throws {
    let camera = CameraProjection(
      eye: [18, 15.85, 18], target: [0, 0.85, 0], fieldOfView: 24, aspect: aspect,
      orthographicHeight: 15)
    let centre = try #require(camera.ray(atScreen: [0.5, 0.5]))
    for point: SIMD2<Float> in [[0, 0], [4, 2], [-5, -3], [-2, 4]] {
      let screen = try #require(camera.screen(ofGround: point))
      let back = try #require(camera.ground(atScreen: screen))
      let ray = try #require(camera.ray(atScreen: screen))
      #expect(simd_distance(back, point) < 0.0001)
      #expect(simd_distance(ray.direction, centre.direction) < 0.00001)
      #expect(simd_distance(ray.origin, centre.origin) > 0.01)
    }
  }

  @Test
  func parallelBoxEntryUsesTheSelectedRayOrigin() throws {
    let camera = CameraProjection(
      eye: [0, 1, 10], target: [0, 1, 0], fieldOfView: 24, aspect: 2,
      orthographicHeight: 10)
    let ray = try #require(camera.ray(atScreen: [0.75, 0.5]))
    #expect(simd_distance(ray.origin, [5, 1, 10]) < 0.0001)
    let distance = try #require(
      camera.entry(along: ray, minimum: [4, 0, -1], maximum: [6, 2, 1]))
    #expect(simd_distance(ray.origin + ray.direction * distance, [5, 1, 1]) < 0.0001)
    #expect(camera.entry(along: ray, minimum: [-1, 0, -1], maximum: [1, 2, 1]) == nil)
    #expect(camera.entry(along: ray, minimum: [4, 0, 9], maximum: [6, 2, 11]) == nil)
    #expect(
      camera.entry(
        along: .init(origin: [.nan, 0, 1], direction: [0, 0, -1]),
        minimum: [-1, 0, -1], maximum: [1, 2, 1]) == nil)
  }

  @Test
  func parallelProjectionRejectsInvalidSpansAndDegenerateRays() {
    for height: Float in [0, -1, .nan, .infinity] {
      let camera = CameraProjection(
        eye: [0, 3, 10], target: .zero, fieldOfView: 24, aspect: 2,
        orthographicHeight: height)
      #expect(camera.ray(atScreen: [0.5, 0.5]) == nil)
      #expect(camera.ground(atScreen: [0.5, 0.5]) == nil)
      #expect(camera.screen(ofWorld: .zero) == nil)
    }
    let camera = CameraProjection(
      eye: [0, 0, 10], target: .zero, fieldOfView: 24, aspect: 2, orthographicHeight: 10)
    #expect(camera.ground(atScreen: [0.5, 0.5]) == nil)
    #expect(camera.ray(atScreen: [.nan, 0.5]) == nil)
    #expect(camera.screen(ofWorld: [0, 0, 11]) == nil)
  }
}
