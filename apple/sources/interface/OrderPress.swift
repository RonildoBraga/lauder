import CoreGraphics
import Foundation

/// A finger pressing the ground for the touch order menu (ADR 0003, phase S3). Held still for
/// about a third of a second, it opens the menu at the finger: releasing without sliding sends
/// both companions, sliding to a name sends that companion and sliding down to Hold holds both.
/// Slide up-left for Attack or up-right for Defend. A quick stationary press is a target tap;
/// straight up from the menu, or moving before it opens, gives no order.
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
  /// Within this distance of where the finger came down, a release means Both.
  static let centre: CGFloat = 30

  /// Where the finger came down: the marked point and the default selection centre.
  let start: CGPoint
  let began: TimeInterval
  private(set) var isOpen = false
  /// Moved before the menu opened, or stopped by the game; it gives no order.
  private(set) var isCancelled = false
  /// What a release now would choose, once open.
  private(set) var choice: Choice?
  private var exceededTapSlop = false

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
    guard point.x.isFinite, point.y.isFinite else {
      cancel()
      return
    }
    let offset = CGVector(dx: point.x - start.x, dy: point.y - start.y)
    let distance = hypot(offset.dx, offset.dy)
    if distance > Self.slop { exceededTapSlop = true }
    if isOpen {
      // Clamping the menu's artwork must not change the finger's directions. Re-evaluate
      // even near the start, so returning there clears a previously selected stance.
      choice = Self.choice(for: offset)
    } else if distance > Self.slop {
      isCancelled = true
    }
  }

  /// Accounts for the release position even without a final move callback. A short, stationary
  /// press is a tap; a hold keeps its menu choice. Neither a late timer nor a cancelled capture
  /// may turn a hold or drag into a target tap.
  mutating func end(at point: CGPoint, time: TimeInterval) -> Bool {
    move(to: point)
    guard time.isFinite, began.isFinite, time >= began else {
      cancel()
      return false
    }
    guard time - began < Self.holdTime else { return false }
    guard !isCancelled, !exceededTapSlop else {
      cancel()
      return false
    }
    // UIKit may deliver the short release after the menu task ran. The touch's timestamp,
    // rather than task scheduling, decides whether it was a tap.
    isOpen = false
    choice = nil
    return true
  }

  mutating func cancel() {
    isCancelled = true
    choice = nil
  }

  /// The order the finger's release gives, if any.
  var release: Choice? { isOpen && !isCancelled ? choice : nil }

  /// The menu's item in the direction the finger slid: the companions' names to the left and
  /// right, Hold below, and Attack/Defend on the two upper diagonals. The upper 60-degree
  /// sector cancels; near-horizontal travel still selects a companion.
  static func choice(for offset: CGVector) -> Choice? {
    guard hypot(offset.dx, offset.dy) >= centre else { return .both }
    if offset.dy < 0 {
      let horizontal = abs(offset.dx)
      let vertical = -offset.dy
      let diagonalRatio = CGFloat(3).squareRoot()
      if horizontal <= vertical / diagonalRatio { return nil }
      if horizontal < vertical * diagonalRatio {
        return offset.dx < 0 ? .attack : .defend
      }
    }
    if abs(offset.dx) >= abs(offset.dy) { return offset.dx < 0 ? .left : .right }
    return offset.dy > 0 ? .hold : nil
  }
}
