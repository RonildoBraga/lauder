import RealityKit
import simd

/// Presents the bridge fight's values. Entities are made once at load; each simulation step
/// supplies their visibility, pose and shots without changing gameplay state.
@MainActor
final class EncounterStage {
  let container = Entity()
  let effects: ShotEffects
  let weaponProps: [PartyMember: Entity]
  private var bodies: [String: Entity] = [:]
  private var visuals: [String: Entity] = [:]
  private var hostileWeaponProps: [String: Entity] = [:]
  private let targetMarker: Entity

  init(level: Level, style: SceneStyle) {
    let shots = Entity()
    shots.name = "combat.shots"
    effects = ShotEffects(style: style, in: shots)
    weaponProps = Dictionary(
      uniqueKeysWithValues: PartyMember.allCases.map {
        ($0, style.weapon(for: Weapon.forMember($0).kind))
      })
    targetMarker = style.targetMarker()
    container.name = "combat"
    targetMarker.name = "combat.target"
    container.addChild(targetMarker)
    container.addChild(shots)

    for spec in level.encounters.flatMap(\.hostiles) {
      let body = Entity()
      body.name = "hostile.\(spec.id)"
      let visual = style.hostile()
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
    }
  }

  func reset(_ fight: EncounterSimulation) {
    effects.clear()
    show(fight)
  }

  func update(_ fight: EncounterSimulation, dt: Float) {
    effects.update(dt: dt)
    for shot in fight.shots {
      let side: ShotEffects.Side = shot.side == .party ? .party : .hostile
      if let trace = shot.trace {
        effects.show(trace, side: side, muzzle: shot.muzzle)
      } else {
        effects.show(
          shot.path, side: side, height: EncounterSimulation.aimHeight, muzzle: shot.muzzle)
      }
    }
    show(fight)
  }

  private func show(_ fight: EncounterSimulation) {
    for (id, state) in fight.hostiles {
      if let body = bodies[id] {
        body.isEnabled = state.isVisible
        body.position = [state.position.x, PartyBody.height / 2, state.position.y]
      }
      if let visual = visuals[id], let pose = fight.hostilePoses[id] {
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
      targetMarker.position = [target.x, 0.012, target.y]
      targetMarker.isEnabled = true
    } else {
      targetMarker.isEnabled = false
    }
    let drawn = fight.drawnWeapons
    for member in PartyMember.allCases {
      guard let prop = weaponProps[member] else { continue }
      prop.isEnabled = drawn.contains(member)
      if let pose = fight.weaponPoses[member] {
        let transform = pose.transform
        prop.position = transform.position
        prop.orientation = transform.orientation
      }
    }
  }
}
