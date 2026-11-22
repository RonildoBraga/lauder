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
      if name == "combat-yard" {
        #expect(summary.highestArenaWave >= 3, "the real-control route did not clear two packs")
        #expect(summary.peakArrivalWarnings > 0, "the route observed no arrival warnings")
      }
      if name == "arena-elevation" {
        #expect(summary.highestFloor >= 2.35, "the bodies never reached the upper deck")
        #expect(summary.lowestFloor <= -1.75, "the bodies never reached the lower trench")
      }
      if name == "arsenal-bench" {
        #expect(
          summary.longestPartySceneryTrace >= 40, "native weapon never struck the distant wall")
        #expect(Set(summary.partyWeaponsFired).isSuperset(of: Set(Weapon.testKinds.map(\.name))))
      }
      if name == "enemy-arsenal" {
        #expect(summary.highestArenaWave >= 3)
        #expect(
          Set(summary.hostileWeaponsFired).isSuperset(of: [
            Weapon.Kind.marksman.name, Weapon.Kind.supportGun.name,
          ]))
        #expect(
          Set(summary.hostileWeaponsRecovered).isSuperset(of: [
            Weapon.Kind.marksman.name, Weapon.Kind.supportGun.name,
          ]))
        #expect(summary.marksmanRetreated)
      }
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
