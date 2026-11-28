import Testing

@testable import Lauder

@MainActor
struct ReadabilityWorldTests {
  @Test func pauseHidesTheWarningAndResumeRetainsTheCommittedAttack() throws {
    let world = GameWorld()
    let warning = try #require(world.root.findEntity(named: "duel.attack-warning"))
    world.update(raw: .init(), deltaTime: 1 / 60)
    for _ in 0..<360 {
      world.update(raw: .init(controllerGuard: true), deltaTime: 1 / 60)
      if world.simulation.enemy.action?.phase == .windup { break }
    }
    let accepted = try #require(world.simulation.enemy.action)
    #expect(accepted.phase == .windup && warning.isEnabled)
    let elapsed = world.simulation.elapsed
    world.update(raw: .init(keyboardPause: true), deltaTime: 1 / 60)
    #expect(world.isPaused && !warning.isEnabled)
    world.update(raw: .init(controllerAttack: true, controllerFocus: true), deltaTime: 0.1)
    #expect(world.simulation.elapsed == elapsed)
    #expect(world.simulation.enemy.action == accepted)
    world.update(raw: .init(), deltaTime: 1 / 60)
    world.update(raw: .init(keyboardPause: true), deltaTime: 1 / 60)
    world.update(raw: .init(), deltaTime: 1 / 60)
    #expect(!world.isPaused && warning.isEnabled)
    #expect(world.simulation.enemy.action?.direction == accepted.direction)
    #expect(world.simulation.hero.action == nil && !world.simulation.isFocused)
    world.retry()
    #expect(!warning.isEnabled && world.simulation.enemy.action == nil)
  }
}
