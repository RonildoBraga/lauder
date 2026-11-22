import Testing

@testable import Lauder

@MainActor
struct WeaponArsenalTests {
  @Test
  func rapidAndMeasuredWeaponsProduceDifferentCadencesUsingProductionHandling() {
    func discharges(_ weapon: Weapon) -> Int {
      var handling = WeaponHandling(weapon: weapon)
      handling.draw()
      var count = 0
      for _ in 0..<240 {
        handling.advance(dt: 1 / 120)
        if handling.isReady {
          handling.fired()
          count += 1
        }
      }
      return count
    }
    let smg = discharges(.submachineGun)
    let sniper = discharges(.marksman)
    let support = discharges(.supportGun)
    #expect(smg > support && support > sniper && sniper > 0)
    #expect(Weapon.marksman.range > Weapon.supportGun.range)
    #expect(Weapon.submachineGun.spread.rest > Weapon.marksman.spread.rest)
    #expect(Weapon.supportGun.reloadTime > Weapon.submachineGun.reloadTime)
  }

  @Test
  func longTravelDoesNotGrantScatterItsCloseStoppingBonusAcrossTheMap() {
    #expect(Weapon.closeScatter.damage(at: 5) == 2)
    #expect(Weapon.closeScatter.damage(at: 45) == 1)
    #expect(Weapon.marksman.damage(at: 45) == 2)
    #expect(Weapon.carbine.damage(at: 45) == 1)
  }

  @Test(arguments: Weapon.testKinds)
  func eachTestWeaponHasItsOwnPropMuzzleSoundAndLeaderFeedback(kind: Weapon.Kind) throws {
    let weapon = Weapon.forKind(kind)
    #expect(weapon.kind == kind && !kind.name.isEmpty)
    let profile = WeaponPose.profile(for: kind)
    #expect(profile.barrel > 0 && profile.kickBack > 0)
    let event = CombatEvent.fired(kind, at: .zero, byLeader: true)
    let sound = try #require(CombatSound.of(event))
    #expect(sound.url != nil)
    let cue = try #require(HapticCue.of(event))
    #expect((try? cue.pattern()) != nil)
    #expect(HapticCue.of(.fired(kind, at: .zero, byLeader: false)) == nil)
    let trigger = CombatHaptics.triggerProfile(for: kind)
    #expect(trigger.start < trigger.end && trigger.strength > 0)
    let prop = SceneStyle().weapon(for: kind)
    #expect(!prop.children.isEmpty)
    if kind == .marksman { #expect(prop.findEntity(named: "weapon.scope") != nil) }
    if kind == .supportGun { #expect(prop.findEntity(named: "weapon.box-magazine") != nil) }
  }
}
