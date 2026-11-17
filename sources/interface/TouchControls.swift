import SwiftUI
import UIKit
import simd

@MainActor
struct TouchControls: UIViewRepresentable {
  let controls: GameControls
  let generation: Int
  /// "Look", or the leader's contextual action such as "Reach latch".
  let actionTitle: String
  let nextLeaderName: String
  let isPaused: Bool

  func makeUIView(context: Context) -> Surface {
    let view = Surface(controls: controls)
    view.update(
      actionTitle: actionTitle, nextLeaderName: nextLeaderName, isPaused: isPaused,
      generation: generation)
    return view
  }

  func updateUIView(_ uiView: Surface, context: Context) {
    uiView.update(
      actionTitle: actionTitle, nextLeaderName: nextLeaderName, isPaused: isPaused,
      generation: generation)
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
    private var generation: Int?

    init(controls: GameControls) {
      self.controls = controls
      super.init(frame: .zero)
      backgroundColor = .clear
      isMultipleTouchEnabled = true
      for zone in [stick, action, cycle, pause] {
        addSubview(zone)
      }
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
      let buttons: [(TouchZone, TouchInput.Button)] = [
        (action, .action), (cycle, .cycle), (pause, .pause),
      ]
      for (zone, button) in buttons {
        zone.changed = { [weak controls] _, isPressed, generation in
          controls?.setTouchButton(button, isPressed: isPressed, generation: generation)
        }
      }
    }

    required init?(coder: NSCoder) { nil }

    func update(actionTitle: String, nextLeaderName: String, isPaused: Bool, generation: Int) {
      if self.generation != generation {
        reset()
      }
      action.setTitle(actionTitle)
      cycle.setTitle("Next: \(nextLeaderName)")
      cycle.accessibilityLabel = "Lead as \(nextLeaderName)"
      pause.setTitle(isPaused ? "Resume" : "Pause")
      // Keep every zone tracking while paused so held fingers must still be released.
      for zone in [stick, action, cycle] {
        zone.alpha = isPaused ? 0.55 : 1
      }
    }

    func reset() {
      let generation = controls.touchGeneration
      self.generation = generation
      for zone in [stick, action, cycle, pause] {
        zone.reset(generation: generation)
      }
    }

    override func layoutSubviews() {
      super.layoutSubviews()
      let inset: CGFloat = 16
      stick.frame = CGRect(x: inset, y: bounds.height - 136 - inset, width: 136, height: 136)
      action.frame = CGRect(
        x: bounds.width - 112 - inset, y: bounds.height - 52 - inset, width: 112, height: 52)
      cycle.frame = CGRect(
        x: bounds.width - 160 - inset, y: bounds.height - 116 - inset, width: 160, height: 52)
      pause.frame = CGRect(x: bounds.width - 112 - inset, y: inset, width: 112, height: 44)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
      let hit = super.hitTest(point, with: event)
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
