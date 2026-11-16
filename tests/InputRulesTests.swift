import Testing

@testable import Lauder

struct InputRulesTests {
  @Test
  func opposingHeldKeysCannotClearTheReleaseGate() {
    var raw = InputRules.Raw(up: true, down: true)
    let opposing = InputRules.resolve(raw, isPaused: false, needsNeutralInput: true)
    #expect(opposing.input == .neutral)
    #expect(opposing.needsNeutralInput)

    raw.down = false
    let stillHeld = InputRules.resolve(raw, isPaused: false, needsNeutralInput: true)
    #expect(stillHeld.input == .neutral)
    #expect(stillHeld.needsNeutralInput)

    raw.up = false
    let released = InputRules.resolve(raw, isPaused: false, needsNeutralInput: true)
    #expect(released.input == .neutral)
    #expect(!released.needsNeutralInput)

    raw.up = true
    let fresh = InputRules.resolve(
      raw, isPaused: false, needsNeutralInput: released.needsNeutralInput)
    #expect(fresh.input.movement == [0, 1])
  }

  @Test
  func heldControllerInputAfterResumeRequiresReleaseAndFreshInput() {
    let held = InputRules.Raw(stick: [1, 0], controllerAction: true)
    let gated = InputRules.resolve(held, isPaused: false, needsNeutralInput: true)
    #expect(gated.input == .neutral)
    #expect(gated.needsNeutralInput)

    let released = InputRules.resolve(.init(), isPaused: false, needsNeutralInput: true)
    #expect(released.input == .neutral)
    #expect(!released.needsNeutralInput)

    let fresh = InputRules.resolve(
      held, isPaused: false, needsNeutralInput: released.needsNeutralInput)
    #expect(fresh.input.movement == [1, 0])
    #expect(fresh.input.actionPressed)
  }

  @Test(arguments: [false, true])
  func pauseIsAvailableWhilePausedAndHeldPauseCannotBypassTheGate(keyboard: Bool) {
    let held = InputRules.Raw(
      stick: [1, 0], controllerAction: true, controllerPause: !keyboard,
      up: true, keyboardAction: true, keyboardPause: keyboard)
    let paused = InputRules.resolve(held, isPaused: true, needsNeutralInput: false)
    #expect(paused.input.movement == .zero)
    #expect(!paused.input.actionPressed)
    #expect(paused.input.pausePressed)

    // Pause/Resume re-arms the gate before the caller reads the next snapshot.
    let heldAfterResume = InputRules.resolve(held, isPaused: false, needsNeutralInput: true)
    #expect(heldAfterResume.input == .neutral)
    #expect(heldAfterResume.needsNeutralInput)
    let released = InputRules.resolve(.init(), isPaused: false, needsNeutralInput: true)
    #expect(!released.needsNeutralInput)
  }

  @Test
  func keyboardMovementOverridesTheStickEvenWhenOpposingKeysCancel() {
    var raw = InputRules.Raw(stick: [1, 0], up: true)
    let keyboard = InputRules.resolve(raw, isPaused: false, needsNeutralInput: false)
    #expect(keyboard.input.movement == [0, 1])

    raw.down = true
    let opposing = InputRules.resolve(raw, isPaused: false, needsNeutralInput: false)
    #expect(opposing.input.movement == .zero)

    raw.up = false
    raw.down = false
    let controller = InputRules.resolve(raw, isPaused: false, needsNeutralInput: false)
    #expect(controller.input.movement == [1, 0])
  }
}
