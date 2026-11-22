import Testing
import simd

@testable import Lauder

/// Companions choose targets and expose their effective firing points in the production fight.
@MainActor
struct CompanionCombatTests {
  @Test
  func companionsPreferTheLeadersAssistedTargetOverANearerHostile() throws {
    let far = shooter("far", at: [0, -4])
    let near = shooter("near", at: [2, -1])
    let level = range(shooters: [far, near])
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    try begin(fight, session: session, level: level)
    for _ in 0..<4 { step(fight, session: session, level: level, facing: [0, -1]) }

    #expect(fight.target == far.standAt)
    for member in session.companions {
      let point = level.spawn(member)
      #expect(simd_distance(point, near.standAt) < simd_distance(point, far.standAt))
      #expect(fight.companionTargetIDs[member] == far.id)
      #expect(fight.aims[member] == far.standAt)
    }
  }

  @Test
  func aCompanionFallsBackWhenTheLeadersTargetIsBeyondTheirWeaponRange() throws {
    let far = shooter("far", at: [0, -8])
    let near = shooter("near", at: [2, -1])
    let level = range(shooters: [far, near])
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    try begin(fight, session: session, level: level)
    for _ in 0..<4 { step(fight, session: session, level: level, facing: [0, -1]) }

    #expect(fight.target == far.standAt)
    #expect(simd_distance(level.spawn(.tom), far.standAt) > Weapon.closeScatter.range)
    #expect(fight.companionTargetIDs[.tom] == near.id && fight.aims[.tom] == near.standAt)
    #expect(fight.companionTargetIDs[.laura] == far.id && fight.aims[.laura] == far.standAt)
  }

  @Test
  func aCompanionFallsBackWhenTheLeadersTargetIsBehindTheirWall() throws {
    let far = shooter("far", at: [0, -6])
    let near = shooter("near", at: [-6, -1])
    let level = range(
      boxes: [.box("wall", at: [-2, 1.5, -1], size: [1, 3, 2])],
      spawns: [.miki: [0, 2], .tom: [6, 4], .laura: [-4, 2]],
      shooters: [far, near], weapons: [.laura: .lightBurst])
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    try begin(fight, session: session, level: level)
    for _ in 0..<4 { step(fight, session: session, level: level, facing: [0, -1]) }

    #expect(fight.target == far.standAt)
    #expect(
      !LineOfSight.isClear(
        from: level.spawn(.laura), to: far.standAt, obstacles: level.obstacles))
    #expect(fight.companionTargetIDs[.laura] == near.id)
    let shot = try nextPartyShot(fight, session: session, level: level, facing: [0, -1])
    #expect(shot.path.start == level.spawn(.laura) && shot.path.strike == .body(near.id))
  }

  @Test
  func aCompanionsCommittedLowCoverPeekCanBeHitWhileTheyDuckTheNextWindUp() throws {
    // Laura is hidden at first, so the shooter initially aims at Miki. During its recovery
    // Laura fires; its next short wind-up can then acquire her still-exposed body.
    let level = range(
      boxes: [lowBlock], spawns: [.miki: [5, 3], .tom: [9, 8], .laura: [0, 0.9]],
      shooters: [shooter("shooter", at: [0, -4], windUp: 0.05, recovery: 0.55, anyone: true)],
      weapons: [.laura: .lightBurst])
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    try begin(fight, session: session, level: level)
    let outgoing = try nextPartyShot(fight, session: session, level: level)
    #expect(outgoing.path.start == level.spawn(.laura))
    let exposed = try #require(fight.coverStates[.laura])
    #expect(exposed.isLow && exposed.firing && exposed.exposed)

    var aimedAtLaura = false
    for _ in 0..<120 {
      step(fight, session: session, level: level)
      if fight.hostileAimPoints["shooter"] == level.spawn(.laura) {
        aimedAtLaura = true
        break
      }
    }
    #expect(aimedAtLaura)
    let shots = fight.companionShots[.laura, default: 0]
    var incoming: FightSimulation.Shot?
    for _ in 0..<120 {
      step(fight, session: session, level: level)
      // Ducking cancels the remaining burst. It cannot erase the already committed peek.
      #expect(fight.companionShots[.laura, default: 0] == shots)
      if let shot = fight.shots.first(where: { if case .hostile = $0.side { true } else { false } })
      {
        incoming = shot
        break
      }
    }
    let hit = try #require(incoming)
    #expect(hit.path.strike == .body(PartyMember.laura.rawValue))
    #expect(hit.path.end == level.spawn(.laura) && session.hits(of: .laura) == 1)
    #expect(fight.coverStates[.laura]?.firing == true)
    for _ in 0..<40 { step(fight, session: session, level: level) }
    #expect(fight.coverStates[.laura]?.firing == false)
    #expect(fight.coverStates[.laura]?.exposed == false)
  }

  @Test
  func aCompanionCannotFireThroughTheMiddleOfTallCover() throws {
    let level = range(
      boxes: [tallBlock], spawns: [.miki: [5, 3], .tom: [6, 3], .laura: [0, 0.9]],
      shooters: [shooter("shooter", at: [0, -4])], weapons: [.laura: .lightBurst])
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    try begin(fight, session: session, level: level)
    for _ in 0..<180 { step(fight, session: session, level: level) }
    let cover = try #require(fight.coverStates[.laura])
    #expect(!cover.isLow && !cover.firing && cover.offset == .zero)
    #expect(fight.companionTargetIDs[.laura] == nil)
    #expect(fight.companionShots[.laura, default: 0] == 0)
  }

  @Test
  func aCompanionsTallEdgeShotUsesTheSamePointAsTheirExposedBody() throws {
    let level = range(
      boxes: [tallBlock], spawns: [.miki: [5, 3], .tom: [6, 3], .laura: [0.75, 0.9]],
      shooters: [shooter("shooter", at: [1.5, -4])], weapons: [.laura: .lightBurst])
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    try begin(fight, session: session, level: level)
    let shot = try nextPartyShot(fight, session: session, level: level)
    let cover = try #require(fight.coverStates[.laura])
    #expect(!cover.isLow && cover.firing && cover.exposed)
    #expect(simd_length(cover.offset) > 0.1)
    #expect(simd_distance(shot.path.start, level.spawn(.laura) + cover.offset) < 0.001)
    #expect(cover.position == level.spawn(.laura))
    #expect(shot.path.strike == .body("shooter"))
  }

  @Test
  func switchingFallbackAndRestartClearEveryMembersTemporaryCoverExposure() throws {
    let level = range(
      boxes: [lowBlock], spawns: [.miki: [0, 0.9], .tom: [-0.7, 0.9], .laura: [0.7, 0.9]],
      shooters: [shooter("shooter", at: [0, -4])], weapons: [.laura: .lightBurst])
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    try begin(fight, session: session, level: level)
    _ = try nextPartyShot(fight, session: session, level: level, fire: true)
    #expect(fight.coverStates[.miki]?.firing == true)
    _ = try nextPartyShot(fight, session: session, level: level)
    #expect(fight.coverStates[.laura]?.firing == true)

    session.pressFormation()
    #expect(session.regrouping)
    session.cycleLeader()
    step(fight, session: session, level: level)
    #expect(session.leader == .tom)
    #expect(fight.coverStates.values.allSatisfy { !$0.firing })
    session.fallBack()
    fight.fallBack()
    #expect(fight.coverStates.isEmpty && fight.companionTargetIDs.isEmpty)

    try begin(fight, session: session, level: level)
    session.pressFormation()
    _ = try nextPartyShot(fight, session: session, level: level, fire: true)
    #expect(fight.coverStates[.tom]?.firing == true)
    session.restart()
    fight.reset()
    #expect(fight.coverStates.isEmpty && fight.companionTargetIDs.isEmpty)
  }

  private var lowBlock: Level.Box { .box("cover", at: [0, 0.5, 0], size: [2, 1, 1]) }
  private var tallBlock: Level.Box { .box("cover", at: [0, 1.5, 0], size: [2, 3, 0.5]) }

  private func begin(_ fight: FightSimulation, session: GameSession, level: Level) throws {
    let encounter = try #require(level.encounters.first)
    #expect(session.beginEncounter(encounter.beat))
    fight.begin(encounter)
  }

  @discardableResult
  private func step(
    _ fight: FightSimulation, session: GameSession, level: Level,
    facing: SIMD2<Float> = [1, 0], fire: Bool = false, pressed: Bool = false
  ) -> FightSimulation.Outcome {
    fight.step(
      dt: 1 / 120, leader: level.spawn(session.leader), facing: facing, aiming: true,
      fireHeld: fire, firePressed: pressed, mayDisrupt: false, signaturePressed: false,
      figures: level.spawns, session: session)
  }

  private func nextPartyShot(
    _ fight: FightSimulation, session: GameSession, level: Level,
    facing: SIMD2<Float> = [1, 0], fire: Bool = false
  ) throws -> FightSimulation.Shot {
    for frame in 0..<240 {
      step(
        fight, session: session, level: level, facing: facing, fire: fire,
        pressed: fire && frame == 0)
      if let shot = fight.shots.first(where: { if case .party = $0.side { true } else { false } }) {
        return shot
      }
    }
    throw NoPartyShot()
  }

  private struct NoPartyShot: Error {}

  private func shooter(
    _ id: String, at point: SIMD2<Float>, windUp: Float = 60, recovery: Float = 1.4,
    anyone: Bool = false
  ) -> Level.Hostile {
    Level.Hostile(
      id: id, name: id, hiddenAt: point, standAt: point, hits: 500, windUp: windUp,
      recovery: recovery, range: 14, inView: true, targetsAnyone: anyone, targetFromWindUp: true)
  }

  private func range(
    boxes: [Level.Box] = [],
    spawns: [PartyMember: SIMD2<Float>] = [
      .miki: [0, 2], .tom: [-0.9, 2.9], .laura: [0.9, 2.9],
    ], shooters: [Level.Hostile],
    weapons: [PartyMember: Weapon] = [.tom: .closeScatter, .laura: .lightBurst]
  ) -> Level {
    let encounter = Level.Encounter(
      beat: .stranger, start: .area(PartyMotion.Box(minimum: [-15, -15], maximum: [15, 15])),
      retryAt: spawns[.miki], hostiles: shooters,
      cues: shooters.map { (0, .engage($0.id)) })
    return Level(
      id: "companion-combat-range",
      ground: .box("ground", at: [0, -0.15, 0], size: [30, 0.3, 30]), boxes: boxes,
      interactions: [], triggers: [], encounters: [encounter], startingAmmo: 60,
      party: [.miki, .tom, .laura], spawns: spawns, heading: [0, -1],
      cameraOffset: CombatYard.level.cameraOffset, fieldOfView: CombatYard.level.fieldOfView,
      opening: "Companion range.", objective: "Test.", lookAround: "Snow.", restartNote: "Restart.",
      combat: Level.Combat(
        companionWeapons: weapons, fallsBack: true, combatPositioning: true, leaderCover: true))
  }
}
