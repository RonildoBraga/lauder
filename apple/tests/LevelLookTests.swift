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
  /// file of its own (ADR 0002), standing on the ground below its body's centre and facing the
  /// figure's -z. A pawn's face is the front of its head, which its headwear leaves bare: Miki's
  /// hair and Laura's hood sit behind it, and Laura's rim frames it. Tom's beanie sits square on
  /// his head. The pawns' headwear sets their heights; the hostile's front mark is its front.
  @Test
  func thePartyAndTheHostilesComeFromTheirModels() throws {
    let world = GameWorld(level: BrooklynBridge.level)
    let heights: [PartyMember: Float] = [.miki: 1.535, .laura: 1.54, .tom: 1.635]
    for member in PartyMember.allCases {
      let name = member.rawValue
      let body = try #require(world.root.findEntity(named: "party.\(name)"))
      let figure = try expectFigure(in: body, from: name, height: try #require(heights[member]))
      func centre(_ part: String) throws -> SIMD3<Float> {
        let entity = try #require(figure.findEntity(named: "\(name)_\(part)"), "\(name) \(part)")
        return entity.visualBounds(relativeTo: figure).center
      }
      let head = try centre("head")
      #expect(abs(head.x) < 0.001 && abs(head.z) < 0.001, "\(name)'s head is over the feet")
      switch member {
      case .miki:
        #expect(try centre("hair").z - head.z > 0.03, "Miki's hair is behind her face")
      case .laura:
        #expect(try centre("hood").z - head.z > 0.05, "Laura's hood is behind her face")
        #expect(try centre("rim").z - head.z < -0.15, "Laura's rim frames her face")
      case .tom:
        let beanie = try centre("beanie")
        #expect(abs(beanie.x) < 0.001 && abs(beanie.z) < 0.001, "Tom's beanie sits square")
      }
    }
    // The bridge's only hostile is the robot, so a range with one shooter shows the model.
    var range = TestRange.practice
    range.encounters = [
      Level.Encounter(
        beat: .stranger, start: .area(PartyMotion.Box(minimum: [-1, -1], maximum: [1, 1])),
        retryAt: nil,
        hostiles: [
          Level.Hostile(
            id: "shooter", name: "Shooter", hiddenAt: [0, -4], standAt: [0, -4], hits: 3)
        ], cues: [])
    ]
    let shooterWorld = GameWorld(level: range)
    let hostile = try #require(shooterWorld.root.findEntity(named: "hostile.shooter"))
    let figure = try expectFigure(in: hostile, from: "hostile", height: 1.58)
    let mark = try #require(figure.findEntity(named: "hostile_mark"))
    let ahead = mark.position(relativeTo: figure)
    #expect(abs(ahead.x) < 0.001 && abs(ahead.z + 0.16) < 0.001, "the hostile faces -z")
  }

  /// The figure that holds `name`'s model, which stands on the ground below the body's centre
  /// and is `height` tall.
  private func expectFigure(in body: Entity, from name: String, height: Float) throws -> Entity {
    let model = try #require(body.findEntity(named: "\(name).model"))
    let figure = try #require(model.parent)
    let bounds = model.visualBounds(relativeTo: figure)
    #expect(abs(bounds.min.y + PartyBody.height / 2) < 0.001, "\(name) stands on the ground")
    #expect(abs(bounds.max.y - bounds.min.y - height) < 0.001, "\(name) is \(height) m tall")
    return figure
  }

  /// World markers keep a readable size on screen (the visual direction). From the bridge's far
  /// camera they are drawn larger, by as much more of the ground as it shows across the screen
  /// than the camera they were made for, so each spans the same share of the screen as it did
  /// from that camera. In the test yard, whose camera is close, they keep their own size.
  @Test
  func worldMarkersKeepTheirSizeOnScreen() throws {
    let bridge = BrooklynBridge.level
    let scale = SceneStyle.markerScale(
      cameraOffset: bridge.cameraOffset, fieldOfView: bridge.fieldOfView)
    #expect(abs(scale - 2.56) < 0.01)
    let yard = SceneStyle.markerScale(
      cameraOffset: TestYard.cameraOffset, fieldOfView: TestYard.level.fieldOfView)
    #expect(abs(yard - 1) < 0.01)
    // The share of the screen's height that a size on the ground spans at a camera's target.
    func share(_ size: Float, _ offset: SIMD3<Float>, _ fieldOfView: Float) -> Float {
      size / (2 * simd_length(offset) * tan(fieldOfView * .pi / 360))
    }
    let made = SceneStyle.markerCamera
    let disc: Float = 0.68
    #expect(
      abs(
        share(disc * scale, bridge.cameraOffset, bridge.fieldOfView)
          - share(disc, made.offset, made.fieldOfView)) < 0.0001)
    // The world draws its markers at that scale.
    let world = GameWorld(level: bridge)
    let leader = try #require(world.root.findEntity(named: "miki.marker"))
    #expect(abs(leader.scale.x - scale) < 0.001 && leader.scale.y == 1)
    let ring = try #require(world.root.findEntity(named: "order.tom"))
    #expect(abs(ring.scale.x - scale) < 0.001 && abs(ring.scale.z - scale) < 0.001)
    let target = try #require(world.root.findEntity(named: "combat.target"))
    #expect(abs(target.scale.x - scale) < 0.001)
    let cross = try #require(world.root.findEntity(named: "order.refused"))
    // Its two bars, 0.8 m by 0.12 m as made, cross at 45°.
    let across = cross.visualBounds(relativeTo: cross).extents.x
    #expect(abs(across - (0.8 + 0.12) * scale * Float(0.5).squareRoot()) < 0.01)
  }
}
