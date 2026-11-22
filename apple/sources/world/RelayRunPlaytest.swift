#if DEBUG
  import simd

  /// The mission's real controls and rendered journey, separate from the bridge's scenarios.
  enum RelayRunPlaytest {
    typealias Step = PlaytestRunner.Step

    static let scenarios: [(name: String, steps: [Step])] = [
      ("relay-run-safe", safeJourney),
      ("relay-run-retreat", guardedJourney),
    ]

    private static let nextLevel: [Step] = [
      .pause, .wait(seconds: 0.5), .menu(1), .wait(seconds: 0.3), .menu(1),
      .wait(seconds: 0.3), .act, .wait(seconds: 1),
    ]

    private static let enter: [Step] =
      nextLevel + [.expectLevel("combat-yard")]
      + nextLevel + [.expectLevel("salvage-yard")]
      + nextLevel + [
        .expectLevel("relay-run"), .expectParty([.miki, .tom, .laura]),
        .expectRepaired(false), .expectFighting(false), .mark("the shelter"),
      ]

    private static let restart: [Step] = [
      .pause, .wait(seconds: 0.5), .menu(1), .wait(seconds: 0.3), .act,
      .expectRestarted, .expectRepaired(false), .expectFighting(false),
      .expectAmmo(RelayRun.level.startingAmmo), .mark("mission restarted"),
    ]

    private static func walk(_ points: [SIMD2<Float>]) -> [Step] { points.map(Step.walk) }

    /// Laura opens access for everyone; Miki leaves the live equipment connected and takes the
    /// disconnected compatible regulator. Spread has to compress through the shared gate.
    private static let safeJourney: [Step] =
      enter + [
        .formation, .expectFormation(.spread), .switchLeader, .switchLeader,
        .wait(seconds: 0.5),
      ] + walk(RelayRun.safeRoute) + [
        .expectFighting(false), .expectBeat(.alone), .expectAmmo(RelayRun.level.startingAmmo),
        .mark("the covered detour"), .walk(RelayRun.latchPoint), .act,
        .expectLine("Laura reaches the latch, and the gate swings open."),
        .wait(seconds: 1), .mark("Laura opens the depot"), .switchLeader,
        .wait(seconds: 0.5), .walk(RelayRun.gateOutside), .walk(RelayRun.gateInside),
        .walkToCabinet(.live), .act,
        .expectLine("Live: it still feeds the next shelter. Leave it connected."),
        .mark("leave the live supply"), .walkToCabinet(.compatible), .act,
        .expectLine("A compatible regulator, disconnected. Safe to take."), .act,
        .expectLine("Miki takes the regulator."), .expectRepaired(false),
        .expectFighting(false), .mark("a useful part"),
        .walk(RelayRun.gateInside), .walk(RelayRun.gateOutside),
      ] + walk(Array(RelayRun.safeRoute.reversed())) + [
        .walk(RelayRun.transmitterPoint), .wait(seconds: 2), .mark("home with the part"),
        .expectFighting(false), .expectBeat(.alone), .expectDefeated(0),
        .expectAmmo(RelayRun.level.startingAmmo), .talk,
        .expectRepaired(true), .expectFighting(false), .mark("a shared signal"),
        .wait(seconds: 1),
      ] + restart + nextLevel + [.expectLevel("brooklyn-bridge"), .mark("back to the bridge")]

    /// The guarded option is readable and reversible. The party withdraws, returns and chooses
    /// to fight, then Tom opens the same depot and the return uses the now-clear shortcut.
    private static let guardedJourney: [Step] =
      enter + [
        .walk(RelayRun.fork), .walk([5, 1]), .mark("the warning before danger"),
        .walk([5, -4]), .expectFighting(true), .mark("the guarded lane"),
        .pause, .wait(seconds: 1), .expectFighting(true), .mark("Pause holds the encounter"),
        .pause, .wait(seconds: 0.2), .formation, .walk([5, 1]), .wait(seconds: 2),
        .expectFighting(false), .expectBeat(.alone), .expectFallBacks(0),
        .expectDefeated(0), .mark("the whole party withdraws"),
        .walk([5, -4]), .expectFighting(true), .awaitDisrupt(seconds: 3), .signature,
        .expectDisrupts(1), .fireUntilDefeated(1, seconds: 15),
        .awaitCombatClear(seconds: 2), .expectFallBacks(0), .expectDefeated(1),
        .mark("the optional shortcut is clear"), .walk([5, -7]), .walk([0, -24.5]),
        .walk(RelayRun.gateOutside), .switchLeader, .wait(seconds: 0.5),
        .walk(RelayRun.panelPoint), .act,
        .expectLine("Tom shifts the loose panel, and the gate swings open."),
        .mark("Tom opens the depot"), .wait(seconds: 1),
        .switchLeader, .switchLeader, .wait(seconds: 0.5),
        .walk(RelayRun.gateOutside), .walk(RelayRun.gateInside),
        .walkToCabinet(.compatible), .act, .act,
        .expectRepaired(false), .walk(RelayRun.gateInside), .walk(RelayRun.gateOutside),
        .walk([0, -24.5]), .walk([5, -7]), .walk([5, 1]), .walk(RelayRun.fork),
        .walk(RelayRun.transmitterPoint), .wait(seconds: 2), .talk,
        .expectRepaired(true), .expectFighting(false), .expectDefeated(1),
        .mark("the part returns through the shortcut"), .wait(seconds: 1),
      ] + restart
  }
#endif
