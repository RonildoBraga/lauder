import RealityKit
import UIKit

@MainActor
struct SceneStyle {
  let unitBox = MeshResource.generateBox(size: 1)
  let unitSphere = MeshResource.generateSphere(radius: 1)

  /// The level's surfaces, made from the shared palette that Blender edits (`Surfaces.swift`).
  private let surfaces: [Level.Surface: SimpleMaterial]

  // The stand-ins and the gameplay signals keep their own colours here: they are not level
  // surfaces, so the palette does not change them.
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

  init(palette: [Level.Surface: Level.Finish] = Surfaces.palette) {
    surfaces = palette.mapValues { Self.makeMaterial($0) }
  }

  func material(for surface: Level.Surface) -> SimpleMaterial {
    guard let material = surfaces[surface] else {
      preconditionFailure("The palette has no finish for \(surface).")
    }
    return material
  }

  private static func makeMaterial(_ finish: Level.Finish) -> SimpleMaterial {
    var material = SimpleMaterial(
      color: color(finish.color), roughness: .float(finish.roughness), isMetallic: false)
    material.metallic = .float(finish.metallic)
    return material
  }

  private static func color(_ value: SIMD3<Float>) -> UIColor {
    UIColor(red: CGFloat(value.x), green: CGFloat(value.y), blue: CGFloat(value.z), alpha: 1)
  }

  /// A greybox vehicle filling its footprint `size`: a car's lower body and cabin, or a taller
  /// van, bus or truck with a band of dark windows.
  func vehicle(size: SIMD3<Float>, at position: SIMD3<Float>) -> Entity {
    let body = material(for: .vehicle)
    let glass = material(for: .glass)
    let vehicle = Entity()
    vehicle.position = position
    let alongZ = size.z >= size.x
    let length = max(size.x, size.z)
    if size.y > 2 {
      vehicle.addChild(block(size: size, at: .zero, material: body))
      let band: SIMD3<Float> =
        alongZ ? [size.x + 0.02, 0.5, length * 0.9] : [length * 0.9, 0.5, size.z + 0.02]
      vehicle.addChild(block(size: band, at: [0, size.y * 0.25, 0], material: glass))
    } else {
      let lower = size.y * 0.55
      vehicle.addChild(
        block(size: [size.x, lower, size.z], at: [0, (lower - size.y) / 2, 0], material: body))
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

  func landmark(for point: Level.PointOfInterest) -> ModelEntity {
    let entity = ModelEntity()
    let size = point.size
    entity.position = point.position + [0, size.y / 2, 0]
    entity.addChild(block(size: size, at: .zero, material: material(for: .metal)))
    entity.addChild(
      block(
        size: [size.x * 0.85, size.y * 0.15, size.z * 1.03], at: [0, -size.y * 0.27, 0],
        material: material(for: .paint)))
    return entity
  }

  /// The level's lights, from its layout file: each shines from its source over the whole level.
  func addLights(_ lights: [Level.Light], to root: Entity) {
    for light in lights {
      let entity = DirectionalLight()
      entity.name = light.name
      entity.light.color = Self.color(light.color)
      entity.light.intensity = light.intensity
      if let distance = light.shadowDistance {
        var shadow = DirectionalLightComponent.Shadow(
          shadowProjection: .automatic(maximumDistance: distance), depthBias: 1)
        shadow.cascades = .fixed(1)
        entity.shadow = shadow
      } else {
        // The light casts shadows only while it has the component; its `shadow` always reads.
        entity.components.remove(DirectionalLightComponent.Shadow.self)
      }
      entity.look(at: .zero, from: light.source, relativeTo: nil)
      root.addChild(entity)
    }
  }
}
