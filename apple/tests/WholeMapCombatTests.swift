import Testing
import simd

@testable import Lauder

/// Production firing separates a round's physical travel from target help and AI awareness.
@MainActor
struct WholeMapCombatTests {
  @Test
  func aManualShotHitsBeyondAssistanceWithoutSelectingAnOffscreenTarget() throws {
    let enemy = hostile(id: "far", at: [0, 42], hits: 1, windUp: 60)
    let level = range(hostiles: [enemy], engaged: [enemy.id])
    let (session, fight) = try begin(level)
    _ = try #require(enemyShot(fight, session: session, at: enemy.standAt - [0, 8], seconds: 62))
    for _ in 0..<60 { _ = step(fight, session: session, at: .zero, aiming: true) }
    #expect(fight.hostiles[enemy.id]?.isTargetable == true)
    #expect(fight.isDrawn && fight.target == nil)
    #expect(42 > fight.leaderWeapon.range)
    let incoming = try #require(partyShot(fight, session: session, at: .zero))
    #expect(incoming.path.strike == .body(enemy.id))
    #expect(simd_distance(incoming.path.start, incoming.path.end) > 40)
    #expect(session.defeated.contains(enemy.id) && session.ammo == level.startingAmmo - 1)
  }

  @Test
  func aManualLongShotStillStrikesNearerCoverInsteadOfTheDistantEnemy() throws {
    let enemy = hostile(id: "far", at: [0, 42], hits: 1, windUp: 60)
    let wall = Level.Box.box("nearer", at: [0, 1.5, 28], size: [8, 3, 1])
    let level = range(hostiles: [enemy], engaged: [enemy.id], boxes: [wall])
    let (session, fight) = try begin(level)
    _ = try #require(enemyShot(fight, session: session, at: enemy.standAt - [0, 8], seconds: 62))
    let shot = try #require(partyShot(fight, session: session, at: .zero))
    #expect(shot.path.strike == .scenery)
    #expect(abs(shot.path.end.y - 27.5) < 0.001)
    #expect(simd_distance(shot.path.start, shot.path.end) > fight.leaderWeapon.range)
    #expect(session.defeated.isEmpty && session.ammo == level.startingAmmo - 1)
  }

  @Test
  func aRifleCannotStartMapWideShotsOutsideItsAcquisitionRange() throws {
    let enemy = hostile(id: "rifle", at: .zero, windUp: 0.05, recovery: 0.05)
    let level = range(hostiles: [enemy], engaged: [enemy.id], player: [0, 42])
    let (session, fight) = try begin(level)
    // Many complete wind-up/recovery cycles would have occurred under the old `.blocked`
    // trigger. A longer physical ray must not make any of those nonexistent shots harmful.
    for _ in 0..<1200 {
      _ = step(fight, session: session, at: [0, 42])
      #expect(hostileShots(fight).isEmpty)
    }
    #expect(session.hitsTaken == 0)
    let shot = try #require(enemyShot(fight, session: session, at: [0, 8]))
    #expect(shot.path.strike == .body(PartyMember.miki.rawValue))
    #expect(session.hitsTaken == 1)
  }

  @Test
  func aWallStopsTheNativeRiflesShotsAtAHiddenLeader() throws {
    let enemy = hostile(id: "rifle", at: .zero, windUp: 0.05, recovery: 0.05)
    let wall = Level.Box.box("screen", at: [0, 1.5, 4], size: [4, 3, 1])
    let level = range(hostiles: [enemy], engaged: [enemy.id], boxes: [wall], player: [0, 8])
    let (session, fight) = try begin(level)
    var shotsStopped = 0
    for _ in 0..<600 {
      _ = step(fight, session: session, at: [0, 8])
      for shot in hostileShots(fight) {
        #expect(shot.path.strike == .scenery)
        shotsStopped += 1
      }
    }
    #expect(shotsStopped > 0 && session.hitsTaken == 0)
    #expect(enemyShot(fight, session: session, at: [6, 6]) != nil)
  }

  @Test
  func theAuthoredWarningTravelsToDistantSceneryWithoutHittingAnyPartyMember() throws {
    let enemy = hostile(
      id: "warning", at: .zero, windUp: 0.1, recovery: 5, firstMiss: true)
    let wall = Level.Box.box("far-screen", at: [0, 1.5, 50], size: [30, 3, 1])
    let members: [PartyMember: SIMD2<Float>] = [.miki: [0, 8], .tom: [-0.98, 8]]
    let level = range(
      hostiles: [enemy], engaged: [enemy.id], boxes: [wall], player: members[.miki]!,
      party: [.miki, .tom], spawns: members)
    let (session, fight) = try begin(level)
    var found: EncounterSimulation.Shot?
    for _ in 0..<120 {
      _ = step(fight, session: session, at: [0, 8], figures: members)
      if let shot = hostileShots(fight).first {
        found = shot
        break
      }
    }
    let warning = try #require(found)
    #expect(warning.path.strike == .scenery)
    #expect(simd_distance(warning.path.start, warning.path.end) > 45)
    #expect(session.hits(of: .miki) == 0 && session.hits(of: .tom) == 0)
    for _ in 0..<60 {
      _ = step(fight, session: session, at: [0, 8], figures: members)
      #expect(hostileShots(fight).isEmpty)
    }
  }

  @Test
  func anUnengagedPersonBeyondAssistanceBlocksAnIntentionalShotAtAnEnemyBehindThem() throws {
    let neutral = hostile(id: "unknown", at: [0, 42], hits: 1)
    let enemy = hostile(id: "known", at: [0, 58], hits: 1, windUp: 60)
    let level = range(hostiles: [neutral, enemy], engaged: [enemy.id])
    let (session, fight) = try begin(level)
    _ = try #require(enemyShot(fight, session: session, at: enemy.standAt - [0, 8], seconds: 62))
    for _ in 0..<240 {
      _ = step(fight, session: session, at: .zero, aiming: true, fire: true)
      #expect(fight.shots.isEmpty)
    }
    #expect(fight.hostiles[neutral.id]?.isTargetable == false)
    #expect(fight.hostiles[enemy.id]?.isTargetable == true)
    #expect(session.ammo == level.startingAmmo && session.defeated.isEmpty)
  }

  private func begin(_ level: Level) throws -> (GameSession, EncounterSimulation) {
    let session = GameSession(level: level)
    let fight = EncounterSimulation(level: level)
    let encounter = try #require(level.encounters.first)
    #expect(session.beginEncounter(encounter.beat))
    fight.begin(encounter)
    return (session, fight)
  }

  @discardableResult
  private func step(
    _ fight: EncounterSimulation, session: GameSession, at point: SIMD2<Float>,
    aiming: Bool = false, fire: Bool = false,
    figures: [PartyMember: SIMD2<Float>]? = nil
  ) -> EncounterSimulation.Outcome {
    fight.step(
      dt: 1 / 120, leader: point, facing: [0, 1], aiming: aiming,
      fireHeld: fire, firePressed: false,
      figures: figures ?? [.miki: point], session: session)
  }

  private func partyShot(_ fight: EncounterSimulation, session: GameSession, at point: SIMD2<Float>)
    -> EncounterSimulation.Shot?
  {
    for _ in 0..<180 {
      _ = step(fight, session: session, at: point, aiming: true, fire: true)
      if let shot = fight.shots.first(where: { if case .party = $0.side { true } else { false } }) {
        return shot
      }
    }
    return nil
  }

  private func enemyShot(
    _ fight: EncounterSimulation, session: GameSession, at point: SIMD2<Float>, seconds: Float = 3
  )
    -> EncounterSimulation.Shot?
  {
    for _ in 0..<Int(seconds * 120) {
      _ = step(fight, session: session, at: point)
      if let shot = hostileShots(fight).first { return shot }
    }
    return nil
  }

  private func hostileShots(_ fight: EncounterSimulation) -> [EncounterSimulation.Shot] {
    fight.shots.filter { if case .hostile = $0.side { true } else { false } }
  }

  private func hostile(
    id: String, at point: SIMD2<Float>, hits: Int = 100,
    windUp: Float = 1, recovery: Float = 1,
    firstMiss: Bool = false
  ) -> Level.Hostile {
    Level.Hostile(
      id: id, name: id, hiddenAt: point, standAt: point, hits: hits,
      windUp: windUp, recovery: recovery, range: 10,
      firstShotMisses: firstMiss)
  }

  private func range(
    hostiles: [Level.Hostile], engaged: [String], boxes: [Level.Box] = [],
    player: SIMD2<Float> = .zero, party: [PartyMember] = [.miki],
    spawns: [PartyMember: SIMD2<Float>]? = nil
  ) -> Level {
    Level(
      id: "whole-map-combat", ground: .box("floor", at: [0, -0.15, 30], size: [20, 0.3, 80]),
      boxes: boxes, interactions: [], triggers: [],
      encounters: [
        .init(
          beat: .stranger, start: .area(.init(minimum: [-10, -10], maximum: [10, 70])),
          retryAt: nil, hostiles: hostiles,
          cues: hostiles.map { (0, .reveal($0.id)) } + engaged.map { (0, .engage($0)) })
      ], startingAmmo: 60, party: party, spawns: spawns ?? [.miki: player], heading: [0, -1],
      cameraOffset: [0, 10, 10], fieldOfView: 42,
      opening: "Range.", objective: "Range.", lookAround: "Range.", restartNote: "Restart.")
  }
}
