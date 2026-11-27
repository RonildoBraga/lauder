import RealityKit
import Testing
import simd

@testable import Lauder

@MainActor
struct GuardLegBreakLifecycleTests {
  @Test
  func aNativeLegBreakCrackAndItsSwordImpactAreDrainedOnlyOnce() throws {
    let trial = try Trial()
    let events = trial.world.takeCombatEvents()
    #expect(cracks(in: events) == 1)
    expectSwordAndImpact(in: events)
    #expect(trial.world.takeCombatEvents().isEmpty)
  }

  @Test
  func pauseFreezesTheRealReactionAndCannotReplayItsUndrainedCrackOnResume() throws {
    let trial = try Trial()
    for _ in 0..<10 { trial.frame() }
    try #require(trial.world.playtestSnapshot.robotPhase == .staggered)
    let root = try #require(trial.world.root.findEntity(named: "spider_bot_heavy_root"))
    let pose = root.transformMatrix(relativeTo: nil)
    let before = trial.world.playtestSnapshot
    trial.frame(.init(keyboardPause: true))
    try #require(trial.world.session.mode == .paused)
    for _ in 0..<60 { trial.frame() }
    #expect(root.transformMatrix(relativeTo: nil) == pose)
    #expect(trial.world.playtestSnapshot.robotPhase == .staggered)
    #expect(trial.world.playtestSnapshot.guardStrategy == before.guardStrategy)
    #expect(trial.world.playtestSnapshot.robotPosition == before.robotPosition)
    #expect(trial.world.playtestSnapshot.robotShots == before.robotShots)
    let events = trial.world.takeCombatEvents()
    #expect(cracks(in: events) == 0)
    expectSwordAndImpact(in: events)
    trial.frame(.init(keyboardPause: true))
    for _ in 0..<60 { trial.frame() }
    #expect(trial.world.playtestSnapshot.robotPhase != .staggered)
    #expect(cracks(in: trial.world.takeCombatEvents()) == 0)
  }

  @Test(arguments: Interruption.allCases)
  func cancelledPresentationContextsDropOnlyTheQueuedLegCue(interruption: Interruption) throws {
    let trial = try Trial()
    defer { trial.world.controls.setActive(false) }
    switch interruption {
    case .restart:
      trial.world.restart()
      #expect(trial.world.playtestSnapshot.robotPhase == .hidden)
      #expect(trial.world.playtestSnapshot.guardStrategy?.health == GuardStrategy.maximumHealth)
      #expect(trial.world.playtestSnapshot.guardStrategy?.detachedLegs.isEmpty == true)
    case .background:
      trial.world.setApplicationActive(false)
      trial.world.setApplicationActive(true)
      trial.frame()
      #expect(!trial.world.controls.needsNeutralInput)
    case .sourceCancellation:
      // Reactivating the input owner cancels its old source generation. Clear the release
      // gate before draining, so a gate-only filter cannot accidentally revive the old cue.
      let generation = trial.world.controls.touchGeneration
      trial.world.controls.setActive(true)
      try #require(trial.world.controls.touchGeneration != generation)
      trial.frame()
      #expect(!trial.world.controls.needsNeutralInput)
    }
    let events = trial.world.takeCombatEvents()
    #expect(cracks(in: events) == 0)
    expectSwordAndImpact(in: events)
    #expect(trial.world.takeCombatEvents().isEmpty)
  }

  enum Interruption: CaseIterable, Sendable {
    case restart, background, sourceCancellation
  }

  private func cracks(in events: [CombatEvent]) -> Int {
    events.filter { if case .guardLegBroken = $0 { true } else { false } }.count
  }

  private func expectSwordAndImpact(in events: [CombatEvent]) {
    #expect(events.contains { if case .fired(.energySword, _, true) = $0 { true } else { false } })
    #expect(events.contains { if case .struckBody = $0 { true } else { false } })
  }

  @MainActor
  private final class Trial {
    let world: GameWorld

    init() throws {
      let origin = simd_normalize(SIMD2<Float>(-1.226398, 0.987247)) * 2.65
      let hostile = Level.Hostile(
        id: "stranger", name: "Guard", hiddenAt: .zero, standAt: .zero, hits: 6,
        attack: .robot, strategicGuard: true, range: 12)
      let encounter = Level.Encounter(
        beat: .stranger, start: .area(.init(minimum: [-20, -20], maximum: [20, 20])),
        retryAt: origin, hostiles: [hostile],
        cues: [(0, .reveal("stranger")), (0, .engage("stranger"))])
      let level = Level(
        id: "leg-break-lifecycle",
        ground: .box("floor", at: [0, -0.15, 0], size: [60, 0.3, 60]),
        boxes: [], triggers: [], encounters: [encounter], party: [.laura, .miki, .tom],
        spawns: [.laura: origin, .miki: [-10, 10], .tom: [10, 10]],
        heading: -simd_normalize(origin), cameraOffset: BrooklynBridge.cameraOffset,
        fieldOfView: 22, opening: "Range", objective: "Test", lookAround: "Range",
        restartNote: "Restart")
      world = GameWorld(level: level)
      world.setApplicationActive(true)
      #expect(world.session.holdAll())
      for _ in 0..<60 {
        frame()
        if world.session.inEncounter, let phase = world.playtestSnapshot.robotPhase,
          phase != .hidden
        {
          break
        }
      }
      try #require(world.session.inEncounter && world.session.leader == .laura)
      frame(.init(keyboardSwap: true))
      frame()
      try #require(world.playtestSnapshot.weapon.kind == .energySword)
      _ = world.takeCombatEvents()
      for _ in 0..<60 * 12 {
        frame(.init(keyboardFire: true))
        if world.playtestSnapshot.guardStrategy?.detachedLegs.count == 1 { break }
      }
      try #require(world.playtestSnapshot.guardStrategy?.detachedLegs.count == 1)
      try #require(world.playtestSnapshot.robotPhase == .staggered)
      try #require(!world.isRetrying && !world.controls.needsNeutralInput)
    }

    func frame(_ raw: InputRules.Raw = .init()) {
      let mode = world.session.mode
      world.update(
        with: world.controls.resolve(raw, mode: mode), sampledIn: mode, deltaTime: 1 / 60)
    }
  }
}
