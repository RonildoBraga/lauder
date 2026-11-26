import Testing

@testable import Lauder

struct GuardTargetingTests {
  @Test
  func unawareAcquisitionStaysLeaderOnlyEvenWhenCompanionsAreExposed() {
    var policy = GuardTargeting()
    policy.recordAttack(by: .tom)
    let selected = policy.select(
      leader: .miki, phase: .patrol, engaged: false, eligible: [.tom])
    #expect(selected == .miki && !policy.isRetaliation)
  }

  @Test
  func onlyActualRecentEligibleAttacksCanReplaceLeader() {
    var policy = GuardTargeting()
    #expect(
      policy.select(leader: .miki, phase: .patrol, engaged: true, eligible: [.tom, .laura])
        == .miki)
    policy.recordAttack(by: .tom)
    policy.advance(dt: 1)
    policy.recordAttack(by: .laura)
    #expect(
      policy.select(leader: .miki, phase: .patrol, engaged: true, eligible: [.tom]) == .tom)
    #expect(policy.isRetaliation)
    #expect(
      policy.select(leader: .miki, phase: .patrol, engaged: true, eligible: [.tom, .laura])
        == .laura)
    #expect(
      policy.select(leader: .miki, phase: .patrol, engaged: true, eligible: []) == .miki)
    #expect(!policy.isRetaliation)
  }

  @Test
  func sightEligibilityAloneDoesNotCreateAnAttackMemory() {
    var policy = GuardTargeting()
    for _ in 0..<600 {
      #expect(
        policy.select(leader: .miki, phase: .searching, engaged: true, eligible: [.tom])
          == .miki)
      policy.advance(dt: 1 / 60)
    }
  }

  @Test
  func attackMemoryExpiresBeforeTheNextAcquisition() {
    var policy = GuardTargeting()
    policy.recordAttack(by: .tom)
    policy.advance(dt: GuardTargeting.attackMemory - 0.01)
    #expect(
      policy.select(leader: .miki, phase: .patrol, engaged: true, eligible: [.tom]) == .tom)
    policy.advance(dt: 0.02)
    #expect(
      policy.select(leader: .miki, phase: .patrol, engaged: true, eligible: [.tom]) == .miki)
    #expect(!policy.isRetaliation)
    policy.recordAttack(by: .laura)
    policy.advance(dt: GuardTargeting.attackMemory)
    #expect(
      policy.select(leader: .miki, phase: .searching, engaged: true, eligible: [.laura])
        == .miki)
  }

  @Test
  func warnedCycleKeepsItsActorDespiteLeaderSwitchNewAttacksSightLossAndExpiry() {
    var policy = GuardTargeting()
    policy.recordAttack(by: .tom)
    #expect(
      policy.select(leader: .miki, phase: .patrol, engaged: true, eligible: [.tom]) == .tom)
    for phase in [
      RobotGuard.Phase.notice, .tracking, .committed, .burst, .recovering,
    ] {
      policy.recordAttack(by: .miki)
      policy.advance(dt: GuardTargeting.attackMemory)
      #expect(
        policy.select(leader: .tom, phase: phase, engaged: true, eligible: [.miki]) == .tom)
      #expect(policy.isRetaliation)
    }
    #expect(
      policy.select(leader: .laura, phase: .searching, engaged: true, eligible: [.tom])
        == .laura)
    #expect(!policy.isRetaliation)
  }

  @Test
  func lostSightDoesNotSwitchActorsInsideAWarningAndReacquisitionStartsFresh() {
    var policy = GuardTargeting()
    policy.recordAttack(by: .tom)
    #expect(
      policy.select(leader: .miki, phase: .patrol, engaged: true, eligible: [.tom]) == .tom)
    #expect(
      policy.select(leader: .miki, phase: .tracking, engaged: true, eligible: [.miki]) == .tom)
    // The guard receives hasSight=false for Tom and returns to searching. A replacement
    // can only be supplied in that acquisition phase, before a new Notice/Tracking cycle.
    #expect(
      policy.select(leader: .miki, phase: .searching, engaged: true, eligible: [.miki])
        == .miki)
    #expect(
      policy.select(leader: .miki, phase: .notice, engaged: true, eligible: [.tom]) == .miki)
  }

  @Test
  func tiesAreStableAndRecentVisibleLeaderFireCanWinToo() {
    var policy = GuardTargeting()
    for member in PartyMember.allCases.reversed() { policy.recordAttack(by: member) }
    #expect(
      policy.select(
        leader: .tom, phase: .patrol, engaged: true, eligible: Set(PartyMember.allCases)) == .miki)
    policy.advance(dt: 0.1)
    policy.recordAttack(by: .tom)
    #expect(
      policy.select(
        leader: .tom, phase: .searching, engaged: true, eligible: Set(PartyMember.allCases))
        == .tom)
    #expect(
      policy.isRetaliation, "real leader fire may also draw retaliation outside the quiet cone")
  }

  @Test
  func resetAndTerminalPhasesRemoveTargetsAndRememberedAttacks() {
    for phase in [RobotGuard.Phase.hidden, .down, .cleared] {
      var policy = GuardTargeting()
      policy.recordAttack(by: .tom)
      _ = policy.select(leader: .miki, phase: .patrol, engaged: true, eligible: [.tom])
      #expect(policy.select(leader: .miki, phase: phase, engaged: true, eligible: [.tom]) == nil)
      #expect(!policy.isRetaliation)
      #expect(
        policy.select(leader: .miki, phase: .patrol, engaged: true, eligible: [.tom]) == .miki)
      policy.recordAttack(by: .tom)
      policy.reset()
      #expect(policy.member == nil && !policy.isRetaliation)
      #expect(
        policy.select(leader: .miki, phase: .patrol, engaged: true, eligible: [.tom]) == .miki)
    }
  }

  @Test
  func missingCycleTargetIsNotReplacedMidBurstAndInvalidTimeDoesNotAgeMemory() {
    var policy = GuardTargeting()
    #expect(
      policy.select(leader: .miki, phase: .burst, engaged: true, eligible: [.miki]) == nil)
    policy.recordAttack(by: .tom)
    for dt: Float in [0, -1, .nan, .infinity] { policy.advance(dt: dt) }
    #expect(
      policy.select(leader: .miki, phase: .patrol, engaged: true, eligible: [.tom]) == .tom)
  }
}
