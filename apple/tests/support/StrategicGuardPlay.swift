#if DEBUG
  import simd

  @testable import Lauder

  /// Run the same bounded player inputs used by rendered routes, from an already active fight.
  /// Every member moves through the world's navigation/collision; no immunity or state edits.
  /// `observe` sees the world after each frame, while the fight is still on.
  @MainActor
  func dismantleGuard(_ world: GameWorld, observe: (GameWorld) -> Void = { _ in }) -> Bool {
    var runner = PlaytestRunner(steps: [.dismantleGuard], name: "guard-contract")
    for _ in 0..<(60 * 62) where !runner.isFinished {
      let dt: Float = 1 / 60
      runner.tick(dt: dt)
      let raw = runner.input(world.playtestSnapshot)
      let mode = world.session.mode
      world.update(
        with: world.controls.resolve(raw, mode: mode), sampledIn: mode, deltaTime: dt)
      observe(world)
      runner.record(
        PlaytestRunner.Frame(
          dt: dt, leader: world.session.leader, positions: world.playtestSnapshot.positions,
          targets: world.companionTargets, warning: world.diagnostic, simulationMilliseconds: 0))
    }
    return runner.summary?.passed == true && world.session.defeated.contains("stranger")
  }
#endif
