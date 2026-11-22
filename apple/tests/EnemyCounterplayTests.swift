import RealityKit
import Testing
import simd

@testable import Lauder

/// Movement must leave time to read an attack, and concurrent warnings must describe the
/// approaching attack rather than whichever actor happens to appear last in a level value.
@MainActor
struct EnemyCounterplayTests {
  private let dt: Float = 1 / 120

  @Test
  func anArenaFlankerMustPrepareAgainAfterMovingWithANearlyFinishedAim() throws {
    let (session, fight, enemy) = try movingFight(burst: 1)
    let first = SIMD2<Float>(0, 12)
    try settle(fight, session: session, at: first)
    try advance(fight, session: session, at: first, seconds: 4) {
      if case .aiming(let remaining) = fight.hostiles[enemy.id]?.phase {
        return remaining < 0.35
      }
      return false
    }
    let next = SIMD2<Float>(-12, 6)
    try waitForMove(fight, session: session, at: next)
    try settle(fight, session: session, at: next)
    guard case .aiming(let remaining) = fight.hostiles[enemy.id]?.phase else {
      Issue.record("A moved flanker did not return to preparing its shot")
      return
    }
    #expect(remaining >= enemy.windUp - 2 * dt)
    for _ in 0..<60 {
      step(fight, session: session, at: next)
      #expect(fight.shots.isEmpty, "A moved actor resumed its old near-complete wind-up")
    }
    #expect(session.hitsTaken == 0)
  }

  @Test
  func anArenaFlankerCannotResumeItsOldBurstOnArrival() throws {
    let (session, fight, enemy) = try movingFight(burst: 12)
    let first = SIMD2<Float>(0, 12)
    try settle(fight, session: session, at: first)
    try advance(fight, session: session, at: first, seconds: 5) { !fight.shots.isEmpty }
    // The long fixture burst straddles the ordinary three-second flank replan. Low cover
    // protects the opening; the new flank can see around it. Health and handling stay real.
    for _ in 0..<312 { step(fight, session: session, at: first) }
    let next = SIMD2<Float>(-12, 6)
    try waitForMove(fight, session: session, at: next)
    try settle(fight, session: session, at: next)
    guard case .recovering(let remaining) = fight.hostiles[enemy.id]?.phase else {
      Issue.record("Movement skipped the flanker’s post-shot recovery")
      return
    }
    #expect(remaining > 1)
    for _ in 0..<60 {
      step(fight, session: session, at: next)
      #expect(fight.shots.isEmpty, "A queued pre-movement round replayed on arrival")
    }
    #expect(session.hitsTaken == 0)
  }

  @Test(arguments: [false, true], [false, true])
  func theImminentAttackOwnsBothWarningAndBearingRegardlessOfArrayOrder(
    grenadier: Bool, reverse: Bool
  ) throws {
    let name = grenadier ? "Urgent grenadier" : "Urgent rusher"
    let urgent = Level.Hostile(
      id: "urgent", name: name, hiddenAt: [0, -2], standAt: [0, -2], hits: 4,
      attack: grenadier ? .throwGrenade : .shoot,
      weapon: grenadier ? .rifle : .closeScatter,
      windUp: 0.9, recovery: 3, range: grenadier ? 19 : 7,
      inView: true, targetsAnyone: true, targetFromWindUp: true)
    let longGun = Level.Hostile(
      id: "later", name: "Later marksman", hiddenAt: [8, -15], standAt: [8, -15], hits: 4,
      weapon: .marksman, windUp: 5, recovery: 3, range: 45,
      inView: true, targetsAnyone: true, targetFromWindUp: true)
    let world = GameWorld(
      level: yard(
        hostiles: reverse ? [longGun, urgent] : [urgent, longGun], at: [0, 4]))
    var found = false
    for _ in 0..<240 {
      update(world)
      let states = world.playtestSnapshot.hostiles
      if case .aiming = states[urgent.id]?.phase,
        case .aiming = states[longGun.id]?.phase
      {
        found = true
        break
      }
    }
    try #require(found, "Both acquired actors must be preparing before comparing warning priority")
    #expect(world.threat?.contains(name) == true)
    #expect(world.compass?.name == "Preparing: \(name)")
  }

  @Test(arguments: [false, true])
  func equalPreparationDeadlinesHaveAStableActorTieBreak(reverse: Bool) throws {
    let first = Level.Hostile(
      id: "a", name: "First rifle", hiddenAt: [-3, -5], standAt: [-3, -5], hits: 4,
      windUp: 2, recovery: 3, range: 25,
      inView: true, targetsAnyone: true, targetFromWindUp: true)
    let second = Level.Hostile(
      id: "b", name: "Second rifle", hiddenAt: [3, -5], standAt: [3, -5], hits: 4,
      windUp: 2, recovery: 3, range: 25,
      inView: true, targetsAnyone: true, targetFromWindUp: true)
    let world = GameWorld(
      level: yard(
        hostiles: reverse ? [second, first] : [first, second], at: [0, 4]))
    for _ in 0..<240 {
      update(world)
      if case .aiming = world.playtestSnapshot.hostiles[first.id]?.phase,
        case .aiming = world.playtestSnapshot.hostiles[second.id]?.phase
      {
        break
      }
    }
    #expect(world.threat?.contains(first.name) == true)
    #expect(world.compass?.name == "Preparing: \(first.name)")
  }

  @Test
  func anArenaPreparationBarStaysInWorldSpaceAndFreezesWithoutGrowingThePool() throws {
    let enemy = Level.Hostile(
      id: "cue", name: "Rifle", hiddenAt: [0, -2], standAt: [0, -2], hits: 4,
      windUp: 2.4, recovery: 3, range: 25,
      inView: true, targetsAnyone: true, targetFromWindUp: true)
    let world = GameWorld(level: yard(hostiles: [enemy], at: [0, 4]))
    let cue = try #require(world.root.findEntity(named: "hostile.cue.windup"))
    let fill = try #require(world.root.findEntity(named: "hostile.cue.windup.remaining"))
    let entities = count(world.root)
    for _ in 0..<240 {
      update(world)
      if cue.isEnabled { break }
    }
    try #require(cue.isEnabled)
    #expect(cue.parent === world.root.findEntity(named: "combat"))
    #expect(cue.orientation == simd_quatf(angle: 0, axis: [0, 1, 0]))
    let width = fill.scale.x
    for _ in 0..<30 { update(world) }
    #expect(fill.scale.x < width && fill.scale.x > 0)
    let frozen = fill.scale
    let position = cue.position
    world.session.togglePause()
    for _ in 0..<120 { update(world) }
    #expect(fill.scale == frozen && cue.position == position && cue.isEnabled)
    #expect(count(world.root) == entities)
    world.restart()
    #expect(!cue.isEnabled && count(world.root) == entities)
  }

  private func movingFight(burst: Int) throws -> (GameSession, FightSimulation, Level.Hostile) {
    let enemy = Level.Hostile(
      id: "flanker", name: "Flanker", hiddenAt: .zero, standAt: .zero, hits: 4,
      weapon: .submachineGun, behavior: .flank, reactionDelay: 0.1,
      burst: burst, burstGap: 0.4, windUp: 3.2, recovery: 6, range: 30,
      inView: true, targetFromWindUp: true)
    let boxes: [Level.Box] = [
      .box("first-cover", at: [0, 0.55, 11], size: [18, 1.1, 1]),
      .box("second-cover", at: [-12, 0.55, 5], size: [18, 1.1, 1]),
    ]
    let level = yard(hostiles: [enemy], at: [0, 12], boxes: boxes, cover: true)
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    let encounter = try #require(level.encounters.first)
    #expect(session.beginEncounter(encounter.beat))
    fight.begin(encounter)
    return (session, fight, enemy)
  }

  private func yard(
    hostiles: [Level.Hostile], at point: SIMD2<Float>, boxes: [Level.Box] = [], cover: Bool = false
  ) -> Level {
    let ground = Level.Box.box("floor", at: [0, -0.15, 6], size: [52, 0.3, 60])
    return Level(
      id: "enemy-counterplay", ground: ground, boxes: boxes,
      interactions: [], triggers: [],
      encounters: [
        .init(
          beat: .stranger, start: .area(ground.footprint), retryAt: nil,
          hostiles: hostiles, cues: [])
      ],
      party: [.miki], spawns: [.miki: point, .tom: point + [2, 1], .laura: point + [-2, 1]],
      heading: [0, -1], cameraOffset: TestYard.cameraOffset, fieldOfView: 42,
      opening: "Test.", objective: "Test.", lookAround: "Test.", restartNote: "Test.",
      combat: .init(leaderCover: cover),
      arena: .init(
        slots: hostiles.map { .init(id: $0.id, point: $0.standAt) },
        warningDuration: 0.01, minimumDistance: 1))
  }

  private func advance(
    _ fight: FightSimulation, session: GameSession, at point: SIMD2<Float>, seconds: Float,
    until condition: () -> Bool
  ) throws {
    for _ in 0..<Int(seconds / dt) {
      step(fight, session: session, at: point)
      if condition() { return }
    }
    let actor = fight.hostiles["flanker"]
    try #require(
      condition(),
      """
      The fixture did not reach its real tactical state: \
      phase=\(String(describing: actor?.phase)), \
      position=\(String(describing: actor?.position)), \
      targetable=\(String(describing: actor?.isTargetable)), \
      everMoved=\(fight.movedEnemies), warning=\(fight.arenaWarnings), \
      threat=\(String(describing: fight.threat)), hits=\(session.hitsTaken), \
      cover=\(String(describing: fight.coverStates[.miki]))
      """)
  }

  private func settle(_ fight: FightSimulation, session: GameSession, at point: SIMD2<Float>) throws
  {
    var previous = try #require(fight.hostiles["flanker"]?.position)
    var moved = false
    try advance(fight, session: session, at: point, seconds: 20) {
      let actor = fight.hostiles["flanker"]
      let current = actor?.position ?? previous
      let moving = simd_distance_squared(current, previous) > 0.0000001
      previous = current
      moved = moved || moving
      return moved && actor?.isTargetable == true && !moving
        && actor?.phase != .waiting
    }
  }

  private func waitForMove(
    _ fight: FightSimulation, session: GameSession, at point: SIMD2<Float>
  ) throws {
    var previous = try #require(fight.hostiles["flanker"]?.position)
    try advance(fight, session: session, at: point, seconds: 3) {
      let current = fight.hostiles["flanker"]?.position ?? previous
      defer { previous = current }
      return simd_distance_squared(current, previous) > 0.0000001
    }
  }

  private func step(_ fight: FightSimulation, session: GameSession, at point: SIMD2<Float>) {
    _ = fight.step(
      dt: dt, leader: point, facing: [0, -1], aiming: false, fireHeld: false,
      firePressed: false, mayDisrupt: false, signaturePressed: false,
      figures: [.miki: point], session: session)
  }

  private func update(_ world: GameWorld) {
    let mode = world.session.mode
    world.update(
      with: world.controls.resolve(InputRules.Raw(), mode: mode), sampledIn: mode,
      deltaTime: 1 / 60)
  }

  private func count(_ entity: Entity) -> Int {
    1 + entity.children.reduce(0) { $0 + count($1) }
  }
}
