import Foundation
import Observation
import RealityKit
import simd

/// Samples shared input once, advances fixed rules, then presents their resolved state.
@MainActor
@Observable
final class GameWorld {
  let root = Entity()
  let controls = GameControls()
  let session = GameSession()
  private(set) var run = DungeonRun()
  var simulation: DuelSimulation { run.simulation }
  private(set) var observation = "Follow the passage. Look for a way back."
  private(set) var retries = 0

  @ObservationIgnored private let camera = WorldCamera()
  @ObservationIgnored private let stage = DuelStage()
  @ObservationIgnored private var subscription: EventSubscription?
  @ObservationIgnored private var applicationActive = false
  @ObservationIgnored private var presented = false
  @ObservationIgnored private var accumulated: Float = 0
  @ObservationIgnored private var pendingAttack = false
  @ObservationIgnored private var pendingDodge = false
  @ObservationIgnored private var pendingFocus = false
  @ObservationIgnored private var lastGeneration = 0
  @ObservationIgnored private var wasReady = false
  #if DEBUG
    @ObservationIgnored private(set) var playtest: PlaytestRunner?
  #endif

  var isActive: Bool { applicationActive && presented }
  var isPaused: Bool { session.mode == .paused }

  init() {
    root.name = "dungeon"
    root.addChild(stage.root)
    camera.attach(to: root)
    camera.reset(
      hero: run.hero.position, enemy: run.enemy?.position ?? run.hero.position,
      isFocused: run.isFocused)
    stage.present(run, deltaTime: 0)
  }

  func projection(aspect: Float) -> CameraProjection { camera.projection(aspect: aspect) }

  func attach(_ subscription: EventSubscription) {
    self.subscription?.cancel()
    self.subscription = subscription
    presented = true
    controls.setActive(isActive)
    cancelPending()
  }

  func setActive(_ active: Bool) {
    guard active != applicationActive else { return }
    applicationActive = active
    controls.setActive(isActive)
    cancelPending()
  }

  func stop() {
    presented = false
    subscription?.cancel()
    subscription = nil
    controls.setActive(false)
    cancelPending()
  }

  func retry() {
    run.retry()
    resetPresentation(message: "Back at the checkpoint. An opened shortcut stays open.")
  }

  func restart() {
    run.restart()
    resetPresentation(message: "A fresh journey. The shortcut and healing find are reset.")
  }

  private func resetPresentation(message: String) {
    session.restart()
    retries += 1
    observation = message
    cancelPending()
    controls.requireNeutralInput()
    stage.resetMotion()
    camera.reset(
      hero: run.hero.position, enemy: run.enemy?.position ?? run.hero.position,
      isFocused: run.isFocused)
    stage.present(run, deltaTime: 0)
  }

  private func cancelPending() {
    accumulated = 0
    pendingAttack = false
    pendingDodge = false
    pendingFocus = false
    wasReady = false
    run.interrupt()
    _ = run.takeEvents()
    stage.stopFeedback()
  }

  func step(deltaTime: TimeInterval) {
    guard isActive else { return }
    #if DEBUG
      if let runner = playtest, !runner.isFinished {
        controls.scriptedRaw = runner.input(world: self)
      }
    #endif
    let started = DispatchTime.now().uptimeNanoseconds
    let before = controls.touchGeneration
    let mode = session.mode
    let input = controls.sample(mode: mode)
    if before != controls.touchGeneration { cancelPending() }
    update(with: input, sampledIn: mode, deltaTime: Float(deltaTime))
    #if DEBUG
      recordPlaytest(
        deltaTime: Float(deltaTime),
        milliseconds: Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000)
    #endif
  }

  /// Headless tests and the rendered runner use the same resolver and frame transaction.
  func update(raw: InputRules.Raw, deltaTime: Float) {
    let mode = session.mode
    let input = controls.resolve(raw, mode: mode)
    update(with: input, sampledIn: mode, deltaTime: deltaTime)
  }

  func update(
    with input: InputRules.Input, sampledIn mode: GameSession.Mode, deltaTime: Float
  ) {
    guard deltaTime.isFinite, deltaTime > 0 else { return }
    if lastGeneration != controls.touchGeneration {
      cancelPending()
      lastGeneration = controls.touchGeneration
    }
    if input.pausePressed {
      session.togglePause()
      controls.requireNeutralInput()
      cancelPending()
      return
    }
    if mode == .paused {
      if input.restartPressed {
        restart()
      } else if input.actionPressed {
        if session.pauseChoice == .restart {
          restart()
        } else {
          session.togglePause()
          controls.requireNeutralInput()
          cancelPending()
        }
      } else {
        session.movePauseChoice(by: input.menuMove)
      }
      return
    }
    if input.restartPressed {
      restart()
      return
    }
    if run.outcome != .fighting && input.actionPressed {
      if run.outcome == .won { restart() } else { retry() }
      return
    }
    let ready = !controls.needsNeutralInput && session.mode == .exploring
    guard ready, run.outcome == .fighting else {
      if wasReady { cancelPending() }
      return
    }
    wasReady = true
    if input.focusPressed {
      pendingFocus = true
      pendingAttack = false
      pendingDodge = false
    }
    if !pendingFocus {
      pendingAttack = pendingAttack || input.attackPressed
      pendingDodge = pendingDodge || input.dodgePressed
    }
    let direction = Movement.direction(for: input.movement, cameraOffset: WorldCamera.offset)
    accumulated += min(deltaTime, 1 / 15)
    while accumulated >= DuelSimulation.fixedStep && run.outcome == .fighting {
      accumulated -= DuelSimulation.fixedStep
      run.step(
        DuelCommand(
          movement: [direction.x, direction.z], attackPressed: pendingAttack,
          guardHeld: input.guardHeld, dodgePressed: pendingDodge, focusPressed: pendingFocus),
        deltaTime: DuelSimulation.fixedStep)
      pendingAttack = false
      pendingDodge = false
      pendingFocus = false
    }
    let events = run.takeEvents()
    camera.update(
      hero: run.hero.position, enemy: run.enemy?.position ?? run.hero.position,
      isFocused: run.isFocused, deltaTime: min(deltaTime, 1 / 15))
    stage.present(run, deltaTime: min(deltaTime, 1 / 15))
    if isActive {
      stage.play(
        events.compactMap { event in
          if case .combat(let combat) = event { combat } else { nil }
        })
    }
    for event in events {
      switch event {
      case .combat(.blocked):
        observation = "Blocked. Keep stamina for the answer."
      case .combat(.evaded):
        observation = "Evaded. The enemy is committed."
      case .combat(.guardBroken): observation = "Guard broken. Release guard and regain space."
      case .combat(.hit(.hero)): observation = "Hit. Watch the pose before the next attack."
      case .combat(.hit(.enemy)):
        observation = "An opening earned."
      case .encounterStarted: observation = "An enemy guards the room. Keep a retreat route."
      case .encounterCleared: observation = "Passage clear. Explore before moving on."
      case .healed: observation = "Recovered health. This find is spent until your next life."
      case .shortcutOpened: observation = "Shortcut opened. The checkpoint is close again."
      case .finished(.won): observation = "The route is clear. You found the way through."
      case .finished(.lost): observation = "Return to the checkpoint and try another approach."
      default: break
      }
    }
  }

  #if DEBUG
    func startPlaytest(_ name: String) {
      guard let runner = PlaytestRunner(scenario: name, recording: true) else {
        observation = "Unknown playtest: \(name)"
        return
      }
      playtest = runner
      controls.scriptedRaw = .init()
    }

    private func recordPlaytest(deltaTime: Float, milliseconds: Double) {
      guard playtest != nil else { return }
      playtest?.record(world: self, deltaTime: deltaTime, milliseconds: milliseconds)
      if let status = playtest?.status { observation = status }
    }
  #endif
}
