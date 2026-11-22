import Testing
import simd

@testable import Lauder

struct ArenaWavesTests {
  private let slots = (0..<8).map {
    ArenaWaves.Slot(id: "slot-\($0)", point: [Float($0) * 10 - 35, -20])
  }
  private let party: [SIMD2<Float>] = [[0, 10], [-1, 11], [1, 11]]

  @Test
  func repeatsMixedPacksWithoutGrowingThePoolOrSkippingArrivalWarnings() {
    var waves = ArenaWaves(config: .init(slots: slots))
    var seen: Set<String> = []
    for expectedWave in 1...1000 {
      let ready = waves.step(dt: 10, defeated: [], party: party)
      #expect(ready.spawn.isEmpty)
      #expect(waves.wave == expectedWave)
      #expect(waves.warnings.count == (expectedWave.isMultiple(of: 2) ? 4 : 3))
      #expect(waves.warnings.values.allSatisfy { $0 == 2 })
      let arriving = waves.step(dt: 2, defeated: [], party: party)
      #expect(arriving.spawn.count == waves.packSize)
      #expect(waves.activeIDs == Set(arriving.spawn) && waves.warnings.isEmpty)
      #expect(waves.activeIDs.count <= 4 && waves.phase == .fighting)
      seen.formUnion(arriving.spawn)
      let cleared = waves.step(dt: 0.01, defeated: Set(arriving.spawn), party: party)
      #expect(cleared.resupply && waves.wave == expectedWave + 1)
      #expect(waves.activeIDs.isEmpty && waves.warnings.isEmpty && waves.phase == .recovering)
    }
    #expect(seen == Set(slots.map(\.id)))
  }

  @Test
  func aMarkerIsCancelledWhenAnyCompanionEntersAndAReplacementGetsTheFullWarning() throws {
    var waves = ArenaWaves(config: .init(slots: slots))
    _ = waves.step(dt: 1, defeated: [], party: party)
    let original = Set(waves.warnings.keys)
    let blocked = slots[0]
    #expect(original.contains(blocked.id))
    let arriving = waves.step(dt: 2, defeated: [], party: [party[0], blocked.point, party[2]])
    #expect(!arriving.spawn.contains(blocked.id))
    #expect(arriving.spawn.count == 2)
    let replacement = try #require(waves.warnings.first)
    #expect(!original.contains(replacement.key) && replacement.value == 2)
    // Root can also reject an occupied or otherwise unsuitable arrival at commit time.
    let rejected = waves.step(
      dt: 2, defeated: [], party: party, canSpawn: { $0.id != replacement.key })
    #expect(rejected.spawn.isEmpty && !waves.warnings.keys.contains(replacement.key))
    #expect(waves.warnings.values.allSatisfy { $0 == 2 })
  }

  @Test
  func unsafeSlotsWaitWithoutCreatingActorsOrAccumulatingAQueue() {
    var waves = ArenaWaves(config: .init(slots: slots))
    for _ in 0..<100 {
      let update = waves.step(dt: 1, defeated: [], party: party, canSpawn: { _ in false })
      #expect(update.spawn.isEmpty && !update.resupply)
    }
    #expect(waves.wave == 1 && waves.activeIDs.isEmpty && waves.warnings.isEmpty)
    #expect(waves.step(dt: 1, defeated: [], party: party).spawn.isEmpty)
    #expect(waves.warnings.count == 3)
  }

  @Test
  func invalidOrPausedStepsPreserveEveryTimerAndPendingArrival() {
    var waves = ArenaWaves(config: .init(slots: slots))
    _ = waves.step(dt: 1, defeated: [], party: party)
    let markers = waves.warnings
    for dt: Float in [0, -1, .nan, .infinity] {
      let update = waves.step(dt: dt, defeated: [], party: party)
      #expect(update.spawn.isEmpty && !update.resupply && waves.warnings == markers)
    }
    _ = waves.step(dt: 100, defeated: [], party: [])
    _ = waves.step(dt: 100, defeated: [], party: [[.nan, 0]])
    #expect(waves.warnings == markers)
  }

  @Test
  func theLastGrenadeMustFinishBeforeResourcesAndActorIDsAreRecycled() {
    var waves = ArenaWaves(config: .init(slots: slots))
    _ = waves.step(dt: 1, defeated: [], party: party)
    let arriving = waves.step(dt: 2, defeated: [], party: party)
    for _ in 0..<20 {
      let held = waves.step(
        dt: 1, defeated: Set(arriving.spawn), party: party, canFinishWave: false)
      #expect(!held.resupply && held.spawn.isEmpty && waves.wave == 1)
    }
    let finished = waves.step(dt: 1, defeated: Set(arriving.spawn), party: party)
    #expect(finished.resupply && waves.wave == 2 && waves.phase == .recovering)
    #expect(waves.step(dt: 3.9, defeated: [], party: party).spawn.isEmpty)
    #expect(waves.warnings.isEmpty)
    _ = waves.step(dt: 0.2, defeated: [], party: party)
    #expect(waves.warnings.count == 4 && waves.warnings.values.allSatisfy { $0 == 2 })
  }

  @Test
  func fallbackRetriesTheSameWaveWithOneResupplyAndRestartReturnsToWaveOne() {
    var waves = ArenaWaves(config: .init(slots: slots))
    _ = waves.step(dt: 1, defeated: [], party: party)
    let arriving = waves.step(dt: 2, defeated: [], party: party)
    _ = waves.step(dt: 1, defeated: Set(arriving.spawn), party: party)
    _ = waves.step(dt: 4, defeated: [], party: party)
    _ = waves.step(dt: 2, defeated: [], party: party)
    #expect(waves.wave == 2 && waves.activeIDs.count == 4)
    waves.retry()
    #expect(waves.wave == 2 && waves.activeIDs.isEmpty && waves.warnings.isEmpty)
    #expect(!waves.step(dt: 0, defeated: [], party: party).resupply)
    #expect(waves.step(dt: 1, defeated: [], party: party).resupply)
    #expect(!waves.step(dt: 1, defeated: [], party: party).resupply)
    _ = waves.step(dt: 2, defeated: [], party: party)
    #expect(waves.warnings.count == 4)
    waves.reset()
    #expect(waves.wave == 1 && waves.activeIDs.isEmpty && waves.warnings.isEmpty)
    #expect(waves.phase == .preparing)
    _ = waves.step(dt: 1, defeated: [], party: party)
    #expect(waves.warnings.count == 3)
  }
}
