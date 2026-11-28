import Testing
import simd

@testable import Lauder

@MainActor
struct WorldLifecycleTests {
  @Test
  func pauseFreezesExistingActionsAndConsumesCombatInputsUntilReleased() {
    let world = GameWorld()
    world.update(raw: .init(), deltaTime: 1 / 60)
    world.update(raw: .init(controllerAttack: true), deltaTime: 1 / 60)
    let action = world.simulation.hero.action
    let time = world.simulation.elapsed
    world.update(raw: .init(keyboardPause: true), deltaTime: 1 / 60)
    #expect(world.isPaused)
    for _ in 0..<30 {
      world.update(
        raw: .init(controllerAttack: true, controllerDodge: true, right: true),
        deltaTime: 1 / 60)
    }
    #expect(world.simulation.elapsed == time && world.simulation.hero.action == action)
    world.update(raw: .init(), deltaTime: 1 / 60)
    world.update(raw: .init(keyboardPause: true), deltaTime: 1 / 60)
    #expect(!world.isPaused)
    #expect(world.controls.needsNeutralInput)
    let resumeTime = world.simulation.elapsed
    world.update(raw: .init(controllerAttack: true), deltaTime: 1 / 60)
    #expect(world.simulation.elapsed == resumeTime)
    world.update(raw: .init(), deltaTime: 1 / 60)
    #expect(world.simulation.elapsed > resumeTime)
    #expect(
      world.simulation.hero.action?.kind == .slash, "the owed action resumes, not a new dodge")
  }

  @Test
  func activityAndStopDiscardSubTickIntentsWithoutResettingTheDuel() {
    let world = GameWorld()
    world.update(raw: .init(), deltaTime: 0.001)
    world.update(raw: .init(controllerAttack: true), deltaTime: 0.001)
    world.setActive(true)
    world.setActive(false)
    let time = world.simulation.elapsed
    world.step(deltaTime: 1)
    #expect(world.simulation.elapsed == time)
    world.update(raw: .init(), deltaTime: 1 / 60)
    #expect(
      world.simulation.hero.action == nil, "an untaken press cannot survive lifecycle cancellation")
    world.stop()
    world.step(deltaTime: 1)
    #expect(!world.isActive)
    #expect(world.retries == 0)
  }

  @Test
  func enteringPauseBeforeTheFirstTickCannotBankAnAttack() {
    let world = GameWorld()
    world.update(raw: .init(), deltaTime: 0.001)
    world.update(raw: .init(controllerAttack: true), deltaTime: 0.001)
    world.update(raw: .init(keyboardPause: true), deltaTime: 1 / 60)
    world.update(raw: .init(), deltaTime: 1 / 60)
    world.update(raw: .init(keyboardPause: true), deltaTime: 1 / 60)
    world.update(raw: .init(), deltaTime: 1 / 60)
    #expect(world.simulation.hero.action == nil)
    #expect(world.simulation.hero.stamina == DuelSimulation.maxStamina)
  }
}
