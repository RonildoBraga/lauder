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
    let mannequin: Mannequin
    let weapon: Entity
    let shield: ModelEntity
    let bladeLength: Float
    let hasShield: Bool
  }

  private let hero: Figure
  private let enemy: Figure
  private let focusRing = Entity()
  private let attackWarning = Entity()
  private let sweepWarning = DuelStage.warning(kind: .sweep)
  private let thrustWarning = DuelStage.warning(kind: .thrust)
  private let shortcutDoor = Entity()
  private let healingAvailable = Entity()
  private let healingSpent = Entity()
  private var clearedMarkers: [(Int, Entity)] = []
  private struct WarningKey: Equatable {
    let kind: DuelAction.Kind
    let origin: SIMD2<Float>
    let direction: SIMD2<Float>
    let shortcutOpen: Bool
  }
  private var warningKey: WarningKey?
  private var warningClear = true
  private lazy var sweepFootprint = Self.footprint(of: sweepWarning)
  private lazy var thrustFootprint = Self.footprint(of: thrustWarning)
  private var players: [CombatSound: AVAudioPlayer] = [:]

  init() {
    hero = Self.figure(
      name: "hero", color: UIColor(red: 0.22, green: 0.58, blue: 0.61, alpha: 1),
      shield: true)
    enemy = Self.figure(
      name: "enemy", color: UIColor(red: 0.64, green: 0.36, blue: 0.2, alpha: 1),
      shield: false)
    root.name = "duel.stage"
    root.addChild(hero.body)
    root.addChild(enemy.body)
    enemy.body.isEnabled = false
    attackWarning.name = "duel.attack-warning"
    attackWarning.isEnabled = false
    attackWarning.addChild(sweepWarning)
    attackWarning.addChild(thrustWarning)
    root.addChild(attackWarning)
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
    buildDungeon()
    let key = DirectionalLight()
    key.light.intensity = 3_400
    key.look(at: .zero, from: [3, 8, 5], relativeTo: nil)
    root.addChild(key)
    let fill = DirectionalLight()
    fill.light.intensity = 1_200
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
    presentFighters(hero: simulation.hero, enemy: simulation.enemy, deltaTime: deltaTime)
    focusRing.position = [simulation.enemy.position.x, 0, simulation.enemy.position.y]
    focusRing.isEnabled = simulation.isFocused
    presentWarning(simulation)
  }

  func present(_ run: DungeonRun, deltaTime: Float) {
    presentFighters(hero: run.hero, enemy: run.visibleEnemy, deltaTime: deltaTime)
    focusRing.isEnabled = run.activeEncounter != nil && run.isFocused
    if let enemy = run.enemy {
      focusRing.position = [enemy.position.x, 0, enemy.position.y]
      presentWarning(run.simulation)
      if attackWarning.isEnabled, let action = enemy.action {
        let key = WarningKey(
          kind: action.kind, origin: enemy.position, direction: action.direction,
          shortcutOpen: run.shortcutOpen)
        if key != warningKey {
          warningKey = key
          warningClear = preparationHasClearance(
            action: action, origin: enemy.position, shortcutOpen: run.shortcutOpen)
        }
        if !warningClear { hideWarning() }
      } else {
        warningKey = nil
      }
    } else {
      hideWarning()
      warningKey = nil
    }
    shortcutDoor.isEnabled = !run.shortcutOpen
    healingAvailable.isEnabled = !run.healingUsed
    healingSpent.isEnabled = run.healingUsed
    for (id, marker) in clearedMarkers { marker.isEnabled = run.clearedEncounters.contains(id) }
  }

  func resetMotion() {
    hero.mannequin.resetMotion()
    enemy.mannequin.resetMotion()
    warningKey = nil
  }

  /// A cue is supplementary: omit a whole cached envelope if it could imply danger through
  /// scenery or over empty space. The committed body/weapon pose remains authoritative.
  func preparationHasClearance(
    action: DuelAction, origin: SIMD2<Float>, shortcutOpen: Bool
  ) -> Bool {
    guard action.kind == .sweep || action.kind == .thrust else { return false }
    let points = action.kind == .sweep ? sweepFootprint : thrustFootprint
    let collision = PartyMotion(
      radius: DuelArena.radius, obstacles: DungeonLayout.obstacles(shortcutOpen: shortcutOpen))
    let rotation = simd_quatf(angle: Movement.yaw(towards: action.direction), axis: [0, 1, 0])
    return points.allSatisfy { point in
      let offset = rotation.act(point)
      let destination = origin + SIMD2(offset.x, offset.z)
      return DungeonLayout.floors.contains { $0.contains(destination) }
        && collision.canTraverse(from: origin, to: destination)
    }
  }

  private static func footprint(of warning: Entity) -> [SIMD3<Float>] {
    warning.children.compactMap { ($0 as? ModelEntity)?.model?.mesh }.flatMap { mesh in
      mesh.contents.models.flatMap { $0.parts.flatMap { $0.positions.elements } }
    }
  }

  private func hideWarning() {
    attackWarning.isEnabled = false
    sweepWarning.isEnabled = false
    thrustWarning.isEnabled = false
  }

  private func presentFighters(
    hero fighter: DuelFighter, enemy visible: DuelFighter?, deltaTime: Float
  ) {
    pose(hero, fighter: fighter, deltaTime: deltaTime)
    let appeared = !enemy.body.isEnabled
    enemy.body.isEnabled = visible != nil
    if let visible { pose(enemy, fighter: visible, deltaTime: appeared ? 0 : deltaTime) }
  }

  private func buildDungeon() {
    let void = Self.box(
      size: [100, 0.1, 100], position: [-10, -0.3, 4],
      color: UIColor(red: 0.035, green: 0.043, blue: 0.052, alpha: 1))
    void.name = "dungeon.void"
    root.addChild(void)
    for (index, floor) in DungeonLayout.floors.enumerated() {
      let centre = (floor.minimum + floor.maximum) / 2
      let size = floor.maximum - floor.minimum
      let chamber = size.x > 5 && size.y > 5
      let slab = Self.box(
        size: [size.x, 0.18, size.y], position: [centre.x, -0.1, centre.y],
        color: chamber
          ? UIColor(red: 0.24, green: 0.26, blue: 0.28, alpha: 1)
          : UIColor(red: 0.19, green: 0.21, blue: 0.23, alpha: 1))
      slab.name = "dungeon.floor.\(index)"
      root.addChild(slab)
      if chamber {
        for x in stride(from: floor.minimum.x + 2, to: floor.maximum.x, by: 2) {
          root.addChild(
            Self.box(
              size: [0.018, 0.006, size.y], position: [x, -0.007, centre.y],
              color: UIColor(white: 0.13, alpha: 1)))
        }
        for z in stride(from: floor.minimum.y + 2, to: floor.maximum.y, by: 2) {
          root.addChild(
            Self.box(
              size: [size.x, 0.006, 0.018], position: [centre.x, -0.007, z],
              color: UIColor(white: 0.13, alpha: 1)))
        }
      }
    }
    for (index, wall) in DungeonLayout.walls.enumerated() {
      let centre = (wall.bounds.minimum + wall.bounds.maximum) / 2
      let size = wall.bounds.maximum - wall.bounds.minimum
      let stone = Self.box(
        size: [size.x, wall.height, size.y], position: [centre.x, wall.height / 2, centre.y],
        color: UIColor(red: 0.13, green: 0.15, blue: 0.18, alpha: 1))
      stone.name = "dungeon.wall.\(index)"
      root.addChild(stone)
      let cap = Self.box(
        size: [size.x + 0.035, 0.055, size.y + 0.035],
        position: [centre.x, wall.height + 0.025, centre.y],
        color: UIColor(red: 0.28, green: 0.29, blue: 0.30, alpha: 1))
      cap.name = "dungeon.wall-cap.\(index)"
      root.addChild(cap)
    }
    for doorway in DungeonLayout.doorways {
      addDoorway(
        name: doorway.name, centre: doorway.centre, width: doorway.width, alongX: doorway.alongX)
    }
    let gate = DungeonLayout.shortcutGate
    let centre = (gate.bounds.minimum + gate.bounds.maximum) / 2
    let width = gate.bounds.maximum.y - gate.bounds.minimum.y
    shortcutDoor.name = "dungeon.shortcut.closed"
    for z in stride(from: -width / 2 + 0.16, through: width / 2 - 0.15, by: 0.28) {
      shortcutDoor.addChild(
        Self.box(
          size: [0.08, gate.height, 0.065], position: [centre.x, gate.height / 2, centre.y + z],
          color: UIColor(red: 0.38, green: 0.31, blue: 0.21, alpha: 1)))
    }
    for height: Float in [0.1, gate.height - 0.08] {
      shortcutDoor.addChild(
        Self.box(
          size: [0.1, 0.075, width], position: [centre.x, height, centre.y],
          color: UIColor(red: 0.38, green: 0.31, blue: 0.21, alpha: 1)))
    }
    root.addChild(shortcutDoor)
    let cache = DungeonLayout.healingPosition
    healingAvailable.name = "dungeon.healing.available"
    healingSpent.name = "dungeon.healing.spent"
    healingSpent.isEnabled = false
    let supply = Self.box(
      size: [0.55, 0.12, 0.55], position: [cache.x, 0.06, cache.y],
      color: UIColor(red: 0.22, green: 0.46, blue: 0.4, alpha: 1))
    healingAvailable.addChild(supply)
    for size: SIMD3<Float> in [[0.12, 0.035, 0.38], [0.38, 0.035, 0.12]] {
      healingAvailable.addChild(
        Self.lamp(
          size: size, position: [cache.x, 0.14, cache.y],
          color: UIColor(red: 0.73, green: 0.95, blue: 0.8, alpha: 1)))
    }
    healingSpent.addChild(
      Self.box(
        size: [0.55, 0.055, 0.55], position: [cache.x, 0.027, cache.y],
        color: UIColor(red: 0.12, green: 0.18, blue: 0.17, alpha: 1)))
    root.addChild(healingAvailable)
    root.addChild(healingSpent)
    for encounter in DungeonLayout.encounters {
      let marker = Self.lamp(
        size: [0.42, 0.025, 0.42], position: [encounter.home.x, 0.015, encounter.home.y],
        color: UIColor(red: 0.68, green: 0.58, blue: 0.35, alpha: 1))
      marker.name = "dungeon.cleared.\(encounter.id)"
      marker.isEnabled = false
      root.addChild(marker)
      clearedMarkers.append((encounter.id, marker))
    }
    let entry = DungeonLayout.heroSpawn
    let checkpoint = Self.lamp(
      size: [0.95, 0.025, 0.95], position: [entry.x, 0.016, entry.y],
      color: UIColor(red: 0.66, green: 0.50, blue: 0.25, alpha: 1))
    checkpoint.name = "dungeon.checkpoint"
    root.addChild(checkpoint)
    let exit = DungeonLayout.exitPosition
    let destination = Self.lamp(
      size: [0.9, 0.025, 0.9], position: [exit.x, 0.016, exit.y],
      color: UIColor(red: 0.72, green: 0.61, blue: 0.38, alpha: 1))
    destination.name = "dungeon.exit"
    root.addChild(destination)
  }

  private func addDoorway(name: String, centre: SIMD2<Float>, width: Float, alongX: Bool) {
    let doorway = Entity()
    doorway.name = "dungeon.doorway.\(name)"
    doorway.position = [centre.x, 0, centre.y]
    if !alongX { doorway.orientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0]) }
    // Door returns are cut away with nearby walls. Tall posts or a floating lintel can
    // obscure the feet/weapon even when the wall itself has already been lowered.
    for sign: Float in [-1, 1] {
      let x = sign * (width / 2 + 0.09)
      doorway.addChild(
        Self.box(
          size: [0.18, 0.22, 0.3], position: [x, 0.11, 0],
          color: UIColor(red: 0.22, green: 0.24, blue: 0.25, alpha: 1)))
      doorway.addChild(
        Self.lamp(
          size: [0.09, 0.08, 0.07], position: [x, 0.21, 0.18],
          color: UIColor(red: 0.95, green: 0.7, blue: 0.33, alpha: 1)))
    }
    doorway.addChild(
      Self.box(
        size: [width, 0.025, 0.15], position: [0, 0.006, 0],
        color: UIColor(red: 0.43, green: 0.35, blue: 0.22, alpha: 1)))
    root.addChild(doorway)
  }

  private static func lamp(size: SIMD3<Float>, position: SIMD3<Float>, color: UIColor)
    -> ModelEntity
  {
    var material = UnlitMaterial()
    material.color = .init(tint: color)
    let light = ModelEntity(mesh: .generateBox(size: size), materials: [material])
    light.position = position
    return light
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
    hideWarning()
    warningKey = nil
    for player in players.values {
      player.stop()
      player.currentTime = 0
    }
  }

  private func presentWarning(_ simulation: DuelSimulation) {
    attackWarning.isEnabled = false
    sweepWarning.isEnabled = false
    thrustWarning.isEnabled = false
    guard simulation.outcome == .fighting, simulation.enemy.health > 0,
      let action = simulation.enemy.action, action.phase == .windup,
      action.kind == .sweep || action.kind == .thrust
    else { return }
    // Enemy actions freeze their origin and direction when accepted. Do not aim this
    // presentation at the hero: it previews the committed attack, even after a sidestep.
    attackWarning.position = [simulation.enemy.position.x, 0.004, simulation.enemy.position.y]
    attackWarning.orientation = simd_quatf(
      angle: Movement.yaw(towards: action.direction), axis: [0, 1, 0])
    sweepWarning.isEnabled = action.kind == .sweep
    thrustWarning.isEnabled = action.kind == .thrust
    attackWarning.isEnabled = true
  }

  private static func warning(kind: DuelAction.Kind) -> Entity {
    let profile = DuelAction(kind: kind, direction: [0, -1]).profile
    let segments = kind == .sweep ? 32 : 12
    let bands = 8
    // Contact tests a target disc, not a point. Include the same radius/range and angular
    // padding in this full-action envelope; thrust may reach it only late in its active phase.
    // It is a preparation cue, not a promise of contact: timing and scenery still decide hits.
    // The 0.6m cutout preserves feet and the focus ring, inside normal 0.76m body separation.
    let inner: Float = 0.6
    let outer = profile.reach + DuelArena.radius
    var positions: [SIMD3<Float>] = []
    for band in 0...bands {
      let radius = inner + (outer - inner) * Float(band) / Float(bands)
      let angle = profile.halfAngle + asin(DuelArena.radius / radius)
      for segment in 0...segments {
        let yaw = -angle + 2 * angle * Float(segment) / Float(segments)
        positions.append([sin(yaw) * radius, 0, -cos(yaw) * radius])
      }
    }
    var indices: [UInt32] = []
    for band in 0..<bands {
      for segment in 0..<segments {
        let a = UInt32(band * (segments + 1) + segment)
        let b = a + UInt32(segments + 1)
        indices += [a, a + 1, b, a + 1, b + 1, b]
      }
    }
    var boundary: [SIMD3<Float>] = []
    boundary += positions[(bands * (segments + 1))...]
    for band in stride(from: bands - 1, through: 0, by: -1) {
      boundary.append(positions[band * (segments + 1) + segments])
    }
    for segment in stride(from: segments - 1, through: 0, by: -1) {
      boundary.append(positions[segment])
    }
    for band in 1..<bands { boundary.append(positions[band * (segments + 1)]) }
    var outline: [SIMD3<Float>] = []
    var outlineIndices: [UInt32] = []
    for index in boundary.indices {
      let start = boundary[index]
      let end = boundary[(index + 1) % boundary.count]
      let side = simd_normalize(simd_cross(end - start, [0, 1, 0])) * 0.014
      let base = UInt32(outline.count)
      let lift = SIMD3<Float>(0, 0.002, 0)
      outline += [start - side + lift, start + side + lift, end - side + lift, end + side + lift]
      outlineIndices += [base, base + 1, base + 2, base + 1, base + 3, base + 2]
    }
    let name = "duel.attack-warning.\(kind == .sweep ? "sweep" : "thrust")"
    let entity = Entity()
    entity.name = name
    entity.isEnabled = false
    entity.addChild(
      warningMesh(name: "\(name).fill", positions: positions, indices: indices, opacity: 0.13))
    entity.addChild(
      warningMesh(
        name: "\(name).outline", positions: outline, indices: outlineIndices, opacity: 0.58))
    return entity
  }

  private static func warningMesh(
    name: String, positions: [SIMD3<Float>], indices: [UInt32], opacity: Float
  ) -> ModelEntity {
    var descriptor = MeshDescriptor(name: name)
    descriptor.positions = MeshBuffers.Positions(positions)
    descriptor.normals = MeshBuffers.Normals(Array(repeating: [0, 1, 0], count: positions.count))
    descriptor.primitives = .triangles(indices)
    guard let mesh = try? MeshResource.generate(from: [descriptor]) else {
      preconditionFailure("The primitive attack warning could not be generated: \(name)")
    }
    var material = UnlitMaterial()
    material.color = .init(tint: UIColor(red: 0.95, green: 0.64, blue: 0.2, alpha: 1))
    material.blending = .transparent(opacity: .init(floatLiteral: opacity))
    let entity = ModelEntity(mesh: mesh, materials: [material])
    entity.name = name
    return entity
  }

  private func pose(_ figure: Figure, fighter: DuelFighter, deltaTime: Float) {
    figure.body.position = [fighter.position.x, 0, fighter.position.y]
    figure.body.orientation = simd_quatf(angle: fighter.yaw, axis: [0, 1, 0])
    let action = fighter.action
    let angle: Float = action?.bladeAngle ?? 0
    let direction = simd_quatf(angle: angle, axis: [0, 1, 0])
    let hilt: Float
    if let action, action.kind == .thrust {
      hilt = action.bladeReach - figure.bladeLength
    } else {
      hilt = 0.35
    }
    figure.weapon.position = SIMD3<Float>(0, 1.08, 0) + direction.act([0, 0, -hilt])
    figure.weapon.orientation = direction
    figure.weapon.isEnabled = fighter.health > 0
    figure.shield.isEnabled = figure.hasShield && fighter.health > 0
    figure.shield.position = [-0.18, 1.05, -0.52]
    figure.shield.orientation = .init()
    let rightHand = figure.weapon.position + direction.act([0, 0, 0.08])
    let leftHand =
      figure.shield.isEnabled && fighter.guarding
      ? figure.shield.position + figure.shield.orientation.act([0, 0, 0.08]) : nil
    figure.mannequin.pose(
      fighter: fighter, deltaTime: deltaTime,
      rightHand: fighter.health > 0 ? rightHand : nil,
      leftHand: fighter.health > 0 ? leftHand : nil)
    if !fighter.guarding {
      let hand = figure.mannequin.leftHand
      figure.shield.orientation = hand.orientation(relativeTo: figure.body)
      figure.shield.position =
        hand.position(relativeTo: figure.body) + figure.shield.orientation.act([0, 0, -0.08])
    }
  }

  private static func figure(
    name: String, color: UIColor, shield hasShield: Bool
  ) -> Figure {
    let body = Entity()
    body.name = "duel.\(name)"
    let mannequin = Mannequin(name: name, color: color)
    body.addChild(mannequin.root)
    let weapon = Entity()
    weapon.name = "\(name).weapon"
    let length: Float = hasShield ? 1.45 : 1.70
    let blade = box(
      size: [hasShield ? 0.09 : 0.12, 0.075, length],
      position: [0, 0, -length / 2], color: .lightGray)
    blade.name = "\(name).blade"
    weapon.addChild(blade)
    weapon.addChild(box(size: [0.3, 0.08, 0.08], position: .zero, color: .darkGray))
    weapon.addChild(box(size: [0.07, 0.07, 0.18], position: [0, 0, 0.09], color: .darkGray))
    body.addChild(weapon)
    let shield = box(
      size: [0.68, 0.72, 0.13], position: [-0.48, 0.95, -0.08],
      color: UIColor(red: 0.7, green: 0.75, blue: 0.73, alpha: 1))
    shield.isEnabled = hasShield
    shield.name = "\(name).shield"
    body.addChild(shield)
    return Figure(
      body: body, mannequin: mannequin, weapon: weapon, shield: shield, bladeLength: length,
      hasShield: hasShield)
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
