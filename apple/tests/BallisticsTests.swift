import Testing
import simd

@testable import Lauder

/// Aiming assistance cannot override a real wall, elevation or the body's vertical extent.
@MainActor
struct BallisticsTests {
  @Test
  func aWallExactlyAtTheEndOfReachStillGetsTheImpact() {
    let wall = Level.Box(name: "limit", position: [0, 1.5, -0.5], size: [4, 3, 1])
    let ballistics = Ballistics(level: yard(boxes: [wall]))
    let shot = ballistics.trace(
      from: [0, 1.25, 5], direction: [0, 0, -1], range: 5, targets: [])
    #expect(shot.strike == .scenery)
    #expect(shot.end == [0, 1.25, 0])
  }

  @Test
  func invalidDirectionsCannotCreateANonfiniteTrace() {
    let ballistics = Ballistics(level: yard())
    let start: SIMD3<Float> = [0, 1.25, 5]
    for direction: SIMD3<Float> in [.zero, [.nan, 0, 0], [.infinity, 0, 0], [0, -.infinity, 0]] {
      let shot = ballistics.trace(from: start, direction: direction, range: 15, targets: [])
      #expect(shot.start == start && shot.end == start && shot.strike == .nothing)
    }
  }

  @Test
  func anElevatedShotPassesOverLowCoverAndHitsTheLowerBody() {
    let terrain = Terrain(patches: [
      .flat(minimum: [-3, 4], maximum: [3, 10], height: 2)
    ])
    let wall = Level.Box(name: "low", position: [0, 0.55, 0], size: [4, 1.1, 1])
    let ballistics = Ballistics(level: yard(terrain: terrain, boxes: [wall]))
    let start = ballistics.point([0, 7])
    let destination = ballistics.point([0, -7])
    let shot = ballistics.trace(
      from: start, direction: destination - start, range: 20,
      targets: [.init(id: "lower", centre: destination)])
    #expect(start.y == 3.25 && destination.y == 1.25)
    #expect(shot.strike == .body("lower"))
    #expect(shot.end.y > 1.25 && shot.end.y < 1.85)
  }

  @Test
  func risingGroundStopsAnUpwardShotBeforeItsAssistedTarget() {
    let terrain = Terrain(patches: [
      .flat(minimum: [-3, -10], maximum: [3, 1], height: 2)
    ])
    let ballistics = Ballistics(level: yard(terrain: terrain))
    let start = ballistics.point([0, 5])
    let destination = ballistics.point([0, -7])
    #expect(!ballistics.isClear(from: start, to: destination))
    let shot = ballistics.trace(
      from: start, direction: destination - start, range: 20,
      targets: [.init(id: "upper", centre: destination)])
    #expect(shot.strike == .scenery)
    #expect(abs(shot.end.z - 1) < 0.001)
    #expect(shot.end.y < 2)
  }

  @Test
  func aTallBlockStillStopsAnElevatedShot() {
    let wall = Level.Box(name: "tall", position: [0, 2, 0], size: [4, 4, 1])
    let ballistics = Ballistics(level: yard(boxes: [wall]))
    let start: SIMD3<Float> = [0, 3.25, 7]
    let destination: SIMD3<Float> = [0, 1.25, -7]
    let shot = ballistics.trace(
      from: start, direction: destination - start, range: 20,
      targets: [.init(id: "behind", centre: destination)])
    #expect(shot.strike == .scenery)
    #expect(abs(shot.end.z - 0.5) < 0.001)
  }

  @Test(arguments: [Float(0.1), 2.5, 3.5])
  func aGroundPlaneCrossingCannotHitAboveOrBelowTheActualCylinder(height: Float) {
    let ballistics = Ballistics(level: yard())
    let shot = ballistics.trace(
      from: [0, height, 5], direction: [0, 0, -1], range: 15,
      targets: [.init(id: "body", centre: [0, 1.25, -5])])
    #expect(shot.strike == .nothing)
    #expect(shot.end.z == -10)
  }

  @Test
  func aShotCrossingTheBodyAtItsHeightUsesTheCircularRadius() {
    let ballistics = Ballistics(level: yard())
    let target = Ballistics.Target(id: "body", centre: [0, 1.25, -5])
    let hit = ballistics.trace(
      from: [0, 1.25, 5], direction: [0, 0, -1], range: 15, targets: [target])
    #expect(hit.strike == .body("body"))
    #expect(abs(hit.end.z - (-5 + target.radius)) < 0.001)
    let miss = ballistics.trace(
      from: [target.radius + 0.01, 1.25, 5], direction: [0, 0, -1], range: 15,
      targets: [target])
    #expect(miss.strike == .nothing)
  }

  @Test
  func coverAndOpenGroundUseElevatedSightsInsteadOfInfiniteFootprints() {
    let terrain = Terrain(patches: [
      .flat(minimum: [-3, 4], maximum: [3, 10], height: 2)
    ])
    let wall = Level.Box(name: "low", position: [0, 0.55, 0], size: [4, 1.1, 1])
    let level = yard(terrain: terrain, boxes: [wall])
    let threats = [CoverPlanner.Threat(position: [0, 7], range: 20)]
    let ballistics = Ballistics(level: level)
    let memo = SightMemo()
    memo.prepare(for: threats)
    let ground = OpenGround(
      threats: threats, obstacles: level.obstacles, ballistics: ballistics, memo: memo)
    #expect(ground.isSeen([0, -7]))
    #expect(ground.extraCost(at: [0, -7]) == OpenGround.extraCost)
    #expect(
      CoverPlanner.target(
        from: [0, -7], threats: threats, weaponRange: 20, obstacles: level.obstacles,
        ballistics: ballistics) == [0, 7])
    // The old 2D sight would incorrectly regard this low wall and cliff as full-height cover.
    #expect(!LineOfSight.isClear(from: [0, 7], to: [0, -7], obstacles: level.obstacles))
  }

  @Test
  func aGuardEvaluatesAFreshCompanionsLowShelterBeforeDetectingThem() {
    let wall = Level.Box(name: "shelter", position: [0, 0.55, 0], size: [4, 1.1, 1])
    let guardSpec = Level.Hostile(
      id: "guard", name: "Guard", hiddenAt: [0, -5], standAt: [0, -5], hits: 4,
      windUp: 1, recovery: 2, range: 14, inView: true, targetsAnyone: true,
      targetFromWindUp: true)
    let encounter = Level.Encounter(
      beat: .stranger, start: .area(TestYard.ground.footprint), retryAt: .zero,
      hostiles: [guardSpec], cues: [], guardArea: TestYard.ground.footprint)
    let level = Level(
      id: "guard-shelter-test", ground: TestYard.ground, boxes: [wall], interactions: [],
      triggers: [], encounters: [encounter], party: [.miki, .laura],
      spawns: [.miki: [-6, 3], .laura: [0, 1.2]], heading: [0, -1],
      cameraOffset: [0, 10, 10], fieldOfView: 42, opening: "A yard.", objective: "Explore.",
      lookAround: "Ground.", restartNote: "Restart.", combat: .init(leaderCover: true))
    let fight = FightSimulation(level: level)
    // No encounter step has prepared Laura's stance. Detection must use the local fresh
    // shelter evaluation, rather than a missing or stale stance from an earlier fight.
    #expect(!fight.notices(encounter, party: [.laura: [0, 1.2]]))
    #expect(fight.notices(encounter, party: [.laura: [5, 1.2]]))
  }

  @Test
  func grenadesTravelBetweenTheirActualLaunchAndLandingFloors() {
    var grenade = Grenade(
      id: 1, owner: "upper", from: [0, 7], at: [0, -7], startHeight: 2.4,
      landingHeight: -1.8)
    #expect(abs(grenade.projectilePosition.y - (2.4 + Grenade.launchHeight)) < 0.0001)
    _ = grenade.advance(dt: Grenade.flightTime)
    #expect(abs(grenade.projectilePosition.y - (-1.8 + Grenade.landingHeight)) < 0.0001)
    #expect(grenade.remaining > 0)
  }

  @Test(arguments: [Float(1.5), 3])
  func aBlastCannotHitThroughARiserOrAcrossAnOutOfReachTier(height: Float) throws {
    let terrain = Terrain(patches: [
      .flat(minimum: [0.7, -3], maximum: [5, 3], height: height)
    ])
    let thrower = Level.Hostile(
      id: "thrower", name: "Thrower", hiddenAt: [0, -5], standAt: [0, -5], hits: 50,
      attack: .throwGrenade, windUp: 0.1, recovery: 60, range: 14, inView: true,
      targetFromWindUp: true)
    let encounter = Level.Encounter(
      beat: .stranger, start: .area(TestYard.ground.footprint), retryAt: .zero,
      hostiles: [thrower], cues: [(0, .engage(thrower.id))])
    let level = Level(
      id: "tier-blast-test", ground: TestYard.ground, terrain: terrain, boxes: [],
      interactions: [], triggers: [], encounters: [encounter], party: [.miki],
      spawns: [.miki: .zero], heading: [0, -1], cameraOffset: [0, 10, 10], fieldOfView: 42,
      opening: "A yard.", objective: "Explore.", lookAround: "Ground.", restartNote: "Restart.")
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    try #require(session.beginEncounter(encounter.beat))
    fight.begin(encounter)
    func step(at point: SIMD2<Float>) {
      _ = fight.step(
        dt: 1 / 120, leader: point, facing: [0, -1], aiming: false, fireHeld: false,
        firePressed: false, mayDisrupt: false, signaturePressed: false,
        figures: [.miki: point], session: session)
    }
    for _ in 0..<120 {
      step(at: .zero)
      if !fight.grenades.isEmpty { break }
    }
    let grenade = try #require(fight.grenades.first)
    #expect(grenade.position == .zero)
    // Still within the painted horizontal radius, but now on a distinct actual floor.
    #expect(grenade.contains([1.2, 0]))
    for _ in 0..<360 {
      step(at: [1.2, 0])
      if fight.grenadesExploded > 0 { break }
    }
    #expect(fight.grenadesExploded == 1)
    #expect(session.hitsTaken == 0)
  }

  private func yard(terrain: Terrain = Terrain(), boxes: [Level.Box] = []) -> Level {
    Level(
      id: "ballistics-test", ground: TestYard.ground, terrain: terrain, boxes: boxes,
      interactions: [], triggers: [], party: [.miki],
      spawns: [.miki: .zero, .laura: [-1, 1], .tom: [1, 1]], heading: [0, -1],
      cameraOffset: [0, 10, 10], fieldOfView: 42, opening: "A yard.", objective: "Explore.",
      lookAround: "Ground.", restartNote: "Restart.")
  }
}
