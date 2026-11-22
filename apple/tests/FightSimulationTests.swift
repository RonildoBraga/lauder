import Testing
import simd

@testable import Lauder

/// Fight rules and their presentation values can run without making a world or any entities.
@MainActor
struct FightSimulationTests {
  @Test
  func practiceFireProducesOneShotAndDrainableFeedbackWithoutSpendingRounds() throws {
    let level = CombatYard.level
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    let ammo = session.ammo
    let shot = try #require(fireOnce(fight, session: session))

    #expect(fight.isDrawn && fight.pose.raise == 1)
    #expect(shot.path.start == leader && shot.path.strike == .scenery)
    #expect(shot.muzzle == WeaponPose.muzzle(from: leader, facing: [0, -1]))
    #expect(session.ammo == ammo && !fight.fightUnderWay)
    let events = fight.takeEvents()
    #expect(
      events == [
        .fired(.carbine, at: leader, byLeader: true), .struckBlock(at: shot.path.end),
      ])
    #expect(fight.takeEvents().isEmpty)

    // A step that does not fire must not leave the previous shot for a renderer to show again.
    _ = step(fight, session: session)
    #expect(fight.shots.isEmpty && fight.takeEvents().isEmpty)
  }

  @Test
  func disruptCancelsATelegraphedShotAndUpdatesAimValuesWithoutARenderer() throws {
    let level = range()
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    let encounter = try #require(level.encounters.first)
    #expect(session.beginEncounter(encounter.beat))
    fight.begin(encounter)
    _ = step(fight, session: session, aiming: true)

    #expect(fight.canDisrupt && fight.fightUnderWay)
    #expect(fight.hostileAimPoints["shooter"] == leader)
    #expect(fight.target == [0, -4])
    let ammo = session.ammo
    let result = step(fight, session: session, signature: true)
    #expect(result.line == "Shooter's shot is disrupted.")
    #expect(result.facing == [0, -1])
    #expect(fight.disrupts == 1 && !fight.canDisrupt)
    #expect(fight.hostileAimPoints["shooter"] == nil)
    #expect(session.ammo == ammo && session.hitsTaken == 0)
    let shot = try #require(fight.shots.first)
    #expect(fight.shots.count == 1 && shot.path.strike == .body("shooter"))
    #expect(
      fight.takeEvents() == [
        .fired(.carbine, at: leader, byLeader: true), .struckBody(at: [0, -4]),
      ])
    #expect(fight.takeEvents().isEmpty)

    // Its cancelled wind-up cannot produce a delayed shot during recovery.
    for _ in 0..<120 {
      _ = step(fight, session: session)
      #expect(fight.shots.isEmpty)
    }
    #expect(session.hitsTaken == 0)
  }

  @Test
  func fallBackKeepsDamageAndDownedHostilesWhileRestartRestoresThem() throws {
    let level = range(hits: 2)
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    let encounter = try #require(level.encounters.first)
    #expect(session.beginEncounter(encounter.beat))
    fight.begin(encounter)
    let first = try #require(fireOnce(fight, session: session))
    #expect(first.path.strike == .body("shooter"))
    #expect(session.ammo == level.startingAmmo - 1 && session.defeated.isEmpty)

    session.fallBack()
    fight.fallBack()
    #expect(!fight.isDrawn && !fight.fightUnderWay)
    #expect(fight.hostiles["shooter"]?.phase == .waiting)
    #expect(fight.hostileAimPoints.isEmpty && fight.target == nil)
    // A second real shot takes it down: the first shot's damage survived falling back.
    #expect(session.beginEncounter(encounter.beat))
    fight.begin(encounter)
    let second = try #require(fireOnce(fight, session: session))
    #expect(second.path.strike == .body("shooter"))
    #expect(session.defeated == ["shooter"] && session.ammo == level.startingAmmo - 2)
    fight.fallBack()
    #expect(fight.hostiles["shooter"]?.isDown == true)
    #expect(fight.falls["shooter"] != nil)

    session.restart()
    fight.reset()
    #expect(session.defeated.isEmpty && session.ammo == level.startingAmmo)
    #expect(fight.hostiles["shooter"]?.phase == .waiting)
    #expect(fight.hostiles["shooter"]?.isTargetable == false)
    #expect(fight.falls.isEmpty && fight.shots.isEmpty)
  }

  @Test
  func aScriptedShotProducesTheTakedownAndItsPresentationValues() throws {
    let level = range(cues: [(0, .shot(by: .tom, at: "shooter"))])
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
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
        .fired(.closeScatter, at: [-1, 3], byLeader: false), .struckBody(at: [0, -4]),
      ])
    #expect(fight.takeEvents().isEmpty)
  }

  @Test
  func changingTheGateChangesTheNextPracticeShot() throws {
    let level = range(hostiles: [])
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    fight.setGate(PartyMotion.Box(minimum: [-2, -2], maximum: [2, -1]))
    let blocked = try #require(fireOnce(fight, session: session))
    #expect(blocked.path.strike == .scenery)
    fight.setGate(nil)
    let clear = try #require(fireOnce(fight, session: session))
    #expect(clear.path.strike == .nothing)
    #expect(simd_distance(clear.path.start, clear.path.end) > 13.9)
    #expect(session.ammo == level.startingAmmo)
  }

  private let leader = SIMD2<Float>(0, 2)
  private var figures: [PartyMember: SIMD2<Float>] {
    [.miki: leader, .tom: [-1, 3], .laura: [1, 3]]
  }

  /// Drive the production simulation until the carbine fires, respecting its draw and cooldown.
  private func fireOnce(_ fight: FightSimulation, session: GameSession) -> FightSimulation.Shot? {
    for frame in 0..<120 {
      _ = step(fight, session: session, fire: true, pressed: frame == 0, aiming: true)
      if let shot = fight.shots.first { return shot }
    }
    return nil
  }

  @discardableResult
  private func step(
    _ fight: FightSimulation, session: GameSession, fire: Bool = false, pressed: Bool = false,
    aiming: Bool = false, signature: Bool = false
  ) -> FightSimulation.Outcome {
    fight.step(
      dt: 1 / 120, leader: leader, facing: [0, -1], aiming: aiming, fireHeld: fire,
      firePressed: pressed, mayDisrupt: true, signaturePressed: signature,
      figures: figures, session: session)
  }

  /// The same small open-range pattern used by the world tests, with no companion weapon to
  /// change the hostile's damage while these checks drive the leader or a scripted cue.
  private func range(
    hits: Int = 50, hostiles: [Level.Hostile]? = nil,
    cues: [(at: Float, cue: Level.Cue)] = [(0, .engage("shooter"))]
  ) -> Level {
    let hostiles =
      hostiles ?? [
        Level.Hostile(
          id: "shooter", name: "Shooter", hiddenAt: [0, -4], standAt: [0, -4], hits: hits,
          windUp: 1.5, recovery: 1.4, range: 14, inView: true, targetsAnyone: true,
          targetFromWindUp: true)
      ]
    let encounter = Level.Encounter(
      beat: .stranger, start: .area(PartyMotion.Box(minimum: [-15, -15], maximum: [15, 15])),
      retryAt: leader, hostiles: hostiles, cues: cues)
    return Level(
      id: "simulation-range",
      ground: .box("ground", at: [0, -0.15, 0], size: [30, 0.3, 30]), boxes: [],
      interactions: [], triggers: [], encounters: [encounter], startingAmmo: 60,
      party: [.miki, .tom, .laura], spawns: figures, heading: [0, -1],
      cameraOffset: CombatYard.level.cameraOffset, fieldOfView: CombatYard.level.fieldOfView,
      opening: "A range.", objective: "Test.", lookAround: "Snow.", restartNote: "Restart.")
  }
}
