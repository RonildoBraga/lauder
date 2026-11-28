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
    #expect(session.combatStance == .defend)
  }

  @Test
  func defendRecallsOrderedCompanionsWithoutCyclingFormation() {
    let session = GameSession(level: TestYard.level)
    session.cycleFormation()
    #expect(session.setCombatStance(.attack))
    session.cycleLeader()
    #expect(session.combatStance == .attack, "leadership does not change the standing stance")
    session.holdAll()
    #expect(session.setCombatStance(.defend))
    #expect(session.orders.isEmpty && session.combatStance == .defend)
    #expect(session.formation == .spread)
    session.send(session.companions[0], to: [2, 3])
    #expect(session.setCombatStance(.defend), "a repeated Defend press recalls new orders too")
    #expect(session.orders.isEmpty && session.formation == .spread)
  }

  @Test
  func stanceCommandsRespectPauseAndDialogueAndRestartDisarmsAttacks() {
    let session = GameSession(level: BrooklynBridge.level)
    #expect(session.setCombatStance(.attack))
    session.togglePause()
    #expect(!session.setCombatStance(.defend) && session.combatStance == .attack)
    session.togglePause()
    #expect(session.converse(.arrival))
    #expect(!session.setCombatStance(.defend) && session.combatStance == .attack)
    session.restart()
    #expect(session.combatStance == .defend)
  }

  @Test
  func encounterRetryRequiresAFreshAttackOrder() {
    let session = GameSession(level: BrooklynBridge.level)
    #expect(session.setCombatStance(.attack))
    #expect(session.beginEncounter(.stranger))
    #expect(session.combatStance == .attack)
    session.retryEncounter()
    #expect(!session.inEncounter && session.combatStance == .defend)
  }

  @Test
  func leadershipTogglesBetweenFightersWithoutRemovingLaura() {
    let session = GameSession(level: TestYard.level)
    for expected in [PartyMember.tom, .miki, .tom, .miki] {
      #expect(session.nextLeader == expected)
      session.cycleLeader()
      #expect(session.leader == expected)
      #expect(session.companions.contains(.laura))
      #expect(session.party == TestYard.level.party)
    }
  }

  @Test
  func supportingLauraDoesNotCreateASwitchTargetForASingleFighter() {
    let level = Level(
      id: "single-fighter", ground: TestYard.ground, boxes: [], triggers: [],
      party: [.miki, .laura], spawns: TestYard.level.spawns, heading: [0, -1],
      cameraOffset: TestYard.cameraOffset, fieldOfView: 42, opening: "", objective: "",
      lookAround: "", restartNote: "")
    let session = GameSession(level: level)
    #expect(session.nextLeader == nil && session.companions == [.laura])
    session.cycleLeader()
    #expect(session.leader == .miki)
    session.recruit(.tom)
    #expect(session.nextLeader == .tom)
    session.cycleLeader()
    #expect(session.nextLeader == .miki && session.companions.contains(.laura))
    #expect(session.rightCompanion != session.leftCompanion)
    #expect(
      Set([session.rightCompanion, session.leftCompanion].compactMap { $0 }) == [.miki, .laura])
  }

  @Test
  func pauseKeepsTheLeaderAndRejectsSwitching() {
    let session = GameSession(level: TestYard.level)
    session.cycleLeader()
    session.togglePause()
    #expect(session.mode == .paused)
    #expect(session.isPaused)
    session.cycleLeader()
    #expect(session.leader == .tom)

    session.togglePause()
    #expect(session.mode == .exploring)
    #expect(session.leader == .tom)
    session.cycleLeader()
    #expect(session.leader == .miki)
  }

  @Test(arguments: ["controller", "keyboard", "touch"])
  func aHeldSwitchProducesOnlyOneLeadershipChange(source: String) {
    let session = GameSession(level: TestYard.level)
    var state = InputRules.State(needsNeutralInput: false)
    func sample(_ raw: InputRules.Raw) {
      let result = InputRules.resolve(raw, mode: session.mode, state: state)
      state = result.state
      if result.input.switchPressed { session.cycleLeader() }
    }

    let pressed: InputRules.Raw =
      switch source {
      case "touch": .init(touchSwitch: true)
      case "keyboard": .init(keyboardSwitch: true)
      default: .init(controllerSwitch: true)
      }
    for _ in 0..<4 { sample(pressed) }
    #expect(session.leader == .tom)
    sample(.init())
    sample(pressed)
    #expect(session.leader == .miki)
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
