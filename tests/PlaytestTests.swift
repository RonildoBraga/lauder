#if DEBUG
  import RealityKit
  import Testing
  import simd

  @testable import Lauder

  /// The Simulator playtest scenarios, driven without rendering. A scenario that cannot be
  /// completed here would fail in `scripts/playtest` too, so the standard check catches it.
  @MainActor
  struct PlaytestTests {
    @Test(arguments: [
      "route", "panel", "closed", "reversals", "switches", "walls", "mission", "bridge-walk",
    ])
    func scenarioPassesWhenDrivenWithoutRendering(name: String) throws {
      let world = GameWorld(level: Level.level(PlaytestRunner.level(for: name)))
      var runner = try #require(PlaytestRunner(scenario: name))
      var frames = 0
      while !runner.isFinished {
        let dt: Float = 1 / 60
        runner.tick(dt: dt)
        let raw = runner.input(world.playtestSnapshot)
        // The same input rules, release gate and mode handling as the rendered run, without
        // hardware or a scene subscription.
        let mode = world.session.mode
        world.update(
          with: world.controls.resolve(raw, mode: mode), sampledIn: mode, deltaTime: dt)
        runner.record(
          PlaytestRunner.Frame(
            dt: dt, leader: world.session.leader, positions: positions(world),
            targets: world.companionTargets, warning: world.diagnostic,
            simulationMilliseconds: 0))
        frames += 1
        try #require(frames < 60 * 300, "\(name) did not finish in five minutes")
      }
      let summary = try #require(runner.summary)
      #expect(summary.passed, "\(name): \(summary.failures)")
      #expect(summary.stepsCompleted == summary.steps)
      #expect(!summary.marks.isEmpty)
    }

    @Test
    func anUnknownScenarioIsReportedOnTheHUD() {
      #expect(PlaytestRunner(scenario: "nope") == nil)
      let world = GameWorld(level: RelayHouse.level)
      world.startPlaytest("nope")
      #expect(world.playtest == nil)
      #expect(world.observation.contains("Unknown playtest"))
      for name in PlaytestRunner.scenarioNames {
        #expect(PlaytestRunner.steps(for: name) != nil, "\(name)")
      }
    }

    /// The party's positions, as the rendered run records them; members yet to join are left out.
    private func positions(_ world: GameWorld) -> [PartyMember: SIMD2<Float>] {
      Dictionary(
        uniqueKeysWithValues: world.session.party.map { ($0, position(world, $0)) })
    }

    private func position(_ world: GameWorld, _ member: PartyMember) -> SIMD2<Float> {
      guard let body = world.root.findEntity(named: "party.\(member.rawValue)") else {
        return [.nan, .nan]
      }
      return SIMD2(body.position.x, body.position.z)
    }
  }
#endif
