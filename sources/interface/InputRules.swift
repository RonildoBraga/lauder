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
    var touchStick: SIMD2<Float> = .zero
    var touchIsTouching = false
    var touchAction = false
    var touchPause = false
    var touchSwitch = false
    /// The touch layout's Restart button, shown in the action button's place while paused.
    var touchRestart = false

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
    var restartWasPressed = false
    /// The vertical direction held in the previous sample: -1 up, 1 down, 0 neither.
    var menuDirection = 0
  }

  struct Input: Equatable, Sendable {
    let movement: SIMD2<Float>
    /// While exploring, act; in a conversation, show the next line; paused, confirm the choice.
    let actionPressed: Bool
    let pausePressed: Bool
    let switchPressed: Bool
    /// A fresh up (-1) or down (1) press while paused, which moves the pause menu's choice.
    var menuMove = 0
    /// A fresh press of the touch Restart button while paused.
    var restartPressed = false

    static let neutral = Input(
      movement: .zero, actionPressed: false, pausePressed: false, switchPressed: false)
  }

  static func resolve(_ raw: Raw, mode: GameSession.Mode, state: State)
    -> (input: Input, state: State)
  {
    let action = raw.keyboardAction || raw.controllerAction || raw.touchAction
    let pause = raw.keyboardPause || raw.controllerPause || raw.touchPause
    let cycle = raw.keyboardSwitch || raw.controllerSwitch || raw.touchSwitch
    let restart = raw.touchRestart
    let movement =
      raw.hasMovementKey
      ? SIMD2<Float>(
        Float(raw.right ? 1 : 0) - Float(raw.left ? 1 : 0),
        Float(raw.up ? 1 : 0) - Float(raw.down ? 1 : 0))
      : raw.touchIsTouching ? raw.touchStick : raw.stick
    let direction = movement.y > 0.5 ? -1 : movement.y < -0.5 ? 1 : 0
    // Consume raw holds even when a gate, mode or higher-priority command suppresses them.
    var next = State(
      needsNeutralInput: state.needsNeutralInput,
      actionWasPressed: action, pauseWasPressed: pause, switchWasPressed: cycle,
      restartWasPressed: restart, menuDirection: direction)
    if state.needsNeutralInput {
      let deadZone = PrototypeLayout.movementDeadZone
      next.needsNeutralInput =
        simd_length_squared(raw.stick) > deadZone * deadZone
        || !raw.stick.x.isFinite || !raw.stick.y.isFinite
        || raw.touchIsTouching
        || simd_length_squared(raw.touchStick) > deadZone * deadZone
        || !raw.touchStick.x.isFinite || !raw.touchStick.y.isFinite
        || raw.hasKeyboardInput || action || pause || cycle || restart
      return (.neutral, next)
    }
    let pauseEdge = pause && !state.pauseWasPressed
    if pauseEdge {
      return (
        Input(
          movement: .zero, actionPressed: false, pausePressed: true, switchPressed: false), next
      )
    }
    let actionEdge = action && !state.actionWasPressed
    switch mode {
    case .paused:
      // The pause menu: up/down choose, action confirms. Switch presses are consumed.
      return (
        Input(
          movement: .zero, actionPressed: actionEdge, pausePressed: false, switchPressed: false,
          menuMove: direction != state.menuDirection ? direction : 0,
          restartPressed: restart && !state.restartWasPressed), next
      )
    case .dialogue:
      // Action shows the next line; movement and switch presses are consumed.
      return (
        Input(
          movement: .zero, actionPressed: actionEdge, pausePressed: false, switchPressed: false),
        next
      )
    case .exploring:
      let switchEdge = cycle && !state.switchWasPressed
      return (
        Input(
          movement: movement,
          actionPressed: actionEdge && !switchEdge,
          pausePressed: false,
          switchPressed: switchEdge
        ), next
      )
    }
  }
}
