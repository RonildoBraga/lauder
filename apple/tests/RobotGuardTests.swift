import Testing
import simd

@testable import Lauder

@MainActor
struct RobotGuardTests {
  private let dt: Float = 1 / 120

  @Test
  func revealStartsPlantedAndPatrolRespectsTheWholeFootprint() {
    var guardBot = RobotGuard(home: .zero)
    #expect(!guardBot.isVisible)
    guardBot.reveal()
    guardBot.engage()
    #expect(guardBot.position == .zero && guardBot.isTargetable)
    let wall = PartyMotion.Box(minimum: [3.2, -4], maximum: [4, 2])
    var travelled: Float = 0
    for _ in 0..<12_000 {
      let previous = guardBot.position
      #expect(
        guardBot.step(dt: dt, target: [100, 100], hasSight: false, obstacles: [wall], party: [])
          == nil)
      let moved = simd_distance(previous, guardBot.position)
      travelled += moved
      #expect(moved <= RobotGuard.speed * dt + 0.00001)
      #expect(guardBot.guardArea.contains(guardBot.position))
      let nearest = simd_min(wall.maximum, simd_max(wall.minimum, guardBot.position))
      #expect(simd_distance(guardBot.position, nearest) >= RobotModelGeometry.navigationRadius)
    }
    #expect(travelled > 2)
  }

  @Test
  func aCommittedBurstAlternatesBarrelsAndDoesNotFollowTheMovingTarget() throws {
    var robot = readyRobot()
    let point = SIMD2<Float>(0, 8)
    for _ in 0..<300 {
      _ = robot.step(dt: dt, target: point, hasSight: true, obstacles: [], party: [])
      if robot.phase == .committed { break }
    }
    #expect(robot.phase == .committed && robot.committedPoint == point)
    let yaw = robot.facing
    var shots: [RobotGuard.Discharge] = []
    for _ in 0..<150 {
      if let shot = robot.step(dt: dt, target: [8, 0], hasSight: false, obstacles: [], party: []) {
        shots.append(shot)
        #expect(simd_distance(shot.origin, robot.muzzle(gun: shot.gun)) < 0.00001)
        // Every gun aims at the old point, including vertical pitch, not the current actor.
        let target = SIMD3(point.x, Float(1.25), point.y)
        let desired = simd_normalize(target - shot.origin)
        #expect(simd_distance(desired, shot.direction) < 0.00001)
      }
    }
    #expect(shots.map(\.gun) == [0, 1, 0])
    #expect(shots.allSatisfy { $0.burst == 1 })
    #expect(robot.facing == yaw && robot.phase == .recovering)
  }

  @Test
  func losingSightBeforeCommitRequiresAFreshWarningAndDoesNotBankAShot() {
    var robot = readyRobot()
    for _ in 0..<150 {
      _ = robot.step(dt: dt, target: [0, 8], hasSight: true, obstacles: [], party: [])
    }
    #expect(robot.phase == .tracking)
    for _ in 0..<30 {
      #expect(robot.step(dt: dt, target: [0, 8], hasSight: false, obstacles: [], party: []) == nil)
    }
    #expect(robot.phase == .searching && robot.shotSerial == 0)
    // Give sight again. A full notice, track and commitment still precede any discharge.
    for _ in 0..<120 {
      #expect(robot.step(dt: dt, target: [0, 8], hasSight: true, obstacles: [], party: []) == nil)
    }
    #expect(robot.shotSerial == 0)
  }

  @Test
  func theMachineDoesNotAcquireBehindItsConeOrAcrossTheMap() {
    for target: SIMD2<Float> in [[0, -8], [0, 15]] {
      var robot = readyRobot()
      for _ in 0..<60 {
        _ = robot.step(dt: dt, target: target, hasSight: true, obstacles: [], party: [])
      }
      #expect(robot.phase == .patrol && robot.shotSerial == 0)
    }
  }

  @Test
  func aLaterPatrolLegFacesTheEntranceAndReacquiresAStationaryTraveller() {
    var robot = readyRobot()
    // Let it turn away and start the eastbound leg before the traveller returns from cover.
    for _ in 0..<1_200 {
      _ = robot.step(dt: dt, target: [2.1, 6.4], hasSight: false, obstacles: [], party: [])
    }
    #expect(robot.phase == .patrol)
    var acquired = false
    var fired = false
    for _ in 0..<4_800 {
      let shot = robot.step(dt: dt, target: [2.1, 6.4], hasSight: true, obstacles: [], party: [])
      acquired = acquired || robot.phase == .notice || robot.phase == .tracking
      if shot != nil {
        fired = true
        break
      }
    }
    #expect(acquired && fired)
  }

  @Test
  func anObservedTravellerBeyondFiringRangeCausesARealBoundedPursuit() {
    let level = BrooklynBridge.level
    var robot = RobotGuard(home: BrooklynBridge.stranger.standAt)
    robot.reveal()
    robot.engage()
    let start = robot.position
    let target = SIMD2<Float>(6.5, 17)
    let ballistics = Ballistics(level: level)
    let mover = PartyMotion(radius: RobotModelGeometry.navigationRadius, obstacles: level.obstacles)
    var pursued = false
    var fired = false
    for _ in 0..<1_800 {
      let before = robot.position
      let sight = ballistics.isClear(
        from: ballistics.point(robot.position, above: 1.52), to: ballistics.point(target))
      let shot = robot.step(
        dt: dt, target: target, hasSight: sight, obstacles: level.obstacles, party: [target],
        coverBoxes: level.boxes)
      pursued = pursued || robot.phase == .pursuing
      fired = fired || shot != nil
      #expect(robot.guardArea.contains(robot.position))
      #expect(mover.canTraverse(from: before, to: robot.position))
    }
    #expect(pursued && fired)
    #expect(simd_distance(start, robot.position) > 2)
    #expect(simd_distance(robot.position, target) < simd_distance(start, target))
  }

  @Test
  func losingSightNeverUpdatesTheRememberedPointFromTheUnseenActor() {
    var first = readyRobot()
    for _ in 0..<120 {
      _ = first.step(dt: dt, target: [0, 13], hasSight: true, obstacles: [], party: [])
    }
    var second = first
    let remembered = first.lastKnownPosition
    #expect(remembered == [0, 13] && first.phase == .pursuing)
    for _ in 0..<1_200 {
      #expect(
        first.step(dt: dt, target: [100, 100], hasSight: false, obstacles: [], party: []) == nil)
      #expect(
        second.step(dt: dt, target: [-100, -100], hasSight: false, obstacles: [], party: []) == nil)
      #expect(first.position == second.position && first.facing == second.facing)
      #expect(first.lastKnownPosition == second.lastKnownPosition)
    }
    #expect(first.phase == .patrol && first.lastKnownPosition == nil)
  }

  @Test
  func reacquiringBeyondFiringRangeContinuesPursuitWithoutAnotherWarningTurn() {
    var robot = readyRobot()
    _ = robot.step(dt: dt, target: [0, 13], hasSight: true, obstacles: [], party: [])
    #expect(robot.phase == .pursuing)
    _ = robot.step(dt: dt, target: [0, 13], hasSight: false, obstacles: [], party: [])
    #expect(robot.phase == .searching)
    _ = robot.step(dt: dt, target: [0, 13], hasSight: true, obstacles: [], party: [])
    #expect(robot.phase == .pursuing)
    #expect(robot.shotSerial == 0)
  }

  @Test
  func anEngagedGuardRetainsRealSightWhileTurningButCannotTrackThroughAWall() {
    var robot = readyRobot()
    _ = robot.step(dt: dt, target: [0, 13], hasSight: true, obstacles: [], party: [])
    _ = robot.step(dt: dt, target: [13, 0], hasSight: true, obstacles: [], party: [])
    #expect(robot.lastKnownPosition == [13, 0] && robot.phase == .pursuing)
    _ = robot.step(dt: dt, target: [0, -13], hasSight: false, obstacles: [], party: [])
    #expect(robot.lastKnownPosition == [13, 0] && robot.phase == .searching)
    #expect(robot.shotSerial == 0)
  }

  @Test
  func bridgeCoverHidesTheTallBodyAndHasAReachableExposedPeek() throws {
    let level = BrooklynBridge.level
    let robot = RobotGuard(home: BrooklynBridge.stranger.standAt)
    let target = SIMD2<Float>(6.5, 16)
    let tactics = RobotTactics(
      area: robot.guardArea, obstacles: level.obstacles, boxes: level.boxes)
    let cover = try #require(tactics.cover(from: robot.position, against: target))
    let mover = PartyMotion(radius: RobotModelGeometry.navigationRadius, obstacles: level.obstacles)
    var previous = robot.position
    for next in cover.route {
      #expect(mover.canTraverse(from: previous, to: next))
      previous = next
    }
    #expect(previous == cover.position && tactics.isCovered(previous, against: target))
    #expect(tactics.route(from: previous, to: cover.peek) != nil)
    #expect(simd_distance(cover.peek, target) <= RobotGuard.detectionRange)
    let rays = Ballistics(level: level)
    let direction = simd_normalize(target - cover.position)
    let side = SIMD2(-direction.y, direction.x) * RobotModelGeometry.bodyRadius
    for point in [cover.position, cover.position + side, cover.position - side] {
      #expect(
        !rays.isClear(
          from: rays.point(target),
          to: rays.point(point, above: 2 * RobotModelGeometry.halfHeight + 0.1)))
    }
    #expect(rays.isClear(from: rays.point(cover.peek, above: 1.52), to: rays.point(target)))
  }

  @Test
  func damageMakesTheGuardRetreatHoldAndPeekBeforeAFreshWarning() throws {
    let level = BrooklynBridge.level
    var robot = RobotGuard(home: BrooklynBridge.stranger.standAt)
    robot.reveal()
    robot.engage()
    let target = SIMD2<Float>(6.5, 16)
    let rays = Ballistics(level: level)
    _ = robot.step(
      dt: dt, target: target, hasSight: true, obstacles: level.obstacles, party: [target],
      coverBoxes: level.boxes)
    robot.notifyHit()
    var phases: [RobotGuard.Phase] = []
    for _ in 0..<4_800 {
      let sight = rays.isClear(
        from: rays.point(robot.position, above: 1.52), to: rays.point(target))
      let shot = robot.step(
        dt: dt, target: target, hasSight: sight, obstacles: level.obstacles, party: [target],
        coverBoxes: level.boxes)
      if phases.last != robot.phase { phases.append(robot.phase) }
      if [.takingCover, .covered, .peeking].contains(robot.phase) {
        #expect(shot == nil)
        robot.notifyHit()
        #expect(!robot.coverRequested)
      }
      if phases.contains(.peeking), robot.phase == .notice { break }
    }
    #expect(phases.prefix(3).elementsEqual([.takingCover, .covered, .peeking]))
    #expect(robot.phase == .notice && robot.shotSerial == 0)
    #expect(robot.coverGoal == nil && robot.elapsed < 0.01)
    for _ in 0..<120 {
      #expect(
        robot.step(
          dt: dt, target: target, hasSight: true, obstacles: level.obstacles, party: [target],
          coverBoxes: level.boxes) == nil)
    }
  }

  @Test
  func damageAfterPursuitStillHasReachableCoverAndAFiniteReengagement() throws {
    let level = BrooklynBridge.level
    let target = SIMD2<Float>(6.5, 17)
    var robot = RobotGuard(home: BrooklynBridge.stranger.standAt)
    let tactics = RobotTactics(
      area: robot.guardArea, obstacles: level.obstacles, boxes: level.boxes)
    let cover = try #require(
      tactics.cover(from: [5.106764, 8.109933], against: target))
    #expect(tactics.isCovered(cover.position, against: target))
    #expect(simd_distance(cover.peek, target) <= RobotGuard.detectionRange)
    robot.reveal()
    robot.engage()
    let rays = Ballistics(level: level)
    for _ in 0..<2_400 {
      _ = robot.step(
        dt: dt, target: target, hasSight: true, obstacles: level.obstacles, party: [target],
        coverBoxes: level.boxes)
      if robot.phase == .notice { break }
    }
    #expect(robot.phase == .notice && simd_distance(robot.position, robot.home) > 2)
    robot.notifyHit()
    var covered = false
    var peeked = false
    for _ in 0..<7_200 {
      let sight = rays.isClear(
        from: rays.point(robot.position, above: 1.52), to: rays.point(target))
      _ = robot.step(
        dt: dt, target: target, hasSight: sight, obstacles: level.obstacles, party: [target],
        coverBoxes: level.boxes)
      covered = covered || robot.phase == .covered
      peeked = peeked || robot.phase == .peeking
      if peeked, robot.phase == .notice { break }
    }
    #expect(covered && peeked && robot.phase == .notice)
    #expect(robot.shotSerial == 0)
  }

  @Test
  func aCoverRequestCannotCancelOrRetargetACommittedBurst() {
    let level = BrooklynBridge.level
    var robot = RobotGuard(home: BrooklynBridge.stranger.standAt)
    robot.reveal()
    robot.engage()
    let target = SIMD2<Float>(6.5, 10)
    for _ in 0..<600 {
      _ = robot.step(
        dt: dt, target: target, hasSight: true, obstacles: level.obstacles, party: [],
        coverBoxes: level.boxes)
      if robot.phase == .committed { break }
    }
    #expect(robot.phase == .committed)
    let committed = robot.committedPoint
    robot.notifyHit()
    var shots: [RobotGuard.Discharge] = []
    for _ in 0..<180 {
      if let shot = robot.step(
        dt: dt, target: [8, 9], hasSight: false, obstacles: level.obstacles, party: [],
        coverBoxes: level.boxes)
      {
        shots.append(shot)
        #expect(robot.committedPoint == committed)
      }
      if robot.phase == .takingCover { break }
    }
    #expect(shots.map(\.gun) == [0, 1, 0])
    #expect(robot.phase == .takingCover)
  }

  @Test
  func lowCoverAndCoverWithoutAnyReachablePeekAreRejected() {
    let area = PartyMotion.Box(minimum: [-4, -4], maximum: [4, 4])
    let low = Level.Box(name: "low", position: [0, 0.5, 1], size: [4, 1, 1])
    let lowTactics = RobotTactics(area: area, obstacles: [low.footprint], boxes: [low])
    #expect(lowTactics.cover(from: [0, -3], against: [0, 4]) == nil)
    let wall = Level.Box(name: "sealed", position: [0, 4, 0], size: [0.6, 8, 16])
    let sealed = RobotTactics(area: area, obstacles: [wall.footprint], boxes: [wall])
    #expect(sealed.cover(from: [-3, 0], against: [3, 0]) == nil)
    #expect(sealed.route(from: [-3, 0], to: [3, 0]) == nil)
  }

  @Test
  func attackInitiationRangeStaysVisibleWhileCameraBLeansAndNarrows() throws {
    // The guard's 12 m acquisition-for-fire radius is shorter than the visible area after
    // the ordinary encounter lean. Check its complete perimeter during the lens transition,
    // including the near/south edge where an unleaned tight lens would crop the guard.
    for aspect: Float in [1.5, 2.16] {
      for heading in 0..<72 {
        let angle = Float(heading) * 2 * .pi / 72
        let direction = SIMD2(cos(angle), sin(angle))
        let point = direction * RobotGuard.attackRange
        var camera = CameraRig(
          offset: BrooklynBridge.cameraOffset, fieldOfView: BrooklynBridge.level.fieldOfView,
          over: .zero)
        for _ in 0..<240 {
          camera.update(
            over: .zero, lean: direction * EncounterSimulation.cameraLeanLimit,
            close: true, deltaTime: dt)
          let screen = try #require(camera.projection(aspect: aspect).screen(ofGround: point))
          #expect(screen.x >= 0 && screen.x <= 1 && screen.y >= 0 && screen.y <= 1)
        }
      }
    }
  }

  @Test
  func repeatedShellHitsDoNotResetTheAttackWarning() throws {
    var state = HostileState(
      spec: Level.Hostile(
        id: "robot", name: "Guard", hiddenAt: .zero, standAt: .zero, hits: 6, attack: .robot,
        range: 12))
    state.reveal()
    state.engage()
    for _ in 0..<120 {
      _ = state.stepRobot(dt: dt, target: [0, 8], hasSight: true, obstacles: [], party: [])
    }
    let before = try #require(state.robot)
    for _ in 0..<20 { state.flinch() }
    #expect(state.robot?.phase == before.phase && state.robot?.elapsed == before.elapsed)
  }

  @Test
  func shutdownAndDisengagementCancelPendingRoundsAndRecoil() throws {
    for bypass in [false, true] {
      var robot = readyRobot()
      for _ in 0..<400 {
        if robot.step(dt: dt, target: [0, 8], hasSight: true, obstacles: [], party: []) != nil {
          break
        }
      }
      #expect(robot.shotSerial == 1)
      if bypass { robot.clear() } else { robot.knockDown() }
      for _ in 0..<1_200 {
        #expect(
          robot.step(dt: dt, target: [0, 8], hasSight: true, obstacles: [], party: []) == nil)
      }
      #expect(!robot.isTargetable && robot.gunRecoil == .zero && robot.shotSerial == 1)
      if bypass {
        #expect(robot.brace == 0)
        for direction in robot.gunDirections {
          #expect(simd_distance(direction, SIMD3(robot.facing.x, 0, robot.facing.y)) < 0.00001)
        }
      }
    }
  }

  @Test
  func threeHonestBarrelRaysCanCostAtMostOneHitAndPauseFreezesTheCycle() throws {
    let level = range()
    let session = GameSession(level: level)
    let fight = EncounterSimulation(level: level)
    #expect(session.beginEncounter(.stranger))
    fight.begin(try #require(level.encounters.first))
    var shots: [EncounterSimulation.Shot] = []
    for _ in 0..<400 {
      _ = step(fight, session: session)
      shots += fight.shots
      if shots.count == 1 { break }
    }
    #expect(shots.count == 1 && session.hitsTaken == 1)
    let before = try #require(fight.hostiles["robot"]?.robot)
    session.togglePause()
    for _ in 0..<120 { _ = step(fight, session: session) }
    let paused = try #require(fight.hostiles["robot"]?.robot)
    #expect(paused.shotSerial == before.shotSerial && paused.elapsed == before.elapsed)
    #expect(paused.position == before.position && paused.gunRecoil == before.gunRecoil)
    session.togglePause()
    for _ in 0..<120 {
      _ = step(fight, session: session)
      shots += fight.shots
    }
    #expect(shots.map(\.gun) == [0, 1, 0])
    #expect(shots.allSatisfy { $0.path.strike == .body("miki") })
    #expect(session.hitsTaken == 1)
  }

  @Test
  func coverCanBlockOneActualBarrelWhileTheOtherFires() throws {
    let pillar = Level.Box(name: "half-cover", position: [-0.7, 2, 3], size: [0.6, 4, 1])
    let level = range(boxes: [pillar])
    let session = GameSession(level: level)
    let fight = EncounterSimulation(level: level)
    #expect(session.beginEncounter(.stranger))
    fight.begin(try #require(level.encounters.first))
    var shots: [EncounterSimulation.Shot] = []
    for _ in 0..<500 {
      _ = step(fight, session: session)
      shots += fight.shots
      if shots.count == 3 { break }
    }
    #expect(shots.count == 3)
    #expect(shots[0].path.strike == .scenery)
    #expect(shots[1].path.strike == .body("miki"))
    #expect(shots[2].path.strike == .scenery)
    #expect(session.hitsTaken == 1)
  }

  @Test
  func retreatKeepsTheUnresolvedEncountersInjuriesRobotDamageAndSpentRounds() throws {
    let level = range()
    let session = GameSession(level: level)
    let fight = EncounterSimulation(level: level)
    #expect(session.beginEncounter(.stranger))
    fight.begin(try #require(level.encounters.first))
    for _ in 0..<400 {
      _ = step(fight, session: session)
      if session.hitsTaken == 1 { break }
    }
    #expect(session.hitsTaken == 1)
    #expect(session.spendRound())
    #expect(!session.hit("robot", toughness: 6))
    // Leave sight/range without taking the authored safe exit. The active encounter's
    // search and return to patrol must not restore either side's damage or ammunition.
    let retreatTicks = Int((RobotGuard.searchTime + RobotGuard.recoveryTime + 2) / dt)
    for _ in 0..<retreatTicks {
      _ = fight.step(
        dt: dt, leader: [0, 24], facing: [0, -1], aiming: false,
        fireHeld: false, firePressed: false, figures: [.miki: [0, 24]], session: session)
    }
    #expect(session.inEncounter && session.hitsTaken == 1 && session.ammo == 11)
    #expect(fight.hostiles["robot"]?.robot?.phase == .patrol)
    for _ in 0..<4 { #expect(!session.hit("robot", toughness: 6)) }
    #expect(session.hit("robot", toughness: 6))
  }

  @Test
  func aBypassEndsAuthorityWithoutInventingAKillAndRestartRestoresTheGuard() throws {
    let level = range()
    let session = GameSession(level: level)
    let fight = EncounterSimulation(level: level)
    #expect(session.beginEncounter(.stranger))
    fight.begin(try #require(level.encounters.first))
    for _ in 0..<400 {
      _ = step(fight, session: session)
      if session.hitsTaken == 1 { break }
    }
    #expect(session.hitsTaken == 1)
    #expect(session.spendRound())
    let ammo = session.ammo
    #expect(fight.resolveRobotBypass(id: "robot", session: session))
    #expect(!session.inEncounter && session.defeated.isEmpty && session.ammo == ammo)
    // Injuries are encounter-local: both victory and the completed safe bypass recover
    // them. Spent ammunition stays spent, and the bypass does not count as a robot kill.
    #expect(session.hitsTaken == 0)
    #expect(fight.hostiles["robot"]?.robot?.isCleared == true && fight.threat == nil)
    for _ in 0..<600 {
      _ = step(fight, session: session)
      #expect(fight.shots.isEmpty)
      #expect(session.hitsTaken == 0)
    }
    #expect(!fight.resolveRobotBypass(id: "robot", session: session))
    // A later empty scene must not lean back towards the old, cleared guard.
    fight.begin(
      Level.Encounter(
        beat: .arrived, start: .area(.init(minimum: [-10, -10], maximum: [10, 10])),
        retryAt: nil, hostiles: [], cues: []))
    #expect(fight.cameraLean(leader: [20, 0]) == .zero)
    fight.reset()
    #expect(fight.hostiles["robot"]?.robot?.phase == .hidden)
    #expect(fight.hostiles["robot"]?.robot?.shotSerial == 0)
  }

  private func readyRobot() -> RobotGuard {
    var robot = RobotGuard(home: .zero)
    robot.reveal()
    robot.engage()
    return robot
  }

  private func step(_ fight: EncounterSimulation, session: GameSession)
    -> EncounterSimulation.Outcome
  {
    fight.step(
      dt: dt, leader: [0, 8], facing: [0, -1], aiming: false,
      fireHeld: false, firePressed: false, figures: [.miki: [0, 8]], session: session)
  }

  private func range(boxes: [Level.Box] = []) -> Level {
    let robot = Level.Hostile(
      id: "robot", name: "Guard", hiddenAt: .zero, standAt: .zero, hits: 6, attack: .robot,
      range: 12)
    return Level(
      id: "robot-fixture", ground: .box("floor", at: [0, -0.15, 0], size: [60, 0.3, 60]),
      boxes: boxes, interactions: [], triggers: [],
      encounters: [
        Level.Encounter(
          beat: .stranger, start: .area(.init(minimum: [-10, -10], maximum: [10, 10])),
          retryAt: [0, 10], hostiles: [robot], cues: [(0, .reveal("robot")), (0, .engage("robot"))])
      ], startingAmmo: 12, party: [.miki], spawns: [.miki: [0, 8]], heading: [0, -1],
      cameraOffset: BrooklynBridge.cameraOffset, fieldOfView: 22,
      opening: "Range", objective: "Range", lookAround: "Range", restartNote: "Restart")
  }
}
