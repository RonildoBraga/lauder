import Testing
import simd

@testable import Lauder

/// Precision fire must reacquire through actual cover instead of banking an unseen shot.
@MainActor
struct MarksmanLineOfSightTests {
  private let dt: Float = 1 / 120
  private let windUp: Float = 2.4

  @Test
  func returningFromCoverRequiresANewFullMarksmanWindUp() throws {
    let exposed = SIMD2<Float>(0, 24)
    let concealed = SIMD2<Float>(8, 24)
    let (session, fight) = try begin(party: [.miki: exposed])
    let rounds = session.ammo
    for _ in 0..<276 {
      step(fight, session: session, party: [.miki: exposed])
      #expect(fight.shots.isEmpty)
    }
    let nearlyReady = try #require(remaining(fight))
    #expect(nearlyReady > 0 && nearlyReady < 0.11)
    #expect(fight.preparingShots.contains("marksman") && fight.movedEnemies.isEmpty)
    #expect(fight.hostiles["marksman"]?.position == .zero)

    // Both positions are within the marksman's 20–30 m comfort band and 45 m acquisition.
    // The three-metre-high wall breaks the real ray without provoking a tactical retreat.
    for _ in 0..<6 {
      step(fight, session: session, party: [.miki: concealed])
      #expect(fight.shots.isEmpty && !fight.preparingShots.contains("marksman"))
    }
    #expect(fight.movedEnemies.isEmpty && session.hitsTaken == 0)

    step(fight, session: session, party: [.miki: exposed])
    #expect(try #require(remaining(fight)) > windUp - 2 * dt)
    #expect(fight.preparingShots.contains("marksman") && fight.shots.isEmpty)
    // Almost the whole authored wind-up must remain visible after reacquisition.
    for _ in 0..<285 {
      step(fight, session: session, party: [.miki: exposed])
      #expect(fight.shots.isEmpty && fight.preparingShots.contains("marksman"))
    }
    var shot: FightSimulation.Shot?
    for _ in 0..<8 {
      step(fight, session: session, party: [.miki: exposed])
      if let fired = fight.shots.first {
        shot = fired
        break
      }
    }
    let fired = try #require(shot)
    #expect(fired.path.strike == .body(PartyMember.miki.rawValue))
    #expect(session.hitsTaken == 2 && session.ammo == rounds)
    #expect(fight.movedEnemies.isEmpty && fight.hostiles["marksman"]?.position == .zero)
  }

  @Test
  func aPriorCueCannotDisruptAMarksmanWhoseAcquiredVictimJustBrokeSight() throws {
    let first: [PartyMember: SIMD2<Float>] = [.miki: [15, 35], .tom: [0, 24]]
    let (session, fight) = try begin(party: first)
    step(fight, session: session, party: first)
    #expect(fight.preparingShots.contains("marksman") && fight.movedEnemies.isEmpty)

    // Miki now has her own clear ten-metre signature shot, but the marksman's previously
    // acquired Tom has just gone behind the wall. Its old cue cannot authorise Disrupt.
    let hidden: [PartyMember: SIMD2<Float>] = [.miki: [0, -10], .tom: [8, 24]]
    step(fight, session: session, party: hidden, signature: true)
    #expect(fight.disrupts == 0 && fight.shots.isEmpty && fight.movedEnemies.isEmpty)
    #expect(try #require(remaining(fight)) > windUp - 2 * dt)
    // It has now acquired Miki and presented a fresh cue, which a later press can answer.
    #expect(fight.canDisrupt && fight.preparingShots.contains("marksman"))
    step(fight, session: session, party: hidden, signature: true)
    #expect(fight.disrupts == 1 && fight.shots.count == 1)
  }

  private func remaining(_ fight: FightSimulation) -> Float? {
    guard case .aiming(let value) = fight.hostiles["marksman"]?.phase else { return nil }
    return value
  }

  private func begin(party: [PartyMember: SIMD2<Float>]) throws -> (GameSession, FightSimulation) {
    let enemy = Level.Hostile(
      id: "marksman", name: "Marksman", hiddenAt: .zero, standAt: .zero, hits: 3,
      weapon: .marksman, behavior: .keepDistance, windUp: windUp, recovery: 2.5,
      range: 45, firstShotMisses: false, inView: true, targetsAnyone: true,
      targetFromWindUp: true)
    let level = Level(
      id: "marksman-sight", ground: .box("floor", at: [0, -0.15, 20], size: [40, 0.3, 80]),
      boxes: [.box("screen", at: [4, 1.5, 12], size: [3, 3, 1])],
      interactions: [], triggers: [],
      encounters: [
        .init(
          beat: .stranger, start: .area(.init(minimum: [-20, -20], maximum: [20, 60])),
          retryAt: nil, hostiles: [enemy], cues: [(0, .engage(enemy.id))])
      ],
      party: PartyMember.allCases.filter { party[$0] != nil }, spawns: party, heading: [0, -1],
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
    _ fight: FightSimulation, session: GameSession, party: [PartyMember: SIMD2<Float>],
    signature: Bool = false
  ) {
    _ = fight.step(
      dt: dt, leader: party[.miki]!, facing: [0, 1], aiming: false,
      fireHeld: false, firePressed: false, mayDisrupt: true, signaturePressed: signature,
      figures: party, session: session)
  }
}
