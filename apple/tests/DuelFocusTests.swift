import Testing
import simd

@testable import Lauder

struct DuelFocusTests {
  @Test func selectionTurnsWithoutMovingAndRemainsBounded() {
    var duel = nearby(yaw: .pi)
    let start = duel.hero.position
    duel.step(.init(focusPressed: true), deltaTime: DuelSimulation.fixedStep)
    #expect(duel.isFocused)
    #expect(duel.hero.position == start)
    #expect(abs(duel.hero.yaw - .pi) <= 5 * .pi * DuelSimulation.fixedStep + 0.0001)
    #expect(alignment(duel) < 0, "selection does not grant an instant 180-degree turn")
    advance(&duel, seconds: 0.25)
    #expect(alignment(duel) > 0.99)
    #expect(duel.hero.stamina == DuelSimulation.maxStamina)
  }

  @Test(arguments: [false, true])
  func backpedalAndStrafeKeepTheOpponentInFront(guarding: Bool) {
    var duel = nearby()
    duel.step(.init(focusPressed: true), deltaTime: DuelSimulation.fixedStep)
    let start = duel.hero.position
    advance(&duel, seconds: 0.3, command: .init(movement: [0, 1], guardHeld: guarding))
    #expect(duel.hero.position.y > start.y + 0.25)
    #expect(alignment(duel) > 0.99)
    let beforeStrafe = duel.hero.position
    advance(&duel, seconds: 0.3, command: .init(movement: [1, 0], guardHeld: guarding))
    #expect(duel.hero.position.x > beforeStrafe.x + 0.25)
    #expect(alignment(duel) > 0.99)
    #expect(duel.hero.guarding == guarding)
  }

  @Test func releasingFocusRestoresOrdinaryMovementFacing() {
    var duel = nearby()
    duel.step(.init(focusPressed: true), deltaTime: DuelSimulation.fixedStep)
    advance(&duel, seconds: 0.25, command: .init(movement: [0, 1]))
    #expect(alignment(duel) > 0.99)
    duel.step(.init(focusPressed: true), deltaTime: DuelSimulation.fixedStep)
    advance(&duel, seconds: 0.25, command: .init(movement: [0, 1]))
    #expect(!duel.isFocused)
    #expect(simd_dot(Movement.facing(yaw: duel.hero.yaw), SIMD2<Float>(0, 1)) > 0.99)
    #expect(alignment(duel) < 0, "free movement follows travel even as the enemy moves sideways")
  }

  @Test func aSlowFrameConsumesOneFocusEdgeAndNoCombatResource() {
    var duel = nearby()
    duel.step(
      .init(attackPressed: true, dodgePressed: true, focusPressed: true), deltaTime: 0.25)
    #expect(duel.isFocused)
    #expect(duel.hero.action == nil)
    #expect(duel.hero.stamina == DuelSimulation.maxStamina)
    #expect(duel.hitsLanded == 0)
  }

  @Test func focusCannotRedirectOrCancelACommittedSwing() throws {
    var duel = nearby()
    advance(&duel, seconds: 0.1, command: .init(attackPressed: true))
    let action = try #require(duel.hero.action)
    let yaw = duel.hero.yaw
    duel.step(
      .init(movement: [1, 0], attackPressed: true, dodgePressed: true, focusPressed: true),
      deltaTime: DuelSimulation.fixedStep)
    #expect(duel.isFocused)
    #expect(duel.hero.action?.kind == action.kind)
    #expect(duel.hero.action?.direction == action.direction)
    #expect(duel.hero.action!.elapsed > action.elapsed)
    #expect(duel.hero.yaw == yaw)
    #expect(duel.hero.stamina == 76)
  }

  @Test(arguments: [DuelAction.Kind.slash, .dodge])
  func changingFacingModeClearsFutureCombatWithoutErasingRecovery(kind: DuelAction.Kind) {
    var duel = nearby()
    advance(&duel, seconds: 0.56, command: .init(attackPressed: true))
    duel.step(
      .init(attackPressed: kind == .slash, dodgePressed: kind == .dodge),
      deltaTime: DuelSimulation.fixedStep)
    duel.step(.init(focusPressed: true), deltaTime: DuelSimulation.fixedStep)
    #expect(duel.hero.action?.phase == .recovery)
    advance(&duel, seconds: 0.2)
    #expect(duel.isFocused)
    #expect(duel.hero.action == nil)
    #expect(duel.hitsLanded == 1)
    #expect(duel.hero.stamina > 76, "no queued follow-up spent stamina")
  }

  @Test func aFocusedBufferedSlashUsesAcceptedFacingButDodgeKeepsTravelDirection() throws {
    var duel = nearby()
    duel.step(.init(focusPressed: true), deltaTime: DuelSimulation.fixedStep)
    duel.step(.init(movement: [1, 0], dodgePressed: true), deltaTime: DuelSimulation.fixedStep)
    let dodgeYaw = duel.hero.yaw
    advance(&duel, seconds: 0.35 - DuelSimulation.fixedStep, command: .init(movement: [1, 0]))
    #expect(duel.hero.action?.kind == .dodge && duel.hero.action?.phase == .recovery)
    #expect(duel.hero.action?.direction == [1, 0])
    #expect(duel.hero.yaw == dodgeYaw, "evasion does not rotate a committed pose")
    duel.step(.init(attackPressed: true), deltaTime: DuelSimulation.fixedStep)
    advance(&duel, seconds: 0.14)
    let slash = try #require(duel.hero.action)
    #expect(slash.kind == .slash && slash.phase == .windup)
    #expect(duel.hero.yaw > 0.05, "the accepted slash uses current bounded enemy-facing")
    #expect(simd_distance(slash.direction, Movement.facing(yaw: duel.hero.yaw)) < 0.0001)
  }

  @Test func interruptionRetainsSelectionAndDefeatAndRetryReleaseIt() {
    var duel = nearby()
    duel.step(.init(focusPressed: true), deltaTime: DuelSimulation.fixedStep)
    duel.interrupt()
    #expect(duel.isFocused, "Pause does not require reacquiring an unchanged target")
    advance(&duel, seconds: 8)
    #expect(duel.outcome == .lost)
    #expect(!duel.isFocused)
    duel.step(.init(focusPressed: true), deltaTime: 0.1)
    #expect(!duel.isFocused, "a defeated duel cannot acquire focus")
    duel.reset()
    duel.step(.init(focusPressed: true), deltaTime: DuelSimulation.fixedStep)
    #expect(duel.isFocused)
    duel.reset()
    #expect(!duel.isFocused)
  }

  private func nearby(yaw: Float = 0) -> DuelSimulation {
    DuelSimulation(heroPosition: [0, 1.4], enemyPosition: [0, 0], heroYaw: yaw)
  }

  private func alignment(_ duel: DuelSimulation) -> Float {
    simd_dot(
      Movement.facing(yaw: duel.hero.yaw),
      simd_normalize(duel.enemy.position - duel.hero.position))
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
