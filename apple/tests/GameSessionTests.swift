import Testing

@testable import Lauder

@MainActor
struct GameSessionTests {
  @Test
  func pauseStartsOnResumeAndNavigationStopsAtTheEnds() {
    let session = GameSession()
    session.movePauseChoice(by: 1)
    #expect(session.mode == .exploring && session.pauseChoice == .resume)
    session.togglePause()
    #expect(session.mode == .paused && session.pauseChoice == .resume)
    session.movePauseChoice(by: -1)
    #expect(session.pauseChoice == .resume)
    session.movePauseChoice(by: 1)
    session.movePauseChoice(by: 1)
    #expect(session.pauseChoice == .restart)
    session.togglePause()
    session.togglePause()
    #expect(session.mode == .paused && session.pauseChoice == .resume)
  }

  @Test
  func restartRestoresPlayingModeAndMenuWithoutOwningCombatState() {
    let session = GameSession()
    session.togglePause()
    session.movePauseChoice(by: 1)
    session.restart()
    #expect(session.mode == .exploring && session.pauseChoice == .resume)
  }
}
