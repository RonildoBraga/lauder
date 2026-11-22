import Testing
import simd

@testable import Lauder

/// Tactical enemies reuse the opening's wind-up and recovery, with explicit opt-in changes.
@MainActor
struct EnemyBehaviorTests {
  @Test
  func anUnchangedShooterStartsAimingAtOnce() {
    let spec = enemy()
    #expect(spec.behavior == .stationary && spec.reactionDelay == 0)
    var state = HostileState(spec: spec)
    state.engage()
    #expect(state.phase == .aiming(remaining: spec.windUp))
    #expect(state.step(dt: spec.windUp, canHit: true, toward: .zero) == .hit)
  }

  @Test(arguments: [Level.Hostile.Behavior.takeCover, .flank])
  func tacticalEnemiesReactBeforeTheirFirstWindUp(behavior: Level.Hostile.Behavior) {
    let spec = enemy(behavior: behavior, reaction: 0.35)
    var state = HostileState(spec: spec)
    state.engage()
    #expect(state.phase == .recovering(remaining: 0.35))
    #expect(!state.isTargetable)
    #expect(state.step(dt: 0.349, canHit: true, toward: .zero) == nil)
    guard case .recovering = state.phase else {
      Issue.record("The reaction ended early")
      return
    }
    #expect(state.step(dt: 0.002, canHit: true, toward: .zero) == nil)
    #expect(state.phase == .aiming(remaining: spec.windUp))
    #expect(state.isTargetable)
    #expect(state.step(dt: spec.windUp - 0.001, canHit: true, toward: .zero) == nil)
    #expect(state.step(dt: 0.002, canHit: true, toward: .zero) == .hit)
    // Recovery after a shot is the ordinary recovery, without paying the reaction twice.
    #expect(state.phase == .recovering(remaining: spec.recovery))
    #expect(state.step(dt: spec.recovery, canHit: true, toward: .zero) == nil)
    #expect(state.phase == .aiming(remaining: spec.windUp))
  }

  @Test
  func movingCannotCompleteAnAimOrRecovery() {
    let spec = enemy(behavior: .flank)
    var state = HostileState(spec: spec)
    state.engage()
    #expect(state.step(dt: 10, canHit: true, toward: .zero, canAttack: false) == nil)
    #expect(state.phase == .aiming(remaining: spec.windUp))
    #expect(state.step(dt: spec.windUp, canHit: true, toward: .zero) == .hit)
    #expect(state.step(dt: 10, canHit: true, toward: .zero, canAttack: false) == nil)
    #expect(state.phase == .recovering(remaining: spec.recovery))
    #expect(state.step(dt: spec.recovery, canHit: true, toward: .zero) == nil)
    #expect(state.phase == .aiming(remaining: spec.windUp))
  }

  @Test
  func aThrowReturnsALaunchAndNeverAnImmediateHit() {
    let spec = enemy(attack: .throwGrenade, reaction: 0.35)
    var state = HostileState(spec: spec)
    state.engage()
    #expect(state.step(dt: 0.35, canHit: true, toward: .zero) == nil)
    #expect(state.step(dt: spec.windUp, canHit: true, toward: .zero) == .grenade)
    #expect(state.phase == .recovering(remaining: spec.recovery))
    #expect(state.step(dt: spec.recovery, canHit: true, toward: .zero) == nil)
    // An out-of-range throw is rejected, with no launch to turn into later damage.
    #expect(state.step(dt: spec.windUp, canHit: false, toward: .zero) == .blocked)
  }

  @Test
  func disruptAndDownCancelAnUnreleasedGrenade() {
    let spec = enemy(attack: .throwGrenade)
    var state = HostileState(spec: spec)
    state.engage()
    _ = state.step(dt: spec.windUp - 0.01, canHit: true, toward: .zero)
    state.disrupt()
    #expect(state.phase == .recovering(remaining: spec.recovery))
    #expect(state.step(dt: 0.02, canHit: true, toward: .zero) == nil)
    state.knockDown()
    state.engage()
    #expect(state.step(dt: 100, canHit: true, toward: .zero) == nil)
    #expect(state.isDown && !state.isTargetable)
  }

  @Test
  func fallbackRestoresTheAuthoredPositionAndReactionWithoutForgettingTheThreat() {
    let spec = enemy(behavior: .takeCover, reaction: 0.35)
    var state = HostileState(spec: spec)
    state.engage()
    _ = state.step(dt: 0.35, canHit: true, toward: .zero)
    state.reposition(to: [4, -5])
    #expect(state.position == [4, -5] && state.isTargetable)
    state.standDown()
    #expect(state.position == spec.standAt && state.phase == .waiting)
    #expect(state.isTargetable)
    #expect(state.step(dt: 100, canHit: true, toward: .zero) == nil)
    state.engage()
    #expect(state.phase == .recovering(remaining: spec.reactionDelay))
    let restarted = HostileState(spec: spec)
    #expect(!restarted.isTargetable && restarted.position == spec.standAt)
  }

  @Test
  func staleDestinationsCannotMoveHiddenRevealingOrDownedActors() {
    var spec = enemy()
    spec.inView = false
    var state = HostileState(spec: spec)
    state.reposition(to: [9, 9])
    #expect(state.position == spec.hiddenAt)
    state.reveal()
    state.reposition(to: [9, 9])
    #expect(state.position == spec.hiddenAt)
    _ = state.step(dt: HostileState.stepOutTime, canHit: true, toward: .zero)
    state.reposition(to: [4, -5])
    #expect(state.position == [4, -5])
    state.reposition(to: [Float.nan, 0])
    #expect(state.position == [4, -5])
    state.knockDown()
    state.reposition(to: [9, 9])
    #expect(state.position == [4, -5])
  }

  @Test
  func theExistingChargerStillClosesWithoutAShooterReaction() {
    let spec = enemy(attack: .charge(speed: 2), reaction: 0.35)
    var state = HostileState(spec: spec)
    state.engage()
    #expect(state.phase == .charging)
    #expect(state.step(dt: 0.1, canHit: false, toward: .zero, canAttack: false) == nil)
    #expect(simd_distance(state.position, .zero) < simd_distance(spec.standAt, .zero))
  }

  private func enemy(
    attack: Level.Hostile.Attack = .shoot,
    behavior: Level.Hostile.Behavior = .stationary, reaction: Float = 0
  ) -> Level.Hostile {
    Level.Hostile(
      id: "tactical", name: "The tactical hostile", hiddenAt: [0, -8], standAt: [0, -5],
      hits: 3, attack: attack, behavior: behavior, reactionDelay: reaction,
      windUp: 1.5, recovery: 1.4, range: 14, inView: true, targetFromWindUp: true)
  }
}
