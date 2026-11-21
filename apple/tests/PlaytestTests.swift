#if DEBUG
  import Testing

  @testable import Lauder

  /// The Simulator playtest scenarios, driven without rendering. A scenario that cannot be
  /// completed here would fail in `apple/scripts/playtest` too, so the standard check catches it.
  @MainActor
  struct PlaytestTests {
    @Test(arguments: PlaytestRunner.scenarioNames)
    func scenarioPassesWhenDrivenWithoutRendering(name: String) throws {
      // The app's game, so that the pause menu's third choice can swap in another level's world.
      let game = Game()
      var runner = try #require(PlaytestRunner(scenario: name))
      var frames = 0
      while !runner.isFinished {
        let dt: Float = 1 / 60
        runner.tick(dt: dt)
        let world = game.world
        let raw = runner.input(world.playtestSnapshot)
        // The same input rules, release gate and mode handling as the rendered run, without
        // hardware or a scene subscription.
        let mode = world.session.mode
        world.update(
          with: world.controls.resolve(raw, mode: mode), sampledIn: mode, deltaTime: dt)
        let after = game.world
        runner.record(
          PlaytestRunner.Frame(
            dt: dt, leader: after.session.leader, positions: after.playtestSnapshot.positions,
            targets: after.companionTargets, warning: after.diagnostic,
            simulationMilliseconds: 0))
        frames += 1
        try #require(frames < 60 * 600, "\(name) did not finish in ten minutes")
      }
      let summary = try #require(runner.summary)
      #expect(summary.passed, "\(name): \(summary.failures)")
      #expect(summary.stepsCompleted == summary.steps)
      #expect(!summary.marks.isEmpty)
    }

    @Test
    func anUnknownScenarioIsReportedOnTheHUD() {
      #expect(PlaytestRunner(scenario: "nope") == nil)
      let world = GameWorld()
      world.startPlaytest("nope")
      #expect(world.playtest == nil)
      #expect(world.observation.contains("Unknown playtest"))
      for name in PlaytestRunner.scenarioNames {
        #expect(PlaytestRunner.steps(for: name) != nil, "\(name)")
      }
    }
  }
#endif
