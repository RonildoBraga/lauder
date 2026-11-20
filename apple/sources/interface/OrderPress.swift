import CoreGraphics
import Foundation

/// A finger pressing the ground for the touch order menu (ADR 0003, phase S3). Held still for
/// about a third of a second, it opens the menu at the finger: releasing without sliding sends
/// both companions, sliding to a name sends that companion and sliding down to Hold holds both.
/// Sliding up, or moving before the menu opens, gives no order.
struct OrderPress {
  enum Choice: Equatable, Sendable {
    case both, left, right, hold

    var command: GameSession.Command {
      switch self {
      case .both: .bothGo
      case .left: .leftGoes
      case .right: .rightGoes
      case .hold: .hold
      }
    }
  }

  /// How long the finger holds still before the menu opens.
  static let holdTime: TimeInterval = 0.35
  /// How far the finger may drift, in points, before the menu opens.
  static let slop: CGFloat = 12
  /// Within this distance of where the menu opened, a release means Both.
  static let centre: CGFloat = 30

  /// Where the finger came down: the marked point, and the menu's centre.
  let start: CGPoint
  let began: TimeInterval
  private(set) var isOpen = false
  /// Moved before the menu opened, or stopped by the game; it gives no order.
  private(set) var isCancelled = false
  /// What a release now would choose, once open.
  private(set) var choice: Choice?

  init(at point: CGPoint, time: TimeInterval) {
    start = point
    began = time
  }

  /// Opens the menu if the finger has held still long enough; true when it opens now.
  mutating func open(at time: TimeInterval) -> Bool {
    guard !isOpen, !isCancelled, time - began >= Self.holdTime - 0.001 else { return false }
    isOpen = true
    choice = .both
    return true
  }

  mutating func move(to point: CGPoint) {
    guard !isCancelled else { return }
    let offset = CGVector(dx: point.x - start.x, dy: point.y - start.y)
    if isOpen {
      choice = Self.choice(for: offset)
    } else if hypot(offset.dx, offset.dy) > Self.slop {
      isCancelled = true
    }
  }

  mutating func cancel() {
    isCancelled = true
    choice = nil
  }

  /// The order the finger's release gives, if any.
  var release: Choice? { isOpen && !isCancelled ? choice : nil }

  /// The menu's item in the direction the finger slid: the companions' names to the left and
  /// right, as the HUD orders them, Hold below and nothing above.
  static func choice(for offset: CGVector) -> Choice? {
    guard hypot(offset.dx, offset.dy) >= centre else { return .both }
    if abs(offset.dx) >= abs(offset.dy) { return offset.dx < 0 ? .left : .right }
    return offset.dy > 0 ? .hold : nil
  }
}
