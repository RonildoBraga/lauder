import Testing
import simd

@testable import Lauder

/// A press of the right stick locks the aim on a hostile (ADR 0020).
@MainActor
struct LockOnTests {
  private let up = SIMD2<Float>(0, -1)
  private let right = SIMD2<Float>(1, 0)
  private let leader = SIMD2<Float>(0, 8)

  // MARK: - Whom a press takes

  /// The first press takes the hostile Fire would: the nearest ahead in sight, or else the
  /// nearest. Each press after it goes round clockwise, as the screen shows the ground.
  @Test
  func aLockTakesWhomFireWouldThenGoesRoundClockwise() {
    let candidates = [
      Targeting.Candidate(id: "left", position: [-5, 8]),
      Targeting.Candidate(id: "ahead", position: [0, 0]),
      Targeting.Candidate(id: "right", position: [6, 8]),
      Targeting.Candidate(id: "behind", position: [0, 12]),
    ]
    let clear: (SIMD2<Float>, SIMD2<Float>) -> Bool = { _, _ in true }
    #expect(
      Targeting.firstLock(from: leader, facing: up, candidates: candidates, isClear: clear)
        == "ahead", "the nearer ones to the sides are not ahead")
    #expect(
      Targeting.firstLock(
        from: leader, facing: up, candidates: candidates, isClear: { _, _ in false })
        == "behind", "with nobody in sight, the nearest")
    var order: [String] = []
    var current = "ahead"
    for _ in 0..<4 {
      current =
        Targeting.nextLock(
          after: current, around: leader, candidates: candidates, up: up, right: right) ?? "none"
      order.append(current)
    }
    #expect(order == ["right", "behind", "left", "ahead"])
    let alone = [Targeting.Candidate(id: "ahead", position: [0, 0])]
    #expect(
      Targeting.nextLock(after: "ahead", around: leader, candidates: alone, up: up, right: right)
        == "ahead", "with nobody else, the lock stays")
    #expect(
      Targeting.nextLock(after: "gone", around: leader, candidates: alone, up: up, right: right)
        == nil)
  }

  /// A locked shot takes the locked hostile in reach and in sight, even with someone nearer
  /// ahead; out of sight, it flies the way the leader faces.
  @Test
  func aLockedShotTakesTheLockedHostile() {
    let near = Aim.Hostile(id: "near", position: [0, -3], isTarget: true)
    let far = Aim.Hostile(id: "far", position: [8, 0], isTarget: true)
    let shot = Aim.shot(
      from: .zero, aim: nil, locked: "far", facing: [0, -1], range: 14, hostiles: [near, far],
      blockers: [])
    #expect(shot?.strike == .body("far"))
    let wall = PartyMotion.Box(minimum: [3, -1], maximum: [4, 1])
    let blocked = Aim.shot(
      from: .zero, aim: nil, locked: "far", facing: [1, 0], range: 14, hostiles: [near, far],
      blockers: [wall])
    #expect(blocked?.strike == .scenery)
  }

  // MARK: - In the fight

  /// One press locks, a second soon after lets go, and one after the release time moves the
  /// lock on. A lock lets go of a hostile who is out of reach.
  @Test
  func aQuickSecondPressLetsGoAndASlowOneMovesOn() throws {
    let level = range()
    let session = GameSession(level: level)
    let fight = EncounterSimulation(level: level)
    let encounter = try #require(level.encounters.first)
    #expect(session.beginEncounter(encounter.beat))
    fight.begin(encounter)
    step(fight, session: session)
    fight.pressLock(from: leader, facing: up, up: up, right: right)
    #expect(fight.lock == "ahead")
    step(fight, session: session, for: 0.1)
    fight.pressLock(from: leader, facing: up, up: up, right: right)
    #expect(fight.lock == nil, "a quick second press lets go")
    step(fight, session: session, for: 0.5)
    fight.pressLock(from: leader, facing: up, up: up, right: right)
    #expect(fight.lock == "ahead")
    step(fight, session: session, for: 0.5)
    fight.pressLock(from: leader, facing: up, up: up, right: right)
    #expect(fight.lock == "right")
    #expect(fight.lockPoint == fight.hostiles["right"]?.position)
    step(fight, session: session, at: [0, 60])
    #expect(fight.lock == nil, "more than 30 m away, the lock lets go")
  }

  /// The lock aims for the player: whatever the stick says, the leader turns to the locked
  /// hostile and Fire takes them, not the one ahead. Once they are down the lock lets go and
  /// the stick aims again.
  @Test
  func theLeaderTurnsToTheLockedHostileAndFireTakesThem() {
    let world = GameWorld(level: range(hits: 1))
    // The fight begins, and its cues bring the guards out.
    for _ in 0..<3 { world.advanceParty(movement: .zero, deltaTime: 1 / 60) }
    world.advanceParty(movement: .zero, lockPressed: true, deltaTime: 1 / 60)
    #expect(world.lockedHostile == "ahead")
    for _ in 0..<30 { world.advanceParty(movement: .zero, deltaTime: 1 / 60) }
    world.advanceParty(movement: .zero, lockPressed: true, deltaTime: 1 / 60)
    #expect(world.lockedHostile == "right")
    let aimLeft = stick(world, towards: [-1, 0])
    for frame in 0..<300 where !world.session.defeated.contains("right") {
      world.advanceParty(
        movement: .zero, aim: aimLeft, fireHeld: true, firePressed: frame == 0, deltaTime: 1 / 60)
    }
    #expect(world.session.defeated == ["right"])
    #expect(world.lockedHostile == nil, "a lock on a hostile who is down lets go")
    for _ in 0..<120 { world.advanceParty(movement: .zero, aim: aimLeft, deltaTime: 1 / 60) }
    #expect(simd_dot(world.facing(of: .miki), [-1, 0]) > 0.99, "the stick aims again")
  }

  /// A red ring circles the locked hostile, wide enough to clear a guard's legs, and goes when
  /// the lock lets go.
  @Test
  func aRedRingCirclesTheLockedHostile() throws {
    let world = GameWorld(level: range())
    for _ in 0..<3 { world.advanceParty(movement: .zero, deltaTime: 1 / 60) }
    let ring = try #require(world.root.findEntity(named: "combat.lock"))
    #expect(!ring.isEnabled)
    world.advanceParty(movement: .zero, lockPressed: true, deltaTime: 1 / 60)
    #expect(world.lockedHostile == "ahead")
    #expect(ring.isEnabled && ring.isEnabledInHierarchy)
    let guardBody = try #require(world.root.findEntity(named: "hostile.ahead"))
    let centre = ring.position(relativeTo: nil)
    let body = guardBody.position(relativeTo: nil)
    #expect(simd_distance(SIMD2(centre.x, centre.z), SIMD2(body.x, body.z)) < 0.01)
    // Above the towers' baked shadows, 3 cm over the snow, and below the ring's own height.
    #expect(centre.y - 0.01 > 0.03 && centre.y < 0.1)
    let radius = SceneStyle.lockRingRadius * ring.scale.x
    #expect(radius > RobotModelGeometry.navigationRadius)
    world.releaseLock()
    world.advanceParty(movement: .zero, deltaTime: 1 / 60)
    #expect(!ring.isEnabled)
  }

  /// Restart forgets the lock.
  @Test
  func restartForgetsTheLock() {
    let world = GameWorld(level: range())
    for _ in 0..<3 { world.advanceParty(movement: .zero, deltaTime: 1 / 60) }
    world.advanceParty(movement: .zero, lockPressed: true, deltaTime: 1 / 60)
    #expect(world.lockedHostile == "ahead")
    world.restart()
    #expect(world.lockedHostile == nil)
  }

  private func step(
    _ fight: EncounterSimulation, session: GameSession, for seconds: Float = 1 / 120,
    at position: SIMD2<Float>? = nil
  ) {
    let at = position ?? leader
    for _ in 0..<max(1, Int((seconds * 120).rounded())) {
      _ = fight.step(
        dt: 1 / 120, leader: at, facing: up, aiming: false, fireHeld: false, firePressed: false,
        figures: [.miki: at], session: session)
    }
  }

  /// Three armed guards beyond their sight of the leader at the start: ahead, to the right
  /// and to the left.
  private func range(hits: Int = 50) -> Level {
    let points: [(String, SIMD2<Float>)] = [
      ("ahead", [0, -12]), ("right", [21, 8]), ("left", [-20, 8]),
    ]
    let robots = points.map { id, point in
      Level.Hostile(
        id: id, name: id, hiddenAt: point, standAt: point, hits: hits, attack: .robot, range: 12)
    }
    let cues: [(at: Float, cue: Level.Cue)] = robots.flatMap {
      [(at: 0, cue: .reveal($0.id)), (at: 0, cue: .engage($0.id))]
    }
    let encounter = Level.Encounter(
      beat: .stranger, start: .area(PartyMotion.Box(minimum: [-30, -30], maximum: [30, 30])),
      retryAt: leader, hostiles: robots, cues: cues)
    return Level(
      id: "lock-range", ground: .box("ground", at: [0, -0.15, 0], size: [80, 0.3, 80]), boxes: [],
      interactions: [], triggers: [], encounters: [encounter], startingAmmo: 60, party: [.miki],
      spawns: [.miki: leader, .tom: [-1, 9], .laura: [1, 9]], heading: [0, -1],
      cameraOffset: BrooklynBridge.cameraOffset,
      fieldOfView: 22, opening: "A range.", objective: "Test.", lookAround: "Snow.",
      restartNote: "Restart.")
  }
}
