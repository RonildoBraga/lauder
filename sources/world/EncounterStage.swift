import RealityKit
import simd

/// A level's fights in the scene (ADR 0004, M2). It plays an encounter's cues, runs each
/// hostile, fires the leader's weapon at the assisted target and shows what happens: the
/// hostiles' bodies, their aim before each shot, the shots, the target marker and the drawn
/// weapon. The session keeps the hits, the rounds and who is down; this keeps only spatial
/// and moment-to-moment state, and every entity is made once, at load.
@MainActor
final class EncounterStage {
  /// What one simulation step of a fight produced.
  struct Outcome {
    /// A short line for the HUD, such as Miki's "Friendly!".
    var line: String?
    /// Where the leader should face, towards the target of a shot just fired.
    var facing: SIMD2<Float>?
    var leaderHit = false
    /// The leader took the last allowed hit: the encounter must start again.
    var retry = false
    var won = false
  }

  /// How long a shot's tracer stays on screen.
  static let tracerTime: Float = 0.08
  /// Shoulder height for aim lines and shots.
  static let aimHeight: Float = 1.25
  /// During a fight the camera leans this share of the way towards the nearest hostile in the
  /// open, up to the limit, so the leader and the threat are both on screen.
  static let cameraLeanShare: Float = 0.4
  static let cameraLeanLimit: Float = 3

  let weapon = Weapon.carbine
  /// Holds the hostiles, aim lines, shots and target marker; the world adds it to the scene.
  let container = Entity()
  /// The leader's weapon; the world puts it in the leader's hands.
  let weaponProp: Entity
  private(set) var encounter: Level.Encounter?
  private(set) var hostiles: [String: HostileState] = [:]
  private(set) var isDrawn = false
  /// The assisted target while the weapon is drawn.
  private(set) var target: String?
  /// Who is winding up a shot, for the HUD.
  private(set) var aiming: String?

  private let specs: [String: Level.Hostile]
  private let obstacles: [PartyMotion.Box]
  private var director = StoryDirector()
  private var bodies: [String: Entity] = [:]
  private var visuals: [String: Entity] = [:]
  private var aimLines: [String: Entity] = [:]
  private var tracers: [String: Entity] = [:]
  private var tracerRemaining: [String: Float] = [:]
  private let leaderTracerID = "leader"
  private let targetMarker: Entity
  private var drawRemaining: Float = 0
  private var cooldown: Float = 0
  private var reportedEmpty = false

  init(level: Level, style: SceneStyle) {
    obstacles = level.obstacles(passageOpen: false)
    let all = level.encounters.flatMap(\.hostiles)
    specs = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    weaponProp = style.carbine()
    targetMarker = ModelEntity(
      mesh: .generateCylinder(height: 0.012, radius: 0.48), materials: [style.threat])
    container.name = "combat"
    targetMarker.name = "combat.target"
    container.addChild(targetMarker)
    for spec in all {
      let body = Entity()
      body.name = "hostile.\(spec.id)"
      let visual = style.hostile()
      body.addChild(visual)
      container.addChild(body)
      bodies[spec.id] = body
      visuals[spec.id] = visual
      aimLines[spec.id] = Self.line(
        named: "hostile.\(spec.id).aim", material: style.threat, container)
      tracers[spec.id] = Self.line(
        named: "hostile.\(spec.id).shot", material: style.threat, container)
    }
    tracers[leaderTracerID] = Self.line(named: "leader.shot", material: style.warm, container)
    reset()
  }

  /// Back to before any fight: hostiles unseen where they wait, nothing aimed or in flight, the
  /// weapon holstered. Restart and an encounter's retry both use it.
  func reset() {
    encounter = nil
    director.stop()
    hostiles = specs.mapValues { HostileState(spec: $0) }
    isDrawn = false
    drawRemaining = 0
    cooldown = 0
    target = nil
    aiming = nil
    reportedEmpty = false
    tracerRemaining = [:]
    for line in aimLines.values { line.isEnabled = false }
    for tracer in tracers.values { tracer.isEnabled = false }
    targetMarker.isEnabled = false
    weaponProp.isEnabled = false
    for (id, state) in hostiles { show(id, state) }
  }

  /// An encounter begins: its cues start playing.
  func begin(_ encounter: Level.Encounter) {
    self.encounter = encounter
    for spec in encounter.hostiles { hostiles[spec.id] = HostileState(spec: spec) }
    director.start(encounter.cues)
  }

  /// One simulation step: cues, hostiles, then the leader's weapon.
  func step(
    dt: Float, leader: SIMD2<Float>, facing: SIMD2<Float>, fireHeld: Bool, firePressed: Bool,
    session: GameSession
  ) -> Outcome {
    var outcome = Outcome()
    fadeTracers(dt: dt)
    if firePressed, !isDrawn {
      isDrawn = true
      drawRemaining = weapon.drawTime
      weaponProp.isEnabled = true
    }
    guard let encounter else {
      updateTarget(leader: leader, facing: facing)
      return outcome
    }
    for cue in director.step(dt: dt) {
      switch cue {
      case .reveal(let id): hostiles[id]?.reveal()
      case .engage(let id): hostiles[id]?.engage()
      case .say(let speaker, let line): outcome.line = "\(speaker): “\(line)”"
      }
    }
    var aimingNow: String?
    for spec in encounter.hostiles {
      guard var state = hostiles[spec.id] else { continue }
      let inRange = simd_distance(state.position, leader) <= spec.range
      let canHit =
        inRange && LineOfSight.isClear(from: state.position, to: leader, obstacles: obstacles)
      if let shot = state.step(dt: dt, canHit: canHit) {
        fire(spec.id, from: state.position, at: leader, range: spec.range, shot: shot)
        if shot == .miss, let line = spec.missLine { outcome.line = line }
        if shot == .hit {
          outcome.leaderHit = true
          if session.takeHit() { outcome.retry = true }
        }
      }
      if case .aiming = state.phase { aimingNow = spec.id }
      hostiles[spec.id] = state
      show(spec.id, state, facing: leader)
      showAim(spec.id, state, at: leader)
    }
    aiming = aimingNow
    if outcome.retry { return outcome }
    updateTarget(leader: leader, facing: facing)
    drawRemaining -= dt
    cooldown -= dt
    if fireHeld, isDrawn, drawRemaining <= 0, cooldown <= 0, let target,
      let state = hostiles[target]
    {
      if session.spendRound() {
        cooldown = weapon.interval
        showTracer(leaderTracerID, from: leader, to: state.position)
        let offset = state.position - leader
        if simd_length(offset) > 0.001 { outcome.facing = simd_normalize(offset) }
        if session.hit(target, toughness: state.spec.hits) {
          hostiles[target]?.knockDown()
          if let down = hostiles[target] { show(target, down, facing: leader) }
          aimLines[target]?.isEnabled = false
          outcome.line = "\(state.spec.name) is down."
        }
      } else if !reportedEmpty {
        reportedEmpty = true
        outcome.line = "Out of ammunition."
      }
    }
    if encounter.hostiles.allSatisfy({ session.defeated.contains($0.id) }) {
      session.endEncounter()
      self.encounter = nil
      director.stop()
      aiming = nil
      for line in aimLines.values { line.isEnabled = false }
      outcome.won = true
    }
    updateTarget(leader: leader, facing: facing)
    return outcome
  }

  /// Where the camera's target should lean from the leader: towards the nearest hostile that
  /// has stepped out and is still standing, during a fight; otherwise nowhere.
  func cameraLean(leader: SIMD2<Float>) -> SIMD2<Float> {
    guard encounter != nil,
      let nearest = hostiles.values.filter({ $0.isVisible && !$0.isDown }).min(by: {
        simd_distance_squared($0.position, leader) < simd_distance_squared($1.position, leader)
      })
    else { return .zero }
    let lean = (nearest.position - leader) * Self.cameraLeanShare
    let length = simd_length(lean)
    return length > Self.cameraLeanLimit ? lean / length * Self.cameraLeanLimit : lean
  }

  // MARK: - Showing it

  private func updateTarget(leader: SIMD2<Float>, facing: SIMD2<Float>) {
    let candidates = hostiles.values.filter(\.isTargetable).map {
      Targeting.Candidate(id: $0.spec.id, position: $0.position)
    }
    target =
      isDrawn
      ? Targeting.target(
        from: leader, facing: facing, candidates: candidates, range: weapon.range,
        isClear: { LineOfSight.isClear(from: $0, to: $1, obstacles: self.obstacles) })
      : nil
    if let target, let state = hostiles[target] {
      targetMarker.isEnabled = true
      targetMarker.position = [state.position.x, 0.012, state.position.y]
    } else {
      targetMarker.isEnabled = false
    }
  }

  /// A hostile's body: unseen while it waits, facing the leader while it stands, lying on the
  /// ground once down.
  private func show(_ id: String, _ state: HostileState, facing leader: SIMD2<Float>? = nil) {
    guard let body = bodies[id], let visual = visuals[id] else { return }
    body.isEnabled = state.isVisible
    body.position = [state.position.x, PartyBody.height / 2, state.position.y]
    if state.isDown {
      visual.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
      visual.position = [0, -0.6, 0]
    } else {
      let offset = (leader ?? state.position + [0, -1]) - state.position
      visual.orientation = simd_quatf(angle: atan2(-offset.x, -offset.y), axis: [0, 1, 0])
      visual.position = .zero
    }
  }

  /// The aim line from a hostile winding up its shot to the leader: the warning to take cover.
  private func showAim(_ id: String, _ state: HostileState, at leader: SIMD2<Float>) {
    guard let line = aimLines[id] else { return }
    guard case .aiming = state.phase else {
      line.isEnabled = false
      return
    }
    place(line, from: state.position, to: leader, thickness: 0.025)
    line.isEnabled = true
  }

  /// A hostile's shot: into the cover, or falling short of a leader out of range; otherwise just
  /// past the leader when it misses on purpose, or into the leader.
  private func fire(
    _ id: String, from start: SIMD2<Float>, at leader: SIMD2<Float>, range: Float,
    shot: HostileState.Shot
  ) {
    let distance = simd_distance(start, leader)
    guard distance > 0.001 else { return }
    let block = LineOfSight.firstBlock(from: start, to: leader, obstacles: obstacles) ?? 1
    let reach = min(block, range / distance)
    let direction = (leader - start) / distance
    if reach < 1 {
      showTracer(id, from: start, to: start + (leader - start) * reach)
    } else if shot == .miss {
      showTracer(
        id, from: start, to: leader + SIMD2(-direction.y, direction.x) * 0.7 + direction * 3)
    } else {
      showTracer(id, from: start, to: leader)
    }
  }

  private func showTracer(_ id: String, from start: SIMD2<Float>, to end: SIMD2<Float>) {
    guard let tracer = tracers[id] else { return }
    place(tracer, from: start, to: end, thickness: 0.04)
    tracer.isEnabled = true
    tracerRemaining[id] = Self.tracerTime
  }

  private func fadeTracers(dt: Float) {
    for (id, remaining) in tracerRemaining {
      if remaining - dt <= 0 {
        tracers[id]?.isEnabled = false
        tracerRemaining[id] = nil
      } else {
        tracerRemaining[id] = remaining - dt
      }
    }
  }

  private func place(
    _ line: Entity, from start: SIMD2<Float>, to end: SIMD2<Float>, thickness: Float
  ) {
    let from = SIMD3(start.x, Self.aimHeight, start.y)
    let to = SIMD3(end.x, Self.aimHeight, end.y)
    let span = to - from
    let length = max(simd_length(span), 0.01)
    line.position = (from + to) / 2
    line.scale = [thickness, thickness, length]
    line.orientation = simd_quatf(from: [0, 0, 1], to: span / length)
  }

  private static func line(named name: String, material: any Material, _ root: Entity) -> Entity {
    let line = ModelEntity(mesh: .generateBox(size: 1), materials: [material])
    line.name = name
    line.isEnabled = false
    root.addChild(line)
    return line
  }
}
