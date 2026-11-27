import RealityKit
import simd

/// Presents the bridge fight's values. Entities are made once at load; each simulation step
/// supplies their visibility, pose and shots without changing gameplay state.
@MainActor
final class EncounterStage {
  let container = Entity()
  let effects: ShotEffects
  /// Each member's two weapons, one entity for each; only the one in hand shows, while drawn.
  let weaponProps: [PartyMember: [Weapon.Kind: Entity]]
  private var bodies: [String: Entity] = [:]
  private var visuals: [String: Entity] = [:]
  private var hostileWeaponProps: [String: Entity] = [:]
  private var robots: [String: RobotPresentation] = [:]
  private var componentMarkers: [String: [ModelEntity]] = [:]
  private enum ComponentLook: Equatable {
    case closed
    case exposed(PartyMember)
  }
  private var componentLooks: [String: [ComponentLook?]] = [:]
  private let closedComponentMaterial = UnlitMaterial(color: .darkGray)
  private let exposedComponentMaterials: [PartyMember: UnlitMaterial]
  private let targetMarker: Entity
  /// The red ring round the locked hostile (ADR 0020).
  private let lockMarker: Entity
  /// The lock ring's scale round a person, and round the robot, whose legs reach further.
  private let lockScale: Float
  private let robotLockScale: Float

  init(level: Level, style: SceneStyle) {
    exposedComponentMaterials = Dictionary(
      uniqueKeysWithValues: PartyMember.allCases.map {
        ($0, UnlitMaterial(color: SceneStyle.colour(of: $0)))
      })
    let shots = Entity()
    shots.name = "combat.shots"
    effects = ShotEffects(style: style, in: shots)
    weaponProps = Dictionary(
      uniqueKeysWithValues: PartyMember.allCases.map { member in
        (
          member,
          Dictionary(
            uniqueKeysWithValues: Weapon.pair(for: member).map {
              ($0.kind, style.weapon(for: $0.kind))
            })
        )
      })
    targetMarker = style.targetMarker()
    lockMarker = style.lockMarker()
    lockScale = style.markerScale
    robotLockScale = max(
      style.markerScale,
      (RobotModelGeometry.navigationRadius + PartyBody.radius) / SceneStyle.lockRingRadius)
    container.name = "combat"
    targetMarker.name = "combat.target"
    lockMarker.name = "combat.lock"
    container.addChild(targetMarker)
    container.addChild(lockMarker)
    container.addChild(shots)

    for spec in level.encounters.flatMap(\.hostiles) {
      let body = Entity()
      body.name = "hostile.\(spec.id)"
      let visual = spec.attack == .robot ? style.robot() : style.hostile()
      if spec.attack == .robot { robots[spec.id] = RobotPresentation(visual: visual) }
      if spec.attack == .shoot {
        let weapon = style.weapon(for: .rifle)
        weapon.name = "hostile.\(spec.id).rifle"
        visual.addChild(weapon)
        hostileWeaponProps[spec.id] = weapon
      }
      body.addChild(visual)
      container.addChild(body)
      bodies[spec.id] = body
      visuals[spec.id] = visual
      if spec.strategicGuard {
        componentLooks[spec.id] = [nil, nil]
        componentMarkers[spec.id] = (0..<2).map { index in
          let marker = ModelEntity(
            mesh: .generateSphere(radius: 1), materials: [style.ink])
          marker.name = "combat.component.\(spec.id).\(index)"
          marker.isEnabled = false
          container.addChild(marker)
          return marker
        }
      }
    }
  }

  func reset(_ fight: EncounterSimulation) {
    effects.clear()
    for (id, presentation) in robots {
      if let state = fight.hostiles[id], let robot = state.robot {
        presentation.reset(position: state.position, facing: robot.facing)
      }
    }
    show(fight, dt: 0)
  }

  func update(_ fight: EncounterSimulation, dt: Float) {
    effects.update(dt: dt)
    for shot in fight.shots {
      let side: ShotEffects.Side = shot.side == .party ? .party : .hostile
      if let trace = shot.trace {
        let impact =
          shot.armoured
          ? Ballistics.Trace(start: trace.start, end: trace.end, strike: .scenery) : trace
        effects.show(impact, side: side, muzzle: shot.muzzle)
      } else {
        effects.show(
          shot.path, side: side, height: EncounterSimulation.aimHeight, muzzle: shot.muzzle)
      }
    }
    show(fight, dt: dt)
  }

  /// Resolved damage shares the world's one drained event batch with sound and HUD numbers.
  func showDamage(_ hits: [DamageHit]) {
    for hit in hits { effects.showDamage(hit) }
  }

  func clearDamage() { effects.clearDamage() }

  private func show(_ fight: EncounterSimulation, dt: Float) {
    for (id, state) in fight.hostiles {
      let points = fight.weakpoints(for: id)
      for (index, marker) in (componentMarkers[id] ?? []).enumerated() {
        marker.isEnabled = points.indices.contains(index)
        guard points.indices.contains(index) else { continue }
        let point = points[index]
        marker.position = point.centre
        marker.scale = SIMD3(repeating: point.radius)
        let member: PartyMember =
          switch point.part {
          case .sensor: .miki
          case .coupling: .laura
          case .reactor: .tom
          }
        let look: ComponentLook = point.exposed ? .exposed(member) : .closed
        if componentLooks[id]?[index] != look {
          let material =
            point.exposed
            ? exposedComponentMaterials[member] ?? closedComponentMaterial
            : closedComponentMaterial
          marker.model?.materials = [material]
          componentLooks[id]?[index] = look
        }
      }
      if let body = bodies[id] {
        body.isEnabled = state.isVisible
        body.position = [state.position.x, PartyBody.height / 2, state.position.y]
      }
      if let presentation = robots[id], let robot = state.robot {
        presentation.update(
          position: state.position, facing: robot.facing, brace: robot.brace,
          gunDirections: robot.gunDirections, gunRecoil: robot.gunRecoil,
          down: state.isDown, dt: dt)
      } else if let visual = visuals[id], let pose = fight.hostilePoses[id] {
        visual.orientation = pose.orientation
        visual.position = pose.position
      }
      if let prop = hostileWeaponProps[id] {
        prop.isEnabled = state.isVisible && !state.isDown
        if let pose = fight.hostileWeaponPoses[id] {
          let transform = pose.transform
          prop.position = transform.position
          prop.orientation = transform.orientation
        }
      }
    }
    if let target = fight.target {
      targetMarker.position = [target.x, SceneStyle.groundMarkerHeight, target.y]
      targetMarker.isEnabled = true
    } else {
      targetMarker.isEnabled = false
    }
    if let id = fight.lock, let point = fight.lockPoint {
      let scale = robots[id] == nil ? lockScale : robotLockScale
      let centre = robots[id] == nil ? point : fight.hostiles[id]?.position ?? point
      lockMarker.scale = [scale, 1, scale]
      lockMarker.position = [centre.x, SceneStyle.groundMarkerHeight, centre.y]
      lockMarker.isEnabled = true
    } else {
      lockMarker.isEnabled = false
    }
    let drawn = fight.drawnWeapons
    for member in PartyMember.allCases {
      guard let props = weaponProps[member] else { continue }
      let inHand = fight.weapon(of: member).kind
      for (kind, prop) in props {
        prop.isEnabled = kind == inHand && drawn.contains(member)
        if kind == inHand, let pose = fight.weaponPoses[member] {
          let transform = pose.transform
          prop.position = transform.position
          prop.orientation = transform.orientation
        }
      }
    }
  }
}
