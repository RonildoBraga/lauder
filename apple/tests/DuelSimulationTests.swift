import Testing
import simd

@testable import Lauder

struct DuelSimulationTests {
  @Test func slashHasPreparationThenOneContactAndRecovery() {
    var duel = nearby()
    advance(&duel, seconds: 0.1, command: .init(attackPressed: true))
    #expect(duel.hero.stamina == 76)
    #expect(duel.hero.action?.phase == .windup)
    #expect(duel.enemy.health == DuelSimulation.enemyMaxHealth)
    advance(&duel, seconds: 0.17)
    #expect(duel.hero.action?.phase == .active)
    #expect(duel.enemy.health == DuelSimulation.enemyMaxHealth - 24)
    #expect(duel.hitsLanded == 1)
    advance(&duel, seconds: 0.25)
    #expect(duel.hero.action?.phase == .recovery)
    #expect(duel.enemy.health == DuelSimulation.enemyMaxHealth - 24)
    advance(&duel, seconds: 0.2)
    #expect(duel.hero.action == nil)
    #expect(duel.hitsLanded == 1)
  }

  @Test func facingAndDistanceMatterWithoutMandatoryWeakpoints() {
    var backwards = nearby(yaw: .pi)
    advance(&backwards, seconds: 0.4, command: .init(attackPressed: true))
    #expect(backwards.hitsLanded == 0)
    var far = DuelSimulation(heroPosition: [0, 4], enemyPosition: [0, -2])
    advance(&far, seconds: 0.4, command: .init(attackPressed: true))
    #expect(far.hitsLanded == 0)
    var front = nearby()
    advance(&front, seconds: 0.4, command: .init(attackPressed: true))
    #expect(front.hitsLanded == 1)
    #expect(front.enemy.health < DuelSimulation.enemyMaxHealth)
  }

  @Test func anActiveAttackCannotTurnOrBeReplacedByAnotherAttack() {
    var duel = nearby()
    advance(&duel, seconds: 0.23, command: .init(attackPressed: true))
    let facing = duel.hero.yaw
    let position = duel.hero.position
    duel.step(
      .init(movement: [1, 0], attackPressed: true, guardHeld: true, dodgePressed: true),
      deltaTime: DuelSimulation.fixedStep)
    #expect(duel.hero.action?.kind == .slash)
    #expect(duel.hero.yaw == facing)
    #expect(duel.hero.position == position)
    #expect(duel.hero.stamina == 76)
  }

  @Test func lateBufferAcceptsOneActionButEarlyPressDoesNotQueueACombo() {
    var early = nearby()
    advance(&early, seconds: 0.1, command: .init(attackPressed: true))
    advance(&early, seconds: 0.65, command: .init(attackPressed: true))
    #expect(early.hero.action == nil)
    var late = nearby()
    advance(&late, seconds: 0.56, command: .init(attackPressed: true))
    duelPress(&late, attack: true)
    advance(&late, seconds: 0.13)
    #expect(late.hero.action?.kind == .slash)
    #expect(late.hero.action?.phase == .windup)
    #expect(late.hero.stamina <= 52.5)
  }

  @Test func interruptionClearsBufferedActionWithoutErasingRecovery() {
    var duel = nearby()
    advance(&duel, seconds: 0.56, command: .init(attackPressed: true))
    duelPress(&duel, attack: true)
    let action = duel.hero.action
    duel.interrupt()
    #expect(duel.hero.action == action)
    #expect(duel.takeEvents().isEmpty)
    advance(&duel, seconds: 0.15)
    #expect(duel.hero.action == nil)
    #expect(duel.hitsLanded == 1)
  }

  @Test(arguments: [Float(0.525), 0.533, 0.54, 0.55])
  func theWholeLateBufferWindowSurvivesItsHandoff(seconds: Float) {
    var duel = nearby()
    advance(&duel, seconds: seconds, command: .init(attackPressed: true))
    duelPress(&duel, attack: true)
    advance(&duel, seconds: 0.71 - seconds, command: .init(movement: [1, 0]))
    #expect(duel.hero.action?.kind == .slash)
    #expect(duel.hero.action?.phase == .windup)
    #expect(
      simd_distance(
        Movement.facing(yaw: duel.hero.yaw), duel.hero.action!.direction) < 0.0001)
  }

  @Test func forwardContactWaitsForTheVisibleSweepToReachTheTarget() {
    var duel = nearby()
    advance(&duel, seconds: 0.2, command: .init(attackPressed: true))
    #expect(duel.hero.action?.phase == .active)
    #expect(duel.hitsLanded == 0)
    advance(&duel, seconds: 0.1)
    #expect(duel.hitsLanded == 1)
  }

  @Test func stationaryAttackSpamLosesToTheWarnedEnemyPattern() {
    var duel = nearby()
    for tick in 0..<2400 {
      duel.step(.init(attackPressed: tick.isMultiple(of: 12)), deltaTime: DuelSimulation.fixedStep)
      if duel.outcome != .fighting { break }
    }
    #expect(duel.hitsLanded > 0)
    #expect(duel.hitsTaken >= 2)
    #expect(duel.outcome == .lost)
    #expect(duel.enemy.health > 0)
  }

  @Test func dodgeWinsSimultaneousAttackAndGuardSuppressesAttack() {
    var duel = nearby()
    duel.step(
      .init(attackPressed: true, guardHeld: true, dodgePressed: true),
      deltaTime: DuelSimulation.fixedStep)
    #expect(duel.hero.action?.kind == .dodge)
    #expect(duel.hero.stamina == 70)
    var guarded = nearby()
    advance(&guarded, seconds: 0.25, command: .init(attackPressed: true, guardHeld: true))
    #expect(guarded.hero.action == nil)
    #expect(guarded.hero.guarding)
    #expect(guarded.hitsLanded == 0)
  }

  @Test func movementIsFiniteAndBounded() {
    var duel = DuelSimulation()
    let spawn = duel.hero.position
    duel.step(.init(movement: [.nan, .infinity]), deltaTime: 0.2)
    #expect(duel.hero.position == spawn)
    advance(&duel, seconds: 4, command: .init(movement: [100, 100]))
    #expect(duel.hero.position.x < DuelArena.halfWidth - DuelArena.radius)
    #expect(duel.hero.position.y < DuelArena.halfDepth - DuelArena.radius)
    #expect(duel.hero.position.x.isFinite && duel.hero.position.y.isFinite)
  }

  @Test func exhaustionRejectsExpensiveActionsButStillAllowsOrdinaryMovement() {
    var duel = DuelSimulation(heroPosition: [4, 3], enemyPosition: [-4, -3])
    for _ in 0..<3 {
      advance(&duel, seconds: 0.49, command: .init(dodgePressed: true))
    }
    #expect(duel.hero.stamina < 24)
    let stamina = duel.hero.stamina
    duelPress(&duel, attack: true, dodge: true)
    #expect(duel.hero.action == nil)
    #expect(duel.hero.stamina == stamina)
    let start = duel.hero.position
    advance(&duel, seconds: 0.1, command: .init(movement: [1, 0]))
    #expect(duel.hero.position.x > start.x + 0.2)
  }

  @Test func nearbyTargetsCannotBeHitThroughScenery() {
    var duel = DuelSimulation(heroPosition: [4.6, 1.95], enemyPosition: [4.6, 0.25])
    advance(&duel, seconds: 0.4, command: .init(attackPressed: true))
    #expect(duel.hitsLanded == 0)
    #expect(duel.enemy.health == DuelSimulation.enemyMaxHealth)
  }

  @Test func continuousMovementCannotCrossTheOpponent() {
    var duel = nearby()
    advance(&duel, seconds: 0.7, command: .init(movement: [0, -1]))
    #expect(simd_distance(duel.hero.position, duel.enemy.position) >= DuelArena.radius * 2)
    #expect(duel.hero.position.y > duel.enemy.position.y)
  }

  @Test func heldShieldBlocksFrontalHitsAndKeepsFacingWhileBackpedalling() {
    var duel = nearby()
    advance(&duel, seconds: 2, command: .init(guardHeld: true))
    #expect(duel.blocks == 1)
    #expect(duel.hitsTaken == 0)
    #expect(duel.hero.health == DuelSimulation.heroMaxHealth)
    #expect(duel.hero.stamina == 78)
    let facing = duel.hero.yaw
    advance(&duel, seconds: 0.2, command: .init(movement: [0, 1], guardHeld: true))
    #expect(duel.hero.yaw == facing)
    #expect(duel.hero.position.y > 1.4)
  }

  @Test func shieldDoesNotProtectTheBack() {
    var duel = nearby(yaw: .pi)
    advance(&duel, seconds: 2, command: .init(guardHeld: true))
    #expect(duel.blocks == 0)
    #expect(duel.hitsTaken == 1)
    #expect(duel.hero.health == 60)
  }

  @Test func holdingGuardForeverEventuallyBreaksItAndReleasingRestoresStamina() {
    var duel = nearby()
    #expect(wait(&duel, command: .init(guardHeld: true), until: { $0.guardBreaks > 0 }))
    #expect(duel.blocks >= 3)
    #expect(duel.hitsTaken > 0)
    #expect(duel.hero.stamina < 1)
    #expect(duel.hero.stagger > 0)
    advance(&duel, seconds: 1)
    #expect(duel.hero.stamina > 0)
  }

  @Test func sweepAndThrustAlternateWithCommittedFacingAndRealRecovery() {
    var duel = nearby()
    #expect(wait(&duel, until: { $0.enemy.action?.kind == .sweep }))
    let direction = duel.enemy.action?.direction
    advance(&duel, seconds: 0.2, command: .init(movement: [1, 0]))
    #expect(duel.enemy.action?.direction == direction)
    #expect(wait(&duel, until: { $0.enemy.action?.phase == .recovery }))
    #expect(duel.enemy.action?.kind == .sweep)
    #expect(duel.enemy.action!.profile.recovery > duel.enemy.action!.profile.active)
    #expect(wait(&duel, until: { $0.enemy.action?.kind == .thrust }))
    #expect(duel.enemy.action?.phase == .windup)
    #expect(duel.enemy.action!.profile.windup > 0.9)
  }

  @Test func dodgeHasAVulnerableStartupAndRecovery() {
    var duel = nearby()
    duelPress(&duel, dodge: true)
    #expect(duel.hero.action?.phase == .windup)
    #expect(duel.hero.action?.isInvulnerable == false)
    advance(&duel, seconds: 0.05)
    #expect(duel.hero.action?.isInvulnerable == true)
    advance(&duel, seconds: 0.2)
    #expect(duel.hero.action?.phase == .recovery)
    #expect(duel.hero.action?.isInvulnerable == false)
    let position = duel.hero.position
    advance(&duel, seconds: 0.1)
    #expect(duel.hero.position == position)
  }

  @Test func timedDodgeEvadesARealContactWhileEarlyDodgeCanBePunished() {
    var timed = nearby()
    #expect(
      wait(
        &timed,
        until: {
          guard let action = $0.enemy.action else { return false }
          return action.phase == .windup && action.profile.windup - action.elapsed < 0.1
        }))
    advance(&timed, seconds: 0.22, command: .init(movement: [0, -1], dodgePressed: true))
    #expect(timed.evasions == 1)
    #expect(timed.hitsTaken == 0)
    var early = nearby()
    #expect(wait(&early, until: { $0.enemy.action != nil }))
    advance(&early, seconds: 0.8, command: .init(movement: [0, -1], dodgePressed: true))
    #expect(early.evasions == 0)
    #expect(early.hitsTaken > 0)
  }

  @Test func idleResourceRecoveryDoesNotRunDuringAttackOrGuard() {
    var duel = nearby()
    advance(&duel, seconds: 0.4, command: .init(attackPressed: true))
    #expect(duel.hero.stamina == 76)
    advance(&duel, seconds: 0.4, command: .init(guardHeld: true))
    #expect(duel.hero.stamina == 76)
    advance(&duel, seconds: 0.2)
    #expect(duel.hero.stamina > 76)
    #expect(duel.hero.stamina <= DuelSimulation.maxStamina)
  }

  @Test func aSlowCallerCrossesContactInsteadOfMissingIt() {
    var coarse = nearby()
    coarse.step(.init(attackPressed: true), deltaTime: 0.25)
    var fine = nearby()
    advance(&fine, seconds: 0.25, command: .init(attackPressed: true))
    #expect(coarse.enemy.health == fine.enemy.health)
    #expect(coarse.hitsLanded == 1)
    #expect(abs(coarse.hero.stamina - fine.hero.stamina) < 0.001)
  }

  @Test func badTimeDoesNotChangeTheDuel() {
    var duel = nearby()
    let hero = duel.hero
    for dt in [Float(0), -1, .nan, .infinity] {
      duel.step(.init(attackPressed: true), deltaTime: dt)
    }
    #expect(duel.hero == hero)
    #expect(duel.elapsed == 0)
    #expect(duel.takeEvents().isEmpty)
  }

  @Test func defeatFreezesTheDuelAndRetryResetsAllAuthority() {
    var duel = nearby()
    #expect(wait(&duel, until: { $0.outcome == .lost }))
    let before = duel.hero
    let time = duel.elapsed
    advance(&duel, seconds: 1, command: .init(movement: [1, 0], attackPressed: true))
    #expect(duel.hero == before)
    #expect(duel.elapsed == time)
    #expect(duel.takeEvents().contains(.finished(.lost)))
    #expect(duel.takeEvents().isEmpty)
    duel.reset()
    #expect(duel.outcome == .fighting)
    #expect(duel.hero.position == DuelArena.heroSpawn)
    #expect(duel.hero.health == DuelSimulation.heroMaxHealth)
    #expect(duel.hero.stamina == DuelSimulation.maxStamina)
    #expect(duel.enemy.health == DuelSimulation.enemyMaxHealth)
    #expect(duel.hero.action == nil && duel.enemy.action == nil)
    #expect(duel.hitsLanded == 0 && duel.hitsTaken == 0 && duel.blocks == 0)
    #expect(duel.takeEvents().isEmpty)
  }

  private func nearby(yaw: Float = 0) -> DuelSimulation {
    DuelSimulation(heroPosition: [0, 1.4], enemyPosition: [0, 0], heroYaw: yaw)
  }

  private func duelPress(_ duel: inout DuelSimulation, attack: Bool = false, dodge: Bool = false) {
    duel.step(
      .init(attackPressed: attack, dodgePressed: dodge), deltaTime: DuelSimulation.fixedStep)
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
    }
  }

  private func wait(
    _ duel: inout DuelSimulation, command: DuelCommand = .neutral,
    until condition: (DuelSimulation) -> Bool
  ) -> Bool {
    for _ in 0..<2400 {
      if condition(duel) { return true }
      duel.step(command, deltaTime: DuelSimulation.fixedStep)
    }
    return condition(duel)
  }
}
