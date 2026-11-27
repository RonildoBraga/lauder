import Testing
import simd

@testable import Lauder

@MainActor
struct EnemyFireTests {
  @Test
  func aWindUpIsPermissionToFireNotAGuaranteedHitOnAMovingTarget() throws {
    let level = range(windUp: 0.1)
    let session = GameSession(level: level)
    let fight = EncounterSimulation(level: level)
    #expect(session.beginEncounter(.stranger))
    fight.begin(try #require(level.encounters.first))
    _ = step(fight, session: session, at: [0, 5], dt: HostileState.stepOutTime)
    // The rifle starts facing south. A target moving east cannot be acquired instantly.
    _ = step(fight, session: session, at: [5, 0], dt: 0.11)
    let shot = try #require(fight.shots.first)
    #expect(shot.path.strike == .nothing && session.hitsTaken == 0)
    #expect(shot.trace != nil && fight.hostileWeaponPoses["rifle"]?.kick == 1)
    let direction = simd_normalize(shot.path.end - shot.path.start)
    #expect(direction.y > 0.5 && direction.x < 0.8)
  }

  @Test
  func aSettledShotHitsTheFirstBodyItActuallyMeets() throws {
    let level = range(windUp: 1)
    let session = GameSession(level: level)
    let fight = EncounterSimulation(level: level)
    #expect(session.beginEncounter(.stranger))
    fight.begin(try #require(level.encounters.first))
    _ = step(fight, session: session, at: [0, 5], dt: HostileState.stepOutTime)
    var incoming: EncounterSimulation.Shot?
    for _ in 0..<140 {
      _ = step(fight, session: session, at: [0, 5], dt: 1 / 120)
      if let shot = fight.shots.first {
        incoming = shot
        break
      }
    }
    let shot = try #require(incoming)
    #expect(shot.path.strike == .body(PartyMember.miki.rawValue))
    #expect(session.hitsTaken == 1)
    #expect(shot.path.end.y < 5 && shot.path.end.y > 4.6)
  }

  @Test
  func anAuthoredWarningCannotHitEvenAnotherPartyMember() throws {
    let level = range(windUp: 0.1, firstMiss: true)
    let session = GameSession(level: level)
    let fight = EncounterSimulation(level: level)
    #expect(session.beginEncounter(.stranger))
    fight.begin(try #require(level.encounters.first))
    _ = step(fight, session: session, at: [0, 5], dt: HostileState.stepOutTime)
    _ = step(fight, session: session, at: [0, 5], dt: 0.11)
    #expect(fight.shots.count == 1 && fight.shots.first?.path.strike != .body("miki"))
    #expect(session.hitsTaken == 0 && session.hits(of: .tom) == 0)
  }

  /// A leader mid-roll is untouchable: the settled shot that would hit her passes through.
  @Test
  func aShotPassesThroughALeaderMidRoll() throws {
    let level = range(windUp: 1)
    let session = GameSession(level: level)
    let fight = EncounterSimulation(level: level)
    #expect(session.beginEncounter(.stranger))
    fight.begin(try #require(level.encounters.first))
    _ = step(
      fight, session: session, at: [0, 5], dt: HostileState.stepOutTime, untouchable: [.miki])
    var incoming: EncounterSimulation.Shot?
    for _ in 0..<140 {
      _ = step(fight, session: session, at: [0, 5], dt: 1 / 120, untouchable: [.miki])
      if let shot = fight.shots.first {
        incoming = shot
        break
      }
    }
    let shot = try #require(incoming)
    #expect(shot.path.strike != .body(PartyMember.miki.rawValue))
    #expect(session.hitsTaken == 0)
  }

  private func step(
    _ fight: EncounterSimulation, session: GameSession, at point: SIMD2<Float>, dt: Float,
    untouchable: Set<PartyMember> = []
  )
    -> EncounterSimulation.Outcome
  {
    fight.step(
      dt: dt, leader: point, facing: [0, -1], aiming: false, fireHeld: false,
      firePressed: false,
      figures: [.miki: point, .tom: [-0.6, 3]], session: session, untouchable: untouchable)
  }

  private func range(windUp: Float, firstMiss: Bool = false) -> Level {
    let rifle = Level.Hostile(
      id: "rifle", name: "Rifle", hiddenAt: .zero, standAt: .zero,
      hits: 10, attack: .shoot, windUp: windUp, recovery: 2, range: 14, firstShotMisses: firstMiss)
    return Level(
      id: "enemy-fire-range",
      ground: .box("floor", at: [0, -0.15, 0], size: [30, 0.3, 30]), boxes: [],
      triggers: [],
      encounters: [
        Level.Encounter(
          beat: .stranger, start: .area(.init(minimum: [-10, -10], maximum: [10, 10])),
          retryAt: nil, hostiles: [rifle], cues: [(0, .reveal("rifle")), (0, .engage("rifle"))])
      ], party: [.miki, .tom], spawns: [.miki: [0, 5], .tom: [-0.6, 3]],
      heading: [0, -1],
      cameraOffset: TestYard.cameraOffset, fieldOfView: 42,
      opening: "Range", objective: "Range", lookAround: "Range", restartNote: "Restart")
  }
}
