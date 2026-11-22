import RealityKit
import simd

/// Amber square corners and a shrinking overhead bar identify an arriving test actor. Unlike
/// a grenade's circular blast warning, this marker describes no damage radius or aim direction.
@MainActor
final class ArenaArrivalMarker {
  let entity = Entity()
  private let countdown = Entity()
  private let duration: Float

  init(slot: ArenaWaves.Slot, duration: Float, terrain: Terrain, style: SceneStyle) {
    self.duration = duration
    entity.name = "arena.arrival.\(slot.id)"
    entity.isEnabled = false
    entity.position = [slot.point.x, terrain.height(at: slot.point) + 0.035, slot.point.y]
    let reach: Float = 0.8
    for x: Float in [-1, 1] {
      for z: Float in [-1, 1] {
        entity.addChild(
          style.block(
            size: [0.5, 0.025, 0.07], at: [x * (reach - 0.25), 0, z * reach],
            material: style.warm))
        entity.addChild(
          style.block(
            size: [0.07, 0.025, 0.5], at: [x * reach, 0, z * (reach - 0.25)],
            material: style.warm))
      }
    }
    countdown.name = "arena.arrival.countdown"
    countdown.position.y = PartyBody.height + 0.5
    countdown.addChild(style.block(size: [1.2, 0.1, 0.1], at: .zero, material: style.warm))
    entity.addChild(countdown)
  }

  func show(remaining: Float?) {
    guard let remaining, remaining > 0 else {
      entity.isEnabled = false
      return
    }
    entity.isEnabled = true
    countdown.scale.x = max(0.04, min(1, remaining / duration))
  }
}
