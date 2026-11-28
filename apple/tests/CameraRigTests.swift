import Testing
import simd

@testable import Lauder

@MainActor
struct CameraRigTests {
  @Test
  func theFixedDuelViewProjectsBothSpawnedActorsAndTheirFeet() throws {
    let rig = CameraRig(
      offset: WorldCamera.offset, fieldOfView: WorldCamera.fieldOfView, over: .zero)
    let view = rig.projection(aspect: 19.5 / 9)
    for point in [DuelArena.heroSpawn, DuelArena.enemySpawn] {
      let feet = try #require(view.screen(ofGround: point))
      let head = try #require(view.screen(ofWorld: [point.x, 1.85, point.y]))
      #expect(feet.x > 0.1 && feet.x < 0.9 && feet.y > 0.1 && feet.y < 0.9)
      #expect(head.x > 0.1 && head.x < 0.9 && head.y > 0.1 && head.y < 0.9)
      #expect(head.y < feet.y)
    }
    #expect(rig.eye == rig.target + WorldCamera.offset)
  }

  @Test
  func projectionAndCameraRelativeMovementShareTheSameFixedOrientation() throws {
    let rig = CameraRig(
      offset: WorldCamera.offset, fieldOfView: WorldCamera.fieldOfView, over: .zero)
    let view = rig.projection(aspect: 2)
    let centre = try #require(view.screen(ofGround: .zero))
    let forward = Movement.direction(for: [0, 1], cameraOffset: rig.offset)
    let moved = try #require(view.screen(ofGround: [forward.x, forward.z]))
    #expect(moved.y < centre.y)
    #expect(abs(moved.x - centre.x) < 0.0001)
  }
}
