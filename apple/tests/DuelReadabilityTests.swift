import Testing
import simd

@testable import Lauder

struct DuelReadabilityTests {
  @Test func aFreshFreeSlashUsesTheFlickAndCommitsItsVisibleFacing() throws {
    var duel = DuelSimulation(heroPosition: [0, 1.4], enemyPosition: .zero)
    duel.step(.init(movement: [1, 0], attackPressed: true), deltaTime: DuelSimulation.fixedStep)
    let slash = try #require(duel.hero.action)
    #expect(slash.kind == .slash && slash.direction == [1, 0])
    #expect(simd_distance(Movement.facing(yaw: duel.hero.yaw), slash.direction) < 0.0001)
    let yaw = duel.hero.yaw
    advance(&duel, seconds: 0.4, command: .init(movement: [-1, 0], attackPressed: true))
    #expect(duel.hero.action?.direction == slash.direction)
    #expect(duel.hero.yaw == yaw && duel.hero.stamina == 76)
  }

  @Test func aBufferedFreeSlashKeepsItsRequestedAimAcrossLaterMovement() throws {
    var duel = DuelSimulation(heroPosition: [0, 1.4], enemyPosition: .zero)
    advance(&duel, seconds: 0.56, command: .init(attackPressed: true))
    duel.step(.init(movement: [1, 0], attackPressed: true), deltaTime: DuelSimulation.fixedStep)
    #expect(duel.hero.action?.direction == [0, -1], "the first slash still owns its recovery")
    advance(&duel, seconds: 0.14, command: .init(movement: [-1, 0]))
    let slash = try #require(duel.hero.action)
    #expect(slash.kind == .slash && slash.phase == .windup && slash.direction == [1, 0])
    #expect(simd_distance(Movement.facing(yaw: duel.hero.yaw), slash.direction) < 0.0001)
    #expect(duel.hero.stamina < 53)
  }

  @Test(arguments: [SIMD2<Float>.zero, [0.00001, 0], [.nan, .infinity]])
  func absentOrInvalidFreeAimUsesTheCurrentFacing(movement: SIMD2<Float>) throws {
    var duel = DuelSimulation(heroPosition: [0, 1.4], enemyPosition: .zero, heroYaw: 0.8)
    duel.step(.init(movement: movement, attackPressed: true), deltaTime: DuelSimulation.fixedStep)
    let slash = try #require(duel.hero.action)
    #expect(simd_distance(slash.direction, Movement.facing(yaw: 0.8)) < 0.0001)
  }

  @Test func aFocusedSlashStillFacesTheEnemyRatherThanTheTravelDirection() throws {
    var duel = DuelSimulation(heroPosition: [0, 1.4], enemyPosition: .zero)
    duel.step(.init(focusPressed: true), deltaTime: DuelSimulation.fixedStep)
    duel.step(.init(movement: [1, 0], attackPressed: true), deltaTime: DuelSimulation.fixedStep)
    let slash = try #require(duel.hero.action)
    let enemyDirection = simd_normalize(duel.enemy.position - duel.hero.position)
    #expect(simd_dot(slash.direction, enemyDirection) > 0.99)
    #expect(abs(slash.direction.x) < 0.1)
    #expect(simd_distance(slash.direction, Movement.facing(yaw: duel.hero.yaw)) < 0.0001)
  }

  @Test func anOpenApproachSeparatesTheFightersAcrossTheScreenBeforePreparation() throws {
    var duel = DuelSimulation()
    try waitForAttack(&duel, seconds: 4)
    let separation = duel.enemy.position - duel.hero.position
    #expect(abs(simd_dot(separation, DuelArena.screenRight)) > 1)
    #expect(abs(simd_dot(simd_normalize(separation), DuelArena.screenRight)) > 0.8)
    #expect(simd_length(separation) <= 1.9)
  }

  @Test func aBlockedNearerSideChoosesTheClearOtherSide() throws {
    // The left goal falls inside the expanded right pillar, but the right route is clear.
    var duel = DuelSimulation(heroPosition: [5, 0], enemyPosition: [3.8, -0.7])
    try waitForAttack(&duel, seconds: 3)
    #expect(duel.enemy.position.x > duel.hero.position.x)
    #expect(simd_dot(duel.enemy.position - duel.hero.position, DuelArena.screenRight) > 0.8)
    #expect(clear(duel.enemy.position))
  }

  @Test func aNearWallApproachKeepsItsFootprintInsideTheArena() throws {
    var duel = DuelSimulation(heroPosition: [0, -4.4], enemyPosition: [1.2, -3.6])
    try waitForAttack(&duel, seconds: 3)
    #expect(clear(duel.enemy.position))
    #expect(duel.enemy.position.y > -DuelArena.halfDepth + DuelArena.radius)
    #expect(simd_dot(duel.enemy.position - duel.hero.position, DuelArena.screenRight) < -0.8)
  }

  @Test func blockedLateralPathsFallBackToAnAttackWithoutCrossingTheHero() throws {
    let hero = SIMD2<Float>(0, 1.4)
    let enemy = hero - simd_normalize(SIMD2<Float>(1, 1)) * 0.8
    var duel = DuelSimulation(heroPosition: hero, enemyPosition: enemy)
    try waitForAttack(&duel, seconds: 1.3)
    #expect(simd_distance(duel.enemy.position, enemy) < 0.001)
    #expect(simd_distance(duel.hero.position, duel.enemy.position) >= DuelArena.radius * 2)
  }

  @Test func aLateralAttemptHasABoundedDeadlineRatherThanEndlessRepositioning() throws {
    let hero = SIMD2<Float>(0, 1.4)
    var duel = DuelSimulation(
      heroPosition: hero, enemyPosition: hero - simd_normalize(SIMD2<Float>(1, 1)) * 2.8)
    try waitForAttack(&duel, seconds: 1.35)
    #expect(duel.elapsed < 1.35)
    #expect(abs(simd_dot(duel.enemy.position - hero, DuelArena.screenRight)) < 1.1)
    #expect(clear(duel.enemy.position))
  }

  @Test func committedEnemyPreparationContactAndRecoveryNeverChaseOrTurn() throws {
    var duel = DuelSimulation()
    try waitForAttack(&duel, seconds: 4)
    let action = try #require(duel.enemy.action)
    let position = duel.enemy.position
    let yaw = duel.enemy.yaw
    var sawContact = false
    var sawRecovery = false
    while let current = duel.enemy.action {
      #expect(current.direction == action.direction)
      #expect(duel.enemy.position == position && duel.enemy.yaw == yaw)
      sawContact = sawContact || current.phase == .active
      sawRecovery = sawRecovery || current.phase == .recovery
      duel.step(.init(movement: [1, 0]), deltaTime: DuelSimulation.fixedStep)
    }
    #expect(sawContact && sawRecovery)
  }

  @Test func retreatBeyondTheLeashStillReturnsTheEnemyHomeWithoutAnAttack() {
    var duel = DuelSimulation(heroPosition: [0, 4.4], enemyPosition: [1, 0])
    advance(&duel, seconds: 3)
    #expect(duel.enemy.action == nil && duel.hero.health == DuelSimulation.heroMaxHealth)
    #expect(simd_distance(duel.enemy.position, DuelArena.enemySpawn) < 0.11)
    #expect(clear(duel.enemy.position))
  }

  private func waitForAttack(_ duel: inout DuelSimulation, seconds: Float) throws {
    let deadline = duel.elapsed + seconds
    while duel.enemy.action == nil, duel.elapsed < deadline {
      duel.step(.neutral, deltaTime: DuelSimulation.fixedStep)
      #expect(clear(duel.enemy.position))
      #expect(simd_distance(duel.hero.position, duel.enemy.position) >= DuelArena.radius * 2)
    }
    _ = try #require(duel.enemy.action, "the enemy must commit instead of circling indefinitely")
  }

  private func clear(_ point: SIMD2<Float>) -> Bool {
    PartyMotion(radius: DuelArena.radius, obstacles: DuelArena.obstacles)
      .canTraverse(from: point, to: point)
  }

  private func advance(
    _ duel: inout DuelSimulation, seconds: Float, command: DuelCommand = .neutral
  ) {
    var remaining = seconds
    var input = command
    while remaining > 0.000001 {
      let dt = min(remaining, DuelSimulation.fixedStep)
      duel.step(input, deltaTime: dt)
      remaining -= dt
      input.attackPressed = false
      input.dodgePressed = false
      input.focusPressed = false
    }
  }
}
