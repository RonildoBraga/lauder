import RealityKit
import simd

/// A low diagonal view keeps its orientation while following the hero or focused pair.
@MainActor
final class WorldCamera {
  static let offset = SIMD3<Float>(18, 15, 18)
  static let fieldOfView: Float = 24

  private let entity = PerspectiveCamera()
  private var rig = CameraRig(
    offset: WorldCamera.offset, fieldOfView: WorldCamera.fieldOfView, over: DuelArena.heroSpawn)

  init() {
    entity.name = "duel.camera"
    entity.camera.fieldOfViewInDegrees = Self.fieldOfView
    entity.camera.fieldOfViewOrientation = .vertical
    apply()
  }

  func attach(to root: Entity) { root.addChild(entity) }
  func projection(aspect: Float) -> CameraProjection { rig.projection(aspect: aspect) }

  func update(hero: SIMD2<Float>, enemy: SIMD2<Float>, isFocused: Bool, deltaTime: Float) {
    rig.update(hero: hero, enemy: enemy, isFocused: isFocused, deltaTime: deltaTime)
    apply()
  }

  func reset(hero: SIMD2<Float>, enemy: SIMD2<Float>, isFocused: Bool) {
    rig.reset(hero: hero, enemy: enemy, isFocused: isFocused)
    apply()
  }

  private func apply() {
    entity.look(at: rig.target, from: rig.eye, relativeTo: nil)
  }
}
