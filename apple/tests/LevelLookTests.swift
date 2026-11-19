import RealityKit
import Testing
import UIKit
import simd

@testable import Lauder

/// The bridge's lights and the surfaces' finishes are plain data that Blender edits with the
/// layouts (ADR 0005), and the game builds its lights and materials from them.
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

  /// Every surface has a finish in the shared palette, within the range that Blender and
  /// RealityKit share, and the game's material for it takes the finish's colour.
  @Test
  func everySurfaceTakesItsFinishFromThePalette() {
    #expect(Set(Surfaces.palette.keys) == Set(Level.Surface.allCases))
    let style = SceneStyle()
    for (surface, finish) in Surfaces.palette {
      let values = [
        finish.color.x, finish.color.y, finish.color.z, finish.roughness, finish.metallic,
      ]
      #expect(values.allSatisfy { (0...1).contains($0) }, "\(surface) stays between 0 and 1")
      var red: CGFloat = 0
      var green: CGFloat = 0
      var blue: CGFloat = 0
      var alpha: CGFloat = 0
      let tint = style.material(for: surface).color.tint
      #expect(tint.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
      let color = SIMD3<Float>(Float(red), Float(green), Float(blue))
      #expect(simd_distance(color, finish.color) < 0.001, "\(surface) takes its colour")
    }
  }
}
