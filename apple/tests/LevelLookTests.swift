import RealityKit
import Testing
import simd

@testable import Lauder

/// The bridge's lights are plain data in the layout file that Blender writes (ADR 0006), and the
/// game builds its lights from them. Its materials come with the scene file.
@MainActor
struct LevelLookTests {
  /// The lights stay within the visual direction's budget: at most two, with at most one casting
  /// shadows. The game adds each as a directional light that shines from its source.
  @Test
  func theGameLightsTheBridgeFromTheLayoutFile() throws {
    let layout = BrooklynBridge.layout
    #expect((1...2).contains(layout.lights.count))
    #expect(layout.lights.filter { $0.shadowDistance != nil }.count <= 1)
    #expect(BrooklynBridge.level.lights.map(\.name) == layout.lights.map(\.name))
    let world = GameWorld(level: BrooklynBridge.level)
    for light in layout.lights {
      let entity = try #require(world.root.findEntity(named: light.name) as? DirectionalLight)
      #expect(entity.light.intensity == light.intensity)
      // The `shadow` property always has a value; the light casts shadows only with the component.
      let casts = entity.components.has(DirectionalLightComponent.Shadow.self)
      #expect(casts == (light.shadowDistance != nil), "\(light.name) casts shadows as written")
      // A directional light shines along its own -z.
      let shining = simd_normalize(entity.convert(direction: [0, 0, -1], to: nil))
      #expect(simd_dot(shining, -simd_normalize(light.source)) > 0.9999, "\(light.name) aims")
    }
  }
}
