import Testing
import simd

@testable import Lauder

struct RobotStaggerTests {
  private let dt: Float = 1 / 120

  @Test(
    arguments: [
      RobotGuard.Phase.patrol, .notice, .tracking, .committed, .burst, .recovering, .searching,
    ],
    [RobotGuard.Pattern.precision, .fan])
  func aBreakCancelsTheOldAttackAndRequiresACompleteNewWarning(
    phase: RobotGuard.Phase, pattern: RobotGuard.Pattern
  ) throws {
    var robot = try ready(at: phase, pattern: pattern)
    let position = robot.position
    let facing = robot.facing
    let shots = robot.shotSerial
    let bursts = robot.burstSerial
    let accepted = robot.stagger()
    #expect(accepted)
    #expect(robot.phase == .staggered && robot.committedPoint == nil)
    var time: Float = 0
    while robot.phase == .staggered, time < 1 {
      #expect(advance(&robot, target: position + [8, 0]) == nil)
      time += dt
      #expect(robot.position == position && robot.facing == facing)
      #expect(robot.shotSerial == shots && robot.burstSerial == bursts)
    }
    #expect(time >= RobotGuard.staggerDuration && time < RobotGuard.staggerDuration + 2 * dt)
    var warningTime: Float = 0
    var sawNotice = false
    var sawTracking = false
    var sawCommit = false
    var shot: RobotGuard.Discharge?
    for _ in 0..<120 * 25 {
      if robot.phase == .notice { sawNotice = true }
      if robot.phase == .tracking { sawTracking = true }
      if robot.phase == .committed { sawCommit = true }
      if [.notice, .tracking, .committed].contains(robot.phase) { warningTime += dt }
      shot = advance(&robot, target: position + [0, 8])
      if shot != nil { break }
    }
    try #require(shot != nil)
    #expect(sawNotice && sawTracking && sawCommit)
    #expect(
      warningTime >= RobotGuard.noticeTime + robot.pattern.trackingTime + robot.pattern.commitTime
        - dt)
    #expect(robot.shotSerial == shots + 1 && robot.burstSerial == bursts + 1)
  }

  @Test
  func aRepeatedBreakRestartsOnlyTheStaggerAndDoesNotShortenExistingRecovery() throws {
    var robot = try ready(at: .recovering)
    let start = robot.position
    for _ in 0..<42 { _ = advance(&robot) }
    let recoveryElapsed = robot.elapsed
    let firstBreak = robot.stagger()
    #expect(firstBreak)
    for _ in 0..<36 { #expect(advance(&robot) == nil) }
    #expect(robot.phase == .staggered)
    let secondBreak = robot.stagger()
    #expect(secondBreak)
    #expect(robot.elapsed == 0)
    var interruptedTime: Float = 36 * dt
    for _ in 0..<120 where robot.phase == .staggered {
      #expect(advance(&robot) == nil)
      interruptedTime += dt
      #expect(robot.position == start)
    }
    try #require(robot.phase == .recovering)
    #expect(abs(robot.elapsed - recoveryElapsed - interruptedTime) < 0.0001)
    let shots = robot.shotSerial
    var total = recoveryElapsed + interruptedTime
    while robot.phase == .recovering, total < 5 {
      #expect(advance(&robot) == nil)
      total += dt
    }
    #expect(total >= GuardStrategy.recoveryDuration - dt)
    #expect(total < GuardStrategy.recoveryDuration + 2 * dt)
    #expect(robot.shotSerial == shots && robot.pattern == .fan)
  }

  @Test
  func anAlmostFinishedRecoveryDoesNotAddAnotherWholeRecoveryCycle() throws {
    var robot = try ready(at: .recovering)
    for _ in 0..<120 * 3 + 48 { _ = advance(&robot) }
    try #require(robot.phase == .recovering)
    let accepted = robot.stagger()
    #expect(accepted)
    for _ in 0..<74 { #expect(advance(&robot) == nil) }
    #expect(robot.phase == .patrol && robot.elapsed < 0.05)
    #expect(robot.pattern == .fan)
  }

  @Test
  func aResolvedShotStaysRealButTheInterruptedBurstCannotInjureAgain() throws {
    var robot = try ready(at: .burst)
    let shots = robot.shotSerial
    let burst = robot.burstSerial
    let firstInjury = robot.acceptBurstHit()
    let duplicateInjury = robot.acceptBurstHit()
    #expect(shots == 1 && firstInjury && !duplicateInjury)
    let accepted = robot.stagger()
    #expect(accepted)
    let interruptedInjury = robot.acceptBurstHit()
    #expect(!interruptedInjury && robot.shotSerial == shots)
    var time: Float = 0
    for _ in 0..<120 * 25 {
      time += dt
      if advance(&robot) != nil { break }
    }
    #expect(time >= GuardStrategy.recoveryDuration + RobotGuard.noticeTime + 1.4 + 0.6 - dt)
    #expect(robot.shotSerial == shots + 1 && robot.burstSerial == burst + 1)
    let newInjury = robot.acceptBurstHit()
    let newDuplicate = robot.acceptBurstHit()
    #expect(newInjury && !newDuplicate)
  }

  @Test
  func hiddenUnarmedAndTerminalRobotsCannotStaggerAndDefeatCancelsTheReaction() {
    var robot = RobotGuard(home: .zero)
    let hidden = robot.stagger()
    #expect(!hidden)
    robot.reveal()
    let unarmed = robot.stagger()
    #expect(!unarmed)
    robot.engage()
    let accepted = robot.stagger()
    #expect(accepted)
    robot.knockDown()
    let down = robot.stagger()
    #expect(!down && robot.phase == .down)
    #expect(advance(&robot) == nil && robot.elapsed == 0)
    robot.clear()
    let cleared = robot.stagger()
    #expect(!cleared && robot.phase == .cleared)
  }

  @Test
  func stoppedAndInvalidTimeCannotAdvanceTheReaction() throws {
    var robot = try ready(at: .committed)
    let accepted = robot.stagger()
    #expect(accepted)
    for _ in 0..<24 { _ = advance(&robot) }
    let elapsed = robot.elapsed
    let drop = robot.bodyDrop
    let muzzle = robot.muzzle(gun: 0)
    for dt: Float in [0, -1, .nan, .infinity] {
      #expect(
        robot.step(dt: dt, target: [8, 0], hasSight: true, obstacles: [], party: []) == nil)
      #expect(robot.elapsed == elapsed && robot.bodyDrop == drop)
      #expect(robot.muzzle(gun: 0) == muzzle && robot.phase == .staggered)
    }
  }

  private func ready(
    at phase: RobotGuard.Phase, pattern: RobotGuard.Pattern = .precision
  ) throws -> RobotGuard {
    var robot = RobotGuard(home: .zero, strategicPatterns: true)
    robot.reveal()
    robot.engage()
    let seek = phase == .searching ? RobotGuard.Phase.tracking : phase
    for _ in 0..<120 * 35 {
      if robot.phase == seek && robot.pattern == pattern { break }
      _ = advance(&robot)
    }
    try #require(robot.phase == seek && robot.pattern == pattern)
    if phase == .searching {
      _ = robot.step(
        dt: dt, target: robot.position + [0, 8], hasSight: false, obstacles: [], party: [])
    }
    try #require(robot.phase == phase)
    return robot
  }

  private func advance(
    _ robot: inout RobotGuard, target: SIMD2<Float>? = nil
  ) -> RobotGuard.Discharge? {
    robot.step(
      dt: dt, target: target ?? robot.position + [0, 8], hasSight: true, obstacles: [], party: [],
      awareOfTarget: true)
  }
}
