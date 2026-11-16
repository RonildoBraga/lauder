import Foundation
import GameController
import Observation

@MainActor
@Observable
final class GameControls {
  enum Status: Equatable {
    case inactive
    case connecting
    case ready
    case failed(String)
  }

  enum Source {
    case none
    case playStation
    case gamepad
    case touch
  }

  struct Input: Sendable {
    let movement: SIMD2<Float>
    let actionPressed: Bool
    let pausePressed: Bool

    static let neutral = Input(movement: .zero, actionPressed: false, pausePressed: false)
  }

  private(set) var status = Status.inactive
  private(set) var source = Source.none
  private(set) var actionSymbol: String?

  var sourceName: String {
    switch source {
    case .none: "No controller"
    case .playStation: "PlayStation controller"
    case .gamepad: "Game controller"
    case .touch: "Touch controls"
    }
  }

  @ObservationIgnored private var isActive = false
  @ObservationIgnored private var isPaused = false
  @ObservationIgnored private var needsNeutralInput = true
  @ObservationIgnored private var generation: UUID?
  @ObservationIgnored private var virtualController: GCVirtualController?
  @ObservationIgnored private var physicalController: GCController?
  @ObservationIgnored private var gamepad: GCExtendedGamepad?
  @ObservationIgnored private var connectionTask: Task<Void, Never>?
  @ObservationIgnored private var observations: [NotificationCenter.ObservationToken] = []

  // A cancelled connect may still finish. Recognise its controller without retaining old attempts.
  @ObservationIgnored private let virtualAttempts = NSHashTable<GCVirtualController>.weakObjects()
  @ObservationIgnored private let virtualProfiles = NSHashTable<GCController>.weakObjects()

  func setActive(_ active: Bool) {
    guard active != isActive else { return }
    isActive = active
    if active {
      observeControllers()
      selectController()
    } else {
      observations.forEach(NotificationCenter.default.removeObserver)
      observations.removeAll()
      detachSource()
    }
  }

  func setPaused(_ paused: Bool) {
    guard paused != isPaused else { return }
    isPaused = paused
    needsNeutralInput = true
    if isActive {
      selectController()
    }
  }

  func retry() {
    guard isActive, case .failed = status else { return }
    selectController()
  }

  // This is a snapshot of the current button state; the caller detects press edges.
  func sample() -> Input {
    guard isActive, status == .ready, let gamepad else { return .neutral }
    let movement = SIMD2(gamepad.leftThumbstick.xAxis.value, gamepad.leftThumbstick.yAxis.value)
    let actionPressed = gamepad.buttonA.isPressed
    let pausePressed = source != .touch && gamepad.buttonMenu.isPressed
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
      center.addObserver(of: GCController.self, for: .didConnect) { [weak self] message in
        self?.controllerChanged(message.controller)
      },
      center.addObserver(of: GCController.self, for: .didDisconnect) { [weak self] message in
        self?.controllerChanged(message.controller)
      },
    ]
  }

  private func controllerChanged(_ controller: GCController) {
    guard isActive, !isOwnVirtualController(controller) else { return }
    selectController()
  }

  private func isOwnVirtualController(_ controller: GCController) -> Bool {
    if virtualAttempts.allObjects.contains(where: { $0.controller === controller }) {
      virtualProfiles.add(controller)
    }
    return virtualProfiles.contains(controller)
  }

  private func selectController() {
    let controllers = GCController.controllers().filter {
      !isOwnVirtualController($0) && $0.extendedGamepad != nil
    }
    let playStation = controllers.filter { isPlayStation($0.extendedGamepad) }
    let candidates = playStation.isEmpty ? controllers : playStation
    if let controller = candidates.first(where: { $0 === physicalController }) ?? candidates.first {
      guard controller !== physicalController else { return }
      detachSource()
      physicalController = controller
      gamepad = controller.extendedGamepad
      source = isPlayStation(gamepad) ? .playStation : .gamepad
      actionSymbol = gamepad?.buttonA.sfSymbolsName
      status = .ready
      return
    }
    if !isPaused, source == .touch, status == .connecting || status == .ready {
      return
    }
    detachSource()
    if !isPaused {
      connectTouch()
    }
  }

  private func isPlayStation(_ gamepad: GCExtendedGamepad?) -> Bool {
    gamepad is GCDualSenseGamepad || gamepad is GCDualShockGamepad
  }

  private func connectTouch() {
    let attempt = UUID()
    generation = attempt

    let configuration = GCVirtualController.Configuration()
    configuration.elements = [GCInputLeftThumbstick, GCInputButtonA]
    let controller = GCVirtualController(configuration: configuration)
    virtualController = controller
    virtualAttempts.add(controller)
    source = .touch
    status = .connecting

    connectionTask = Task { [weak self] in
      do {
        try await controller.connect()
        try Task.checkCancellation()
        guard let self, self.isActive, !self.isPaused, self.generation == attempt else {
          controller.disconnect()
          return
        }
        guard let profile = controller.controller, let gamepad = profile.extendedGamepad else {
          throw ConnectionError.missingGamepad
        }
        self.virtualProfiles.add(profile)
        self.gamepad = gamepad
        self.actionSymbol = gamepad.buttonA.sfSymbolsName
        self.status = .ready
        self.connectionTask = nil
      } catch {
        controller.disconnect()
        guard let self, self.generation == attempt else { return }
        self.gamepad = nil
        self.virtualController = nil
        self.connectionTask = nil
        self.source = .none
        self.actionSymbol = nil
        self.status = .failed(error.localizedDescription)
      }
    }
  }

  private func detachSource() {
    generation = nil
    connectionTask?.cancel()
    connectionTask = nil
    physicalController = nil
    gamepad = nil
    needsNeutralInput = true
    if let controller = virtualController?.controller {
      virtualProfiles.add(controller)
    }
    virtualController?.disconnect()
    virtualController = nil
    source = .none
    actionSymbol = nil
    status = .inactive
  }

  isolated deinit {
    observations.forEach(NotificationCenter.default.removeObserver)
    connectionTask?.cancel()
    virtualController?.disconnect()
  }

  private enum ConnectionError: LocalizedError {
    case missingGamepad

    var errorDescription: String? {
      "Touch controls connected without the required movement and action inputs."
    }
  }
}
