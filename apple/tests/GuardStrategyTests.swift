import Testing

@testable import Lauder

struct GuardStrategyTests {
  @Test(arguments: [
    Weapon.longRifle, .assaultRifle, .shotgun, .energySword, .minigun,
  ])
  func everyDamagingWeaponCanFinishWithOrdinaryBodyHits(weapon: Weapon) throws {
    var guardState = GuardStrategy()
    var dealt = 0
    var last: GuardStrategy.Hit?
    while guardState.health > 0 {
      let hitContact = guardState.accept(
        weapon: weapon.kind, part: nil, damage: weapon.damage, recovering: false)
      let hit = try #require(hitContact)
      #expect(hit.amount > 0 && hit.amount <= weapon.damage)
      #expect(hit.effectiveness == .normal && !hit.brokeComponent)
      dealt += hit.amount
      last = hit
    }
    #expect(last?.defeated == true && guardState.phase == .complete)
    #expect(dealt == GuardStrategy.maximumHealth)
    #expect(!guardState.sensorDisabled && !guardState.couplingBreached)
    #expect(guardState.reactorDamage == 0)
  }

  @Test
  func closedPartsAndUnmatchedWeaponsStillDealTheirOrdinaryDamage() throws {
    var guardState = GuardStrategy()
    let contacts: [(Weapon.Kind, GuardStrategy.Part, Int, Bool)] = [
      (.longRifle, .sensor, 48, false),
      (.assaultRifle, .sensor, 5, true),
      (.shotgun, .coupling, 45, true),
      (.energySword, .coupling, 30, true),
      (.minigun, .reactor, 3, true),
    ]
    var dealt = 0
    for (weapon, part, damage, recovering) in contacts {
      let hitContact = guardState.accept(
        weapon: weapon, part: part, damage: damage, recovering: recovering)
      let hit = try #require(hitContact)
      #expect(hit.amount == damage && hit.effectiveness == .normal)
      #expect(!hit.brokeComponent && !hit.defeated)
      dealt += damage
    }
    #expect(guardState.health == GuardStrategy.maximumHealth - dealt)
    #expect(guardState.phase == .sensor && !guardState.sensorDisabled)
    #expect(!guardState.couplingBreached && guardState.reactorDamage == 0)
  }

  @Test
  func matchedExposedPartsApplyOneBonusAndAdvanceOptionalComponents() throws {
    var guardState = GuardStrategy()
    let sensorContact = guardState.accept(
      weapon: .longRifle, part: .sensor, damage: 48, recovering: true)
    let sensor = try #require(sensorContact)
    #expect(sensor.amount == 144 && sensor.effectiveness == .weakpoint)
    #expect(sensor.brokeComponent && !sensor.defeated)
    #expect(guardState.phase == .coupling && guardState.sensorDisabled)

    let wrongWeaponContact = guardState.accept(
      weapon: .shotgun, part: .coupling, damage: 45, recovering: false)
    let wrongWeapon = try #require(wrongWeaponContact)
    #expect(wrongWeapon.amount == 45 && wrongWeapon.effectiveness == .normal)
    #expect(!wrongWeapon.brokeComponent && !guardState.couplingBreached)
    let couplingContact = guardState.accept(
      weapon: .energySword, part: .coupling, damage: 30, recovering: false)
    let coupling = try #require(couplingContact)
    #expect(coupling.amount == 90 && coupling.effectiveness == .weakpoint)
    #expect(coupling.brokeComponent && guardState.phase == .reactor)

    let closedContact = guardState.accept(
      weapon: .minigun, part: .reactor, damage: 3, recovering: false)
    let closed = try #require(closedContact)
    #expect(closed.amount == 3 && closed.effectiveness == .normal)
    guardState.advance(delta: 0.01, recovering: true)
    let coreContact = guardState.accept(
      weapon: .minigun, part: .reactor, damage: 3, recovering: true)
    let core = try #require(coreContact)
    #expect(core.amount == 9 && core.effectiveness == .weakpoint)
    #expect(!core.brokeComponent && !core.defeated)
    #expect(guardState.reactorDamage == 9)
    #expect(guardState.health == GuardStrategy.maximumHealth - 144 - 45 - 90 - 3 - 9)
  }

  @Test
  func structuralProgressAndHealthPersistAcrossMissedRepeatedWindows() throws {
    var guardState = openedGuard()
    let firstContact = guardState.accept(
      weapon: .minigun, part: .reactor, damage: 3, recovering: true)
    let first = try #require(firstContact)
    let health = guardState.health
    guardState.advance(delta: GuardStrategy.windowDuration, recovering: true)
    #expect(guardState.windowRemaining == 0 && guardState.reactorDamage == first.amount)
    for _ in 0..<10 { guardState.advance(delta: 1, recovering: true) }
    #expect(!guardState.isExposed(.reactor, recovering: true))
    #expect(guardState.health == health)
    guardState.advance(delta: 1, recovering: false)
    guardState.advance(delta: 0.01, recovering: true)
    #expect(guardState.windowRemaining == GuardStrategy.windowDuration)
    let secondContact = guardState.accept(
      weapon: .minigun, part: .reactor, damage: 3, recovering: true)
    let second = try #require(secondContact)
    #expect(second.effectiveness == .weakpoint && guardState.reactorDamage == 18)
    #expect(guardState.sensorDisabled && guardState.couplingBreached)
    #expect(guardState.health == health - second.amount)
  }

  @Test
  func aLateBreachStillGivesTheWholeIndependentBonusWindow() {
    var guardState = GuardStrategy()
    guardState.advance(delta: 0.01, recovering: true)
    _ = guardState.accept(weapon: .longRifle, part: .sensor, damage: 48, recovering: true)
    guardState.advance(delta: 3.9, recovering: true)
    let breach = guardState.accept(
      weapon: .energySword, part: .coupling, damage: 30, recovering: true)
    #expect(breach?.brokeComponent == true && guardState.windowRemaining == 4)
    guardState.advance(delta: 0.25, recovering: false)
    #expect(guardState.windowRemaining == 3.75)
    #expect(guardState.isExposed(.reactor, recovering: false))
  }

  @Test
  func anAlreadyBrokenPartDoesNotAwardAnotherBonusOrBreak() throws {
    var guardState = openedGuard()
    for (weapon, part): (Weapon.Kind, GuardStrategy.Part) in [
      (.longRifle, .sensor), (.energySword, .coupling),
    ] {
      let hitContact = guardState.accept(weapon: weapon, part: part, damage: 10, recovering: true)
      let hit = try #require(hitContact)
      #expect(hit.amount == 10 && hit.effectiveness == .normal && !hit.brokeComponent)
    }
  }

  @Test
  func ordinaryAndBonusOverkillReportOnlyActualHealthLost() throws {
    var ordinary = GuardStrategy()
    let bodyContact = ordinary.accept(
      weapon: .assaultRifle, part: nil, damage: .max, recovering: false)
    let body = try #require(bodyContact)
    #expect(body.amount == GuardStrategy.maximumHealth && body.defeated)
    #expect(body.effectiveness == .normal && ordinary.health == 0)

    var matched = openedGuard()
    let remaining = matched.health
    let coreContact = matched.accept(
      weapon: .minigun, part: .reactor, damage: .max, recovering: true)
    let core = try #require(coreContact)
    #expect(core.amount == remaining && core.defeated && core.effectiveness == .weakpoint)
    #expect(matched.reactorDamage == remaining && matched.health == 0)
    #expect(matched.phase == .complete && matched.windowRemaining == 0)
    #expect(!matched.isExposed(.reactor, recovering: true))
    let defeated = matched
    let afterDefeat = matched.accept(weapon: .minigun, part: .reactor, damage: 3, recovering: true)
    #expect(afterDefeat == nil)
    #expect(matched == defeated)
  }

  @Test
  func invalidDamageAndTimeCannotMutateTheGuard() {
    var guardState = openedGuard()
    let previous = guardState
    for damage in [0, -1, Int.min] {
      let invalid = guardState.accept(
        weapon: .minigun, part: .reactor, damage: damage, recovering: true)
      #expect(invalid == nil)
      #expect(guardState == previous)
    }
    for delta: Float in [0, -1, .nan, .infinity] {
      guardState.advance(delta: delta, recovering: true)
      #expect(guardState == previous)
    }
  }

  @Test
  func separateEncountersAndResetOwnTheirHealthProgressAndTimers() {
    var first = openedGuard()
    var second = first
    first.advance(delta: 4, recovering: true)
    #expect(first.windowRemaining == 0 && second.windowRemaining == 4)
    _ = second.accept(weapon: .minigun, part: .reactor, damage: 3, recovering: true)
    #expect(first.reactorDamage == 0 && second.reactorDamage == 9)
    #expect(first.health == second.health + 9)
    let reset = GuardStrategy()
    #expect(reset.phase == .sensor && reset.health == GuardStrategy.maximumHealth)
    #expect(!reset.sensorDisabled && !reset.couplingBreached)
    #expect(reset.reactorDamage == 0 && reset.windowRemaining == 0)
  }

  private func openedGuard() -> GuardStrategy {
    var guardState = GuardStrategy()
    _ = guardState.accept(weapon: .longRifle, part: .sensor, damage: 48, recovering: true)
    _ = guardState.accept(weapon: .energySword, part: .coupling, damage: 30, recovering: true)
    return guardState
  }
}
