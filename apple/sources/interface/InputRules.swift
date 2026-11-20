import simd

enum InputRules {
  /// Where a touch order was given: the press's point on the screen, from 0 to 1 across and
  /// down, and the screen's width over its height, so the world can find the ground under it.
  struct ScreenPoint: Equatable, Sendable {
    let x: Float
    let y: Float
    let aspect: Float
  }

  /// A squad order from the touch menu, sent once when its finger lifts (ADR 0003, phase S3).
  struct TouchOrder: Equatable, Sendable {
    let command: GameSession.Command
    let point: ScreenPoint
  }

  struct Raw: Equatable, Sendable {
    var stick: SIMD2<Float> = .zero
    var controllerAction = false
    var controllerPause = false
    var controllerSwitch = false
    /// R2 / RT.
    var controllerFire = false
    /// Triangle / Y.
    var controllerFormation = false
    /// The D-pad's directions: squad orders while exploring, and up or down in the pause menu.
    var dpadUp = false
    var dpadDown = false
    var dpadLeft = false
    var dpadRight = false
    var left = false
    var right = false
    var up = false
    var down = false
    var keyboardAction = false
    var keyboardPause = false
    var keyboardSwitch = false
    var keyboardFire = false
    var keyboardFormation = false
    /// The arrow keys, the Simulator keyboard's D-pad.
    var arrowUp = false
    var arrowDown = false
    var arrowLeft = false
    var arrowRight = false
    var touchStick: SIMD2<Float> = .zero
    var touchIsTouching = false
    var touchAction = false
    var touchPause = false
    var touchSwitch = false
    /// The touch layout's Restart button, shown in the action button's place while paused.
    var touchRestart = false
    var touchFire = false
    var touchFormation = false
    /// A finger pressing the ground, which may open the order menu.
    var touchGround = false
    /// Where the touch menu opened since the last sample: the press's point, which the world
    /// fixes on the ground then, so moving the leader during the press does not move it.
    var touchMark: ScreenPoint?
    /// An order the touch menu sent since the last sample.
    var touchOrder: TouchOrder?

    var hasMovementKey: Bool { left || right || up || down }
    var hasArrowKey: Bool { arrowUp || arrowDown || arrowLeft || arrowRight }
    var hasDpad: Bool { dpadUp || dpadDown || dpadLeft || dpadRight }
    var hasKeyboardInput: Bool {
      hasMovementKey || keyboardAction || keyboardPause || keyboardSwitch || keyboardFire
        || keyboardFormation || hasArrowKey
    }
  }

  struct State: Equatable, Sendable {
    var needsNeutralInput = true
    var actionWasPressed = false
    var pauseWasPressed = false
    var switchWasPressed = false
    var restartWasPressed = false
    var fireWasPressed = false
    var formationWasPressed = false
    /// The order directions held in the previous sample, from the D-pad or the arrow keys.
    var upWasPressed = false
    var downWasPressed = false
    var leftWasPressed = false
    var rightWasPressed = false
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
    /// Fire held while exploring: the weapon keeps shooting at its own pace.
    var fireHeld = false
    /// A fresh Fire press while exploring, which draws a holstered weapon.
    var firePressed = false
    /// A fresh formation press while exploring, which calls everyone back after an order and
    /// otherwise cycles the squad's formation.
    var formationPressed = false
    /// A fresh squad order while exploring (ADR 0003, phase S3).
    var command: GameSession.Command?
    /// Where on the screen a touch order marked its point; nil for the D-pad and arrow keys,
    /// whose point lies ahead of the leader.
    var commandPoint: ScreenPoint?
    /// Where the touch order menu has just opened, while exploring.
    var markPoint: ScreenPoint?

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
    let fire = raw.keyboardFire || raw.controllerFire || raw.touchFire
    let formation = raw.keyboardFormation || raw.controllerFormation || raw.touchFormation
    let up = raw.dpadUp || raw.arrowUp
    let down = raw.dpadDown || raw.arrowDown
    let left = raw.dpadLeft || raw.arrowLeft
    let right = raw.dpadRight || raw.arrowRight
    let movement =
      raw.hasMovementKey
      ? SIMD2<Float>(
        Float(raw.right ? 1 : 0) - Float(raw.left ? 1 : 0),
        Float(raw.up ? 1 : 0) - Float(raw.down ? 1 : 0))
      : raw.touchIsTouching ? raw.touchStick : raw.stick
    // The pause menu takes the D-pad and arrow keys as well as the stick and movement keys.
    let direction = movement.y > 0.5 || up ? -1 : movement.y < -0.5 || down ? 1 : 0
    // Consume raw holds even when a gate, mode or higher-priority command suppresses them.
    var next = State(
      needsNeutralInput: state.needsNeutralInput,
      actionWasPressed: action, pauseWasPressed: pause, switchWasPressed: cycle,
      restartWasPressed: restart, fireWasPressed: fire, formationWasPressed: formation,
      upWasPressed: up, downWasPressed: down, leftWasPressed: left, rightWasPressed: right,
      menuDirection: direction)
    if state.needsNeutralInput {
      let deadZone = Movement.deadZone
      next.needsNeutralInput =
        simd_length_squared(raw.stick) > deadZone * deadZone
        || !raw.stick.x.isFinite || !raw.stick.y.isFinite
        || raw.touchIsTouching
        || simd_length_squared(raw.touchStick) > deadZone * deadZone
        || !raw.touchStick.x.isFinite || !raw.touchStick.y.isFinite
        || raw.hasKeyboardInput || action || pause || cycle || restart || fire || formation
        || raw.hasDpad || raw.touchGround
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
      // The pause menu: up/down choose, action confirms. Switch, formation and order presses
      // are consumed.
      return (
        Input(
          movement: .zero, actionPressed: actionEdge, pausePressed: false, switchPressed: false,
          menuMove: direction != state.menuDirection ? direction : 0,
          restartPressed: restart && !state.restartWasPressed), next
      )
    case .dialogue:
      // Action shows the next line; movement, switch, formation and order presses are consumed.
      return (
        Input(
          movement: .zero, actionPressed: actionEdge, pausePressed: false, switchPressed: false),
        next
      )
    case .exploring:
      let switchEdge = cycle && !state.switchWasPressed
      let formationEdge = formation && !state.formationWasPressed
      // One order per sample. A touch order is already a single event; among fresh directions
      // Hold comes first, then both, then one side, should two arrive together.
      var command: GameSession.Command?
      var commandPoint: ScreenPoint?
      if let order = raw.touchOrder {
        command = order.command
        commandPoint = order.point
      } else if down && !state.downWasPressed {
        command = .hold
      } else if up && !state.upWasPressed {
        command = .bothGo
      } else if left && !state.leftWasPressed {
        command = .leftGoes
      } else if right && !state.rightWasPressed {
        command = .rightGoes
      }
      // A squad command in the same sample discards the action, as a switch does.
      return (
        Input(
          movement: movement,
          actionPressed: actionEdge && !switchEdge && !formationEdge && command == nil,
          pausePressed: false,
          switchPressed: switchEdge,
          fireHeld: fire,
          firePressed: fire && !state.fireWasPressed,
          formationPressed: formationEdge,
          command: command,
          commandPoint: commandPoint,
          markPoint: raw.touchMark
        ), next
      )
    }
  }
}
