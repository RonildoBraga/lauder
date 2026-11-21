import RealityKit
import simd

/// A level's fights and scripted scenes (ADR 0004, M2 to M4), and the leader's carbine (ADR
/// 0007). It plays an encounter's cues, runs each hostile, fires the leader's weapon where the
/// leader aims, in a fight or out of one, and, where the level's rules have it, the companions'
/// weapons (ADR 0005), and shows what happens: the hostiles' bodies, their aim before each shot,
/// the leader's aim, the shots, the target marker and the drawn weapon. The session keeps the
/// hits, the rounds, the loot and who is down; this keeps only spatial and moment-to-moment
/// state, and every entity is made once, at load.
@MainActor
final class EncounterStage {
  /// What one simulation step of a fight produced.
  struct Outcome {
    /// A short line for the HUD, such as Miki's "Friendly!".
    var line: String?
    /// Where the leader should face, towards where a shot just fired went.
    var facing: SIMD2<Float>?
    /// Someone took the last allowed hit: the encounter must start again, or the party falls
    /// back where the level has that rule.
    var retry = false
    /// Members who appeared in this step, such as Tom before his shot.
    var appeared: [PartyMember] = []
    /// Members who stood up in this step, such as Laura once she is helped.
    var stood: [PartyMember] = []
    /// A member who fired a scripted shot, and the direction they fired in.
    var shooter: (member: PartyMember, facing: SIMD2<Float>)?
    /// Two members who turn to face each other.
    var face: (PartyMember, PartyMember)?
  }

  /// Shoulder height for aim lines and shots.
  static let aimHeight: Float = 1.25
  /// During a fight the camera leans this share of the way towards the nearest hostile in the
  /// open, up to the limit, so the leader and the threat are both on screen.
  static let cameraLeanShare: Float = 0.4
  static let cameraLeanLimit: Float = 3
  /// While a scene with a focus plays, such as Laura calling out, the camera leans most of the
  /// way towards it, so it comes into view clear of the HUD whichever way the party approaches.
  static let focusShare: Float = 0.8
  static let focusLimit: Float = 7

  /// Holds the hostiles, aim lines, shots and target marker; the world adds it to the scene.
  let container = Entity()
  /// What every shot looks like (ADR 0007).
  let effects: ShotEffects
  /// The leader's weapon; the world puts it in the leader's hands.
  let weaponProp: Entity
  private(set) var hostiles: [String: HostileState] = [:]
  private(set) var isDrawn = false
  /// The HUD's warning, such as "The stranger is aiming."
  private(set) var threat: String?
  /// Whether the fight is under way: a hostile has begun a wind-up, or the leader has fired.
  /// Companions never fire before (ADR 0005).
  private(set) var fightUnderWay = false
  /// Where each companion firing by themselves aims, at their target, for them to face.
  private(set) var aims: [PartyMember: SIMD2<Float>] = [:]
  /// How many shots each companion has fired by themselves in this run. Tests and playtests
  /// read it.
  private(set) var companionShots: [PartyMember: Int] = [:]
  /// Whether the leader can Disrupt a wind-up now, for the HUD (ADR 0005).
  private(set) var canDisrupt = false
  /// How many wind-ups Disrupt has cancelled in this run. Tests and playtests read it.
  private(set) var disrupts = 0

  /// Whether the party stands still while a scripted scene plays, whoever leads.
  var holdsParty: Bool { encounter?.holdsParty == true }

  /// The current fight's standing shooters, as companions see them in a fight: where each
  /// stands, how far it reaches, whom its wind-up aims at, whether it is a target yet, and
  /// which way it faces (ADR 0003, phase S4).
  var threats: [CoverPlanner.Threat] {
    guard let encounter else { return [] }
    return encounter.hostiles.compactMap { spec in
      guard spec.attack == .shoot, let state = hostiles[spec.id], state.isVisible, !state.isDown
      else { return nil }
      return CoverPlanner.Threat(
        position: state.position, range: spec.range, aimingAt: victims[spec.id],
        isTarget: state.isTargetable, facing: facings[spec.id] ?? lookout)
    }
  }

  private let weapon = Weapon.carbine
  private let specs: [String: Level.Hostile]
  private let obstacles: [PartyMotion.Box]
  /// What stops the leader's shots: the level's blocks that rise above shoulder height, and a
  /// salvage task's gate as it stands (ADR 0007).
  private let shotBlockers: [PartyMotion.Box]
  private var gate: PartyMotion.Box?
  private let rules: Level.Combat
  /// Which way a hostile waiting in view faces: back along the level's starting heading,
  /// towards where the party comes from.
  private let lookout: SIMD2<Float>
  private var encounter: Level.Encounter?
  /// Whom each hostile that aims at anyone began its current wind-up at.
  private var victims: [String: PartyMember] = [:]
  /// Which way each hostile in the fight faces: towards whom it aims at, as a unit vector.
  private var facings: [String: SIMD2<Float>] = [:]
  /// When each companion's weapon fires next.
  private var companionFire: [PartyMember: AutoFire] = [:]
  private var director = StoryDirector()
  private var bodies: [String: Entity] = [:]
  private var visuals: [String: Entity] = [:]
  private var aimLines: [String: Entity] = [:]
  /// The leader's aim while the right stick aims the drawn carbine, out to where a shot would
  /// strike (ADR 0007).
  private let aimSight: Entity
  private let targetMarker: Entity
  /// How much larger than authored the aim marker and the aim and shot lines show.
  private let markerScale: Float
  private var drawRemaining: Float = 0
  private var cooldown: Float = 0
  private var reportedEmpty = false

  init(level: Level, style: SceneStyle) {
    obstacles = level.obstacles
    shotBlockers = Aim.blockers(level.boxes, above: Self.aimHeight)
    let shots = Entity()
    shots.name = "combat.shots"
    effects = ShotEffects(style: style, in: shots)
    aimSight = style.line(style.warm)
    rules = level.combat
    lookout = -level.heading
    let all = level.encounters.flatMap(\.hostiles)
    specs = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    weaponProp = style.carbine()
    markerScale = style.markerScale
    targetMarker = style.targetMarker()
    container.name = "combat"
    targetMarker.name = "combat.target"
    container.addChild(targetMarker)
    container.addChild(shots)
    aimSight.name = "leader.aim"
    aimSight.isEnabled = false
    container.addChild(aimSight)
    /// An aim or shot line, unseen until it is placed.
    func line(named name: String, _ material: any Material) -> Entity {
      let line = style.line(material)
      line.name = name
      line.isEnabled = false
      container.addChild(line)
      return line
    }
    for spec in all {
      let body = Entity()
      body.name = "hostile.\(spec.id)"
      let visual = style.hostile()
      body.addChild(visual)
      container.addChild(body)
      bodies[spec.id] = body
      visuals[spec.id] = visual
      aimLines[spec.id] = line(named: "hostile.\(spec.id).aim", style.threat)
    }
    reset()
  }

  /// Back to before any fight: hostiles unseen where they wait, or in view where they stand,
  /// nothing aimed or in flight, the weapon holstered. Restart and an encounter's retry both
  /// use it.
  func reset() {
    hostiles = specs.mapValues { HostileState(spec: $0) }
    companionShots = [:]
    disrupts = 0
    stopFighting()
  }

  /// The party fell back after the last allowed hit on anyone (ADR 0005): the fight stops, and
  /// every hostile still standing waits where it stands, keeping the damage dealt; those down
  /// stay down. Nothing is aimed or in flight, and the weapon is holstered.
  func fallBack() {
    for id in hostiles.keys { hostiles[id]?.standDown() }
    stopFighting()
  }

  /// No encounter under way, nothing aimed or in flight, the weapon holstered, and every
  /// hostile shown as it now is.
  private func stopFighting() {
    encounter = nil
    director.stop()
    isDrawn = false
    drawRemaining = 0
    cooldown = 0
    threat = nil
    reportedEmpty = false
    endFight()
    for line in aimLines.values { line.isEnabled = false }
    effects.clear()
    aimSight.isEnabled = false
    targetMarker.isEnabled = false
    weaponProp.isEnabled = false
    for (id, state) in hostiles { show(id, state) }
  }

  /// The fight is over: nobody is aimed at, nothing can be disrupted, and the companions hold
  /// their fire.
  private func endFight() {
    fightUnderWay = false
    victims = [:]
    facings = [:]
    companionFire = [:]
    aims = [:]
    canDisrupt = false
  }

  /// An encounter begins: its cues start playing. Its hostiles stay as they are: unseen where
  /// they wait, or in view where they stand, as Restart and a retry left them.
  func begin(_ encounter: Level.Encounter) {
    self.encounter = encounter
    director.start(encounter.cues)
  }

  /// One simulation step: cues, the leader's Disrupt, hostiles, the leader's weapon, then the
  /// companions'. `aim` is where the right stick aims the leader's carbine on the ground, if it
  /// does. `figures` are the members who can be seen, the leader included, for scripted shots
  /// and for hostiles that can aim at anyone. `mayDisrupt` says whether the leader has Disrupt to
  /// use: Miki, in a level that has it. Outside an encounter, only the leader's weapon acts, and
  /// its shots spend no rounds (ADR 0007).
  func step(
    dt: Float, leader: SIMD2<Float>, facing: SIMD2<Float>, aim: SIMD2<Float>?, fireHeld: Bool,
    firePressed: Bool, mayDisrupt: Bool, signaturePressed: Bool,
    figures: [PartyMember: SIMD2<Float>], session: GameSession
  ) -> Outcome {
    var outcome = Outcome()
    effects.update(dt: dt)
    // A fresh Fire press, or aiming with the right stick, draws a holstered weapon.
    if firePressed || aim != nil, !isDrawn {
      isDrawn = true
      drawRemaining = weapon.drawTime
      weaponProp.isEnabled = true
    }
    drawRemaining -= dt
    cooldown -= dt
    guard let encounter else {
      fireLeader(
        leader: leader, aim: aim, facing: facing, fireHeld: fireHeld, inFight: false,
        session: session, outcome: &outcome)
      updateTarget(leader: leader, aim: aim, facing: facing)
      return outcome
    }
    for cue in director.step(dt: dt) {
      switch cue {
      case .reveal(let id): hostiles[id]?.reveal()
      case .engage(let id): hostiles[id]?.engage()
      case .say(let speaker, let line): outcome.line = "\(speaker): “\(line)”"
      case .loot(let body):
        if let loot = specs[body]?.loot, session.search(body, loot: loot) {
          outcome.line = Self.describe(loot)
        }
      case .appear(let member): outcome.appeared.append(member)
      case .stand(let member): outcome.stood.append(member)
      case .shot(let member, let id):
        guard let from = figures[member], let state = hostiles[id], !state.isDown else { break }
        effects.show(
          ShotPath(start: from, end: state.position, strike: .body(id)), side: .party,
          height: Self.aimHeight)
        session.defeat(id)
        hostiles[id]?.knockDown()
        if let down = hostiles[id] { show(id, down, facing: from) }
        aimLines[id]?.isEnabled = false
        let offset = state.position - from
        if simd_length(offset) > 0.001 { outcome.shooter = (member, simd_normalize(offset)) }
        outcome.line = "\(state.spec.name) is down."
      case .face(let first, let second): outcome.face = (first, second)
      case .talk(let conversation): _ = session.converse(conversation)
      }
    }
    // The party, where they can be seen: who a hostile can hit, and who fires by themselves.
    let party = figures.filter { session.party.contains($0.key) }
    // Disrupt comes before the hostiles move on, so a press on the step that a wind-up would
    // end still answers it.
    if mayDisrupt, signaturePressed, let id = disruptable(from: leader, in: encounter) {
      disrupt(id, from: leader, outcome: &outcome)
    }
    var threatNow: String?
    for spec in encounter.hostiles {
      guard var state = hostiles[spec.id] else { continue }
      // The leader, or whoever a hostile that aims at anyone began its wind-up at.
      let victim = spec.targetsAnyone ? victims[spec.id] ?? session.leader : session.leader
      let aimedAt = party[victim] ?? leader
      let inRange = simd_distance(state.position, aimedAt) <= spec.range
      let canHit =
        inRange && LineOfSight.isClear(from: state.position, to: aimedAt, obstacles: obstacles)
      if let shot = state.step(dt: dt, canHit: canHit, toward: leader) {
        fire(from: state.position, at: aimedAt, victim: victim, range: spec.range, shot: shot)
        if shot == .miss, let line = spec.missLine { outcome.line = line }
        if shot == .hit, session.takeHit(victim) { outcome.retry = true }
      }
      if case .aiming = state.phase {
        fightUnderWay = true
        if spec.targetsAnyone, victims[spec.id] == nil {
          victims[spec.id] = nearestInSight(of: state, among: party) ?? session.leader
        }
      } else {
        victims[spec.id] = nil
      }
      // Whom it aims at now, for its aim line, its facing and the HUD.
      let aim = spec.targetsAnyone ? victims[spec.id] ?? session.leader : session.leader
      let aimPosition = party[aim] ?? leader
      switch state.phase {
      case .aiming:
        threatNow =
          spec.targetsAnyone
          ? "\(spec.name) is aiming at \(aim.displayName)." : "\(spec.name) is aiming."
      case .charging: threatNow = "\(spec.name) is running at you."
      default: break
      }
      hostiles[spec.id] = state
      let facing = aimPosition - state.position
      if simd_length(facing) > 0.001 { facings[spec.id] = simd_normalize(facing) }
      show(spec.id, state, facing: aimPosition)
      showAim(spec.id, state, at: aimPosition)
    }
    threat = threatNow
    canDisrupt = mayDisrupt && disruptable(from: leader, in: encounter) != nil
    if outcome.retry { return outcome }
    fireLeader(
      leader: leader, aim: aim, facing: facing, fireHeld: fireHeld, inFight: true,
      session: session, outcome: &outcome)
    // Companions fire by themselves once the fight is under way, never before, not while a
    // scene holds the party (ADR 0005), and not while they regroup (ADR 0003, phase S4).
    if fightUnderWay, !encounter.holdsParty, !rules.companionWeapons.isEmpty, !session.regrouping {
      fireCompanions(dt: dt, party: party, session: session, outcome: &outcome)
    } else {
      aims = [:]
    }
    // A fight ends once everyone in it is down; a scene also plays its timeline to the end.
    if !director.isPlaying, encounter.hostiles.allSatisfy({ session.defeated.contains($0.id) }) {
      session.endEncounter()
      self.encounter = nil
      director.stop()
      threat = nil
      for line in aimLines.values { line.isEnabled = false }
      if let line = encounter.clearedLine { outcome.line = line }
      endFight()
    }
    updateTarget(leader: leader, aim: aim, facing: facing)
    return outcome
  }

  /// The leader's shot, while Fire is held and the drawn carbine is ready: along the right
  /// stick's aim, or at the assisted target, or straight ahead (ADR 0007). In a fight it spends
  /// a round and puts the fight under way; outside one it spends nothing.
  private func fireLeader(
    leader: SIMD2<Float>, aim: SIMD2<Float>?, facing: SIMD2<Float>, fireHeld: Bool,
    inFight: Bool, session: GameSession, outcome: inout Outcome
  ) {
    guard fireHeld, isDrawn, drawRemaining <= 0, cooldown <= 0,
      let path = leaderShot(from: leader, aim: aim, facing: facing)
    else { return }
    if inFight {
      guard session.spendRound() else {
        if !reportedEmpty {
          reportedEmpty = true
          outcome.line = "Out of ammunition."
        }
        return
      }
      fightUnderWay = true
    }
    cooldown = weapon.interval
    effects.show(path, side: .party, height: Self.aimHeight)
    let offset = path.end - leader
    if simd_length(offset) > 0.001 { outcome.facing = simd_normalize(offset) }
    if inFight, case .body(let id) = path.strike, let state = hostiles[id],
      session.hit(id, toughness: state.spec.hits)
    {
      knockDown(id, from: leader, outcome: &outcome)
    }
  }

  /// Where the leader's shot would go now, among the hostiles standing in view; nil while it
  /// would meet one who is not yet a target.
  private func leaderShot(from leader: SIMD2<Float>, aim: SIMD2<Float>?, facing: SIMD2<Float>)
    -> ShotPath?
  {
    let standing = hostiles.values.filter { $0.isVisible && !$0.isDown }.map {
      Aim.Hostile(id: $0.spec.id, position: $0.position, isTarget: $0.isTargetable)
    }
    return Aim.shot(
      from: leader, aim: aim, facing: facing, range: weapon.range, hostiles: standing,
      blockers: blockers)
  }

  /// What stops the leader's shots now.
  private var blockers: [PartyMotion.Box] { shotBlockers + (gate.map { [$0] } ?? []) }

  /// A salvage task's gate as it stands, shut in the fence or swung open, which stops the
  /// leader's shots as it stops movement (ADR 0006, ADR 0007).
  func setGate(_ footprint: PartyMotion.Box?) {
    gate = footprint
  }

  /// Each companion with a weapon fires by themselves at their own assisted target, the nearest
  /// hostile that is a target, in clear sight and within reach, at their weapon's own pace. Their
  /// shots spend no rounds.
  private func fireCompanions(
    dt: Float, party: [PartyMember: SIMD2<Float>], session: GameSession,
    outcome: inout Outcome
  ) {
    var aims: [PartyMember: SIMD2<Float>] = [:]
    for member in session.companions {
      guard let weapon = rules.companionWeapons[member], let from = party[member] else { continue }
      let candidates = hostiles.values.filter(\.isTargetable).map {
        Targeting.Candidate(id: $0.spec.id, position: $0.position)
      }
      let target = Targeting.nearest(
        from: from, candidates: candidates, range: weapon.range,
        isClear: { LineOfSight.isClear(from: $0, to: $1, obstacles: self.obstacles) })
      var trigger = companionFire[member] ?? AutoFire(weapon: weapon)
      let fires = trigger.step(dt: dt, weapon: weapon, hasTarget: target != nil)
      companionFire[member] = trigger
      guard let target, let state = hostiles[target] else { continue }
      aims[member] = state.position
      guard fires else { continue }
      effects.show(
        ShotPath(start: from, end: state.position, strike: .body(target)), side: .party,
        height: Self.aimHeight)
      companionShots[member, default: 0] += 1
      // A blast that counts as several hits stops counting once the hostile is down.
      for _ in 0..<weapon.damage {
        guard session.hit(target, toughness: state.spec.hits) else { continue }
        knockDown(target, from: from, outcome: &outcome)
        break
      }
    }
    self.aims = aims
  }

  /// Whom a hostile that aims at anyone begins its wind-up at: the nearest member in clear
  /// sight within its reach. Nil when there is nobody, and it aims at the leader, whose shot
  /// cover or distance will stop.
  private func nearestInSight(of state: HostileState, among party: [PartyMember: SIMD2<Float>])
    -> PartyMember?
  {
    let candidates = party.map { Targeting.Candidate(id: $0.key.rawValue, position: $0.value) }
    return Targeting.nearest(
      from: state.position, candidates: candidates, range: state.spec.range,
      isClear: { LineOfSight.isClear(from: $0, to: $1, obstacles: self.obstacles) }
    ).flatMap(PartyMember.init(rawValue:))
  }

  /// The wind-up that Disrupt from the leader would cancel now, if any.
  private func disruptable(from leader: SIMD2<Float>, in encounter: Level.Encounter) -> String? {
    Disrupt.target(
      from: leader, hostiles: encounter.hostiles.compactMap { hostiles[$0.id] },
      isClear: { LineOfSight.isClear(from: $0, to: $1, obstacles: self.obstacles) })
  }

  /// Miki's Disrupt (ADR 0005): her precise shot cancels the hostile's wind-up, and it recovers
  /// before it can aim again. It spends no round.
  private func disrupt(_ id: String, from leader: SIMD2<Float>, outcome: inout Outcome) {
    guard var state = hostiles[id] else { return }
    state.disrupt()
    hostiles[id] = state
    victims[id] = nil
    aimLines[id]?.isEnabled = false
    disrupts += 1
    effects.show(
      ShotPath(start: leader, end: state.position, strike: .body(id)), side: .party,
      height: Self.aimHeight)
    let offset = state.position - leader
    if simd_length(offset) > 0.001 { outcome.facing = simd_normalize(offset) }
    outcome.line = "\(state.spec.name)'s shot is disrupted."
  }

  /// A hostile goes down where it stood, facing whoever shot it; its aim goes, and the HUD says
  /// so.
  private func knockDown(_ id: String, from shooter: SIMD2<Float>, outcome: inout Outcome) {
    hostiles[id]?.knockDown()
    if let down = hostiles[id] { show(id, down, facing: shooter) }
    aimLines[id]?.isEnabled = false
    victims[id] = nil
    if let name = specs[id]?.name { outcome.line = "\(name) is down." }
  }

  /// What a search found, for the HUD.
  static func describe(_ loot: Level.Loot) -> String {
    var found: [String] = []
    if loot.rounds > 0 { found.append(loot.rounds == 1 ? "a round" : "\(loot.rounds) rounds") }
    if loot.medicalKits > 0 {
      found.append(loot.medicalKits == 1 ? "a medical kit" : "\(loot.medicalKits) medical kits")
    }
    return found.isEmpty ? "Nothing useful." : "Found " + found.joined(separator: " and ") + "."
  }

  /// Where the camera's target should lean from the leader: towards a scene's focus while it
  /// plays, or towards the nearest hostile that has stepped out and is still standing, during a
  /// fight; otherwise nowhere.
  func cameraLean(leader: SIMD2<Float>) -> SIMD2<Float> {
    guard let encounter else { return .zero }
    if let focus = encounter.focus {
      return Self.lean(from: leader, towards: focus, share: Self.focusShare, limit: Self.focusLimit)
    }
    guard
      let nearest = hostiles.values.filter({ $0.isVisible && !$0.isDown }).min(by: {
        simd_distance_squared($0.position, leader) < simd_distance_squared($1.position, leader)
      })
    else { return .zero }
    return Self.lean(
      from: leader, towards: nearest.position, share: Self.cameraLeanShare,
      limit: Self.cameraLeanLimit)
  }

  private static func lean(
    from leader: SIMD2<Float>, towards point: SIMD2<Float>, share: Float, limit: Float
  ) -> SIMD2<Float> {
    let lean = (point - leader) * share
    let length = simd_length(lean)
    return length > limit ? lean / length * limit : lean
  }

  // MARK: - Showing it

  /// The marker under the hostile the leader's next shot would hit, and, while the right stick
  /// aims the drawn carbine, the aim out to where that shot would strike.
  private func updateTarget(leader: SIMD2<Float>, aim: SIMD2<Float>?, facing: SIMD2<Float>) {
    let path = isDrawn ? leaderShot(from: leader, aim: aim, facing: facing) : nil
    if case .body(let id) = path?.strike, let state = hostiles[id] {
      targetMarker.isEnabled = true
      targetMarker.position = [state.position.x, 0.012, state.position.y]
    } else {
      targetMarker.isEnabled = false
    }
    guard isDrawn, let aim,
      let end = path?.end
        ?? Aim.ray(from: leader, along: aim, range: weapon.range, hostiles: [], blockers: blockers)?
        .end
    else {
      aimSight.isEnabled = false
      return
    }
    place(aimSight, from: leader, to: end, thickness: 0.015 * markerScale)
    aimSight.isEnabled = true
  }

  /// A hostile's body: unseen while it waits out of view, facing whom it aims at while it
  /// fights, or the way the party comes from while it waits in view, and lying on the ground once
  /// down.
  private func show(_ id: String, _ state: HostileState, facing point: SIMD2<Float>? = nil) {
    guard let body = bodies[id], let visual = visuals[id] else { return }
    body.isEnabled = state.isVisible
    body.position = [state.position.x, PartyBody.height / 2, state.position.y]
    if state.isDown {
      visual.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
      visual.position = [0, -0.6, 0]
    } else {
      let offset = (point ?? state.position + lookout) - state.position
      visual.orientation = simd_quatf(angle: Movement.yaw(towards: offset), axis: [0, 1, 0])
      visual.position = .zero
    }
  }

  /// The aim line from a hostile winding up its shot to whom it aims at: the warning to take
  /// cover.
  private func showAim(_ id: String, _ state: HostileState, at point: SIMD2<Float>) {
    guard let line = aimLines[id] else { return }
    guard case .aiming = state.phase else {
      line.isEnabled = false
      return
    }
    place(line, from: state.position, to: point, thickness: 0.025 * markerScale)
    line.isEnabled = true
  }

  /// A hostile's shot at the leader, or at whom it aims: into the cover, which it chips, or
  /// falling short of someone out of range; otherwise just past them when it misses on purpose,
  /// or into them.
  private func fire(
    from start: SIMD2<Float>, at point: SIMD2<Float>, victim: PartyMember, range: Float,
    shot: HostileState.Shot
  ) {
    let distance = simd_distance(start, point)
    guard distance > 0.001 else { return }
    let block = LineOfSight.firstBlock(from: start, to: point, obstacles: obstacles) ?? 1
    let reach = min(block, range / distance)
    let direction = (point - start) / distance
    let path =
      if reach < 1 {
        ShotPath(
          start: start, end: start + (point - start) * reach,
          strike: block < 1 && block <= range / distance ? .scenery : .nothing)
      } else if shot == .miss {
        ShotPath(
          start: start, end: point + SIMD2(-direction.y, direction.x) * 0.7 + direction * 3,
          strike: .nothing)
      } else {
        ShotPath(start: start, end: point, strike: .body(victim.rawValue))
      }
    effects.show(path, side: .hostile, height: Self.aimHeight)
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
}
