import Testing
import simd

@testable import Lauder

/// The production fight, rather than a second ammunition model, owns each traveller's weapon.
@MainActor
struct SquadWeaponTests {
  @Test(arguments: PartyMember.allCases)
  func everyLeaderFiresTheirOwnWeaponAndSpendsExactlyOneSharedRound(member: PartyMember) throws {
    let level = range()
    let session = GameSession(level: level)
    while session.leader != member { session.cycleLeader() }
    let fight = FightSimulation(level: level)
    try begin(fight, session: session, level: level)
    let shot = try #require(fireOnce(fight, session: session, level: level))
    let weapon = Weapon.forMember(member)
    #expect(fight.leaderWeapon.kind == weapon.kind)
    #expect(session.ammo == level.startingAmmo - 1)
    #expect(fight.status(for: member).loaded == weapon.capacity - 1)
    #expect(shot.path.start == level.spawn(member))
    #expect(
      fight.takeEvents().contains {
        if case .fired(let kind, _, let byLeader) = $0 {
          kind == weapon.kind && byLeader
        } else {
          false
        }
      })
  }

  @Test
  func tomsCloseBlastIsOneShotThatDealsTwoHits() throws {
    let level = range(
      target: [0, 1], hits: 2, spawns: [.miki: [-2, 3], .tom: [0, 2], .laura: [2, 3]])
    let session = GameSession(level: level)
    session.cycleLeader()
    let fight = FightSimulation(level: level)
    try begin(fight, session: session, level: level)
    let shot = try #require(fireOnce(fight, session: session, level: level))
    #expect(shot.path.strike == .body("target") && fight.shots.count == 1)
    #expect(session.defeated == ["target"] && session.ammo == level.startingAmmo - 1)
  }

  @Test
  func switchingAwayAndBackCannotRefillLaurasMagazineOrFinishHerBurstEarly() throws {
    let level = range()
    let session = GameSession(level: level)
    session.cycleLeader()
    session.cycleLeader()
    let fight = FightSimulation(level: level)
    try begin(fight, session: session, level: level)
    _ = try #require(fireOnce(fight, session: session, level: level))
    let loaded = fight.status(for: .laura).loaded
    let ammo = session.ammo
    for _ in 0..<3 {
      session.cycleLeader()
      step(fight, session: session, level: level)
    }
    #expect(session.leader == .laura && fight.status(for: .laura).loaded == loaded)
    for _ in 0..<30 {
      step(fight, session: session, level: level, fire: true)
      #expect(!fight.shots.contains { if case .party = $0.side { true } else { false } })
    }
    #expect(fight.status(for: .laura).loaded == loaded && session.ammo == ammo)
  }

  @Test
  func aReloadContinuesAcrossRolesWithoutRefillingOnASwitch() throws {
    let level = range()
    let session = GameSession(level: level)
    session.cycleLeader()
    let fight = FightSimulation(level: level)
    try begin(fight, session: session, level: level)
    try fireUntilReload(fight, session: session, level: level)
    let remaining = fight.status(for: .tom).reloadRemaining
    let ammo = session.ammo
    for _ in 0..<3 {
      session.cycleLeader()
      step(fight, session: session, level: level)
    }
    let after = fight.status(for: .tom)
    #expect(after.loaded == 0 && after.reloadRemaining > 0)
    #expect(abs(after.reloadRemaining - (remaining - 3 / 120)) < 0.001)
    #expect(session.ammo == ammo)
    for _ in 0..<240 { step(fight, session: session, level: level) }
    #expect(fight.status(for: .tom).loaded == Weapon.closeScatter.capacity)
    #expect(fight.status(for: .tom).reloadRemaining == 0 && session.ammo == ammo)
  }

  @Test
  func aCompanionKeepsTheSamePartlyUsedMagazineWhenTheyBecomeLeader() throws {
    let level = range(companionWeapons: [.laura: .lightBurst])
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    try begin(fight, session: session, level: level)
    for _ in 0..<240 {
      step(fight, session: session, level: level)
      if fight.companionShots[.laura, default: 0] > 0 { break }
    }
    #expect(fight.companionShots[.laura] == 1)
    let loaded = fight.status(for: .laura).loaded
    #expect(loaded == Weapon.lightBurst.capacity - 1 && session.ammo == level.startingAmmo)
    for _ in 0..<2 {
      session.cycleLeader()
      step(fight, session: session, level: level)
    }
    #expect(session.leader == .laura && fight.status(for: .laura).loaded == loaded)
    for _ in 0..<30 { step(fight, session: session, level: level, fire: true) }
    #expect(fight.status(for: .laura).loaded == loaded && session.ammo == level.startingAmmo)
  }

  @Test
  func companionsCanMissAtRangeAndNeverSpendTheSharedRounds() throws {
    let level = range(target: [0, -9], companionWeapons: [.laura: .lightBurst])
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    try begin(fight, session: session, level: level)
    var shots: [ShotPath] = []
    for _ in 0..<(120 * 36) {
      step(fight, session: session, level: level)
      shots += fight.shots.compactMap { if case .party = $0.side { $0.path } else { nil } }
    }
    #expect(shots.count >= 18)
    #expect(shots.contains { $0.strike == .nothing })
    #expect(session.ammo == level.startingAmmo)
  }

  @Test
  func restartRestoresWeaponHandlingWhileFallbackDoesNotCreateSharedRounds() throws {
    let level = range()
    let session = GameSession(level: level)
    session.cycleLeader()
    let fight = FightSimulation(level: level)
    try begin(fight, session: session, level: level)
    try fireUntilReload(fight, session: session, level: level)
    let ammo = session.ammo
    session.fallBack()
    fight.fallBack()
    #expect(session.ammo == ammo)
    session.restart()
    fight.reset()
    for member in PartyMember.allCases {
      let status = fight.status(for: member)
      #expect(status.loaded == Weapon.forMember(member).capacity)
      #expect(status.reloadRemaining == 0 && !status.isDrawn)
    }
    #expect(session.ammo == level.startingAmmo)
  }

  #if DEBUG
    @Test
    func pauseCannotCompleteAReloadOrReplayAFirePress() throws {
      let world = GameWorld(level: CombatYard.level)
      world.session.cycleLeader()
      let aim = stick(world, towards: [0, -1])
      #expect(
        run(world, upTo: 10, fire: true, aim: aim) {
          world.playtestSnapshot.weapon.reloadRemaining > 0
        })
      let before = world.playtestSnapshot.weapon
      let ammo = world.session.ammo
      pressPause(world)
      #expect(world.session.mode == .paused)
      for _ in 0..<120 {
        world.update(with: .neutral, sampledIn: .paused, deltaTime: 1 / 60)
      }
      let paused = world.playtestSnapshot.weapon
      #expect(paused.loaded == before.loaded && paused.reloadRemaining == before.reloadRemaining)
      #expect(world.session.ammo == ammo)
      pressPause(world)
      _ = run(world, upTo: 2.1)
      #expect(world.playtestSnapshot.weapon.reloadRemaining == 0)
      #expect(world.playtestSnapshot.weapon.loaded == Weapon.closeScatter.capacity)
      #expect(world.session.ammo == ammo)
    }
  #endif

  private func begin(_ fight: FightSimulation, session: GameSession, level: Level) throws {
    let encounter = try #require(level.encounters.first)
    #expect(session.beginEncounter(encounter.beat))
    fight.begin(encounter)
  }

  @discardableResult
  private func step(
    _ fight: FightSimulation, session: GameSession, level: Level,
    fire: Bool = false, pressed: Bool = false
  ) -> FightSimulation.Outcome {
    let leader = level.spawn(session.leader)
    let target = level.encounters[0].hostiles[0].standAt
    return fight.step(
      dt: 1 / 120, leader: leader, facing: simd_normalize(target - leader), aiming: true,
      fireHeld: fire, firePressed: pressed, mayDisrupt: false, signaturePressed: false,
      figures: level.spawns, session: session)
  }

  private func fireOnce(_ fight: FightSimulation, session: GameSession, level: Level)
    -> FightSimulation.Shot?
  {
    for frame in 0..<240 {
      step(fight, session: session, level: level, fire: true, pressed: frame == 0)
      if let shot = fight.shots.first(where: { if case .party = $0.side { true } else { false } }) {
        return shot
      }
    }
    return nil
  }

  private func fireUntilReload(_ fight: FightSimulation, session: GameSession, level: Level) throws
  {
    for frame in 0..<(120 * 12) {
      step(fight, session: session, level: level, fire: true, pressed: frame == 0)
      if fight.status(for: session.leader).reloadRemaining > 0 { return }
    }
    throw NoReload()
  }

  private struct NoReload: Error {}

  private func range(
    target: SIMD2<Float> = [0, -2], hits: Int = 500,
    spawns: [PartyMember: SIMD2<Float>] = [
      .miki: [0, 2], .tom: [-0.9, 2.9], .laura: [0.9, 2.9],
    ],
    companionWeapons: [PartyMember: Weapon] = [:]
  ) -> Level {
    let hostile = Level.Hostile(
      id: "target", name: "Target", hiddenAt: target, standAt: target, hits: hits,
      windUp: 60, recovery: 1.4, range: 14, inView: true, targetFromWindUp: true)
    let encounter = Level.Encounter(
      beat: .stranger, start: .area(PartyMotion.Box(minimum: [-15, -15], maximum: [15, 15])),
      retryAt: spawns[.miki], hostiles: [hostile], cues: [(0, .engage(hostile.id))])
    return Level(
      id: "squad-weapon-range",
      ground: .box("ground", at: [0, -0.15, 0], size: [30, 0.3, 30]), boxes: [],
      interactions: [], triggers: [], encounters: [encounter], startingAmmo: 60,
      party: [.miki, .tom, .laura], spawns: spawns, heading: [0, -1],
      cameraOffset: CombatYard.level.cameraOffset, fieldOfView: CombatYard.level.fieldOfView,
      opening: "A range.", objective: "Test.", lookAround: "Snow.", restartNote: "Restart.",
      combat: Level.Combat(companionWeapons: companionWeapons, fallsBack: true))
  }
}
