import simd

enum InputRules {
  struct Raw {
    var stick: SIMD2<Float> = .zero
    var controllerAction = false
    var controllerPause = false
    var left = false
    var right = false
    var up = false
    var down = false
    var keyboardAction = false
    var keyboardPause = false

    var hasMovementKey: Bool { left || right || up || down }
    var hasKeyboardInput: Bool { hasMovementKey || keyboardAction || keyboardPause }
  }

  struct Input: Equatable, Sendable {
    let movement: SIMD2<Float>
    let actionPressed: Bool
    let pausePressed: Bool

    static let neutral = Input(movement: .zero, actionPressed: false, pausePressed: false)
  }

  static func resolve(_ raw: Raw, isPaused: Bool, needsNeutralInput: Bool)
    -> (input: Input, needsNeutralInput: Bool)
  {
    let actionPressed = raw.keyboardAction || raw.controllerAction
    let pausePressed = raw.keyboardPause || raw.controllerPause
    if needsNeutralInput {
      let deadZone = PrototypeLayout.movementDeadZone
      let isNeutral =
        simd_length_squared(raw.stick) <= deadZone * deadZone
        && !raw.hasKeyboardInput && !actionPressed && !pausePressed
      return (.neutral, !isNeutral)
    }
    let movement =
      raw.hasMovementKey
      ? SIMD2<Float>(
        Float(raw.right ? 1 : 0) - Float(raw.left ? 1 : 0),
        Float(raw.up ? 1 : 0) - Float(raw.down ? 1 : 0)) : raw.stick
    return (
      Input(
        movement: isPaused ? .zero : movement,
        actionPressed: !isPaused && actionPressed,
        pausePressed: pausePressed
      ), false
    )
  }
}
