import Foundation
import GameController
import Observation
import simd

@MainActor
@Observable
final class GameControls {
  enum Status: Equatable {
    case inactive
    case waitingForInput
    case ready
  }

  typealias Input = InputRules.Input

  private(set) var status = Status.inactive
  private(set) var actionSymbol: String?
  private(set) var sourceName = "Connect a controller or keyboard"
  private(set) var pauseButtonName = "Menu"
  private(set) var switchButtonName = "Right shoulder"
  private(set) var needsNeutralInput = true

  @ObservationIgnored private var isActive = false
  @ObservationIgnored private var inputState = InputRules.State()
  @ObservationIgnored private var controller: GCController?
  @ObservationIgnored private var gamepad: GCExtendedGamepad?
  @ObservationIgnored private var observations: [NotificationCenter.ObservationToken] = []

  func setActive(_ active: Bool) {
    guard active != isActive else { return }
    isActive = active
    if active {
      requireNeutralInput()
      observeControllers()
      selectController()
    } else {
      observations.forEach(NotificationCenter.default.removeObserver)
      observations.removeAll()
      detachController()
      status = .inactive
    }
  }

  func requireNeutralInput() {
    inputState = InputRules.State()
    if !needsNeutralInput { needsNeutralInput = true }
  }

  // Buttons are fresh press intents; callers must not detect the same edges again.
  func sample(mode: GameSession.Mode) -> Input {
    guard isActive, status == .ready else { return .neutral }
    let keyboard = GCKeyboard.coalesced?.keyboardInput
    func pressed(_ code: GCKeyCode) -> Bool {
      keyboard?.button(forKeyCode: code)?.isPressed ?? false
    }
    let raw = InputRules.Raw(
      stick: SIMD2(
        gamepad?.leftThumbstick.xAxis.value ?? 0,
        gamepad?.leftThumbstick.yAxis.value ?? 0
      ),
      controllerAction: gamepad?.buttonA.isPressed ?? false,
      controllerPause: gamepad?.buttonMenu.isPressed ?? false,
      controllerSwitch: gamepad?.rightShoulder.isPressed ?? false,
      left: pressed(.keyA), right: pressed(.keyD),
      up: pressed(.keyW), down: pressed(.keyS),
      keyboardAction: pressed(.keyE), keyboardPause: pressed(.escape),
      keyboardSwitch: pressed(.keyQ)
    )
    let deadZone = PrototypeLayout.movementDeadZone
    if raw.hasKeyboardInput {
      showKeyboard()
    } else if let gamepad,
      simd_length_squared(raw.stick) > deadZone * deadZone
        || raw.controllerAction || raw.controllerPause || raw.controllerSwitch
    {
      showController(gamepad)
    }
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
        self.selectController()
      },
      center.addObserver(of: GCKeyboard.self, for: .didDisconnect) { [weak self] _ in
        guard let self, self.isActive else { return }
        self.requireNeutralInput()
        self.selectController()
      },
    ]
  }

  private func selectController(excluding disconnected: GCController? = nil) {
    // Simulator may expose a generic profile instead of the vendor-specific subclass.
    let candidates = GCController.controllers().filter {
      $0 !== disconnected && $0.extendedGamepad != nil
    }
    guard let selected = candidates.first(where: { $0 === controller }) ?? candidates.first,
      let profile = selected.extendedGamepad
    else {
      detachController()
      if GCKeyboard.coalesced?.keyboardInput != nil {
        showKeyboard()
        status = .ready
      } else {
        status = .waitingForInput
      }
      return
    }
    guard selected !== controller else { return }
    detachController()
    controller = selected
    gamepad = profile
    showController(profile)
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

  private func showSource(_ name: String, action: String?, pause: String, cycle: String) {
    if sourceName != name { sourceName = name }
    if actionSymbol != action { actionSymbol = action }
    if pauseButtonName != pause { pauseButtonName = pause }
    if switchButtonName != cycle { switchButtonName = cycle }
  }

  private func detachController() {
    controller = nil
    gamepad = nil
    showSource(
      "Connect a controller or keyboard", action: nil, pause: "Menu", cycle: "Right shoulder")
    requireNeutralInput()
  }

  isolated deinit {
    observations.forEach(NotificationCenter.default.removeObserver)
  }
}
