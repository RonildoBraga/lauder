import Testing

@testable import Lauder

struct InputRulesTests {
  @Test
  func opposingMovementKeysCannotClearNeutralGate() {
    var state = InputRules.State()
    #expect(sample(.init(up: true, down: true), state: &state) == .neutral)
    #expect(state.needsNeutralInput)
    #expect(sample(.init(up: true), state: &state) == .neutral)
    #expect(state.needsNeutralInput)
    #expect(sample(.init(), state: &state) == .neutral)
    #expect(!state.needsNeutralInput)
    #expect(sample(.init(up: true), state: &state).movement == [0, 1])
  }

  @Test
  func centredTouchContactAndHeldGuardPreventResumeUntilRelease() {
    var state = InputRules.State()
    #expect(sample(.init(touchIsTouching: true), state: &state) == .neutral)
    #expect(state.needsNeutralInput)
    #expect(sample(.init(touchGuard: true), state: &state) == .neutral)
    #expect(state.needsNeutralInput)
    _ = sample(.init(), state: &state)
    #expect(!state.needsNeutralInput)
    #expect(sample(.init(touchGuard: true), state: &state).guardHeld)
  }

  @Test(arguments: [Float.nan, .infinity, -.infinity])
  func invalidStickCannotClearNeutralGate(value: Float) {
    var state = InputRules.State()
    #expect(sample(.init(stick: [value, 0]), state: &state) == .neutral)
    #expect(state.needsNeutralInput)
    _ = sample(.init(touchStick: [0, value]), state: &state)
    #expect(state.needsNeutralInput)
    _ = sample(.init(), state: &state)
    #expect(!state.needsNeutralInput)
  }

  @Test
  func keyboardMovementOverridesStickIncludingOpposingKeys() {
    var state = InputRules.State(needsNeutralInput: false)
    #expect(sample(.init(stick: [1, 0], up: true), state: &state).movement == [0, 1])
    #expect(sample(.init(stick: [1, 0], up: true, down: true), state: &state).movement == .zero)
    #expect(sample(.init(stick: [1, 0]), state: &state).movement == [1, 0])
    #expect(
      sample(.init(stick: [1, 0], touchStick: [0, 1], touchIsTouching: true), state: &state)
        .movement == [0, 1])
  }

  @Test
  func attackAndDodgeAreFreshEdgesButGuardRemainsHeld() {
    var state = InputRules.State(needsNeutralInput: false)
    let raw = InputRules.Raw(controllerAttack: true, controllerGuard: true, controllerDodge: true)
    let first = sample(raw, state: &state)
    #expect(first.attackPressed && first.dodgePressed && first.guardHeld)
    let held = sample(raw, state: &state)
    #expect(!held.attackPressed && !held.dodgePressed && held.guardHeld)
    _ = sample(.init(), state: &state)
    let fresh = sample(raw, state: &state)
    #expect(fresh.attackPressed && fresh.dodgePressed)
  }

  @Test
  func pauseHasPriorityAndConsumesSimultaneousCombatEdges() {
    var state = InputRules.State(needsNeutralInput: false)
    let raw = InputRules.Raw(
      controllerAttack: true, controllerGuard: true, controllerDodge: true,
      controllerPause: true, up: true)
    #expect(sample(raw, state: &state) == .init(pausePressed: true))
    #expect(sample(raw, mode: .paused, state: &state) == .neutral)
    // The world re-arms this gate whenever Pause changes the mode.
    state = InputRules.State()
    #expect(sample(raw, mode: .paused, state: &state) == .neutral)
    #expect(state.needsNeutralInput)
    _ = sample(.init(), mode: .paused, state: &state)
    #expect(!state.needsNeutralInput)
    #expect(sample(.init(controllerPause: true), mode: .paused, state: &state).pausePressed)
  }

  @Test
  func pausedAttackAndDodgeDoNotReplayWhenPlayResumes() {
    var state = InputRules.State(needsNeutralInput: false)
    let held = InputRules.Raw(keyboardAttack: true, keyboardDodge: true)
    #expect(sample(held, mode: .paused, state: &state) == .neutral)
    #expect(sample(held, state: &state) == .neutral)
    _ = sample(.init(), state: &state)
    #expect(sample(held, state: &state).attackPressed)
  }

  @Test
  func pauseNavigationAndConfirmationAreFreshAndDoNotMoveTheHero() {
    var state = InputRules.State(needsNeutralInput: false)
    let down = InputRules.Raw(controllerAction: true, down: true)
    let first = sample(down, mode: .paused, state: &state)
    #expect(first.menuMove == 1 && first.actionPressed && first.movement == .zero)
    #expect(sample(down, mode: .paused, state: &state) == .neutral)
    #expect(sample(.init(arrowUp: true), mode: .paused, state: &state).menuMove == -1)
    _ = sample(.init(), mode: .paused, state: &state)
    #expect(sample(.init(dpadDown: true), mode: .paused, state: &state).menuMove == 1)
  }

  @Test
  func aFreshConfirmIsAvailableForOutcomeRetryWithoutBecomingAnAttack() {
    var state = InputRules.State(needsNeutralInput: false)
    let first = sample(.init(keyboardAction: true), state: &state)
    #expect(first.actionPressed && !first.attackPressed)
    #expect(sample(.init(keyboardAction: true), state: &state) == .neutral)
  }

  @Test
  func touchRestartIsPausedOnlyAndNotRepeatedByHolding() {
    var state = InputRules.State(needsNeutralInput: false)
    #expect(sample(.init(touchRestart: true), state: &state) == .neutral)
    #expect(sample(.init(touchRestart: true), mode: .paused, state: &state) == .neutral)
    _ = sample(.init(), mode: .paused, state: &state)
    #expect(sample(.init(touchRestart: true), mode: .paused, state: &state).restartPressed)
    #expect(sample(.init(touchRestart: true), mode: .paused, state: &state) == .neutral)
  }

  private func sample(
    _ raw: InputRules.Raw, mode: GameSession.Mode = .exploring,
    state: inout InputRules.State
  ) -> InputRules.Input {
    let result = InputRules.resolve(raw, mode: mode, state: state)
    state = result.state
    return result.input
  }
}
