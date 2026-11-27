import Testing
import simd

@testable import Lauder

struct RobotMobilityTests {
  private let dt: Float = 1 / 120

  @Test(arguments: 0...4)
  func lostLegsLimitBothPatrolAndLiveTargetTurns(lost: Int) {
    let strategy = damaged(lost)
    let expectedRates: [Float] = [0.8, 0.52, 0.32, 0.16, 0.08]
    for tracking in [false, true] {
      var robot = ready()
      var peak: Float = 0
      for _ in 0..<240 {
        let before = robot.facing
        // A moving flank target keeps the tracking turn unfinished. Patrol's first
        // destination is behind it, so it also cannot finish its turn in these two seconds.
        let flank = robot.position + SIMD2(-before.y, before.x) * 8
        _ = robot.step(
          dt: dt, target: flank, hasSight: tracking, obstacles: [], party: [],
          awareOfTarget: tracking, speedMultiplier: strategy.speedMultiplier,
          turnMultiplier: strategy.turnMultiplier, grounded: lost == 4)
        let rate =
          abs(
            (Movement.yaw(towards: robot.facing) - Movement.yaw(towards: before))
              .remainder(dividingBy: 2 * .pi)) / dt
        #expect(rate <= expectedRates[lost] + 0.0001)
        peak = max(peak, rate)
      }
      #expect(abs(peak - expectedRates[lost]) < 0.0001)
      #expect(robot.shotSerial == 0, "An unfinished physical turn cannot skip the warning")
    }
  }

  @Test(arguments: 0...4)
  func aDamagedGuardStillCommitsOnceAndCannotHomeInDuringItsBurst(lost: Int) {
    let strategy = damaged(lost)
    var robot = ready()
    let target = SIMD2<Float>(0, 8)
    for _ in 0..<300 {
      _ = robot.step(
        dt: dt, target: target, hasSight: true, obstacles: [], party: [],
        speedMultiplier: strategy.speedMultiplier, turnMultiplier: strategy.turnMultiplier,
        grounded: lost == 4)
      if robot.phase == .committed { break }
    }
    #expect(robot.phase == .committed && robot.committedPoint == target)
    let facing = robot.facing
    var shots = 0
    for _ in 0..<150 {
      let shot = robot.step(
        dt: dt, target: [8, 0], hasSight: false, obstacles: [], party: [],
        speedMultiplier: strategy.speedMultiplier, turnMultiplier: strategy.turnMultiplier,
        grounded: lost == 4)
      if let shot {
        shots += 1
        let delta = SIMD3(target.x, 1.25, target.y) - shot.origin
        #expect(simd_distance(simd_normalize(delta), shot.direction) < 0.0001)
      }
      #expect(robot.facing == facing && robot.committedPoint == target)
    }
    #expect(shots == 3)
  }

  @Test
  func invalidTurningCannotContaminateFacingOrBypassTheGroundedCap() {
    for multiplier: Float in [.nan, .infinity, -.infinity, -1, 0, 2] {
      for grounded in [false, true] {
        var robot = ready()
        let initial = robot.facing
        for _ in 0..<120 {
          let before = robot.facing
          _ = robot.step(
            dt: dt, target: [8, 0], hasSight: true, obstacles: [], party: [],
            awareOfTarget: true, speedMultiplier: 0,
            turnMultiplier: multiplier, grounded: grounded)
          let angle = abs(
            (Movement.yaw(towards: robot.facing) - Movement.yaw(towards: before))
              .remainder(dividingBy: 2 * .pi))
          let limit = RobotGuard.turnRate * (grounded ? Float(0.1) : 1) * dt
          #expect(angle <= limit + 0.000001)
          #expect(robot.facing.x.isFinite && robot.facing.y.isFinite)
        }
        if !multiplier.isFinite || multiplier <= 0 { #expect(robot.facing == initial) }
      }
    }
  }

  private func damaged(_ count: Int) -> GuardStrategy {
    var strategy = GuardStrategy()
    for leg in 0..<count {
      for _ in 0..<3 {
        _ = strategy.accept(weapon: .energySword, part: .leg(leg), damage: 30)
      }
    }
    return strategy
  }

  private func ready() -> RobotGuard {
    var robot = RobotGuard(home: .zero)
    robot.reveal()
    robot.engage()
    return robot
  }
}
