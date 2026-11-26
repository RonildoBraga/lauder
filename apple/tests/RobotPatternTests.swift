import Testing
import simd

@testable import Lauder

struct RobotPatternTests {
  private let delta: Float = 1 / 120

  @Test(arguments: [false, true])
  func onlyTheStrategicGuardAlternatesCompletedBursts(strategic: Bool) {
    var robot = ready(strategic: strategic)
    var bursts: [Int: [RobotGuard.Discharge]] = [:]
    var injuryOpportunities: [Int: Int] = [:]
    for _ in 0..<6_000 {
      if let shot = step(&robot) {
        bursts[shot.burst, default: []].append(shot)
        if robot.acceptBurstHit() { injuryOpportunities[shot.burst, default: 0] += 1 }
        let secondInjury = robot.acceptBurstHit()
        #expect(!secondInjury)
        #expect(simd_distance(shot.origin, robot.muzzle(gun: shot.gun)) < 0.00001)
        #expect(simd_distance(shot.direction, robot.gunDirections[shot.gun]) < 0.00001)
        #expect(abs(simd_length(shot.direction) - 1) < 0.00001)
        let yaw = Movement.yaw(towards: [shot.direction.x, shot.direction.z])
        let body = Movement.yaw(towards: robot.facing)
        #expect(
          abs((yaw - body).remainder(dividingBy: 2 * .pi)) <= RobotGuard.gunYawLimit + 0.00001)
        if shot.burst == 3 && robot.phase == .recovering { break }
      }
    }
    #expect(bursts.keys.sorted() == [1, 2, 3])
    #expect(bursts[1]?.map(\.gun) == [0, 1, 0])
    #expect(bursts[2]?.map(\.gun) == (strategic ? [0, 1, 0, 1, 0] : [0, 1, 0]))
    #expect(bursts[3]?.map(\.gun) == [0, 1, 0])
    #expect(bursts[1]?.allSatisfy { $0.pattern == .precision } == true)
    #expect(bursts[2]?.allSatisfy { $0.pattern == (strategic ? .fan : .precision) } == true)
    #expect(bursts[3]?.allSatisfy { $0.pattern == .precision } == true)
    #expect(injuryOpportunities == [1: 1, 2: 1, 3: 1])
    #expect(robot.recoveryDuration == (strategic ? 4 : 1.8))
  }

  @Test
  func theFanHasALongerWarningFullBraceAndDistinctHonestRays() throws {
    var robot = ready(strategic: true)
    var clock: Float = 0
    var warningStart: Float?
    var warnings: [RobotGuard.Pattern: Float] = [:]
    var braces: [RobotGuard.Pattern: Float] = [:]
    var fanDirections: [SIMD3<Float>] = []
    var widestDeviation: Float = 0
    for _ in 0..<4_800 {
      let before = robot.phase
      let shot = step(&robot)
      clock += delta
      if before != .notice && robot.phase == .notice { warningStart = clock }
      if let shot {
        if warnings[shot.pattern] == nil {
          warnings[shot.pattern] = clock - (warningStart ?? 0)
          braces[shot.pattern] = robot.brace
        }
        if shot.pattern == .fan {
          fanDirections.append(shot.direction)
          let centre = simd_normalize(SIMD3<Float>(0, 1.25, 8) - shot.origin)
          widestDeviation = max(
            widestDeviation, acos(min(1, max(-1, simd_dot(centre, shot.direction)))))
          if fanDirections.count == 5 { break }
        }
      }
    }
    let precise = try #require(warnings[.precision])
    let fan = try #require(warnings[.fan])
    #expect(fan > precise + 0.5)
    #expect(abs(try #require(braces[.precision]) - 0.6) < 0.01)
    #expect(abs(try #require(braces[.fan]) - 1) < 0.01)
    #expect(fanDirections.count == 5 && widestDeviation > 8 * .pi / 180)
    #expect(
      zip(fanDirections, fanDirections.dropFirst()).allSatisfy { simd_distance($0, $1) > 0.01 })
  }

  @Test
  func aCommittedFanCannotHomeInAfterTheTravellerMoves() {
    var stationary = ready(strategic: true)
    for _ in 0..<4_800 {
      _ = step(&stationary)
      if stationary.pattern == .fan && stationary.phase == .committed { break }
    }
    #expect(stationary.pattern == .fan && stationary.phase == .committed)
    var moving = stationary
    var count = 0
    for _ in 0..<240 {
      let expected = step(&stationary)
      let actual = moving.step(
        dt: delta, target: [-8, 0], hasSight: false, obstacles: [], party: [])
      #expect(actual == expected)
      if actual != nil { count += 1 }
      #expect(moving.facing == stationary.facing)
    }
    #expect(count == 5)
  }

  @Test(arguments: [false, true])
  func defeatAndBypassCancelTheRestOfAFan(bypass: Bool) {
    var robot = ready(strategic: true)
    for _ in 0..<4_800 {
      if let shot = step(&robot), shot.pattern == .fan { break }
    }
    #expect(robot.pattern == .fan && robot.phase == .burst)
    let serial = robot.shotSerial
    if bypass { robot.clear() } else { robot.knockDown() }
    for _ in 0..<1_200 { #expect(step(&robot) == nil) }
    #expect(robot.shotSerial == serial && robot.gunRecoil == .zero)
  }

  private func ready(strategic: Bool) -> RobotGuard {
    var robot = RobotGuard(home: .zero, strategicPatterns: strategic)
    robot.reveal()
    robot.engage()
    return robot
  }

  private func step(_ robot: inout RobotGuard) -> RobotGuard.Discharge? {
    robot.step(dt: delta, target: [0, 8], hasSight: true, obstacles: [], party: [])
  }
}
