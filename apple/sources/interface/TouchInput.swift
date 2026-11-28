import simd

/// Raw capture, including taps that begin and end between world updates.
/// InputRules retains edge detection and mode policy.
struct TouchInput {
  enum Button: CaseIterable, Hashable, Sendable {
    case attack, guardAction, dodge, pause, restart
  }

  private(set) var generation = 0
  private var stick: SIMD2<Float> = .zero
  private var isTouching = false
  private var held: Set<Button> = []
  private var pending: Set<Button> = []

  mutating func setStick(_ movement: SIMD2<Float>, isTouching: Bool, generation: Int) {
    guard generation == self.generation else { return }
    stick = isTouching ? movement : .zero
    self.isTouching = isTouching
  }

  mutating func setButton(_ button: Button, isPressed: Bool, generation: Int) {
    guard generation == self.generation else { return }
    if isPressed {
      if held.insert(button).inserted { pending.insert(button) }
    } else {
      held.remove(button)
    }
  }

  mutating func sample() -> InputRules.Raw {
    let pressed = held.union(pending)
    pending.removeAll(keepingCapacity: true)
    return InputRules.Raw(
      touchStick: stick, touchIsTouching: isTouching,
      touchAttack: pressed.contains(.attack), touchGuard: pressed.contains(.guardAction),
      touchDodge: pressed.contains(.dodge), touchPause: pressed.contains(.pause),
      touchRestart: pressed.contains(.restart))
  }

  /// Invalidate captures before the next SwiftUI/UIKit update, on source or lifecycle changes.
  mutating func cancel() {
    generation += 1
    stick = .zero
    isTouching = false
    held.removeAll(keepingCapacity: true)
    pending.removeAll(keepingCapacity: true)
  }

  static func movement(displacement: SIMD2<Float>, radius: Float) -> SIMD2<Float> {
    guard radius.isFinite, radius > 0,
      displacement.x.isFinite, displacement.y.isFinite
    else { return .zero }
    let value = SIMD2(displacement.x, -displacement.y) / radius
    let length = simd_length(value)
    guard length.isFinite else { return .zero }
    return length > 1 ? value / length : value
  }
}
