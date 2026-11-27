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
  /// Whether Fire is shown for the active character's weapon (ADR 0007, ADR 0010).
  let showsFire: Bool
  /// The leader's other weapon, which the Swap button brings into hand (ADR 0021).
  let swapTitle: String
  /// Whether Formation is shown: once the leader has two companions.
  let showsFormation: Bool
  /// "Formation", or "Follow" while anyone is going or holding, when it calls them back.
  let formationTitle: String
  /// The companions the order menu offers on its left and right, as the HUD orders them; nil
  /// while orders are unavailable; quick ground taps can still target an enemy.
  let orderNames: (left: String, right: String)?
  /// The pause menu's Vibration choice as it stands, "Vibration: On" or "Vibration: Off", a
  /// button shown only while paused (ADR 0008).
  let vibrationTitle: String
  /// The pause menu's current status-panel choice.
  let panelTitle: String
  let mode: GameSession.Mode
  /// Shared squad readiness, supplied by gameplay; the control keeps its finger while waiting.
  var grenadeTitle: String = "Grenade"
  /// Only Tom throws the shared grenade; a held contact survives a leader change until lift.
  var showsGrenade = true

  func makeUIView(context: Context) -> Surface {
    let view = Surface(controls: controls)
    updateUIView(view, context: context)
    return view
  }

  func updateUIView(_ uiView: Surface, context: Context) {
    uiView.update(
      actionTitle: actionTitle, nextLeaderName: nextLeaderName, showsFire: showsFire,
      swapTitle: swapTitle, showsFormation: showsFormation,
      formationTitle: formationTitle, orderNames: orderNames,
      vibrationTitle: vibrationTitle, panelTitle: panelTitle, mode: mode, generation: generation,
      grenadeTitle: grenadeTitle, showsGrenade: showsGrenade)
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
    private let dodge = TouchZone(title: "Roll")
    private let swap = TouchZone()
    private let grenade = TouchZone(title: "Grenade")
    private let formation = TouchZone(title: "Formation")
    private let vibration = TouchZone()
    private let panel = TouchZone()
    private let menu = OrderMenu()
    private var generation: Int?
    private var mode = GameSession.Mode.exploring
    private var showsFire = false
    private var showsGrenade = true
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
      for zone in [
        stick, action, cycle, pause, fire, dodge, swap, grenade, formation, vibration, panel,
      ] {
        addSubview(zone)
      }
      menu.isHidden = true
      addSubview(menu)
      fire.accessibilityLabel = "Fire"
      fire.accessibilityHint = "Fires while held. Tap an enemy to target it."
      dodge.accessibilityHint =
        "Rolls a short way in the direction you move. Shots pass through you while you roll."
      formation.accessibilityHint =
        "Changes formation or calls everyone back. Hold the ground for squad orders, including Attack and Defend."
      vibration.accessibilityHint = "Turns vibration off, or on again."
      panel.accessibilityHint = "Shows or hides the status panel."
      swap.accessibilityHint = "Brings the leader's other weapon into hand."
      grenade.accessibilityHint =
        "Throws once toward the selected enemy or the way you aim. The squad shares its recharge."
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
        (cycle, .cycle), (pause, .pause), (fire, .fire), (dodge, .dodge), (formation, .formation),
        (vibration, .vibration), (panel, .panel), (swap, .swap), (grenade, .grenade),
      ]
      for (zone, button) in buttons {
        zone.changed = { [weak self] _, isPressed, generation in
          guard let self else { return }
          self.controls.setTouchButton(button, isPressed: isPressed, generation: generation)
          if !isPressed { self.refreshWeaponVisibility() }
        }
      }
    }

    required init?(coder: NSCoder) { nil }

    func update(
      actionTitle: String, nextLeaderName: String?, showsFire: Bool, swapTitle: String,
      showsFormation: Bool, formationTitle: String, orderNames: (left: String, right: String)?,
      vibrationTitle: String, panelTitle: String, mode: GameSession.Mode, generation: Int,
      grenadeTitle: String = "Grenade", showsGrenade: Bool = true
    ) {
      self.mode = mode
      self.showsFire = showsFire
      self.showsGrenade = showsGrenade
      self.orderNames = orderNames
      if self.generation != generation {
        reset()
      }
      formation.setTitle(formationTitle)
      if mode == .exploring, let orderNames {
        formation.accessibilityCustomActions = [
          UIAccessibilityCustomAction(name: "Squad Attack") { [weak self] _ in
            self?.sendOrder(.attack, generation: generation) ?? false
          },
          UIAccessibilityCustomAction(name: "Squad Defend") { [weak self] _ in
            self?.sendOrder(.defend, generation: generation) ?? false
          },
          UIAccessibilityCustomAction(name: "Send \(orderNames.left) ahead") {
            [weak self] _ in self?.sendOrder(.leftGoes, generation: generation) ?? false
          },
          UIAccessibilityCustomAction(name: "Send \(orderNames.right) ahead") {
            [weak self] _ in self?.sendOrder(.rightGoes, generation: generation) ?? false
          },
          UIAccessibilityCustomAction(name: "Send both ahead") { [weak self] _ in
            self?.sendOrder(.bothGo, generation: generation) ?? false
          },
          UIAccessibilityCustomAction(name: "Hold positions") { [weak self] _ in
            self?.sendOrder(.hold, generation: generation) ?? false
          },
        ]
      } else {
        formation.accessibilityCustomActions = nil
      }
      fire.accessibilityCustomActions =
        mode == .exploring && showsFire
        ? [
          UIAccessibilityCustomAction(name: "Target") { [weak self] _ in
            self?.sendTarget(.acquire, generation: generation) ?? false
          },
          UIAccessibilityCustomAction(name: "Next target") { [weak self] _ in
            self?.sendTarget(.next, generation: generation) ?? false
          },
          UIAccessibilityCustomAction(name: "Let go") { [weak self] _ in
            self?.sendTarget(.release, generation: generation) ?? false
          },
        ] : nil
      if let orderNames {
        menu.setNames(left: orderNames.left, right: orderNames.right)
      }
      // Pause, a conversation or Restart closes the menu, and a source change resets it; either
      // way its finger must still lift.
      if mode != .exploring || (orderNames == nil && press?.isOpen == true),
        press?.isCancelled == false
      {
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
      // Keep a held contact mounted until it lifts, including across mode changes.
      // Roll shows with Fire while exploring, so it never covers a conversation's lines, and
      // stays while a finger holds it. Swap sits above it on the same terms.
      swap.setTitle("Swap: \(swapTitle)")
      swap.accessibilityLabel = "Swap to \(swapTitle)"
      grenade.setTitle(grenadeTitle)
      grenade.accessibilityLabel = "Grenade"
      grenade.accessibilityValue = grenadeTitle
      refreshWeaponVisibility()
      // Formation appears with the second companion; a finger on it keeps it until it lifts.
      formation.isHidden = !showsFormation && !formation.isCaptured
      pause.setTitle(mode == .paused ? "Resume" : "Pause")
      // Vibration appears beside Resume while paused; held fingers remain captured.
      vibration.setTitle(vibrationTitle)
      vibration.isHidden = mode != .paused && !vibration.isCaptured
      panel.setTitle(panelTitle)
      panel.isHidden = mode != .paused && !panel.isCaptured
      // Keep every zone tracking while paused or talking so held fingers must still be
      // released. The action zone stays bright: it continues a conversation or restarts.
      for zone in [stick, cycle, fire, dodge, swap, grenade, formation] {
        zone.alpha = mode == .exploring ? 1 : 0.55
      }
    }

    private func refreshWeaponVisibility() {
      for zone in [fire, dodge, swap] {
        zone.isHidden = (!showsFire || mode != .exploring) && !zone.isCaptured
      }
      grenade.isHidden = (!showsGrenade || mode != .exploring) && !grenade.isCaptured
    }

    func reset() {
      let generation = controls.touchGeneration
      self.generation = generation
      for zone in [
        stick, action, cycle, pause, fire, dodge, swap, grenade, formation, vibration, panel,
      ] {
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
      // Beside Fire on the bottom row, so a thumb can roll out of a burst and shoot back.
      dodge.frame = CGRect(
        x: fire.frame.minX - 12 - 112, y: bounds.height - 52 - inset, width: 112, height: 52)
      // Above Roll and Fire, up to Next's column: the leader's other weapon.
      swap.frame = CGRect(
        x: dodge.frame.minX, y: bounds.height - 116 - inset,
        width: cycle.frame.minX - 12 - dodge.frame.minX, height: 52)
      // One utility control above Roll, left of Formation; the existing controls stay put.
      grenade.frame = CGRect(
        x: dodge.frame.minX, y: formation.frame.minY, width: 112, height: 52)
      pause.frame = CGRect(x: bounds.width - 112 - inset, y: inset, width: 112, height: 44)
      // Beside Resume, shown only while paused.
      vibration.frame = CGRect(
        x: pause.frame.minX - 12 - 150, y: inset, width: 150, height: 44)
      panel.frame = CGRect(x: vibration.frame.minX - 12 - 150, y: inset, width: 150, height: 44)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
      let hit = super.hitTest(point, with: event)
      guard hit === self || hit === menu else { return hit }
      // Open ground takes target taps even before the squad offers orders, apart from the
      // corner where Pause and the SwiftUI "Use controller" button sit.
      let corner = CGRect(
        x: bounds.width - 200, y: 0, width: 200, height: pause.frame.maxY + 76)
      let takesPress =
        mode == .exploring && press == nil && !corner.contains(point)
      return takesPress ? self : nil
    }

    // MARK: - The order press (ADR 0003, phase S3)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
      guard mode == .exploring, press == nil, let touch = touches.first, let generation,
        generation == controls.touchGeneration
      else { return }
      press = OrderPress(at: touch.location(in: self), time: touch.timestamp)
      pressTouch = ObjectIdentifier(touch)
      pressGeneration = generation
      controls.setTouchButton(.ground, isPressed: true, generation: generation)
      if orderNames != nil {
        let began = touch.timestamp
        pressTimer = Task { [weak self] in
          try? await Task.sleep(for: .seconds(OrderPress.holdTime))
          guard !Task.isCancelled else { return }
          self?.openMenu(since: began)
        }
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
      guard let touch = pressing(touches) else { return }
      let point = touch.location(in: self)
      let tapped = press?.end(at: point, time: touch.timestamp) == true
      endPress(sending: true, tapAt: tapped ? point : nil)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
      guard pressing(touches) != nil else { return }
      endPress(sending: false)
    }

    private func pressing(_ touches: Set<UITouch>) -> UITouch? {
      touches.first { ObjectIdentifier($0) == pressTouch }
    }

    private func openMenu(since began: TimeInterval) {
      guard mode == .exploring, orderNames != nil, var press, press.began == began,
        pressGeneration == controls.touchGeneration
      else { return }
      guard press.open(at: began + OrderPress.holdTime, in: bounds), let layout = press.menuLayout
      else { return }
      self.press = press
      // Centre Both under the finger where possible, then keep all six choices on the screen.
      menu.frame = layout.frame
      menu.highlight(.both)
      menu.isHidden = false
      // The ground under the finger now is the point, even if the leader moves meanwhile.
      if let point = screenPoint(press.start) {
        controls.setTouchMark(point, generation: pressGeneration)
      }
    }

    /// The finger lifted, or the press stopped: send the menu's choice when asked, at the point
    /// where the finger came down, and release the ground.
    private func endPress(sending: Bool, tapAt point: CGPoint? = nil) {
      pressTimer?.cancel()
      pressTimer = nil
      if sending, let point, let target = targetTap(at: point) {
        controls.setTouchTarget(.tap(target), generation: pressGeneration)
      } else if sending, let press, let choice = press.release {
        let stance = choice == .attack || choice == .defend
        let point = stance ? nil : screenPoint(press.start)
        if stance || point != nil {
          controls.setTouchOrder(
            InputRules.TouchOrder(command: choice.command, point: point),
            generation: pressGeneration)
        }
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

    /// VoiceOver uses the same orders; a nil terrain point means ahead of the leader.
    private func sendOrder(_ command: GameSession.Command, generation: Int) -> Bool {
      guard mode == .exploring, orderNames != nil, self.generation == generation,
        generation == controls.touchGeneration
      else { return false }
      endPress(sending: false)
      controls.setTouchOrder(.init(command: command, point: nil), generation: generation)
      return true
    }

    private func sendTarget(_ command: InputRules.TargetCommand, generation: Int) -> Bool {
      guard mode == .exploring, self.generation == generation,
        generation == controls.touchGeneration
      else { return false }
      endPress(sending: false)
      controls.setTouchTarget(command, generation: generation)
      return true
    }

    /// RealityView fills the window, while this surface can be inset by its safe area. Keep
    /// taps in that rendered viewport's coordinates and points; an unmounted view has none.
    func targetTap(at point: CGPoint) -> InputRules.TargetTap? {
      guard let position = screenPoint(point), let window else { return nil }
      return .init(point: position, viewHeight: Float(window.bounds.height))
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
/// right as the HUD orders them, Hold below, and Attack/Defend on the upper diagonals.
@MainActor
private final class OrderMenu: UIView {
  private let both = OrderMenu.item("Both")
  private let left = OrderMenu.item("")
  private let right = OrderMenu.item("")
  private let hold = OrderMenu.item("Hold")
  private let attack = OrderMenu.item("↖ Attack")
  private let defend = OrderMenu.item("Defend ↗")

  init() {
    super.init(frame: CGRect(origin: .zero, size: OrderPress.MenuLayout.size))
    isUserInteractionEnabled = false
    accessibilityElementsHidden = true
    for (label, choice) in zip(
      [both, left, right, hold, attack, defend], OrderPress.MenuLayout.choices)
    {
      addSubview(label)
      label.frame = OrderPress.MenuLayout.itemFrame(choice)
    }
  }

  required init?(coder: NSCoder) { nil }

  func setNames(left leftName: String, right rightName: String) {
    left.text = "◀ \(leftName)"
    right.text = "\(rightName) ▶"
  }

  func highlight(_ choice: OrderPress.Choice?) {
    let items: [(UILabel, OrderPress.Choice)] = [
      (both, .both), (left, .left), (right, .right), (hold, .hold),
      (attack, .attack), (defend, .defend),
    ]
    // Frosted items with ink words; the chosen one turns ink with frosted words (the visual
    // direction's HUD).
    for (label, item) in items {
      let chosen = item == choice
      label.backgroundColor =
        chosen
        ? HUDStyle.inkForTouch.withAlphaComponent(0.9) : HUDStyle.frostForTouch(pressed: true)
      label.textColor = chosen ? HUDStyle.frostForTouch(pressed: true) : HUDStyle.inkForTouch
      label.layer.borderColor = HUDStyle.inkForTouch.withAlphaComponent(chosen ? 0.9 : 0.25).cgColor
    }
  }

  private static func item(_ title: String) -> UILabel {
    let label = UILabel()
    label.text = title
    label.font = .systemFont(ofSize: 15, weight: .semibold)
    label.textColor = HUDStyle.inkForTouch
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
    label.textColor = HUDStyle.inkForTouch
    label.textAlignment = .center
    label.adjustsFontSizeToFitWidth = true
    label.minimumScaleFactor = 0.8
    label.isUserInteractionEnabled = false
    addSubview(label)
    thumb.backgroundColor = HUDStyle.inkForTouch.withAlphaComponent(0.3)
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

  /// Frosted with an ink outline, denser while pressed (the visual direction's HUD).
  private func refreshAppearance() {
    backgroundColor = HUDStyle.frostForTouch(pressed: isHighlighted)
    layer.borderWidth = 1
    layer.borderColor = HUDStyle.inkForTouch.withAlphaComponent(isHighlighted ? 0.55 : 0.2).cgColor
  }
}
