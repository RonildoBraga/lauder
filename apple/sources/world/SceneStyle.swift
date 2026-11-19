import RealityKit
import UIKit

@MainActor
struct SceneStyle {
  let unitBox = MeshResource.generateBox(size: 1)

  // The level's look comes from its scene file, and the party's and the hostiles' from their
  // models' scene files, all exported by Blender (ADR 0002). The gameplay signals keep their own
  // colours here.
  /// A level without a scene file, such as a test's: its boxes and landmarks as plain blocks.
  let scenery = SimpleMaterial(
    color: UIColor(red: 0.55, green: 0.57, blue: 0.56, alpha: 1), roughness: 0.9,
    isMetallic: false)
  /// The carbine.
  let gear = SimpleMaterial(
    color: UIColor(red: 0.16, green: 0.25, blue: 0.25, alpha: 1), roughness: 0.9,
    isMetallic: false)
  let warm = UnlitMaterial(color: UIColor(red: 1, green: 0.75, blue: 0.4, alpha: 1))
  /// Threats: a hostile's aim and shots, and the assisted target's marker.
  let threat = UnlitMaterial(color: UIColor(red: 0.95, green: 0.3, blue: 0.24, alpha: 1))
  let signal = UnlitMaterial(color: UIColor(red: 0.62, green: 0.87, blue: 0.77, alpha: 1))

  private static func color(_ value: SIMD3<Float>) -> UIColor {
    UIColor(red: CGFloat(value.x), green: CGFloat(value.y), blue: CGFloat(value.z), alpha: 1)
  }

  // Only visual children are scaled; parent entities keep their authored layout transforms.
  func block(size: SIMD3<Float>, at position: SIMD3<Float>, material: any Material)
    -> ModelEntity
  {
    let model = ModelEntity(mesh: unitBox, materials: [material])
    model.scale = size
    model.position = position
    return model
  }

  /// A member of the party, from the model named after them in `blender/assets`.
  func partyMember(_ member: PartyMember) -> Entity {
    figure(member.rawValue)
  }

  /// A hostile, from the `hostile` model: the party's shape in a dark red that reads as a threat.
  func hostile() -> Entity {
    figure("hostile")
  }

  /// A carbine held at the right side, pointing ahead; shown while it is drawn.
  func carbine() -> ModelEntity {
    block(size: [0.07, 0.08, 0.55], at: [0.21, 0.08, -0.22], material: gear)
  }

  /// The models that the game creates, each loaded once from its scene file (ADR 0002)
  /// and copied for every figure that shows it.
  private static var models: [String: Entity] = [:]

  /// A figure from its model. The model stands on the ground at its origin and faces Blender's
  /// -y, the game's +z, so it is turned half a turn to face -z, and lowered to stand below the
  /// body's centre, which the game moves and turns. Its front mark makes facing readable without
  /// a rig or animation.
  private func figure(_ name: String) -> Entity {
    let model = Self.model(named: name).clone(recursive: true)
    model.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])
    model.position = [0, -PartyBody.height / 2, 0]
    let visual = Entity()
    visual.addChild(model)
    return visual
  }

  private static func model(named name: String) -> Entity {
    if let model = models[name] {
      return model
    }
    do {
      let model = try Entity.load(named: name, in: .main)
      model.name = "\(name).model"
      models[name] = model
      return model
    } catch {
      preconditionFailure("The \(name) model's scene file, \(name).usdz, did not load: \(error)")
    }
  }

  /// The level's lights, from its layout file: a sun shines from its source over the whole
  /// level, and a point or spot light from where it stands.
  func addLights(_ lights: [Level.Light], to root: Entity) {
    for light in lights {
      let color = Self.color(light.color)
      let entity: Entity
      switch light.kind {
      case .sun(let source, let shadowDistance):
        let sun = DirectionalLight()
        sun.light.color = color
        sun.light.intensity = light.intensity
        if let shadowDistance {
          var shadow = DirectionalLightComponent.Shadow(
            shadowProjection: .automatic(maximumDistance: shadowDistance), depthBias: 1)
          shadow.cascades = .fixed(1)
          sun.shadow = shadow
        } else {
          // The light casts shadows only while it has the component; its `shadow` always reads.
          sun.components.remove(DirectionalLightComponent.Shadow.self)
        }
        sun.look(at: .zero, from: source, relativeTo: nil)
        entity = sun
      case .point(let position, let radius):
        let point = PointLight()
        point.light = PointLightComponent(
          color: color, intensity: light.intensity, attenuationRadius: radius)
        point.position = position
        entity = point
      case .spot(let position, let target, let radius, let innerAngle, let outerAngle, let shadow):
        // RealityKit's spot angles are full cone widths, as the layout's are: a 60° outer angle
        // 10 m above the ground lights a radius of 10 tan 30° = 5.77 m (ADR 0002).
        let spot = SpotLight()
        spot.light = SpotLightComponent(
          color: color, intensity: light.intensity, innerAngleInDegrees: innerAngle,
          outerAngleInDegrees: outerAngle, attenuationRadius: radius)
        if shadow {
          spot.components.set(SpotLightComponent.Shadow())
        } else {
          spot.components.remove(SpotLightComponent.Shadow.self)
        }
        // A spot light shines along its own -z.
        spot.look(at: target, from: position, relativeTo: nil)
        entity = spot
      }
      entity.name = light.name
      root.addChild(entity)
    }
  }
}
