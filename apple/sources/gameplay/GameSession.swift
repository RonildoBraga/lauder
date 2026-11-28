import Observation

/// Session mode and menu authority. Combat outcomes and health belong to DuelSimulation.
@MainActor
@Observable
final class GameSession {
  enum Mode: Equatable, Sendable {
    case exploring, paused
  }

  enum PauseChoice: CaseIterable, Sendable {
    case resume, restart
  }

  private(set) var mode = Mode.exploring
  private(set) var pauseChoice = PauseChoice.resume
  var availablePauseChoices: [PauseChoice] { PauseChoice.allCases }

  func togglePause() {
    mode = mode == .paused ? .exploring : .paused
    pauseChoice = .resume
  }

  func movePauseChoice(by step: Int) {
    guard mode == .paused, step != 0 else { return }
    let choices = availablePauseChoices
    let index = choices.firstIndex(of: pauseChoice) ?? 0
    pauseChoice = choices[min(max(index + step.signum(), 0), choices.count - 1)]
  }

  func restart() {
    mode = .exploring
    pauseChoice = .resume
  }
}
