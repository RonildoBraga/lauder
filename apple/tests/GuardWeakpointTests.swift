import Testing
import simd

@testable import Lauder

struct GuardWeakpointTests {
  @Test
  func theEyeAndFourGeneratedLegsExistTogetherFromTheStart() throws {
    let robot = RobotGuard(home: [3, 4])
    let points = GuardWeakpoint.make(id: "guard", robot: robot, strategy: GuardStrategy())
    #expect(points.count == 5 && Set(points.map(\.id)).count == 5)
    let eye = try #require(points.first { $0.part == .eye })
    #expect(eye.id == "guard.eye")
    #expect(simd_distance(eye.centre, [3, 1.53, 4.7045]) < 0.0001)
    for index in 0..<RobotModelGeometry.legs.count {
      let point = try #require(points.first { $0.part == .leg(index) })
      let leg = RobotModelGeometry.legs[index]
      #expect(point.id == "guard.leg.\(index)")
      #expect(point.centre.y > leg.foot.z && point.centre.y < leg.hip.z)
      let direction = point.ground - robot.position
      #expect(simd_length(direction) > RobotModelGeometry.bodyRadius)
      #expect(simd_length(direction) < RobotModelGeometry.navigationRadius)
      // A fresh robot faces +z, reversing the canonical -z model's x/z signs.
      #expect(direction.x * leg.foot.x > 0 && direction.y * leg.foot.y < 0)
      #expect(!point.target.acceptsInteriorHits)
    }
  }

  @Test
  func aDetachedLegAloneDisappearsWhileTheEyeStaysCriticalAndAvailable() throws {
    var strategy = GuardStrategy()
    for _ in 0..<3 { _ = strategy.accept(weapon: .energySword, part: .leg(1), damage: 30) }
    let robot = RobotGuard(home: .zero)
    let points = GuardWeakpoint.make(id: "guard", robot: robot, strategy: strategy)
    #expect(points.count == 4 && !points.contains { $0.part == .leg(1) })
    #expect(points.contains { $0.part == .eye })
    #expect([0, 2, 3].allSatisfy { index in points.contains { $0.part == .leg(index) } })
    let hit = strategy.accept(weapon: .assaultRifle, part: .eye, damage: 5)
    #expect(hit?.effectiveness == .weakpoint && hit?.amount == 15)
    _ = strategy.accept(weapon: nil, part: nil, damage: .max)
    #expect(GuardWeakpoint.make(id: "guard", robot: robot, strategy: strategy).isEmpty)
  }

  @Test
  func componentCentresFollowNativeTurningAndBracingWithoutStageWindows() throws {
    var robot = RobotGuard(home: .zero)
    robot.reveal()
    robot.engage()
    for _ in 0..<90 {
      _ = robot.step(
        dt: 1 / 120, target: [5, 5], hasSight: true, obstacles: [], party: [],
        awareOfTarget: true)
    }
    let points = GuardWeakpoint.make(id: "guard", robot: robot, strategy: GuardStrategy())
    let eye = try #require(points.first { $0.part == .eye })
    let facing = robot.facing
    #expect(simd_dot(simd_normalize(eye.ground - robot.position), facing) > 0.999)
    #expect(abs(eye.centre.y - (1.53 - RobotModelGeometry.braceDepth * robot.brace)) < 0.0001)
    #expect(points.count == 5)
    for _ in 0..<1_200 {
      _ = robot.step(dt: 1 / 120, target: [5, 5], hasSight: true, obstacles: [], party: [])
    }
    #expect(GuardWeakpoint.make(id: "guard", robot: robot, strategy: GuardStrategy()).count == 5)
  }
}
