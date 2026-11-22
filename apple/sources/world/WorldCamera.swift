import RealityKit
import simd

/// Owns the camera entity, its motion and landmark fading. The world supplies the party and
/// encounter's current camera intent; this component owns how that intent is presented.
@MainActor
final class WorldCamera {
  private let entity = PerspectiveCamera()
  private var rig: CameraRig
  private var landmarks = LandmarkFade()

  init(level: Level, over point: SIMD2<Float>) {
    rig = CameraRig(offset: level.cameraOffset, fieldOfView: level.fieldOfView, over: point)
    entity.name = "camera"
    entity.camera.fieldOfViewInDegrees = level.fieldOfView
  }

  var target: SIMD3<Float> { rig.target }
  var eye: SIMD3<Float> { rig.eye }
  var lens: Float { rig.lens }

  /// Capture the authored static look before actors are added, then prepare its ghost materials.
  func attach(to root: Entity) {
    landmarks = LandmarkFade(look: root)
    root.addChild(entity)
    landmarks.prepare(before: entity)
  }

  func switchLeader() { rig.switchLeader() }
  func reset(over point: SIMD2<Float>) { rig.reset(over: point) }

  func projection(aspect: Float) -> CameraProjection { rig.projection(aspect: aspect) }

  func update(
    over leader: SIMD2<Float>, lean: SIMD2<Float>, close: Bool, party: [SIMD3<Float>],
    deltaTime: Float
  ) {
    rig.update(over: leader, lean: lean, close: close, deltaTime: deltaTime)
    entity.look(at: rig.target, from: rig.eye, relativeTo: nil)
    if abs(entity.camera.fieldOfViewInDegrees - rig.lens) > 0.001 {
      entity.camera.fieldOfViewInDegrees = rig.lens
    }
    landmarks.update(eye: rig.eye, seeing: party + [rig.target], deltaTime: deltaTime)
  }
}
