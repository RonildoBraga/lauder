import Observation

@MainActor
@Observable
final class GameSession {
  // Dialogue and mission state belong to later stages, when their rules exist.
  enum Mode: Equatable, Sendable {
    case exploring, paused
  }

  enum ActionResult: Equatable, Sendable {
    case opened, alreadyOpen, notEligible, unavailable
  }

  private(set) var mode = Mode.exploring
  private(set) var leader = PartyMember.miki
  /// Party B's shared progress: either specialist action opens the passage for everyone.
  private(set) var passageOpen = false

  var isPaused: Bool { mode == .paused }

  func togglePause() {
    mode = isPaused ? .exploring : .paused
  }

  func cycleLeader() {
    guard mode == .exploring else { return }
    leader = leader.next
  }

  /// Accept or reject a named action. The world has already checked that the active body
  /// stands in the action's approach area; the session checks mode, eligibility and progress.
  func perform(_ action: PrototypeLayout.ActionID, by member: PartyMember) -> ActionResult {
    guard mode == .exploring else { return .unavailable }
    // Repeating either method, by anyone, has no further effect once the passage is open.
    guard !passageOpen else { return .alreadyOpen }
    guard PrototypeLayout.interaction(action).member == member else { return .notEligible }
    passageOpen = true
    return .opened
  }
}
