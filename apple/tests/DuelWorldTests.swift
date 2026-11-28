import Testing
import simd

@testable import Lauder

@MainActor
struct DuelWorldTests {
  @Test
  func aPressSmallerThanOneTickIsConsumedExactlyOnceAtTheNextTick() {
    let world = GameWorld()
    world.update(raw: .init(), deltaTime: 0.001)
    world.update(raw: .init(controllerAttack: true), deltaTime: 0.001)
    #expect(world.simulation.hero.action == nil)
    world.update(raw: .init(), deltaTime: 0.02)
    #expect(world.simulation.hero.action?.kind == .slash)
    #expect(world.simulation.hero.stamina == 76)
    #expect(world.simulation.hitsLanded == 0, "wind-up cannot become an immediate hit")
  }

  @Test
  func fixedStepsKeepOrdinaryFrameRatesEquivalent() {
    let sixty = GameWorld()
    let thirty = GameWorld()
    for world in [sixty, thirty] { world.update(raw: .init(), deltaTime: 0.0001) }
    for _ in 0..<30 { sixty.update(raw: .init(right: true), deltaTime: 1 / 60) }
    for _ in 0..<15 { thirty.update(raw: .init(right: true), deltaTime: 1 / 30) }
    #expect(simd_distance(sixty.simulation.hero.position, thirty.simulation.hero.position) < 0.001)
    #expect(abs(sixty.simulation.elapsed - thirty.simulation.elapsed) < 0.001)
  }

  @Test
  func retryRestoresRulesAndRequiresReleasedInputBeforeAnyFreshAction() {
    let world = GameWorld()
    world.update(raw: .init(), deltaTime: 1 / 60)
    world.update(raw: .init(controllerAttack: true), deltaTime: 1 / 60)
    #expect(world.simulation.hero.action?.kind == .slash)
    world.retry()
    #expect(world.retries == 1 && world.session.mode == .exploring)
    #expect(world.simulation.hero.position == DungeonLayout.heroSpawn)
    #expect(world.run.enemy == nil && world.run.visibleEnemy == nil)
    #expect(world.run.activeEncounter == nil && world.run.clearedEncounters.isEmpty)
    #expect(world.simulation.hero.stamina == DuelSimulation.maxStamina)
    #expect(world.simulation.hero.action == nil && world.simulation.enemy.action == nil)
    for _ in 0..<12 {
      world.update(raw: .init(controllerAttack: true, right: true), deltaTime: 1 / 60)
    }
    #expect(world.simulation.elapsed == 0)
    #expect(world.controls.needsNeutralInput)
    world.update(raw: .init(), deltaTime: 1 / 60)
    world.update(raw: .init(controllerAttack: true), deltaTime: 1 / 60)
    #expect(world.simulation.hero.action?.kind == .slash)
  }
}
