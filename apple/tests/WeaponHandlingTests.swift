import Testing

@testable import Lauder

/// The same weapon must keep its mechanical limits when its owner changes roles.
struct WeaponHandlingTests {
  @Test(arguments: [Weapon.carbine, .lightBurst, .closeScatter])
  func drawingOnceWaitsForReadinessWithoutRestartingTheDelay(weapon: Weapon) {
    var handling = WeaponHandling(weapon: weapon)
    #expect(!handling.isDrawn && !handling.isReady)
    #expect(handling.magazineRemaining == weapon.capacity)
    handling.draw()
    handling.advance(dt: weapon.drawTime - 0.001)
    #expect(handling.isDrawn && !handling.isReady)
    handling.draw()
    handling.advance(dt: 0.002)
    #expect(handling.isReady)
  }

  @Test(arguments: [Weapon.carbine, .lightBurst, .closeScatter])
  func anEmptyMagazineAutomaticallyReloadsWithoutFiringThroughTheWait(weapon: Weapon) {
    var handling = WeaponHandling(weapon: weapon)
    handling.draw()
    handling.advance(dt: weapon.drawTime + 0.001)
    for index in 0..<weapon.capacity {
      #expect(handling.isReady)
      handling.fired()
      if index + 1 < weapon.capacity { handling.advance(dt: weapon.interval + 0.001) }
    }
    #expect(handling.magazineRemaining == 0 && handling.reloadRemaining > 0)
    #expect(!handling.isReady)
    handling.fired()
    #expect(handling.magazineRemaining == 0)
    handling.advance(dt: weapon.reloadTime - 0.001)
    #expect(handling.magazineRemaining == 0 && !handling.isReady)
    handling.advance(dt: 0.002)
    #expect(handling.magazineRemaining == weapon.capacity && handling.reloadRemaining == 0)
    handling.advance(dt: weapon.interval)
    #expect(handling.isReady)
  }

  @Test
  func lauraFiresThreeShortGapsThenWaitsBetweenBursts() {
    let weapon = Weapon.lightBurst
    var handling = WeaponHandling(weapon: weapon)
    handling.draw()
    handling.advance(dt: weapon.drawTime + 0.001)
    for index in 0..<3 {
      #expect(handling.isReady)
      handling.fired()
      #expect(handling.magazineRemaining == weapon.capacity - index - 1)
      handling.advance(dt: weapon.burstGap - 0.001)
      #expect(!handling.isReady)
      handling.advance(dt: 0.002)
      if index < 2 { #expect(handling.isReady) }
    }
    #expect(!handling.isReady)
    handling.advance(dt: weapon.interval)
    #expect(handling.isReady)
  }

  @Test
  func releasingAnUnfinishedBurstCannotRefillOrShortenItsRecovery() {
    let weapon = Weapon.lightBurst
    var handling = WeaponHandling(weapon: weapon)
    handling.draw()
    handling.advance(dt: weapon.drawTime + 0.001)
    handling.fired()
    handling.releaseTrigger()
    handling.releaseTrigger()
    handling.advance(dt: weapon.burstGap + 0.01)
    #expect(!handling.isReady && handling.magazineRemaining == weapon.capacity - 1)
    handling.advance(dt: weapon.interval)
    #expect(handling.isReady && handling.magazineRemaining == weapon.capacity - 1)
  }

  @Test
  func anEmptyClickConsumesNoMagazineRoundAndKeepsTheOrdinaryRateLimit() {
    let weapon = Weapon.carbine
    var handling = WeaponHandling(weapon: weapon)
    handling.draw()
    handling.advance(dt: weapon.drawTime + 0.001)
    handling.emptyClick()
    #expect(!handling.isReady && handling.magazineRemaining == weapon.capacity)
    #expect(handling.reloadRemaining == 0)
    handling.advance(dt: weapon.interval - 0.001)
    #expect(!handling.isReady)
    handling.advance(dt: 0.002)
    #expect(handling.isReady)
  }
}
