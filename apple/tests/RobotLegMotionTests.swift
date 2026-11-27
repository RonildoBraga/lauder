import Testing
import simd

@testable import Lauder

struct RobotLegMotionTests {
  @Test
  func fewerSupportingLegsTakeProgressivelyLongerSwingsInsteadOfHurryingTheQueue() throws {
    let durations = try (0..<4).map { lost in
      var motion = RobotMotion()
      motion.reset(position: .zero, facing: [0, -1])
      let missing = Set([3, 2, 1].prefix(lost))
      let dt: Float = 1 / 240
      let speed = RobotGuard.speed * Float(4 - lost) / 4
      var liftedAt: Float?
      for frame in 1...1200 {
        let time = Float(frame) * dt
        _ = motion.advance(
          position: [0, -time * speed], facing: [0, -1], brace: 0,
          detachedLegs: missing, dt: dt)
        let lifted = motion.footPositions[0].y > RobotModelGeometry.legs[0].foot.z + 0.00001
        if lifted, liftedAt == nil { liftedAt = time }
        if !lifted, let liftedAt { return time - liftedAt }
      }
      throw MissingSwing()
    }
    #expect(durations[0] > 0.1 && durations[0] < 0.14)
    for index in 1..<durations.count { #expect(durations[index] > durations[index - 1]) }
    #expect(durations[3] > durations[0] * 3)
    #expect(durations[3] < durations[0] * 5)
  }

  @Test(arguments: [1, 2, 3])
  func pauseFreezesADamagedSwingAndResetRestoresTheHealthyCadence(lost: Int) throws {
    var motion = RobotMotion()
    motion.reset(position: .zero, facing: [0, -1])
    let missing = Set([3, 2, 1].prefix(lost))
    let dt: Float = 1 / 120
    let speed = RobotGuard.speed * Float(4 - lost) / 4
    var position = SIMD2<Float>.zero
    for frame in 1...600 {
      position = [0, -Float(frame) * dt * speed]
      _ = motion.advance(
        position: position, facing: [0, -1], brace: 0, detachedLegs: missing, dt: dt)
      if motion.footPositions[0].y > RobotModelGeometry.legs[0].foot.z + 0.001 { break }
    }
    try #require(motion.footPositions[0].y > RobotModelGeometry.legs[0].foot.z + 0.001)
    let paused = motion.footPositions
    for _ in 0..<120 {
      _ = motion.advance(position: position, facing: [0, -1], brace: 0, dt: 0)
    }
    #expect(motion.footPositions == paused)
    _ = motion.advance(position: position, facing: [0, -1], brace: 0, dt: dt)
    #expect(motion.footPositions[0] != paused[0])

    motion.reset(position: .zero, facing: [0, -1])
    var fresh = RobotMotion()
    fresh.reset(position: .zero, facing: [0, -1])
    for frame in 1...180 {
      let at = SIMD2<Float>(0, -Float(frame) * dt * RobotGuard.speed)
      _ = motion.advance(position: at, facing: [0, -1], brace: 0, dt: dt)
      _ = fresh.advance(position: at, facing: [0, -1], brace: 0, dt: dt)
      #expect(motion.footPositions == fresh.footPositions)
    }
  }

  @Test
  func losingTheSwingingLegCancelsItsStepWithoutMovingPlantedFeet() throws {
    var motion = RobotMotion()
    motion.reset(position: .zero, facing: [0, -1])
    for _ in 0..<2 {
      _ = motion.advance(position: [0, -0.1], facing: [0, -1], brace: 0, dt: 1 / 60)
    }
    let before = motion.footPositions
    let lifted = try #require(
      before.indices.first { before[$0].y > RobotModelGeometry.legs[$0].foot.z + 0.001 })
    _ = motion.advance(
      position: [0, -0.1], facing: [0, -1], brace: 0, detachedLegs: [lifted], dt: 0)
    #expect(motion.footPositions == before)
    var healthyStepped = false
    for frame in 1...90 {
      let old = motion.footPositions
      _ = motion.advance(
        position: [0, -0.1 - Float(frame) * 0.003], facing: [0, -1], brace: 0, dt: 1 / 60)
      let now = motion.footPositions
      #expect(now[lifted] == before[lifted])
      let moving = now.indices.filter { simd_distance(now[$0], old[$0]) > 0.00001 }
      #expect(moving.count <= 1)
      healthyStepped = healthyStepped || !moving.isEmpty
    }
    #expect(healthyStepped)
  }

  @Test
  func allMissingLegsStayOutOfTheQueueUntilAnExplicitReset() {
    var motion = RobotMotion()
    motion.reset(position: .zero, facing: [0, -1])
    let before = motion.footPositions
    _ = motion.advance(
      position: [0, -0.1], facing: [0, -1], brace: 0, detachedLegs: [0, 1, 2, 3], dt: 1 / 60)
    for _ in 0..<60 {
      _ = motion.advance(position: [0, -0.1], facing: [0, -1], brace: 0, dt: 1 / 60)
    }
    #expect(motion.footPositions == before)
    motion.reset(position: .zero, facing: [0, -1])
    for _ in 0..<3 {
      _ = motion.advance(position: [0, -0.1], facing: [0, -1], brace: 0, dt: 1 / 60)
    }
    #expect(motion.footPositions != before)
  }

  @Test
  func oneRemainingLegCanStillStepAndInvalidIndicesDoNotAffectIt() {
    var motion = RobotMotion()
    motion.reset(position: .zero, facing: [0, -1])
    let before = motion.footPositions
    for _ in 0..<4 {
      _ = motion.advance(
        position: [0, -0.1], facing: [0, -1], brace: 0,
        detachedLegs: [-1, 1, 2, 3, 4], dt: 1 / 60)
    }
    #expect(motion.footPositions[0] != before[0])
    for index in 1...3 { #expect(motion.footPositions[index] == before[index]) }
  }

  private struct MissingSwing: Error {}
}
