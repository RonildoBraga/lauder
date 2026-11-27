import RealityKit
import simd

/// The loaded C model's named rigid joints. Its meshes and dimensions come from Blender; this
/// presenter supplies a crawl from actual movement and keeps the visible barrels on the rays.
@MainActor
final class RobotPresentation {
  private struct Leg {
    let connector: Entity
    let swivel: Entity
    let upper: Entity
    let lower: Entity
    let ankle: Entity
  }

  private struct FallenLeg {
    let entity: Entity
    let start: Transform
    let end: Transform
    var elapsed: Float = 0
  }

  private let visual: Entity
  private let root: Entity
  private let legs: [Leg]
  private let guns: [Entity]
  private let gunPositions: [SIMD3<Float>]
  private let sensor: Entity
  private let debrisRoot = Entity()
  private var debris: [FallenLeg] = []
  private var detachedLegs: Set<Int> = []
  private var motion = RobotMotion()
  private static let fallTime: Float = 0.6

  init(visual: Entity, debrisParent: Entity) {
    self.visual = visual
    func part(_ label: String) -> Entity {
      let name =
        "spider_bot_heavy_"
        + label.replacingOccurrences(of: "-", with: "_")
        .replacingOccurrences(of: " ", with: "_")
      guard let entity = visual.findEntity(named: name) else {
        preconditionFailure("The Blender robot export lacks \(name). Export the model again.")
      }
      return entity
    }
    root = part("root")
    legs = RobotModelGeometry.legs.map {
      Leg(
        connector: part("\($0.name) connector"),
        swivel: part("\($0.name) hip pivot"), upper: part("\($0.name) upper pivot"),
        lower: part("\($0.name) lower pivot"), ankle: part("\($0.name) ankle pivot"))
    }
    guns = [part("gun-left recoil"), part("gun-right recoil")]
    gunPositions = guns.map(\.position)
    sensor = part("square sensor")
    let redEye = UnlitMaterial(color: .red)
    func colourEye(_ entity: Entity) {
      if var model = entity.components[ModelComponent.self] {
        model.materials = [redEye]
        entity.components.set(model)
      }
      for child in entity.children { colourEye(child) }
    }
    colourEye(sensor)
    debrisRoot.name = "robot.leg-debris"
    debrisParent.addChild(debrisRoot)
  }

  func reset(position: SIMD2<Float>, facing: SIMD2<Float>) {
    for leg in legs { leg.connector.isEnabled = true }
    for fallen in debris { fallen.entity.removeFromParent() }
    debris.removeAll()
    detachedLegs.removeAll()
    motion.reset(position: position, facing: facing)
    update(
      position: position, facing: facing, brace: 0, gunDirections: [], gunRecoil: .zero,
      down: false, dt: 0)
  }

  func update(
    position: SIMD2<Float>, facing: SIMD2<Float>, brace: Float,
    gunDirections: [SIMD3<Float>], gunRecoil: SIMD2<Float>, down: Bool,
    detachedLegs missing: Set<Int> = [], bodyDrop: Float? = nil, dt: Float
  ) {
    let bodyYaw = Movement.yaw(towards: facing)
    visual.orientation = simd_quatf(angle: bodyYaw, axis: [0, 1, 0])
    visual.position = .zero
    let lowered = down ? 1 : max(0, min(1, brace))
    let drop = max(0, bodyDrop ?? RobotModelGeometry.braceDepth * lowered)
    root.position.z = -drop
    for index in legs.indices where missing.contains(index) && !detachedLegs.contains(index) {
      detach(index)
    }
    advanceDebris(dt: dt)
    let poses = motion.advance(
      position: position, facing: facing, brace: lowered,
      detachedLegs: detachedLegs, bodyDrop: drop, dt: down ? 0 : dt)
    for (index, pose) in poses.enumerated() where !detachedLegs.contains(index) {
      let leg = legs[index]
      leg.swivel.orientation = simd_quatf(angle: pose.swivel, axis: [0, 0, 1])
      leg.upper.orientation = simd_quatf(angle: pose.upper, axis: [0, 1, 0])
      leg.lower.orientation = simd_quatf(angle: pose.lower, axis: [0, 1, 0])
      leg.ankle.orientation = pose.ankle
    }
    for index in guns.indices {
      let direction =
        gunDirections.indices.contains(index) ? gunDirections[index] : SIMD3<Float>.zero
      let yaw =
        simd_length(direction) > 0.001
        ? Movement.yaw(towards: [direction.x, direction.z]) - bodyYaw : 0
      let pitch = simd_length(direction) > 0.001 ? asin(max(-1, min(1, direction.y))) : 0
      // Source +z maps to game +y; source +x maps to game -x.
      let rotation =
        simd_quatf(angle: yaw, axis: [0, 0, 1])
        * simd_quatf(angle: -pitch, axis: [1, 0, 0])
      let recoil = gunRecoil[index]
      guns[index].orientation = rotation
      guns[index].position = gunPositions[index] + rotation.act([0, max(0, recoil), 0])
    }
    sensor.isEnabled = !down
  }

  /// Freeze the complete currently posed assembly. Its clone lives outside the moving body;
  /// source meshes stay shared and the prop adds no physics or collision authority.
  private func detach(_ index: Int) {
    let connector = legs[index].connector
    let world = connector.transformMatrix(relativeTo: nil)
    let prop = connector.clone(recursive: true)
    prop.name = "robot.fallen-leg.\(RobotModelGeometry.legs[index].name)"
    debrisRoot.addChild(prop)
    prop.setTransformMatrix(world, relativeTo: nil)
    let start = Transform(matrix: world)
    var end = start
    let side: Float = RobotModelGeometry.legs[index].hip.x < 0 ? 1 : -1
    let bodyTurn = visual.orientation
    let outward = bodyTurn.act([side, 0, 0])
    let axis = bodyTurn.act([0, 0, side])
    end.rotation = simd_quatf(angle: 0.65, axis: axis) * start.rotation
    end.translation += outward * 0.25
    prop.setTransformMatrix(end.matrix, relativeTo: nil)
    end.translation.y -= prop.visualBounds(relativeTo: nil).min.y
    prop.setTransformMatrix(world, relativeTo: nil)
    debris.append(FallenLeg(entity: prop, start: start, end: end))
    detachedLegs.insert(index)
    connector.isEnabled = false
  }

  private func advanceDebris(dt: Float) {
    let elapsed = max(0, min(dt, 1 / 15))
    guard elapsed > 0 else { return }
    for index in debris.indices where debris[index].elapsed < Self.fallTime {
      debris[index].elapsed = min(Self.fallTime, debris[index].elapsed + elapsed)
      let fallen = debris[index]
      let progress = fallen.elapsed / Self.fallTime
      let amount = progress * progress
      var pose = fallen.start
      pose.rotation = simd_slerp(fallen.start.rotation, fallen.end.rotation, progress)
      pose.translation = simd_mix(
        fallen.start.translation, fallen.end.translation, SIMD3(repeating: amount))
      fallen.entity.setTransformMatrix(pose.matrix, relativeTo: nil)
      let lowest = fallen.entity.visualBounds(relativeTo: nil).min.y
      if lowest < 0 {
        pose.translation.y -= lowest
        fallen.entity.setTransformMatrix(pose.matrix, relativeTo: nil)
      }
    }
  }
}
