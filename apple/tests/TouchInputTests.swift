import Testing
import simd

@testable import Lauder

struct TouchInputTests {
  @Test
  func stickIsCameraInputWithClampedMagnitudeAndInvertedScreenY() {
    #expect(TouchInput.movement(displacement: [0, -20], radius: 40) == [0, 0.5])
    #expect(TouchInput.movement(displacement: [40, 0], radius: 40) == [1, 0])
    let diagonal = TouchInput.movement(displacement: [80, 80], radius: 40)
    #expect(abs(simd_length(diagonal) - 1) < 0.00001)
    #expect(diagonal.x > 0 && diagonal.y < 0)
    #expect(TouchInput.movement(displacement: [.nan, 1], radius: 40) == .zero)
    #expect(TouchInput.movement(displacement: [1, 1], radius: 0) == .zero)
  }

  @Test
  func endingOneContactDoesNotReleaseOtherControls() {
    var touch = TouchInput()
    touch.setStick([0.5, 0], isTouching: true, generation: 0)
    touch.setButton(.action, isPressed: true, generation: 0)
    touch.setButton(.cycle, isPressed: true, generation: 0)
    _ = touch.sample()
    touch.setButton(.cycle, isPressed: false, generation: 0)
    let movingAction = touch.sample()
    #expect(movingAction.touchStick == [0.5, 0])
    #expect(movingAction.touchIsTouching)
    #expect(movingAction.touchAction)
    #expect(!movingAction.touchSwitch)
    touch.setStick(.zero, isTouching: false, generation: 0)
    let heldAction = touch.sample()
    #expect(heldAction.touchStick == .zero && !heldAction.touchIsTouching)
    #expect(heldAction.touchAction)
  }

  @Test(arguments: [TouchInput.Button.action, .cycle, .pause, .formation])
  func rapidTapIsSampledOnceRatherThanLostBetweenUpdates(button: TouchInput.Button) {
    var touch = TouchInput()
    touch.setButton(button, isPressed: true, generation: 0)
    touch.setButton(button, isPressed: false, generation: 0)
    let raw = touch.sample()
    var state = InputRules.State(needsNeutralInput: false)
    let first = InputRules.resolve(raw, mode: .exploring, state: state)
    state = first.state
    #expect(first.input.actionPressed == (button == .action))
    #expect(first.input.switchPressed == (button == .cycle))
    #expect(first.input.pausePressed == (button == .pause))
    #expect(first.input.formationPressed == (button == .formation))
    #expect(InputRules.resolve(touch.sample(), mode: .exploring, state: state).input == .neutral)
  }

  @Test
  func cancellationDiscardsQueuedPressesAndRejectsOldCapturesAfterReactivation() {
    var touch = TouchInput()
    touch.setStick([1, 0], isTouching: true, generation: 0)
    touch.setButton(.pause, isPressed: true, generation: 0)
    touch.cancel()
    #expect(touch.generation == 1)
    touch.setStick([1, 0], isTouching: true, generation: 0)
    touch.setButton(.action, isPressed: true, generation: 0)
    #expect(touch.sample() == .init())
    touch.setStick(.zero, isTouching: true, generation: 1)
    #expect(touch.sample().touchIsTouching)
    touch.setButton(.cycle, isPressed: true, generation: 1)
    #expect(touch.sample().touchSwitch)
    touch.cancel()
    touch.setButton(.cycle, isPressed: false, generation: 1)
    #expect(touch.sample() == .init())
  }
}
