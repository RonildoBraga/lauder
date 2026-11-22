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
  /// The leader's weapon, posed at its grip; the world puts it in the leader's hands.
  let weaponProp: Entity

  private var bodies: [String: Entity] = [:]
  private var visuals: [String: Entity] = [:]
  private var aimLines: [String: Entity] = [:]
  private let targetMarker: Entity
  /// How much larger than authored the aim marker and the aim and shot lines show.
  private let markerScale: Float

  init(level: Level, style: SceneStyle) {
    let shots = Entity()
    shots.name = "combat.shots"
    effects = ShotEffects(style: style, in: shots)
    weaponProp = style.carbine()
    markerScale = style.markerScale
    targetMarker = style.targetMarker()
    container.name = "combat"
    targetMarker.name = "combat.target"
    container.addChild(targetMarker)
    container.addChild(shots)

    for spec in level.encounters.flatMap(\.hostiles) {
      let body = Entity()
      body.name = "hostile.\(spec.id)"
      let visual = style.hostile()
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
    show(fight)
  }

  /// Applies the state without advancing it or choosing a target, pose, shot or outcome.
  private func show(_ fight: FightSimulation) {
    for (id, state) in fight.hostiles {
      if let body = bodies[id] {
        body.isEnabled = state.isVisible
        body.position = [state.position.x, PartyBody.height / 2, state.position.y]
      }
      if let visual = visuals[id], let pose = fight.hostilePoses[id] {
        visual.orientation = pose.orientation
        visual.position = pose.position
      }
      if let line = aimLines[id] {
        if let point = fight.hostileAimPoints[id] {
          place(line, from: state.position, to: point, thickness: 0.025 * markerScale)
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
    weaponProp.isEnabled = fight.isDrawn
    if fight.isDrawn {
      let transform = fight.pose.transform
      weaponProp.position = transform.position
      weaponProp.orientation = transform.orientation
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
