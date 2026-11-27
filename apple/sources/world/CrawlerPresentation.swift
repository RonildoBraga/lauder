import RealityKit
import simd

/// Presents a pack crawler from its movement (issue #208): its facing, its legs swinging as it
/// walks, folded and unfolding, the crouch and warning glow of a wind-up, the tip into a ram and
/// its collapse. It reads the simulation's values and never changes them.
@MainActor
final class CrawlerPresentation {
  /// How fast the legs swing while it walks, in radians a second.
  static let stride: Float = 16
  private let visual: Entity
  private let legs: [Entity]
  private let glow: ModelEntity
  private var gait: Float = 0
  private var time: Float = 0
  private var unfolded: Float = 0

  init(id: String, visual: Entity) {
    self.visual = visual
    func part(_ label: String) -> Entity {
      let name = "crawler_" + label.replacingOccurrences(of: " ", with: "_")
      guard let entity = visual.findEntity(named: name) else {
        preconditionFailure("The Blender crawler export lacks \(name). Export the model again.")
      }
      return entity
    }
    legs = (1...4).map { part("leg \($0)") }
    let sensor = part("sensor")
    // The guard's own unlit red, so the pack reads as its machines.
    let red = UnlitMaterial(color: .red)
    if var model = sensor.components[ModelComponent.self] {
      model.materials = model.materials.map { _ in red }
      sensor.components.set(model)
    }
    var hot = UnlitMaterial(color: .init(red: 1, green: 0.35, blue: 0.25, alpha: 1))
    hot.blending = .transparent(opacity: .init(floatLiteral: 0.55))
    glow = ModelEntity(mesh: .generateSphere(radius: 0.09), materials: [hot])
    glow.name = "hostile.\(id).warning"
    glow.isEnabled = false
    sensor.addChild(glow)
  }

  func update(_ crawler: Crawler, visible: Bool, dt: Float) {
    time += dt
    let awake: Bool =
      switch crawler.phase {
      case .hidden, .folded, .cleared: false
      default: true
      }
    // Unfolding eases the legs out from under the body and lifts it.
    unfolded += (awake ? 1 : -1) * dt / Crawler.unfoldTime
    unfolded = max(0, min(1, unfolded))
    if crawler.isWalking {
      gait = (gait + Self.stride * dt).truncatingRemainder(dividingBy: 2 * .pi)
    }
    // Each leg keeps Blender's frame under the scene file's turned root: x runs across it.
    for (index, leg) in legs.enumerated() {
      let side: Float = index == 0 || index == 3 ? -1 : 1
      let swing = crawler.isWalking ? sin(gait + (index % 2 == 0 ? 0 : .pi)) * 0.55 : 0
      let tuck = (1 - unfolded) * 0.9 * side
      leg.orientation =
        simd_quatf(angle: tuck, axis: [0, 1, 0]) * simd_quatf(angle: swing, axis: [1, 0, 0])
    }
    let yaw = simd_quatf(angle: Movement.yaw(towards: crawler.facing), axis: [0, 1, 0])
    var pitch: Float = 0
    var drop: Float = (1 - unfolded) * 0.12
    var roll: Float = 0
    switch crawler.phase {
    case .windingUp:
      // A crouch that deepens through the wind-up, nose down towards its line.
      pitch = -0.12 * crawler.windUp
      drop += 0.06 * crawler.windUp
    case .ramming:
      pitch = -0.2
    case .down:
      roll = 1.4 * crawler.fallen
      drop += 0.1 * crawler.fallen
    default:
      break
    }
    visual.orientation =
      yaw * simd_quatf(angle: pitch, axis: [1, 0, 0]) * simd_quatf(angle: roll, axis: [0, 0, 1])
    visual.position = [0, -drop, 0]
    glow.isEnabled = visible && crawler.phase == .windingUp
    glow.scale = SIMD3(repeating: 0.8 + 0.4 * abs(sin(time * 16)))
  }
}
