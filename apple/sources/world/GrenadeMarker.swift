import RealityKit
import simd

/// A reusable, full-size blast warning. The outer boundary stays at the actual damage radius;
/// a smaller ring contracts with the fuse, and amber alternates with red near detonation.
@MainActor
final class GrenadeMarker {
  let entity = Entity()
  private let warning = Entity()
  private let urgent = Entity()
  private let countdown = Entity()
  private let projectile: ModelEntity

  init(style: SceneStyle) {
    entity.name = "grenade.marker"
    entity.isEnabled = false
    warning.name = "grenade.warning"
    urgent.name = "grenade.urgent"
    countdown.name = "grenade.countdown"
    projectile = ModelEntity(
      mesh: .generateSphere(radius: Grenade.landingHeight), materials: [style.gear])
    projectile.name = "grenade.projectile"
    entity.addChild(warning)
    entity.addChild(urgent)
    entity.addChild(countdown)
    entity.addChild(projectile)

    let segments = 24
    let step = 2 * Float.pi / Float(segments)
    let thickness: Float = 0.08
    // Outer corners lie on the radius rather than extending beyond it. Unlike cosmetic
    // markers, this ring never uses the camera's markerScale, which would misstate damage.
    let radius = Grenade.radius * cos(step / 2) - thickness / 2
    let length = 2 * Grenade.radius * sin(step / 2)
    for (ring, material) in [
      (warning, style.warm), (urgent, style.threat), (countdown, style.warm),
    ] {
      for index in 0..<segments {
        let angle = step * (Float(index) + 0.5)
        let segment = style.block(
          size: [length, 0.018, thickness],
          at: [radius * sin(angle), 0.035, radius * cos(angle)], material: material)
        segment.orientation = simd_quatf(angle: angle, axis: [0, 1, 0])
        ring.addChild(segment)
      }
    }
    countdown.position.y = 0.01
  }

  func show(_ grenade: Grenade?) {
    guard let grenade, grenade.remaining > 0 else {
      entity.isEnabled = false
      return
    }
    entity.position = [grenade.position.x, 0, grenade.position.y]
    entity.isEnabled = true
    let elapsed = Grenade.fuse - grenade.remaining
    let flashesRed = grenade.remaining <= 1 && Int(elapsed * 8) % 2 == 0
    warning.isEnabled = !flashesRed
    urgent.isEnabled = flashesRed
    let progress = max(0.04, grenade.remaining / Grenade.fuse)
    countdown.scale = [progress, 1, progress]
    projectile.position = grenade.projectilePosition - entity.position
  }
}
