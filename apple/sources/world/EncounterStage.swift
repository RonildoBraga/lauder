import RealityKit
import simd

/// Presents a fight's values (ADR 0004, ADR 0007, ADR 0008). The simulation owns the hostiles,
/// shots, aim and poses; this owns only their entities. Every entity is made once at load, and
/// the world applies each simulation step before asking this stage to show it.
@MainActor
final class EncounterStage {
  /// Holds the hostiles, shots and target marker; the world adds it to the scene.
  let container = Entity()
  /// What every shot looks like (ADR 0007).
  let effects: ShotEffects
  /// Each member's weapon, posed at its grip; the world attaches it to that member's visual.
  let weaponProps: [PartyMember: Entity]

  private var bodies: [String: Entity] = [:]
  private var visuals: [String: Entity] = [:]
  private var hostileWeaponProps: [String: Entity] = [:]
  private let targetMarker: Entity
  private let coverShields: [PartyMember: CoverShield]
  private let enemyCoverShields: [String: CoverShield]
  private let grenadeMarkers: [String: GrenadeMarker]
  private let arrivalMarkers: [String: ArenaArrivalMarker]
  private var throwerMarks: [String: Entity] = [:]
  private let terrain: Terrain

  init(level: Level, style: SceneStyle) {
    terrain = level.terrain
    let shots = Entity()
    shots.name = "combat.shots"
    effects = ShotEffects(style: style, in: shots, terrain: level.terrain)
    weaponProps = Dictionary(
      uniqueKeysWithValues: PartyMember.allCases.map {
        ($0, style.weapon(for: Weapon.forMember($0).kind))
      })
    targetMarker = style.targetMarker()
    coverShields =
      level.combat.leaderCover
      ? Dictionary(
        uniqueKeysWithValues: PartyMember.allCases.map { member in
          let shield = CoverShield(style: style)
          shield.entity.name = "cover.shield.\(member.rawValue)"
          return (member, shield)
        }) : [:]
    let specs = level.encounters.flatMap(\.hostiles)
    enemyCoverShields = Dictionary(
      uniqueKeysWithValues: specs.filter { $0.behavior != .stationary }.map { spec in
        let shield = CoverShield(style: style)
        shield.entity.name = "cover.hostile.\(spec.id)"
        return (spec.id, shield)
      })
    grenadeMarkers = Dictionary(
      uniqueKeysWithValues: specs.filter { $0.attack == .throwGrenade }.map { spec in
        let marker = GrenadeMarker(style: style)
        marker.entity.name = "grenade.marker.\(spec.id)"
        return (spec.id, marker)
      })
    if let arena = level.arena {
      arrivalMarkers = Dictionary(
        uniqueKeysWithValues: arena.slots.map { slot in
          (
            slot.id,
            ArenaArrivalMarker(
              slot: slot, duration: arena.warningDuration, terrain: level.terrain, style: style)
          )
        })
    } else {
      arrivalMarkers = [:]
    }
    container.name = "combat"
    targetMarker.name = "combat.target"
    container.addChild(targetMarker)
    container.addChild(shots)
    for shield in coverShields.values { container.addChild(shield.entity) }
    for shield in enemyCoverShields.values { container.addChild(shield.entity) }
    for marker in grenadeMarkers.values { container.addChild(marker.entity) }
    for marker in arrivalMarkers.values { container.addChild(marker.entity) }

    for spec in specs {
      let body = Entity()
      body.name = "hostile.\(spec.id)"
      let visual = style.hostile()
      if spec.attack == .shoot {
        // The raised barrel and recoil communicate aim without revealing its exact endpoint.
        let weapon = style.weapon(for: .rifle)
        weapon.name = "hostile.\(spec.id).rifle"
        visual.addChild(weapon)
        hostileWeaponProps[spec.id] = weapon
      }
      if spec.attack == .throwGrenade {
        // A simple overhead shape distinguishes the thrower without requiring character art.
        let mark = style.block(
          size: [0.3, 0.12, 0.24], at: [0, PartyBody.height / 2 + 0.14, 0], material: style.warm)
        mark.name = "hostile.\(spec.id).thrower"
        visual.addChild(mark)
        throwerMarks[spec.id] = mark
      }
      body.addChild(visual)
      container.addChild(body)
      bodies[spec.id] = body
      visuals[spec.id] = visual

    }
  }

  /// Restart or a fall back clears the effects, then shows the simulation's resulting state.
  func reset(_ fight: FightSimulation) {
    effects.clear()
    show(fight)
  }

  /// Existing effects advance before this step's shots appear, as they did before the split.
  /// Shot values belong to this step only; the world calls this once for each simulation step.
  func update(_ fight: FightSimulation, dt: Float) {
    effects.update(dt: dt)
    for shot in fight.shots {
      let side: ShotEffects.Side =
        switch shot.side {
        case .party: .party
        case .hostile: .hostile
        }
      if let trace = shot.trace {
        effects.show(trace, side: side, muzzle: shot.muzzle)
      } else {
        effects.show(
          shot.path, side: side,
          height: terrain.height(at: shot.path.start) + FightSimulation.aimHeight,
          muzzle: shot.muzzle)
      }
    }
    for point in fight.explosions { effects.blast(at: point) }
    show(fight)
  }

  /// Applies the state without advancing it or choosing a target, pose, shot or outcome.
  private func show(_ fight: FightSimulation) {
    for (member, shield) in coverShields {
      if let cover = fight.coverStates[member] {
        shield.show(
          at: cover.position, toward: -cover.normal, exposed: cover.exposed,
          floor: terrain.height(at: cover.position))
      } else {
        shield.hide()
      }
    }
    for (id, shield) in enemyCoverShields {
      if let cover = fight.enemyCoverStates[id], fight.hostiles[id]?.isDown == false {
        shield.show(
          at: cover.position, toward: -cover.normal, exposed: cover.exposed,
          floor: terrain.height(at: cover.position))
      } else {
        shield.hide()
      }
    }
    for (id, marker) in arrivalMarkers { marker.show(remaining: fight.arenaWarnings[id]) }
    for (owner, marker) in grenadeMarkers {
      marker.show(fight.grenades.first { $0.owner == owner })
    }
    for (id, state) in fight.hostiles {
      if let body = bodies[id] {
        body.isEnabled = state.isVisible
        body.position = [
          state.position.x, terrain.height(at: state.position) + PartyBody.height / 2,
          state.position.y,
        ]
      }
      if let visual = visuals[id], let pose = fight.hostilePoses[id] {
        visual.scale = [1, pose.scale, 1]
        visual.orientation = pose.orientation
        visual.position = pose.position
      }
      throwerMarks[id]?.isEnabled = state.isVisible && !state.isDown
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
      targetMarker.position = [target.x, terrain.height(at: target) + 0.012, target.y]
      targetMarker.isEnabled = true
    } else {
      targetMarker.isEnabled = false
    }
    let drawn = fight.drawnWeapons
    for (member, prop) in weaponProps {
      prop.isEnabled = drawn.contains(member)
      if let pose = fight.weaponPoses[member] {
        let transform = pose.transform
        prop.position = transform.position
        prop.orientation = transform.orientation
      }
    }
  }

}
