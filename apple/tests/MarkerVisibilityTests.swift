import RealityKit
import Testing
import simd

@testable import Lauder

/// The bridge's baked tower shadows lie 3 cm above its snow. Check the rendered entities'
/// undersides, including the leader's child marker, rather than just the configured height.
@MainActor
struct MarkerVisibilityTests {
  @Test
  func leaderAndOrderMarkersClearTheBakedShadows() throws {
    let world = GameWorld(level: BrooklynBridge.level)
    let leader = try #require(world.root.findEntity(named: "miki.marker"))
    expectClearance(leader)
    var order = InputRules.Input.neutral
    order.command = .bothGo
    world.update(with: order, sampledIn: .exploring, deltaTime: 1 / 60)
    for member in world.session.companions {
      let ring = try #require(world.root.findEntity(named: "order.\(member.rawValue)"))
      #expect(ring.isEnabled)
      expectClearance(ring)
    }
  }

  @Test
  func theAssistedTargetAndLockMarkersClearTheBakedShadows() throws {
    var level = TestRange.mikiAlone
    let point = SIMD2<Float>(0, -6)
    level.encounters = [
      Level.Encounter(
        beat: .stranger, start: .area(PartyMotion.Box(minimum: [-10, -10], maximum: [10, 10])),
        retryAt: nil,
        hostiles: [
          Level.Hostile(
            id: "guard", name: "Guard", hiddenAt: point, standAt: point, hits: 100,
            attack: .robot, range: 12)
        ], cues: [(at: 0, cue: .reveal("guard")), (at: 0, cue: .engage("guard"))])
    ]
    let world = GameWorld(level: level)
    for frame in 0..<60 {
      world.advanceParty(
        movement: .zero, aim: stick(world, towards: [0, -1]), fireHeld: true,
        firePressed: frame == 0, lockPressed: frame == 5, deltaTime: 1 / 60)
    }
    for name in ["combat.target", "combat.lock"] {
      let marker = try #require(world.root.findEntity(named: name))
      #expect(marker.isEnabled)
      expectClearance(marker)
    }
  }

  #if DEBUG
    @Test
    func updatedPlaytestDestinationMarkersClearTheBakedShadows() throws {
      let world = GameWorld(level: BrooklynBridge.level)
      world.startPlaytest("formations")
      for frame in 0..<10 {
        let raw = InputRules.Raw(stick: frame < 2 ? .zero : stick(world, towards: [0, -1]))
        world.update(
          with: world.controls.resolve(raw, mode: .exploring), sampledIn: .exploring,
          deltaTime: 1 / 60)
      }
      for member in world.session.companions {
        let disc = try #require(
          world.root.findEntity(named: "playtest.target.\(member.rawValue)"))
        #expect(disc.isEnabled)
        expectClearance(disc)
      }
    }
  #endif

  private func expectClearance(_ marker: Entity) {
    #expect(abs(marker.position(relativeTo: nil).y - SceneStyle.groundMarkerHeight) < 0.0001)
    let bounds = marker.visualBounds(relativeTo: nil)
    #expect(bounds.min.y > 0.03, "\(marker.name)'s underside clears the tower shadows")
    #expect(bounds.max.y < 0.1, "\(marker.name) stays close to the snow")
  }
}
