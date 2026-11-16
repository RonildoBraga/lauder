import simd

enum InputRules {
  struct Raw: Equatable, Sendable {
    var stick: SIMD2<Float> = .zero
    var controllerAction = false
    var controllerPause = false
    var controllerSwitch = false
    var left = false
    var right = false
    var up = false
    var down = false
    var keyboardAction = false
    var keyboardPause = false
    var keyboardSwitch = false

    var hasMovementKey: Bool { left || right || up || down }
    var hasKeyboardInput: Bool {
      hasMovementKey || keyboardAction || keyboardPause || keyboardSwitch
    }
  }

  struct State: Equatable, Sendable {
    var needsNeutralInput = true
    var actionWasPressed = false
    var pauseWasPressed = false
    var switchWasPressed = false
  }

  struct Input: Equatable, Sendable {
    let movement: SIMD2<Float>
    let actionPressed: Bool
    let pausePressed: Bool
    let switchPressed: Bool

    static let neutral = Input(
      movement: .zero, actionPressed: false, pausePressed: false, switchPressed: false)
  }

  static func resolve(_ raw: Raw, mode: GameSession.Mode, state: State)
    -> (input: Input, state: State)
  {
    let action = raw.keyboardAction || raw.controllerAction
    let pause = raw.keyboardPause || raw.controllerPause
    let cycle = raw.keyboardSwitch || raw.controllerSwitch
    // Consume raw holds even when a gate, mode or higher-priority command suppresses them.
    var next = State(
      needsNeutralInput: state.needsNeutralInput,
      actionWasPressed: action, pauseWasPressed: pause, switchWasPressed: cycle)
    if state.needsNeutralInput {
      let deadZone = PrototypeLayout.movementDeadZone
      next.needsNeutralInput =
        simd_length_squared(raw.stick) > deadZone * deadZone
        || !raw.stick.x.isFinite || !raw.stick.y.isFinite
        || raw.hasKeyboardInput || action || pause || cycle
      return (.neutral, next)
    }
    let pauseEdge = pause && !state.pauseWasPressed
    if pauseEdge {
      return (
        Input(
          movement: .zero, actionPressed: false, pausePressed: true, switchPressed: false), next
      )
    }
    guard mode == .exploring else { return (.neutral, next) }
    let movement =
      raw.hasMovementKey
      ? SIMD2<Float>(
        Float(raw.right ? 1 : 0) - Float(raw.left ? 1 : 0),
        Float(raw.up ? 1 : 0) - Float(raw.down ? 1 : 0)) : raw.stick
    let switchEdge = cycle && !state.switchWasPressed
    return (
      Input(
        movement: movement,
        actionPressed: action && !state.actionWasPressed && !switchEdge,
        pausePressed: false,
        switchPressed: switchEdge
      ), next
    )
  }
}
