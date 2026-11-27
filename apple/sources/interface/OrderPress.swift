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

  /// One layout for the labels and their hit regions, in the capture surface's coordinates.
  struct MenuLayout {
    static let size = CGSize(width: 280, height: 168)
    static let centre = CGPoint(x: 140, y: 84)
    static let choices: [Choice] = [.both, .left, .right, .hold, .attack, .defend]
    let frame: CGRect

    init(at start: CGPoint, in bounds: CGRect? = nil) {
      var origin = CGPoint(x: start.x - Self.centre.x, y: start.y - Self.centre.y)
      if let bounds {
        origin.x = max(bounds.minX, min(origin.x, bounds.maxX - Self.size.width))
        origin.y = max(bounds.minY, min(origin.y, bounds.maxY - Self.size.height))
      }
      frame = CGRect(origin: origin, size: Self.size)
    }

    static func itemFrame(_ choice: Choice) -> CGRect {
      let origin: CGPoint =
        switch choice {
        case .both: CGPoint(x: 98, y: 62)
        case .left: CGPoint(x: 0, y: 62)
        case .right: CGPoint(x: 196, y: 62)
        case .hold: CGPoint(x: 98, y: 124)
        case .attack: CGPoint(x: 0, y: 0)
        case .defend: CGPoint(x: 196, y: 0)
        }
      return CGRect(origin: origin, size: CGSize(width: 84, height: 44))
    }

    func choice(at point: CGPoint) -> Choice? {
      let local = CGPoint(x: point.x - frame.minX, y: point.y - frame.minY)
      return Self.choices.first { Self.itemFrame($0).contains(local) }
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
  private(set) var menuLayout: MenuLayout?
  private var exceededTapSlop = false

  init(at point: CGPoint, time: TimeInterval) {
    start = point
    began = time
  }

  /// Opens the menu if the finger has held still long enough; true when it opens now.
  mutating func open(at time: TimeInterval, in bounds: CGRect? = nil) -> Bool {
    guard !isOpen, !isCancelled, time - began >= Self.holdTime - 0.001 else { return false }
    isOpen = true
    menuLayout = MenuLayout(at: start, in: bounds)
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
      // Returning to the original finger always clears the selection. Elsewhere the drawn
      // item wins, including when the layout was clamped; directions fill only the gaps.
      choice =
        distance < Self.centre ? .both : menuLayout?.choice(at: point) ?? Self.choice(for: offset)
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

  /// Directional fallback between and beyond the drawn items. Straight up cancels, while
  /// near-horizontal travel still selects a companion.
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
