import RealityKit
import Testing
import simd

@testable import Lauder

@MainActor
struct EnemyVarietyTests {
  @Test
  func theArenaUsesDistinctEquipmentAndSixRolesWithoutIncreasingTheActiveBudget() throws {
    let level = CombatYard.level
    let config = try #require(level.arena)
    #expect(config.slots.count == 10 && config.maxActive == 4)
    #expect(CombatYard.rightShooter.weapon == .submachineGun)
    #expect(CombatYard.rightShooter.burst == 4 && CombatYard.rightShooter.burstGap == 0.1)
    #expect(CombatYard.rusher.weapon == .closeScatter && CombatYard.rusher.burst == 1)
    #expect(CombatYard.marksman.weapon == .marksman)
    #expect(CombatYard.marksman.behavior == .keepDistance && CombatYard.marksman.windUp >= 2.4)
    #expect(CombatYard.supportGunner.weapon == .supportGun)
    #expect(CombatYard.supportGunner.behavior == .takeCover)
    #expect(CombatYard.supportGunner.burst == 6 && CombatYard.supportGunner.recovery >= 3)
    #expect(CombatYard.hostiles.filter { $0.weapon == .marksman }.count == 1)
    #expect(CombatYard.hostiles.filter { $0.weapon == .supportGun }.count == 1)
    #expect(CombatYard.marksman.hits <= CombatYard.leftShooter.hits)
    #expect(CombatYard.supportGunner.hits <= CombatYard.leftShooter.hits)
    let motion = PartyMotion(radius: PartyBody.radius, obstacles: level.obstacles)
    let grid = NavigationGrid(level: level)
    for spec in [CombatYard.marksman, CombatYard.supportGunner] {
      #expect(motion.canTraverse(from: spec.standAt, to: spec.standAt))
      #expect(grid.route(from: level.spawn(.miki), to: spec.standAt) != nil)
    }
    #expect(level.terrain.height(at: CombatYard.marksman.standAt) == 2.4)
    #expect(RelayRun.level.arena == nil && BrooklynBridge.level.arena == nil)
  }

  @Test
  func theThirdSafePackIntroducesBothNewRolesAfterTheExistingOpeningPacks() {
    var waves = ArenaWaves(config: CombatYard.waves)
    var packs: [Set<String>] = []
    for _ in 1...3 {
      let warning = waves.step(dt: 4, defeated: [], party: Array(CombatYard.spawns.values))
      #expect(warning.spawn.isEmpty && !waves.warnings.isEmpty)
      let spawned = waves.step(dt: 2, defeated: [], party: Array(CombatYard.spawns.values))
      #expect(spawned.spawn.count <= 4)
      packs.append(Set(spawned.spawn))
      let cleared = waves.step(
        dt: 0.01, defeated: Set(spawned.spawn), party: Array(CombatYard.spawns.values))
      #expect(cleared.resupply)
    }
    #expect(packs[0] == ["left-shooter", "right-shooter", "rusher"])
    #expect(packs[1] == ["thrower", "north-rifle", "north-flanker", "north-rusher"])
    #expect(packs[2] == ["north-thrower", "marksman", "support-gunner"])
  }

  @Test
  func aCrowdedMarksmanYieldsGroundWithinItsLegalHomeAndThenHoldsAComfortableLane() {
    let spec = marksman(at: [0, -4])
    let level = yard(hostiles: [spec])
    let motion = PartyMotion(radius: PartyBody.radius, obstacles: level.obstacles)
    var tactics = EnemyTactics(level: level)
    var actor = engaged(spec)
    let target = SIMD2<Float>(0, 5)
    var moved = false
    for _ in 0..<600 {
      let old = actor.position
      let step = tactics.step(hostiles: [spec.id: actor], party: [.miki: target], dt: 1 / 60)
      if let next = step.positions[spec.id] {
        #expect(motion.canTraverse(from: old, to: next))
        #expect(simd_distance(next, old) <= EnemyTactics.speed / 60 + 0.0001)
        #expect(simd_distance(next, spec.standAt) <= EnemyTactics.marksmanReach + 0.0001)
        actor.reposition(to: next)
      }
      moved = moved || step.moving.contains(spec.id)
    }
    #expect(moved)
    #expect(simd_distance(actor.position, target) >= EnemyTactics.marksmanNear - 0.2)
    #expect(simd_distance(actor.position, target) <= EnemyTactics.marksmanFar + 0.2)
    let settled = actor.position
    for _ in 0..<180 {
      let step = tactics.step(hostiles: [spec.id: actor], party: [.miki: target], dt: 1 / 60)
      #expect(step.moving.isEmpty)
    }
    #expect(actor.position == settled)
  }

  @Test
  func aComfortableMarksmanKeepsItsPositionInsteadOfConstantlyOrbiting() {
    let spec = marksman(at: [0, -20])
    var tactics = EnemyTactics(level: yard(hostiles: [spec]))
    let actor = engaged(spec)
    let step = tactics.step(hostiles: [spec.id: actor], party: [.miki: [0, 5]], dt: 1 / 60)
    #expect(step.moving.isEmpty && step.positions.isEmpty)
    #expect(tactics.goals[spec.id] == actor.position)
  }

  @Test
  func aMarksmanDoesNotReactToAnUnseenOrUnacquiredPartyAcrossTheMap() {
    let spec = marksman(at: [0, -10])
    let actor = engaged(spec)
    let wall = Level.Box.box("screen", at: [0, 1.5, 0], size: [10, 3, 1])
    var hidden = EnemyTactics(level: yard(hostiles: [spec], boxes: [wall]))
    #expect(
      hidden.step(hostiles: [spec.id: actor], party: [.miki: [0, 5]], dt: 1 / 60).moving.isEmpty)
    #expect(hidden.goals.isEmpty)
    var distant = EnemyTactics(level: yard(hostiles: [spec]))
    #expect(
      distant.step(hostiles: [spec.id: actor], party: [.miki: [0, 40]], dt: 1 / 60).moving.isEmpty)
    #expect(distant.goals.isEmpty)
  }

  @Test
  func aMarksmanRetreatCannotStepOffTheRealDeckOrThroughItsCover() {
    let spec = CombatYard.marksman
    let level = CombatYard.level
    let target = SIMD2<Float>(-18, -22)
    let motion = PartyMotion(radius: PartyBody.radius, obstacles: level.obstacles)
    var tactics = EnemyTactics(level: level)
    var actor = engaged(spec)
    let initialDistance = simd_distance(actor.position, target)
    var moved = false
    for _ in 0..<480 {
      let before = actor.position
      let step = tactics.step(hostiles: [spec.id: actor], party: [.miki: target], dt: 1 / 60)
      if let next = step.positions[spec.id] {
        #expect(motion.canTraverse(from: before, to: next))
        #expect(level.bounds.contains(next))
        #expect(simd_distance(next, spec.standAt) <= EnemyTactics.marksmanReach + 0.0001)
        actor.reposition(to: next)
      }
      moved = moved || step.moving.contains(spec.id)
    }
    #expect(moved && simd_distance(actor.position, target) > initialDistance + 2)
  }

  @Test
  func roleEquipmentAndNonDirectionalWindUpCueStayPooledAndFreezeOnPause() throws {
    let spec = marksman(at: [0, -20])
    let world = GameWorld(level: yard(hostiles: [spec]))
    // Sample neutral through the shared authority to release its initial input gate.
    for _ in 0..<30 {
      let mode = world.session.mode
      let input = world.controls.resolve(InputRules.Raw(), mode: mode)
      world.update(with: input, sampledIn: mode, deltaTime: 1 / 60)
    }
    let prop = try #require(world.root.findEntity(named: "hostile.test-marksman.marksman"))
    let role = try #require(world.root.findEntity(named: "hostile.test-marksman.role"))
    let cue = try #require(world.root.findEntity(named: "hostile.test-marksman.windup"))
    #expect(prop.isEnabled && role.isEnabled && cue.isEnabled)
    #expect(world.root.findEntity(named: "hostile.test-marksman.aim") == nil)
    let count = entityCount(world.root)
    let scale = cue.scale
    let position = cue.position
    world.session.togglePause()
    for _ in 0..<600 { world.update(with: .neutral, sampledIn: .paused, deltaTime: 1 / 60) }
    #expect(cue.isEnabled && cue.scale == scale && cue.position == position)
    #expect(entityCount(world.root) == count)
    let restart = InputRules.Input(
      movement: .zero, actionPressed: false, pausePressed: false, switchPressed: false,
      restartPressed: true)
    world.update(with: restart, sampledIn: .paused, deltaTime: 1 / 60)
    #expect(!cue.isEnabled && entityCount(world.root) == count)
  }

  private func marksman(at point: SIMD2<Float>) -> Level.Hostile {
    Level.Hostile(
      id: "test-marksman", name: "The marksman", hiddenAt: point, standAt: point,
      hits: 4, weapon: .marksman, behavior: .keepDistance, windUp: 2.4, recovery: 2.5,
      range: 45, inView: true, targetsAnyone: true, targetFromWindUp: true)
  }

  private func engaged(_ spec: Level.Hostile) -> HostileState {
    var state = HostileState(spec: spec)
    state.engage()
    if spec.reactionDelay > 0 {
      _ = state.step(dt: spec.reactionDelay, canHit: false, toward: .zero)
    }
    return state
  }

  private func yard(hostiles: [Level.Hostile], boxes: [Level.Box] = []) -> Level {
    Level(
      id: "enemy-variety-test",
      ground: .box("ground", at: [0, -0.15, 0], size: [60, 0.3, 60]), boxes: boxes,
      interactions: [], triggers: [],
      encounters: [
        Level.Encounter(
          beat: .stranger,
          start: .area(PartyMotion.Box(minimum: [-30, -30], maximum: [30, 30])),
          retryAt: nil, hostiles: hostiles, cues: [(0, .engage("test-marksman"))])
      ], party: [.miki],
      spawns: [.miki: [0, 5], .laura: [-1.4, 6.4], .tom: [1.4, 6.4]], heading: [0, -1],
      cameraOffset: TestYard.cameraOffset, fieldOfView: 42,
      opening: "A test.", objective: "Test.", lookAround: "A yard.", restartNote: "Restart.")
  }

  private func entityCount(_ entity: Entity) -> Int {
    1 + entity.children.reduce(0) { $0 + entityCount($1) }
  }
}
