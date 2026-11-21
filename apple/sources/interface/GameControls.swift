import Foundation
import GameController
import Observation

@MainActor
@Observable
final class GameControls {
  enum Status: Equatable {
    case inactive
    case ready
  }

  typealias Input = InputRules.Input

  private(set) var status = Status.inactive
  private(set) var actionSymbol: String?
  private(set) var sourceName = "Touch controls"
  private(set) var pauseButtonName = "Pause"
  private(set) var switchButtonName = "Switch"
  private(set) var fireButtonName = "Fire"
  private(set) var formationButtonName = "Formation"
  /// The button that hides or shows the status panel; touch has none.
  private(set) var panelButtonName = "Panel"
  /// The button that leads as the member before the leader; touch has none, and Next cycles.
  private(set) var previousButtonName = "Previous"
  /// The button for the leader's signature, such as Miki's Disrupt.
  private(set) var signatureButtonName = "Signature"
  private(set) var needsNeutralInput = true
  private(set) var touchControlsEnabled = true
  private(set) var hasController = false
  private(set) var touchGeneration = 0

  @ObservationIgnored private var isActive = false
  @ObservationIgnored private var inputState = InputRules.State()
  @ObservationIgnored private var touchInput = TouchInput()
  /// Whether the player chose touch controls while a controller is attached.
  @ObservationIgnored private(set) var prefersTouch = false
  @ObservationIgnored private var controller: GCController?
  @ObservationIgnored private var gamepad: GCExtendedGamepad?
  @ObservationIgnored private var observations: [NotificationCenter.ObservationToken] = []
  #if DEBUG
    /// Replaces hardware input while a Simulator playtest runs (Debug builds only). It still
    /// passes through InputRules, so release gates, Pause and switch edges behave as for a player.
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

  func requireNeutralInput() {
    // Preserve held fingers on Pause: even a centred stick contact must be released.
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

  /// Where the touch order menu has opened, so the world can fix the point on the ground.
  func setTouchMark(_ point: InputRules.ScreenPoint, generation: Int) {
    guard isActive, touchControlsEnabled else { return }
    touchInput.setMark(point, generation: generation)
  }

  /// The touch order menu's choice, at the point where its finger pressed the ground.
  func setTouchOrder(_ order: InputRules.TouchOrder, generation: Int) {
    guard isActive, touchControlsEnabled else { return }
    touchInput.setOrder(order, generation: generation)
  }

  private func cancelTouches() {
    touchInput.cancel()
    touchGeneration = touchInput.generation
  }

  /// This frame's input. Buttons are fresh press intents; callers must not detect the same edges
  /// again.
  func sample(mode: GameSession.Mode) -> Input {
    guard isActive, status == .ready else { return .neutral }
    let keyboard = GCKeyboard.coalesced?.keyboardInput
    func pressed(_ code: GCKeyCode) -> Bool {
      keyboard?.button(forKeyCode: code)?.isPressed ?? false
    }
    let touch = touchControlsEnabled ? touchInput.sample() : InputRules.Raw()
    // The controller counts only while the touch controls are off.
    let pad = touchControlsEnabled ? nil : gamepad
    var raw = InputRules.Raw(
      stick: SIMD2(pad?.leftThumbstick.xAxis.value ?? 0, pad?.leftThumbstick.yAxis.value ?? 0),
      controllerAction: pad?.buttonA.isPressed == true,
      controllerPause: pad?.buttonMenu.isPressed == true,
      controllerSwitch: pad?.rightShoulder.isPressed == true,
      controllerPrevious: pad?.leftShoulder.isPressed == true,
      controllerFire: pad?.rightTrigger.isPressed == true,
      controllerFormation: pad?.buttonY.isPressed == true,
      controllerPanel: pad?.buttonB.isPressed == true,
      controllerSignature: pad?.buttonX.isPressed == true,
      dpadUp: pad?.dpad.up.isPressed == true, dpadDown: pad?.dpad.down.isPressed == true,
      dpadLeft: pad?.dpad.left.isPressed == true, dpadRight: pad?.dpad.right.isPressed == true,
      left: pressed(.keyA), right: pressed(.keyD),
      up: pressed(.keyW), down: pressed(.keyS),
      keyboardAction: pressed(.keyE), keyboardPause: pressed(.escape),
      keyboardSwitch: pressed(.keyQ), keyboardPrevious: pressed(.keyZ),
      keyboardFire: pressed(.keyF), keyboardFormation: pressed(.keyR),
      keyboardPanel: pressed(.keyH), keyboardSignature: pressed(.keyX),
      arrowUp: pressed(.upArrow), arrowDown: pressed(.downArrow),
      arrowLeft: pressed(.leftArrow), arrowRight: pressed(.rightArrow),
      touchStick: touch.touchStick, touchIsTouching: touch.touchIsTouching,
      touchAction: touch.touchAction, touchPause: touch.touchPause, touchSwitch: touch.touchSwitch,
      touchRestart: touch.touchRestart, touchOtherLevel: touch.touchOtherLevel,
      touchFire: touch.touchFire,
      touchFormation: touch.touchFormation, touchSignature: touch.touchSignature,
      touchGround: touch.touchGround,
      touchMark: touch.touchMark, touchOrder: touch.touchOrder
    )
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

  /// Resolve one raw sample with this owner's edge history and release gate. Headless tests
  /// call it directly to drive the same rules without hardware.
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
        "PS5 controller", action: profile.buttonA.sfSymbolsName, pause: "Options", cycle: "R1",
        previous: "L1", fire: "R2", formation: "Triangle", panel: "Circle", signature: "Square")
    } else if profile is GCXboxGamepad {
      showSource(
        "Xbox controller", action: profile.buttonA.sfSymbolsName, pause: "Menu", cycle: "RB",
        previous: "LB", fire: "RT", formation: "Y", panel: "B", signature: "X")
    } else {
      showSource(
        "Game controller", action: profile.buttonA.sfSymbolsName, pause: "Menu",
        cycle: "Right shoulder", previous: "Left shoulder", fire: "Right trigger",
        formation: "Button Y", panel: "Button B", signature: "Button X")
    }
  }

  private func showKeyboard() {
    showSource(
      "Keyboard · WASD", action: "e.square", pause: "Escape", cycle: "Q", previous: "Z",
      fire: "F", formation: "R", panel: "H", signature: "X")
  }

  private func showTouch() {
    showSource(
      "Touch controls", action: "hand.tap", pause: "Pause", cycle: "Switch", previous: "Next",
      fire: "Fire", formation: "Formation", panel: "Panel", signature: "Signature")
  }

  private func showSource(
    _ name: String, action: String?, pause: String, cycle: String, previous: String,
    fire: String, formation: String, panel: String, signature: String
  ) {
    if sourceName != name { sourceName = name }
    if actionSymbol != action { actionSymbol = action }
    if pauseButtonName != pause { pauseButtonName = pause }
    if switchButtonName != cycle { switchButtonName = cycle }
    if previousButtonName != previous { previousButtonName = previous }
    if fireButtonName != fire { fireButtonName = fire }
    if formationButtonName != formation { formationButtonName = formation }
    if panelButtonName != panel { panelButtonName = panel }
    if signatureButtonName != signature { signatureButtonName = signature }
  }

  isolated deinit {
    observations.forEach(NotificationCenter.default.removeObserver)
  }
}
