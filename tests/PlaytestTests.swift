#if DEBUG
  import RealityKit
  import Testing
  import simd

  @testable import Lauder

  /// The Simulator playtest scenarios, driven without rendering. A scenario that cannot be
  /// completed here would fail in `scripts/playtest` too, so the standard check catches it.
  @MainActor
  struct PlaytestTests {
    @Test(arguments: ["route", "panel", "closed", "reversals", "switches", "walls"])
    func scenarioPassesWhenDrivenWithoutRendering(name: String) throws {
      let world = GameWorld()
      var runner = try #require(PlaytestRunner(scenario: name))
      var frames = 0
      while !runner.isFinished {
        let dt: Float = 1 / 60
        runner.tick(dt: dt)
        let raw = runner.input(
          leader: world.session.leader, leaderPosition: position(world, world.session.leader),
          positions: positions(world), passageOpen: world.session.passageOpen)
        // The rendered run sends these through InputRules; here a press acts directly.
        if raw.controllerSwitch { world.session.cycleLeader() }
        if raw.controllerAction { world.performAction() }
        world.advanceParty(movement: raw.stick, deltaTime: dt)
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
      let world = GameWorld()
      world.startPlaytest("nope")
      #expect(world.playtest == nil)
      #expect(world.observation.contains("Unknown playtest"))
      for name in PlaytestRunner.scenarioNames {
        #expect(PlaytestRunner.steps(for: name) != nil, "\(name)")
      }
    }

    private func positions(_ world: GameWorld) -> [PartyMember: SIMD2<Float>] {
      Dictionary(
        uniqueKeysWithValues: PartyMember.allCases.map { ($0, position(world, $0)) })
    }

    private func position(_ world: GameWorld, _ member: PartyMember) -> SIMD2<Float> {
      guard let body = world.root.findEntity(named: "party.\(member.rawValue)") else {
        return [.nan, .nan]
      }
      return SIMD2(body.position.x, body.position.z)
    }
  }
#endif
