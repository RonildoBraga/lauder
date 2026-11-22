import RealityKit
import Testing
import simd

@testable import Lauder

/// The repeatable test's planner drives the real fight, session and preallocated presentation.
@MainActor
struct ArenaIntegrationTests {
  private let level = CombatYard.level
  private var party: [PartyMember: SIMD2<Float>] { level.spawns }

  @Test
  func onlyWarnedSlotsAppearAndThirtyWavesReuseTheSameActorsAndEntities() throws {
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    let stage = EncounterStage(level: level, style: SceneStyle())
    stage.reset(fight)
    let pool = Set(CombatYard.hostiles.map(\.id))
    let entities = count(stage.container)
    #expect(fight.hostiles.count == 8 && fight.hostiles.values.allSatisfy { !$0.isVisible })
    try begin(fight, session: session)

    for wave in 1...30 {
      try until(fight, session: session, stage: stage) { !fight.arenaWarnings.isEmpty }
      let warned = Set(fight.arenaWarnings.keys)
      #expect(warned.count == (wave.isMultiple(of: 2) ? 4 : 3))
      #expect(fight.hostiles.values.allSatisfy { !$0.isVisible })
      for id in pool {
        let marker = try #require(stage.container.findEntity(named: "arena.arrival.\(id)"))
        #expect(marker.isEnabled == warned.contains(id))
      }
      try until(fight, session: session, stage: stage) {
        fight.hostiles.values.contains { $0.isVisible }
      }
      let visible = Set(fight.hostiles.filter { $0.value.isVisible }.keys)
      #expect(visible == warned && visible.count <= 4 && fight.arenaWave == wave)
      // Exercise damage, searched-body and spent-round records for each reused ID. A new
      // life must take a fresh first hit, and the clear must forget all of the old life.
      for id in visible {
        #expect(!session.hit(id, toughness: 2))
        session.defeat(id)
        #expect(session.search(id, loot: Level.Loot(rounds: 1)))
      }
      #expect(session.spendRound())
      #expect(!session.takeHit(.miki))
      step(fight, session: session, stage: stage, dt: 0.01)
      #expect(fight.arenaWave == wave + 1 && session.inEncounter)
      #expect(session.defeated.isEmpty && session.searched.isEmpty)
      #expect(session.ammo == level.startingAmmo && session.hitsTaken == 0)
      #expect(fight.hostiles.values.allSatisfy { !$0.isVisible })
      #expect(Set(fight.hostiles.keys) == pool && fight.falls.count <= pool.count)
      #expect(count(stage.container) == entities)
    }
  }

  @Test
  func fallbackHidesEverySlotAndRetriesTheSameWaveWithFreshResources() throws {
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    let stage = EncounterStage(level: level, style: SceneStyle())
    try begin(fight, session: session)
    try until(fight, session: session, stage: stage) {
      fight.hostiles.values.contains { $0.isVisible }
    }
    let partlyHit = try #require(fight.hostiles.first { $0.value.isVisible }?.key)
    #expect(!session.hit(partlyHit, toughness: 2))
    #expect(session.spendRound())
    #expect(!session.takeHit(.miki))
    session.fallBack()
    fight.fallBack()
    stage.reset(fight)
    #expect(fight.arenaWave == 1 && fight.arenaWarnings.isEmpty)
    #expect(fight.hostiles.values.allSatisfy { !$0.isVisible })
    try begin(fight, session: session)
    step(fight, session: session, stage: stage, dt: 0.1)
    #expect(session.ammo == level.startingAmmo && session.hitsTaken == 0)
    #expect(session.defeated.isEmpty && session.searched.isEmpty)
    #expect(!session.hit(partlyHit, toughness: 2))
    #expect(fight.arenaWarnings.isEmpty && fight.hostiles.values.allSatisfy { !$0.isVisible })
    try until(fight, session: session, stage: stage) { !fight.arenaWarnings.isEmpty }
    #expect(fight.arenaWave == 1)

    session.restart()
    fight.reset()
    stage.reset(fight)
    #expect(fight.arenaWave == 1 && fight.arenaWarnings.isEmpty && !session.inEncounter)
    #expect(fight.hostiles.values.allSatisfy { !$0.isVisible })
  }

  @Test
  func pauseFreezesArrivalCountdownsThroughTheWorldAndRestartKeepsTheVenue() throws {
    let world = GameWorld(level: level)
    walk(world, to: [6, 3])
    let markers = try level.arena!.slots.map { slot in
      try #require(world.root.findEntity(named: "arena.arrival.\(slot.id)"))
    }
    for _ in 0..<600 where !markers.contains(where: { $0.isEnabled }) {
      world.advanceParty(movement: stick(world, towards: [0, -1]), deltaTime: 1 / 60)
    }
    try #require(world.session.inEncounter && markers.contains { $0.isEnabled })
    let visibility = markers.map(\.isEnabled)
    let scales = markers.map { $0.findEntity(named: "arena.arrival.countdown")?.scale }
    let positions = PartyMember.allCases.map { position(world, $0) }
    pressPause(world)
    for _ in 0..<600 {
      world.update(with: .neutral, sampledIn: .paused, deltaTime: 1 / 60)
    }
    #expect(world.session.mode == .paused && markers.map(\.isEnabled) == visibility)
    #expect(markers.map { $0.findEntity(named: "arena.arrival.countdown")?.scale } == scales)
    #expect(PartyMember.allCases.map { position(world, $0) } == positions)
    let restart = InputRules.Input(
      movement: .zero, actionPressed: false, pausePressed: false, switchPressed: false,
      restartPressed: true)
    world.update(with: restart, sampledIn: .paused, deltaTime: 1 / 60)
    #expect(world.level.id == level.id && !world.session.inEncounter)
    #expect(position(world, .miki) == level.spawn(.miki))
    #expect(markers.allSatisfy { !$0.isEnabled })
  }

  @Test
  func storyAndSalvageLevelsKeepTheirFiniteEncountersAndReceiveNoArenaMarkers() {
    for other in [BrooklynBridge.level, SalvageYard.level, RelayRun.level] {
      #expect(other.arena == nil)
      let fight = FightSimulation(level: other)
      let stage = EncounterStage(level: other, style: SceneStyle())
      #expect(fight.arenaWave == nil && fight.arenaWarnings.isEmpty && fight.arenaStatus == nil)
      #expect(!stage.container.children.contains { $0.name.hasPrefix("arena.arrival.") })
    }
  }

  private func begin(_ fight: FightSimulation, session: GameSession) throws {
    try #require(session.beginEncounter(CombatYard.fight.beat))
    fight.begin(CombatYard.fight)
  }

  private func until(
    _ fight: FightSimulation, session: GameSession, stage: EncounterStage,
    condition: () -> Bool
  ) throws {
    for _ in 0..<100 {
      if condition() { return }
      step(fight, session: session, stage: stage, dt: 0.25)
    }
    try #require(condition(), "The arena did not reach its next phase.")
  }

  private func step(
    _ fight: FightSimulation, session: GameSession, stage: EncounterStage, dt: Float
  ) {
    _ = fight.step(
      dt: dt, leader: level.spawn(.miki), facing: [0, -1], aiming: false, fireHeld: false,
      firePressed: false, mayDisrupt: true, signaturePressed: false, figures: party,
      session: session)
    stage.update(fight, dt: dt)
    _ = fight.takeEvents()
  }
}
