#if DEBUG
  import Testing
  import simd

  @testable import Lauder

  /// The Simulator playtest scenarios, driven without rendering. A scenario that cannot be
  /// completed here would fail in `apple/scripts/playtest` too, so the standard check catches it.
  @MainActor
  struct PlaytestTests {
    @Test(arguments: PlaytestRunner.scenarioNames)
    func scenarioPassesWhenDrivenWithoutRendering(name: String) throws {
      // Use the app's world and ordinary input rules, including Pause and Restart, on the
      // level the route was written for, as the rendered run's launch argument chooses.
      let world = GameWorld(level: PlaytestRunner.level(for: name))
      var runner = try #require(PlaytestRunner(scenario: name))
      if name == "touch-fight" { world.controls.useTouchControls() }
      var frames = 0
      while !runner.isFinished {
        let dt: Float = 1 / 60
        runner.tick(dt: dt)
        let raw = runner.input(world.playtestSnapshot)
        if name == "touch-fight" {
          try #require(!raw.hasControllerInput && !raw.hasKeyboardInput)
          try #require(raw.stick == .zero && raw.aimStick == .zero)
        }
        // The same input rules, release gate and mode handling as the rendered run, without
        // hardware or a scene subscription.
        let mode = world.session.mode
        world.update(
          with: world.controls.resolve(raw, mode: mode), sampledIn: mode, deltaTime: dt)
        let after = world
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
      if name == "robot-parts" {
        let opening = try #require(summary.legStagger)
        #expect(opening.completed && opening.staggeredSamples >= 2)
        #expect(opening.observedSeconds > 0 && opening.shotsDuringStagger == 0)
        #expect(opening.firstShotSerial == opening.lastShotSerial)
        let mark = try #require(summary.marks.first { $0.name == "leg-break stagger begins" })
        #expect(mark.robotPhase == "staggered" && (mark.health ?? 0) > 0)
        #expect((mark.legsLost ?? 0) > 0)
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

    @Test
    func theCompanionDriverCannotSilentlyChangeDefaultDefendToAttack() {
      let world = GameWorld(level: BrooklynBridge.level)
      var runner = PlaytestRunner(steps: [.companionFight], name: "explicit-attack-contract")
      for _ in 0..<90 where !runner.isFinished {
        let raw = runner.input(world.playtestSnapshot)
        #expect(!raw.dpadUp && !raw.controllerFire)
        runner.tick(dt: 1 / 60)
      }
      #expect(runner.summary?.passed == false)
      #expect(runner.summary?.failures.first == "companion fight requires an explicit Attack order")
      #expect(world.session.combatStance == .defend)
    }

    @Test
    func aRetaliationCaptureCannotInventAWarningAndTakeControl() {
      let world = GameWorld(level: BrooklynBridge.level)
      var runner = PlaytestRunner(steps: [.leadWarnedMember], name: "real-warning-contract")
      for _ in 0..<90 where !runner.isFinished {
        let raw = runner.input(world.playtestSnapshot)
        #expect(!raw.controllerSwitch && !raw.controllerFire)
        runner.tick(dt: 1 / 60)
      }
      #expect(runner.summary?.passed == false)
      #expect(
        runner.summary?.failures.first
          == "no actual warned member was available for the control switch")
      #expect(world.session.leader == .miki && world.guardTarget == nil)
    }

    @Test
    func aCoverCheckCannotInventAnEngagedFightOrIssueItsOwnAttackOrder() {
      let world = GameWorld(level: BrooklynBridge.level)
      var runner = PlaytestRunner(
        steps: [.settleDefendCover(seconds: 1, hold: 0.5)], name: "cover-context-contract")
      for _ in 0..<90 where !runner.isFinished {
        let raw = runner.input(world.playtestSnapshot)
        #expect(raw == InputRules.Raw())
        runner.tick(dt: 1 / 60)
      }
      #expect(runner.summary?.passed == false)
      #expect(
        runner.summary?.failures.first == "cover settlement requires an active defended guard fight"
      )
      #expect(world.session.combatStance == .defend && world.session.leader == .miki)
    }

    @Test
    func aRealCompanionReturnStillPassesAfterTheLeaderRollsAway() throws {
      let template = GameWorld(level: TestRange.practice).playtestSnapshot
      let start = defendObservation(template, leader: .zero, companion: [4, 0])
      var runner = beginDefendCheck(start, name: "recall-before-roll-contract")
      for companion: SIMD2<Float> in [[3, 0], [1.5, 0]] {
        runner.tick(dt: 0.2)
        let raw = runner.input(defendObservation(template, leader: .zero, companion: companion))
        #expect(!raw.controllerFire && !raw.controllerSwitch && !raw.dpadUp)
      }
      runner.tick(dt: 0.2)
      let roll = runner.input(
        defendObservation(template, leader: .zero, companion: [1.5, 0], phase: .committed))
      #expect(roll.controllerDodge && roll.stick != .zero)
      #expect(!roll.controllerFire && !roll.controllerSwitch && !roll.dpadUp)
      // The final live gap is now 4.5 m, exceeding the original 4 m despite the real return.
      let afterRoll = defendObservation(template, leader: [-3, 0], companion: [1.5, 0])
      runner.tick(dt: 0.2)
      _ = runner.input(afterRoll)
      runner.tick(dt: 0.3)
      _ = runner.input(afterRoll)
      let summary = try #require(runner.summary)
      #expect(summary.passed && summary.failures.isEmpty)
    }

    @Test
    func movingTheLeaderTowardsAStationaryCompanionDoesNotCountAsRecall() throws {
      let template = GameWorld(level: TestRange.practice).playtestSnapshot
      let start = defendObservation(template, leader: .zero, companion: [4, 0])
      var runner = beginDefendCheck(start, name: "stationary-follower-recall-contract")
      for leader: SIMD2<Float> in [[1, 0], [2.5, 0], [2.5, 0]] {
        runner.tick(dt: 0.4)
        _ = runner.input(defendObservation(template, leader: leader, companion: [4, 0]))
      }
      let summary = try #require(runner.summary)
      #expect(!summary.passed)
      #expect(summary.failures == ["Defend did not bring a distant companion toward the leader"])
    }

    @Test
    func noCompanionApproachStillFailsTheDefendRecallCheck() throws {
      let template = GameWorld(level: TestRange.practice).playtestSnapshot
      let start = defendObservation(template, leader: .zero, companion: [4, 0])
      var runner = beginDefendCheck(start, name: "missing-recall-contract")
      for _ in 0..<3 {
        runner.tick(dt: 0.4)
        _ = runner.input(start)
      }
      let summary = try #require(runner.summary)
      #expect(!summary.passed)
      #expect(summary.failures == ["Defend did not bring a distant companion toward the leader"])
    }

    /// These are observed-state fixtures for the driver's measurement, not shortcuts used by
    /// a rendered gameplay route. Native movement and roll execution have their own tests.
    private func defendObservation(
      _ template: PlaytestRunner.Snapshot, leader: SIMD2<Float>, companion: SIMD2<Float>,
      phase: RobotGuard.Phase = .recovering
    ) -> PlaytestRunner.Snapshot {
      var result = PlaytestRunner.Snapshot(
        level: template.level, leader: .miki, party: [.miki, .tom, .laura],
        positions: [.miki: leader, .laura: companion, .tom: [0, 1.5]],
        mode: .exploring, firedTriggers: 0, beat: .stranger, hitsTaken: 0, defeated: 0,
        formation: .close, orders: [:], refusedOrders: 0, camera: template.camera,
        weapon: template.weapon)
      result.guardStrategy = GuardStrategy()
      result.robotPhase = phase
      result.robotPosition = [0, -4]
      return result
    }

    private func beginDefendCheck(
      _ start: PlaytestRunner.Snapshot, name: String
    ) -> PlaytestRunner {
      var runner = PlaytestRunner(steps: [.wait(seconds: 0), .defendGuard(seconds: 1)], name: name)
      #expect(runner.input(start) == InputRules.Raw())
      runner.tick(dt: 0.5)
      #expect(runner.input(start) == InputRules.Raw())
      return runner
    }

    @Test
    func afterLegLossTheRangedDriverOrdersAttackThenPeeksFromCoverBeforeFiring() throws {
      let world = GameWorld(level: BrooklynBridge.level)
      walk(world, to: [6.5, 10])
      walk(world, to: [3.64, 11.09])
      var snapshot = world.playtestSnapshot
      let at = try #require(snapshot.positions[.miki])
      let centre = try #require(snapshot.robotPosition)
      let point = try #require(snapshot.guardPoints.first)
      let rays = Ballistics(level: snapshot.level)
      try #require(
        !rays.isClear(from: rays.point(at), to: point.centre)
          || !rays.isClear(from: rays.point(centre, above: 1.52), to: rays.point(at)))
      // This policy-only observation starts after Laura's leg break. The native world is
      // unchanged; actual contacts/detachment are exercised by robot-parts and combat tests.
      var observed = try #require(snapshot.guardStrategy)
      for _ in 0..<GuardStrategy.swordHitsToDetach {
        _ = observed.accept(weapon: .energySword, part: .leg(0), damage: 30)
      }
      snapshot.guardStrategy = observed
      var runner = PlaytestRunner(steps: [.dismantleGuard], name: "manual-cover-peek-contract")
      var peeked = false
      var orderedAttack = false
      for _ in 0..<90 where !runner.isFinished {
        let raw = runner.input(snapshot)
        #expect(!raw.controllerFire && !raw.controllerSwitch)
        if raw.dpadUp {
          orderedAttack = true
          snapshot.combatStance = .attack
        }
        if raw.stick != .zero && !raw.controllerDodge {
          peeked = true
          break
        }
        runner.tick(dt: 1 / 60)
      }
      #expect(orderedAttack && peeked, "the ordinary command must precede the clear-lane approach")
      #expect(world.session.leader == .miki && !world.isRetrying)
      #expect(world.playtestSnapshot.guardStrategy?.detachedLegs.isEmpty == true)
    }

    @Test
    func injuryEvidenceSurvivesClearedSnapshotsAndCountsRetryEdgesOnce() throws {
      let world = GameWorld(level: BrooklynBridge.level)
      var snapshot = world.playtestSnapshot
      var runner = PlaytestRunner(steps: [.wait(seconds: 0)], name: "injury-evidence-contract")
      let samples: [([PartyMember: Int], Bool)] = [
        ([.miki: 1, .laura: 2, .tom: 0], false),
        ([.miki: 3, .laura: 1, .tom: 1], true),
        ([.miki: 0, .laura: 0, .tom: 2], true),
        ([:], false),
        ([.tom: 1], true),
      ]
      for (hits, retrying) in samples {
        snapshot.partyHits = hits
        snapshot.isRetrying = retrying
        #expect(runner.input(snapshot) == InputRules.Raw(), "initial release input stays neutral")
        runner.tick(dt: 0.1)
      }
      snapshot.partyHits = [:]
      snapshot.isRetrying = false
      for _ in 0..<10 where !runner.isFinished {
        _ = runner.input(snapshot)
        runner.tick(dt: 0.1)
      }
      let summary = try #require(runner.summary)
      #expect(summary.passed)
      #expect(summary.peakPartyHits == ["miki": 3, "laura": 2, "tom": 2])
      #expect(summary.retryCount == 2)
      snapshot.partyHits = [.miki: 99]
      snapshot.isRetrying = true
      _ = runner.input(snapshot)
      #expect(runner.summary?.peakPartyHits == summary.peakPartyHits)
      #expect(runner.summary?.retryCount == 2)
    }

    @Test
    func aShotBeforeTheFirstStaggerSampleIsNotMiscountedAndAFreshWarningIsRecorded() throws {
      let summary = try legStaggerObservation(shotsWhileStaggered: 4, breakPhase: .staggered)
      let observed = try #require(summary.legStagger)
      #expect(summary.passed && observed.completed)
      #expect(observed.firstShotSerial == 4 && observed.lastShotSerial == 4)
      #expect(observed.shotsDuringStagger == 0 && observed.staggeredSamples == 2)
      #expect(observed.freshWarningObserved)
      #expect(summary.marks.contains { $0.name == "fresh warning after leg-break stagger" })
    }

    @Test
    func theRenderedRouteCannotPassAShotDuringContinuousStagger() throws {
      let summary = try legStaggerObservation(shotsWhileStaggered: 5, breakPhase: .staggered)
      #expect(!summary.passed)
      #expect(summary.legStagger?.shotsDuringStagger == 1)
      #expect(
        summary.failures.contains(
          "the guard fired during a continuously observed leg-break stagger"))
    }

    @Test
    func aQuietOpeningDoesNotInventAFreshWarning() throws {
      let summary = try legStaggerObservation(
        shotsWhileStaggered: 4, breakPhase: .staggered, observesWarning: false)
      #expect(summary.passed && summary.legStagger?.completed == true)
      #expect(summary.legStagger?.freshWarningObserved == false)
      #expect(!summary.marks.contains { $0.name == "fresh warning after leg-break stagger" })
    }

    @Test
    func theRenderedRouteCannotPassANonlethalBreakWithoutStagger() throws {
      let summary = try legStaggerObservation(shotsWhileStaggered: 4, breakPhase: .tracking)
      #expect(!summary.passed)
      #expect(summary.failures.contains("the first nonlethal leg break did not enter stagger"))
    }

    /// Observation fixtures check the recorder's failure contract, not native combat. The
    /// scenario test above drives the unchanged robot-parts route through the actual world.
    private func legStaggerObservation(
      shotsWhileStaggered: Int, breakPhase: RobotGuard.Phase, observesWarning: Bool = true
    ) throws -> PlaytestRunner.Summary {
      var snapshot = GameWorld(level: BrooklynBridge.level).playtestSnapshot
      snapshot.guardStrategy = GuardStrategy()
      snapshot.robotPhase = .burst
      snapshot.robotShots = 3
      var runner = PlaytestRunner(steps: [.wait(seconds: 0)], name: "robot-parts")
      _ = runner.input(snapshot)
      var broken = GuardStrategy()
      for _ in 0..<GuardStrategy.swordHitsToDetach {
        _ = broken.accept(weapon: .energySword, part: .leg(0), damage: 30)
      }
      snapshot.guardStrategy = broken
      snapshot.robotPhase = breakPhase
      snapshot.robotShots = 4
      runner.tick(dt: 0.1)
      _ = runner.input(snapshot)
      snapshot.robotShots = shotsWhileStaggered
      runner.tick(dt: 0.1)
      _ = runner.input(snapshot)
      snapshot.robotPhase = .patrol
      runner.tick(dt: 0.1)
      _ = runner.input(snapshot)
      snapshot.robotPhase = observesWarning ? .notice : .patrol
      snapshot.guardTarget = observesWarning ? .miki : nil
      runner.tick(dt: 0.1)
      _ = runner.input(snapshot)
      runner.tick(dt: 0.2)
      _ = runner.input(snapshot)
      return try #require(runner.summary)
    }
  }
#endif
