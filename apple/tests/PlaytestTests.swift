#if DEBUG
  import Testing
  import simd

  @testable import Lauder

  @MainActor
  struct PlaytestTests {
    @Test(arguments: PlaytestRunner.scenarioNames)
    func scriptedDungeonRoutesUseTheRealInputAndSimulation(name: String) throws {
      let world = GameWorld()
      let runner = try #require(PlaytestRunner(scenario: name))
      var frames = 0
      while !runner.isFinished && frames < 60 * 185 {
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
      case "dungeon-journey":
        #expect(summary.outcome == "won" && summary.heroHits >= 10 && summary.heroHealth > 0)
        #expect(summary.encountersCleared == [0, 1])
        #expect(summary.shortcutOpen && summary.healingUsed)
        #expect(summary.retries == 0)
      case "dungeon-defence":
        #expect(summary.blocks > 0 && summary.evasions > 0)
        #expect(summary.heroHealth == DuelSimulation.heroMaxHealth)
        // Near a wall the whole supplementary envelope is deliberately omitted.
        // Stage tests separately verify both visible kinds on clear floor.
        #expect(Set(summary.warningsShown).isSubset(of: ["sweep", "thrust"]))
      case "dungeon-recovery":
        #expect(summary.retries == 1 && summary.heroHits == 0)
      case "dungeon-focus":
        #expect(summary.outcome == "fighting" && summary.heroHits >= 5 && summary.heroHealth > 0)
        #expect(summary.encountersCleared == [0])
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
