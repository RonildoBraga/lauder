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
  private(set) var weaponProps: [PartyMember: Entity]
  private var partyWeaponKinds: [PartyMember: Weapon.Kind] = [:]
  private var partyWeaponCache: [PartyMember: [Weapon.Kind: Entity]] = [:]
  private let style: SceneStyle

  private var bodies: [String: Entity] = [:]
  private var visuals: [String: Entity] = [:]
  private var hostileWeaponProps: [String: Entity] = [:]
  private let targetMarker: Entity
  private let coverShields: [PartyMember: CoverShield]
  private let enemyCoverShields: [String: CoverShield]
  private let grenadeMarkers: [String: GrenadeMarker]
  private let arrivalMarkers: [String: ArenaArrivalMarker]
  private var throwerMarks: [String: Entity] = [:]
  private var roleMarks: [String: Entity] = [:]
  private var windUpCues: [String: Entity] = [:]
  private var windUpFills: [String: Entity] = [:]
  private let terrain: Terrain

  init(level: Level, style: SceneStyle) {
    self.style = style
    terrain = level.terrain
    let shots = Entity()
    shots.name = "combat.shots"
    effects = ShotEffects(style: style, in: shots, terrain: level.terrain)
    weaponProps = Dictionary(
      uniqueKeysWithValues: PartyMember.allCases.map {
        ($0, style.weapon(for: Weapon.forMember($0).kind))
      })
    for member in PartyMember.allCases {
      let kind = Weapon.forMember(member).kind
      partyWeaponKinds[member] = kind
      if let prop = weaponProps[member] { partyWeaponCache[member] = [kind: prop] }
    }
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
        let weapon = style.weapon(for: spec.weapon)
        weapon.name = "hostile.\(spec.id).\(spec.weapon)"
        visual.addChild(weapon)
        hostileWeaponProps[spec.id] = weapon
        if let mark = roleMark(for: spec.weapon, style: style) {
          mark.name = "hostile.\(spec.id).role"
          visual.addChild(mark)
          roleMarks[spec.id] = mark
        }
      }
      if (spec.attack == .shoot || spec.attack == .throwGrenade)
        && (level.arena != nil || spec.weapon == .marksman || spec.weapon == .supportGun)
      {
        // Reuse the simple countdown language above a preparing actor, in world space so
        // turning cannot hide it edge-on. It gives no aim direction or future impact point.
        let cue = Entity()
        cue.name = "hostile.\(spec.id).windup"
        cue.isEnabled = false
        cue.addChild(
          style.block(size: [1, 0.1, 0.1], at: .zero, material: style.gear))
        let fill = style.block(size: [0.92, 0.06, 0.12], at: [0, 0.035, 0], material: style.warm)
        fill.name = "hostile.\(spec.id).windup.remaining"
        cue.addChild(fill)
        container.addChild(cue)
        windUpCues[spec.id] = cue
        windUpFills[spec.id] = fill
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
      roleMarks[id]?.isEnabled = state.isVisible && !state.isDown
      if let cue = windUpCues[id] {
        if case .aiming(let remaining) = state.phase, fight.preparingShots.contains(id) {
          cue.isEnabled = true
          cue.position = [
            state.position.x, terrain.height(at: state.position) + PartyBody.height + 0.35,
            state.position.y,
          ]
          let fraction = max(0.02, min(1, remaining / max(0.001, state.spec.windUp)))
          windUpFills[id]?.scale.x = 0.92 * fraction
          windUpFills[id]?.position.x = -0.46 * (1 - fraction)
        } else {
          cue.isEnabled = false
        }
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
      targetMarker.position = [target.x, terrain.height(at: target) + 0.012, target.y]
      targetMarker.isEnabled = true
    } else {
      targetMarker.isEnabled = false
    }
    let drawn = fight.drawnWeapons
    for member in PartyMember.allCases {
      guard var prop = weaponProps[member] else { continue }
      let kind = fight.equippedWeapon(for: member).kind
      if partyWeaponKinds[member] != kind {
        let parent = prop.parent
        prop.isEnabled = false
        prop.removeFromParent()
        let replacement = partyWeaponCache[member]?[kind] ?? style.weapon(for: kind)
        partyWeaponCache[member, default: [:]][kind] = replacement
        parent?.addChild(replacement)
        weaponProps[member] = replacement
        partyWeaponKinds[member] = kind
        prop = replacement
      }
      prop.isEnabled = drawn.contains(member)
      if let pose = fight.weaponPoses[member] {
        let transform = pose.transform
        prop.position = transform.position
        prop.orientation = transform.orientation
      }
    }
  }

  /// Distinct equipment silhouettes in the existing palette; none implies armour or a
  /// larger hit pool. Weapon geometry supplies the barrel and magazine differences too.
  private func roleMark(for kind: Weapon.Kind, style: SceneStyle) -> Entity? {
    let result = Entity()
    switch kind {
    case .marksman:
      result.addChild(
        style.block(
          size: [0.3, 0.07, 0.13], at: [0, PartyBody.height / 2 + 0.1, 0],
          material: style.gear))
    case .supportGun:
      for side: Float in [-1, 1] {
        result.addChild(
          style.block(
            size: [0.14, 0.28, 0.2], at: [side * 0.3, 0.12, 0.05],
            material: style.gear))
      }
    case .submachineGun:
      result.addChild(
        style.block(size: [0.12, 0.32, 0.12], at: [-0.27, 0.2, 0.1], material: style.gear))
    case .closeScatter:
      result.addChild(
        style.block(size: [0.48, 0.1, 0.12], at: [0, 0.15, -0.08], material: style.gear))
    default: return nil
    }
    return result
  }

}
