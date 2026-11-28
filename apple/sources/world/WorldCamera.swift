import RealityKit
import simd

/// One fixed orientation keeps movement and committed attacks readable across the compact arena.
@MainActor
final class WorldCamera {
  static let offset = SIMD3<Float>(0, 13, 11)
  static let fieldOfView: Float = 44

  private let entity = PerspectiveCamera()
  private let rig = CameraRig(
    offset: WorldCamera.offset, fieldOfView: WorldCamera.fieldOfView, over: .zero)

  init() {
    entity.name = "duel.camera"
    entity.camera.fieldOfViewInDegrees = Self.fieldOfView
    entity.look(at: rig.target, from: rig.eye, relativeTo: nil)
  }

  func attach(to root: Entity) { root.addChild(entity) }
  func projection(aspect: Float) -> CameraProjection { rig.projection(aspect: aspect) }
}
