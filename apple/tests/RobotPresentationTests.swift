import RealityKit
import Testing
import simd

@testable import Lauder

/// These load the real exported hierarchy: a correct numeric solver alone does not establish
/// that imported local axes, the figure's half turn and the visible barrels agree.
@MainActor
struct RobotPresentationTests {
  private func fixture() -> (Entity, Entity, RobotPresentation) {
    let body = Entity()
    body.position.y = PartyBody.height / 2
    let visual = SceneStyle().robot()
    body.addChild(visual)
    let presenter = RobotPresentation(visual: visual)
    presenter.reset(position: .zero, facing: [0, -1])
    return (body, visual, presenter)
  }

  private func part(_ name: String, in visual: Entity) throws -> Entity {
    try #require(
      visual.findEntity(
        named: "spider_bot_heavy_"
          + name.replacingOccurrences(of: "-", with: "_")
          .replacingOccurrences(of: " ", with: "_")))
  }

  @Test
  func theLoadedJointAxesKeepTheRobotGrounded() throws {
    let (body, visual, presenter) = fixture()
    defer { withExtendedLifetime((body, presenter)) {} }
    for leg in RobotModelGeometry.legs {
      let foot = try part("\(leg.name) foot", in: visual)
      let ankle = try part("\(leg.name) ankle pivot", in: visual)
      let upper = try part("\(leg.name) upper pivot", in: visual)
      let knee = try part("\(leg.name) knee pivot", in: visual)
      let lower = try part("\(leg.name) lower pivot", in: visual)
      let wanted = SIMD3(-leg.foot.x, leg.foot.z, leg.foot.y)
      #expect(simd_distance(ankle.position(relativeTo: nil), wanted) < 0.001)
      #expect(abs(foot.visualBounds(relativeTo: nil).min.y) < 0.001)
      #expect(simd_distance(foot.convert(direction: [0, 0, 1], to: nil), [0, 1, 0]) < 0.001)
      #expect(
        simd_distance(
          upper.convert(position: [0, 0, RobotModelGeometry.upperLength], to: nil),
          knee.position(relativeTo: nil)) < 0.001)
      #expect(
        simd_distance(
          lower.convert(position: [0, 0, RobotModelGeometry.lowerLength], to: nil),
          ankle.position(relativeTo: nil)) < 0.001)
    }
  }

  @Test
  func theRealFeetRemainLevelWhileWalkingTurningAndBracing() throws {
    let (body, visual, presenter) = fixture()
    for frame in 1...420 {
      let t = Float(frame) / 60
      let yaw = min(Float.pi / 2, max(0, t - 3) * 0.7)
      let position = SIMD2<Float>(0, -min(t, 3) * 0.55)
      body.position = [position.x, PartyBody.height / 2, position.y]
      presenter.update(
        position: position, facing: Movement.facing(yaw: yaw), brace: t > 6 ? 1 : 0,
        gunDirections: [], gunRecoil: .zero, down: false, dt: 1 / 60)
      for leg in RobotModelGeometry.legs {
        let foot = try part("\(leg.name) foot", in: visual)
        let up = simd_normalize(foot.convert(direction: [0, 0, 1], to: nil))
        #expect(simd_dot(up, [0, 1, 0]) > 0.9999)
        #expect(foot.visualBounds(relativeTo: nil).min.y > -0.002)
      }
    }
  }

  @Test
  func visibleMuzzlesAndPitchMatchTheThreeDimensionalShotTransform() throws {
    let (body, visual, presenter) = fixture()
    for yaw in [Float(0), .pi / 2, -.pi / 2] {
      let position = SIMD2<Float>(3, -5)
      let brace: Float = 0.8
      let recoil = SIMD2<Float>(0.06, 0.03)
      let offsets: [Float] = [0.11, -0.09]
      let pitches: [Float] = [-0.06, -0.04]
      let turn = simd_quatf(angle: yaw, axis: [0, 1, 0])
      let directions = zip(offsets, pitches).map { offset, pitch in
        (simd_quatf(angle: yaw + offset, axis: [0, 1, 0])
          * simd_quatf(angle: pitch, axis: [1, 0, 0])).act([0, 0, -1])
      }
      body.position = [position.x, PartyBody.height / 2, position.y]
      presenter.reset(position: position, facing: Movement.facing(yaw: yaw))
      presenter.update(
        position: position, facing: Movement.facing(yaw: yaw), brace: brace,
        gunDirections: directions, gunRecoil: recoil, down: false, dt: 0)
      for index in 0..<2 {
        let marker = try part(index == 0 ? "muzzle-left" : "muzzle-right", in: visual)
        let gun =
          simd_quatf(angle: offsets[index], axis: [0, 1, 0])
          * simd_quatf(angle: pitches[index], axis: [1, 0, 0])
        let mount = RobotModelGeometry.gunMounts[index]
        let tip = RobotModelGeometry.muzzles[index] - mount + SIMD3(0, 0, recoil[index])
        let wanted =
          SIMD3(position.x, -RobotModelGeometry.braceDepth * brace, position.y)
          + turn.act(mount + gun.act(tip))
        #expect(simd_distance(marker.position(relativeTo: nil), wanted) < 0.001)
        let forward = simd_normalize(marker.convert(direction: [0, -1, 0], to: nil))
        #expect(simd_dot(forward, directions[index]) > 0.9999)
      }
    }
  }

  @Test
  func pauseHoldsTheFeetAndResetRestoresTheNeutralStance() {
    var motion = RobotMotion()
    motion.reset(position: .zero, facing: [0, -1])
    _ = motion.advance(position: [0, -0.1], facing: [0, -1], brace: 0, dt: 1 / 60)
    let before = motion.footPositions
    for _ in 0..<60 {
      _ = motion.advance(position: [0, -0.1], facing: [0, -1], brace: 0, dt: 0)
    }
    #expect(motion.footPositions == before)
    motion.reset(position: .zero, facing: [0, -1])
    #expect(
      motion.footPositions
        == RobotModelGeometry.legs.map { SIMD3(-$0.foot.x, $0.foot.z, $0.foot.y) })
  }

  /// Reconstruct real endpoints independently: a clamped inverse solve must not silently move
  /// a foot whose desired anchor still claims to be planted.
  @Test(arguments: [false, true])
  func actualPatrolAndCombatKeepPlantedFeetReachable(combat: Bool) {
    var guardBot = RobotGuard(home: .zero)
    guardBot.reveal()
    guardBot.engage()
    var motion = RobotMotion()
    motion.reset(position: .zero, facing: guardBot.facing)
    var maxError: Float = 0
    var maxReach: Float = 0
    var maxDrift: Float = 0
    var oldWanted: [SIMD3<Float>] = []
    var oldActual: [SIMD3<Float>] = []
    for frame in 0..<7200 {
      let time = Float(frame) / 60
      let target: SIMD2<Float> = combat ? [8 * sin(time * 0.11), 8 * cos(time * 0.11)] : [0, 10]
      _ = guardBot.step(
        dt: 1 / 60, target: target, hasSight: combat && Int(time) % 20 < 14,
        obstacles: [], party: [])
      let position = guardBot.position
      let yaw = Movement.yaw(towards: guardBot.facing)
      let turn = simd_quatf(angle: yaw, axis: [0, 1, 0])
      let origin = SIMD3(position.x, -RobotModelGeometry.braceDepth * guardBot.brace, position.y)
      let poses = motion.advance(
        position: position, facing: guardBot.facing, brace: guardBot.brace, dt: 1 / 60)
      let wanted = motion.footPositions
      var actual: [SIMD3<Float>] = []
      for index in poses.indices {
        let leg = RobotModelGeometry.legs[index]
        let pose = poses[index]
        let upper =
          simd_quatf(angle: leg.angle + pose.swivel, axis: [0, 0, 1])
          * simd_quatf(angle: pose.upper, axis: [0, 1, 0])
        let lower = upper * simd_quatf(angle: pose.lower, axis: [0, 1, 0])
        let source =
          leg.hip + upper.act([0, 0, RobotModelGeometry.upperLength])
          + lower.act([0, 0, RobotModelGeometry.lowerLength])
        let endpoint = origin + turn.act([-source.x, source.z, source.y])
        actual.append(endpoint)
        maxError = max(maxError, simd_distance(endpoint, wanted[index]))
        let local = turn.inverse.act(wanted[index] - origin)
        maxReach = max(maxReach, simd_length(SIMD3(-local.x, local.z, local.y) - leg.hip))
        if oldWanted.count == wanted.count,
          simd_distance(oldWanted[index], wanted[index]) < 0.000001,
          abs(wanted[index].y - leg.foot.z) < 0.00001
        {
          maxDrift = max(maxDrift, simd_distance(oldActual[index], endpoint))
        }
      }
      oldWanted = wanted
      oldActual = actual
    }
    #expect(maxReach < RobotModelGeometry.upperLength + RobotModelGeometry.lowerLength - 0.0001)
    #expect(maxError < 0.0001)
    #expect(maxDrift < 0.0001)
  }
}
