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

  @Test(arguments: [Float(12.01), 13, 14])
  func aVisibleTargetBeyondAttackRangeCannotHoldTrackingForever(distance: Float) throws {
    var robot = readyRobot()
    let point = SIMD2<Float>(0, distance)
    for _ in 0..<120 {
      _ = robot.step(dt: dt, target: point, hasSight: true, obstacles: [], party: [])
      if robot.phase == .tracking { break }
    }
    try #require(robot.phase == .tracking)
    // Quiet detection still reaches 14 m, and the full existing tracking warning remains.
    for _ in 0..<116 {
      #expect(robot.step(dt: dt, target: point, hasSight: true, obstacles: [], party: []) == nil)
      #expect(robot.phase == .tracking)
    }
    for _ in 0..<8 {
      _ = robot.step(dt: dt, target: point, hasSight: true, obstacles: [], party: [])
      if robot.phase == .searching { break }
    }
    #expect(robot.phase == .searching && robot.shotSerial == 0)
    #expect(robot.committedPoint == nil)
    // A later in-range observation must start a new complete warning, not bank a shot.
    _ = robot.step(dt: dt, target: [0, 8], hasSight: true, obstacles: [], party: [])
    #expect(robot.phase == .notice)
    for _ in 0..<120 {
      #expect(robot.step(dt: dt, target: [0, 8], hasSight: true, obstacles: [], party: []) == nil)
    }
    #expect(robot.shotSerial == 0)
    for _ in 0..<120 {
      _ = robot.step(dt: dt, target: [0, 8], hasSight: true, obstacles: [], party: [])
      if robot.shotSerial > 0 { break }
    }
    #expect(robot.shotSerial == 1)
  }

  @Test
  func theAttackRangeBoundaryStillCommitsAfterItsCompleteWarning() throws {
    var robot = readyRobot()
    for _ in 0..<240 {
      _ = robot.step(
        dt: dt, target: [0, RobotGuard.attackRange], hasSight: true, obstacles: [], party: [])
      if robot.phase == .committed { break }
    }
    #expect(robot.phase == .committed)
    #expect(robot.committedPoint == SIMD2<Float>(0, RobotGuard.attackRange))
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
  func retreatKeepsTheUnresolvedEncountersInjuriesAndRobotDamage() throws {
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
    #expect(!session.hit("robot", toughness: 6))
    // Leave sight/range without taking the authored safe exit. The active encounter's
    // search and return to patrol must not restore either side's damage.
    for _ in 0..<1_200 {
      _ = fight.step(
        dt: dt, leader: [0, 24], facing: [0, -1], aiming: false,
        fireHeld: false, firePressed: false, figures: [.miki: [0, 24]], session: session)
    }
    #expect(session.inEncounter && session.hitsTaken == 1)
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
    #expect(fight.resolveRobotBypass(id: "robot", session: session))
    #expect(!session.inEncounter && session.defeated.isEmpty)
    // Injuries are encounter-local: both victory and the completed safe bypass recover
    // them, and the bypass does not count as a robot kill.
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
      boxes: boxes, triggers: [],
      encounters: [
        Level.Encounter(
          beat: .stranger, start: .area(.init(minimum: [-10, -10], maximum: [10, 10])),
          retryAt: [0, 10], hostiles: [robot], cues: [(0, .reveal("robot")), (0, .engage("robot"))])
      ], party: [.miki], spawns: [.miki: [0, 8]], heading: [0, -1],
      cameraOffset: BrooklynBridge.cameraOffset, fieldOfView: 22,
      opening: "Range", objective: "Range", lookAround: "Range", restartNote: "Restart")
  }
}
