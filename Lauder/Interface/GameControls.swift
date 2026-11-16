import Foundation
import GameController
import Observation

@MainActor
@Observable
final class GameControls {
  enum Status: Equatable {
    case inactive
    case waitingForController
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
  private(set) var sourceName = "Connect a PS5 or Xbox controller"
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
    guard isActive, status == .ready, let gamepad else { return .neutral }
    let movement = SIMD2(gamepad.leftThumbstick.xAxis.value, gamepad.leftThumbstick.yAxis.value)
    let actionPressed = gamepad.buttonA.isPressed
    let pausePressed = gamepad.buttonMenu.isPressed
    if needsNeutralInput {
      if movement.x * movement.x + movement.y * movement.y <= 0.15 * 0.15,
        !actionPressed, !pausePressed
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
      status = .waitingForController
      return
    }
    guard selected !== controller else { return }
    detachController()
    controller = selected
    gamepad = profile
    actionSymbol = profile.buttonA.sfSymbolsName
    if profile is GCDualSenseGamepad {
      sourceName = "PS5 controller"
      pauseButtonName = "Options"
    } else {
      sourceName = profile is GCXboxGamepad ? "Xbox controller" : "Game controller"
      pauseButtonName = "Menu"
    }
    status = .ready
  }

  private func detachController() {
    controller = nil
    gamepad = nil
    actionSymbol = nil
    sourceName = "Connect a PS5 or Xbox controller"
    pauseButtonName = "Menu"
    needsNeutralInput = true
  }

  isolated deinit {
    observations.forEach(NotificationCenter.default.removeObserver)
  }
}
