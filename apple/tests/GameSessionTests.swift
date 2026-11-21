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

  /// Previous cycles the other way (ADR 0005); with two in the party it leads as Next does.
  @Test
  func previousCyclesBackwardsAndMatchesNextWithTwo() {
    let session = GameSession(level: TestYard.level)
    for expected in [PartyMember.tom, .laura, .miki] {
      session.cycleLeaderBackwards()
      #expect(session.leader == expected)
    }
    session.togglePause()
    session.cycleLeaderBackwards()
    #expect(session.leader == .miki)
    let bridge = GameSession(level: BrooklynBridge.level)
    #expect(bridge.previousLeader == nil)
    bridge.recruit(.tom)
    #expect(bridge.previousLeader == .tom && bridge.nextLeader == .tom)
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
    session.recruit(.tom)
    #expect(session.converse(.metTom))
    #expect(session.mode == .dialogue)
    #expect(session.currentLine == MissionScript.lines(.metTom).first)
    session.cycleLeader()
    #expect(session.leader == .miki)
    #expect(session.perform(.searchStranger) == .unavailable)
    for line in MissionScript.lines(.metTom).dropFirst() {
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
    #expect(session.converse(.metTom))
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

  /// Resume, Restart, while the combat experiment lasts the other level (ADR 0005), and
  /// Vibration (ADR 0008).
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
    #expect(session.pauseChoice == .otherLevel)
    session.movePauseChoice(by: 1)
    #expect(session.pauseChoice == .vibration)
    session.movePauseChoice(by: 1)
    #expect(session.pauseChoice == .vibration)
    session.movePauseChoice(by: -1)
    #expect(session.pauseChoice == .otherLevel)
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
    #expect(session.converse(.metTom))
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
