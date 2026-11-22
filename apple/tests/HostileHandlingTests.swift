import Testing
import simd

@testable import Lauder

struct HostileHandlingTests {
  @Test
  func trackingTurnsAtABoundedRateAndCanLagBehindATarget() {
    var handling = HostileHandling(facing: [0, -1])
    let dt: Float = 1 / 120
    handling.advance(dt: dt, toward: [10, 0], aiming: true)
    let angle = acos(max(-1, min(1, simd_dot(handling.facing, SIMD2(0, -1)))))
    #expect(abs(angle - HostileHandling.turnRate * dt) < 0.0001)
    #expect(simd_distance(handling.facing, [1, 0]) > 1)
    for _ in 0..<120 { handling.advance(dt: dt, toward: [10, 0], aiming: true) }
    #expect(simd_distance(handling.facing, [1, 0]) < 0.0001)
    #expect(handling.pose.raise == 1)
  }

  @Test
  func onePermissionProducesOnlyOneShotAndCancellationCannotReplayIt() {
    var handling = HostileHandling(facing: [0, -1])
    var random = SeededRandom(seed: 42)
    handling.begin()
    handling.begin()
    #expect(handling.takeShot(using: &random) != nil)
    #expect(handling.pose.kick == 1 && handling.pose.raise == 1)
    #expect(handling.takeShot(using: &random) == nil)
    handling.begin()
    handling.cancel()
    handling.advance(dt: 5, toward: [0, -10], aiming: false)
    #expect(handling.takeShot(using: &random) == nil)
    handling.begin()
    #expect(handling.takeShot(using: &random) != nil)
  }

  @Test
  func theAuthoredWarningDeliberatelyMissesTheBody() throws {
    var handling = HostileHandling(facing: [0, -1])
    var random = SeededRandom(seed: 42)
    handling.advance(dt: 0.1, toward: [0, -2], aiming: true)
    handling.begin(deliberateMiss: true)
    let candidate = handling.takeShot(using: &random)
    let shot = try #require(candidate)
    #expect(shot.deliberateMiss)
    let ray = try #require(
      Aim.ray(
        from: .zero, along: shot.direction, range: 10,
        hostiles: [Aim.Hostile(id: "miki", position: [0, -2], isTarget: true)], blockers: []))
    #expect(ray.strike == .nothing)
    #expect(handling.takeShot(using: &random) == nil)
    handling.begin()
    #expect(handling.takeShot(using: &random)?.deliberateMiss == false)
  }

  @Test
  func identicalSeedsReplaySpreadAndTurningDoesNotTeleportTheBarrel() throws {
    var first = HostileHandling(facing: [0, -1])
    var second = first
    var firstRandom = SeededRandom(seed: 17)
    var secondRandom = SeededRandom(seed: 17)
    var rays: [HostileHandling.Discharge] = []
    for _ in 0..<3 {
      first.begin()
      second.begin()
      let candidate = first.takeShot(using: &firstRandom)
      let shot = try #require(candidate)
      #expect(shot == second.takeShot(using: &secondRandom))
      #expect(abs(simd_length(shot.direction) - 1) < 0.0001)
      rays.append(shot)
      first.advance(dt: 0.161, toward: [0, -14], aiming: true)
      second.advance(dt: 0.161, toward: [0, -14], aiming: true)
    }
    #expect(Set(rays.map { $0.direction.x }).count > 1)
    first.advance(dt: 1 / 120, toward: [14, 0], aiming: true)
    first.begin()
    let candidate = first.takeShot(using: &firstRandom)
    let lagging = try #require(candidate)
    let path = try #require(
      Aim.ray(
        from: .zero, along: lagging.direction, range: 14,
        hostiles: [Aim.Hostile(id: "miki", position: [10, 0], isTarget: true)], blockers: []))
    #expect(path.strike == .nothing)
  }
}
