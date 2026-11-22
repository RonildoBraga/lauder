import RealityKit
import UIKit

@MainActor
struct SceneStyle {
  let unitBox = MeshResource.generateBox(size: 1)

  // The level's look comes from its scene file, and the party's and the hostiles' from their
  // models' scene files, all exported by Blender (ADR 0002). The gameplay signals keep their own
  // colours here.
  /// A level without a scene file, such as the combat yard or a test's: its boxes as plain
  /// blocks.
  let scenery = SimpleMaterial(
    color: UIColor(red: 0.55, green: 0.57, blue: 0.56, alpha: 1), roughness: 0.9,
    isMetallic: false)
  /// Such a level's ground, in the palette's snow (the visual direction).
  let snow = SimpleMaterial(
    color: UIColor(red: 236 / 255, green: 233 / 255, blue: 226 / 255, alpha: 1), roughness: 1,
    isMetallic: false)
  /// The party's weapons.
  let gear = SimpleMaterial(
    color: UIColor(red: 0.16, green: 0.25, blue: 0.25, alpha: 1), roughness: 0.9,
    isMetallic: false)
  /// The palette's colours that the salvage yard's greybox adds (the visual direction): rust for
  /// a barrier or a warning, ink for a pole, faded teal for old paintwork, and stone.
  let rust = SceneStyle.palette(166, 90, 67)
  let ink = SceneStyle.palette(54, 65, 75)
  let fadedTeal = SceneStyle.palette(94, 124, 128)
  let stone = SceneStyle.palette(183, 172, 157)
  /// Amber: things to use, and the leader's disc.
  let warm = UnlitMaterial(color: UIColor(red: 1, green: 0.75, blue: 0.4, alpha: 1))
  /// Threats: a hostile's aim and shots, and the assisted target's marker.
  let threat = UnlitMaterial(color: UIColor(red: 0.95, green: 0.3, blue: 0.24, alpha: 1))
  let signal = UnlitMaterial(color: UIColor(red: 0.62, green: 0.87, blue: 0.77, alpha: 1))
  /// How much larger than their authored sizes the world markers show: the leader's disc, order
  /// rings, the refusal cross, the aim marker and the aim and shot lines.
  let markerScale: Float

  /// The camera the world markers were made for: the bridge's before the frozen look, about
  /// 14 m from its target with a 42° lens.
  static let markerCamera = (offset: SIMD3<Float>(0, 10, 9.9), fieldOfView: Float(42))

  init(markerScale: Float = 1) {
    self.markerScale = markerScale
  }

  /// The marker scale for a level's camera, so that its markers keep a readable size on screen
  /// (the visual direction): how much more of the ground a camera shows across the screen at
  /// its target than the camera the markers were made for, and never less than 1.
  static func markerScale(cameraOffset: SIMD3<Float>, fieldOfView: Float) -> Float {
    func shown(_ offset: SIMD3<Float>, _ fieldOfView: Float) -> Float {
      simd_length(offset) * tan(fieldOfView * .pi / 360)
    }
    return max(
      1, shown(cameraOffset, fieldOfView) / shown(markerCamera.offset, markerCamera.fieldOfView))
  }

  /// A palette colour, from its 8-bit values, as the visual direction sets its materials: matte,
  /// and not metallic.
  private static func palette(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> SimpleMaterial {
    SimpleMaterial(
      color: UIColor(red: red / 255, green: green / 255, blue: blue / 255, alpha: 1), roughness: 1,
      isMetallic: false)
  }

  private static func colour(_ value: SIMD3<Float>) -> UIColor {
    UIColor(red: CGFloat(value.x), green: CGFloat(value.y), blue: CGFloat(value.z), alpha: 1)
  }

  /// A box of this size, centred at `position`: the unit box, scaled.
  func block(size: SIMD3<Float>, at position: SIMD3<Float>, material: any Material)
    -> ModelEntity
  {
    let model = ModelEntity(mesh: unitBox, materials: [material])
    model.scale = size
    model.position = position
    return model
  }

  /// A line for an aim or a shot: the unit box, which the fight stretches between the line's
  /// ends.
  func line(_ material: any Material) -> ModelEntity {
    ModelEntity(mesh: unitBox, materials: [material])
  }

  /// The leader's mark: a solid disc on the ground beneath the body's centre, in the warm
  /// colour.
  func leaderMarker() -> ModelEntity {
    let disc = ModelEntity(mesh: .generateCylinder(height: 0.015, radius: 0.34), materials: [warm])
    disc.position.y = -PartyBody.height / 2 + 0.025
    disc.scale = [markerScale, 1, markerScale]
    return disc
  }

  /// The assisted target's mark: a disc on the ground beneath it, in the threats' colour.
  func targetMarker() -> ModelEntity {
    let disc = ModelEntity(
      mesh: .generateCylinder(height: 0.012, radius: 0.48), materials: [threat])
    disc.scale = [markerScale, 1, markerScale]
    return disc
  }

  /// A member of the party, from the model named after them in `blender/assets`.
  func partyMember(_ member: PartyMember) -> Entity {
    figure(member.rawValue)
  }

  /// A hostile, from the `hostile` model: the party's shape in a dark red that reads as a threat.
  func hostile() -> Entity {
    figure("hostile")
  }

  /// A party weapon, with its origin at the grip and its barrel ahead along -z. The simple
  /// shapes differ in length and weight; the same profile locates its visual and shot muzzle.
  func weapon(for kind: Weapon.Kind) -> Entity {
    let grip = Entity()
    let size: SIMD3<Float> =
      switch kind {
      case .carbine, .rifle: [0.07, 0.08, 0.55]
      case .lightBurst: [0.065, 0.07, 0.4]
      case .closeScatter: [0.13, 0.11, 0.65]
      }
    grip.name =
      switch kind {
      case .carbine: "leader.carbine"
      case .lightBurst: "weapon.light-burst"
      case .closeScatter: "weapon.close-scatter"
      case .rifle: "weapon.rifle"
      }
    let barrel = WeaponPose.profile(for: kind).barrel
    grip.addChild(
      block(
        size: size, at: [0, 0, size.z / 2 - barrel], material: gear))
    return grip
  }

  /// Each member's colour, as their model's clothing shows it.
  static func colour(of member: PartyMember) -> UIColor {
    switch member {
    case .miki: UIColor(red: 0.25, green: 0.65, blue: 0.59, alpha: 1)
    case .laura: UIColor(red: 0.9, green: 0.61, blue: 0.29, alpha: 1)
    case .tom: UIColor(red: 0.38, green: 0.51, blue: 0.81, alpha: 1)
    }
  }

  /// Where a companion is going: a flat ring on the ground in their colour (ADR 0003, phase
  /// S3), unlike the leader's solid disc.
  func orderMarker(for member: PartyMember) -> Entity {
    let ring = Entity()
    let material = UnlitMaterial(color: Self.colour(of: member))
    let segments = 10
    let radius: Float = 0.36
    let length = 2 * radius * sin(.pi / Float(segments)) + 0.02
    for index in 0..<segments {
      let angle = 2 * .pi * Float(index) / Float(segments)
      let segment = block(
        size: [length, 0.02, 0.07], at: [radius * sin(angle), 0, radius * cos(angle)],
        material: material)
      segment.orientation = simd_quatf(angle: angle, axis: [0, 1, 0])
      ring.addChild(segment)
    }
    ring.scale = [markerScale, 1, markerScale]
    return ring
  }

  /// A brief cross where an order's point cannot be reached, upright in its own x-y plane so
  /// that turned towards the camera it reads as an X.
  func refusalCross() -> Entity {
    let cross = Entity()
    for angle in [Float.pi / 4, -Float.pi / 4] {
      let bar = block(
        size: [0.8 * markerScale, 0.12 * markerScale, 0.02], at: .zero, material: threat)
      bar.orientation = simd_quatf(angle: angle, axis: [0, 0, 1])
      cross.addChild(bar)
    }
    return cross
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
      let colour = Self.colour(light.color)
      let entity: Entity
      switch light.kind {
      case .sun(let source, let shadowDistance):
        let sun = DirectionalLight()
        sun.light.color = colour
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
          color: colour, intensity: light.intensity, attenuationRadius: radius)
        point.position = position
        entity = point
      case .spot(let position, let target, let radius, let innerAngle, let outerAngle, let shadow):
        // RealityKit's spot angles are full cone widths, as the layout's are: a 60° outer angle
        // 10 m above the ground lights a radius of 10 tan 30° = 5.77 m (ADR 0002).
        let spot = SpotLight()
        spot.light = SpotLightComponent(
          color: colour, intensity: light.intensity, innerAngleInDegrees: innerAngle,
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
