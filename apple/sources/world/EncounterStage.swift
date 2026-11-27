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
  private var drones: [String: DronePresentation] = [:]
  private var crawlers: [String: CrawlerPresentation] = [:]
  private var componentMarkers: [String: [ModelEntity]] = [:]
  private enum ComponentLook: Equatable { case damaged, nearBreak }
  private var componentLooks: [String: [ComponentLook?]] = [:]
  private let damagedLegMaterial = UnlitMaterial(color: .orange)
  private let nearBreakMaterial = UnlitMaterial(color: .red)
  private let grenadeProp = ModelEntity(
    mesh: .generateSphere(radius: 0.16), materials: [UnlitMaterial(color: .orange)])
  private let blastProp: ModelEntity = {
    var material = UnlitMaterial(color: .orange)
    material.blending = .transparent(opacity: .init(floatLiteral: 0.25))
    return ModelEntity(mesh: .generateSphere(radius: 1), materials: [material])
  }()
  private var blastRemaining: Float = 0
  private let targetMarker: Entity
  /// The red ring round the locked hostile (ADR 0020).
  private let lockMarker: Entity
  /// The lock ring's scale round a person, and round the robot, whose legs reach further.
  private let lockScale: Float
  private let robotLockScale: Float

  init(level: Level, style: SceneStyle) {
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
    grenadeProp.name = "combat.grenade"
    blastProp.name = "combat.blast"
    grenadeProp.isEnabled = false
    blastProp.isEnabled = false
    container.addChild(grenadeProp)
    container.addChild(blastProp)

    for spec in level.encounters.flatMap(\.hostiles) {
      let body = Entity()
      body.name = "hostile.\(spec.id)"
      let visual =
        spec.attack == .robot
        ? style.robot()
        : spec.isDrone ? style.drone() : spec.isCrawler ? style.crawler() : style.hostile()
      if spec.attack == .robot {
        robots[spec.id] = RobotPresentation(visual: visual, debrisParent: container)
      }
      if spec.isDrone {
        drones[spec.id] = DronePresentation(id: spec.id, visual: visual, shadowParent: container)
      }
      if spec.isCrawler {
        crawlers[spec.id] = CrawlerPresentation(id: spec.id, visual: visual)
      }
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
        componentLooks[spec.id] = Array(repeating: nil, count: GuardStrategy.legCount)
        componentMarkers[spec.id] = (0..<GuardStrategy.legCount).map { index in
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
    blastRemaining = 0
    blastProp.isEnabled = false
    grenadeProp.isEnabled = false
    for (id, presentation) in robots {
      if let state = fight.hostiles[id], let robot = state.robot {
        presentation.reset(position: state.position, facing: robot.facing)
      }
    }
    show(fight, dt: 0)
  }

  func update(_ fight: EncounterSimulation, dt: Float) {
    effects.update(dt: dt)
    if let centre = fight.blasts.last {
      blastProp.position = centre
      blastRemaining = 0.45
    } else {
      blastRemaining = max(0, blastRemaining - dt)
    }
    blastProp.isEnabled = blastRemaining > 0
    let blastScale = Grenade.blastRadius * (1 - blastRemaining / 0.45)
    blastProp.scale = [blastScale, 0.12, blastScale]
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
    grenadeProp.isEnabled = fight.grenade != nil
    if let grenade = fight.grenade { grenadeProp.position = grenade.position }
    for (id, state) in fight.hostiles {
      let points = fight.weakpoints(for: id)
      for (index, marker) in (componentMarkers[id] ?? []).enumerated() {
        let hits = fight.guardStrategies[id]?.swordHits[index] ?? 0
        guard hits > 0, let point = points.first(where: { $0.part == .leg(index) }) else {
          marker.isEnabled = false
          continue
        }
        marker.isEnabled = true
        marker.position = point.centre
        marker.scale = SIMD3(repeating: 0.14)
        let look: ComponentLook =
          hits >= GuardStrategy.swordHitsToDetach - 1 ? .nearBreak : .damaged
        if componentLooks[id]?[index] != look {
          marker.model?.materials = [look == .nearBreak ? nearBreakMaterial : damagedLegMaterial]
          componentLooks[id]?[index] = look
        }
      }
      if let body = bodies[id] {
        body.isEnabled = state.isVisible
        body.position =
          state.drone.map(DronePresentation.bodyPosition)
          ?? [state.position.x, PartyBody.height / 2, state.position.y]
      }
      if let presentation = robots[id], let robot = state.robot {
        presentation.update(
          position: state.position, facing: robot.facing, brace: robot.brace,
          gunDirections: robot.gunDirections, gunRecoil: robot.gunRecoil,
          down: state.isDown, detachedLegs: fight.guardStrategies[id]?.detachedLegs ?? [],
          bodyDrop: robot.bodyDrop, dt: dt)
      } else if let presentation = drones[id], let drone = state.drone {
        presentation.update(drone, visible: state.isVisible, dt: dt)
      } else if let presentation = crawlers[id], let crawler = state.crawler {
        presentation.update(crawler, visible: state.isVisible, dt: dt)
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
