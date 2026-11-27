import Testing
import simd

@testable import Lauder

struct RobotLegMotionTests {
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
}
