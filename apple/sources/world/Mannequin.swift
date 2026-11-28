import RealityKit
import UIKit
import simd

/// A plain rigid mannequin driven by the checked Blender armature, not an independent combat clock.
@MainActor
final class Mannequin {
  let root = Entity()
  /// Socket axes are -Z through the palm and +Y up in the neutral rest pose.
  let rightHand = Entity()
  let leftHand = Entity()
  private let library: MannequinLibrary
  private let joints: [Entity]
  private var proxies: [(entity: ModelEntity, material: SimpleMaterial)] = []
  private let flash = SimpleMaterial(color: .white, roughness: 1, isMetallic: false)
  private var previousPosition: SIMD2<Float>?
  private var previousFighter: DuelFighter?
  private var previousRight: SIMD3<Float>?
  private var previousLeft: SIMD3<Float>?
  private var idleTime: Float = 0
  private var gaitPhase: Float = 0
  private(set) var rightGripGap: Float = 0
  private(set) var leftGripGap: Float = 0
  private(set) var selectedClip = "idle"

  init(name: String, color: UIColor, library: MannequinLibrary = .shared) {
    self.library = library
    joints = library.bones.map { bone in
      let entity = Entity()
      entity.name = "\(name).bone.\(bone.name)"
      return entity
    }
    root.name = "\(name).mannequin"
    for index in joints.indices {
      let parent = library.bones[index].parent
      (parent < 0 ? root : joints[parent]).addChild(joints[index])
    }
    for proxy in library.proxies {
      let size = SIMD3<Float>(proxy.size[0], proxy.size[1], proxy.size[2])
      let material = SimpleMaterial(
        color: proxy.accent ? color : UIColor(white: 0.24, alpha: 1), roughness: 0.9,
        isMetallic: false)
      let entity = ModelEntity(mesh: .generateBox(size: size), materials: [material])
      entity.name = "\(name).proxy.\(proxy.name)"
      entity.transform = Transform(
        rotation: simd_quatf(
          vector: SIMD4(proxy.rotation[0], proxy.rotation[1], proxy.rotation[2], proxy.rotation[3])),
        translation: SIMD3(proxy.position[0], proxy.position[1], proxy.position[2]))
      joints[proxy.bone].addChild(entity)
      proxies.append((entity, material))
    }
    for (side, socket) in [("L", leftHand), ("R", rightHand)] {
      let q = library.sockets[side]!
      socket.name = "\(name).socket.hand.\(side)"
      socket.orientation = simd_quatf(vector: SIMD4(q[0], q[1], q[2], q[3]))
      joints[library.index("hand.\(side)")].addChild(socket)
    }
    apply(library.sample("idle", time: 0))
  }

  func resetMotion() {
    previousPosition = nil
    previousFighter = nil
    previousRight = nil
    previousLeft = nil
    idleTime = 0
    gaitPhase = 0
  }

  func pose(
    fighter: DuelFighter, deltaTime: Float, rightHand: SIMD3<Float>? = nil,
    leftHand: SIMD3<Float>? = nil
  ) {
    if deltaTime <= 0, previousFighter == fighter, previousRight == rightHand,
      previousLeft == leftHand
    {
      return
    }
    let displacement =
      deltaTime > 0 ? fighter.position - (previousPosition ?? fighter.position) : .zero
    previousPosition = fighter.position
    previousFighter = fighter
    previousRight = rightHand
    previousLeft = leftHand
    idleTime += max(0, deltaTime)
    let distance = simd_length(displacement)
    var time = idleTime
    selectedClip = "idle"
    if let action = fighter.action {
      selectedClip =
        switch action.kind {
        case .slash: "slash"
        case .sweep: "sweep"
        case .thrust: "thrust"
        case .dodge: "dodge"
        }
      time = library.actionTime(selectedClip, phase: action.phase, progress: action.phaseProgress)
    } else if fighter.stagger > 0 {
      selectedClip = "hit"
      time = library.hitTime(
        remaining: fighter.stagger, duration: DuelSimulation.guardBreakStaggerDuration)
    } else if fighter.hitFlash > 0 {
      selectedClip = "hit"
      time = library.hitTime(remaining: fighter.hitFlash, duration: DuelSimulation.hitFlashDuration)
    } else if distance > 0.00001, deltaTime > 0 {
      let local = simd_quatf(angle: -fighter.yaw, axis: [0, 1, 0]).act(
        [displacement.x, 0, displacement.y])
      let speed = distance / deltaTime
      selectedClip =
        abs(local.x) > abs(local.z) * 1.2
        ? (local.x < 0 ? "strafe_left" : "strafe_right")
        : (local.z > 0 ? "backward" : (speed < 1.6 ? "walk" : "run"))
      let clip = library.clips[selectedClip]!
      gaitPhase += distance / max(0.1, clip.nominalSpeed * clip.duration)
      time = gaitPhase * clip.duration
    } else if fighter.guarding {
      selectedClip = "guard"
    }
    var local = library.sample(selectedClip, time: time)
    if fighter.action != nil, fighter.hitFlash > 0 {
      library.recoil(&local, remainingFlash: fighter.hitFlash)
    }
    var world = library.world(local)
    if fighter.guarding { library.brace(&world) }
    library.ground(&world)
    rightGripGap = rightHand.map { library.fitArm(side: "R", target: $0, world: &world) } ?? 0
    leftGripGap = leftHand.map { library.fitArm(side: "L", target: $0, world: &world) } ?? 0
    apply(library.local(world))
    root.position = fighter.health > 0 ? .zero : [0, 0.25, 0]
    root.orientation =
      fighter.health > 0
      ? .init() : simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
    for proxy in proxies {
      proxy.entity.model?.materials = [fighter.hitFlash > 0 ? flash : proxy.material]
    }
  }

  private func apply(_ pose: [MannequinJointPose]) {
    for index in joints.indices {
      joints[index].position = pose[index].position
      joints[index].orientation = pose[index].rotation
    }
  }
}
