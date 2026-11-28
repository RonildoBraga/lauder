import Testing
import simd

@testable import Lauder

struct DungeonRunTests {
  @Test func aSlowCallRetainsATransientRoomEntryAndConsumesFocusOnlyOnce() throws {
    var slow = DungeonRun()
    try approachFirstRoom(&slow, enter: false)
    try walk(&slow, to: [1.7, 1.2])
    #expect(slow.activeEncounter == nil)
    var fixed = slow
    let command = DuelCommand(
      movement: simd_normalize(SIMD2<Float>(-1, 1)), focusPressed: true)
    slow.step(command, deltaTime: 0.25)
    quarterSecond(&fixed, command: command)
    #expect(!DungeonLayout.encounters[0].activation.contains(slow.hero.position))
    #expect(slow.activeEncounter == 0 && fixed.activeEncounter == 0)
    #expect(
      !slow.isFocused && !fixed.isFocused, "the pre-engagement Focus press cannot replay on entry")
    #expect(simd_distance(slow.hero.position, fixed.hero.position) < 0.0001)
    #expect(abs(slow.simulation.elapsed - fixed.simulation.elapsed) < 0.0001)
    #expect(slow.takeEvents() == fixed.takeEvents())

    try walk(&slow, to: DungeonLayout.firstEntry)
    fixed = slow
    slow.step(.init(focusPressed: true), deltaTime: 0.25)
    quarterSecond(&fixed, command: .init(focusPressed: true))
    #expect(slow.isFocused && fixed.isFocused, "one slow call supplies one fresh selection edge")
  }

  @Test func aSlowCallHealsATransientAlcoveCrossingExactlyAsFixedTicksDo() throws {
    var slow = DungeonRun()
    try approachFirstRoom(&slow)
    try receiveOneHit(&slow)
    try defeatActiveEnemy(&slow)
    advance(&slow, seconds: 0.7)
    try walk(&slow, to: [-4, -1.8])
    try walk(&slow, to: [-9.5, -1.8])
    try walk(&slow, to: [-9.5, 0.3])
    #expect(!slow.healingUsed && slow.hero.health == 60)
    _ = slow.takeEvents()
    var fixed = slow
    let command = DuelCommand(movement: simd_normalize(SIMD2<Float>(1, -1)))
    slow.step(command, deltaTime: 0.25)
    quarterSecond(&fixed, command: command)
    #expect(!DungeonLayout.healingArea.contains(slow.hero.position))
    #expect(slow.healingUsed && fixed.healingUsed && slow.hero.health == 100)
    #expect(slow.hero.health == fixed.hero.health)
    #expect(simd_distance(slow.hero.position, fixed.hero.position) < 0.0001)
    #expect(slow.takeEvents() == [.healed(40)] && fixed.takeEvents() == [.healed(40)])
  }

  @Test func aSlowCallStopsAtTheSameRealExitCrossingAsFixedTicks() throws {
    var slow = DungeonRun()
    try approachFirstRoom(&slow)
    try defeatActiveEnemy(&slow)
    advance(&slow, seconds: 0.7)
    try walk(&slow, to: [-4, -1.8])
    try walk(&slow, to: [-10.5, -1.8])
    try walk(&slow, to: DungeonLayout.secondEntry)
    try defeatActiveEnemy(&slow)
    advance(&slow, seconds: 0.7)
    try walk(&slow, to: [-16, -3])
    try walk(&slow, to: [-19.9, -3.8])
    #expect(slow.outcome == .fighting)
    _ = slow.takeEvents()
    var fixed = slow
    let command = DuelCommand(movement: simd_normalize(SIMD2<Float>(-1, -1)))
    slow.step(command, deltaTime: 0.25)
    quarterSecond(&fixed, command: command)
    #expect(slow.outcome == .won && fixed.outcome == .won)
    #expect(simd_distance(slow.hero.position, fixed.hero.position) < 0.0001)
    #expect(abs(slow.simulation.elapsed - fixed.simulation.elapsed) < 0.0001)
    #expect(slow.takeEvents() == [.finished(.won)] && fixed.takeEvents() == [.finished(.won)])
  }

  @Test func authoredBoundariesKeepTraversableMovementOnTheSharedFloor() {
    for open in [false, true] {
      let collision = PartyMotion(
        radius: DuelArena.radius, obstacles: DungeonLayout.obstacles(shortcutOpen: open))
      for floor in DungeonLayout.floors {
        for x in stride(from: floor.minimum.x + 0.5, to: floor.maximum.x, by: 0.75) {
          for z in stride(from: floor.minimum.y + 0.5, to: floor.maximum.y, by: 0.75) {
            let start = SIMD2<Float>(x, z)
            guard collision.canTraverse(from: start, to: start) else { continue }
            for delta: SIMD2<Float> in [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, -1]] {
              let end = collision.resolve(start: start, delta: delta)
              #expect(
                DungeonLayout.floors.contains { $0.contains(end) },
                "no wall gap may lead into the void")
            }
          }
        }
      }
    }
  }

  @Test func theBentApproachUsesRealMovementAndActivatesOnlyTheFirstRoom() throws {
    var run = DungeonRun()
    #expect(run.hero.position == DungeonLayout.heroSpawn)
    #expect(run.enemy == nil && run.activeEncounter == nil && !run.isFocused)
    run.step(.init(attackPressed: true, focusPressed: true), deltaTime: 1 / 60)
    #expect(!run.isFocused && run.hero.action == nil)
    for point: SIMD2<Float> in [[0, 7], [0, 5.2], [3.2, 5.2], [3.2, 1.2]] {
      try walk(&run, to: point)
      #expect(run.activeEncounter == nil)
    }
    try walk(&run, to: DungeonLayout.firstEntry)
    #expect(run.activeEncounter == 0 && run.enemy != nil)
    #expect(run.clearedEncounters.isEmpty && run.outcome == .fighting)
  }

  @Test func corridorWallsStopStraightCutsAndDoNotExposeHiddenGuards() {
    var run = DungeonRun()
    for _ in 0..<480 { run.step(.init(movement: [0, -1]), deltaTime: 1 / 120) }
    #expect(run.hero.position.y >= 4 + DuelArena.radius)
    #expect(run.activeEncounter == nil && run.enemy == nil && run.visibleEnemy == nil)
    run.step(.init(focusPressed: true), deltaTime: 1 / 120)
    #expect(!run.isFocused)
  }

  @Test func aVisibleUnengagedGuardActivatesBeforeItCanBeHit() throws {
    var run = DungeonRun()
    try approachFirstRoom(&run, enter: false)
    let visible = try #require(run.visibleEnemy)
    #expect(run.enemy == nil && run.activeEncounter == nil)
    #expect(simd_distance(run.hero.position, visible.position) > 2.18)
    run.step(.init(focusPressed: true), deltaTime: 1 / 120)
    #expect(!run.isFocused)
    try walk(&run, to: DungeonLayout.firstEntry)
    run.step(.init(focusPressed: true), deltaTime: 1 / 120)
    #expect(run.isFocused)
  }

  @Test func clearingARoomPreservesHeroResourcesAndTelemetryInsteadOfEndingTheRun() throws {
    var run = DungeonRun()
    try approachFirstRoom(&run)
    try receiveOneHit(&run)
    try defeatActiveEnemy(&run)
    let health = run.hero.health
    let contacts = run.simulation.hitsLanded
    #expect(health == 60 && contacts == 7)
    #expect(run.clearedEncounters == [0] && run.activeEncounter == nil)
    #expect(run.outcome == .fighting && !run.isFocused && run.enemy == nil)
    #expect(run.hero.action != nil, "the winning swing still owes its own recovery")
    advance(&run, seconds: 0.7)
    try walk(&run, to: [-4, -1.8])
    try walk(&run, to: [-10.5, -1.8])
    try walk(&run, to: DungeonLayout.secondEntry)
    #expect(run.activeEncounter == 1 && run.hero.health == health)
    #expect(run.simulation.hitsLanded == contacts && run.simulation.hitsTaken == 1)
    #expect(run.enemy?.health == DuelSimulation.enemyMaxHealth)
    #expect(!run.healingUsed)
  }

  @Test func recoveryWaitsAtFullHealthThenHealsOnceWithoutOverhealing() throws {
    var run = DungeonRun()
    try approachFirstRoom(&run)
    try defeatActiveEnemy(&run)
    advance(&run, seconds: 0.7)
    try walk(&run, to: [-4, -1.8])
    try walk(&run, to: [-8.5, -1.8])
    try walk(&run, to: DungeonLayout.healingPosition)
    #expect(run.hero.health == 100 && !run.healingUsed)

    var damaged = DungeonRun()
    try approachFirstRoom(&damaged)
    try receiveOneHit(&damaged)
    try defeatActiveEnemy(&damaged)
    advance(&damaged, seconds: 0.7)
    try walk(&damaged, to: [-4, -1.8])
    try walk(&damaged, to: [-8.5, -1.8])
    _ = damaged.takeEvents()
    try walk(&damaged, to: DungeonLayout.healingPosition)
    #expect(damaged.hero.health == 100 && damaged.healingUsed)
    #expect(damaged.takeEvents().filter { $0 == .healed(40) }.count == 1)
    advance(&damaged, seconds: 1)
    #expect(damaged.takeEvents().isEmpty && damaged.hero.health == 100)
  }

  @Test func theShortcutOpensFromTheFarSideAndDeathRetryRetainsOnlyThatDiscovery() throws {
    var run = DungeonRun()
    try walk(&run, to: [0, 7])
    for _ in 0..<120 { run.step(.init(movement: [-1, 0]), deltaTime: 1 / 120) }
    #expect(!run.shortcutOpen && run.hero.position.x > -1.5 + DuelArena.radius)
    try walk(&run, to: [0, 7])
    try approachFirstRoom(&run)
    try defeatActiveEnemy(&run)
    advance(&run, seconds: 0.7)
    try walk(&run, to: [-4, -1.8])
    try walk(&run, to: [-10.5, -1.8])
    try walk(&run, to: DungeonLayout.secondEntry)
    try walk(&run, to: [-14.5, 3.5])
    try walk(&run, to: [-14.5, 7])
    try walk(&run, to: [-3.2, 7])
    #expect(run.shortcutOpen)
    try walk(&run, to: [0, 7])
    #expect(
      run.hero.position.x > -0.1, "opening changes the actual collision, not only the gate mesh")
    try walk(&run, to: [-3.2, 7])
    try walk(&run, to: [-14.5, 7])
    try walk(&run, to: [-14.5, 3.5])
    try walk(&run, to: [-14.5, -0.5])
    for _ in 0..<2400 where run.outcome == .fighting {
      run.step(.neutral, deltaTime: 1 / 120)
    }
    #expect(run.outcome == .lost)
    run.retry()
    #expect(run.shortcutOpen && run.clearedEncounters.isEmpty && !run.healingUsed)
    #expect(run.hero.position == DungeonLayout.heroSpawn && run.hero.health == 100)
    #expect(run.simulation.hitsLanded == 0 && run.activeEncounter == nil)
    run.restart()
    #expect(!run.shortcutOpen && run.hero.position == DungeonLayout.heroSpawn)
  }

  @Test func twoVictoriesStillRequireTheRealExitAndAFullRestartClearsTheRoute() throws {
    var run = DungeonRun()
    try approachFirstRoom(&run)
    try defeatActiveEnemy(&run)
    advance(&run, seconds: 0.7)
    try walk(&run, to: [-4, -1.8])
    try walk(&run, to: [-10.5, -1.8])
    try walk(&run, to: DungeonLayout.secondEntry)
    try defeatActiveEnemy(&run)
    #expect(run.clearedEncounters == [0, 1] && run.outcome == .fighting)
    #expect(run.simulation.hitsLanded == 14)
    advance(&run, seconds: 0.7)
    try walk(&run, to: [-16, -3])
    try walk(&run, to: DungeonLayout.exitPosition)
    #expect(run.outcome == .won && !run.isFocused)
    let position = run.hero.position
    run.step(.init(movement: [1, 0], attackPressed: true), deltaTime: 0.2)
    #expect(run.hero.position == position && run.hero.action == nil)
    run.restart()
    #expect(run.outcome == .fighting && run.clearedEncounters.isEmpty && !run.healingUsed)
  }

  @Test func localEncounterHomeAndExplorationNeverReuseTheOldArenaLeash() {
    var simulation = DuelSimulation(
      heroPosition: [-14.5, -3], enemyPosition: [-14.5, -5], obstacles: [],
      enemyHome: [-14.5, -5], enemyLeash: 3)
    for _ in 0..<180 { simulation.step(.init(guardHeld: true), deltaTime: 1 / 120) }
    #expect(simulation.enemy.action != nil, "a remote room engages around its own home")
    var exploration = DuelSimulation(
      heroPosition: [20, 20], enemyEnabled: false, endsOnEnemyDefeat: false)
    for _ in 0..<120 {
      exploration.step(.init(movement: [1, 0], focusPressed: true), deltaTime: 1 / 120)
    }
    #expect(exploration.hero.position.x > 22.7 && !exploration.isFocused)
    #expect(exploration.enemy.action == nil && exploration.hitsTaken == 0)
  }

  private func approachFirstRoom(_ run: inout DungeonRun, enter: Bool = true) throws {
    for point: SIMD2<Float> in [[0, 7], [0, 5.2], [3.2, 5.2], [3.2, 1.2]] {
      try walk(&run, to: point)
    }
    if enter { try walk(&run, to: DungeonLayout.firstEntry) }
  }

  private func walk(_ run: inout DungeonRun, to target: SIMD2<Float>) throws {
    for _ in 0..<2400 {
      let offset = target - run.hero.position
      if simd_length(offset) < 0.04 { return }
      run.step(.init(movement: simd_normalize(offset)), deltaTime: 1 / 120)
      #expect(run.outcome == .fighting || run.outcome == .won)
      if run.outcome == .won, DungeonLayout.exitArea.contains(target) { return }
    }
    #expect(
      simd_distance(run.hero.position, target) < 0.04, "the authored route must be traversable")
    try #require(simd_distance(run.hero.position, target) < 0.04)
  }

  private func receiveOneHit(_ run: inout DungeonRun) throws {
    for _ in 0..<1200 where run.simulation.hitsTaken == 0 {
      run.step(.neutral, deltaTime: 1 / 120)
    }
    try #require(run.hero.health == 60)
  }

  private func defeatActiveEnemy(_ run: inout DungeonRun) throws {
    try #require(run.activeEncounter != nil)
    run.step(.init(focusPressed: !run.isFocused), deltaTime: 1 / 120)
    var retreating = false
    for tick in 0..<7200 {
      guard run.activeEncounter != nil else { return }
      let offset = run.simulation.enemy.position - run.hero.position
      var command = DuelCommand()
      if run.hero.stamina < 35 { retreating = true }
      if run.hero.stamina >= 80 { retreating = false }
      if retreating, run.simulation.enemy.action?.phase != .active {
        command.movement = -simd_normalize(offset)
      } else if let action = run.simulation.enemy.action,
        action.phase == .active || (action.phase == .windup && action.phaseProgress > 0.55)
      {
        command.guardHeld = true
      } else if let action = run.simulation.enemy.action, action.phase == .recovery,
        action.duration - action.elapsed > 0.4, run.hero.action == nil, simd_length(offset) <= 2.1
      {
        command.attackPressed = tick.isMultiple(of: 2)
      } else if simd_length(offset) > 1.8 {
        command.movement = simd_normalize(offset)
      }
      if !run.isFocused { command.focusPressed = true }
      run.step(command, deltaTime: 1 / 120)
      if run.outcome == .lost { break }
    }
    try #require(run.activeEncounter == nil && run.outcome == .fighting)
  }

  private func advance(_ run: inout DungeonRun, seconds: Float) {
    for _ in 0..<Int(seconds * 120) { run.step(.neutral, deltaTime: 1 / 120) }
  }

  private func quarterSecond(_ run: inout DungeonRun, command: DuelCommand) {
    for tick in 0..<30 {
      var input = command
      if tick > 0 {
        input.attackPressed = false
        input.dodgePressed = false
        input.focusPressed = false
      }
      run.step(input, deltaTime: DuelSimulation.fixedStep)
    }
  }
}
