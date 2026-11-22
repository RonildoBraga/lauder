import RealityKit
import Testing
import simd

@testable import Lauder

/// Production fight values must reach the reusable stage entities without changing the rules.
@MainActor
struct EnemyPresentationTests {
  @Test
  func aRealGrenadeShowsItsPooledWarningAndBlastAndRestartClearsBoth() throws {
    let leader = SIMD2<Float>(0, 4)
    let thrower = Level.Hostile(
      id: "thrower", name: "The thrower", hiddenAt: [0, -4], standAt: [0, -4], hits: 3,
      attack: .throwGrenade, windUp: 0.06, recovery: 10, range: 14, inView: true,
      targetFromWindUp: true)
    let level = yard(hostile: thrower, leader: leader)
    let fight = FightSimulation(level: level)
    let session = GameSession(level: level)
    let stage = EncounterStage(level: level, style: SceneStyle())
    stage.reset(fight)
    let marker = try #require(stage.container.findEntity(named: "grenade.marker.thrower"))
    let role = try #require(stage.container.findEntity(named: "hostile.thrower.thrower"))
    let effects = try #require(stage.container.findEntity(named: "combat.shots"))
    let count = entityCount(stage.container)
    #expect(!marker.isEnabled && role.isEnabled)
    try begin(fight, session: session, level: level)
    for _ in 0..<120 where fight.grenades.isEmpty {
      step(fight, stage: stage, session: session, leader: leader)
    }
    let grenade = try #require(fight.grenades.first)
    #expect(marker.isEnabled && marker.position == [grenade.position.x, 0, grenade.position.y])
    #expect(entityCount(stage.container) == count)

    var sawBlast = false
    for _ in 0..<360 {
      step(fight, stage: stage, session: session, leader: [5, 4])
      if !fight.explosions.isEmpty {
        sawBlast = true
        #expect(!marker.isEnabled)
        #expect(effects.children.contains { $0.name == "hostile.flash" && $0.isEnabled })
        #expect(effects.children.contains { $0.name == "shot.chip" && $0.isEnabled })
        break
      }
    }
    #expect(sawBlast && entityCount(stage.container) == count)
    session.restart()
    fight.reset()
    stage.reset(fight)
    #expect(!marker.isEnabled && role.isEnabled)
    #expect(effects.children.allSatisfy { !$0.isEnabled })
    #expect(entityCount(stage.container) == count)
  }

  @Test
  func tacticalCoverAndRaisedWeaponsShowIntentWithoutAnExactAimLine() throws {
    let leader = SIMD2<Float>(3, 4)
    let shooter = Level.Hostile(
      id: "cover", name: "The cover shooter", hiddenAt: [1.8, -1], standAt: [1.8, -1], hits: 3,
      behavior: .takeCover, windUp: 1.5, recovery: 3, range: 14, inView: true,
      targetFromWindUp: true)
    let wall = Level.Box.box("wall", at: [0, 1.5, 0], size: [4, 3, 1])
    let level = yard(hostile: shooter, leader: leader, boxes: [wall])
    let fight = FightSimulation(level: level)
    let session = GameSession(level: level)
    let stage = EncounterStage(level: level, style: SceneStyle())
    let body = try #require(stage.container.findEntity(named: "hostile.cover"))
    let visual = try #require(body.children.first)
    let rifle = try #require(stage.container.findEntity(named: "hostile.cover.rifle"))
    #expect(stage.container.findEntity(named: "hostile.cover.aim") == nil)
    let shield = try #require(stage.container.findEntity(named: "cover.hostile.cover"))
    let count = entityCount(stage.container)
    try begin(fight, session: session, level: level)
    var sawCrouch = false
    var sawRaisedWeapon = false
    for _ in 0..<60 {
      step(fight, stage: stage, session: session, leader: leader)
      if let cover = fight.enemyCoverStates[shooter.id], !cover.firing {
        sawCrouch = true
        #expect(shield.isEnabled && visual.scale.y == 0.68)
        #expect(visual.position == fight.hostilePoses[shooter.id]?.position)
      }
      if let pose = fight.hostileWeaponPoses[shooter.id], pose.raise > 0 {
        sawRaisedWeapon = true
        #expect(rifle.isEnabled && rifle.parent === visual)
        #expect(rifle.position == pose.transform.position)
        #expect(rifle.orientation == pose.transform.orientation)
      }
    }
    #expect(sawCrouch && sawRaisedWeapon && entityCount(stage.container) == count)
    session.restart()
    fight.reset()
    stage.reset(fight)
    #expect(!shield.isEnabled && visual.scale == [1, 1, 1])
    #expect(stage.container.findEntity(named: "hostile.cover.aim") == nil)
    #expect(entityCount(stage.container) == count)
  }

  @Test
  func repeatedBlastsReuseTheShotPoolsAndLeaveNoPersistentWallMarks() {
    let container = Entity()
    let effects = ShotEffects(style: SceneStyle(), in: container)
    let count = entityCount(container)
    for index in 0..<40 { effects.blast(at: [Float(index % 3), 2]) }
    #expect(entityCount(container) == count && effects.marksShown == 0)
    #expect(container.children.contains { $0.name == "hostile.flash" && $0.isEnabled })
    #expect(container.children.contains { $0.name == "shot.chip" && $0.isEnabled })
    effects.update(dt: ShotEffects.chipTime + 0.1)
    #expect(container.children.allSatisfy { !$0.isEnabled })
    effects.blast(at: [2, 3])
    effects.clear()
    #expect(container.children.allSatisfy { !$0.isEnabled })
    #expect(entityCount(container) == count)
  }

  private func entityCount(_ entity: Entity) -> Int {
    1 + entity.children.reduce(0) { $0 + entityCount($1) }
  }

  private func begin(_ fight: FightSimulation, session: GameSession, level: Level) throws {
    let encounter = try #require(level.encounters.first)
    #expect(session.beginEncounter(encounter.beat))
    fight.begin(encounter)
  }

  private func step(
    _ fight: FightSimulation, stage: EncounterStage, session: GameSession,
    leader: SIMD2<Float>
  ) {
    _ = fight.step(
      dt: 1 / 120, leader: leader, facing: [0, -1], aiming: false, fireHeld: false,
      firePressed: false, mayDisrupt: false, signaturePressed: false,
      figures: [.miki: leader], session: session)
    stage.update(fight, dt: 1 / 120)
  }

  private func yard(
    hostile: Level.Hostile, leader: SIMD2<Float>, boxes: [Level.Box] = []
  ) -> Level {
    Level(
      id: "enemy-presentation", ground: .box("ground", at: [0, -0.15, 0], size: [24, 0.3, 24]),
      boxes: boxes, interactions: [], triggers: [],
      encounters: [
        Level.Encounter(
          beat: .stranger, start: .area(PartyMotion.Box(minimum: [-12, -12], maximum: [12, 12])),
          retryAt: nil, hostiles: [hostile], cues: [(0, .engage(hostile.id))])
      ],
      party: [.miki], spawns: [.miki: leader], heading: [0, -1],
      cameraOffset: TestYard.cameraOffset, fieldOfView: 42, opening: "Snow.", objective: "Test.",
      lookAround: "A yard.", restartNote: "Restart.", combat: Level.Combat(leaderCover: true))
  }
}
