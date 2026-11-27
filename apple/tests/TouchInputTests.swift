import CoreGraphics
import Testing
import UIKit
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
    (CGVector(dx: -30, dy: -60), nil),
    (CGVector(dx: 30, dy: -60), nil),
    (CGVector(dx: -40, dy: -60), .attack),
    (CGVector(dx: 40, dy: -60), .defend),
    (CGVector(dx: -98, dy: -62), .attack),
    (CGVector(dx: 98, dy: -62), .defend),
    (CGVector(dx: -110, dy: -60), .attack),
    (CGVector(dx: 110, dy: -60), .defend),
    (CGVector(dx: -30, dy: -20), .both),
    (CGVector(dx: 30, dy: -20), .both),
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

  @Test(arguments: [
    (CGPoint(x: 200, y: 30), CGVector(dx: -60, dy: 0), OrderPress.Choice.left),
    (CGPoint(x: 200, y: 30), CGVector(dx: 60, dy: 0), .right),
    (CGPoint(x: 200, y: 280), CGVector(dx: -60, dy: 0), .left),
    (CGPoint(x: 200, y: 280), CGVector(dx: 60, dy: 0), .right),
    (CGPoint(x: 20, y: 150), CGVector(dx: 60, dy: 0), .right),
    (CGPoint(x: 380, y: 150), CGVector(dx: -60, dy: 0), .left),
  ])
  func anUnclampedMenuKeepsSidewaysTravelOutsideBothSelectingACompanion(
    start: CGPoint, offset: CGVector, expected: OrderPress.Choice
  ) {
    // Without surface bounds, the menu remains centred on the finger. Actual clamping and
    // visible-item releases are exercised by TouchOrderSurfaceTests.
    var press = OrderPress(at: start, time: 0)
    let opened = press.open(at: 1)
    #expect(opened)
    press.move(to: CGPoint(x: start.x + offset.dx, y: start.y + offset.dy))
    #expect(press.release == expected)
    #expect(press.start == start, "selection never moves the marked ground point")
  }

  @Test(arguments: [CGFloat(0), 5, 15])
  func anExtremeTopPressUsesVisibleItemsAndKeepsReturnAndCancellationSafe(y: CGFloat) {
    let start = CGPoint(x: 200, y: y)
    var press = OrderPress(at: start, time: 0)
    let opened = press.open(at: 1, in: CGRect(x: 0, y: 0, width: 400, height: 300))
    #expect(opened)
    // Clamping puts the visible stance items beside a very high finger. Those items win,
    // while returning to the original finger or cancelling still clears the selection.
    press.move(to: CGPoint(x: 260, y: y))
    #expect(press.release == .defend)
    press.move(to: CGPoint(x: 140, y: y))
    #expect(press.release == .attack)
    press.move(to: CGPoint(x: 203, y: y))
    #expect(press.release == .both)
    press.move(to: CGPoint(x: 200, y: 0))
    #expect(press.release == .both, "short upward travel cannot arm a stance")
    press.cancel()
    #expect(press.release == nil, "a cancelled touch never sends the prior choice")
  }

  @Test(arguments: [OrderPress.Choice.attack, .defend])
  func returningToTheFingerStartClearsAStanceEvenNearTheTopEdge(stance: OrderPress.Choice) {
    let start = CGPoint(x: 200, y: 40)
    var press = OrderPress(at: start, time: 0)
    let opened = press.open(at: 1)
    #expect(opened)
    press.move(to: CGPoint(x: start.x + (stance == .attack ? -40 : 40), y: 9))
    #expect(press.release == stance)
    press.move(to: CGPoint(x: start.x + 3, y: start.y + 1))
    #expect(press.release == .both && press.release?.command == .bothGo)
    press.move(to: CGPoint(x: start.x + 20, y: start.y - 10))
    #expect(press.release == .both, "the entire centre radius clears a previous choice")
    press.cancel()
    #expect(press.release == nil)
  }

  @Test(arguments: [GameSession.Command.attack, .defend])
  func touchStancesAreSingleEventsAndCannotSurviveSourceCancellation(command: GameSession.Command) {
    var touch = TouchInput()
    let order = InputRules.TouchOrder(command: command, point: nil)
    touch.setOrder(order, generation: 0)
    #expect(touch.sample().touchOrder == order)
    #expect(touch.sample().touchOrder == nil)
    touch.setOrder(order, generation: 0)
    touch.cancel()
    touch.setOrder(order, generation: 0)
    #expect(touch.sample().touchOrder == nil)
    touch.setOrder(order, generation: touch.generation)
    var state = InputRules.State()
    let gated = InputRules.resolve(touch.sample(), mode: .exploring, state: state)
    state = gated.state
    #expect(gated.input.command == nil)
    #expect(InputRules.resolve(touch.sample(), mode: .exploring, state: state).input.command == nil)
  }

  @MainActor
  @Test
  func stanceAccessibilityActionsUseTheExistingFormationControlOnlyDuringPlay() throws {
    let surface = TouchControls.Surface(controls: GameControls())
    func update(_ mode: GameSession.Mode) {
      surface.update(
        actionTitle: "Look", nextLeaderName: "Tom", showsFire: true, swapTitle: "Assault rifle",
        showsFormation: true, formationTitle: "Formation", orderNames: ("Tom", "Laura"),
        vibrationTitle: "Vibration: On", panelTitle: "Status panel: On", mode: mode, generation: 0)
    }
    update(.exploring)
    let formation = try #require(surface.subviews.first { $0.accessibilityLabel == "Formation" })
    #expect(
      formation.accessibilityCustomActions?.map(\.name) == [
        "Squad Attack", "Squad Defend", "Send Tom ahead", "Send Laura ahead", "Send both ahead",
        "Hold positions",
      ])
    update(.paused)
    #expect(formation.accessibilityCustomActions == nil)
    update(.dialogue)
    #expect(formation.accessibilityCustomActions == nil)
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
