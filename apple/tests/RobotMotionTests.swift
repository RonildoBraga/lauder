import Testing
import simd

@testable import Lauder

struct RobotMotionTests {
  @Test
  func longStepsRemainGroundedAndReachableThroughReversalsAndHeldTurns() {
    var motion = RobotMotion()
    var position = SIMD2<Float>.zero
    var yaw: Float = 0
    motion.reset(position: position, facing: Movement.facing(yaw: yaw))
    #expect(!motion.canPlaceBody(position: [10, 10], facing: [0, -1], brace: 0))
    let goals: [SIMD2<Float>] = [[0, -3], [3, -3], [3, 1], [-3, 1], [-3, -3]]
    var maximumError: Float = 0
    var maximumUpError: Float = 0
    var maximumReach: Float = 0
    var maximumFootprint: Float = 0
    var maximumTilt: Float = 0
    var minimumHeight: Float = 0
    var minimumSupports = 4
    var travelled: Float = 0
    var held = 0
    for frame in 0..<3600 {
      let target = goals[(frame / 360) % goals.count]
      let delta = target - position
      let brace: Float = frame % 1200 > 1000 ? 1 : 0
      let proposedYaw = Movement.turn(
        from: yaw, towards: Movement.yaw(towards: delta), limit: 0.8 / 60)
      if motion.canPlaceBody(
        position: position, facing: Movement.facing(yaw: proposedYaw), brace: brace)
      {
        yaw = proposedYaw
      } else {
        held += 1
      }
      if simd_length(delta) > 0.05,
        simd_dot(simd_normalize(delta), Movement.facing(yaw: yaw)) > cos(Float.pi / 180)
      {
        let proposed = position + simd_normalize(delta) * (0.55 / 60)
        if motion.canPlaceBody(position: proposed, facing: Movement.facing(yaw: yaw), brace: brace)
        {
          travelled += simd_distance(proposed, position)
          position = proposed
        } else {
          held += 1
        }
      }
      motion.advance(
        position: position, facing: Movement.facing(yaw: yaw), brace: brace, dt: 1 / 60)
      maximumReach = max(maximumReach, motion.maximumReach)
      maximumFootprint = max(
        maximumFootprint,
        motion.footPositions.map {
          simd_length(SIMD2($0.x, $0.z) - position) + RobotModelGeometry.footRadius
        }.max() ?? 0)
      maximumTilt = max(maximumTilt, simd_length(motion.bodyPose.rotation.imag))
      minimumHeight = min(minimumHeight, motion.bodyPose.offset.y)
      minimumSupports = min(
        minimumSupports, motion.footPositions.filter { abs($0.y - 0.15) < 0.00001 }.count)
      let heading = simd_quatf(angle: yaw, axis: [0, 1, 0])
      for (index, pose) in motion.legPoses.enumerated() {
        let leg = RobotModelGeometry.legs[index]
        let upper =
          simd_quatf(angle: leg.angle + pose.swivel, axis: [0, 0, 1])
          * simd_quatf(angle: pose.upper, axis: [0, 1, 0])
        let lower = upper * simd_quatf(angle: pose.lower, axis: [0, 1, 0])
        let source =
          leg.hip + upper.act([0, 0, RobotModelGeometry.upperLength])
          + lower.act([0, 0, RobotModelGeometry.lowerLength])
        let actual =
          SIMD3(position.x, 0, position.y)
          + heading.act(
            motion.bodyPose.offset + motion.bodyPose.rotation.act([-source.x, source.z, source.y]))
        maximumError = max(maximumError, simd_distance(actual, motion.footPositions[index]))
        let rotation =
          simd_quatf(angle: yaw, axis: [0, 0, 1])
          * motion.bodyPose.sourceRotation * lower * pose.ankle
        maximumUpError = max(maximumUpError, simd_distance(rotation.act([0, 0, 1]), [0, 0, 1]))
      }
    }
    #expect(maximumReach < RobotModelGeometry.upperLength + RobotModelGeometry.lowerLength - 0.0001)
    #expect(maximumFootprint < RobotModelGeometry.navigationRadius - 0.004)
    #expect(maximumError < 0.00001)
    #expect(maximumUpError < 0.00001)
    #expect(minimumSupports >= 3)
    #expect(maximumTilt > 0.001 && maximumTilt < 0.025)
    #expect(minimumHeight < -0.05 && minimumHeight > -0.071)
    #expect(travelled > 5)
    #expect(held > 0)
  }
}
