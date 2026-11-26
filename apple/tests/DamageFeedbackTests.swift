import RealityKit
import Testing
import simd

@testable import Lauder

struct DamageFeedbackTests {
  @Test
  func rapidRoundsKeepEveryAmountWithoutRenewingTheOriginalNumber() throws {
    var feedback = DamageFeedback()
    feedback.receive(hit(amount: 2))
    let original = try #require(feedback.labels.first)
    feedback.advance(dt: 0.06)
    feedback.receive(hit(amount: 3, at: [1, 2, 3]))
    feedback.advance(dt: 0.06)
    feedback.receive(hit(amount: 4))
    let combined = try #require(feedback.labels.first)
    #expect(feedback.labels.count == 1 && combined.id == original.id)
    #expect(combined.amount == 9 && abs(combined.age - 0.12) < 0.0001)
    feedback.advance(dt: 0.06)
    feedback.receive(hit(amount: 5))
    #expect(feedback.labels.count == 2)
    #expect(feedback.labels.map(\.amount).reduce(0, +) == 14)
    #expect(feedback.labels[0].age > DamageFeedback.rapidWindow)
    #expect(feedback.labels[1].age == 0)
  }

  @Test
  func differentTargetsAttackersAndHitKindsNeverShareAMisleadingNumber() {
    var feedback = DamageFeedback()
    feedback.receive(hit(amount: 2))
    feedback.receive(hit(amount: 4, effectiveness: .weakpoint))
    feedback.receive(hit(amount: 3, target: "second"))
    feedback.receive(hit(amount: 5, attacker: .miki))
    feedback.receive(hit(amount: 7, weapon: .shotgun))
    feedback.receive(hit(amount: 7, weapon: .shotgun))
    #expect(feedback.labels.count == 6)
    #expect(feedback.labels.filter { $0.effectiveness == .weakpoint }.map(\.amount) == [4])
    #expect(feedback.labels.filter { $0.target == "second" }.map(\.amount) == [3])
    #expect(feedback.labels.filter { $0.attacker == .miki }.map(\.amount) == [5])
    #expect(feedback.labels.map(\.amount).reduce(0, +) == 28)
  }

  @Test
  func aRapidComponentBreakRetainsTheAmountsCategoryAndLatestImpact() throws {
    var feedback = DamageFeedback()
    feedback.receive(hit(amount: 4, effectiveness: .weakpoint))
    feedback.advance(dt: 0.06)
    feedback.receive(
      hit(amount: 7, at: [3, 1.45, -2], effectiveness: .weakpoint, brokeComponent: true))
    let label = try #require(feedback.labels.first)
    #expect(feedback.labels.count == 1 && label.amount == 11)
    #expect(label.effectiveness == .weakpoint && label.brokeComponent)
    #expect(label.position == SIMD3<Float>(3, 1.45, -2) && label.age > 0)
  }

  @Test
  func continuousRapidFireCannotKeepAnOldNumberAliveForever() throws {
    var feedback = DamageFeedback()
    feedback.receive(hit(amount: 1))
    let original = try #require(feedback.labels.first).id
    for _ in 0..<16 {
      feedback.advance(dt: 0.06)
      feedback.receive(hit(amount: 1))
    }
    #expect(!feedback.labels.contains { $0.id == original })
    #expect(feedback.labels.count <= DamageFeedback.maximumLabels)
    feedback.advance(dt: DamageFeedback.lifetime)
    #expect(feedback.labels.isEmpty)
  }

  @Test
  func theVisibleSetIsBoundedAndClearingCannotReplayOrReuseOldLabels() throws {
    var feedback = DamageFeedback()
    for _ in 0..<20 { feedback.receive(hit(amount: 1, weapon: .longRifle)) }
    #expect(feedback.labels.count == DamageFeedback.maximumLabels)
    let previous = try #require(feedback.labels.last).id
    feedback.clear()
    feedback.advance(dt: 1)
    #expect(feedback.labels.isEmpty)
    feedback.receive(hit(amount: 2))
    #expect(try #require(feedback.labels.first).id > previous)
  }

  @Test
  func invalidOrZeroDamageNeverCreatesFeedbackAndInvalidTimeCannotAgeIt() {
    var feedback = DamageFeedback()
    feedback.receive(hit(amount: 0))
    feedback.receive(hit(amount: -1))
    feedback.receive(hit(amount: 3, at: [.nan, 1, 0]))
    #expect(feedback.labels.isEmpty)
    feedback.receive(hit(amount: 1))
    let before = feedback
    for dt: Float in [0, -1, .nan, .infinity] { feedback.advance(dt: dt) }
    #expect(feedback == before)
  }

  @Test
  func aDamageResultHasItsActualSpatialContextButDoesNotDuplicateSoundOrHaptics() {
    let result = hit(amount: 7, at: [3, 2, -4])
    let event = CombatEvent.damaged(result)
    #expect(event.position == SIMD2<Float>(3, -4))
    #expect(CombatSound.of(event) == nil && HapticCue.of(event) == nil)
  }

  private func hit(
    amount: Int, target: String = "guard", attacker: PartyMember = .tom,
    weapon: Weapon.Kind = .minigun, at position: SIMD3<Float> = [0, 1.25, 0],
    effectiveness: DamageHit.Effectiveness = .normal, brokeComponent: Bool = false
  ) -> DamageHit {
    DamageHit(
      target: target, attacker: attacker, weapon: weapon, amount: amount, position: position,
      effectiveness: effectiveness, brokeComponent: brokeComponent)
  }
}

@MainActor
struct DamageImpactTests {
  @Test
  func onlyAcceptedEffectiveDamageAddsABoundedRateLimitedAccentAtTheActualImpact() throws {
    let container = Entity()
    let effects = ShotEffects(style: SceneStyle(), in: container)
    let count = container.children.count
    let point: SIMD3<Float> = [2, 1.45, -3]
    func hit(_ effectiveness: DamageHit.Effectiveness, broken: Bool = false) -> DamageHit {
      DamageHit(
        target: "guard", attacker: .tom, weapon: .minigun, amount: 4, position: point,
        effectiveness: effectiveness, brokeComponent: broken)
    }
    effects.showDamage(hit(.normal))
    #expect(shown(in: container).isEmpty)
    effects.showDamage(hit(.weakpoint))
    let first = try #require(shown(in: container).first)
    #expect(first.position == point)
    effects.showDamage(hit(.weakpoint))
    effects.update(dt: 0.06)
    effects.showDamage(hit(.weakpoint))
    #expect(shown(in: container).count == 1)
    effects.update(dt: 0.06)
    #expect(shown(in: container).isEmpty)
    effects.showDamage(hit(.weakpoint))
    effects.showDamage(hit(.weakpoint, broken: true))
    #expect(shown(in: container).count == 2)
    for _ in 0..<20 { effects.showDamage(hit(.weakpoint, broken: true)) }
    #expect(shown(in: container).count == 4 && container.children.count == count)
    effects.show(
      Ballistics.Trace(start: [0, 1, 0], end: [0, 1, -100], strike: .nothing),
      side: .party, muzzle: nil)
    effects.clearDamage()
    #expect(shown(in: container).isEmpty)
    #expect(container.children.contains { $0.name == "party.streak" && $0.isEnabled })
    effects.clear()
    effects.update(dt: 1)
    #expect(container.children.allSatisfy { !$0.isEnabled })
  }

  private func shown(in container: Entity) -> [Entity] {
    container.children.filter { $0.name == "shot.effective" && $0.isEnabled }
  }
}
