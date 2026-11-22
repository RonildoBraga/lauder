import RealityKit
import Testing
import simd

@testable import Lauder

/// A map-long hitscan path has a short moving visual, rather than a truncated ray or beam.
@MainActor
struct LongShotEffectsTests {
  @Test
  func aBridgeLengthTracerCrossesTheWholePathWhileRemainingShort() throws {
    let container = Entity()
    let effects = ShotEffects(style: SceneStyle(), in: container)
    effects.show(longTrace, side: .party, muzzle: nil)
    let tracer = try #require(shown("party.streak", in: container).first)
    effects.update(dt: ShotEffects.maximumFlightTime * 0.75)
    #expect(tracer.isEnabled && tracer.position.z < -370)
    #expect(tracer.scale.z <= ShotEffects.streakLength + 0.001)
    // The tail clears shortly after the capped head flight, regardless of map length.
    effects.update(dt: 0.05)
    #expect(!tracer.isEnabled)
  }

  @Test
  func simultaneousRapidFireRetainsEveryInflightTracerWithoutGrowingThePools() {
    let container = Entity()
    let effects = ShotEffects(style: SceneStyle(), in: container)
    let entities = container.children.count
    for _ in 0..<3 { effects.show(longTrace, side: .party, muzzle: nil) }
    for _ in 0..<4 { effects.show(longTrace, side: .hostile, muzzle: nil) }
    let oldestParty = shown("party.streak", in: container)
    let oldestHostile = shown("hostile.streak", in: container)
    effects.update(dt: 0.1)
    for _ in 0..<3 { effects.show(longTrace, side: .party, muzzle: nil) }
    for _ in 0..<4 { effects.show(longTrace, side: .hostile, muzzle: nil) }
    #expect(shown("party.streak", in: container).count == 6)
    #expect(shown("hostile.streak", in: container).count == 8)
    #expect(oldestParty.allSatisfy { $0.isEnabled && $0.position.z < -300 })
    #expect(oldestHostile.allSatisfy { $0.isEnabled && $0.position.z < -300 })
    // Continue at ten discharges/second per actor, including both companions. Older traces
    // finish before the next volley needs their slots; each new shot is still presented.
    for _ in 0..<30 {
      effects.update(dt: 0.1)
      for _ in 0..<3 { effects.show(longTrace, side: .party, muzzle: nil) }
      for _ in 0..<4 { effects.show(longTrace, side: .hostile, muzzle: nil) }
      #expect(shown("party.streak", in: container).count == 6)
      #expect(shown("hostile.streak", in: container).count == 8)
      #expect(container.children.count == entities)
    }
    effects.update(dt: 0.2)
    #expect(shown("party.streak", in: container).isEmpty)
    #expect(shown("hostile.streak", in: container).isEmpty)
  }

  @Test
  func aLongSlopedTraceLeavesItsImpactAtTheActualThreeDimensionalEndpoint() throws {
    let container = Entity()
    let effects = ShotEffects(style: SceneStyle(), in: container)
    let trace = Ballistics.Trace(start: [0, 3.65, 6], end: [3, 1.25, -40], strike: .scenery)
    effects.show(trace, side: .party, muzzle: nil)
    let mark = try #require(shown("shot.mark", in: container).first)
    #expect(simd_distance(mark.position, trace.end) < 0.021)
    #expect(effects.marksShown == 1)
    effects.update(dt: 0.04)
    let tracer = try #require(shown("party.streak", in: container).first)
    #expect(tracer.position.y < trace.start.y && tracer.position.y > trace.end.y)
    #expect(tracer.scale.z <= ShotEffects.streakLength + 0.001)
  }

  @Test
  func clearingCancelsLongTracersAndCannotReplayThemLater() {
    let container = Entity()
    let effects = ShotEffects(style: SceneStyle(), in: container)
    effects.show(longTrace, side: .hostile, muzzle: nil)
    effects.update(dt: 0.05)
    effects.clear()
    effects.update(dt: 0.2)
    #expect(container.children.allSatisfy { !$0.isEnabled })
  }

  private var longTrace: Ballistics.Trace {
    .init(start: [0, 1.25, 0], end: [0, 1.25, -500], strike: .nothing)
  }

  private func shown(_ name: String, in container: Entity) -> [Entity] {
    container.children.filter { $0.name == name && $0.isEnabled }
  }
}
