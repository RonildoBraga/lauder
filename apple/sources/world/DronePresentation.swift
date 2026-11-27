import RealityKit
import simd

/// Presents a scout drone from its flight (issue #201): where it flies and faces, its spinning
/// rotors, the eye's warning glow, its tilt into a dive, its shadow on the snow and its fall.
/// It reads the simulation's values and never changes them.
@MainActor
final class DronePresentation {
  /// The model's body centre above its origin, which stands on the ground in Blender.
  static let modelCentre: Float = 0.115
  /// How fast the rotors turn while it flies, in radians a second.
  static let rotorSpeed: Float = 38
  private let visual: Entity
  private let rotors: [Entity]
  private let glow: ModelEntity
  private let shadow: ModelEntity
  private var spin: Float = 0
  private var time: Float = 0

  init(id: String, visual: Entity, shadowParent: Entity) {
    self.visual = visual
    func part(_ label: String) -> Entity {
      let name = "scout_drone_" + label.replacingOccurrences(of: " ", with: "_")
      guard let entity = visual.findEntity(named: name) else {
        preconditionFailure("The Blender drone export lacks \(name). Export the model again.")
      }
      return entity
    }
    rotors = (1...4).map { part("rotor \($0)") }
    let eye = part("eye")
    // The guard's own unlit red, so the drones read as its machines.
    let red = UnlitMaterial(color: .red)
    func colour(_ entity: Entity) {
      if var model = entity.components[ModelComponent.self] {
        model.materials = model.materials.map { _ in red }
        entity.components.set(model)
      }
      for child in entity.children { colour(child) }
    }
    colour(eye)
    var hot = UnlitMaterial(color: .init(red: 1, green: 0.35, blue: 0.25, alpha: 1))
    hot.blending = .transparent(opacity: .init(floatLiteral: 0.55))
    glow = ModelEntity(mesh: .generateSphere(radius: 0.11), materials: [hot])
    glow.name = "hostile.\(id).warning"
    glow.isEnabled = false
    eye.addChild(glow)
    var dark = UnlitMaterial(color: .black)
    dark.blending = .transparent(opacity: .init(floatLiteral: 0.3))
    shadow = ModelEntity(
      mesh: .generateCylinder(height: 0.01, radius: ScoutDrone.radius), materials: [dark])
    shadow.name = "hostile.\(id).shadow"
    shadow.isEnabled = false
    shadowParent.addChild(shadow)
  }

  /// Where the body entity stands for `drone`, given that a figure's model is lowered by half
  /// a body inside its visual (SceneStyle.figure).
  static func bodyPosition(of drone: ScoutDrone) -> SIMD3<Float> {
    [drone.position.x, drone.height - modelCentre + PartyBody.height / 2, drone.position.y]
  }

  func update(_ drone: ScoutDrone, visible: Bool, dt: Float) {
    time += dt
    if !drone.isDown {
      spin = (spin + Self.rotorSpeed * dt).truncatingRemainder(dividingBy: 2 * .pi)
    }
    // Each rotor keeps Blender's frame under the scene file's turned root, so its up is z.
    for rotor in rotors {
      rotor.orientation = simd_quatf(angle: spin, axis: [0, 0, 1])
    }
    let yaw = simd_quatf(angle: Movement.yaw(towards: drone.facing), axis: [0, 1, 0])
    let pitch: Float =
      switch drone.phase {
      case .diving: -18 * .pi / 180
      case .climbing: 10 * .pi / 180
      case .down: -35 * .pi / 180
      default: 0
      }
    let roll: Float = drone.isDown ? 50 * .pi / 180 : 0
    visual.orientation =
      yaw * simd_quatf(angle: pitch, axis: [1, 0, 0]) * simd_quatf(angle: roll, axis: [0, 0, 1])
    glow.isEnabled = visible && drone.phase == .warning
    glow.scale = SIMD3(repeating: 0.85 + 0.3 * abs(sin(time * 14)))
    shadow.isEnabled = visible && !drone.isDown
    shadow.position = [drone.position.x, SceneStyle.groundMarkerHeight, drone.position.y]
    // The shadow tightens as the drone comes down, which shows how high it flies.
    let spread = 0.7 + 0.3 * min(1, drone.height / ScoutDrone.cruiseHeight)
    shadow.scale = [spread, 1, spread]
  }
}
