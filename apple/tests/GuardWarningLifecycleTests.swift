import Testing
import simd

@testable import Lauder

/// The world may advance several native steps before the interface drains feedback. A warning
/// describes the current live threat; ordinary shot/impact feedback remains an event history.
@MainActor
struct GuardWarningLifecycleTests {
  @Test
  func aLiveNativeWarningAndShotAreDeliveredOnlyOnce() throws {
    let trial = try Trial()
    let events = trial.world.takeCombatEvents()
    #expect(warnings(in: events) == [.miki])
    expectNativeShotAndImpact(in: events)
    #expect(trial.world.takeCombatEvents().isEmpty)
  }

  @Test(arguments: Interruption.allCases)
  func aQueuedWarningCannotSurviveItsPresentationContext(interruption: Interruption) throws {
    let trial = try Trial()
    switch interruption {
    case .pause:
      trial.frame(.init(keyboardPause: true))
      #expect(trial.world.session.mode == .paused)
    case .restart:
      trial.world.restart()
      #expect(trial.world.guardTarget == nil)
    case .inactive:
      trial.world.setApplicationActive(false)
      trial.world.setApplicationActive(true)
      trial.frame()
      // The same live target and a cleared release gate cannot resurrect the old cue.
      #expect(trial.world.guardTarget == .miki)
      #expect(!trial.world.controls.needsNeutralInput)
    }
    let events = trial.world.takeCombatEvents()
    #expect(warnings(in: events).isEmpty)
    expectNativeShotAndImpact(in: events)
    #expect(trial.world.takeCombatEvents().isEmpty)
  }

  @Test
  func defendDoesNotEraseAnAlreadyWarnedAttack() throws {
    let trial = try Trial()
    trial.frame(.init(arrowUp: true))
    #expect(trial.world.session.combatStance == .attack)
    trial.frame(.init(arrowDown: true))
    #expect(trial.world.session.combatStance == .defend)
    #expect(trial.world.guardTarget == .miki)
    let events = trial.world.takeCombatEvents()
    #expect(warnings(in: events) == [.miki])
    expectNativeShotAndImpact(in: events)
  }

  @Test
  func aCompletedBurstCannotReplayItsEarlierAcquisitionWarning() throws {
    let trial = try Trial()
    for _ in 0..<180 {
      trial.frame()
      if trial.world.guardTarget == nil { break }
    }
    try #require(trial.world.guardTarget == nil)
    #expect(trial.world.session.mode == .exploring && trial.world.session.inEncounter)
    #expect(!trial.world.controls.needsNeutralInput && !trial.world.isRetrying)
    let events = trial.world.takeCombatEvents()
    #expect(warnings(in: events).isEmpty)
    expectNativeShotAndImpact(in: events)
  }

  enum Interruption: CaseIterable, Sendable {
    case pause, restart, inactive
  }

  private func warnings(in events: [CombatEvent]) -> [PartyMember] {
    events.compactMap { event in
      if case .guardTargeted(let member, _) = event { member } else { nil }
    }
  }

  private func expectNativeShotAndImpact(in events: [CombatEvent]) {
    #expect(
      events.contains { if case .fired(.longRifle, _, true) = $0 { true } else { false } })
    #expect(
      events.contains {
        switch $0 {
        case .struckBody, .struckBlock: true
        default: false
        }
      })
  }

  @MainActor
  private final class Trial {
    let world: GameWorld

    init() throws {
      let hostile = Level.Hostile(
        id: "guard", name: "Guard", hiddenAt: .zero, standAt: .zero, hits: 6,
        attack: .robot, strategicGuard: true, range: 12)
      let encounter = Level.Encounter(
        beat: .stranger, start: .area(.init(minimum: [-15, -15], maximum: [15, 15])),
        retryAt: [0, 12], hostiles: [hostile],
        cues: [(0, .reveal("guard")), (0, .engage("guard"))])
      let level = Level(
        id: "guard-warning-lifecycle",
        ground: .box("floor", at: [0, -0.15, 0], size: [40, 0.3, 40]),
        boxes: [], triggers: [], encounters: [encounter], party: [.miki, .tom, .laura],
        spawns: [.miki: [0, 8], .tom: [-1, 9], .laura: [1, 9]], heading: [0, -1],
        cameraOffset: BrooklynBridge.cameraOffset, fieldOfView: 22,
        opening: "Range", objective: "Test", lookAround: "Range", restartNote: "Restart")
      world = GameWorld(level: level)
      world.setApplicationActive(true)
      for _ in 0..<60 {
        frame()
        if world.guardTarget != nil { break }
      }
      try #require(world.guardTarget == .miki)
      // A real draw, discharge and contact occur while the initial warning is still live.
      // Leave every event queued until the tested presentation/lifecycle transition.
      for _ in 0..<40 { frame(.init(keyboardFire: true)) }
      frame()
      try #require(world.guardTarget == .miki && !world.isRetrying)
      try #require(!world.controls.needsNeutralInput)
    }

    func frame(_ raw: InputRules.Raw = .init()) {
      let mode = world.session.mode
      let input = world.controls.resolve(raw, mode: mode)
      world.update(with: input, sampledIn: mode, deltaTime: 1 / 60)
    }
  }
}
