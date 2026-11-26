#if DEBUG
  import Testing

  @testable import Lauder

  /// The Simulator playtest scenarios, driven without rendering. A scenario that cannot be
  /// completed here would fail in `apple/scripts/playtest` too, so the standard check catches it.
  @MainActor
  struct PlaytestTests {
    @Test(arguments: PlaytestRunner.scenarioNames)
    func scenarioPassesWhenDrivenWithoutRendering(name: String) throws {
      // Use the app's world and ordinary input rules, including Pause and Restart.
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

    @Test
    func aGuardRetryFailsTheScriptInsteadOfSilentlyWinningAnotherAttempt() {
      let world = GameWorld(level: BrooklynBridge.level)
      walk(world, to: [6.5, 10])
      var snapshot = world.playtestSnapshot
      snapshot.isRetrying = true
      var runner = PlaytestRunner(steps: [.dismantleGuard], name: "retry-contract")
      for _ in 0..<90 where !runner.isFinished {
        _ = runner.input(snapshot)
        runner.tick(dt: 1 / 60)
      }
      #expect(runner.summary?.passed == false)
      #expect(runner.summary?.failures.count == 1)
      #expect(runner.summary?.failures.first?.contains("retried") == true)
    }

    @Test
    func theCompanionRouteFailsRatherThanTakingOverAnotherLeader() {
      let world = GameWorld(level: BrooklynBridge.level)
      world.session.cycleLeader()
      var runner = PlaytestRunner(steps: [.companionFight], name: "leader-authority-contract")
      for _ in 0..<90 where !runner.isFinished {
        let raw = runner.input(world.playtestSnapshot)
        #expect(!raw.controllerSwitch && !raw.controllerFire)
        runner.tick(dt: 1 / 60)
      }
      #expect(runner.summary?.passed == false)
      #expect(runner.summary?.failures.first == "companion fight took control from Miki")
      #expect(world.session.leader == .tom)
    }
  }
#endif
