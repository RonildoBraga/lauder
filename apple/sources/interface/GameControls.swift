import Foundation
import GameController
import Observation

@MainActor
@Observable
final class GameControls {
  enum Status: Equatable {
    case inactive, ready
  }

  typealias Input = InputRules.Input

  private(set) var status = Status.inactive
  private(set) var actionSymbol: String?
  private(set) var sourceName = "Touch controls"
  private(set) var pauseButtonName = "Pause"
  private(set) var attackButtonName = "Attack"
  private(set) var guardButtonName = "Guard"
  private(set) var dodgeButtonName = "Dodge"
  private(set) var focusButtonName = "Focus"
  private(set) var needsNeutralInput = true
  private(set) var touchControlsEnabled = true
  private(set) var hasController = false
  private(set) var touchGeneration = 0

  @ObservationIgnored private var isActive = false
  @ObservationIgnored private var inputState = InputRules.State()
  @ObservationIgnored private var touchInput = TouchInput()
  @ObservationIgnored private(set) var prefersTouch = false
  @ObservationIgnored private var controller: GCController?
  @ObservationIgnored private var gamepad: GCExtendedGamepad?
  @ObservationIgnored private var observations: [NotificationCenter.ObservationToken] = []
  #if DEBUG
    /// Scripted Simulator input still passes through the production rules and release gate.
    @ObservationIgnored var scriptedRaw: InputRules.Raw?
  #endif

  func setActive(_ active: Bool) {
    guard active != isActive else { return }
    isActive = active
    cancelTouches()
    if active {
      requireNeutralInput()
      observeControllers()
      selectController()
    } else {
      observations.forEach(NotificationCenter.default.removeObserver)
      observations.removeAll()
      controller = nil
      gamepad = nil
      hasController = false
      requireNeutralInput()
      status = .inactive
    }
  }

  var activeController: GCController? { touchControlsEnabled ? nil : controller }

  func requireNeutralInput() {
    // Pause must retain centred-stick contacts until every finger lifts.
    inputState = InputRules.State()
    if !needsNeutralInput { needsNeutralInput = true }
  }

  func useTouchControls() {
    prefersTouch = true
    guard !touchControlsEnabled else { return }
    cancelTouches()
    requireNeutralInput()
    touchControlsEnabled = true
    showTouch()
  }

  func useController() {
    guard let gamepad else { return }
    prefersTouch = false
    guard touchControlsEnabled else { return }
    cancelTouches()
    requireNeutralInput()
    touchControlsEnabled = false
    showController(gamepad)
  }

  func setTouchStick(_ movement: SIMD2<Float>, isTouching: Bool, generation: Int) {
    guard isActive, touchControlsEnabled else { return }
    touchInput.setStick(movement, isTouching: isTouching, generation: generation)
  }

  func setTouchButton(_ button: TouchInput.Button, isPressed: Bool, generation: Int) {
    guard isActive, touchControlsEnabled else { return }
    touchInput.setButton(button, isPressed: isPressed, generation: generation)
  }

  private func cancelTouches() {
    touchInput.cancel()
    touchGeneration = touchInput.generation
  }

  func sample(mode: GameSession.Mode) -> Input {
    guard isActive, status == .ready else { return .neutral }
    let keyboard = GCKeyboard.coalesced?.keyboardInput
    func pressed(_ code: GCKeyCode) -> Bool {
      keyboard?.button(forKeyCode: code)?.isPressed ?? false
    }
    let touch = touchControlsEnabled ? touchInput.sample() : InputRules.Raw()
    let pad = touchControlsEnabled ? nil : gamepad
    var raw = InputRules.Raw(
      stick: SIMD2(pad?.leftThumbstick.xAxis.value ?? 0, pad?.leftThumbstick.yAxis.value ?? 0),
      controllerAttack: pad?.rightShoulder.isPressed == true,
      controllerGuard: pad?.leftShoulder.isPressed == true,
      controllerDodge: pad?.buttonB.isPressed == true,
      controllerFocus: pad?.rightThumbstickButton?.isPressed == true,
      controllerPause: pad?.buttonMenu.isPressed == true,
      controllerAction: pad?.buttonA.isPressed == true,
      dpadUp: pad?.dpad.up.isPressed == true, dpadDown: pad?.dpad.down.isPressed == true,
      left: pressed(.keyA), right: pressed(.keyD),
      up: pressed(.keyW), down: pressed(.keyS),
      keyboardAttack: pressed(.keyF), keyboardGuard: pressed(.keyQ),
      keyboardDodge: pressed(.spacebar), keyboardFocus: pressed(.tab),
      keyboardPause: pressed(.escape),
      keyboardAction: pressed(.keyE), arrowUp: pressed(.upArrow), arrowDown: pressed(.downArrow),
      touchStick: touch.touchStick, touchIsTouching: touch.touchIsTouching,
      touchAttack: touch.touchAttack, touchGuard: touch.touchGuard,
      touchDodge: touch.touchDodge, touchFocus: touch.touchFocus, touchPause: touch.touchPause,
      touchRestart: touch.touchRestart)
    #if DEBUG
      if let scriptedRaw { raw = scriptedRaw }
    #endif
    if raw.hasKeyboardInput {
      showKeyboard()
    } else if touchControlsEnabled {
      showTouch()
    } else if let gamepad, raw.hasControllerInput {
      showController(gamepad)
    }
    return resolve(raw, mode: mode)
  }

  /// Headless tests use the same edge history and neutral gate as hardware samples.
  func resolve(_ raw: InputRules.Raw, mode: GameSession.Mode) -> Input {
    let result = InputRules.resolve(raw, mode: mode, state: inputState)
    inputState = result.state
    if needsNeutralInput != inputState.needsNeutralInput {
      needsNeutralInput = inputState.needsNeutralInput
    }
    return result.input
  }

  private func observeControllers() {
    let center = NotificationCenter.default
    observations = [
      center.addObserver(of: GCController.self, for: .didConnect) { [weak self] _ in
        guard let self, self.isActive else { return }
        self.selectController()
      },
      center.addObserver(of: GCController.self, for: .didDisconnect) { [weak self] message in
        guard let self, self.isActive else { return }
        self.selectController(excluding: message.controller)
      },
      center.addObserver(of: GCKeyboard.self, for: .didConnect) { [weak self] _ in
        guard let self, self.isActive else { return }
        self.requireNeutralInput()
        self.cancelTouches()
        self.selectController()
      },
      center.addObserver(of: GCKeyboard.self, for: .didDisconnect) { [weak self] _ in
        guard let self, self.isActive else { return }
        self.requireNeutralInput()
        self.cancelTouches()
        self.selectController()
      },
    ]
  }

  private func selectController(excluding disconnected: GCController? = nil) {
    // Simulator may expose a generic profile instead of the vendor-specific subclass.
    let candidates = GCController.controllers().filter {
      $0 !== disconnected && $0.extendedGamepad != nil
    }
    let selected = candidates.first(where: { $0 === controller }) ?? candidates.first
    let profile = selected?.extendedGamepad
    let useTouch = profile == nil || prefersTouch
    if selected !== controller || useTouch != touchControlsEnabled {
      cancelTouches()
      requireNeutralInput()
    }
    controller = selected
    gamepad = profile
    hasController = profile != nil
    touchControlsEnabled = useTouch
    if useTouch {
      showTouch()
    } else if let profile {
      showController(profile)
    }
    status = .ready
  }

  private func showController(_ profile: GCExtendedGamepad) {
    if profile is GCDualSenseGamepad {
      showSource(
        "PS5 controller", action: profile.buttonA.sfSymbolsName,
        pause: "Options", attack: "R1", guardAction: "L1", dodge: "Circle", focus: "R3")
    } else if profile is GCXboxGamepad {
      showSource(
        "Xbox controller", action: profile.buttonA.sfSymbolsName,
        pause: "Menu", attack: "RB", guardAction: "LB", dodge: "B", focus: "Right stick click")
    } else {
      showSource(
        "Game controller", action: profile.buttonA.sfSymbolsName,
        pause: "Menu", attack: "Right shoulder", guardAction: "Left shoulder", dodge: "Button B",
        focus: "Right stick click")
    }
  }

  private func showKeyboard() {
    showSource(
      "Keyboard · WASD", action: "e.square", pause: "Escape",
      attack: "F", guardAction: "Q", dodge: "Space", focus: "Tab")
  }

  private func showTouch() {
    showSource(
      "Touch controls", action: "hand.tap", pause: "Pause",
      attack: "Attack", guardAction: "Guard", dodge: "Dodge", focus: "Focus")
  }

  private func showSource(
    _ name: String, action: String?, pause: String, attack: String,
    guardAction: String, dodge: String, focus: String
  ) {
    if sourceName != name { sourceName = name }
    if actionSymbol != action { actionSymbol = action }
    if pauseButtonName != pause { pauseButtonName = pause }
    if attackButtonName != attack { attackButtonName = attack }
    if guardButtonName != guardAction { guardButtonName = guardAction }
    if dodgeButtonName != dodge { dodgeButtonName = dodge }
    if focusButtonName != focus { focusButtonName = focus }
  }

  isolated deinit {
    observations.forEach(NotificationCenter.default.removeObserver)
  }
}
