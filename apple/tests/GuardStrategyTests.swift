import Testing

@testable import Lauder

struct GuardStrategyTests {
  @Test
  func everyStepNeedsItsOwnCharacterWeaponAndExposedPart() {
    var guardState = GuardStrategy()
    #expect(guardState.phase == .sensor)
    #expect(
      guardState.accept(member: .miki, weapon: .longRifle, part: .sensor, recovering: false)
        == .blocked)
    #expect(
      guardState.accept(member: .miki, weapon: .assaultRifle, part: .sensor, recovering: true)
        == .blocked)
    #expect(
      guardState.accept(member: .tom, weapon: .longRifle, part: .sensor, recovering: true)
        == .blocked)
    #expect(
      guardState.accept(member: .miki, weapon: .longRifle, part: .reactor, recovering: true)
        == .blocked)
    #expect(
      guardState.accept(member: .miki, weapon: .longRifle, part: .sensor, recovering: true)
        == .progressed)
    #expect(guardState.phase == .coupling && guardState.sensorDisabled)
    #expect(
      guardState.accept(member: .laura, weapon: .shotgun, part: .coupling, recovering: false)
        == .blocked)
    #expect(
      guardState.accept(member: .miki, weapon: .energySword, part: .coupling, recovering: false)
        == .blocked)
    #expect(
      guardState.accept(member: .laura, weapon: .energySword, part: .reactor, recovering: false)
        == .blocked)
    #expect(
      guardState.accept(member: .laura, weapon: .energySword, part: .coupling, recovering: false)
        == .progressed)
    #expect(guardState.phase == .reactor && guardState.couplingBreached)
    #expect(
      guardState.accept(member: .tom, weapon: .minigun, part: .reactor, recovering: false)
        == .blocked)
    guardState.advance(delta: 0.01, recovering: true)
    #expect(
      guardState.accept(member: .tom, weapon: .assaultRifle, part: .reactor, recovering: true)
        == .blocked)
    #expect(
      guardState.accept(member: .miki, weapon: .minigun, part: .reactor, recovering: true)
        == .blocked)
    #expect(
      guardState.accept(member: .tom, weapon: .minigun, part: .coupling, recovering: true)
        == .blocked)
    #expect(
      guardState.accept(member: .tom, weapon: .minigun, part: .reactor, recovering: true)
        == .damaged)
    #expect(guardState.reactorDamage == 1)
  }

  @Test
  func structuralProgressPersistsAndMissedWindowsReopenWithoutResettingDamage() {
    var guardState = GuardStrategy()
    #expect(
      guardState.accept(member: .miki, weapon: .longRifle, part: .sensor, recovering: true)
        == .progressed)
    guardState.advance(delta: 100, recovering: false)
    #expect(guardState.phase == .coupling)
    #expect(
      guardState.accept(member: .laura, weapon: .energySword, part: .coupling, recovering: false)
        == .progressed)
    guardState.advance(delta: 100, recovering: false)
    #expect(guardState.phase == .reactor && guardState.windowRemaining == 0)
    guardState.advance(delta: 0.01, recovering: true)
    for _ in 0..<5 {
      #expect(
        guardState.accept(member: .tom, weapon: .minigun, part: .reactor, recovering: true)
          == .damaged)
    }
    guardState.advance(delta: GuardStrategy.windowDuration, recovering: true)
    #expect(guardState.windowRemaining == 0 && guardState.reactorDamage == 5)
    for _ in 0..<10 { guardState.advance(delta: 1, recovering: true) }
    #expect(
      !guardState.isExposed(.reactor, recovering: true),
      "the same recovery cannot refresh an expired window")
    guardState.advance(delta: 1, recovering: false)
    guardState.advance(delta: 0.01, recovering: true)
    #expect(guardState.windowRemaining == GuardStrategy.windowDuration)
    for _ in 0..<6 {
      #expect(
        guardState.accept(member: .tom, weapon: .minigun, part: .reactor, recovering: true)
          == .damaged)
    }
    #expect(
      guardState.accept(member: .tom, weapon: .minigun, part: .reactor, recovering: true)
        == .defeated)
    #expect(guardState.phase == .complete && guardState.reactorDamage == 12)
    guardState.advance(delta: 1, recovering: false)
    guardState.advance(delta: 1, recovering: true)
    #expect(guardState.windowRemaining == 0)
    #expect(
      guardState.accept(member: .tom, weapon: .minigun, part: .reactor, recovering: true)
        == .blocked)
  }

  @Test
  func aLateBreachStillGivesTheWholeIndependentWindow() {
    var guardState = GuardStrategy()
    guardState.advance(delta: 0.01, recovering: true)
    _ = guardState.accept(member: .miki, weapon: .longRifle, part: .sensor, recovering: true)
    guardState.advance(delta: 3.9, recovering: true)
    #expect(
      guardState.accept(member: .laura, weapon: .energySword, part: .coupling, recovering: true)
        == .progressed)
    #expect(guardState.windowRemaining == 4)
    guardState.advance(delta: 0.25, recovering: false)
    #expect(guardState.windowRemaining == 3.75)
    #expect(
      guardState.accept(member: .tom, weapon: .minigun, part: .reactor, recovering: false)
        == .damaged)
    let previous = guardState
    for delta: Float in [0, -1, .nan, .infinity] {
      guardState.advance(delta: delta, recovering: true)
      #expect(guardState == previous)
    }
  }

  @Test
  func noSoloCharacterOrPairCanFinishTheSequence() {
    let teams: [[PartyMember]] = [
      [.miki], [.laura], [.tom], [.miki, .laura], [.miki, .tom], [.laura, .tom],
    ]
    for team in teams {
      var guardState = GuardStrategy()
      for _ in 0..<4 {
        guardState.advance(delta: 1, recovering: false)
        guardState.advance(delta: 0.01, recovering: true)
        for _ in 0..<20 {
          for member in team {
            for weapon in Weapon.pair(for: member) {
              for part in GuardStrategy.Part.allCases {
                #expect(
                  guardState.accept(
                    member: member, weapon: weapon.kind, part: part, recovering: true) != .defeated)
              }
            }
          }
        }
      }
      #expect(guardState.phase != .complete)
    }
  }

  @Test
  func separateEncountersOwnIndependentProgressAndTimers() {
    var first = GuardStrategy()
    _ = first.accept(member: .miki, weapon: .longRifle, part: .sensor, recovering: true)
    _ = first.accept(member: .laura, weapon: .energySword, part: .coupling, recovering: true)
    var second = first
    first.advance(delta: 4, recovering: true)
    #expect(first.windowRemaining == 0 && second.windowRemaining == 4)
    _ = second.accept(member: .tom, weapon: .minigun, part: .reactor, recovering: true)
    #expect(first.reactorDamage == 0 && second.reactorDamage == 1)
    #expect(GuardStrategy().phase == .sensor)
  }
}
