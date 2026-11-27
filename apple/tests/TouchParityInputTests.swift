import CoreGraphics
import Testing
import UIKit

@testable import Lauder

struct TouchParityInputTests {
  private var tap: InputRules.TargetCommand {
    .tap(.init(point: .init(x: 0.5, y: 0.25, aspect: 2), viewHeight: 428))
  }

  @Test(arguments: [0.1, 0.349])
  func aQuickStationaryPressBecomesATapAndNeverAnOrder(duration: Double) {
    var press = OrderPress(at: CGPoint(x: 100, y: 100), time: 0)
    press.move(to: CGPoint(x: 104, y: 97))
    let tapped = press.end(at: CGPoint(x: 112, y: 100), time: duration)
    #expect(tapped)
    #expect(press.release == nil && !press.isOpen)
    #expect(press.start == CGPoint(x: 100, y: 100))
  }

  @Test
  func aHoldOrALateMenuTimerCannotBecomeATargetTap() {
    var held = OrderPress(at: CGPoint(x: 100, y: 100), time: 0)
    let opened = held.open(at: OrderPress.holdTime)
    #expect(opened)
    let tapped = held.end(at: CGPoint(x: 40, y: 100), time: 0.5)
    #expect(!tapped && held.release == .left)

    var delayed = OrderPress(at: CGPoint(x: 100, y: 100), time: 0)
    let delayedTap = delayed.end(at: CGPoint(x: 100, y: 100), time: OrderPress.holdTime)
    #expect(!delayedTap && delayed.release == nil)
  }

  @Test
  func anOverdueMenuTaskCannotTurnAShortTouchIntoASquadOrder() {
    let start = CGPoint(x: 100, y: 100)
    var press = OrderPress(at: start, time: 0)
    let opened = press.open(at: 1)
    #expect(opened)
    // The task was handled first, but UIKit's release timestamp still describes a short tap.
    let tapped = press.end(at: CGPoint(x: 104, y: 103), time: 0.2)
    #expect(tapped && !press.isOpen && press.release == nil)
  }

  @Test
  func aLargeExcursionHandledAfterAnOverdueTaskCannotBecomeATapOnReturn() {
    let start = CGPoint(x: 100, y: 100)
    var press = OrderPress(at: start, time: 0)
    let opened = press.open(at: 1)
    #expect(opened)
    press.move(to: CGPoint(x: 140, y: 100))
    let tapped = press.end(at: start, time: 0.2)
    #expect(!tapped && press.isCancelled && press.release == nil)
  }

  @Test(arguments: [OrderPress.Choice.attack, .defend])
  func returningOnlyOnReleaseClearsAHeldStanceWithoutBecomingATap(stance: OrderPress.Choice) {
    let start = CGPoint(x: 200, y: 150)
    var press = OrderPress(at: start, time: 0)
    let opened = press.open(at: 1)
    #expect(opened)
    press.move(to: CGPoint(x: start.x + (stance == .attack ? -60 : 60), y: 100))
    #expect(press.release == stance)
    let tapped = press.end(at: start, time: 1.2)
    #expect(!tapped && press.release == .both)
  }

  @Test
  func aDragAndAnEndOnlyMovementCannotSlipThroughAsTaps() {
    var drag = OrderPress(at: CGPoint(x: 100, y: 100), time: 0)
    drag.move(to: CGPoint(x: 113, y: 100))
    let returnedTap = drag.end(at: CGPoint(x: 100, y: 100), time: 0.1)
    #expect(!returnedTap && drag.isCancelled && drag.release == nil)

    var endOnly = OrderPress(at: CGPoint(x: 100, y: 100), time: 0)
    let endOnlyTap = endOnly.end(at: CGPoint(x: 100, y: 113), time: 0.1)
    #expect(!endOnlyTap && endOnly.isCancelled && endOnly.release == nil)
  }

  @Test
  func invalidAndCancelledCapturesCannotBecomeTaps() {
    var stopped = OrderPress(at: CGPoint(x: 100, y: 100), time: 0)
    stopped.cancel()
    let stoppedTap = stopped.end(at: CGPoint(x: 100, y: 100), time: 0.1)
    #expect(!stoppedTap && stopped.release == nil)
    for time: Double in [-1, .nan, .infinity] {
      var press = OrderPress(at: CGPoint(x: 100, y: 100), time: 0)
      let tapped = press.end(at: CGPoint(x: 100, y: 100), time: time)
      #expect(!tapped && press.isCancelled)
    }
    var invalidPoint = OrderPress(at: CGPoint(x: 100, y: 100), time: 0)
    let invalidTap = invalidPoint.end(at: CGPoint(x: CGFloat.nan, y: 100), time: 0.1)
    #expect(!invalidTap && invalidPoint.isCancelled)
  }

  @Test
  func aTargetEventIsConsumedOnceWhileTheOtherFingerKeepsMoving() {
    var touch = TouchInput()
    touch.setStick([0.5, 0], isTouching: true, generation: 0)
    touch.setTarget(tap, generation: 0)
    var state = InputRules.State(needsNeutralInput: false)
    let first = InputRules.resolve(touch.sample(), mode: .exploring, state: state)
    state = first.state
    #expect(first.input.targetCommand == tap && first.input.movement == [0.5, 0])
    #expect(!first.input.fireHeld && !first.input.firePressed && !first.input.lockPressed)
    let next = InputRules.resolve(touch.sample(), mode: .exploring, state: state).input
    #expect(next.targetCommand == nil && next.movement == [0.5, 0])
  }

  @Test
  func cancellingTheSourceDropsQueuedAndStaleTargetCallbacks() {
    var touch = TouchInput()
    touch.setTarget(tap, generation: 0)
    touch.setButton(.panel, isPressed: true, generation: 0)
    touch.cancel()
    #expect(touch.sample() == InputRules.Raw())
    touch.setTarget(.acquire, generation: 0)
    #expect(touch.sample().touchTarget == nil)
    touch.setTarget(.next, generation: touch.generation)
    #expect(touch.sample().touchTarget == .next)
    #expect(touch.sample().touchTarget == nil)
  }

  @Test(arguments: [GameSession.Mode.paused, .dialogue])
  func aNonPlayingModeConsumesATargetWithoutReplayingIt(mode: GameSession.Mode) {
    var touch = TouchInput()
    touch.setTarget(tap, generation: 0)
    let state = InputRules.State(needsNeutralInput: false)
    let consumed = InputRules.resolve(touch.sample(), mode: mode, state: state)
    #expect(consumed.input == .neutral)
    let resumed = InputRules.resolve(touch.sample(), mode: .exploring, state: consumed.state)
    #expect(resumed.input.targetCommand == nil)
  }

  @Test
  func aTapDuringTheReleaseGateIsDroppedUntilEveryFingerLifts() {
    var touch = TouchInput()
    touch.setStick(.zero, isTouching: true, generation: 0)
    touch.setTarget(tap, generation: 0)
    var result = InputRules.resolve(touch.sample(), mode: .exploring, state: .init())
    #expect(result.input == .neutral && result.state.needsNeutralInput)
    touch.setStick(.zero, isTouching: false, generation: 0)
    result = InputRules.resolve(touch.sample(), mode: .exploring, state: result.state)
    #expect(result.input == .neutral && !result.state.needsNeutralInput)
    touch.setTarget(tap, generation: 0)
    result = InputRules.resolve(touch.sample(), mode: .exploring, state: result.state)
    #expect(result.input.targetCommand == tap)
  }

  @Test(arguments: [
    InputRules.Raw(touchPause: true),
    InputRules.Raw(touchSwitch: true),
    InputRules.Raw(touchFormation: true),
    InputRules.Raw(touchOrder: .init(command: .defend, point: nil)),
    InputRules.Raw(controllerLock: true),
    InputRules.Raw(keyboardLock: true),
  ])
  func aHigherPriorityCommandConsumesASimultaneousTarget(raw: InputRules.Raw) {
    var raw = raw
    raw.touchTarget = tap
    let result = InputRules.resolve(raw, mode: .exploring, state: .init(needsNeutralInput: false))
    #expect(result.input.targetCommand == nil)
    if raw.controllerLock || raw.keyboardLock { #expect(result.input.lockPressed) }
    let next = InputRules.resolve(.init(), mode: .exploring, state: result.state)
    #expect(next.input.targetCommand == nil)
  }

  @Test
  func theTouchPanelToggleActsOnlyOnAFreshPausedPress() {
    var state = InputRules.State(needsNeutralInput: false)
    func resolve(_ raw: InputRules.Raw, mode: GameSession.Mode) -> InputRules.Input {
      let result = InputRules.resolve(raw, mode: mode, state: state)
      state = result.state
      return result.input
    }
    #expect(!resolve(.init(touchPanel: true), mode: .exploring).panelPressed)
    #expect(!resolve(.init(touchPanel: true), mode: .paused).panelPressed)
    _ = resolve(.init(), mode: .paused)
    #expect(resolve(.init(touchPanel: true), mode: .paused).panelPressed)
    #expect(!resolve(.init(touchPanel: true), mode: .paused).panelPressed)
    _ = resolve(.init(), mode: .dialogue)
    #expect(!resolve(.init(touchPanel: true), mode: .dialogue).panelPressed)
    #expect(!resolve(.init(touchPanel: true), mode: .paused).panelPressed)

    var touch = TouchInput()
    touch.setButton(.panel, isPressed: true, generation: 0)
    touch.setButton(.panel, isPressed: false, generation: 0)
    #expect(touch.sample().touchPanel)
    #expect(!touch.sample().touchPanel)
  }
}

@MainActor
struct TouchParitySurfaceTests {
  @Test(arguments: [CGSize(width: 926, height: 428), CGSize(width: 874, height: 402)])
  func anInsetMountedSurfaceUsesTheFullWindowViewportForTargetTaps(size: CGSize) throws {
    let scene = try #require(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let window = UIWindow(windowScene: scene)
    window.frame = CGRect(origin: .zero, size: size)
    // Keep this isolated window hidden: the fixture must not replace the app's key window.
    defer { withExtendedLifetime(window) {} }
    let container = UIView(
      frame: CGRect(x: 12, y: 7, width: size.width - 24, height: size.height - 14))
    window.addSubview(container)
    let surface = TouchControls.Surface(controls: GameControls())
    surface.frame = CGRect(x: 35, y: 13, width: size.width - 94, height: size.height - 50)
    container.addSubview(surface)
    // The nested inset puts the surface at window (47,20). A finger over the rendered
    // viewport's (30%,60%) point must retain those coordinates rather than its local fractions.
    let localPoint = CGPoint(x: size.width * 0.3 - 47, y: size.height * 0.6 - 20)
    let tap = try #require(surface.targetTap(at: localPoint))
    #expect(abs(tap.point.x - 0.3) < 0.00001)
    #expect(abs(tap.point.y - 0.6) < 0.00001)
    #expect(abs(tap.point.aspect - Float(size.width / size.height)) < 0.00001)
    #expect(tap.viewHeight == Float(window.bounds.height))
    #expect(tap.viewHeight != Float(surface.bounds.height))
    #expect(window.isHidden, "the fixture does not take over the active window")
    #expect(!window.isKeyWindow)
  }

  @Test
  func anUnmountedSurfaceDoesNotInventATargetViewportFromItsOwnBounds() {
    let surface = TouchControls.Surface(controls: GameControls())
    surface.frame = CGRect(x: 47, y: 0, width: 832, height: 407)
    #expect(surface.window == nil)
    #expect(surface.targetTap(at: CGPoint(x: 400, y: 200)) == nil)
  }

  @Test
  func groundTapsAreOfferedWithoutOrdersOnlyDuringPlay() {
    let controls = GameControls()
    let surface = TouchControls.Surface(controls: controls)
    surface.frame = CGRect(x: 0, y: 0, width: 926, height: 428)
    update(surface, mode: .exploring, generation: 0, orders: nil)
    surface.layoutIfNeeded()
    #expect(surface.hitTest(CGPoint(x: 400, y: 100), with: nil) === surface)
    #expect(surface.hitTest(CGPoint(x: 850, y: 100), with: nil) == nil)
    update(surface, mode: .paused, generation: 0, orders: nil)
    #expect(surface.hitTest(CGPoint(x: 400, y: 100), with: nil) == nil)
    update(surface, mode: .dialogue, generation: 0, orders: nil)
    #expect(surface.hitTest(CGPoint(x: 400, y: 100), with: nil) == nil)
  }

  @Test
  func fireHidesForDialogueAndThePanelToggleAppearsOnlyOnPause() throws {
    let surface = TouchControls.Surface(controls: GameControls())
    update(surface, mode: .exploring, generation: 0)
    let fire = try #require(surface.subviews.first { $0.accessibilityLabel == "Fire" })
    let panel = try #require(surface.subviews.first { $0.accessibilityLabel == "Status panel: On" })
    #expect(!fire.isHidden && panel.isHidden)
    update(surface, mode: .dialogue, generation: 0)
    #expect(fire.isHidden && panel.isHidden && fire.accessibilityCustomActions == nil)
    update(surface, mode: .paused, generation: 0)
    #expect(fire.isHidden && !panel.isHidden)
    surface.frame = CGRect(x: 0, y: 0, width: 926, height: 428)
    surface.layoutIfNeeded()
    let vibration = try #require(
      surface.subviews.first { $0.accessibilityLabel == "Vibration: On" })
    #expect(panel.frame.maxX < vibration.frame.minX)
    #expect(panel.frame.width >= 44 && panel.frame.height >= 44)
  }

  @Test
  func accessibleTargetActionsUseTheSameOneShotPathWithoutFiring() throws {
    let controls = activeTouchControls()
    defer { controls.setActive(false) }
    let surface = TouchControls.Surface(controls: controls)
    // Keep the view alive: its accessibility handlers intentionally retain it weakly.
    defer { withExtendedLifetime(surface) {} }
    update(surface, mode: .exploring, generation: controls.touchGeneration, orders: nil)
    let fire = try #require(surface.subviews.first { $0.accessibilityLabel == "Fire" })
    let actions = try #require(fire.accessibilityCustomActions)
    #expect(actions.map(\.name) == ["Target", "Next target", "Let go"])
    controls.setTouchStick([0.5, 0], isTouching: true, generation: controls.touchGeneration)
    for (action, expected) in zip(actions, [InputRules.TargetCommand.acquire, .next, .release]) {
      let handler = try #require(action.actionHandler)
      #expect(handler(action))
      let input = controls.sample(mode: .exploring)
      #expect(input.targetCommand == expected && input.movement == [0.5, 0])
      #expect(!input.fireHeld && !input.firePressed)
      #expect(controls.sample(mode: .exploring).targetCommand == nil)
    }
    update(surface, mode: .paused, generation: controls.touchGeneration, orders: nil)
    let action = try #require(actions.first)
    #expect(action.actionHandler?(action) == false)
    #expect(controls.sample(mode: .paused).targetCommand == nil)
  }

  @Test
  func accessibleOrdersUseCurrentNamesAndTheExistingAheadOrHoldCommands() throws {
    let controls = activeTouchControls()
    defer { controls.setActive(false) }
    let surface = TouchControls.Surface(controls: controls)
    // Keep the view alive: its accessibility handlers intentionally retain it weakly.
    defer { withExtendedLifetime(surface) {} }
    update(surface, mode: .exploring, generation: controls.touchGeneration)
    let formation = try #require(surface.subviews.first { $0.accessibilityLabel == "Formation" })
    let actions = try #require(formation.accessibilityCustomActions)
    let commands: [GameSession.Command] = [.attack, .defend, .leftGoes, .rightGoes, .bothGo, .hold]
    #expect(
      actions.map(\.name) == [
        "Squad Attack", "Squad Defend", "Send Tom ahead", "Send Laura ahead", "Send both ahead",
        "Hold positions",
      ])
    for (action, expected) in zip(actions, commands) {
      let handler = try #require(action.actionHandler)
      #expect(handler(action))
      let input = controls.sample(mode: .exploring)
      #expect(input.command == expected && input.commandPoint == nil)
      #expect(controls.sample(mode: .exploring).command == nil)
    }
  }

  @Test
  func staleAccessibleCallbacksCannotTargetAfterSourceCancellation() throws {
    let controls = activeTouchControls()
    defer { controls.setActive(false) }
    let surface = TouchControls.Surface(controls: controls)
    // Keep the view alive: its accessibility handlers intentionally retain it weakly.
    defer { withExtendedLifetime(surface) {} }
    update(surface, mode: .exploring, generation: controls.touchGeneration)
    let fire = try #require(surface.subviews.first { $0.accessibilityLabel == "Fire" })
    let action = try #require(fire.accessibilityCustomActions?.first)
    let oldGeneration = controls.touchGeneration
    controls.setActive(false)
    controls.setActive(true)
    controls.useTouchControls()
    _ = controls.sample(mode: .exploring)
    #expect(controls.touchGeneration != oldGeneration)
    #expect(action.actionHandler?(action) == false)
    controls.setTouchTarget(.acquire, generation: oldGeneration)
    #expect(controls.sample(mode: .exploring).targetCommand == nil)
  }

  private func activeTouchControls() -> GameControls {
    let controls = GameControls()
    controls.setActive(true)
    controls.useTouchControls()
    _ = controls.sample(mode: .exploring)
    #expect(!controls.needsNeutralInput)
    return controls
  }

  private func update(
    _ surface: TouchControls.Surface, mode: GameSession.Mode, generation: Int,
    orders: (String, String)? = ("Tom", "Laura")
  ) {
    surface.update(
      actionTitle: "Look", nextLeaderName: "Tom", showsFire: true, swapTitle: "Assault rifle",
      showsFormation: true, formationTitle: "Formation", orderNames: orders,
      vibrationTitle: "Vibration: On", panelTitle: "Status panel: On", mode: mode,
      generation: generation)
  }
}
