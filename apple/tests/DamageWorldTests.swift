import Testing
import simd

@testable import Lauder

@MainActor
struct DamageWorldTests {
  @Test
  func oneNativeHitFeedsNumbersAndTheSameUndrainedAudioBatch() throws {
    let world = try damagedWorld()
    let batch = world.takeCombatEvents()
    let hits = batch.compactMap { event -> DamageHit? in
      if case .damaged(let hit) = event { return hit }
      return nil
    }
    try #require(!hits.isEmpty)
    #expect(
      world.damageFeedback.labels.reduce(0) { $0 + $1.amount } == hits.reduce(0) { $0 + $1.amount })
    #expect(batch.contains { if case .fired = $0 { true } else { false } })
    #expect(world.takeCombatEvents().isEmpty)
    #expect(world.guardHealth == GuardStrategy.maximumHealth - hits.reduce(0) { $0 + $1.amount })
  }

  @Test
  func pauseFreezesNumbersAndRestartClearsTheOldEnemy() throws {
    let world = try damagedWorld()
    pressPause(world)
    try #require(world.isPaused)
    let labels = world.damageFeedback.labels
    let health = world.guardHealth
    for _ in 0..<60 {
      world.update(with: .neutral, sampledIn: .paused, deltaTime: 1 / 60)
    }
    #expect(world.damageFeedback.labels == labels && world.guardHealth == health)
    world.restart()
    #expect(world.damageFeedback.labels.isEmpty && world.guardHealth == nil)
  }

  @Test
  func backgroundingClearsNumbersAndReturningCannotReplayThem() throws {
    let world = try damagedWorld()
    world.setApplicationActive(false)
    #expect(world.damageFeedback.labels.isEmpty)
    #expect(!world.takeCombatEvents().contains { if case .damaged = $0 { true } else { false } })
    world.setApplicationActive(true)
    for _ in 0..<6 {
      let raw = InputRules.Raw()
      let mode = world.session.mode
      world.update(
        with: world.controls.resolve(raw, mode: mode), sampledIn: mode, deltaTime: 1 / 60)
    }
    #expect(world.damageFeedback.labels.isEmpty)
  }

  private func damagedWorld() throws -> GameWorld {
    let world = GameWorld(level: BrooklynBridge.level)
    world.setApplicationActive(true)
    #expect(world.session.holdAll())
    walk(world, to: [6.5, 8])
    _ = world.takeCombatEvents()
    let robot = try #require(world.playtestSnapshot.robotPosition)
    try #require(
      run(world, upTo: 2, fire: true, aim: stick(world, towards: robot - position(world, .miki))) {
        !world.damageFeedback.labels.isEmpty
      })
    return world
  }
}
