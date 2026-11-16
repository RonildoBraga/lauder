import Observation

@MainActor
@Observable
final class GameSession {
  // Dialogue and mission state belong to later stages, when their rules exist.
  enum Mode: Equatable, Sendable {
    case exploring, paused
  }

  private(set) var mode = Mode.exploring
  private(set) var leader = PartyMember.miki

  var isPaused: Bool { mode == .paused }

  func togglePause() {
    mode = isPaused ? .exploring : .paused
  }

  func cycleLeader() {
    guard mode == .exploring else { return }
    leader = leader.next
  }
}
