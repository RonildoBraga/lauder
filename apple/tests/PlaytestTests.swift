#if DEBUG
  import Testing
  import simd

  @testable import Lauder

  @MainActor
  struct PlaytestTests {
    @Test(arguments: PlaytestRunner.scenarioNames)
    func scriptedDuelRoutesUseTheRealInputAndSimulation(name: String) throws {
      let world = GameWorld()
      let runner = try #require(PlaytestRunner(scenario: name))
      var frames = 0
      while !runner.isFinished && frames < 60 * 95 {
        let input = runner.input(world: world)
        world.update(raw: input, deltaTime: 1 / 60)
        runner.record(world: world, deltaTime: 1 / 60, milliseconds: 0)
        frames += 1
      }
      let summary = try #require(runner.summary)
      #expect(summary.passed, "\(name): \(summary.failures)")
      #expect(summary.stepsCompleted == summary.steps)
      #expect(!summary.marks.isEmpty)
      switch name {
      case "duel-attack":
        #expect(summary.outcome == "won" && summary.heroHits >= 5 && summary.heroHealth > 0)
        #expect(summary.retries == 0)
      case "duel-defence":
        #expect(summary.blocks > 0 && summary.evasions > 0)
        #expect(summary.heroHealth == DuelSimulation.heroMaxHealth)
      case "duel-recovery":
        #expect(summary.retries == 1 && summary.heroHits == 0)
      case "duel-focus":
        #expect(summary.outcome == "won" && summary.heroHits >= 5 && summary.heroHealth > 0)
        #expect(summary.blocks > 0 && summary.retries == 0 && !summary.focused)
      default: Issue.record("Unasserted scenario")
      }
    }

    @Test
    func unknownScenarioCannotSilentlyRunAnotherRoute() {
      #expect(PlaytestRunner(scenario: "unknown-duel") == nil)
      let world = GameWorld()
      world.startPlaytest("unknown-duel")
      #expect(world.playtest == nil)
      #expect(world.observation == "Unknown playtest: unknown-duel")
    }
  }
#endif
