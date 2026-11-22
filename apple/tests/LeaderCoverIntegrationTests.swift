import Testing
import simd

@testable import Lauder

/// Cover's signal, shot geometry and damage must agree in the production fight simulation.
/// These ranges have no companion fire, so a teammate cannot hide a broken cover rule by
/// flinching or downing the shooter before its wind-up ends.
@MainActor
struct LeaderCoverIntegrationTests {
  @Test
  func aShotOnTheLastWindUpStepExposesTheLeaderBeforeIncomingDamageResolves() throws {
    let level = range()
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    try begin(fight, session: session, level: level)
    // Aiming draws the weapon without firing. Stop immediately before the hostile's next
    // fixed step will finish its wind-up, while the leader is still protected by the block.
    try prepareWindUp(fight, session: session, within: 1 / 120)
    #expect(fight.coverState?.firing == false && session.hitsTaken == 0)
    let rounds = session.ammo
    step(fight, session: session, fire: true, pressed: true)

    #expect(fight.shots.count == 2 && session.ammo == rounds - 1)
    let incoming = try #require(fight.shots.first)
    if case .hostile = incoming.side {} else { Issue.record("The hostile must fire first.") }
    #expect(incoming.path.strike == .body(PartyMember.miki.rawValue))
    #expect(incoming.path.end == leader && session.hitsTaken == 1)
    #expect(fight.coverState?.firing == true && fight.coverState?.exposed == true)
  }

  @Test
  func drawingAndEmptyClicksDoNotExposeTheLeader() throws {
    for ammo in [60, 0] {
      let level = range(ammo: ammo)
      let session = GameSession(level: level)
      let fight = FightSimulation(level: level)
      try begin(fight, session: session, level: level)
      // Holding Fire during the draw must not be mistaken for a shot.
      for frame in 0..<30 {
        step(fight, session: session, fire: true, pressed: frame == 0)
        #expect(fight.shots.isEmpty && fight.coverState?.firing == false)
      }
      if ammo > 0 {
        _ = try #require(fireOnce(fight, session: session))
        #expect(fight.coverState?.firing == true)
      } else {
        // Past the draw, empty clicks still leave the low block between body and shooter.
        for _ in 0..<120 {
          step(fight, session: session, fire: true)
          #expect(fight.coverState?.firing == false)
        }
        #expect(session.hitsTaken == 0 && session.ammo == 0)
        #expect(fight.takeEvents().contains { if case .empty = $0 { true } else { false } })
      }
    }
  }

  @Test
  func firingOverLowCoverAllowsTheIncomingShotThenCoverProtectsAgain() throws {
    let level = range()
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    try begin(fight, session: session, level: level)
    try prepareWindUp(fight, session: session)
    let sheltered = try #require(fight.coverState)
    #expect(sheltered.isLow && !sheltered.firing && !sheltered.exposed)

    // Fire east, away from the shooter, so its wind-up is not delayed by the leader's hit.
    let outgoing = try #require(fireOnce(fight, session: session))
    #expect(outgoing.path.start == leader)
    #expect(fight.coverState?.firing == true && fight.coverState?.exposed == true)
    let incoming = try nextHostileShot(fight, session: session)
    #expect(incoming.path.strike == .body(PartyMember.miki.rawValue))
    #expect(incoming.path.end == leader && session.hitsTaken == 1)

    for _ in 0..<60 { step(fight, session: session) }
    #expect(fight.coverState?.firing == false && fight.coverState?.exposed == false)
    let blocked = try nextHostileShot(fight, session: session)
    #expect(blocked.path.strike == .scenery && blocked.path.end.y <= 0.501)
    #expect(session.hitsTaken == 1)
  }

  @Test
  func movingAwayFromALowBlockLeavesTheStandingLeaderExposed() throws {
    let level = range()
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    try begin(fight, session: session, level: level)
    let sheltered = try nextHostileShot(fight, session: session)
    #expect(sheltered.path.strike == .scenery && session.hitsTaken == 0)

    // A low block only protects a character crouched near it. Backing away must not restore
    // the old footprint-only protection for a standing body above that same low block.
    let away = SIMD2<Float>(0, 2)
    step(fight, session: session, at: away)
    #expect(fight.coverState == nil)
    let incoming = try nextHostileShot(fight, session: session, at: away)
    #expect(fight.coverState == nil)
    #expect(incoming.path.strike == .body(PartyMember.miki.rawValue))
    #expect(incoming.path.end == away && session.hitsTaken == 1)
  }

  @Test
  func aTallEdgeUsesTheSamePeekPointForOutgoingAndIncomingShots() throws {
    let point = SIMD2<Float>(0.75, 0.9)
    let box = Level.Box.box("cover", at: [0, 1.5, 0], size: [2, 3, 0.5])
    let level = range(box: box, leader: point, shooters: [shooter(at: [1.5, -4])])
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    try begin(fight, session: session, level: level)
    try prepareWindUp(fight, session: session, at: point, facing: [0, -1])
    #expect(fight.coverState?.exposed == false)

    let outgoing = try #require(fireOnce(fight, session: session, at: point, facing: [0, -1]))
    let cover = try #require(fight.coverState)
    let exposedPoint = point + cover.offset
    #expect(!cover.isLow && cover.firing && cover.exposed)
    #expect(simd_length(cover.offset) > 0.1)
    #expect(simd_distance(outgoing.path.start, exposedPoint) < 0.001)
    #expect(outgoing.muzzle == WeaponPose.muzzle(from: exposedPoint, facing: [0, -1]))
    // Turning away after the shot cannot instantly duck the body back behind the wall. The
    // validated peek lasts for the exposure window, even though the weapon can aim elsewhere.
    step(fight, session: session, at: point, facing: [0, 1])
    let turned = try #require(fight.coverState)
    #expect(simd_distance(point + turned.offset, exposedPoint) < 0.001)
    let incoming = try nextHostileShot(fight, session: session, at: point, facing: [0, 1])
    #expect(incoming.path.strike == .body(PartyMember.miki.rawValue))
    #expect(simd_distance(incoming.path.end, exposedPoint) < 0.001)
    #expect(session.hitsTaken == 1)
  }

  @Test
  func aFlankerMakesTheShieldRedAndHitsWhileTheFrontShotStillStrikesCover() throws {
    let level = range(shooters: [shooter(at: [0, -4]), shooter(id: "flanker", at: [4, 1])])
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    try begin(fight, session: session, level: level)
    var shots: [FightSimulation.Shot] = []
    for _ in 0..<105 {
      step(fight, session: session)
      shots += fight.shots.filter { if case .hostile = $0.side { true } else { false } }
    }
    #expect(fight.coverState?.firing == false && fight.coverState?.exposed == true)
    #expect(shots.count == 2)
    #expect(shots.filter { $0.path.strike == .scenery }.count == 1)
    #expect(shots.filter { $0.path.strike == .body(PartyMember.miki.rawValue) }.count == 1)
    #expect(session.hitsTaken == 1)
  }

  @Test
  func levelsWithoutTheExperimentKeepTheirExistingLowBlockRule() throws {
    let level = range(enabled: false)
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    try begin(fight, session: session, level: level)
    try prepareWindUp(fight, session: session)
    _ = try #require(fireOnce(fight, session: session))
    #expect(fight.coverState == nil)
    let incoming = try nextHostileShot(fight, session: session)
    #expect(incoming.path.strike == .scenery && session.hitsTaken == 0)
    #expect(!BrooklynBridge.level.combat.leaderCover && !SalvageYard.level.combat.leaderCover)
  }

  @Test
  func exposureDoesNotCarryToAnotherLeaderOrSurviveFallbackAndReset() throws {
    let level = range()
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    try begin(fight, session: session, level: level)
    _ = try #require(fireOnce(fight, session: session))
    #expect(fight.coverState?.firing == true)
    session.cycleLeader()
    step(fight, session: session, at: level.spawn(.tom))
    #expect(fight.coverState == nil)
    session.cycleLeader()
    step(fight, session: session)
    #expect(fight.coverState?.firing == false)

    _ = try #require(fireOnce(fight, session: session))
    #expect(fight.coverState?.firing == true)
    session.fallBack()
    fight.fallBack()
    #expect(fight.coverState == nil)
    try begin(fight, session: session, level: level)
    _ = try #require(fireOnce(fight, session: session))
    #expect(fight.coverState?.firing == true)
    session.restart()
    fight.reset()
    #expect(fight.coverState == nil)
  }

  #if DEBUG
    @Test
    func pauseFreezesAnExposedStanceUntilFreshSimulationResumes() throws {
      let world = GameWorld(level: range())
      let aim = stick(world, towards: [1, 0])
      #expect(
        run(world, upTo: 1, fire: true, aim: aim) {
          world.playtestSnapshot.leaderCover?.firing == true
        })
      let ammo = world.session.ammo
      pressPause(world)
      #expect(world.session.mode == .paused)
      for _ in 0..<90 {
        world.update(with: .neutral, sampledIn: .paused, deltaTime: 1 / 60)
      }
      #expect(world.playtestSnapshot.leaderCover?.firing == true)
      #expect(world.session.ammo == ammo)
      pressPause(world)
      #expect(world.session.mode == .exploring)
      _ = run(world, upTo: 0.45)
      #expect(world.playtestSnapshot.leaderCover?.firing == false)
    }
  #endif

  private let leader = SIMD2<Float>(0, 0.9)

  private func begin(_ fight: FightSimulation, session: GameSession, level: Level) throws {
    let encounter = try #require(level.encounters.first)
    #expect(session.beginEncounter(encounter.beat))
    fight.begin(encounter)
  }

  @discardableResult
  private func step(
    _ fight: FightSimulation, session: GameSession, at point: SIMD2<Float>? = nil,
    facing: SIMD2<Float> = [1, 0], fire: Bool = false, pressed: Bool = false
  ) -> FightSimulation.Outcome {
    let point = point ?? leader
    return fight.step(
      dt: 1 / 120, leader: point, facing: facing, aiming: true, fireHeld: fire,
      firePressed: pressed, mayDisrupt: false, signaturePressed: false,
      figures: [session.leader: point], session: session)
  }

  private func prepareWindUp(
    _ fight: FightSimulation, session: GameSession, at point: SIMD2<Float>? = nil,
    facing: SIMD2<Float> = [1, 0], within: Float = 0.08
  ) throws {
    for _ in 0..<240 {
      step(fight, session: session, at: point, facing: facing)
      if case .aiming(let remaining)? = fight.hostiles["shooter"]?.phase,
        remaining <= within && remaining > 0
      {
        return
      }
    }
    throw CoverTestFailure.noWindUp
  }

  private func fireOnce(
    _ fight: FightSimulation, session: GameSession, at point: SIMD2<Float>? = nil,
    facing: SIMD2<Float> = [1, 0]
  ) -> FightSimulation.Shot? {
    for frame in 0..<120 {
      step(fight, session: session, at: point, facing: facing, fire: true, pressed: frame == 0)
      if let shot = fight.shots.first(where: { if case .party = $0.side { true } else { false } }) {
        return shot
      }
    }
    return nil
  }

  private func nextHostileShot(
    _ fight: FightSimulation, session: GameSession, at point: SIMD2<Float>? = nil,
    facing: SIMD2<Float> = [1, 0]
  ) throws -> FightSimulation.Shot {
    for _ in 0..<600 {
      step(fight, session: session, at: point, facing: facing)
      if let shot = fight.shots.first(where: { if case .hostile = $0.side { true } else { false } })
      {
        return shot
      }
    }
    throw CoverTestFailure.noHostileShot
  }

  private enum CoverTestFailure: Error { case noWindUp, noHostileShot }

  private func shooter(id: String = "shooter", at point: SIMD2<Float>) -> Level.Hostile {
    Level.Hostile(
      id: id, name: id, hiddenAt: point, standAt: point, hits: 50,
      windUp: 0.8, recovery: 1.4, range: 14, inView: true, targetFromWindUp: true)
  }

  private func range(
    box: Level.Box = .box("cover", at: [0, 0.5, 0], size: [2, 1, 1]),
    leader: SIMD2<Float> = [0, 0.9], shooters: [Level.Hostile]? = nil, enabled: Bool = true,
    ammo: Int = 60
  ) -> Level {
    let shooters = shooters ?? [shooter(at: [0, -4])]
    let encounter = Level.Encounter(
      beat: .stranger, start: .area(PartyMotion.Box(minimum: [-10, -10], maximum: [10, 10])),
      retryAt: leader, hostiles: shooters, cues: shooters.map { (0, .engage($0.id)) })
    return Level(
      id: "leader-cover-range",
      ground: .box("ground", at: [0, -0.15, 0], size: [30, 0.3, 30]), boxes: [box],
      interactions: [], triggers: [], encounters: [encounter], startingAmmo: ammo,
      party: [.miki, .tom], spawns: [.miki: leader, .tom: [5, 3], .laura: [6, 3]],
      heading: [0, -1],
      cameraOffset: CombatYard.level.cameraOffset, fieldOfView: CombatYard.level.fieldOfView,
      opening: "Cover range.", objective: "Test.", lookAround: "Snow.", restartNote: "Restart.",
      combat: Level.Combat(fallsBack: true, leaderCover: enabled))
  }
}
