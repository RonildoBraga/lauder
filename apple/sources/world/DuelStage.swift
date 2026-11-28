import AVFAudio
import RealityKit
import UIKit
import simd

enum CombatSound: String, CaseIterable {
  case swordSwing = "sword-swing"
  case strikeBody = "strike-body"
  case strikeBlock = "strike-block"
}

/// Plain geometry and sound consume authoritative phases/events; they never award a hit.
@MainActor
final class DuelStage {
  let root = Entity()

  private struct Figure {
    let body: Entity
    let shape: Entity
    let torso: ModelEntity
    let weapon: Entity
    let shield: ModelEntity
    let material: SimpleMaterial
    var previous: SIMD2<Float>
    var stride: Float = 0
  }

  private var hero: Figure
  private var enemy: Figure
  private let focusRing = Entity()
  private var players: [CombatSound: AVAudioPlayer] = [:]
  private let flash = SimpleMaterial(color: .white, roughness: 0.8, isMetallic: false)

  init() {
    hero = Self.figure(
      name: "hero", color: UIColor(red: 0.22, green: 0.58, blue: 0.61, alpha: 1),
      position: [0, 2.5], shield: true)
    enemy = Self.figure(
      name: "enemy", color: UIColor(red: 0.64, green: 0.36, blue: 0.2, alpha: 1),
      position: [0, -1.5], shield: false)
    root.name = "duel.stage"
    root.addChild(hero.body)
    root.addChild(enemy.body)
    focusRing.name = "duel.focus-ring"
    focusRing.isEnabled = false
    let segments = 16
    let radius: Float = 0.56
    let mesh = MeshResource.generateBox(
      size: [0.035, 0.018, 2 * radius * sin(.pi / Float(segments))])
    let ringMaterial = SimpleMaterial(
      color: UIColor(red: 0.95, green: 0.82, blue: 0.42, alpha: 1),
      roughness: 1, isMetallic: false)
    for index in 0..<segments {
      let angle = Float(index) * 2 * .pi / Float(segments)
      let segment = ModelEntity(mesh: mesh, materials: [ringMaterial])
      segment.position = [sin(angle) * radius, 0.018, cos(angle) * radius]
      segment.orientation = simd_quatf(angle: angle + .pi / 2, axis: [0, 1, 0])
      focusRing.addChild(segment)
    }
    root.addChild(focusRing)
    root.addChild(
      Self.box(
        size: [14.8, 0.2, 10.8], position: [0, -0.12, 0],
        color: UIColor(red: 0.31, green: 0.34, blue: 0.35, alpha: 1)))
    for (index, obstacle) in DuelArena.obstacles.enumerated() {
      let centre = (obstacle.minimum + obstacle.maximum) / 2
      let size = obstacle.maximum - obstacle.minimum
      // Foreground curbs retain a visible boundary without hiding feet in the lower camera.
      // Collision stays in the unchanged flat arena geometry.
      let foreground =
        obstacle.minimum.x >= DuelArena.halfWidth || obstacle.minimum.y >= DuelArena.halfDepth
      let height: Float = foreground ? 0.18 : 0.7
      let box = Self.box(
        size: [size.x, height, size.y], position: [centre.x, height / 2, centre.y],
        color: UIColor(red: 0.43, green: 0.46, blue: 0.46, alpha: 1))
      box.name = "duel.blocker.\(index)"
      root.addChild(box)
    }
    for x in stride(from: -6, through: 6, by: 2) {
      root.addChild(
        Self.box(
          size: [0.018, 0.01, 10], position: [Float(x), -0.01, 0],
          color: UIColor(white: 0.38, alpha: 1)))
    }
    for z in stride(from: -4, through: 4, by: 2) {
      root.addChild(
        Self.box(
          size: [14, 0.01, 0.018], position: [0, -0.01, Float(z)],
          color: UIColor(white: 0.38, alpha: 1)))
    }
    let key = DirectionalLight()
    key.light.intensity = 5_500
    key.look(at: .zero, from: [3, 8, 5], relativeTo: nil)
    root.addChild(key)
    let fill = DirectionalLight()
    fill.light.intensity = 1_800
    fill.look(at: .zero, from: [-5, 4, -2], relativeTo: nil)
    root.addChild(fill)
    for sound in CombatSound.allCases {
      guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav"),
        let player = try? AVAudioPlayer(contentsOf: url)
      else {
        preconditionFailure("A checked combat sound could not load: \(sound.rawValue)")
      }
      player.volume = 0.35
      player.prepareToPlay()
      players[sound] = player
    }
  }

  func present(_ simulation: DuelSimulation, deltaTime: Float) {
    pose(&hero, fighter: simulation.hero, deltaTime: deltaTime)
    pose(&enemy, fighter: simulation.enemy, deltaTime: deltaTime)
    focusRing.position = [simulation.enemy.position.x, 0, simulation.enemy.position.y]
    focusRing.isEnabled = simulation.isFocused
  }

  func play(_ events: [DuelEvent]) {
    for event in events {
      let sound: CombatSound?
      switch event {
      case .swung: sound = .swordSwing
      case .hit: sound = .strikeBody
      case .blocked, .guardBroken: sound = .strikeBlock
      default: sound = nil
      }
      guard let sound, let player = players[sound] else { continue }
      player.currentTime = 0
      player.play()
    }
  }

  func stopFeedback() {
    for player in players.values {
      player.stop()
      player.currentTime = 0
    }
  }

  private func pose(_ figure: inout Figure, fighter: DuelFighter, deltaTime: Float) {
    let distance = simd_distance(figure.previous, fighter.position)
    figure.stride += distance * 7
    figure.previous = fighter.position
    figure.body.position = [fighter.position.x, 0, fighter.position.y]
    figure.body.orientation = simd_quatf(angle: fighter.yaw, axis: [0, 1, 0])
    figure.shape.position.y = distance > 0.0001 ? abs(sin(figure.stride)) * 0.035 : 0
    figure.shape.orientation = .init()
    figure.weapon.position = [0, 1.08, 0]
    figure.weapon.orientation = .init()
    figure.shield.position = fighter.guarding ? [-0.18, 1.05, -0.52] : [-0.48, 0.95, -0.08]
    figure.shield.orientation = simd_quatf(
      angle: fighter.guarding ? 0 : -.pi / 3, axis: [0, 1, 0])
    figure.torso.model?.materials = [fighter.hitFlash > 0 ? flash : figure.material]
    guard fighter.health > 0 else {
      figure.shape.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
      figure.shape.position.y = 0.25
      return
    }
    guard let action = fighter.action else { return }
    switch action.kind {
    case .slash, .sweep:
      figure.weapon.orientation = simd_quatf(angle: action.bladeAngle, axis: [0, 1, 0])
    case .thrust:
      figure.weapon.position.z = -(action.bladeReach - 2.05)
    case .dodge:
      figure.shape.position.y = 0.12 * sin(action.progress * .pi)
      figure.shape.orientation = simd_quatf(angle: -0.38, axis: [1, 0, 0])
    }
  }

  private static func figure(
    name: String, color: UIColor, position: SIMD2<Float>, shield hasShield: Bool
  ) -> Figure {
    let body = Entity()
    body.name = "duel.\(name)"
    let shape = Entity()
    shape.name = "\(name).shape"
    body.addChild(shape)
    let material = SimpleMaterial(color: color, roughness: 0.9, isMetallic: false)
    let torso = ModelEntity(mesh: .generateBox(size: [0.64, 0.73, 0.4]), materials: [material])
    torso.position = [0, 1.03, 0]
    shape.addChild(torso)
    shape.addChild(box(size: [0.42, 0.4, 0.37], position: [0, 1.62, -0.01], color: color))
    for x in [Float(-0.18), 0.18] {
      shape.addChild(
        box(size: [0.23, 0.56, 0.26], position: [x, 0.36, 0], color: .darkGray))
      shape.addChild(
        box(size: [0.25, 0.15, 0.4], position: [x, 0.075, -0.08], color: .darkGray))
    }
    shape.addChild(
      box(size: [0.32, 0.07, 0.08], position: [0, 1.63, -0.22], color: .black))
    let weapon = Entity()
    let blade = box(
      size: [hasShield ? 0.13 : 0.17, 0.1, hasShield ? 1.8 : 2.05],
      position: [0, 0, hasShield ? -0.9 : -1.025], color: .lightGray)
    weapon.addChild(blade)
    weapon.addChild(box(size: [0.35, 0.15, 0.13], position: [0, 0, -0.15], color: .darkGray))
    shape.addChild(weapon)
    let shield = box(
      size: [0.68, 0.72, 0.13], position: [-0.48, 0.95, -0.08],
      color: UIColor(red: 0.7, green: 0.75, blue: 0.73, alpha: 1))
    shield.isEnabled = hasShield
    shape.addChild(shield)
    return Figure(
      body: body, shape: shape, torso: torso, weapon: weapon,
      shield: shield, material: material, previous: position)
  }

  private static func box(size: SIMD3<Float>, position: SIMD3<Float>, color: UIColor)
    -> ModelEntity
  {
    let entity = ModelEntity(
      mesh: .generateBox(size: size),
      materials: [SimpleMaterial(color: color, roughness: 0.9, isMetallic: false)])
    entity.position = position
    return entity
  }
}
