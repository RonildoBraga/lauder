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
    // While paused the action confirms the menu's choice and the switch does nothing. Neither
    // carries over into exploring.
    let paused = sample(held, mode: .paused, state: &state)
    #expect(paused.actionPressed)
    #expect(!paused.switchPressed)
    #expect(sample(held, state: &state) == .neutral)
    #expect(sample(.init(), state: &state) == .neutral)
    #expect(sample(.init(keyboardSwitch: true), state: &state).switchPressed)
  }

  @Test
  func aConversationTakesFreshActionPressesAndNothingElse() {
    var state = InputRules.State(needsNeutralInput: false)
    let raw = InputRules.Raw(stick: [1, 0], controllerAction: true, controllerSwitch: true)
    let first = sample(raw, mode: .dialogue, state: &state)
    #expect(first.actionPressed)
    #expect(!first.switchPressed)
    #expect(first.movement == .zero)
    // A held action shows no further line, and the held switch never reaches exploring.
    #expect(sample(raw, mode: .dialogue, state: &state) == .neutral)
    let after = sample(raw, state: &state)
    #expect(!after.switchPressed)
    #expect(!after.actionPressed)
  }

  @Test(arguments: [false, true])
  func thePauseMenuMovesOnFreshUpAndDownPresses(keyboard: Bool) {
    var state = InputRules.State(needsNeutralInput: false)
    let down = keyboard ? InputRules.Raw(down: true) : InputRules.Raw(stick: [0, -1])
    let up = keyboard ? InputRules.Raw(up: true) : InputRules.Raw(stick: [0, 1])
    let moved = sample(down, mode: .paused, state: &state)
    #expect(moved.menuMove == 1)
    #expect(moved.movement == .zero)
    #expect(sample(down, mode: .paused, state: &state).menuMove == 0)
    #expect(sample(up, mode: .paused, state: &state).menuMove == -1)
    #expect(sample(.init(), mode: .paused, state: &state).menuMove == 0)
    // A sideways or shallow push does not move the choice.
    #expect(sample(.init(stick: [0.9, -0.3]), mode: .paused, state: &state).menuMove == 0)
  }

  @Test
  func aDirectionHeldWhenPausingDoesNotMoveTheMenu() {
    var state = InputRules.State(needsNeutralInput: false)
    #expect(sample(.init(controllerPause: true, down: true), state: &state).pausePressed)
    #expect(sample(.init(down: true), mode: .paused, state: &state).menuMove == 0)
  }

  @Test
  func theTouchRestartButtonActsOnlyInThePauseMenu() {
    var state = InputRules.State(needsNeutralInput: false)
    let restart = InputRules.Raw(touchRestart: true)
    #expect(sample(restart, state: &state) == .neutral)
    #expect(sample(.init(), state: &state) == .neutral)
    #expect(sample(restart, mode: .dialogue, state: &state) == .neutral)
    #expect(sample(.init(), mode: .paused, state: &state) == .neutral)
    #expect(sample(restart, mode: .paused, state: &state).restartPressed)
    #expect(!sample(restart, mode: .paused, state: &state).restartPressed)
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
    let paused = sample(held, mode: .paused, state: &state)
    #expect(paused.actionPressed)
    #expect(!paused.switchPressed)
    #expect(paused.movement == .zero)
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
    InputRules.Raw(touchRestart: true),
    InputRules.Raw(controllerFormation: true),
    InputRules.Raw(keyboardFormation: true),
    InputRules.Raw(touchFormation: true),
    InputRules.Raw(dpadUp: true),
    InputRules.Raw(dpadDown: true),
    InputRules.Raw(dpadLeft: true),
    InputRules.Raw(dpadRight: true),
    InputRules.Raw(arrowUp: true),
    InputRules.Raw(arrowLeft: true),
    InputRules.Raw(touchGround: true),
    InputRules.Raw(controllerPrevious: true),
    InputRules.Raw(keyboardPrevious: true),
    InputRules.Raw(controllerSignature: true),
    InputRules.Raw(keyboardSignature: true),
    InputRules.Raw(touchSignature: true),
    InputRules.Raw(touchOtherLevel: true),
    InputRules.Raw(touchVibration: true),
  ])
  func everyGameplayButtonKeepsTheReleaseGateClosed(raw: InputRules.Raw) {
    var state = InputRules.State()
    #expect(sample(raw, state: &state) == .neutral)
    #expect(state.needsNeutralInput)
    #expect(sample(.init(), state: &state) == .neutral)
    #expect(!state.needsNeutralInput)
  }

  // MARK: - The formation button (ADR 0003, phase S2)

  @Test(arguments: [
    InputRules.Raw(controllerFormation: true),
    InputRules.Raw(keyboardFormation: true),
    InputRules.Raw(touchFormation: true),
  ])
  func eachFormationPressCountsOnce(raw: InputRules.Raw) {
    var state = InputRules.State(needsNeutralInput: false)
    #expect(sample(raw, state: &state).formationPressed)
    #expect(!sample(raw, state: &state).formationPressed, "a held button does not repeat")
    #expect(!sample(.init(), state: &state).formationPressed)
    #expect(sample(raw, state: &state).formationPressed)
  }

  @Test
  func theFormationKeyIsKeyboardInput() {
    #expect(InputRules.Raw(keyboardFormation: true).hasKeyboardInput)
  }

  @Test
  func aFormationPressDiscardsAnActionInTheSameSample() {
    var state = InputRules.State(needsNeutralInput: false)
    var raw = InputRules.Raw(stick: [0.5, 0], controllerAction: true, controllerFormation: true)
    let pressed = sample(raw, state: &state)
    #expect(pressed.formationPressed)
    #expect(!pressed.actionPressed)
    #expect(pressed.movement == [0.5, 0])
    // The held action does not act once the formation button lifts; it needs a fresh press.
    raw.controllerFormation = false
    #expect(!sample(raw, state: &state).actionPressed)
    raw.controllerAction = false
    #expect(!sample(raw, state: &state).actionPressed)
    raw.controllerAction = true
    #expect(sample(raw, state: &state).actionPressed)
  }

  @Test
  func switchAndFormationPressedTogetherBothCount() {
    var state = InputRules.State(needsNeutralInput: false)
    let both = sample(.init(keyboardSwitch: true, keyboardFormation: true), state: &state)
    #expect(both.switchPressed)
    #expect(both.formationPressed)
  }

  @Test(arguments: [GameSession.Mode.paused, .dialogue])
  func pausedAndTalkingConsumeFormationPresses(mode: GameSession.Mode) {
    var state = InputRules.State(needsNeutralInput: false)
    let held = InputRules.Raw(controllerFormation: true)
    #expect(!sample(held, mode: mode, state: &state).formationPressed)
    // Still held when play resumes: it was consumed, not queued.
    #expect(!sample(held, state: &state).formationPressed)
    #expect(!sample(.init(), state: &state).formationPressed)
    #expect(sample(held, state: &state).formationPressed)
  }

  // MARK: - The panel button

  @Test(arguments: [InputRules.Raw(controllerPanel: true), InputRules.Raw(keyboardPanel: true)])
  func eachPanelPressCountsOnce(raw: InputRules.Raw) {
    var state = InputRules.State(needsNeutralInput: false)
    #expect(sample(raw, state: &state).panelPressed)
    #expect(!sample(raw, state: &state).panelPressed, "a held button does not repeat")
    #expect(!sample(.init(), state: &state).panelPressed)
    #expect(sample(raw, state: &state).panelPressed)
    // In a conversation it works too, so the panel can be hidden while people talk.
    #expect(!sample(.init(), state: &state).panelPressed)
    #expect(sample(raw, mode: .dialogue, state: &state).panelPressed)
  }

  @Test
  func thePanelKeyIsKeyboardInputAndHoldsTheReleaseGate() {
    #expect(InputRules.Raw(keyboardPanel: true).hasKeyboardInput)
    var state = InputRules.State()
    let held = InputRules.Raw(controllerPanel: true)
    #expect(!sample(held, state: &state).panelPressed)
    #expect(state.needsNeutralInput, "a held panel button keeps the gate closed")
    _ = sample(.init(), state: &state)
    #expect(!state.needsNeutralInput)
    #expect(sample(held, state: &state).panelPressed)
  }

  /// The panel button, like the controller's other buttons and its stick, shows the controller as
  /// the source again; a stick inside the dead zone, the keyboard and touch do not.
  @Test
  func thePanelButtonIsControllerInput() {
    #expect(InputRules.Raw(controllerPanel: true).hasControllerInput)
    for raw in [
      InputRules.Raw(controllerAction: true), .init(dpadUp: true), .init(stick: [0, 0.5]),
    ] {
      #expect(raw.hasControllerInput)
    }
    #expect(!InputRules.Raw(stick: [0.1, 0]).hasControllerInput)
    #expect(!InputRules.Raw(keyboardPanel: true).hasControllerInput)
    #expect(!InputRules.Raw(touchAction: true).hasControllerInput)
  }

  @Test
  func thePauseMenuConsumesPanelPresses() {
    var state = InputRules.State(needsNeutralInput: false)
    let held = InputRules.Raw(controllerPanel: true)
    #expect(!sample(held, mode: .paused, state: &state).panelPressed)
    // Still held when play resumes: it was consumed, not queued.
    #expect(!sample(held, state: &state).panelPressed)
  }

  // MARK: - Squad orders (ADR 0003, phase S3)

  private static let touchPoint = InputRules.ScreenPoint(x: 0.4, y: 0.6, aspect: 2)

  @Test(arguments: [
    (InputRules.Raw(dpadUp: true), GameSession.Command.bothGo),
    (InputRules.Raw(dpadDown: true), .hold),
    (InputRules.Raw(dpadLeft: true), .leftGoes),
    (InputRules.Raw(dpadRight: true), .rightGoes),
    (InputRules.Raw(arrowUp: true), .bothGo),
    (InputRules.Raw(arrowDown: true), .hold),
    (InputRules.Raw(arrowLeft: true), .leftGoes),
    (InputRules.Raw(arrowRight: true), .rightGoes),
  ])
  func eachDirectionGivesItsOrderOnce(raw: InputRules.Raw, command: GameSession.Command) {
    var state = InputRules.State(needsNeutralInput: false)
    let pressed = sample(raw, state: &state)
    #expect(pressed.command == command)
    #expect(pressed.commandPoint == nil, "the point lies ahead of the leader")
    #expect(sample(raw, state: &state).command == nil, "a held direction does not repeat")
    #expect(sample(.init(), state: &state).command == nil)
    #expect(sample(raw, state: &state).command == command)
  }

  @Test
  func theArrowKeysAreKeyboardInputAndTheDpadIsNot() {
    #expect(InputRules.Raw(arrowRight: true).hasKeyboardInput)
    #expect(!InputRules.Raw(dpadRight: true).hasKeyboardInput)
  }

  @Test
  func aTouchOrderPassesOnceWithItsPoint() {
    var state = InputRules.State(needsNeutralInput: false)
    let order = InputRules.TouchOrder(command: .leftGoes, point: Self.touchPoint)
    let given = sample(.init(touchOrder: order), state: &state)
    #expect(given.command == .leftGoes)
    #expect(given.commandPoint == Self.touchPoint)
    #expect(sample(.init(), state: &state).command == nil)
  }

  @Test(arguments: [GameSession.Mode.exploring, .paused, .dialogue])
  func theMenuMarkPassesOnlyWhileExploring(mode: GameSession.Mode) {
    var state = InputRules.State(needsNeutralInput: false)
    let marked = sample(.init(touchMark: Self.touchPoint), mode: mode, state: &state)
    #expect(marked.markPoint == (mode == .exploring ? Self.touchPoint : nil))
    #expect(sample(.init(), mode: mode, state: &state).markPoint == nil)
  }

  @Test
  func holdComesFirstWhenTwoDirectionsArriveTogether() {
    var state = InputRules.State(needsNeutralInput: false)
    #expect(sample(.init(dpadUp: true, dpadDown: true), state: &state).command == .hold)
    #expect(
      sample(.init(dpadUp: true, dpadDown: true, dpadLeft: true), state: &state).command
        == .leftGoes, "only the fresh direction counts")
  }

  @Test
  func anOrderDiscardsAnActionInTheSameSampleButNotAFormationPress() {
    var state = InputRules.State(needsNeutralInput: false)
    let both = sample(
      .init(controllerAction: true, controllerFormation: true, dpadUp: true), state: &state)
    #expect(both.command == .bothGo)
    #expect(both.formationPressed)
    #expect(!both.actionPressed)
    #expect(!sample(.init(controllerAction: true), state: &state).actionPressed)
  }

  @Test(arguments: [GameSession.Mode.paused, .dialogue])
  func pausedAndTalkingConsumeOrders(mode: GameSession.Mode) {
    var state = InputRules.State(needsNeutralInput: false)
    let held = InputRules.Raw(dpadLeft: true)
    #expect(sample(held, mode: mode, state: &state).command == nil)
    #expect(sample(held, state: &state).command == nil, "consumed, not queued")
    let order = InputRules.TouchOrder(command: .bothGo, point: Self.touchPoint)
    #expect(sample(.init(touchOrder: order), mode: mode, state: &state).command == nil)
    #expect(sample(.init(), state: &state).command == nil)
  }

  @Test(arguments: [false, true])
  func theDpadAndArrowKeysMoveThePauseMenu(keyboard: Bool) {
    var state = InputRules.State(needsNeutralInput: false)
    let down = keyboard ? InputRules.Raw(arrowDown: true) : InputRules.Raw(dpadDown: true)
    let up = keyboard ? InputRules.Raw(arrowUp: true) : InputRules.Raw(dpadUp: true)
    #expect(sample(down, mode: .paused, state: &state).menuMove == 1)
    #expect(sample(down, mode: .paused, state: &state).menuMove == 0)
    #expect(sample(up, mode: .paused, state: &state).menuMove == -1)
  }

  @Test
  func aTouchOrderDuringTheReleaseGateIsDropped() {
    var state = InputRules.State()
    let order = InputRules.TouchOrder(command: .hold, point: Self.touchPoint)
    #expect(sample(.init(touchOrder: order), state: &state) == .neutral)
    #expect(!state.needsNeutralInput, "an order alone is not a held control")
    #expect(sample(.init(), state: &state).command == nil)
  }

  // MARK: - Signature, Previous leader and the pause menu's third choice (ADR 0005)

  @Test(arguments: [
    InputRules.Raw(controllerSignature: true), InputRules.Raw(keyboardSignature: true),
    InputRules.Raw(touchSignature: true),
  ])
  func eachSignaturePressCountsOnceWhileExploring(raw: InputRules.Raw) {
    var state = InputRules.State(needsNeutralInput: false)
    #expect(sample(raw, state: &state).signaturePressed)
    #expect(!sample(raw, state: &state).signaturePressed, "a held button does not repeat")
    #expect(!sample(.init(), state: &state).signaturePressed)
    #expect(sample(raw, state: &state).signaturePressed)
  }

  @Test(arguments: [
    InputRules.Raw(controllerPrevious: true), InputRules.Raw(keyboardPrevious: true),
  ])
  func eachPreviousPressCountsOnceWhileExploring(raw: InputRules.Raw) {
    var state = InputRules.State(needsNeutralInput: false)
    let pressed = sample(raw, state: &state)
    #expect(pressed.previousPressed && !pressed.switchPressed)
    #expect(!sample(raw, state: &state).previousPressed, "a held button does not repeat")
    #expect(!sample(.init(), state: &state).previousPressed)
    #expect(sample(raw, state: &state).previousPressed)
  }

  @Test(arguments: [
    (InputRules.Raw(controllerSignature: true), GameSession.Mode.paused),
    (InputRules.Raw(controllerSignature: true), .dialogue),
    (InputRules.Raw(keyboardPrevious: true), .paused),
    (InputRules.Raw(keyboardPrevious: true), .dialogue),
  ])
  func pausedAndTalkingConsumeSignatureAndPreviousPresses(
    raw: InputRules.Raw, mode: GameSession.Mode
  ) {
    var state = InputRules.State(needsNeutralInput: false)
    let consumed = sample(raw, mode: mode, state: &state)
    #expect(!consumed.signaturePressed && !consumed.previousPressed)
    // Still held when play resumes: it was consumed, not queued.
    let held = sample(raw, state: &state)
    #expect(!held.signaturePressed && !held.previousPressed)
    #expect(sample(.init(), state: &state) == .neutral)
    let fresh = sample(raw, state: &state)
    #expect(fresh.signaturePressed || fresh.previousPressed)
  }

  @Test
  func switchesAndCommandsComeBeforeTheSignatureAndTheSignatureBeforeTheAction() {
    var state = InputRules.State(needsNeutralInput: false)
    // Next wins over Previous in the same sample.
    let both = sample(.init(controllerSwitch: true, controllerPrevious: true), state: &state)
    #expect(both.switchPressed && !both.previousPressed)
    _ = sample(.init(), state: &state)
    // A switch discards a signature and an action pressed with it, until fresh presses.
    let switched = sample(
      .init(controllerAction: true, controllerPrevious: true, controllerSignature: true),
      state: &state)
    #expect(switched.previousPressed && !switched.signaturePressed && !switched.actionPressed)
    #expect(!sample(.init(controllerSignature: true), state: &state).signaturePressed)
    _ = sample(.init(), state: &state)
    // So do a formation press and an order.
    let formed = sample(.init(controllerFormation: true, controllerSignature: true), state: &state)
    #expect(formed.formationPressed && !formed.signaturePressed)
    _ = sample(.init(), state: &state)
    let ordered = sample(.init(controllerSignature: true, dpadUp: true), state: &state)
    #expect(ordered.command == .bothGo && !ordered.signaturePressed)
    _ = sample(.init(), state: &state)
    // The signature discards an action pressed with it.
    let signed = sample(.init(controllerAction: true, controllerSignature: true), state: &state)
    #expect(signed.signaturePressed && !signed.actionPressed)
  }

  @Test
  func signatureAndPreviousAreInputFromTheirOwnSources() {
    for raw in [InputRules.Raw(keyboardPrevious: true), .init(keyboardSignature: true)] {
      #expect(raw.hasKeyboardInput && !raw.hasControllerInput)
    }
    for raw in [InputRules.Raw(controllerPrevious: true), .init(controllerSignature: true)] {
      #expect(raw.hasControllerInput && !raw.hasKeyboardInput)
    }
    #expect(!InputRules.Raw(touchSignature: true).hasControllerInput)
  }

  @Test
  func theTouchButtonForTheThirdChoiceActsOnlyInThePauseMenu() {
    var state = InputRules.State(needsNeutralInput: false)
    let choice = InputRules.Raw(touchOtherLevel: true)
    #expect(sample(choice, state: &state) == .neutral)
    #expect(sample(.init(), state: &state) == .neutral)
    #expect(sample(choice, mode: .dialogue, state: &state) == .neutral)
    #expect(sample(.init(), mode: .paused, state: &state) == .neutral)
    let chosen = sample(choice, mode: .paused, state: &state)
    #expect(chosen.otherLevelPressed && !chosen.actionPressed && !chosen.restartPressed)
    #expect(!sample(choice, mode: .paused, state: &state).otherLevelPressed)
  }

  /// ADR 0008: the touch Vibration button acts only in the pause menu, once for each press,
  /// and not while the release gate waits for a held finger to lift.
  @Test
  func theTouchVibrationButtonActsOnlyInThePauseMenuOnceTheGateIsOpen() {
    let press = InputRules.Raw(touchVibration: true)
    var gated = InputRules.State()
    #expect(!sample(press, mode: .paused, state: &gated).vibrationPressed)
    #expect(gated.needsNeutralInput)
    var state = InputRules.State(needsNeutralInput: false)
    #expect(sample(press, state: &state) == .neutral)
    #expect(sample(.init(), state: &state) == .neutral)
    #expect(sample(press, mode: .dialogue, state: &state) == .neutral)
    #expect(sample(.init(), mode: .paused, state: &state) == .neutral)
    let chosen = sample(press, mode: .paused, state: &state)
    #expect(chosen.vibrationPressed && !chosen.actionPressed && !chosen.otherLevelPressed)
    #expect(!sample(press, mode: .paused, state: &state).vibrationPressed)
  }

  private func sample(
    _ raw: InputRules.Raw, mode: GameSession.Mode = .exploring, state: inout InputRules.State
  ) -> InputRules.Input {
    let result = InputRules.resolve(raw, mode: mode, state: state)
    state = result.state
    return result.input
  }
}
