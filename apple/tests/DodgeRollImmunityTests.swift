import Testing
import simd

@testable import Lauder

/// The leader's dodge roll in the world, pressed through the real controls (issue #209,
/// finding 1). Miki rolls straight away from the guard just before its precision burst, so she
/// stays on its committed line while every round fires: only the roll's immunity can keep her
/// unhurt. The same moment without the roll is the control, and it is hit.
@MainActor
struct DodgeRollImmunityTests {
  #if DEBUG
    @Test(arguments: [true, false])
    func aRollAlongTheGuardsCommittedLineCarriesMikiThroughItsBurst(rolls: Bool) throws {
      let burst = RobotGuard.Pattern.precision
      let span = Float(burst.roundCount - 1) * burst.shotInterval
      // The roll has to start before the first round and still be under way at the last.
      try #require(DodgeRoll.duration > span)
      let world = GameWorld(level: Self.range())
      let step = GameWorld.simulationStep
      var frames = 0
      func frame(_ raw: InputRules.Raw = .init()) {
        let mode = world.session.mode
        world.update(
          with: world.controls.resolve(raw, mode: mode), sampledIn: mode, deltaTime: step)
        frames += 1
      }

      // The guard notices Miki, tracks her and fixes its line on where she stands.
      for _ in 0..<Int(8 / step) where world.playtestSnapshot.robotPhase != .committed {
        frame()
      }
      var snapshot = world.playtestSnapshot
      try #require(snapshot.robotPhase == .committed && snapshot.guardTarget == .miki)
      let guardian = try #require(snapshot.robotPosition)
      let start = try #require(snapshot.positions[.miki])
      let committed = try #require(snapshot.robotCommittedPoint)
      try #require(simd_distance(committed, start) < PartyBody.radius)
      let line = simd_normalize(committed - guardian)

      // Press at the middle of the moments from which one roll covers the whole burst.
      let pressAt = burst.commitTime - (DodgeRoll.duration - span) / 2
      for _ in 1..<Int((pressAt / step).rounded()) { frame() }
      let pressed = frames + 1
      let shotsBefore = world.playtestSnapshot.robotShots
      frame(
        .init(
          stick: rolls
            ? Movement.stick(towards: line, cameraOffset: world.level.cameraOffset) : .zero,
          controllerDodge: rolls))

      // Every round of the burst fires while the roll is under way, each with Miki on the line.
      var rounds: [(frame: Int, at: SIMD2<Float>)] = []
      var shots = shotsBefore
      while frames < pressed + Int((DodgeRoll.duration / step).rounded()) + 30 {
        frame()
        snapshot = world.playtestSnapshot
        if snapshot.robotShots > shots, let miki = snapshot.positions[.miki] {
          rounds.append((frames, miki))
          shots = snapshot.robotShots
        }
      }
      try #require(rounds.count == burst.roundCount)
      let rollEnds = pressed + Int((DodgeRoll.duration / step).rounded()) - 1
      #expect(rounds.allSatisfy { $0.frame >= pressed && $0.frame <= rollEnds })
      for round in rounds {
        let offset = round.at - guardian
        let aside = simd_length(offset - line * simd_dot(offset, line))
        #expect(aside < PartyBody.radius, "Miki left the committed line by \(aside) m")
      }
      let end = try #require(world.playtestSnapshot.positions[.miki])
      if rolls {
        // She rolled its full length along the line, and no round touched her.
        #expect(simd_distance(end, start) > DodgeRoll.distance - 0.2)
        #expect(world.playtestSnapshot.partyHits[.miki] == 0)
      } else {
        #expect(simd_distance(end, start) < 0.05)
        #expect(world.playtestSnapshot.partyHits[.miki] == 1)
      }
    }

    /// Miki alone on open ground in front of the guard, with nothing between them.
    private static func range() -> Level {
      let guardian = Level.Hostile(
        id: "stranger", name: "Guard", hiddenAt: .zero, standAt: .zero, hits: 6,
        attack: .robot, strategicGuard: true, range: 12)
      let encounter = Level.Encounter(
        beat: .stranger, start: .area(.init(minimum: [-20, -20], maximum: [20, 20])),
        retryAt: [0, 18], hostiles: [guardian],
        cues: [(0, .reveal(guardian.id)), (0, .engage(guardian.id))])
      return Level(
        id: "dodge-roll-range",
        ground: .box("floor", at: [0, -0.15, 0], size: [60, 0.3, 60]),
        boxes: [], triggers: [], encounters: [encounter], party: [.miki],
        spawns: [.miki: [0, 6], .tom: [-2, 8], .laura: [2, 8]], heading: [0, -1],
        cameraOffset: BrooklynBridge.cameraOffset, fieldOfView: 22, opening: "Range",
        objective: "Test", lookAround: "Range", restartNote: "Restart")
    }
  #endif
}
