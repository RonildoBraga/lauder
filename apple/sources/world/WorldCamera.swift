import Foundation
import RealityKit
import simd

/// A fixed diagonal view keeps its orientation while following the hero or focused pair.
@MainActor
final class WorldCamera {
  static let pitchDegrees: Float = {
    #if DEBUG
      let requested = UserDefaults.standard.float(forKey: "LauderCameraPitch")
      if [Float(30.5), 35, 40].contains(requested) { return requested }
    #endif
    return 35
  }()
  static let offset = offset(forPitch: pitchDegrees)
  static let fieldOfView: Float = 24

  static func offset(forPitch pitch: Float) -> SIMD3<Float> {
    // Calibrated through CameraProjection at target height 0.85m and vertical FOV 24°:
    // a centred 1.85m figure fills 10.104% of the viewport at every pitch. The 40°
    // distance (33.1m) also retains the opposite-corner pair inside the same lens.
    switch pitch {
    case 30.5: [22.659590, 18.876242, 22.659590]
    case 40: [17.929450, 21.276270, 17.929450]
    default: [20.489737, 20.289818, 20.489737]
    }
  }

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
