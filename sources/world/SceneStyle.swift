import RealityKit
import UIKit

@MainActor
struct SceneStyle {
  let unitBox = MeshResource.generateBox(size: 1)
  let unitSphere = MeshResource.generateSphere(radius: 1)

  let wallCap = SimpleMaterial(
    color: UIColor(red: 0.65, green: 0.68, blue: 0.55, alpha: 1), roughness: 1,
    isMetallic: false)
  let metal = SimpleMaterial(
    color: UIColor(red: 0.16, green: 0.25, blue: 0.25, alpha: 1), roughness: 0.9,
    isMetallic: false)
  let rust = SimpleMaterial(
    color: UIColor(red: 0.59, green: 0.33, blue: 0.23, alpha: 1), roughness: 1,
    isMetallic: false)
  let stone = SimpleMaterial(
    color: UIColor(red: 0.56, green: 0.57, blue: 0.45, alpha: 1), roughness: 1,
    isMetallic: false)
  let warm = UnlitMaterial(color: UIColor(red: 1, green: 0.75, blue: 0.4, alpha: 1))
  /// Threats: a hostile's aim and shots, and the assisted target's marker.
  let threat = UnlitMaterial(color: UIColor(red: 0.95, green: 0.3, blue: 0.24, alpha: 1))
  let signal = UnlitMaterial(color: UIColor(red: 0.62, green: 0.87, blue: 0.77, alpha: 1))
  let asphalt = SimpleMaterial(
    color: UIColor(red: 0.27, green: 0.29, blue: 0.29, alpha: 1), roughness: 1,
    isMetallic: false)
  let steel = SimpleMaterial(
    color: UIColor(red: 0.42, green: 0.48, blue: 0.5, alpha: 1), roughness: 0.9,
    isMetallic: false)
  let granite = SimpleMaterial(
    color: UIColor(red: 0.66, green: 0.62, blue: 0.54, alpha: 1), roughness: 1,
    isMetallic: false)
  let vehicleBody = SimpleMaterial(
    color: UIColor(red: 0.47, green: 0.38, blue: 0.33, alpha: 1), roughness: 1,
    isMetallic: false)
  let glass = SimpleMaterial(
    color: UIColor(red: 0.14, green: 0.19, blue: 0.21, alpha: 1), roughness: 0.7,
    isMetallic: false)
  let river = SimpleMaterial(
    color: UIColor(red: 0.13, green: 0.2, blue: 0.24, alpha: 1), roughness: 0.8,
    isMetallic: false)

  func material(for surface: Level.Surface) -> SimpleMaterial {
    switch surface {
    case .concrete: stone
    case .hazard: rust
    case .asphalt: asphalt
    case .steel: steel
    case .granite: granite
    case .vehicle: vehicleBody
    case .metal: metal
    case .river: river
    case .paint: wallCap
    }
  }

  /// A greybox vehicle filling its footprint `size`: a car's lower body and cabin, or a taller
  /// van, bus or truck with a band of dark windows.
  func vehicle(size: SIMD3<Float>, at position: SIMD3<Float>) -> Entity {
    let vehicle = Entity()
    vehicle.position = position
    let alongZ = size.z >= size.x
    let length = max(size.x, size.z)
    if size.y > 2 {
      vehicle.addChild(block(size: size, at: .zero, material: vehicleBody))
      let band: SIMD3<Float> =
        alongZ ? [size.x + 0.02, 0.5, length * 0.9] : [length * 0.9, 0.5, size.z + 0.02]
      vehicle.addChild(block(size: band, at: [0, size.y * 0.25, 0], material: glass))
    } else {
      let lower = size.y * 0.55
      vehicle.addChild(
        block(
          size: [size.x, lower, size.z], at: [0, (lower - size.y) / 2, 0],
          material: vehicleBody))
      let cabin: SIMD3<Float> =
        alongZ
        ? [size.x * 0.9, size.y - lower, length * 0.5]
        : [length * 0.5, size.y - lower, size.z * 0.9]
      vehicle.addChild(block(size: cabin, at: [0, (size.y - cabin.y) / 2, 0], material: glass))
    }
    return vehicle
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
    block(size: [0.07, 0.08, 0.55], at: [0.21, 0.08, -0.22], material: metal)
  }

  private func standIn(color: UIColor, width: Float) -> Entity {
    let visual = Entity()
    let clothing = SimpleMaterial(color: color, roughness: 1, isMetallic: false)
    visual.addChild(block(size: [width, 0.72, 0.3], at: [0, 0.04, 0], material: clothing))
    let head = ModelEntity(mesh: unitSphere, materials: [wallCap])
    head.scale = SIMD3(repeating: 0.16)
    head.position = [0, 0.57, 0]
    visual.addChild(head)
    // A small front mark makes facing readable without a rig or new animation.
    visual.addChild(block(size: [0.15, 0.2, 0.025], at: [0, 0.12, -0.16], material: signal))
    for side: Float in [-1, 1] {
      visual.addChild(
        block(size: [0.13, 0.55, 0.18], at: [side * 0.105, -0.55, 0], material: metal))
      visual.addChild(
        block(size: [0.18, 0.1, 0.28], at: [side * 0.105, -0.8, -0.04], material: clothing))
    }
    return visual
  }

  func landmark(for point: Level.PointOfInterest) -> ModelEntity {
    let entity = ModelEntity()
    let size = point.size
    entity.position = point.position + [0, size.y / 2, 0]
    entity.addChild(block(size: size, at: .zero, material: metal))
    entity.addChild(
      block(
        size: [size.x * 0.85, size.y * 0.15, size.z * 1.03], at: [0, -size.y * 0.27, 0],
        material: wallCap))
    return entity
  }

  func addLighting(to root: Entity) {
    let key = DirectionalLight()
    key.name = "sun-key"
    key.light.color = UIColor(red: 1, green: 0.91, blue: 0.74, alpha: 1)
    key.light.intensity = 4500
    var shadow = DirectionalLightComponent.Shadow(
      shadowProjection: .automatic(maximumDistance: 25), depthBias: 1)
    shadow.cascades = .fixed(1)
    key.shadow = shadow
    key.look(at: .zero, from: [-3, 8, 5], relativeTo: nil)
    root.addChild(key)

    let fill = DirectionalLight()
    fill.name = "sky-fill"
    fill.light.color = UIColor(red: 0.67, green: 0.81, blue: 0.85, alpha: 1)
    fill.light.intensity = 600
    fill.shadow = nil
    fill.look(at: .zero, from: [3, 5, -4], relativeTo: nil)
    root.addChild(fill)
  }
}
