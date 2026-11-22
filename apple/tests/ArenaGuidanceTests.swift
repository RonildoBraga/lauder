import Testing
import simd

@testable import Lauder

@MainActor
struct ArenaGuidanceTests {
  @Test
  func theArenaCompassFindsWarnedArrivalsThenLivingEnemiesAcrossTheLargerYard() throws {
    var level = CombatYard.level
    level.combat.companionWeapons = [:]
    let world = GameWorld(level: level)
    #expect(world.compass == nil)
    try walk(world, through: [[6.5, 2.5], [6.5, -2]])
    let warned = try #require(world.playtestSnapshot.arenaWarnings.keys.first)
    #expect(level.encounters.flatMap(\.hostiles).contains { $0.id == warned })
    let arrival = try #require(world.compass)
    #expect(arrival.name.hasPrefix("Arrival: ") && arrival.metres >= 8)

    try #require(
      run(world, upTo: 3) {
        world.playtestSnapshot.hostiles.values.contains { $0.isVisible && !$0.isDown }
      })
    let leader = position(world, world.session.leader)
    let living = world.playtestSnapshot.hostiles.values.filter { $0.isVisible && !$0.isDown }
      .sorted { $0.spec.id < $1.spec.id }
    let nearest = try #require(
      living.min(by: {
        simd_distance_squared($0.position, leader) < simd_distance_squared($1.position, leader)
      }))
    let compass = try #require(world.compass)
    #expect(compass.name == nearest.spec.name && compass.metres > Int(Weapon.closeScatter.range))
    #expect(compass.metres == Int(simd_distance(leader, nearest.position).rounded()))
    let (forward, right) = Movement.axes(cameraOffset: level.cameraOffset)
    let direction = nearest.position - leader
    let expected =
      (atan2(simd_dot(direction, right), simd_dot(direction, forward)) * 180 / .pi)
      .rounded() * .pi / 180
    #expect(abs(compass.angle - expected) < 0.0001)

    world.restart()
    #expect(world.compass == nil && world.playtestSnapshot.arenaWarnings.isEmpty)
  }
}
