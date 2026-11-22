import RealityKit
import Testing
import simd

@testable import Lauder

/// Evasion is a fixed temporary destination, independent of formation motion and held orders.
@MainActor
struct GrenadeEvasionTests {
  @Test
  func aFollowingCompanionEscapesWhileTheLeaderMovesBackAcrossItsEscapeDirection() throws {
    let world = GameWorld(level: level(laura: [-0.9, 0.9], tom: [0.9, 0.9]))
    let marker = try #require(world.root.findEntity(named: "grenade.marker.thrower"))
    try #require(run(world, upTo: 1) { marker.isEnabled })
    let landing = SIMD2(marker.position.x, marker.position.z)
    try #require(simd_distance(position(world, .laura), landing) < Grenade.radius)
    #expect(world.session.order(of: .laura) == .following)

    // Laura's nearest escape is northwest of the landing. A southeast-moving leader must
    // not add formation feed-forward velocity to her fixed escape destination.
    let movement = stick(world, towards: [1, -1])
    for _ in 0..<240 where marker.isEnabled {
      world.advanceParty(movement: movement, deltaTime: 1 / 60)
    }
    #expect(!marker.isEnabled && world.fallBacks == 0)
    #expect(simd_distance(position(world, .laura), landing) > Grenade.radius)
    #expect(world.session.hits(of: .laura) == 0)
    #expect(world.session.order(of: .laura) == .following)
  }

  @Test
  func aSettledHeldCompanionTakesAShortEscapeThenReturnsToTheSameOrderPoint() throws {
    // The next safe grid destination is about half a metre from this point: farther than
    // settleDistance but nearer than reengageDistance. A settled motor must explicitly wake.
    let held: SIMD2<Float> = [2.03, 0.65]
    let world = GameWorld(level: level(laura: held, tom: [-5, 5]))
    #expect(world.session.holdAll())
    run(world, upTo: 0.1)
    let order = world.session.order(of: .laura)
    #expect(order == .holding(held))
    let marker = try #require(world.root.findEntity(named: "grenade.marker.thrower"))
    try #require(run(world, upTo: 1) { marker.isEnabled })
    let landing = SIMD2(marker.position.x, marker.position.z)
    let before = position(world, .laura)
    try #require(simd_distance(before, landing) < Grenade.radius)

    try #require(
      run(world, upTo: 0.8) {
        simd_distance(position(world, .laura), landing) > Grenade.radius + 0.15
      })
    let moved = simd_distance(position(world, .laura), before)
    #expect(moved > 0.1 && moved < CompanionMotor.reengageDistance)
    #expect(world.session.order(of: .laura) == order)
    for _ in 0..<240 where marker.isEnabled {
      world.advanceParty(movement: .zero, deltaTime: 1 / 60)
    }
    #expect(!marker.isEnabled && world.fallBacks == 0)
    #expect(world.session.hits(of: .laura) == 0)
    #expect(world.session.order(of: .laura) == order)
    #expect(run(world, upTo: 3) { simd_distance(position(world, .laura), held) < 0.3 })
    #expect(world.session.order(of: .laura) == order)
  }

  private func level(laura: SIMD2<Float>, tom: SIMD2<Float>) -> Level {
    let spawns: [PartyMember: SIMD2<Float>] = [.miki: .zero, .tom: tom, .laura: laura]
    let thrower = Level.Hostile(
      id: "thrower", name: "Thrower", hiddenAt: [0, -5], standAt: [0, -5], hits: 6,
      attack: .throwGrenade, windUp: 0.2, recovery: 60, range: 14, inView: true,
      targetFromWindUp: true)
    let encounter = Level.Encounter(
      beat: .stranger, start: .area(PartyMotion.Box(minimum: [-10, -10], maximum: [10, 10])),
      retryAt: spawns[.miki], hostiles: [thrower], cues: [(at: 0, cue: .engage(thrower.id))])
    return Level(
      id: "grenade-evasion", ground: .box("ground", at: [0, -0.15, 0], size: [20, 0.3, 20]),
      boxes: [], interactions: [], triggers: [], encounters: [encounter], startingAmmo: 60,
      party: [.miki, .tom, .laura], spawns: spawns, heading: [0, -1],
      cameraOffset: TestYard.cameraOffset, fieldOfView: 42,
      opening: "Snow.", objective: "Test.", lookAround: "A thrower.", restartNote: "Restart.",
      combat: Level.Combat(fallsBack: true, leaderCover: true))
  }
}
