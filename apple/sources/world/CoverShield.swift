import RealityKit
import simd

/// The active character's directional cover cue (ADR 0009): a ground half-ring towards the
/// shelter, red whenever a shooter can see them. Both looks are made at load and reused.
@MainActor
final class CoverShield {
  let entity = Entity()
  private let protectedArc = Entity()
  private let exposedArc = Entity()
  private let inset: Float

  init(style: SceneStyle) {
    let radius: Float = 0.55
    let thickness: Float = 0.07
    // The curved front points at the shelter. Move the arc's centre behind the body so its
    // front stays outside the wall even at body contact and with camera-scaled markers.
    inset = max(0, (radius + thickness / 2 + 0.03) * style.markerScale - PartyBody.radius)
    entity.name = "cover.shield"
    entity.isEnabled = false
    protectedArc.name = "cover.protected"
    exposedArc.name = "cover.exposed"
    entity.addChild(protectedArc)
    entity.addChild(exposedArc)

    let segments = 9
    let step = Float.pi / Float(segments)
    let length = 2 * radius * sin(step / 2) + 0.012
    for (arc, material) in [(protectedArc, style.signal), (exposedArc, style.threat)] {
      for index in 0..<segments {
        let angle = -.pi / 2 + step * (Float(index) + 0.5)
        let segment = style.block(
          size: [length, 0.018, thickness], at: [radius * sin(angle), 0, -radius * cos(angle)],
          material: material)
        segment.orientation = simd_quatf(angle: -angle, axis: [0, 1, 0])
        arc.addChild(segment)
      }
    }
    entity.scale = [style.markerScale, 1, style.markerScale]
  }

  /// The shield's curved front faces the block, with its centre behind the body's anchor to
  /// keep it visible at wall contact. Its colour comes from the incoming-damage sight check;
  /// this renderer decides no cover rules.
  func show(
    at point: SIMD2<Float>, toward direction: SIMD2<Float>, exposed: Bool, floor: Float = 0
  ) {
    guard simd_length_squared(direction) > 0.000001 else {
      hide()
      return
    }
    let centre = point - simd_normalize(direction) * inset
    entity.position = [centre.x, floor + 0.028, centre.y]
    entity.orientation = simd_quatf(angle: Movement.yaw(towards: direction), axis: [0, 1, 0])
    protectedArc.isEnabled = !exposed
    exposedArc.isEnabled = exposed
    entity.isEnabled = true
  }

  func hide() {
    entity.isEnabled = false
  }
}
