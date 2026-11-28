import simd

/// Shared source-independent commands. Combat owns legality, buffering and resource costs.
enum InputRules {
  struct Raw: Equatable, Sendable {
    var stick: SIMD2<Float> = .zero
    var controllerAttack = false
    var controllerGuard = false
    var controllerDodge = false
    var controllerFocus = false
    var controllerPause = false
    var controllerAction = false
    var dpadUp = false
    var dpadDown = false
    var left = false
    var right = false
    var up = false
    var down = false
    var keyboardAttack = false
    var keyboardGuard = false
    var keyboardDodge = false
    var keyboardFocus = false
    var keyboardPause = false
    var keyboardAction = false
    var arrowUp = false
    var arrowDown = false
    var touchStick: SIMD2<Float> = .zero
    /// A centred stick contact still prevents neutral input until its finger lifts.
    var touchIsTouching = false
    var touchAttack = false
    var touchGuard = false
    var touchDodge = false
    var touchFocus = false
    var touchPause = false
    var touchRestart = false

    var hasMovementKey: Bool { left || right || up || down }
    var hasKeyboardInput: Bool {
      hasMovementKey || keyboardAttack || keyboardGuard || keyboardDodge || keyboardFocus
        || keyboardPause
        || keyboardAction || arrowUp || arrowDown
    }
    var hasControllerInput: Bool {
      !Self.isNeutral(stick) || controllerAttack || controllerGuard || controllerDodge
        || controllerFocus
        || controllerPause || controllerAction || dpadUp || dpadDown
    }
    var hasTouchInput: Bool {
      touchIsTouching || !Self.isNeutral(touchStick) || touchAttack || touchGuard || touchDodge
        || touchFocus
        || touchPause || touchRestart
    }

    private static func isNeutral(_ vector: SIMD2<Float>) -> Bool {
      vector.x.isFinite && vector.y.isFinite
        && simd_length_squared(vector) <= Movement.deadZone * Movement.deadZone
    }
  }

  struct State: Equatable, Sendable {
    var needsNeutralInput = true
    var attackWasPressed = false
    var dodgeWasPressed = false
    var focusWasPressed = false
    var pauseWasPressed = false
    var actionWasPressed = false
    var restartWasPressed = false
    var menuDirection = 0
  }

  struct Input: Equatable, Sendable {
    var movement: SIMD2<Float> = .zero
    var attackPressed = false
    var guardHeld = false
    var dodgePressed = false
    var focusPressed = false
    var pausePressed = false
    var actionPressed = false
    var menuMove = 0
    var restartPressed = false

    static let neutral = Input()
  }

  static func resolve(_ raw: Raw, mode: GameSession.Mode, state: State)
    -> (input: Input, state: State)
  {
    let attack = raw.controllerAttack || raw.keyboardAttack || raw.touchAttack
    let guardHeld = raw.controllerGuard || raw.keyboardGuard || raw.touchGuard
    let dodge = raw.controllerDodge || raw.keyboardDodge || raw.touchDodge
    let focus = raw.controllerFocus || raw.keyboardFocus || raw.touchFocus
    let pause = raw.controllerPause || raw.keyboardPause || raw.touchPause
    let action = raw.controllerAction || raw.keyboardAction
    let movement =
      raw.hasMovementKey
      ? SIMD2<Float>(
        Float(raw.right ? 1 : 0) - Float(raw.left ? 1 : 0),
        Float(raw.up ? 1 : 0) - Float(raw.down ? 1 : 0))
      : raw.touchIsTouching ? raw.touchStick : raw.stick
    let direction =
      movement.y > 0.5 || raw.dpadUp || raw.arrowUp
      ? -1
      : movement.y < -0.5 || raw.dpadDown || raw.arrowDown ? 1 : 0
    // Consume every raw edge, including when Pause or a release gate suppresses it.
    var next = State(
      needsNeutralInput: state.needsNeutralInput,
      attackWasPressed: attack, dodgeWasPressed: dodge, focusWasPressed: focus,
      pauseWasPressed: pause, actionWasPressed: action,
      restartWasPressed: raw.touchRestart, menuDirection: direction)
    if state.needsNeutralInput {
      next.needsNeutralInput =
        raw.hasControllerInput || raw.hasKeyboardInput || raw.hasTouchInput
      return (.neutral, next)
    }
    if pause && !state.pauseWasPressed {
      return (Input(pausePressed: true), next)
    }
    if mode == .paused {
      return (
        Input(
          actionPressed: action && !state.actionWasPressed,
          menuMove: direction != state.menuDirection ? direction : 0,
          restartPressed: raw.touchRestart && !state.restartWasPressed), next
      )
    }
    return (
      Input(
        movement: movement, attackPressed: attack && !state.attackWasPressed,
        guardHeld: guardHeld, dodgePressed: dodge && !state.dodgeWasPressed,
        focusPressed: focus && !state.focusWasPressed,
        actionPressed: action && !state.actionWasPressed), next
    )
  }
}
