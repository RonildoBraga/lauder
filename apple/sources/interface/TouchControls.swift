import SwiftUI
import UIKit
import simd

@MainActor
struct TouchControls: UIViewRepresentable {
  let controls: GameControls
  let generation: Int
  /// "Look", the leader's contextual action such as "Search", "Continue" in a
  /// conversation, or "Restart" while paused.
  let actionTitle: String
  /// Who Next would switch to, or nil while the leader travels alone.
  let nextLeaderName: String?
  /// Whether Fire is shown: in an encounter, or while the weapon is drawn.
  let showsFire: Bool
  /// Whether Formation is shown: once the leader has two companions.
  let showsFormation: Bool
  /// "Formation", or "Follow" while anyone is going or holding, when it calls them back.
  let formationTitle: String
  /// The companions the order menu offers on its left and right, as the HUD orders them; nil
  /// until orders are offered, and pressing the ground does nothing (ADR 0003, phase S3).
  let orderNames: (left: String, right: String)?
  let mode: GameSession.Mode

  func makeUIView(context: Context) -> Surface {
    let view = Surface(controls: controls)
    updateUIView(view, context: context)
    return view
  }

  func updateUIView(_ uiView: Surface, context: Context) {
    uiView.update(
      actionTitle: actionTitle, nextLeaderName: nextLeaderName, showsFire: showsFire,
      showsFormation: showsFormation, formationTitle: formationTitle, orderNames: orderNames,
      mode: mode, generation: generation)
  }

  static func dismantleUIView(_ uiView: Surface, coordinator: ()) {
    uiView.reset()
  }

  final class Surface: UIView {
    private let controls: GameControls
    private let stick = TouchZone(isStick: true)
    private let action = TouchZone(title: "Look")
    private let cycle = TouchZone()
    private let pause = TouchZone(title: "Pause")
    private let fire = TouchZone(title: "Fire")
    private let formation = TouchZone(title: "Formation")
    private let menu = OrderMenu()
    private var generation: Int?
    private var mode = GameSession.Mode.exploring
    private var orderNames: (left: String, right: String)?
    /// The finger pressing the ground for the order menu, from its touch to its release.
    private var press: OrderPress?
    private var pressTouch: ObjectIdentifier?
    private var pressGeneration = 0
    private var pressTimer: Task<Void, Never>?
    /// What the action zone sent when its finger came down. Its release sends the same, even
    /// if Pause changed the zone into Restart in between.
    private var actionBinding = TouchInput.Button.action

    init(controls: GameControls) {
      self.controls = controls
      super.init(frame: .zero)
      backgroundColor = .clear
      isMultipleTouchEnabled = true
      for zone in [stick, action, cycle, pause, fire, formation] {
        addSubview(zone)
      }
      menu.isHidden = true
      addSubview(menu)
      fire.accessibilityLabel = "Fire"
      fire.accessibilityHint = "Draws the weapon, then fires at the marked target while held."
      formation.accessibilityHint =
        "Changes the formation: Close, Spread, then Column. After an order, calls everyone back."
      stick.accessibilityLabel = "Move"
      stick.accessibilityHint = "Drag to move the active character. Lift your finger to stop."
      stick.accessibilityTraits = .allowsDirectInteraction
      stick.changed = { [weak self] point, isTouching, generation in
        guard let self else { return }
        let displacement =
          point.map {
            SIMD2(Float($0.x - self.stick.bounds.midX), Float($0.y - self.stick.bounds.midY))
          } ?? .zero
        let movement = TouchInput.movement(
          displacement: displacement, radius: Float(self.stick.travelRadius))
        self.stick.showMovement(movement)
        self.controls.setTouchStick(
          movement, isTouching: isTouching, generation: generation)
      }
      // In the pause menu the action zone is the Restart button.
      action.changed = { [weak self] _, isPressed, generation in
        guard let self else { return }
        if isPressed { self.actionBinding = self.mode == .paused ? .restart : .action }
        self.controls.setTouchButton(
          self.actionBinding, isPressed: isPressed, generation: generation)
      }
      let buttons: [(TouchZone, TouchInput.Button)] = [
        (cycle, .cycle), (pause, .pause), (fire, .fire), (formation, .formation),
      ]
      for (zone, button) in buttons {
        zone.changed = { [weak controls] _, isPressed, generation in
          controls?.setTouchButton(button, isPressed: isPressed, generation: generation)
        }
      }
    }

    required init?(coder: NSCoder) { nil }

    func update(
      actionTitle: String, nextLeaderName: String?, showsFire: Bool, showsFormation: Bool,
      formationTitle: String, orderNames: (left: String, right: String)?,
      mode: GameSession.Mode, generation: Int
    ) {
      self.mode = mode
      self.orderNames = orderNames
      if self.generation != generation {
        reset()
      }
      formation.setTitle(formationTitle)
      if let orderNames {
        menu.setNames(left: orderNames.left, right: orderNames.right)
      }
      // Pause, a conversation or Restart closes the menu, and a source change resets it; either
      // way its finger must still lift.
      if mode != .exploring || orderNames == nil, press?.isCancelled == false {
        press?.cancel()
        closeMenu()
      }
      action.setTitle(actionTitle)
      if let nextLeaderName {
        cycle.setTitle("Next: \(nextLeaderName)")
        cycle.accessibilityLabel = "Lead as \(nextLeaderName)"
      }
      // Alone, there is nobody to switch to. A finger already on Next keeps it until it lifts,
      // so the release gate still sees that button let go.
      cycle.isHidden = nextLeaderName == nil && !cycle.isCaptured
      // Fire appears once there is something to fight, and stays while a finger holds it.
      fire.isHidden = !showsFire && !fire.isCaptured
      // Formation appears with the second companion; a finger on it keeps it until it lifts.
      formation.isHidden = !showsFormation && !formation.isCaptured
      pause.setTitle(mode == .paused ? "Resume" : "Pause")
      // Keep every zone tracking while paused or talking so held fingers must still be
      // released. The action zone stays bright: it continues a conversation or restarts.
      for zone in [stick, cycle, fire, formation] {
        zone.alpha = mode == .exploring ? 1 : 0.55
      }
    }

    func reset() {
      let generation = controls.touchGeneration
      self.generation = generation
      for zone in [stick, action, cycle, pause, fire, formation] {
        zone.reset(generation: generation)
      }
      endPress(sending: false)
    }

    override func layoutSubviews() {
      super.layoutSubviews()
      let inset: CGFloat = 16
      stick.frame = CGRect(x: inset, y: bounds.height - 136 - inset, width: 136, height: 136)
      action.frame = CGRect(
        x: bounds.width - 112 - inset, y: bounds.height - 52 - inset, width: 112, height: 52)
      cycle.frame = CGRect(
        x: bounds.width - 160 - inset, y: bounds.height - 116 - inset, width: 160, height: 52)
      // Above Next, the top of the right thumb's column: the fifth and last button.
      formation.frame = CGRect(
        x: bounds.width - 160 - inset, y: bounds.height - 180 - inset, width: 160, height: 52)
      // Beside Look on the bottom row, within reach of the right thumb.
      fire.frame = CGRect(
        x: bounds.width - 224 - inset - 12, y: bounds.height - 52 - inset, width: 112, height: 52)
      pause.frame = CGRect(x: bounds.width - 112 - inset, y: inset, width: 112, height: 44)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
      let hit = super.hitTest(point, with: event)
      guard hit === self || hit === menu else { return hit }
      // Open ground takes the order press while orders are offered, apart from the corner where
      // Pause and the SwiftUI "Use controller" button sit. Otherwise touches pass through.
      let corner = CGRect(
        x: bounds.width - 200, y: 0, width: 200, height: pause.frame.maxY + 76)
      let takesPress =
        orderNames != nil && mode == .exploring && press == nil && !corner.contains(point)
      return takesPress ? self : nil
    }

    // MARK: - The order press (ADR 0003, phase S3)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
      guard press == nil, let touch = touches.first, let generation else { return }
      press = OrderPress(at: touch.location(in: self), time: touch.timestamp)
      pressTouch = ObjectIdentifier(touch)
      pressGeneration = generation
      controls.setTouchButton(.ground, isPressed: true, generation: generation)
      let began = touch.timestamp
      pressTimer = Task { [weak self] in
        try? await Task.sleep(for: .seconds(OrderPress.holdTime))
        guard !Task.isCancelled else { return }
        self?.openMenu(since: began)
      }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
      guard let touch = pressing(touches) else { return }
      press?.move(to: touch.location(in: self))
      if press?.isOpen == true {
        menu.highlight(press?.choice)
      } else if press?.isCancelled == true {
        pressTimer?.cancel()
      }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
      guard pressing(touches) != nil else { return }
      endPress(sending: true)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
      guard pressing(touches) != nil else { return }
      endPress(sending: false)
    }

    private func pressing(_ touches: Set<UITouch>) -> UITouch? {
      touches.first { ObjectIdentifier($0) == pressTouch }
    }

    private func openMenu(since began: TimeInterval) {
      guard var press, press.began == began else { return }
      guard press.open(at: began + OrderPress.holdTime) else { return }
      self.press = press
      let size = menu.bounds.size
      // The menu opens with Both under the finger, kept on the screen.
      menu.frame.origin = CGPoint(
        x: min(max(press.start.x - size.width / 2, 0), bounds.width - size.width),
        y: min(max(press.start.y - 20, 0), bounds.height - size.height))
      menu.highlight(.both)
      menu.isHidden = false
      // The ground under the finger now is the point, even if the leader moves meanwhile.
      if let point = screenPoint(press.start) {
        controls.setTouchMark(point, generation: pressGeneration)
      }
    }

    /// The finger lifted, or the press stopped: send the menu's choice when asked, at the point
    /// where the finger came down, and release the ground.
    private func endPress(sending: Bool) {
      pressTimer?.cancel()
      pressTimer = nil
      if sending, let press, let choice = press.release, let point = screenPoint(press.start) {
        controls.setTouchOrder(
          InputRules.TouchOrder(command: choice.command, point: point),
          generation: pressGeneration)
      }
      if press != nil {
        controls.setTouchButton(.ground, isPressed: false, generation: pressGeneration)
      }
      press = nil
      pressTouch = nil
      closeMenu()
    }

    private func closeMenu() {
      menu.isHidden = true
      menu.highlight(nil)
    }

    /// A point in this view as a share of the whole window, which the game's view fills.
    private func screenPoint(_ point: CGPoint) -> InputRules.ScreenPoint? {
      guard let window, window.bounds.width > 0, window.bounds.height > 0 else { return nil }
      let onScreen = convert(point, to: window)
      return InputRules.ScreenPoint(
        x: Float(onScreen.x / window.bounds.width), y: Float(onScreen.y / window.bounds.height),
        aspect: Float(window.bounds.width / window.bounds.height))
    }
  }
}

/// The order menu around the finger: Both in the middle, the companions to the left and
/// right as the HUD orders them, and Hold below.
@MainActor
private final class OrderMenu: UIView {
  private let both = OrderMenu.item("Both")
  private let left = OrderMenu.item("")
  private let right = OrderMenu.item("")
  private let hold = OrderMenu.item("Hold")

  init() {
    super.init(frame: CGRect(x: 0, y: 0, width: 280, height: 112))
    isUserInteractionEnabled = false
    accessibilityElementsHidden = true
    for label in [both, left, right, hold] { addSubview(label) }
    let width: CGFloat = 84
    let height: CGFloat = 40
    both.frame = CGRect(x: 140 - width / 2, y: 0, width: width, height: height)
    left.frame = CGRect(x: 0, y: 0, width: width, height: height)
    right.frame = CGRect(x: 280 - width, y: 0, width: width, height: height)
    hold.frame = CGRect(x: 140 - width / 2, y: 112 - height, width: width, height: height)
  }

  required init?(coder: NSCoder) { nil }

  func setNames(left leftName: String, right rightName: String) {
    left.text = "◀ \(leftName)"
    right.text = "\(rightName) ▶"
  }

  func highlight(_ choice: OrderPress.Choice?) {
    let items: [(UILabel, OrderPress.Choice)] = [
      (both, .both), (left, .left), (right, .right), (hold, .hold),
    ]
    for (label, item) in items {
      let chosen = item == choice
      label.backgroundColor = UIColor(
        red: chosen ? 0.2 : 0.075, green: chosen ? 0.33 : 0.13, blue: chosen ? 0.33 : 0.14,
        alpha: 0.92)
      label.layer.borderColor = UIColor(white: 0.95, alpha: chosen ? 0.85 : 0.3).cgColor
    }
  }

  private static func item(_ title: String) -> UILabel {
    let label = UILabel()
    label.text = title
    label.font = .systemFont(ofSize: 15, weight: .semibold)
    label.textColor = UIColor(white: 0.95, alpha: 1)
    label.textAlignment = .center
    label.adjustsFontSizeToFitWidth = true
    label.minimumScaleFactor = 0.8
    label.layer.cornerRadius = 12
    label.layer.borderWidth = 1
    label.clipsToBounds = true
    return label
  }
}

/// Each zone owns one finger from begin to end, even if that finger crosses another zone.
@MainActor
private final class TouchZone: UIControl {
  var changed: ((CGPoint?, Bool, Int) -> Void)?
  private let isStick: Bool
  private let label = UILabel()
  private let thumb = UIView()
  private var generation = 0
  private var captured: (identity: ObjectIdentifier, generation: Int)?
  private var movement = SIMD2<Float>.zero

  var travelRadius: CGFloat { max(1, min(bounds.width, bounds.height) / 2 - 26) }
  /// Whether a finger currently holds this zone.
  var isCaptured: Bool { captured != nil }

  init(title: String = "", isStick: Bool = false) {
    self.isStick = isStick
    super.init(frame: .zero)
    isMultipleTouchEnabled = true
    isExclusiveTouch = false
    isAccessibilityElement = true
    accessibilityTraits = .button
    label.font = .systemFont(ofSize: 15, weight: .semibold)
    label.textColor = UIColor(white: 0.95, alpha: 1)
    label.textAlignment = .center
    label.adjustsFontSizeToFitWidth = true
    label.minimumScaleFactor = 0.8
    label.isUserInteractionEnabled = false
    addSubview(label)
    thumb.backgroundColor = UIColor(white: 0.95, alpha: 0.4)
    thumb.isUserInteractionEnabled = false
    thumb.isHidden = !isStick
    addSubview(thumb)
    setTitle(title)
    refreshAppearance()
  }

  required init?(coder: NSCoder) { nil }

  override var isHighlighted: Bool {
    didSet { refreshAppearance() }
  }

  func setTitle(_ title: String) {
    label.text = title
    accessibilityLabel = title
  }

  func showMovement(_ movement: SIMD2<Float>) {
    self.movement = movement
    setNeedsLayout()
  }

  func reset(generation: Int) {
    self.generation = generation
    captured = nil
    isHighlighted = false
    showMovement(.zero)
    changed?(nil, false, generation)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    layer.cornerRadius = isStick ? min(bounds.width, bounds.height) / 2 : 12
    label.frame = bounds.insetBy(dx: 10, dy: 4)
    thumb.bounds = CGRect(x: 0, y: 0, width: 48, height: 48)
    thumb.layer.cornerRadius = 24
    thumb.center = CGPoint(
      x: bounds.midX + CGFloat(movement.x) * travelRadius,
      y: bounds.midY - CGFloat(movement.y) * travelRadius)
  }

  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    guard isStick else { return super.point(inside: point, with: event) }
    let dx = point.x - bounds.midX
    let dy = point.y - bounds.midY
    let radius = min(bounds.width, bounds.height) / 2
    return dx * dx + dy * dy <= radius * radius
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard captured == nil, let touch = touches.first else { return }
    let generation = self.generation
    captured = (ObjectIdentifier(touch), generation)
    isHighlighted = true
    changed?(touch.location(in: self), true, generation)
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard isStick, let captured,
      let touch = touches.first(where: { ObjectIdentifier($0) == captured.identity })
    else { return }
    changed?(touch.location(in: self), true, captured.generation)
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    release(touches)
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    release(touches)
  }

  override func accessibilityActivate() -> Bool {
    guard !isStick, captured == nil else { return false }
    let generation = self.generation
    changed?(nil, true, generation)
    changed?(nil, false, generation)
    return true
  }

  private func release(_ touches: Set<UITouch>) {
    guard let captured,
      touches.contains(where: { ObjectIdentifier($0) == captured.identity })
    else { return }
    self.captured = nil
    isHighlighted = false
    changed?(nil, false, captured.generation)
  }

  private func refreshAppearance() {
    backgroundColor = UIColor(
      red: 0.075, green: 0.13, blue: 0.14, alpha: isHighlighted ? 0.95 : 0.65)
    layer.borderWidth = 1
    layer.borderColor = UIColor(white: 0.95, alpha: isHighlighted ? 0.65 : 0.3).cgColor
  }
}
