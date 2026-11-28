import Testing

@testable import Lauder

@MainActor
struct DuelRecoveryTests {
  @Test
  func directRetryKeepsEveryRealTouchContactBehindTheNeutralGate() {
    let world = GameWorld()
    world.controls.setActive(true)
    world.controls.useTouchControls()
    defer { world.controls.setActive(false) }
    let generation = world.controls.touchGeneration
    frame(world)

    world.controls.setTouchStick(.zero, isTouching: true, generation: generation)
    world.controls.setTouchButton(.attack, isPressed: true, generation: generation)
    world.controls.setTouchButton(.guardAction, isPressed: true, generation: generation)
    frame(world)
    #expect(world.simulation.hero.guarding, "the real held guard reaches combat before Retry")
    #expect(world.simulation.elapsed > 0)

    // This is the same entry point as the outcome panel's native Retry button.
    world.retry()
    #expect(world.retries == 1 && world.controls.needsNeutralInput)
    for _ in 0..<3 { frame(world) }
    #expect(world.simulation.elapsed == 0 && world.simulation.hero.action == nil)

    world.controls.setTouchButton(.attack, isPressed: false, generation: generation)
    frame(world)
    #expect(world.controls.needsNeutralInput && world.simulation.elapsed == 0)
    world.controls.setTouchButton(.guardAction, isPressed: false, generation: generation)
    frame(world)
    #expect(
      world.controls.needsNeutralInput && world.simulation.elapsed == 0,
      "a centred stick still holds its own finger after every button lifts")

    world.controls.setTouchStick(.zero, isTouching: false, generation: generation)
    frame(world)
    #expect(!world.controls.needsNeutralInput)
    #expect(world.simulation.hero.action == nil && !world.simulation.hero.guarding)
    world.controls.setTouchButton(.attack, isPressed: true, generation: generation)
    frame(world)
    #expect(world.simulation.hero.action?.kind == .slash)
    #expect(world.simulation.hero.stamina == 76)
    #expect(world.simulation.hitsLanded == 0, "the fresh attack still has to prepare")
  }

  @Test
  func changedSourceGenerationDiscardsAnAcceptedSubTickPressBeforeItCanExecute() {
    let world = GameWorld()
    world.controls.setActive(true)
    world.controls.useTouchControls()
    defer { world.controls.setActive(false) }
    let oldGeneration = world.controls.touchGeneration
    frame(world, deltaTime: 0.001)
    world.controls.setTouchButton(.attack, isPressed: true, generation: oldGeneration)
    frame(world, deltaTime: 0.001)
    #expect(world.simulation.elapsed == 0 && world.simulation.hero.action == nil)
    #expect(!world.controls.needsNeutralInput, "the press was accepted, not rejected by a gate")

    // Exercise the controls owner's real cancellation/generation path without calling the
    // world's cancellation method: its common frame transaction must notice the changed source.
    world.controls.setActive(false)
    world.controls.setActive(true)
    world.controls.useTouchControls()
    let freshGeneration = world.controls.touchGeneration
    #expect(freshGeneration > oldGeneration)
    world.controls.setTouchButton(.attack, isPressed: true, generation: oldGeneration)
    frame(world, deltaTime: 0.001)
    frame(world, deltaTime: 0.02)
    #expect(!world.controls.needsNeutralInput)
    #expect(world.simulation.elapsed > 0)
    #expect(world.simulation.hero.action == nil)
    #expect(world.simulation.hero.stamina == DuelSimulation.maxStamina)

    world.controls.setTouchButton(.attack, isPressed: true, generation: freshGeneration)
    frame(world)
    #expect(world.simulation.hero.action?.kind == .slash)
    #expect(world.simulation.hero.stamina == 76)
  }

  private func frame(_ world: GameWorld, deltaTime: Float = 1 / 60) {
    let mode = world.session.mode
    let input = world.controls.sample(mode: mode)
    world.update(with: input, sampledIn: mode, deltaTime: deltaTime)
  }
}
