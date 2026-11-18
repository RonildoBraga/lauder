import RealityKit
import Testing
import simd

@testable import Lauder

@MainActor
struct PartySpacingTests {
  /// #28: with uneven frame times, followers lost ground they could not regain while the
  /// leader kept running. A full-speed circle in open ground isolates that effect.
  @Test(arguments: 0..<4)
  func followersKeepTheirSpacingWhateverTheFrameTimes(cadence: Int) throws {
    let world = GameWorld(level: RelayHouse.level)
    let members = PartyMember.allCases
    let bodies = try members.map { member in
      try #require(world.root.findEntity(named: "party.\(member.rawValue)"))
    }
    var state = UInt64(0x5EED_0028) &+ UInt64(cadence)
    func unit() -> Float {
      state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
      return Float(state >> 40) / Float(1 << 24)
    }
    // Screen-relative stick axes for a world heading, as GameWorld consumes them.
    let toCamera = SIMD2(RelayHouse.cameraOffset.x, RelayHouse.cameraOffset.z)
    let forward = -simd_normalize(toCamera)
    let right = SIMD2(-forward.y, forward.x)

    var heading: Float = 0
    var elapsed: Float = 0
    var frame = 0
    var farthest: Float = 0
    while elapsed < 30 {
      let dt: Float =
        switch cadence {
        case 0: 1 / 60
        case 1: 0.012 + unit() * 0.012
        case 2: (frame / 90) % 2 == 0 ? 1 / 120 : 1 / 60
        default: frame % 60 == 59 ? 1 / 30 : 1 / 60
        }
      frame += 1
      elapsed += dt
      // A 2.5 m radius from the spawn stays clear of the shelter and the south boundary.
      heading += PartyBody.speed * dt / 2.5
      let direction = SIMD2(cos(heading), sin(heading))
      world.advanceParty(
        movement: SIMD2(simd_dot(direction, right), simd_dot(direction, forward)),
        deltaTime: dt)
      try #require(world.diagnostic == nil, "cadence \(cadence), frame \(frame)")
      guard elapsed > 5 else { continue }
      let leader = bodies[members.firstIndex(of: world.session.leader)!].position
      for body in bodies {
        farthest = max(farthest, simd_distance(leader, body.position))
      }
    }
    // The rear follower's nominal route distance is 1.6 m, measured at about 1.60 m here with
    // every cadence. Before #28, uneven cadences reached the far side of the circle (5 m).
    #expect(farthest <= 1.7, "cadence \(cadence): farther follower reached \(farthest) m")
  }

  @Test
  func aShortFrameCarriesItsTimeToTheNextFrame() throws {
    let world = GameWorld(level: RelayHouse.level)
    let leader = try #require(world.root.findEntity(named: "party.miki"))
    let start = leader.position
    // Less than one step: no movement yet, but the time is owed to the next frame.
    world.advanceParty(movement: [0, 1], deltaTime: GameWorld.simulationStep * 0.75)
    #expect(leader.position == start)
    world.advanceParty(movement: [0, 1], deltaTime: GameWorld.simulationStep * 0.5)
    let moved = simd_distance(leader.position, start)
    #expect(abs(moved - PartyBody.speed * GameWorld.simulationStep) < 0.0001)
  }
}
