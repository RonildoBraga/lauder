import RealityKit
import simd

/// Presents a fight's values (ADR 0004, ADR 0007, ADR 0008). The simulation owns the hostiles,
/// shots, aim and poses; this owns only their entities. Every entity is made once at load, and
/// the world applies each simulation step before asking this stage to show it.
@MainActor
final class EncounterStage {
  /// Holds the hostiles, aim lines, shots and target marker; the world adds it to the scene.
  let container = Entity()
  /// What every shot looks like (ADR 0007).
  let effects: ShotEffects
  /// Each member's weapon, posed at its grip; the world attaches it to that member's visual.
  let weaponProps: [PartyMember: Entity]

  private var bodies: [String: Entity] = [:]
  private var visuals: [String: Entity] = [:]
  private var aimLines: [String: Entity] = [:]
  private let targetMarker: Entity
  private let coverShields: [PartyMember: CoverShield]
  private let enemyCoverShields: [String: CoverShield]
  private let grenadeMarkers: [String: GrenadeMarker]
  private var throwerMarks: [String: Entity] = [:]
  /// How much larger than authored the aim marker and the aim and shot lines show.
  private let markerScale: Float

  init(level: Level, style: SceneStyle) {
    let shots = Entity()
    shots.name = "combat.shots"
    effects = ShotEffects(style: style, in: shots)
    weaponProps = Dictionary(
      uniqueKeysWithValues: PartyMember.allCases.map {
        ($0, style.weapon(for: Weapon.forMember($0).kind))
      })
    markerScale = style.markerScale
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
    container.name = "combat"
    targetMarker.name = "combat.target"
    container.addChild(targetMarker)
    container.addChild(shots)
    for shield in coverShields.values { container.addChild(shield.entity) }
    for shield in enemyCoverShields.values { container.addChild(shield.entity) }
    for marker in grenadeMarkers.values { container.addChild(marker.entity) }

    for spec in specs {
      let body = Entity()
      body.name = "hostile.\(spec.id)"
      let visual = style.hostile()
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

      let line = style.line(style.threat)
      line.name = "hostile.\(spec.id).aim"
      line.isEnabled = false
      container.addChild(line)
      aimLines[spec.id] = line
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
      effects.show(
        shot.path, side: side, height: FightSimulation.aimHeight, muzzle: shot.muzzle)
    }
    for point in fight.explosions { effects.blast(at: point) }
    show(fight)
  }

  /// Applies the state without advancing it or choosing a target, pose, shot or outcome.
  private func show(_ fight: FightSimulation) {
    for (member, shield) in coverShields {
      if let cover = fight.coverStates[member] {
        shield.show(at: cover.position, toward: -cover.normal, exposed: cover.exposed)
      } else {
        shield.hide()
      }
    }
    for (id, shield) in enemyCoverShields {
      if let cover = fight.enemyCoverStates[id], fight.hostiles[id]?.isDown == false {
        shield.show(at: cover.position, toward: -cover.normal, exposed: cover.exposed)
      } else {
        shield.hide()
      }
    }
    for (owner, marker) in grenadeMarkers {
      marker.show(fight.grenades.first { $0.owner == owner })
    }
    for (id, state) in fight.hostiles {
      if let body = bodies[id] {
        body.isEnabled = state.isVisible
        body.position = [state.position.x, PartyBody.height / 2, state.position.y]
      }
      if let visual = visuals[id], let pose = fight.hostilePoses[id] {
        visual.scale = [1, pose.scale, 1]
        visual.orientation = pose.orientation
        visual.position = pose.position
      }
      throwerMarks[id]?.isEnabled = state.isVisible && !state.isDown
      if let line = aimLines[id] {
        if let point = fight.hostileAimPoints[id] {
          place(
            line, from: fight.hostileAimOrigins[id] ?? state.position,
            to: point, thickness: 0.025 * markerScale)
          line.isEnabled = true
        } else {
          line.isEnabled = false
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
    for (member, prop) in weaponProps {
      prop.isEnabled = drawn.contains(member)
      if let pose = fight.weaponPoses[member] {
        let transform = pose.transform
        prop.position = transform.position
        prop.orientation = transform.orientation
      }
    }
  }

  private func place(
    _ line: Entity, from start: SIMD2<Float>, to end: SIMD2<Float>, thickness: Float
  ) {
    let from = SIMD3(start.x, FightSimulation.aimHeight, start.y)
    let to = SIMD3(end.x, FightSimulation.aimHeight, end.y)
    let span = to - from
    let length = max(simd_length(span), 0.01)
    line.position = (from + to) / 2
    line.scale = [thickness, thickness, length]
    line.orientation = simd_quatf(from: [0, 0, 1], to: span / length)
  }
}
