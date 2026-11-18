import Foundation
import GameController
import Observation
import simd

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
  private(set) var needsNeutralInput = true
  private(set) var touchControlsEnabled = true
  private(set) var hasController = false
  private(set) var touchGeneration = 0

  @ObservationIgnored private var isActive = false
  @ObservationIgnored private var inputState = InputRules.State()
  @ObservationIgnored private var touchInput = TouchInput()
  @ObservationIgnored private var prefersTouch = false
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

  private func cancelTouches() {
    touchInput.cancel()
    touchGeneration = touchInput.generation
  }

  // Buttons are fresh press intents; callers must not detect the same edges again.
  func sample(mode: GameSession.Mode) -> Input {
    guard isActive, status == .ready else { return .neutral }
    let keyboard = GCKeyboard.coalesced?.keyboardInput
    func pressed(_ code: GCKeyCode) -> Bool {
      keyboard?.button(forKeyCode: code)?.isPressed ?? false
    }
    let touch = touchControlsEnabled ? touchInput.sample() : InputRules.Raw()
    var raw = InputRules.Raw(
      stick: SIMD2(
        touchControlsEnabled ? 0 : gamepad?.leftThumbstick.xAxis.value ?? 0,
        touchControlsEnabled ? 0 : gamepad?.leftThumbstick.yAxis.value ?? 0
      ),
      controllerAction: !touchControlsEnabled && (gamepad?.buttonA.isPressed ?? false),
      controllerPause: !touchControlsEnabled && (gamepad?.buttonMenu.isPressed ?? false),
      controllerSwitch: !touchControlsEnabled && (gamepad?.rightShoulder.isPressed ?? false),
      left: pressed(.keyA), right: pressed(.keyD),
      up: pressed(.keyW), down: pressed(.keyS),
      keyboardAction: pressed(.keyE), keyboardPause: pressed(.escape),
      keyboardSwitch: pressed(.keyQ),
      touchStick: touch.touchStick, touchIsTouching: touch.touchIsTouching,
      touchAction: touch.touchAction, touchPause: touch.touchPause, touchSwitch: touch.touchSwitch,
      touchRestart: touch.touchRestart
    )
    #if DEBUG
      if let scriptedRaw { raw = scriptedRaw }
    #endif
    let deadZone = PrototypeLayout.movementDeadZone
    if raw.hasKeyboardInput {
      showKeyboard()
    } else if touchControlsEnabled {
      showTouch()
    } else if let gamepad,
      simd_length_squared(raw.stick) > deadZone * deadZone
        || raw.controllerAction || raw.controllerPause || raw.controllerSwitch
    {
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
        "PS5 controller", action: profile.buttonA.sfSymbolsName, pause: "Options", cycle: "R1")
    } else if profile is GCXboxGamepad {
      showSource(
        "Xbox controller", action: profile.buttonA.sfSymbolsName, pause: "Menu", cycle: "RB")
    } else {
      showSource(
        "Game controller", action: profile.buttonA.sfSymbolsName, pause: "Menu",
        cycle: "Right shoulder")
    }
  }

  private func showKeyboard() {
    showSource("Keyboard · WASD", action: "e.square", pause: "Escape", cycle: "Q")
  }

  private func showTouch() {
    showSource("Touch controls", action: "hand.tap", pause: "Pause", cycle: "Switch")
  }

  private func showSource(_ name: String, action: String?, pause: String, cycle: String) {
    if sourceName != name { sourceName = name }
    if actionSymbol != action { actionSymbol = action }
    if pauseButtonName != pause { pauseButtonName = pause }
    if switchButtonName != cycle { switchButtonName = cycle }
  }

  isolated deinit {
    observations.forEach(NotificationCenter.default.removeObserver)
  }
}
