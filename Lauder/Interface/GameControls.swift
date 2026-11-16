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

  struct Input: Sendable {
    let movement: SIMD2<Float>
    let actionPressed: Bool
    let pausePressed: Bool

    static let neutral = Input(movement: .zero, actionPressed: false, pausePressed: false)
  }

  private(set) var status = Status.inactive
  private(set) var actionSymbol: String?
  private(set) var sourceName = "Connect a controller or keyboard"
  private(set) var pauseButtonName = "Menu"

  @ObservationIgnored private var isActive = false
  @ObservationIgnored private var isPaused = false
  @ObservationIgnored private var needsNeutralInput = true
  @ObservationIgnored private var controller: GCController?
  @ObservationIgnored private var gamepad: GCExtendedGamepad?
  @ObservationIgnored private var observations: [NotificationCenter.ObservationToken] = []

  func setActive(_ active: Bool) {
    guard active != isActive else { return }
    isActive = active
    if active {
      observeControllers()
      selectController()
    } else {
      observations.forEach(NotificationCenter.default.removeObserver)
      observations.removeAll()
      detachController()
      status = .inactive
    }
  }

  func setPaused(_ paused: Bool) {
    guard paused != isPaused else { return }
    isPaused = paused
    needsNeutralInput = true
  }

  // This is a snapshot of the current button state; the caller detects press edges.
  func sample() -> Input {
    guard isActive, status == .ready else { return .neutral }
    let keyboard = GCKeyboard.coalesced?.keyboardInput
    func pressed(_ code: GCKeyCode) -> Bool {
      keyboard?.button(forKeyCode: code)?.isPressed ?? false
    }
    let left = pressed(.keyA)
    let right = pressed(.keyD)
    let up = pressed(.keyW)
    let down = pressed(.keyS)
    let keyboardAction = pressed(.keyE)
    let keyboardPause = pressed(.escape)
    let hasMovementKey = left || right || up || down
    let hasKeyboardInput = hasMovementKey || keyboardAction || keyboardPause
    let stick = SIMD2(
      gamepad?.leftThumbstick.xAxis.value ?? 0,
      gamepad?.leftThumbstick.yAxis.value ?? 0
    )
    let movement =
      hasMovementKey
      ? SIMD2<Float>(
        Float(right ? 1 : 0) - Float(left ? 1 : 0),
        Float(up ? 1 : 0) - Float(down ? 1 : 0)) : stick
    let actionPressed = keyboardAction || (gamepad?.buttonA.isPressed ?? false)
    let pausePressed = keyboardPause || (gamepad?.buttonMenu.isPressed ?? false)
    if hasKeyboardInput {
      showKeyboard()
    } else if let gamepad,
      simd_length_squared(stick) > 0.15 * 0.15 || actionPressed || pausePressed
    {
      showController(gamepad)
    }
    if needsNeutralInput {
      if simd_length_squared(stick) <= 0.15 * 0.15,
        !hasKeyboardInput, !actionPressed, !pausePressed
      {
        needsNeutralInput = false
      }
      return .neutral
    }
    return Input(
      movement: isPaused ? .zero : movement,
      actionPressed: !isPaused && actionPressed,
      pausePressed: pausePressed
    )
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
        self.needsNeutralInput = true
        self.selectController()
      },
      center.addObserver(of: GCKeyboard.self, for: .didDisconnect) { [weak self] _ in
        guard let self, self.isActive else { return }
        self.needsNeutralInput = true
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
    actionSymbol = profile.buttonA.sfSymbolsName
    if profile is GCDualSenseGamepad {
      sourceName = "PS5 controller"
      pauseButtonName = "Options"
    } else {
      sourceName = profile is GCXboxGamepad ? "Xbox controller" : "Game controller"
      pauseButtonName = "Menu"
    }
  }

  private func showKeyboard() {
    sourceName = "Keyboard · WASD"
    actionSymbol = "e.square"
    pauseButtonName = "Escape"
  }

  private func detachController() {
    controller = nil
    gamepad = nil
    actionSymbol = nil
    sourceName = "Connect a controller or keyboard"
    pauseButtonName = "Menu"
    needsNeutralInput = true
  }

  isolated deinit {
    observations.forEach(NotificationCenter.default.removeObserver)
  }
}
