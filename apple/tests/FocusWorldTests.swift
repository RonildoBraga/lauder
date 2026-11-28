import Testing
import simd

@testable import Lauder

@MainActor
struct FocusWorldTests {
  @Test func aSubTickFocusPressWinsQueuedCombatAndTogglesOnlyOnce() {
    let world = firstEncounterWorld()
    world.update(raw: .init(), deltaTime: 0.001)
    world.update(raw: .init(controllerAttack: true), deltaTime: 0.001)
    world.update(raw: .init(controllerDodge: true, controllerFocus: true), deltaTime: 0.001)
    #expect(!world.simulation.isFocused)
    world.update(raw: .init(controllerFocus: true), deltaTime: 0.03)
    #expect(world.simulation.isFocused)
    #expect(world.simulation.hero.action == nil)
    #expect(world.simulation.hero.stamina == DuelSimulation.maxStamina)
  }

  @Test func pausePreservesSelectionButConsumesFocusPresses() {
    let world = firstEncounterWorld()
    world.update(raw: .init(), deltaTime: 1 / 60)
    world.update(raw: .init(controllerFocus: true), deltaTime: 1 / 60)
    #expect(world.simulation.isFocused)
    world.update(raw: .init(keyboardPause: true), deltaTime: 1 / 60)
    let view = world.projection(aspect: 2.16)
    world.update(raw: .init(controllerFocus: true), deltaTime: 1 / 60)
    #expect(world.controls.needsNeutralInput)
    world.update(raw: .init(), deltaTime: 1 / 60)
    world.update(raw: .init(controllerFocus: true), deltaTime: 1 / 60)
    #expect(world.isPaused && world.simulation.isFocused)
    #expect(world.projection(aspect: 2.16).eye == view.eye)
    world.update(raw: .init(), deltaTime: 1 / 60)
    world.update(raw: .init(keyboardPause: true), deltaTime: 1 / 60)
    world.update(raw: .init(controllerFocus: true), deltaTime: 1 / 60)
    #expect(world.simulation.isFocused && world.controls.needsNeutralInput)
    world.update(raw: .init(), deltaTime: 1 / 60)
    world.update(raw: .init(controllerFocus: true), deltaTime: 1 / 60)
    #expect(!world.simulation.isFocused)
  }

  @Test func sourceGenerationCannotReplayAnAcceptedSubTickFocus() {
    let world = firstEncounterWorld()
    world.controls.setActive(true)
    world.controls.useTouchControls()
    defer { world.controls.setActive(false) }
    let generation = world.controls.touchGeneration
    frame(world, dt: 0.001)
    world.controls.setTouchButton(.focus, isPressed: true, generation: generation)
    frame(world, dt: 0.001)
    #expect(!world.controls.needsNeutralInput && !world.simulation.isFocused)
    world.controls.setActive(false)
    world.controls.setActive(true)
    world.controls.useTouchControls()
    let fresh = world.controls.touchGeneration
    #expect(fresh > generation)
    world.controls.setTouchButton(.focus, isPressed: true, generation: generation)
    frame(world, dt: 0.02)
    #expect(!world.simulation.isFocused)
    world.controls.setTouchButton(.focus, isPressed: true, generation: fresh)
    frame(world, dt: 0.02)
    #expect(world.simulation.isFocused)
  }

  @Test func pauseDiscardsAQueuedFocusBeforeItsFirstSimulationTick() {
    let world = firstEncounterWorld()
    world.update(raw: .init(), deltaTime: 0.001)
    world.update(raw: .init(keyboardFocus: true), deltaTime: 0.001)
    #expect(!world.simulation.isFocused)
    world.update(raw: .init(keyboardPause: true), deltaTime: 0.001)
    #expect(world.isPaused)
    world.update(raw: .init(), deltaTime: 1 / 60)
    world.update(raw: .init(keyboardPause: true), deltaTime: 1 / 60)
    world.update(raw: .init(), deltaTime: 1 / 60)
    #expect(!world.isPaused && !world.simulation.isFocused)
    world.update(raw: .init(keyboardFocus: true), deltaTime: 1 / 60)
    #expect(world.simulation.isFocused)
  }

  @Test func retryClearsFocusAndItsMarkerAndWaitsForReleasedControls() throws {
    let world = firstEncounterWorld()
    let marker = try #require(world.root.findEntity(named: "duel.focus-ring"))
    #expect(!marker.isEnabled)
    world.update(raw: .init(), deltaTime: 1 / 60)
    world.update(raw: .init(controllerFocus: true), deltaTime: 1 / 60)
    #expect(world.simulation.isFocused && marker.isEnabled)
    world.retry()
    #expect(!world.simulation.isFocused && !marker.isEnabled)
    #expect(simd_distance(world.run.hero.position, DungeonLayout.heroSpawn) < 0.001)
    world.update(raw: .init(controllerFocus: true), deltaTime: 1 / 60)
    #expect(!world.simulation.isFocused && world.controls.needsNeutralInput)
    world.update(raw: .init(), deltaTime: 1 / 60)
    world.update(raw: .init(controllerFocus: true), deltaTime: 1 / 60)
    #expect(!world.simulation.isFocused, "the checkpoint cannot select a guard in another room")
  }

  @Test func focusDoesNotRotateMovementAxesAndTheLiveCameraFollowsItsActors() {
    let world = firstEncounterWorld()
    world.update(raw: .init(), deltaTime: 1 / 60)
    world.update(raw: .init(controllerFocus: true), deltaTime: 1 / 60)
    let before = world.projection(aspect: 2.16)
    let start = world.simulation.hero.position
    // The clear doorway avoids confusing camera axes with wall sliding.
    let away = SIMD2<Float>(1, 0)
    let stick = Movement.stick(towards: away, cameraOffset: WorldCamera.offset)
    for _ in 0..<30 { world.update(raw: .init(stick: stick), deltaTime: 1 / 60) }
    let travelled = world.simulation.hero.position - start
    #expect(simd_dot(simd_normalize(travelled), away) > 0.99)
    #expect(simd_length(travelled) > 1)
    let wanted = simd_normalize(world.simulation.enemy.position - world.simulation.hero.position)
    #expect(simd_dot(Movement.facing(yaw: world.simulation.hero.yaw), wanted) > 0.99)
    let after = world.projection(aspect: 2.16)
    #expect(simd_distance(before.target, after.target) > 0.1)
    #expect(simd_distance(after.eye - after.target, WorldCamera.offset) < 0.0001)
  }

  private func frame(_ world: GameWorld, dt: Float) {
    let mode = world.session.mode
    world.update(with: world.controls.sample(mode: mode), sampledIn: mode, deltaTime: dt)
  }
}
