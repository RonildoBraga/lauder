import RealityKit
import UIKit

@MainActor
struct SceneStyle {
  let unitBox = MeshResource.generateBox(size: 1)
  let unitCylinder = MeshResource.generateCylinder(height: 1, radius: 1)
  let unitSphere = MeshResource.generateSphere(radius: 1)

  let ground = SimpleMaterial(
    color: UIColor(red: 0.23, green: 0.31, blue: 0.29, alpha: 1), roughness: 1,
    isMetallic: false)
  let wall = SimpleMaterial(
    color: UIColor(red: 0.39, green: 0.48, blue: 0.44, alpha: 1), roughness: 1,
    isMetallic: false)
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
  let foliage = SimpleMaterial(
    color: UIColor(red: 0.35, green: 0.43, blue: 0.25, alpha: 1), roughness: 1,
    isMetallic: false)
  let cloth = SimpleMaterial(
    color: UIColor(red: 0.34, green: 0.46, blue: 0.47, alpha: 1), roughness: 1,
    isMetallic: false)
  let warm = UnlitMaterial(color: UIColor(red: 1, green: 0.75, blue: 0.4, alpha: 1))
  let signal = UnlitMaterial(color: UIColor(red: 0.62, green: 0.87, blue: 0.77, alpha: 1))
  let water = SimpleMaterial(
    color: UIColor(red: 0.29, green: 0.52, blue: 0.71, alpha: 1), roughness: 0.6,
    isMetallic: false)
  // The bridge's greybox surfaces.
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
    case .ground: ground
    case .concrete: stone
    case .shelter: wall
    case .depot: metal
    case .hazard: rust
    case .asphalt: asphalt
    case .steel: steel
    case .granite: granite
    case .vehicle: vehicleBody
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
    let visual = Entity()
    let color: UIColor
    let width: Float
    switch member {
    case .miki:
      color = UIColor(red: 0.25, green: 0.65, blue: 0.59, alpha: 1)
      width = 0.38
    case .laura:
      color = UIColor(red: 0.9, green: 0.61, blue: 0.29, alpha: 1)
      width = 0.31
    case .tom:
      color = UIColor(red: 0.38, green: 0.51, blue: 0.81, alpha: 1)
      width = 0.49
    }
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
    if point.id == RelayHouse.PointID.transmitter.rawValue {
      entity.addChild(
        block(size: [0.48, 0.32, 0.025], at: [0, 0.12, 0.315], material: signal))
      entity.addChild(
        block(size: [0.05, 0.9, 0.05], at: [0.28, 0.9, 0], material: metal))
    }
    // The transmitter's status light and the regulator itself change with the mission, so
    // GameWorld adds them.
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
