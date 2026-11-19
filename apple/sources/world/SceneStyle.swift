import RealityKit
import UIKit

@MainActor
struct SceneStyle {
  let unitBox = MeshResource.generateBox(size: 1)
  let unitSphere = MeshResource.generateSphere(radius: 1)

  // The level's look comes from its scene file, exported by Blender (ADR 0006). The stand-ins
  // and the gameplay signals keep their own colours here.
  /// A level without a scene file, such as a test's: its boxes and landmarks as plain blocks.
  let scenery = SimpleMaterial(
    color: UIColor(red: 0.55, green: 0.57, blue: 0.56, alpha: 1), roughness: 0.9,
    isMetallic: false)
  /// The stand-ins' heads.
  let head = SimpleMaterial(
    color: UIColor(red: 0.65, green: 0.68, blue: 0.55, alpha: 1), roughness: 1,
    isMetallic: false)
  /// The stand-ins' legs and the carbine.
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

  func partyMember(_ member: PartyMember) -> Entity {
    switch member {
    case .miki: standIn(color: UIColor(red: 0.25, green: 0.65, blue: 0.59, alpha: 1), width: 0.38)
    case .laura: standIn(color: UIColor(red: 0.9, green: 0.61, blue: 0.29, alpha: 1), width: 0.31)
    case .tom: standIn(color: UIColor(red: 0.38, green: 0.51, blue: 0.81, alpha: 1), width: 0.49)
    }
  }

  /// A hostile's stand-in: the same shape as the party's, in a dark red that reads as a threat.
  func hostile() -> Entity {
    standIn(color: UIColor(red: 0.55, green: 0.18, blue: 0.17, alpha: 1), width: 0.4)
  }

  /// A carbine held at the right side, pointing ahead; shown while it is drawn.
  func carbine() -> ModelEntity {
    block(size: [0.07, 0.08, 0.55], at: [0.21, 0.08, -0.22], material: gear)
  }

  private func standIn(color: UIColor, width: Float) -> Entity {
    let visual = Entity()
    let clothing = SimpleMaterial(color: color, roughness: 1, isMetallic: false)
    visual.addChild(block(size: [width, 0.72, 0.3], at: [0, 0.04, 0], material: clothing))
    let head = ModelEntity(mesh: unitSphere, materials: [self.head])
    head.scale = SIMD3(repeating: 0.16)
    head.position = [0, 0.57, 0]
    visual.addChild(head)
    // A small front mark makes facing readable without a rig or new animation.
    visual.addChild(block(size: [0.15, 0.2, 0.025], at: [0, 0.12, -0.16], material: signal))
    for side: Float in [-1, 1] {
      visual.addChild(
        block(size: [0.13, 0.55, 0.18], at: [side * 0.105, -0.55, 0], material: gear))
      visual.addChild(
        block(size: [0.18, 0.1, 0.28], at: [side * 0.105, -0.8, -0.04], material: clothing))
    }
    return visual
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
