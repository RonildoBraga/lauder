import Testing

@testable import Lauder

struct GuardStrategyTests {
  @Test(arguments: [Weapon.longRifle, .assaultRifle, .shotgun, .energySword, .minigun])
  func everyDamagingWeaponCanFinishWithOrdinaryBodyHits(weapon: Weapon) throws {
    var state = GuardStrategy()
    var dealt = 0
    while state.health > 0 {
      let result = state.accept(weapon: weapon.kind, part: nil, damage: weapon.damage)
      let hit = try #require(result)
      #expect(hit.amount > 0 && hit.amount <= weapon.damage)
      #expect(hit.effectiveness == .normal && !hit.brokeComponent)
      dealt += hit.amount
    }
    #expect(dealt == GuardStrategy.maximumHealth && state.phase == .complete)
    #expect(state.detachedLegs.isEmpty && state.swordHits.isEmpty)
  }

  @Test(arguments: [Weapon.longRifle, .assaultRifle, .shotgun, .energySword, .minigun, .rifle])
  func anEyeContactIsAlwaysCriticalForEveryWeapon(weapon: Weapon) throws {
    var state = GuardStrategy()
    for _ in 0..<3 {
      let result = state.accept(weapon: weapon.kind, part: .eye, damage: weapon.damage)
      let hit = try #require(result)
      #expect(hit.amount == weapon.damage * GuardStrategy.weakpointMultiplier)
      #expect(hit.effectiveness == .weakpoint && hit.detachedLeg == nil)
    }
    #expect(state.phase == .active && state.detachedLegs.isEmpty)
  }

  @Test
  func threeRealSwordContactsOnOneLegDetachItOnceAndKeepOrdinaryDamage() throws {
    var state = GuardStrategy()
    for count in 1...GuardStrategy.swordHitsToDetach {
      let result = state.accept(weapon: .energySword, part: .leg(2), damage: 30)
      let hit = try #require(result)
      #expect(hit.amount == 30 && hit.effectiveness == .normal)
      #expect(state.swordHits[2] == count)
      #expect(hit.detachedLeg == (count == 3 ? 2 : nil))
      #expect(hit.brokeComponent == (count == 3))
    }
    #expect(state.detachedLegs == [2] && state.speedMultiplier == 0.75)
    let repeated = state.accept(weapon: .energySword, part: .leg(2), damage: 30)
    #expect(repeated?.detachedLeg == nil && repeated?.amount == 30)
    #expect(state.swordHits[2] == 3 && state.detachedLegs == [2])
    #expect(state.health == GuardStrategy.maximumHealth - 120)
  }

  @Test
  func contactsOnDifferentLegsDoNotPoolTheirStructuralDamage() {
    var state = GuardStrategy()
    for _ in 0..<2 {
      for index in 0..<GuardStrategy.legCount {
        _ = state.accept(weapon: .energySword, part: .leg(index), damage: 30)
      }
    }
    #expect(state.detachedLegs.isEmpty && state.speedMultiplier == 1)
    #expect((0..<4).allSatisfy { state.swordHits[$0] == 2 })
    _ = state.accept(weapon: .energySword, part: .leg(1), damage: 30)
    #expect(state.detachedLegs == [1] && state.swordHits[0] == 2)
  }

  @Test
  func gunsBodySwingsInvalidIndicesAndSplashCannotManufactureLegProgress() {
    var state = GuardStrategy()
    for weapon: Weapon.Kind? in [.longRifle, .shotgun, .minigun, nil] {
      for _ in 0..<3 { _ = state.accept(weapon: weapon, part: .leg(0), damage: 1) }
    }
    for part: GuardStrategy.Part? in [nil, .leg(-1), .leg(4), .leg(Int.max)] {
      for _ in 0..<3 { _ = state.accept(weapon: .energySword, part: part, damage: 1) }
    }
    let splash = state.accept(weapon: nil, part: .eye, damage: 10)
    #expect(splash?.amount == 10 && splash?.effectiveness == .normal)
    #expect(state.detachedLegs.isEmpty && state.swordHits.isEmpty && state.speedMultiplier == 1)
    #expect(state.health < GuardStrategy.maximumHealth)
  }

  @Test
  func eachLostLegReducesWalkingByOneQuarterWithoutDefeatingTheGuard() {
    var state = GuardStrategy()
    #expect(state.turnMultiplier == 1)
    let turning: [Float] = [0.65, 0.4, 0.2, 0.1]
    for index in 0..<4 {
      for _ in 0..<3 { _ = state.accept(weapon: .energySword, part: .leg(index), damage: 30) }
      #expect(state.speedMultiplier == 1 - Float(index + 1) * 0.25)
      #expect(state.turnMultiplier == turning[index])
    }
    #expect(state.detachedLegs == [0, 1, 2, 3] && state.speedMultiplier == 0)
    #expect(state.health == GuardStrategy.maximumHealth - 360 && state.phase == .active)
  }

  @Test
  func ordinaryAndCriticalOverkillReportOnlyActualHealthLost() throws {
    for part: GuardStrategy.Part? in [nil, .eye] {
      var state = GuardStrategy()
      let result = state.accept(weapon: .longRifle, part: part, damage: .max)
      let hit = try #require(result)
      #expect(hit.amount == GuardStrategy.maximumHealth && hit.defeated)
      #expect(hit.effectiveness == (part == .eye ? .weakpoint : .normal))
      #expect(state.health == 0 && state.phase == .complete)
      let defeated = state
      let stale = state.accept(weapon: .energySword, part: .leg(0), damage: 30)
      #expect(stale == nil && state == defeated)
    }
  }

  @Test
  func invalidDamageCannotMutateTheGuardAndResetRestoresAllLegs() {
    var state = GuardStrategy()
    for _ in 0..<3 { _ = state.accept(weapon: .energySword, part: .leg(0), damage: 30) }
    let before = state
    for damage in [0, -1, Int.min] {
      let invalid = state.accept(weapon: .energySword, part: .leg(1), damage: damage)
      #expect(invalid == nil && state == before)
    }
    let reset = GuardStrategy()
    #expect(reset.health == GuardStrategy.maximumHealth && reset.phase == .active)
    #expect(reset.swordHits.isEmpty && reset.detachedLegs.isEmpty && reset.speedMultiplier == 1)
    #expect(reset.turnMultiplier == 1)
  }
}
