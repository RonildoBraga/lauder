import Testing
import simd

@testable import Lauder

/// #200 items 7 and 8. A guard that can't move keeps its full pause after each recovery, which
/// the maintainer kept as a reward for breaking its legs. A legless wreck settles onto its
/// belly even when the guard falls moments after losing its last leg.
struct GuardWreckAndPauseTests {
  private let dt: Float = 1 / 120

  @Test(arguments: [false, true])
  func aGuardDefeatedJustAfterLosingItsLastLegStillSettlesOntoItsBelly(afterTheFight: Bool) {
    var robot = RobotGuard(home: .zero, strategicPatterns: true)
    robot.reveal()
    // A fifth of a second into settling, it falls.
    for _ in 0..<24 {
      _ = robot.step(
        dt: dt, target: [0, 30], hasSight: false, obstacles: [], party: [],
        speedMultiplier: 0, grounded: true)
    }
    let fallen = robot.bodyDrop
    #expect(fallen > 0 && fallen < RobotGuard.groundedDrop / 2)
    robot.knockDown()
    #expect(abs(robot.bodyDrop - fallen) < 0.0001)
    var previous = robot.bodyDrop
    for _ in 0..<120 {
      // During the fight the encounter still steps the downed guard; once it has ended, the
      // simulation settles the wreck directly.
      if afterTheFight {
        robot.settleWreck(dt: dt, grounded: true)
      } else {
        _ = robot.step(
          dt: dt, target: [0, 30], hasSight: false, obstacles: [], party: [],
          speedMultiplier: 0, grounded: true)
      }
      #expect(robot.bodyDrop >= previous)
      previous = robot.bodyDrop
    }
    #expect(abs(robot.bodyDrop - RobotGuard.groundedDrop) < 0.0001)
  }

  @Test
  func aWreckThatStillHasLegsKeepsItsHeight() {
    var robot = RobotGuard(home: .zero, strategicPatterns: true)
    robot.reveal()
    for _ in 0..<24 {
      _ = robot.step(
        dt: dt, target: [0, 30], hasSight: false, obstacles: [], party: [],
        speedMultiplier: 0, grounded: true)
    }
    robot.knockDown()
    let fallen = robot.bodyDrop
    for _ in 0..<120 {
      robot.settleWreck(dt: dt, grounded: false)
      _ = robot.step(
        dt: dt, target: [0, 30], hasSight: false, obstacles: [], party: [], grounded: false)
    }
    #expect(abs(robot.bodyDrop - fallen) < 0.0001)
  }

  @Test
  func aGuardThatCannotMoveHoldsItsPlaceForTheWholePauseAfterRecovery() throws {
    var robot = RobotGuard(home: .zero, strategicPatterns: true)
    robot.reveal()
    robot.engage()
    var time: Float = 0
    var recovered: (time: Float, position: SIMD2<Float>, facing: SIMD2<Float>)?
    var pause: Float?
    var previous = robot.phase
    // The grounded pivot is slow, so allow time for its first full warned cycle.
    for _ in 0..<120 * 40 where pause == nil {
      _ = robot.step(
        dt: dt, target: [5, 5], hasSight: true, obstacles: [], party: [], awareOfTarget: true,
        speedMultiplier: 0, grounded: true)
      time += dt
      if previous == .recovering, robot.phase == .patrol {
        recovered = (time, robot.position, robot.facing)
      }
      if let recovered, robot.phase == .patrol {
        #expect(robot.position == recovered.position)
        #expect(simd_distance(robot.facing, recovered.facing) < 0.0001)
      }
      if let recovered, previous == .patrol, robot.phase == .notice {
        pause = time - recovered.time
      }
      previous = robot.phase
    }
    let held = try #require(pause)
    #expect(abs(held - 4) < 0.05)
  }
}
