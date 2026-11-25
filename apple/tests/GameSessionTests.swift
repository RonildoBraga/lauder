import Testing

@testable import Lauder

@MainActor
struct GameSessionTests {
  @Test
  func startsExploringWithMiki() {
    let session = GameSession(level: TestYard.level)
    #expect(session.mode == .exploring)
    #expect(!session.isPaused)
    #expect(session.leader == .miki)
  }

  @Test
  func leadershipCyclesThroughAllThreeMembers() {
    let session = GameSession(level: TestYard.level)
    for expected in [PartyMember.laura, .tom, .miki, .laura] {
      session.cycleLeader()
      #expect(session.leader == expected)
    }
  }

  @Test
  func pauseKeepsTheLeaderAndRejectsSwitching() {
    let session = GameSession(level: TestYard.level)
    session.cycleLeader()
    session.togglePause()
    #expect(session.mode == .paused)
    #expect(session.isPaused)
    session.cycleLeader()
    #expect(session.leader == .laura)

    session.togglePause()
    #expect(session.mode == .exploring)
    #expect(session.leader == .laura)
    session.cycleLeader()
    #expect(session.leader == .tom)
  }

  @Test
  func aHeldSwitchProducesOnlyOneLeadershipChange() {
    let session = GameSession(level: TestYard.level)
    var state = InputRules.State(needsNeutralInput: false)
    func sample(_ raw: InputRules.Raw) {
      let result = InputRules.resolve(raw, mode: session.mode, state: state)
      state = result.state
      if result.input.switchPressed { session.cycleLeader() }
    }

    for _ in 0..<4 { sample(.init(controllerSwitch: true)) }
    #expect(session.leader == .laura)
    sample(.init())
    sample(.init(controllerSwitch: true))
    #expect(session.leader == .tom)
  }

  // MARK: - Conversations and the pause menu, with the bridge's exchange

  @Test
  func aConversationHoldsActionsAndSwitchingUntilItsLastLine() {
    let session = GameSession(level: BrooklynBridge.level)
    #expect(session.converse(.arrival))
    #expect(session.mode == .dialogue)
    #expect(session.currentLine == MissionScript.lines(.arrival).first)
    session.cycleLeader()
    #expect(session.leader == .miki)
    for line in MissionScript.lines(.arrival).dropFirst() {
      session.advanceDialogue()
      #expect(session.currentLine == line)
    }
    session.advanceDialogue()
    #expect(session.mode == .exploring)
    #expect(session.currentLine == nil)
    session.cycleLeader()
    #expect(session.leader == .tom)
  }

  @Test
  func pauseKeepsTheConversationAtItsLine() {
    let session = GameSession(level: BrooklynBridge.level)
    #expect(session.converse(.arrival))
    session.advanceDialogue()
    let line = session.currentLine
    session.togglePause()
    #expect(session.mode == .paused)
    session.advanceDialogue()
    #expect(session.currentLine == line)
    session.togglePause()
    #expect(session.mode == .dialogue)
    #expect(session.currentLine == line)
  }

  /// Resume, Restart, Vibration and Status panel.
  @Test
  func thePauseMenuOpensOnResumeAndHasFourChoices() {
    let session = GameSession(level: BrooklynBridge.level)
    session.movePauseChoice(by: 1)
    session.togglePause()
    #expect(session.pauseChoice == .resume)
    session.movePauseChoice(by: -1)
    #expect(session.pauseChoice == .resume)
    session.movePauseChoice(by: 1)
    #expect(session.pauseChoice == .restart)
    session.movePauseChoice(by: 1)
    #expect(session.pauseChoice == .vibration)
    session.movePauseChoice(by: 1)
    #expect(session.pauseChoice == .statusPanel)
    session.movePauseChoice(by: 1)
    #expect(session.pauseChoice == .statusPanel)
    session.movePauseChoice(by: -1)
    #expect(session.pauseChoice == .vibration)
    session.movePauseChoice(by: -1)
    #expect(session.pauseChoice == .restart)
    session.movePauseChoice(by: -1)
    #expect(session.pauseChoice == .resume)
    session.movePauseChoice(by: 1)
    session.togglePause()
    session.togglePause()
    #expect(session.pauseChoice == .resume)
  }

  @Test
  func restartLeavesNoConversationOrMenuChoiceBehind() {
    let session = GameSession(level: BrooklynBridge.level)
    #expect(session.converse(.arrival))
    session.togglePause()
    session.movePauseChoice(by: 1)
    session.restart()
    #expect(session.mode == .exploring)
    #expect(session.conversation == nil && session.currentLine == nil)
    #expect(session.pauseChoice == .resume)
    // Pause after Restart resumes to exploring, not to the old conversation.
    session.togglePause()
    session.togglePause()
    #expect(session.mode == .exploring)
  }
}
