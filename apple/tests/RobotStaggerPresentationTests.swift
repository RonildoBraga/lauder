import RealityKit
import Testing
import simd

@testable import Lauder

/// Load the actual rigid model: a stagger must move its visible eye and guns with native
/// targeting while the remaining feet stay planted, rather than hiding an unreachable solve.
@MainActor
struct RobotStaggerPresentationTests {
  @Test(arguments: 1...3)
  func aStaggerDipsTheLoadedHullWithoutSlidingFeetOrSeparatingItsNativeTargets(lost: Int) throws {
    let strategy = damaged(lost)
    var robot = ready()
    for _ in 0..<120 {
      advance(&robot, strategy: strategy, dt: 1 / 120)
      if robot.phase == .tracking { break }
    }
    try #require(robot.phase == .tracking)
    let (body, visual, presenter) = fixture(robot)
    defer { withExtendedLifetime(body) {} }
    show(robot, strategy: strategy, presenter: presenter, dt: 0)
    let feet = try RobotModelGeometry.legs.enumerated().compactMap { index, leg in
      guard !strategy.detachedLegs.contains(index) else {
        return nil as (Entity, Entity, SIMD3<Float>)?
      }
      let ankle = try part("\(leg.name) ankle pivot", in: visual)
      let foot = try part("\(leg.name) foot", in: visual)
      return (ankle, foot, ankle.position(relativeTo: nil))
    }
    let baseline = robot.bodyDrop
    var deepest = baseline
    let accepted = robot.stagger()
    try #require(accepted)
    for _ in 0..<120 {
      advance(&robot, strategy: strategy, dt: 1 / 120)
      show(robot, strategy: strategy, presenter: presenter, dt: 1 / 120)
      deepest = max(deepest, robot.bodyDrop)
      try expectAlignment(robot, strategy: strategy, visual: visual)
      for (ankle, foot, anchor) in feet {
        #expect(simd_distance(ankle.position(relativeTo: nil), anchor) < 0.001)
        #expect(abs(foot.visualBounds(relativeTo: nil).min.y) < 0.002)
        let up = simd_normalize(foot.convert(direction: [0, 0, 1], to: nil))
        #expect(simd_dot(up, [0, 1, 0]) > 0.9999)
      }
      if robot.phase != .staggered { break }
    }
    #expect(deepest > baseline + 0.07, "The loaded model must show a real crouch pulse")
    #expect(abs(robot.bodyDrop - baseline) < 0.001)
  }

  @Test
  func pauseFreezesTheLoadedStaggerAndResetRestoresTheHealthyModel() throws {
    let strategy = damaged(1)
    var robot = ready()
    let (body, visual, presenter) = fixture(robot)
    defer { withExtendedLifetime(body) {} }
    let accepted = robot.stagger()
    try #require(accepted)
    for _ in 0..<30 {
      advance(&robot, strategy: strategy, dt: 1 / 120)
      show(robot, strategy: strategy, presenter: presenter, dt: 1 / 120)
    }
    try #require(robot.phase == .staggered && robot.bodyDrop > 0.05)
    let entities =
      try ["root", "square sensor", "muzzle-left", "muzzle-right"].map {
        try part($0, in: visual)
      } + RobotModelGeometry.legs.map { try part("\($0.name) ankle pivot", in: visual) }
    let before = entities.map { $0.transformMatrix(relativeTo: nil) }
    let drop = robot.bodyDrop
    for _ in 0..<120 {
      advance(&robot, strategy: strategy, dt: 0)
      show(robot, strategy: strategy, presenter: presenter, dt: 0)
    }
    #expect(robot.phase == .staggered && robot.bodyDrop == drop)
    #expect(entities.map { $0.transformMatrix(relativeTo: nil) } == before)

    robot = ready()
    presenter.reset(position: robot.position, facing: robot.facing)
    #expect(robot.bodyDrop == 0)
    try expectAlignment(robot, strategy: GuardStrategy(), visual: visual)
    for leg in RobotModelGeometry.legs {
      #expect(try part("\(leg.name) connector", in: visual).isEnabled)
      let foot = try part("\(leg.name) foot", in: visual)
      #expect(abs(foot.visualBounds(relativeTo: nil).min.y) < 0.002)
    }
  }

  @Test
  func theLastLegCanSettleDuringStaggerWithoutDrivingTheBellyBelowTheDeck() throws {
    let strategy = damaged(4)
    var robot = ready()
    let (body, visual, presenter) = fixture(robot)
    defer { withExtendedLifetime(body) {} }
    let belly = try part("belly plate", in: visual)
    let accepted = robot.stagger()
    try #require(accepted)
    for _ in 0..<90 {
      advance(&robot, strategy: strategy, dt: 1 / 120)
      show(robot, strategy: strategy, presenter: presenter, dt: 1 / 120)
      #expect(robot.position == .zero)
      #expect(robot.bodyDrop <= RobotGuard.groundedDrop)
      #expect(belly.visualBounds(relativeTo: nil).min.y >= -0.001)
      try expectAlignment(robot, strategy: strategy, visual: visual)
    }
    try #require(abs(robot.bodyDrop - RobotGuard.groundedDrop) < 0.0001)
    // A further accepted reaction on an already settled value must still respect the floor.
    let groundedReaction = robot.stagger()
    try #require(groundedReaction)
    for _ in 0..<90 {
      advance(&robot, strategy: strategy, dt: 1 / 120)
      show(robot, strategy: strategy, presenter: presenter, dt: 1 / 120)
      #expect(abs(belly.visualBounds(relativeTo: nil).min.y) < 0.001)
      try expectAlignment(robot, strategy: strategy, visual: visual)
    }
  }

  @Test(arguments: [0, 1, 3, 4])
  func defeatAtTheStaggerPeakCannotRaiseTheLoadedHullAndResetRestoresItsHeight(lost: Int) throws {
    let strategy = damaged(lost)
    var robot = ready()
    let (body, visual, presenter) = fixture(robot)
    defer { withExtendedLifetime(body) {} }
    let hull = try part("root", in: visual)
    let healthyHeight = hull.position(relativeTo: nil).y
    let accepted = robot.stagger()
    try #require(accepted)
    for _ in 0..<36 {
      advance(&robot, strategy: strategy, dt: 1 / 120)
      show(robot, strategy: strategy, presenter: presenter, dt: 1 / 120)
    }
    try #require(robot.phase == .staggered && robot.bodyDrop > 0.05)
    let drop = robot.bodyDrop
    let shots = robot.shotSerial
    let parts = try ["root", "square sensor", "muzzle-left", "muzzle-right"].map {
      try part($0, in: visual)
    }
    let heights = parts.map { $0.position(relativeTo: nil).y }
    let belly = try part("belly plate", in: visual)
    robot.knockDown()
    show(robot, strategy: strategy, presenter: presenter, dt: 0)
    let legless = lost == GuardStrategy.legCount
    for _ in 0..<120 {
      advance(&robot, strategy: strategy, dt: 1 / 120)
      show(robot, strategy: strategy, presenter: presenter, dt: 1 / 120)
      #expect(robot.isDown && robot.shotSerial == shots)
      // A wreck never rises; a legless one keeps settling onto its belly (#200).
      let settled = robot.bodyDrop - drop
      #expect(legless ? settled >= -0.0001 : abs(settled) < 0.0001)
      for (entity, height) in zip(parts, heights) {
        #expect(abs(entity.position(relativeTo: nil).y - (height - settled)) < 0.001)
      }
      #expect(belly.visualBounds(relativeTo: nil).min.y >= -0.001)
    }
    if legless { #expect(abs(robot.bodyDrop - RobotGuard.groundedDrop) < 0.0001) }
    robot = ready()
    presenter.reset(position: robot.position, facing: robot.facing)
    #expect(robot.bodyDrop == 0)
    #expect(abs(hull.position(relativeTo: nil).y - healthyHeight) < 0.001)
    try expectAlignment(robot, strategy: GuardStrategy(), visual: visual)
  }

  private func ready() -> RobotGuard {
    var robot = RobotGuard(home: .zero, strategicPatterns: true)
    robot.reveal()
    robot.engage()
    return robot
  }

  private func damaged(_ count: Int) -> GuardStrategy {
    var strategy = GuardStrategy()
    for index in 0..<count {
      for _ in 0..<GuardStrategy.swordHitsToDetach {
        _ = strategy.accept(weapon: .energySword, part: .leg(index), damage: 1)
      }
    }
    return strategy
  }

  private func advance(_ robot: inout RobotGuard, strategy: GuardStrategy, dt: Float) {
    _ = robot.step(
      dt: dt, target: [0, 8], hasSight: true, obstacles: [], party: [],
      speedMultiplier: strategy.speedMultiplier, turnMultiplier: strategy.turnMultiplier,
      grounded: strategy.detachedLegs.count == GuardStrategy.legCount)
  }

  private func fixture(_ robot: RobotGuard) -> (Entity, Entity, RobotPresentation) {
    let body = Entity()
    body.position = [robot.position.x, PartyBody.height / 2, robot.position.y]
    let visual = SceneStyle().robot()
    body.addChild(visual)
    let presenter = RobotPresentation(visual: visual, debrisParent: body)
    presenter.reset(position: robot.position, facing: robot.facing)
    return (body, visual, presenter)
  }

  private func show(
    _ robot: RobotGuard, strategy: GuardStrategy, presenter: RobotPresentation, dt: Float
  ) {
    presenter.update(
      position: robot.position, facing: robot.facing, brace: robot.brace,
      gunDirections: robot.gunDirections, gunRecoil: robot.gunRecoil, down: robot.isDown,
      detachedLegs: strategy.detachedLegs, bodyDrop: robot.bodyDrop, dt: dt)
  }

  private func part(_ name: String, in visual: Entity) throws -> Entity {
    try #require(
      visual.findEntity(
        named: "spider_bot_heavy_"
          + name.replacingOccurrences(of: "-", with: "_")
          .replacingOccurrences(of: " ", with: "_")))
  }

  private func expectAlignment(
    _ robot: RobotGuard, strategy: GuardStrategy, visual: Entity
  ) throws {
    let eye = try #require(
      GuardWeakpoint.make(id: "guard", robot: robot, strategy: strategy)
        .first { $0.part == .eye })
    #expect(
      simd_distance(try part("square sensor", in: visual).position(relativeTo: nil), eye.centre)
        < 0.001)
    for index in 0..<2 {
      let marker = try part(index == 0 ? "muzzle-left" : "muzzle-right", in: visual)
      #expect(simd_distance(marker.position(relativeTo: nil), robot.muzzle(gun: index)) < 0.001)
      let forward = simd_normalize(marker.convert(direction: [0, -1, 0], to: nil))
      #expect(simd_dot(forward, robot.gunDirections[index]) > 0.9999)
    }
  }
}
