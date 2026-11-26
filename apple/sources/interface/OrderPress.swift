import CoreGraphics
import Foundation

/// A finger pressing the ground for the touch order menu (ADR 0003, phase S3). Held still for
/// about a third of a second, it opens the menu at the finger: releasing without sliding sends
/// both companions, sliding to a name sends that companion and sliding down to Hold holds both.
/// Slide up-left for Attack or up-right for Defend. Straight up, or moving before the menu
/// opens, gives no order.
struct OrderPress {
  enum Choice: Equatable, Sendable {
    case both, left, right, hold, attack, defend

    var command: GameSession.Command {
      switch self {
      case .both: .bothGo
      case .left: .leftGoes
      case .right: .rightGoes
      case .hold: .hold
      case .attack: .attack
      case .defend: .defend
      }
    }
  }

  /// How long the finger holds still before the menu opens.
  static let holdTime: TimeInterval = 0.35
  /// How far the finger may drift, in points, before the menu opens.
  static let slop: CGFloat = 12
  /// Within this distance of where the menu opened, a release means Both.
  static let centre: CGFloat = 30

  /// Where the finger came down: the marked point and the default selection centre.
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

  mutating func move(to point: CGPoint, menuCentre: CGPoint? = nil) {
    guard !isCancelled else { return }
    let offset = CGVector(dx: point.x - start.x, dy: point.y - start.y)
    if isOpen {
      // A menu clamped at a screen edge uses its visible item's centre. A small finger drift
      // still keeps the initial Both choice rather than selecting an item moved under it.
      if menuCentre != nil, hypot(offset.dx, offset.dy) <= Self.slop { return }
      let centre = menuCentre ?? start
      choice = Self.choice(for: CGVector(dx: point.x - centre.x, dy: point.y - centre.y))
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
  /// right, Hold below, and Attack/Defend on the two upper diagonals. Straight up cancels.
  static func choice(for offset: CGVector) -> Choice? {
    guard hypot(offset.dx, offset.dy) >= centre else { return .both }
    if offset.dy < -centre, abs(offset.dx) > centre / 2 {
      return offset.dx < 0 ? .attack : .defend
    }
    if abs(offset.dx) >= abs(offset.dy) { return offset.dx < 0 ? .left : .right }
    return offset.dy > 0 ? .hold : nil
  }
}
