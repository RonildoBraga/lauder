import Testing
import simd

@testable import Lauder

@MainActor
struct GuardBodyTests {
  @Test(arguments: [false, true])
  func walkingAndRollingCannotEnterTheLivingHull(rolling: Bool) throws {
    let hostile = Level.Hostile(
      id: "guard", name: "Guard", hiddenAt: .zero, standAt: .zero, hits: 6,
      attack: .robot, strategicGuard: true)
    let encounter = Level.Encounter(
      beat: .stranger, start: .area(.init(minimum: [-10, -10], maximum: [10, 10])),
      retryAt: nil, hostiles: [hostile], cues: [(0, .reveal("guard")), (0, .engage("guard"))])
    let level = Level(
      id: "hull-test", ground: .box("floor", at: [0, -0.15, 0], size: [40, 0.3, 40]),
      boxes: [], triggers: [], encounters: [encounter], party: [.miki],
      spawns: [.miki: [0, 4], .tom: [-5, 6], .laura: [5, 6]], heading: [0, -1],
      cameraOffset: BrooklynBridge.cameraOffset,
      fieldOfView: 42, opening: "Test", objective: "Test", lookAround: "Test", restartNote: "Test")
    let world = GameWorld(level: level)
    let stick = stick(world, towards: [0, -1])
    for frame in 0..<120 {
      world.advanceParty(
        movement: stick, dodgePressed: rolling && frame == 5, deltaTime: 1 / 60)
      let robot = try #require(world.root.findEntity(named: "hostile.guard"))
      let centre = SIMD2(robot.position.x, robot.position.z)
      #expect(
        simd_distance(position(world, .miki), centre)
          >= RobotModelGeometry.bodyRadius + PartyBody.radius - 0.001)
    }
    #expect(position(world, .miki).y < 2)
  }
}
