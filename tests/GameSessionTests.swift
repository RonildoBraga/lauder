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
}
