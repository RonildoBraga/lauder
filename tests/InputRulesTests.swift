import Testing

@testable import Lauder

struct InputRulesTests {
  @Test
  func opposingHeldKeysCannotClearTheReleaseGate() {
    var state = InputRules.State()
    var raw = InputRules.Raw(up: true, down: true)
    #expect(sample(raw, state: &state) == .neutral)
    #expect(state.needsNeutralInput)

    raw.down = false
    #expect(sample(raw, state: &state) == .neutral)
    #expect(state.needsNeutralInput)

    raw.up = false
    #expect(sample(raw, state: &state) == .neutral)
    #expect(!state.needsNeutralInput)

    raw.up = true
    #expect(sample(raw, state: &state).movement == [0, 1])
  }

  @Test
  func heldControllerInputAfterResumeRequiresReleaseAndFreshInput() {
    var state = InputRules.State()
    let held = InputRules.Raw(stick: [1, 0], controllerAction: true)
    #expect(sample(held, state: &state) == .neutral)
    #expect(state.needsNeutralInput)

    #expect(sample(.init(), state: &state) == .neutral)
    #expect(!state.needsNeutralInput)

    let fresh = sample(held, state: &state)
    #expect(fresh.movement == [1, 0])
    #expect(fresh.actionPressed)
    #expect(!sample(held, state: &state).actionPressed)
  }

  @Test(arguments: [false, true])
  func pauseHasPriorityAndRequiresReleaseBeforeAnotherPress(keyboard: Bool) {
    var state = InputRules.State(needsNeutralInput: false)
    let held = InputRules.Raw(
      stick: [1, 0], controllerAction: true, controllerPause: !keyboard,
      controllerSwitch: true, up: true, keyboardAction: true, keyboardPause: keyboard,
      keyboardSwitch: true)
    let pause = sample(held, state: &state)
    #expect(pause.movement == .zero)
    #expect(!pause.actionPressed)
    #expect(pause.pausePressed)
    #expect(!pause.switchPressed)
    #expect(sample(held, mode: .paused, state: &state) == .neutral)

    // The input owner re-arms the release gate when the session toggles Pause.
    state = InputRules.State()
    #expect(sample(held, state: &state) == .neutral)
    #expect(state.needsNeutralInput)
    #expect(sample(.init(), state: &state) == .neutral)
    #expect(!state.needsNeutralInput)
    #expect(sample(held, mode: .paused, state: &state).pausePressed)
  }

  @Test
  func keyboardMovementOverridesTheStickEvenWhenOpposingKeysCancel() {
    var state = InputRules.State(needsNeutralInput: false)
    var raw = InputRules.Raw(stick: [1, 0], up: true)
    #expect(sample(raw, state: &state).movement == [0, 1])

    raw.down = true
    #expect(sample(raw, state: &state).movement == .zero)

    raw.up = false
    raw.down = false
    #expect(sample(raw, state: &state).movement == [1, 0])
  }

  @Test(arguments: [false, true])
  func simultaneousSwitchConsumesActionUntilAFreshPress(keyboard: Bool) {
    var state = InputRules.State(needsNeutralInput: false)
    var raw = InputRules.Raw(
      stick: [0.5, 0], controllerAction: !keyboard, controllerSwitch: !keyboard,
      keyboardAction: keyboard, keyboardSwitch: keyboard)
    let switched = sample(raw, state: &state)
    #expect(switched.switchPressed)
    #expect(!switched.actionPressed)
    #expect(switched.movement == [0.5, 0])

    let held = sample(raw, state: &state)
    #expect(!held.switchPressed)
    #expect(!held.actionPressed)
    #expect(!state.needsNeutralInput)

    raw.controllerSwitch = false
    raw.keyboardSwitch = false
    #expect(!sample(raw, state: &state).actionPressed)
    raw.controllerAction = false
    raw.keyboardAction = false
    #expect(!sample(raw, state: &state).actionPressed)
    raw.keyboardAction = keyboard
    raw.controllerAction = !keyboard
    #expect(sample(raw, state: &state).actionPressed)
  }

  @Test
  func switchingDoesNotReplayAnActionAlreadyHeld() {
    var state = InputRules.State(needsNeutralInput: false)
    var raw = InputRules.Raw(controllerAction: true)
    #expect(sample(raw, state: &state).actionPressed)
    raw.controllerSwitch = true
    let switched = sample(raw, state: &state)
    #expect(switched.switchPressed)
    #expect(!switched.actionPressed)
    raw.controllerSwitch = false
    #expect(!sample(raw, state: &state).actionPressed)
  }

  @Test
  func pausedSwitchAndActionAreConsumedRatherThanQueued() {
    var state = InputRules.State(needsNeutralInput: false)
    let held = InputRules.Raw(keyboardAction: true, keyboardSwitch: true)
    #expect(sample(held, mode: .paused, state: &state) == .neutral)
    #expect(sample(held, state: &state) == .neutral)
    #expect(sample(.init(), state: &state) == .neutral)
    #expect(sample(.init(keyboardSwitch: true), state: &state).switchPressed)
  }

  @Test
  func touchInputRequiresEveryContactToReleaseBeforeFreshIntent() {
    var state = InputRules.State()
    var held = InputRules.Raw(
      touchStick: [0.5, 0], touchIsTouching: true, touchAction: true)
    #expect(sample(held, state: &state) == .neutral)
    #expect(state.needsNeutralInput)

    // Centring the knob and releasing a button does not lift the joystick finger.
    held.touchStick = .zero
    held.touchAction = false
    #expect(sample(held, state: &state) == .neutral)
    #expect(state.needsNeutralInput)
    held.touchIsTouching = false
    #expect(sample(held, state: &state) == .neutral)
    #expect(!state.needsNeutralInput)

    held.touchStick = [0.5, 0]
    held.touchIsTouching = true
    held.touchAction = true
    let fresh = sample(held, state: &state)
    #expect(fresh.movement == [0.5, 0])
    #expect(fresh.actionPressed)
    #expect(!sample(held, state: &state).actionPressed)
  }

  @Test(arguments: [
    InputRules.Raw(touchStick: [1, 0]),
    InputRules.Raw(touchStick: [.nan, 0]),
    InputRules.Raw(touchStick: [0, .infinity]),
    InputRules.Raw(touchStick: [-.infinity, 0]),
  ])
  func touchVectorCannotClearTheReleaseGateWithoutAContact(raw: InputRules.Raw) {
    var state = InputRules.State()
    #expect(sample(raw, state: &state) == .neutral)
    #expect(state.needsNeutralInput)
    #expect(sample(.init(), state: &state) == .neutral)
    #expect(!state.needsNeutralInput)
  }

  @Test
  func movementUsesHeldKeysThenAnActiveTouchStickThenTheController() {
    var state = InputRules.State(needsNeutralInput: false)
    var raw = InputRules.Raw(
      stick: [1, 0], up: true, touchStick: [0, -0.5], touchIsTouching: true)
    #expect(sample(raw, state: &state).movement == [0, 1])
    raw.down = true
    #expect(sample(raw, state: &state).movement == .zero)
    raw.up = false
    raw.down = false
    #expect(sample(raw, state: &state).movement == [0, -0.5])
    raw.touchStick = .zero
    #expect(sample(raw, state: &state).movement == .zero)
    raw.touchIsTouching = false
    #expect(sample(raw, state: &state).movement == [1, 0])
  }

  @Test
  func simultaneousTouchSwitchConsumesActionAndKeepsMovement() {
    var state = InputRules.State(needsNeutralInput: false)
    var raw = InputRules.Raw(
      touchStick: [0.5, 0], touchIsTouching: true, touchAction: true, touchSwitch: true)
    let switched = sample(raw, state: &state)
    #expect(switched.movement == [0.5, 0])
    #expect(switched.switchPressed)
    #expect(!switched.actionPressed)
    #expect(!state.needsNeutralInput)
    #expect(!sample(raw, state: &state).switchPressed)

    raw.touchSwitch = false
    #expect(!sample(raw, state: &state).actionPressed)
    raw.touchAction = false
    #expect(!sample(raw, state: &state).actionPressed)
    raw.touchAction = true
    #expect(sample(raw, state: &state).actionPressed)
  }

  @Test
  func touchPauseWinsAndRequiresReleaseBeforeResuming() {
    var state = InputRules.State(needsNeutralInput: false)
    let held = InputRules.Raw(
      touchStick: [0.5, 0], touchIsTouching: true, touchAction: true,
      touchPause: true, touchSwitch: true)
    let pause = sample(held, state: &state)
    #expect(pause.movement == .zero)
    #expect(pause.pausePressed)
    #expect(!pause.switchPressed)
    #expect(!pause.actionPressed)
    #expect(sample(held, mode: .paused, state: &state) == .neutral)

    state = InputRules.State()
    #expect(sample(held, mode: .paused, state: &state) == .neutral)
    #expect(state.needsNeutralInput)
    #expect(sample(.init(), mode: .paused, state: &state) == .neutral)
    #expect(!state.needsNeutralInput)
    #expect(sample(.init(touchPause: true), mode: .paused, state: &state).pausePressed)
  }

  @Test
  func pausedTouchSwitchAndActionAreConsumedRatherThanQueued() {
    var state = InputRules.State(needsNeutralInput: false)
    let held = InputRules.Raw(
      touchStick: [0.5, 0], touchIsTouching: true, touchAction: true, touchSwitch: true)
    #expect(sample(held, mode: .paused, state: &state) == .neutral)
    let resumed = sample(held, state: &state)
    #expect(resumed.movement == [0.5, 0])
    #expect(!resumed.actionPressed)
    #expect(!resumed.switchPressed)
    #expect(sample(.init(), state: &state) == .neutral)
    #expect(sample(.init(touchSwitch: true), state: &state).switchPressed)
  }

  @Test(arguments: [
    InputRules.Raw(controllerAction: true),
    InputRules.Raw(controllerPause: true),
    InputRules.Raw(controllerSwitch: true),
    InputRules.Raw(keyboardAction: true),
    InputRules.Raw(keyboardPause: true),
    InputRules.Raw(keyboardSwitch: true),
    InputRules.Raw(touchAction: true),
    InputRules.Raw(touchPause: true),
    InputRules.Raw(touchSwitch: true),
  ])
  func everyGameplayButtonKeepsTheReleaseGateClosed(raw: InputRules.Raw) {
    var state = InputRules.State()
    #expect(sample(raw, state: &state) == .neutral)
    #expect(state.needsNeutralInput)
    #expect(sample(.init(), state: &state) == .neutral)
    #expect(!state.needsNeutralInput)
  }

  private func sample(
    _ raw: InputRules.Raw, mode: GameSession.Mode = .exploring, state: inout InputRules.State
  ) -> InputRules.Input {
    let result = InputRules.resolve(raw, mode: mode, state: state)
    state = result.state
    return result.input
  }
}
