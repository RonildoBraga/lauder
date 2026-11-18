import simd

/// Raw touch capture, including taps that begin and end between world updates.
/// Gameplay edge detection and mode policy remain in InputRules.
struct TouchInput {
  enum Button: Hashable {
    case action, cycle, pause, restart, fire
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
      touchAction: pressed.contains(.action), touchPause: pressed.contains(.pause),
      touchSwitch: pressed.contains(.cycle), touchRestart: pressed.contains(.restart),
      touchFire: pressed.contains(.fire))
  }

  /// Invalidate old captures immediately, before the next SwiftUI/UIKit update.
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
