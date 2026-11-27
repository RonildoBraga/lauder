import Testing
import simd

@testable import Lauder

/// The production fight owns each traveller's two weapons and their magazines (ADR 0021).
@MainActor
struct SquadWeaponTests {
  @Test(arguments: PartyMember.allCases)
  func everyLeaderFiresTheWeaponInHand(member: PartyMember) throws {
    let level = range()
    let session = GameSession(level: level)
    while session.leader != member { session.cycleLeader() }
    let fight = EncounterSimulation(level: level)
    try begin(fight, session: session, level: level)
    let shot = try #require(fireOnce(fight, session: session, level: level))
    let weapon = Weapon.pair(for: member)[0]
    #expect(fight.leaderWeapon.kind == weapon.kind)
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
  func laurasShotgunBlastIsOneShotThatDealsThreeHits() throws {
    let level = range(
      target: [0, 1], hits: 3, spawns: [.miki: [-2, 3], .tom: [2, 3], .laura: [0, 2]])
    let session = GameSession(level: level)
    session.cycleLeader()
    session.cycleLeader()
    let fight = EncounterSimulation(level: level)
    try begin(fight, session: session, level: level)
    let shot = try #require(fireOnce(fight, session: session, level: level))
    #expect(shot.path.strike == .body("target") && fight.shots.count == 1)
    #expect(session.defeated == ["target"])
  }

  @Test
  func switchingAwayAndBackCannotRefillLaurasMagazineOrShortenHerInterval() throws {
    let level = range()
    let session = GameSession(level: level)
    session.cycleLeader()
    session.cycleLeader()
    let fight = EncounterSimulation(level: level)
    try begin(fight, session: session, level: level)
    _ = try #require(fireOnce(fight, session: session, level: level))
    let loaded = fight.status(for: .laura).loaded
    for _ in 0..<3 {
      session.cycleLeader()
      step(fight, session: session, level: level)
    }
    #expect(session.leader == .laura && fight.status(for: .laura).loaded == loaded)
    for _ in 0..<30 {
      step(fight, session: session, level: level, fire: true)
      #expect(!fight.shots.contains { if case .party = $0.side { true } else { false } })
    }
    #expect(fight.status(for: .laura).loaded == loaded)
  }

  @Test
  func aReloadContinuesAcrossRolesWithoutRefillingOnASwitch() throws {
    let level = range()
    let session = GameSession(level: level)
    session.cycleLeader()
    let fight = EncounterSimulation(level: level)
    try begin(fight, session: session, level: level)
    try fireUntilReload(fight, session: session, level: level)
    let remaining = fight.status(for: .tom).reloadRemaining
    for _ in 0..<3 {
      session.cycleLeader()
      step(fight, session: session, level: level)
    }
    let after = fight.status(for: .tom)
    #expect(after.loaded == 0 && after.reloadRemaining > 0)
    #expect(abs(after.reloadRemaining - (remaining - 3 / 120)) < 0.001)
    for _ in 0..<400 { step(fight, session: session, level: level) }
    #expect(fight.status(for: .tom).loaded == Weapon.minigun.capacity)
    #expect(fight.status(for: .tom).reloadRemaining == 0)
  }

  @Test
  func restartRestoresWeaponHandlingAndTheFirstWeapons() throws {
    let level = range()
    let session = GameSession(level: level)
    session.cycleLeader()
    let fight = EncounterSimulation(level: level)
    try begin(fight, session: session, level: level)
    try fireUntilReload(fight, session: session, level: level)
    fight.swapWeapon(for: .miki)
    session.restart()
    fight.reset()
    for member in PartyMember.allCases {
      let status = fight.status(for: member)
      let first = Weapon.pair(for: member)[0]
      #expect(status.kind == first.kind && status.loaded == first.capacity)
      #expect(status.reloadRemaining == 0 && !status.isDrawn)
    }
  }

  #if DEBUG
    @Test
    func pauseCannotCompleteAReloadOrReplayAFirePress() throws {
      let world = GameWorld(level: TestRange.practice)
      world.session.cycleLeader()
      let aim = stick(world, towards: [0, -1])
      #expect(
        run(world, upTo: 10, fire: true, aim: aim) {
          world.playtestSnapshot.weapon.reloadRemaining > 0
        })
      let before = world.playtestSnapshot.weapon
      pressPause(world)
      #expect(world.session.mode == .paused)
      for _ in 0..<120 {
        world.update(with: .neutral, sampledIn: .paused, deltaTime: 1 / 60)
      }
      let paused = world.playtestSnapshot.weapon
      #expect(paused.loaded == before.loaded && paused.reloadRemaining == before.reloadRemaining)
      pressPause(world)
      _ = run(world, upTo: 3.2)
      #expect(world.playtestSnapshot.weapon.reloadRemaining == 0)
      #expect(world.playtestSnapshot.weapon.loaded == Weapon.minigun.capacity)
    }
  #endif

  private func begin(_ fight: EncounterSimulation, session: GameSession, level: Level) throws {
    let encounter = try #require(level.encounters.first)
    #expect(session.beginEncounter(encounter.beat))
    fight.begin(encounter)
    for _ in 0..<120 { step(fight, session: session, level: level) }
  }

  @discardableResult
  private func step(
    _ fight: EncounterSimulation, session: GameSession, level: Level,
    fire: Bool = false, pressed: Bool = false
  ) -> EncounterSimulation.Outcome {
    let leader = level.spawn(session.leader)
    let target = level.encounters[0].hostiles[0].standAt
    return fight.step(
      dt: 1 / 120, leader: leader, facing: simd_normalize(target - leader), aiming: true,
      fireHeld: fire, firePressed: pressed,
      figures: level.spawns, session: session)
  }

  private func fireOnce(_ fight: EncounterSimulation, session: GameSession, level: Level)
    -> EncounterSimulation.Shot?
  {
    for frame in 0..<240 {
      step(fight, session: session, level: level, fire: true, pressed: frame == 0)
      if let shot = fight.shots.first(where: { if case .party = $0.side { true } else { false } }) {
        return shot
      }
    }
    return nil
  }

  private func fireUntilReload(_ fight: EncounterSimulation, session: GameSession, level: Level)
    throws
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
    ]
  ) -> Level {
    let hostile = Level.Hostile(
      id: "target", name: "Target", hiddenAt: target, standAt: target, hits: hits, attack: .shoot,
      windUp: 0.01, recovery: 60, range: 14)
    let encounter = Level.Encounter(
      beat: .stranger, start: .area(PartyMotion.Box(minimum: [-15, -15], maximum: [15, 15])),
      retryAt: spawns[.miki], hostiles: [hostile],
      cues: [(0, .reveal(hostile.id)), (0, .engage(hostile.id))])
    return Level(
      id: "squad-weapon-range",
      ground: .box("ground", at: [0, -0.15, 0], size: [30, 0.3, 30]), boxes: [],
      triggers: [], encounters: [encounter], party: [.miki, .tom, .laura], spawns: spawns,
      heading: [0, -1],
      cameraOffset: TestYard.cameraOffset, fieldOfView: 42,
      opening: "A range.", objective: "Test.", lookAround: "Snow.", restartNote: "Restart.")
  }
}
