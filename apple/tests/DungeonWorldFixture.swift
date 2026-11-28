import Testing
import simd

@testable import Lauder

/// Reach the real room with ordinary shared input; lifecycle tests need an engaged opponent.
@MainActor
func firstEncounterWorld() -> GameWorld {
  let world = GameWorld()
  world.update(raw: .init(), deltaTime: 1 / 60)
  for target in [SIMD2<Float>(0, 7), [0, 5.2], [3.2, 5.2], [3.2, 1.2], [0, 1.2]] {
    var frames = 0
    while simd_distance(world.run.hero.position, target) > 0.08 && frames < 900 {
      let direction = target - world.run.hero.position
      let stick = Movement.stick(towards: direction, cameraOffset: WorldCamera.offset)
      world.update(raw: .init(stick: stick), deltaTime: 1 / 60)
      frames += 1
    }
    #expect(simd_distance(world.run.hero.position, target) < 0.08)
  }
  world.update(raw: .init(), deltaTime: 1 / 60)
  #expect(world.run.activeEncounter == 0)
  return world
}
