import RealityKit
import Testing
import simd

@testable import Lauder

/// The bridge's lights are plain data in the layout file that Blender writes (ADR 0002), and the
/// game builds its lights from them. Its materials come with the scene file, and the party's and
/// the hostiles' looks with their models' scene files.
@MainActor
struct LevelLookTests {
  /// The lights stay within the visual direction's budget: at most four, with at most one casting
  /// shadows. The game adds a sun as a directional light that shines from its source.
  @Test
  func theGameLightsTheBridgeFromTheLayoutFile() throws {
    let layout = BrooklynBridge.layout
    #expect((1...4).contains(layout.lights.count))
    #expect(layout.lights.filter(\.castsShadows).count <= 1)
    #expect(BrooklynBridge.level.lights.map(\.name) == layout.lights.map(\.name))
    let world = GameWorld(level: BrooklynBridge.level)
    for light in layout.lights {
      guard case .sun(let source, _) = light.kind else { continue }
      let entity = try #require(world.root.findEntity(named: light.name) as? DirectionalLight)
      #expect(entity.light.intensity == light.intensity)
      // The `shadow` property always has a value; the light casts shadows only with the component.
      let casts = entity.components.has(DirectionalLightComponent.Shadow.self)
      #expect(casts == light.castsShadows, "\(light.name) casts shadows as written")
      // A directional light shines along its own -z.
      let shining = simd_normalize(entity.convert(direction: [0, 0, -1], to: nil))
      #expect(simd_dot(shining, -simd_normalize(source)) > 0.9999, "\(light.name) aims")
    }
  }

  /// A point light stands where the layout puts it and reaches as far as its radius. A spot
  /// light also aims at its target with its cone, and casts the one shadow when the layout says
  /// so; the others cast none.
  @Test
  func pointAndSpotLightsStandAndAimAsWritten() throws {
    var level = BrooklynBridge.level
    level.lights = [
      .sun("sun", from: [0, 10, 0], color: [1, 1, 1], intensity: 2000),
      .point("lamp", at: [3, 2.5, 100], color: [1, 0.8, 0.6], intensity: 20000, radius: 12),
      .spot(
        "searchlight", at: [-6, 8, 90], toward: [-6, 0, 80], color: [0.9, 0.95, 1],
        intensity: 40000, radius: 30, angles: [30, 45], shadow: true),
    ]
    let world = GameWorld(level: level)
    let sun = try #require(world.root.findEntity(named: "sun") as? DirectionalLight)
    #expect(!sun.components.has(DirectionalLightComponent.Shadow.self))
    let lamp = try #require(world.root.findEntity(named: "lamp") as? PointLight)
    #expect(lamp.light.intensity == 20000)
    #expect(lamp.light.attenuationRadius == 12)
    #expect(simd_distance(lamp.position(relativeTo: nil), [3, 2.5, 100]) < 0.0001)
    let spot = try #require(world.root.findEntity(named: "searchlight") as? SpotLight)
    #expect(spot.light.intensity == 40000)
    #expect(spot.light.attenuationRadius == 30)
    #expect(spot.light.innerAngleInDegrees == 30)
    #expect(spot.light.outerAngleInDegrees == 45)
    #expect(spot.components.has(SpotLightComponent.Shadow.self))
    #expect(simd_distance(spot.position(relativeTo: nil), [-6, 8, 90]) < 0.0001)
    // A spot light shines along its own -z.
    let shining = simd_normalize(spot.convert(direction: [0, 0, -1], to: nil))
    #expect(simd_dot(shining, simd_normalize(SIMD3<Float>(0, -8, -10))) > 0.9999)
  }

  /// Each member of the party, and each hostile, shows the model that Blender exports to a scene
  /// file of its own (ADR 0002): standing on the ground below its body's centre, 1.58 m
  /// tall, and facing the figure's -z, where its front mark is.
  @Test
  func thePartyAndTheHostilesComeFromTheirModels() throws {
    let world = GameWorld(level: BrooklynBridge.level)
    for member in PartyMember.allCases {
      let body = try #require(world.root.findEntity(named: "party.\(member.rawValue)"))
      try expectFigure(in: body, from: member.rawValue)
    }
    let hostile = try #require(world.root.findEntity(named: "hostile.attacker"))
    try expectFigure(in: hostile, from: "hostile")
  }

  private func expectFigure(in body: Entity, from name: String) throws {
    let model = try #require(body.findEntity(named: "\(name).model"))
    let figure = try #require(model.parent)
    let mark = try #require(model.findEntity(named: "\(name)_mark"))
    let ahead = mark.position(relativeTo: figure)
    #expect(abs(ahead.x) < 0.001 && abs(ahead.z + 0.16) < 0.001, "\(name) faces -z")
    let bounds = model.visualBounds(relativeTo: figure)
    #expect(abs(bounds.min.y + PartyBody.height / 2) < 0.001, "\(name) stands on the ground")
    #expect(abs(bounds.max.y - bounds.min.y - 1.58) < 0.001, "\(name) is 1.58 m tall")
  }
}
