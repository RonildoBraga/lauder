import Testing
import simd

@testable import Lauder

/// A displayed wind-up is necessary for Disrupt, but its old cue cannot outlive acquisition.
@MainActor
struct DisruptAcquisitionTests {
  @Test
  func aPriorCueCannotDisruptAShortRangeShooterAfterItsVictimLeavesAcquisition() throws {
    let (session, fight) = try begin()
    step(fight, session: session, at: [0, 6])
    #expect(fight.preparingShots.contains("rusher") && fight.canDisrupt)
    let rounds = session.ammo

    // Eight metres is still inside Miki's fourteen-metre signature reach, but outside the
    // rusher's seven-metre acquisition. The prior rendered cue must not authorise a shot.
    step(fight, session: session, at: [0, 8], signature: true)
    #expect(fight.disrupts == 0 && fight.shots.isEmpty && session.ammo == rounds)
    #expect(!fight.canDisrupt && !fight.preparingShots.contains("rusher"))

    // A fresh cue after reacquisition restores the signature, rather than disabling it.
    step(fight, session: session, at: [0, 6])
    #expect(fight.canDisrupt)
    step(fight, session: session, at: [0, 6], signature: true)
    #expect(fight.disrupts == 1 && fight.shots.count == 1)
  }

  @Test
  func startingATacticalMoveCancelsThePreviousStepsDisruptEligibility() throws {
    let (session, fight) = try begin(advancing: true)
    // The one-step arrival reaction finishes into a real cue. Navigation begins on the
    // following step, when the actor is known and aiming; a simultaneous signature is stale.
    step(fight, session: session, at: [0, 6])
    #expect(fight.preparingShots.contains("rusher") && fight.canDisrupt)
    let previous = try #require(fight.hostiles["rusher"]?.position)
    #expect(fight.movedEnemies.isEmpty)

    step(fight, session: session, at: [0, 6], signature: true)
    #expect(fight.movedEnemies.contains("rusher"))
    #expect(fight.hostiles["rusher"]?.position != previous)
    #expect(fight.disrupts == 0 && fight.shots.isEmpty)
    #expect(!fight.canDisrupt && !fight.preparingShots.contains("rusher"))
  }

  private func begin(advancing: Bool = false) throws -> (GameSession, FightSimulation) {
    let enemy = Level.Hostile(
      id: "rusher", name: "Rusher", hiddenAt: .zero, standAt: .zero, hits: 3,
      weapon: .closeScatter, behavior: advancing ? .advance : .stationary,
      reactionDelay: advancing ? 1 / 120 : 0,
      windUp: 5, recovery: 1, range: 7, firstShotMisses: false,
      inView: true, targetsAnyone: true, targetFromWindUp: true)
    let level = Level(
      id: "disrupt-acquisition", ground: .box("floor", at: [0, -0.15, 0], size: [32, 0.3, 32]),
      boxes: [], interactions: [], triggers: [],
      encounters: [
        .init(
          beat: .stranger, start: .area(.init(minimum: [-16, -16], maximum: [16, 16])),
          retryAt: nil, hostiles: [enemy], cues: [(0, .engage(enemy.id))])
      ],
      party: [.miki], spawns: [.miki: [0, 6]], heading: [0, -1],
      cameraOffset: [0, 10, 10], fieldOfView: 42,
      opening: "Range.", objective: "Range.", lookAround: "Range.", restartNote: "Restart.",
      combat: .init(disrupt: true))
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    let encounter = try #require(level.encounters.first)
    #expect(session.beginEncounter(encounter.beat))
    fight.begin(encounter)
    return (session, fight)
  }

  private func step(
    _ fight: FightSimulation, session: GameSession, at point: SIMD2<Float>, signature: Bool = false
  ) {
    _ = fight.step(
      dt: 1 / 120, leader: point, facing: [0, -1], aiming: false,
      fireHeld: false, firePressed: false, mayDisrupt: true, signaturePressed: signature,
      figures: [.miki: point], session: session)
  }
}
