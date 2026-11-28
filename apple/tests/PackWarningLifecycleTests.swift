import Testing
import simd

@testable import Lauder

/// A pack member's warning sound follows the guard's lifecycle (issues #201 and #208): it is
/// heard once while it is live, and not after Pause, Restart or the app going inactive before
/// the frame's feedback drained.
@MainActor
struct PackWarningLifecycleTests {
  enum Kind: CaseIterable, Sendable {
    case drone, crawler
  }

  enum Interruption: CaseIterable, Sendable {
    case pause, restart, inactive, quietExit
  }

  @Test(arguments: Kind.allCases)
  func aLiveWarningIsHeardOnce(kind: Kind) throws {
    let trial = try Trial(kind: kind)
    #expect(warnings(in: trial.world.takeCombatEvents()) == 1)
    #expect(warnings(in: trial.world.takeCombatEvents()) == 0)
  }

  @Test(arguments: Kind.allCases, Interruption.allCases)
  func aQueuedWarningIsNotHeardOnceItsMomentHasPassed(
    kind: Kind, interruption: Interruption
  ) throws {
    let trial = try Trial(kind: kind)
    switch interruption {
    case .pause:
      trial.frame(.init(keyboardPause: true))
      #expect(trial.world.session.mode == .paused)
    case .restart:
      trial.world.restart()
    case .inactive:
      trial.world.setApplicationActive(false)
      trial.world.setApplicationActive(true)
      trial.frame()
    case .quietExit:
      // The leader steps into the quiet exit, which leaves the pack harmless, before the
      // feedback drains: the member that warned has gone quiet (#227).
      for _ in 0..<60 * 5 where trial.world.session.inEncounter {
        trial.world.advanceParty(movement: stick(trial.world, towards: [1, 0]), deltaTime: 1 / 60)
      }
      #expect(!trial.world.session.inEncounter)
    }
    #expect(warnings(in: trial.world.takeCombatEvents()) == 0)
  }

  private func warnings(in events: [CombatEvent]) -> Int {
    events.filter {
      switch $0 {
      case .droneWarning, .crawlerWarning: true
      default: false
      }
    }.count
  }

  @MainActor
  private final class Trial {
    let world: GameWorld
    private let kind: Kind

    init(kind: Kind) throws {
      self.kind = kind
      let guardian = Level.Hostile(
        id: "guard", name: "Guard", hiddenAt: .zero, standAt: .zero, hits: 6, attack: .robot,
        strategicGuard: true)
      // The crawler waits nearer the leader than the companions, so it winds up on her.
      let pack =
        switch kind {
        case .drone:
          Level.Hostile(
            id: "drone", name: "Scout drone", hiddenAt: .zero, standAt: .zero,
            hits: ScoutDrone.health, attack: .drone(orbit: 0, slot: 0))
        case .crawler:
          Level.Hostile(
            id: "crawler", name: "Crawler", hiddenAt: [0, 5], standAt: [0, 5],
            hits: Crawler.health, attack: .crawler(slot: 0))
        }
      let encounter = Level.Encounter(
        beat: .stranger, start: .area(.init(minimum: [-15, -15], maximum: [15, 15])),
        retryAt: [0, 12], hostiles: [guardian, pack],
        cues: [
          (0, .reveal("guard")), (0, .engage("guard")), (0, .reveal(pack.id)),
          (0, .engage(pack.id)),
        ],
        // A step to the leader's right leaves the guard by its quiet exit.
        safeExit: .init(minimum: [1.5, 7], maximum: [4, 11]))
      let level = Level(
        id: "pack-warning-lifecycle",
        ground: .box("floor", at: [0, -0.15, 0], size: [40, 0.3, 40]),
        boxes: [], triggers: [], encounters: [encounter], party: [.miki, .tom, .laura],
        spawns: [.miki: [0, 9], .tom: [-1, 10.5], .laura: [1, 10.5]], heading: [0, -1],
        cameraOffset: BrooklynBridge.cameraOffset, fieldOfView: 22,
        opening: "Range", objective: "Test", lookAround: "Range", restartNote: "Restart")
      world = GameWorld(level: level)
      world.setApplicationActive(true)
      // Feedback drains every frame until the pack member starts its audible warning; that
      // frame's events stay queued for the transition under test.
      for _ in 0..<60 * 20 {
        frame()
        if isWarningAudibly { return }
        _ = world.takeCombatEvents()
      }
      Issue.record("The pack member never warned audibly")
      try #require(isWarningAudibly)
    }

    /// A drone's warning is heard whoever it watches; a crawler's only on the leader.
    private var isWarningAudibly: Bool {
      let snapshot = world.playtestSnapshot
      return switch kind {
      case .drone: snapshot.drones.contains { $0.phase == .warning }
      case .crawler:
        snapshot.crawlers.contains { $0.phase == .windingUp && $0.watching == snapshot.leader }
      }
    }

    func frame(_ raw: InputRules.Raw = .init()) {
      let mode = world.session.mode
      let input = world.controls.resolve(raw, mode: mode)
      world.update(with: input, sampledIn: mode, deltaTime: 1 / 60)
    }
  }
}
