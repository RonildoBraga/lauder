import Testing
import simd

@testable import Lauder

/// Fight rules and their presentation values can run without making a world or any entities.
@MainActor
struct EncounterSimulationTests {
  @Test
  func practiceFireProducesOneShotAndDrainableFeedback() throws {
    let level = TestRange.practice
    let session = GameSession(level: level)
    let fight = EncounterSimulation(level: level)
    let shot = try #require(fireOnce(fight, session: session))

    #expect(fight.isDrawn && fight.pose.raise == 1)
    #expect(shot.path.start == leader && shot.path.strike == .scenery)
    #expect(shot.muzzle == WeaponPose.muzzle(from: leader, facing: [0, -1], kind: .longRifle))
    let events = fight.takeEvents()
    #expect(
      events == [
        .fired(.longRifle, at: leader, byLeader: true), .struckBlock(at: shot.path.end),
      ])
    #expect(fight.takeEvents().isEmpty)

    // A step that does not fire must not leave the previous shot for a renderer to show again.
    _ = step(fight, session: session)
    #expect(fight.shots.isEmpty && fight.takeEvents().isEmpty)
  }

  @Test
  func aScriptedShotProducesTheTakedownAndItsPresentationValues() throws {
    let level = range(cues: [(0, .shot(by: .tom, at: "shooter"))])
    let session = GameSession(level: level)
    let fight = EncounterSimulation(level: level)
    let encounter = try #require(level.encounters.first)
    #expect(session.beginEncounter(encounter.beat))
    fight.begin(encounter)
    let result = step(fight, session: session)

    #expect(result.shooter?.member == .tom)
    #expect(result.line == "Shooter is down.")
    #expect(session.defeated == ["shooter"])
    #expect(fight.hostiles["shooter"]?.isDown == true)
    #expect(fight.falls["shooter"] != nil && fight.jolts[.tom] != nil)
    let shot = try #require(fight.shots.first)
    #expect(fight.shots.count == 1)
    #expect(shot.path.start == figures[.tom] && shot.path.strike == .body("shooter"))
    #expect(
      fight.takeEvents() == [
        .fired(.minigun, at: [-1, 3], byLeader: false), .struckBody(at: [0, -4]),
      ])
    #expect(fight.takeEvents().isEmpty)
  }

  private let leader = SIMD2<Float>(0, 2)
  private var figures: [PartyMember: SIMD2<Float>] {
    [.miki: leader, .tom: [-1, 3], .laura: [1, 3]]
  }

  /// Drive the production simulation until the long rifle fires, respecting its draw and
  /// cooldown.
  private func fireOnce(_ fight: EncounterSimulation, session: GameSession) -> EncounterSimulation
    .Shot?
  {
    for frame in 0..<120 {
      _ = step(fight, session: session, fire: true, pressed: frame == 0, aiming: true)
      if let shot = fight.shots.first { return shot }
    }
    return nil
  }

  @discardableResult
  private func step(
    _ fight: EncounterSimulation, session: GameSession, fire: Bool = false, pressed: Bool = false,
    aiming: Bool = false
  ) -> EncounterSimulation.Outcome {
    fight.step(
      dt: 1 / 120, leader: leader, facing: [0, -1], aiming: aiming, fireHeld: fire,
      firePressed: pressed,
      figures: figures, session: session)
  }

  /// The same small open-range pattern used by the world tests, with no companion weapon to
  /// change the hostile's damage while these checks drive the leader or a scripted cue.
  private func range(
    hits: Int = 50, hostiles: [Level.Hostile]? = nil,
    cues: [(at: Float, cue: Level.Cue)] = [(0, .reveal("shooter")), (0, .engage("shooter"))]
  ) -> Level {
    let hostiles =
      hostiles ?? [
        Level.Hostile(
          id: "shooter", name: "Shooter", hiddenAt: [0, -4], standAt: [0, -4], hits: hits,
          attack: .shoot,
          windUp: 1.5, recovery: 1.4, range: 14)
      ]
    let encounter = Level.Encounter(
      beat: .stranger, start: .area(PartyMotion.Box(minimum: [-15, -15], maximum: [15, 15])),
      retryAt: leader, hostiles: hostiles, cues: cues)
    return Level(
      id: "simulation-range",
      ground: .box("ground", at: [0, -0.15, 0], size: [30, 0.3, 30]), boxes: [],
      triggers: [], encounters: [encounter], party: [.miki, .tom, .laura], spawns: figures,
      heading: [0, -1],
      cameraOffset: TestYard.cameraOffset, fieldOfView: 42,
      opening: "A range.", objective: "Test.", lookAround: "Snow.", restartNote: "Restart.")
  }
}
