import CoreGraphics
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
  func aGroundPressHoldsTheReleaseGateUntilItLifts() {
    var touch = TouchInput()
    touch.setButton(.ground, isPressed: true, generation: 0)
    #expect(touch.sample().touchGround)
    #expect(touch.sample().touchGround, "held, not only pressed")
    touch.setButton(.ground, isPressed: false, generation: 0)
    #expect(!touch.sample().touchGround)
  }

  @Test
  func aMenuOrderIsSampledOnceAndDroppedByCancellation() {
    var touch = TouchInput()
    let order = InputRules.TouchOrder(
      command: .rightGoes, point: InputRules.ScreenPoint(x: 0.5, y: 0.5, aspect: 2))
    touch.setOrder(order, generation: 0)
    #expect(touch.sample().touchOrder == order)
    #expect(touch.sample().touchOrder == nil)
    touch.setOrder(order, generation: 0)
    touch.cancel()
    #expect(touch.sample().touchOrder == nil)
    touch.setOrder(order, generation: 0)
    #expect(touch.sample().touchOrder == nil, "an old capture's order is rejected")
  }

  @Test
  func theMenuMarkIsSampledOnceAndDroppedByCancellation() {
    var touch = TouchInput()
    let point = InputRules.ScreenPoint(x: 0.3, y: 0.4, aspect: 2)
    touch.setMark(point, generation: 0)
    #expect(touch.sample().touchMark == point)
    #expect(touch.sample().touchMark == nil)
    touch.setMark(point, generation: 0)
    touch.cancel()
    #expect(touch.sample().touchMark == nil)
  }

  // MARK: - The order press (ADR 0003, phase S3)

  @Test
  func aQuickTapOnTheGroundGivesNoOrder() {
    var press = OrderPress(at: CGPoint(x: 100, y: 100), time: 10)
    let opened = press.open(at: 10.2)
    #expect(!opened)
    #expect(press.release == nil)
  }

  @Test
  func holdingStillOpensTheMenuOnBoth() {
    var press = OrderPress(at: CGPoint(x: 100, y: 100), time: 10)
    press.move(to: CGPoint(x: 106, y: 104))
    let opened = press.open(at: 10 + OrderPress.holdTime)
    #expect(opened)
    let openedAgain = press.open(at: 11)
    #expect(!openedAgain, "it opens once")
    #expect(press.release == .both)
  }

  @Test
  func movingBeforeTheMenuOpensCancelsIt() {
    var press = OrderPress(at: CGPoint(x: 100, y: 100), time: 10)
    press.move(to: CGPoint(x: 100, y: 100 + OrderPress.slop + 1))
    let opened = press.open(at: 11)
    #expect(!opened)
    press.move(to: CGPoint(x: 100, y: 100))
    #expect(press.release == nil)
  }

  @Test(arguments: [
    (CGVector(dx: 10, dy: -12), OrderPress.Choice?.some(.both)),
    (CGVector(dx: -80, dy: 10), .left),
    (CGVector(dx: 70, dy: -20), .right),
    (CGVector(dx: 15, dy: 60), .hold),
    (CGVector(dx: -10, dy: -60), nil),
  ])
  func slidingChoosesTheItemInThatDirection(offset: CGVector, choice: OrderPress.Choice?) {
    var press = OrderPress(at: CGPoint(x: 200, y: 150), time: 0)
    let opened = press.open(at: 1)
    #expect(opened)
    press.move(to: CGPoint(x: 200 + offset.dx, y: 150 + offset.dy))
    #expect(press.release == choice)
  }

  @Test
  func aStoppedPressGivesNoOrder() {
    var press = OrderPress(at: CGPoint(x: 100, y: 100), time: 0)
    let opened = press.open(at: 1)
    #expect(opened)
    press.move(to: CGPoint(x: 160, y: 100))
    press.cancel()
    #expect(press.release == nil)
    #expect(OrderPress.Choice.right.command == .rightGoes)
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
