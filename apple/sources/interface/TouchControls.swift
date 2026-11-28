import SwiftUI
import UIKit
import simd

/// Three combat actions and an enemy-focus toggle. Captures stay mounted while paused.
@MainActor
struct TouchControls: UIViewRepresentable {
  let controls: GameControls
  let generation: Int
  let mode: GameSession.Mode
  var isFocused = false

  func makeUIView(context: Context) -> Surface {
    let view = Surface(controls: controls)
    updateUIView(view, context: context)
    return view
  }

  func updateUIView(_ uiView: Surface, context: Context) {
    uiView.update(mode: mode, generation: generation, isFocused: isFocused)
  }

  static func dismantleUIView(_ uiView: Surface, coordinator: ()) {
    uiView.reset()
  }

  final class Surface: UIView {
    private let controls: GameControls
    private let stick = TouchZone(isStick: true)
    private let attack = TouchZone(title: "Attack")
    private let guardAction = TouchZone(title: "Guard")
    private let dodge = TouchZone(title: "Dodge")
    private let focus = TouchZone(title: "Focus")
    private let pause = TouchZone(title: "Pause")
    private let restart = TouchZone(title: "Restart")
    private var generation: Int?
    private var mode = GameSession.Mode.exploring

    init(controls: GameControls) {
      self.controls = controls
      super.init(frame: .zero)
      backgroundColor = .clear
      isMultipleTouchEnabled = true
      for zone in zones { addSubview(zone) }
      stick.accessibilityLabel = "Move"
      stick.accessibilityHint = "Drag to move. Lift your finger to stop."
      stick.accessibilityTraits = .allowsDirectInteraction
      attack.accessibilityHint = "One sword attack per press."
      guardAction.accessibilityHint = "Hold to block attacks from the direction you face."
      dodge.accessibilityHint = "Dodge in the direction you move, then recover."
      focus.accessibilityHint = "Toggle facing the enemy while moving."
      restart.accessibilityHint = "Begin a fresh duel."
      stick.changed = { [weak self] point, isTouching, generation in
        guard let self else { return }
        let displacement =
          point.map {
            SIMD2(Float($0.x - self.stick.bounds.midX), Float($0.y - self.stick.bounds.midY))
          } ?? .zero
        let movement = TouchInput.movement(
          displacement: displacement, radius: Float(self.stick.travelRadius))
        self.stick.showMovement(movement)
        self.controls.setTouchStick(movement, isTouching: isTouching, generation: generation)
      }
      let buttons: [(TouchZone, TouchInput.Button)] = [
        (attack, .attack), (guardAction, .guardAction), (dodge, .dodge), (focus, .focus),
        (pause, .pause), (restart, .restart),
      ]
      for (zone, button) in buttons {
        zone.changed = { [weak self] _, isPressed, generation in
          guard let self else { return }
          self.controls.setTouchButton(button, isPressed: isPressed, generation: generation)
          if !isPressed { self.refreshVisibility() }
        }
      }
    }

    required init?(coder: NSCoder) { nil }

    private var zones: [TouchZone] { [stick, attack, guardAction, dodge, focus, pause, restart] }

    func update(mode: GameSession.Mode, generation: Int, isFocused: Bool = false) {
      self.mode = mode
      if self.generation != generation { reset() }
      pause.setTitle(mode == .paused ? "Resume" : "Pause")
      focus.setTitle(isFocused ? "Unfocus" : "Focus")
      focus.accessibilityValue = isFocused ? "On" : "Off"
      refreshVisibility()
    }

    func reset() {
      let generation = controls.touchGeneration
      self.generation = generation
      for zone in zones { zone.reset(generation: generation) }
    }

    private func refreshVisibility() {
      // Preserve the original binding and capture until lift. A held attack never becomes Restart.
      for zone in [attack, guardAction, dodge, focus] {
        zone.isHidden = mode == .paused && !zone.isCaptured
        zone.alpha = mode == .paused ? 0.3 : 1
      }
      stick.alpha = mode == .paused ? 0.3 : 1
      restart.isHidden = mode != .paused && !restart.isCaptured
    }

    override func layoutSubviews() {
      super.layoutSubviews()
      let left = max(16, safeAreaInsets.left + 12)
      let right = bounds.width - max(16, safeAreaInsets.right + 12)
      let bottom = bounds.height - max(16, safeAreaInsets.bottom + 12)
      let top = max(12, safeAreaInsets.top + 8)
      stick.frame = CGRect(x: left, y: bottom - 132, width: 132, height: 132)
      attack.frame = CGRect(x: right - 96, y: bottom - 64, width: 96, height: 64)
      focus.frame = CGRect(x: right - 96, y: bottom - 116, width: 96, height: 44)
      guardAction.frame = CGRect(x: right - 204, y: bottom - 128, width: 96, height: 56)
      dodge.frame = CGRect(x: right - 204, y: bottom - 60, width: 96, height: 60)
      pause.frame = CGRect(x: right - 96, y: top, width: 96, height: 44)
      restart.frame = CGRect(x: right - 96, y: top + 52, width: 96, height: 44)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
      let hit = super.hitTest(point, with: event)
      // Empty ground does not consume the source picker or the outcome's Retry button.
      return hit === self ? nil : hit
    }
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
