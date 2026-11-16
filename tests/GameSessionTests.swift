import Testing

@testable import Lauder

@MainActor
struct GameSessionTests {
  @Test
  func startsExploringWithMiki() {
    let session = GameSession()
    #expect(session.mode == .exploring)
    #expect(!session.isPaused)
    #expect(session.leader == .miki)
  }

  @Test
  func leadershipCyclesThroughAllThreeMembers() {
    let session = GameSession()
    for expected in [PartyMember.lara, .tomas, .miki, .lara] {
      session.cycleLeader()
      #expect(session.leader == expected)
    }
  }

  @Test
  func pauseKeepsTheLeaderAndRejectsSwitching() {
    let session = GameSession()
    session.cycleLeader()
    session.togglePause()
    #expect(session.mode == .paused)
    #expect(session.isPaused)
    session.cycleLeader()
    #expect(session.leader == .lara)

    session.togglePause()
    #expect(session.mode == .exploring)
    #expect(session.leader == .lara)
    session.cycleLeader()
    #expect(session.leader == .tomas)
  }

  @Test
  func aHeldSwitchProducesOnlyOneLeadershipChange() {
    let session = GameSession()
    var state = InputRules.State(needsNeutralInput: false)
    func sample(_ raw: InputRules.Raw) {
      let result = InputRules.resolve(raw, mode: session.mode, state: state)
      state = result.state
      if result.input.switchPressed { session.cycleLeader() }
    }

    for _ in 0..<4 { sample(.init(controllerSwitch: true)) }
    #expect(session.leader == .lara)
    sample(.init())
    sample(.init(controllerSwitch: true))
    #expect(session.leader == .tomas)
  }
}
