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
    /// The right stick: the armed leader's aim, apart from movement (ADR 0007).
    var aimStick: SIMD2<Float> = .zero
    var controllerAction = false
    var controllerPause = false
    /// L1 / LB: lead as the next member, going round the party.
    var controllerSwitch = false
    /// R2 / RT.
    var controllerFire = false
    /// Triangle / Y.
    var controllerFormation = false
    /// Square / X: the leader's dodge roll.
    var controllerDodge = false
    /// R3 / RS, a press of the right stick: lock the aim on a hostile, or move the lock to the
    /// next; two quick presses let go (ADR 0020).
    var controllerLock = false
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
    /// Q: lead as the next member, going round the party.
    var keyboardSwitch = false
    var keyboardFire = false
    var keyboardFormation = false
    /// Space: the leader's dodge roll.
    var keyboardDodge = false
    /// O: the keyboard's lock, as a press of the right stick (ADR 0020).
    var keyboardLock = false
    /// The arrow keys, the Simulator keyboard's D-pad.
    var arrowUp = false
    var arrowDown = false
    var arrowLeft = false
    var arrowRight = false
    /// I, K, J and L: the keyboard's aim, as the right stick's (ADR 0007).
    var aimUp = false
    var aimDown = false
    var aimLeft = false
    var aimRight = false
    var touchStick: SIMD2<Float> = .zero
    var touchIsTouching = false
    var touchAction = false
    var touchPause = false
    var touchSwitch = false
    /// The touch layout's Restart button, shown in the action button's place while paused.
    var touchRestart = false
    /// The touch layout's Vibration button, shown only while paused (ADR 0008).
    var touchVibration = false
    var touchFire = false
    var touchFormation = false
    /// The touch layout's Roll button.
    var touchDodge = false
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
    var hasAimKey: Bool { aimUp || aimDown || aimLeft || aimRight }
    var hasKeyboardInput: Bool {
      hasMovementKey || keyboardAction || keyboardPause || keyboardSwitch || keyboardFire
        || keyboardFormation || keyboardDodge || keyboardLock || hasArrowKey || hasAimKey
    }
    /// Any of the controller's buttons, or either stick beyond the dead zone.
    var hasControllerInput: Bool {
      let deadZone = Movement.deadZone * Movement.deadZone
      return simd_length_squared(stick) > deadZone || simd_length_squared(aimStick) > deadZone
        || controllerAction || controllerPause || controllerSwitch || controllerFire
        || controllerFormation || controllerDodge || controllerLock || hasDpad
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
    var vibrationWasPressed = false
    var dodgeWasPressed = false
    var lockWasPressed = false
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
    /// A fresh press of the touch Vibration button while paused (ADR 0008).
    var vibrationPressed = false
    /// Where the right stick, or I, K, J and L, aims while exploring, in the stick's terms: up
    /// and right on the screen. Nil inside the dead zone (ADR 0007).
    var aim: SIMD2<Float>?
    /// A fresh dodge press while exploring: the leader rolls the way they move.
    var dodgePressed = false
    /// A fresh lock press while exploring: lock the aim on a hostile or move the lock on, or,
    /// soon after the last, let go (ADR 0020).
    var lockPressed = false

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
    let vibration = raw.touchVibration
    let fire = raw.keyboardFire || raw.controllerFire || raw.touchFire
    let formation = raw.keyboardFormation || raw.controllerFormation || raw.touchFormation
    let dodge = raw.keyboardDodge || raw.controllerDodge || raw.touchDodge
    let lock = raw.keyboardLock || raw.controllerLock
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
    let aimKeys = SIMD2<Float>(
      Float(raw.aimRight ? 1 : 0) - Float(raw.aimLeft ? 1 : 0),
      Float(raw.aimUp ? 1 : 0) - Float(raw.aimDown ? 1 : 0))
    let aimed = raw.hasAimKey ? aimKeys : raw.aimStick
    let aim =
      aimed.x.isFinite && aimed.y.isFinite
        && simd_length_squared(aimed) > Movement.deadZone * Movement.deadZone
      ? aimed : nil
    // The pause menu takes the D-pad and arrow keys as well as the stick and movement keys.
    let direction = movement.y > 0.5 || up ? -1 : movement.y < -0.5 || down ? 1 : 0
    // Consume raw holds even when a gate, mode or higher-priority command suppresses them.
    var next = State(
      needsNeutralInput: state.needsNeutralInput,
      actionWasPressed: action, pauseWasPressed: pause, switchWasPressed: cycle,
      restartWasPressed: restart, fireWasPressed: fire, formationWasPressed: formation,
      upWasPressed: up, downWasPressed: down, leftWasPressed: left, rightWasPressed: right,
      menuDirection: direction)
    next.vibrationWasPressed = vibration
    next.dodgeWasPressed = dodge
    next.lockWasPressed = lock
    if state.needsNeutralInput {
      let deadZone = Movement.deadZone
      next.needsNeutralInput =
        simd_length_squared(raw.stick) > deadZone * deadZone
        || !raw.stick.x.isFinite || !raw.stick.y.isFinite
        || simd_length_squared(raw.aimStick) > deadZone * deadZone
        || !raw.aimStick.x.isFinite || !raw.aimStick.y.isFinite
        || raw.touchIsTouching
        || simd_length_squared(raw.touchStick) > deadZone * deadZone
        || !raw.touchStick.x.isFinite || !raw.touchStick.y.isFinite
        || raw.hasKeyboardInput || action || pause || cycle || restart || fire || formation
        || raw.hasDpad || raw.touchGround || vibration || dodge || lock
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
      // The pause menu: up/down choose, action confirms, and the touch buttons choose directly.
      // Switch, formation, lock and order presses are consumed.
      return (
        Input(
          movement: .zero, actionPressed: actionEdge, pausePressed: false, switchPressed: false,
          menuMove: direction != state.menuDirection ? direction : 0,
          restartPressed: restart && !state.restartWasPressed,
          vibrationPressed: vibration && !state.vibrationWasPressed), next
      )
    case .dialogue:
      // Action shows the next line; movement, switch, formation, lock and order presses are
      // consumed.
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
      // A switch or a squad command in the same sample discards the leader's action and roll.
      let commanded = switchEdge || formationEdge || command != nil
      return (
        Input(
          movement: movement,
          actionPressed: actionEdge && !commanded,
          pausePressed: false,
          switchPressed: switchEdge,
          fireHeld: fire,
          firePressed: fire && !state.fireWasPressed,
          formationPressed: formationEdge,
          command: command,
          commandPoint: commandPoint,
          markPoint: raw.touchMark,
          aim: aim,
          dodgePressed: dodge && !state.dodgeWasPressed && !commanded,
          lockPressed: lock && !state.lockWasPressed
        ), next
      )
    }
  }
}
