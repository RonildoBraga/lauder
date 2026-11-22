import simd

/// A level's fights and scripted cues as values. It advances hostiles, weapons, spread and
/// reactions in the existing fixed simulation step and reports shots and feedback without
/// creating entities or playing audio or haptics. GameSession still owns progress and damage.
@MainActor
final class FightSimulation {
  /// A shot for the stage to show once, with the same path and muzzle used by the rules.
  struct Shot {
    enum Side { case party, hostile }
    let path: ShotPath
    let side: Side
    var muzzle: SIMD2<Float>? = nil
  }

  /// The pose last presented at a simulation instant. Capturing it at the original update
  /// points preserves when a new hit's jolt first appears, as well as a downed body's fall.
  struct FigurePose {
    let orientation: simd_quatf
    let position: SIMD3<Float>
  }

  /// What one simulation step of a fight produced.
  struct Outcome {
    /// A short line for the HUD, such as Miki's "Friendly!".
    var line: String?
    /// Where the leader should turn to face: towards the assisted target while Fire turns her
    /// to it, or towards the wind-up she disrupted.
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
  /// Where the leader's shots' spread starts its numbers, so every run scatters the same way.
  static let seed: UInt64 = 8

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
  /// How each member of the party rocks after firing or being hit, while it lasts (ADR 0008).
  private(set) var jolts: [PartyMember: BodyJolt] = [:]
  /// How the leader holds her weapon now (ADR 0008).
  private(set) var pose = WeaponPose()
  /// What players hear and feel since the world last took them (ADR 0008).
  private(set) var events: [CombatEvent] = []

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
  /// The target marker and the hostiles' warnings as last shown by the rules.
  private(set) var target: SIMD2<Float>?
  private(set) var hostileAimPoints: [String: SIMD2<Float>] = [:]
  private(set) var hostilePoses: [String: FigurePose] = [:]
  /// Visual shots from this step only, in firing order; the stage reads them immediately.
  private(set) var shots: [Shot] = []
  private var drawRemaining: Float = 0
  private var cooldown: Float = 0
  private var reportedEmpty = false
  /// The leader's spread, and what picks where in it each shot goes (ADR 0008).
  private var scatter = Scatter()
  private var random = SeededRandom(seed: FightSimulation.seed)
  /// Where the leader stood and faced a step ago: how fast she moves and turns widens her spread.
  private var lastLeader: (position: SIMD2<Float>, facing: SIMD2<Float>)?
  /// Each standing hostile's turn, how it rocks after firing or being hit, and the fall of each
  /// one downed (ADR 0008).
  private var hostileYaws: [String: Float] = [:]
  private(set) var hostileJolts: [String: BodyJolt] = [:]
  private(set) var falls: [String: Fall] = [:]

  init(level: Level) {
    obstacles = level.obstacles
    shotBlockers = Aim.blockers(level.boxes, above: Self.aimHeight)
    rules = level.combat
    lookout = -level.heading
    specs = Dictionary(
      uniqueKeysWithValues: level.encounters.flatMap(\.hostiles).map { ($0.id, $0) })
    reset()
  }

  /// Back to before any fight: hostiles unseen where they wait, or in view where they stand,
  /// nothing aimed or in flight, the weapon holstered. Restart and an encounter's retry both
  /// use it.
  func reset() {
    hostiles = specs.mapValues { HostileState(spec: $0) }
    companionShots = [:]
    disrupts = 0
    random = SeededRandom(seed: Self.seed)
    falls = [:]
    hostileJolts = [:]
    jolts = [:]
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
    pose.holster()
    scatter = Scatter()
    lastLeader = nil
    endFight()
    hostileAimPoints = [:]
    target = nil
    shots.removeAll(keepingCapacity: true)
    for (id, state) in hostiles { faceHostile(id, state) }
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

  /// What players hear and feel since the last call, which empties the list (ADR 0008).
  func takeEvents() -> [CombatEvent] {
    defer { events.removeAll(keepingCapacity: true) }
    return events
  }

  /// One simulation step: cues, the leader's Disrupt, hostiles, the leader's weapon, then the
  /// companions'. `facing` is the way the leader faces, which her shots leave along; `aiming`
  /// says whether the right stick aims her carbine, and Fire otherwise turns her towards the
  /// assisted target (ADR 0008). `figures` are the members who can be seen, the leader included,
  /// for scripted shots and for hostiles that can aim at anyone. `mayDisrupt` says whether the
  /// leader has Disrupt to use: Miki, in a level that has it. Outside an encounter, only the
  /// leader's weapon acts, and its shots spend no rounds (ADR 0007).
  func step(
    dt: Float, leader: SIMD2<Float>, facing: SIMD2<Float>, aiming: Bool, fireHeld: Bool,
    firePressed: Bool, mayDisrupt: Bool, signaturePressed: Bool,
    figures: [PartyMember: SIMD2<Float>], session: GameSession
  ) -> Outcome {
    var outcome = Outcome()
    shots.removeAll(keepingCapacity: true)
    settleBodies(dt: dt)
    // A fresh Fire press, or aiming with the right stick, draws a holstered weapon.
    if firePressed || aiming, !isDrawn {
      isDrawn = true
      drawRemaining = weapon.drawTime
    }
    drawRemaining -= dt
    cooldown -= dt
    let motion = leaderMotion(at: leader, facing: facing, dt: dt)
    scatter.settle(dt: dt, spread: weapon.spread)
    pose.step(dt: dt, aiming: isDrawn && (aiming || fireHeld))
    guard let encounter else {
      fireLeader(
        leader: leader, aiming: aiming, facing: facing, motion: motion, fireHeld: fireHeld,
        inFight: false, session: session, outcome: &outcome)
      updateTarget(leader: leader, aiming: aiming, facing: facing)
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
        let path = ShotPath(start: from, end: state.position, strike: .body(id))
        shots.append(Shot(path: path, side: .party))
        report(path, firedBy: Self.weaponKind(of: member), byLeader: false)
        rock(member, awayFrom: state.position, at: from)
        session.defeat(id)
        knockDown(id, from: from)
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
      disrupt(id, from: leader, facing: facing, session: session, outcome: &outcome)
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
        fire(
          spec.id, from: state.position, at: aimedAt, victim: victim, range: spec.range,
          shot: shot, isLeader: victim == session.leader)
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
      faceHostile(spec.id, state, facing: aimPosition)
      aimHostile(spec.id, state, at: aimPosition)
    }
    threat = threatNow
    canDisrupt = mayDisrupt && disruptable(from: leader, in: encounter) != nil
    if outcome.retry { return outcome }
    fireLeader(
      leader: leader, aiming: aiming, facing: facing, motion: motion, fireHeld: fireHeld,
      inFight: true, session: session, outcome: &outcome)
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
      hostileAimPoints = [:]
      if let line = encounter.clearedLine { outcome.line = line }
      endFight()
    }
    updateTarget(leader: leader, aiming: aiming, facing: facing)
    return outcome
  }

  /// The leader's shot, while Fire is held and the drawn carbine is ready: along her facing,
  /// with the help near it, or at the assisted target once she faces it; anywhere within her
  /// spread (ADR 0007, ADR 0008). In a fight it spends a round and puts the fight under way;
  /// outside one it spends nothing.
  private func fireLeader(
    leader: SIMD2<Float>, aiming: Bool, facing: SIMD2<Float>,
    motion: (speed: Float, turning: Float),
    fireHeld: Bool, inFight: Bool, session: GameSession, outcome: inout Outcome
  ) {
    guard fireHeld, isDrawn, let aimed = leaderShot(from: leader, aiming: aiming, facing: facing)
    else { return }
    // Without the stick, Fire turns her towards the assisted target, and she fires once she
    // faces it within the help's angle.
    if !aiming, case .body = aimed.strike, simd_distance(aimed.end, leader) > 0.001 {
      let towards = simd_normalize(aimed.end - leader)
      outcome.facing = towards
      guard simd_dot(towards, facing) >= cos(Aim.helpAngle) else { return }
    }
    guard drawRemaining <= 0, cooldown <= 0 else { return }
    if inFight {
      guard session.spendRound() else {
        cooldown = weapon.interval
        events.append(.empty(at: leader))
        if !reportedEmpty {
          reportedEmpty = true
          outcome.line = "Out of ammunition."
        }
        return
      }
      fightUnderWay = true
    }
    cooldown = weapon.interval
    let cone = scatter.angle(spread: weapon.spread, speed: motion.speed, turning: motion.turning)
    let path = Aim.scattered(
      aimed, by: Scatter.deviation(within: cone, using: &random), range: weapon.range,
      hostiles: standingHostiles, blockers: blockers)
    scatter.fired(spread: weapon.spread)
    pose.fired()
    jolts[session.leader, default: BodyJolt()].push(towards: -facing, by: BodyJolt.recoil)
    shots.append(
      Shot(
        path: path, side: .party, muzzle: WeaponPose.muzzle(from: leader, facing: facing)))
    report(path, firedBy: weapon.kind, byLeader: true)
    if inFight, case .body(let id) = path.strike {
      hit(id, from: leader, damage: weapon.damage, session: session, outcome: &outcome)
    }
  }

  /// Where the leader's shot would go now, among the hostiles standing in view, before its
  /// spread: along her facing with the help near it while the stick aims, or else at the
  /// assisted target or straight ahead; nil while it would meet one who is not yet a target.
  private func leaderShot(from leader: SIMD2<Float>, aiming: Bool, facing: SIMD2<Float>)
    -> ShotPath?
  {
    Aim.shot(
      from: leader, aim: aiming ? facing : nil, facing: facing, range: weapon.range,
      hostiles: standingHostiles, blockers: blockers)
  }

  /// The hostiles standing in view, as a shot sees them.
  private var standingHostiles: [Aim.Hostile] {
    hostiles.values.filter { $0.isVisible && !$0.isDown }.map {
      Aim.Hostile(id: $0.spec.id, position: $0.position, isTarget: $0.isTargetable)
    }
  }

  /// What stops the leader's shots now.
  private var blockers: [PartyMotion.Box] { shotBlockers + (gate.map { [$0] } ?? []) }

  /// A salvage task's gate as it stands, shut in the fence or swung open, which stops the
  /// leader's shots as it stops movement (ADR 0006, ADR 0007).
  func setGate(_ footprint: PartyMotion.Box?) {
    gate = footprint
  }

  /// How fast the leader moves and turns in this step, each as a share of her full speed.
  private func leaderMotion(at position: SIMD2<Float>, facing: SIMD2<Float>, dt: Float)
    -> (speed: Float, turning: Float)
  {
    defer { lastLeader = (position, facing) }
    guard let last = lastLeader, dt > 0 else { return (0, 0) }
    let speed = simd_distance(position, last.position) / (PartyBody.speed * dt)
    let turned = acos(min(max(simd_dot(facing, last.facing), -1), 1))
    return (speed, turned / (Movement.leaderTurnRate * dt))
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
      let path = ShotPath(start: from, end: state.position, strike: .body(target))
      shots.append(Shot(path: path, side: .party))
      report(path, firedBy: weapon.kind, byLeader: false)
      rock(member, awayFrom: state.position, at: from)
      companionShots[member, default: 0] += 1
      hit(target, from: from, damage: weapon.damage, session: session, outcome: &outcome)
    }
    self.aims = aims
  }

  /// A shot from `shooter` hits a hostile, counting `damage` hits: it goes down once it has
  /// taken its last, and otherwise rocks and flinches, which delays a wind-up (ADR 0008). A
  /// blast that counts as several hits stops counting once the hostile is down.
  private func hit(
    _ id: String, from shooter: SIMD2<Float>, damage: Int, session: GameSession,
    outcome: inout Outcome
  ) {
    guard let state = hostiles[id] else { return }
    for _ in 0..<damage where session.hit(id, toughness: state.spec.hits) {
      knockDown(id, from: shooter)
      outcome.line = "\(state.spec.name) is down."
      return
    }
    hostiles[id]?.flinch()
    hostileJolts[id, default: BodyJolt()].push(towards: state.position - shooter, by: BodyJolt.hit)
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
  private func disrupt(
    _ id: String, from leader: SIMD2<Float>, facing: SIMD2<Float>, session: GameSession,
    outcome: inout Outcome
  ) {
    guard var state = hostiles[id] else { return }
    state.disrupt()
    hostiles[id] = state
    victims[id] = nil
    hostileAimPoints[id] = nil
    disrupts += 1
    let path = ShotPath(start: leader, end: state.position, strike: .body(id))
    let offset = state.position - leader
    let towards = simd_length(offset) > 0.001 ? simd_normalize(offset) : facing
    pose.fired()
    jolts[session.leader, default: BodyJolt()].push(towards: -towards, by: BodyJolt.recoil)
    hostileJolts[id, default: BodyJolt()].push(towards: towards, by: BodyJolt.hit)
    shots.append(
      Shot(
        path: path, side: .party, muzzle: WeaponPose.muzzle(from: leader, facing: towards)))
    report(path, firedBy: weapon.kind, byLeader: true)
    outcome.facing = towards
    outcome.line = "\(state.spec.name)'s shot is disrupted."
  }

  /// A hostile goes down where it stood, falling away from whoever shot it; its aim goes.
  private func knockDown(_ id: String, from shooter: SIMD2<Float>) {
    guard let state = hostiles[id] else { return }
    hostiles[id]?.knockDown()
    falls[id] = Fall(away: state.position - shooter, yaw: hostileYaws[id] ?? 0)
    hostileJolts[id] = nil
    if let down = hostiles[id] { faceHostile(id, down) }
    hostileAimPoints[id] = nil
    victims[id] = nil
  }

  /// A member of the party rocks back from their own shot at `target`.
  private func rock(_ member: PartyMember, awayFrom target: SIMD2<Float>, at position: SIMD2<Float>)
  {
    jolts[member, default: BodyJolt()].push(towards: position - target, by: BodyJolt.recoil)
  }

  /// What players hear and feel of one shot: the weapon firing, then what it strikes.
  private func report(_ path: ShotPath, firedBy kind: Weapon.Kind, byLeader: Bool) {
    events.append(.fired(kind, at: path.start, byLeader: byLeader))
    switch path.strike {
    case .body: events.append(.struckBody(at: path.end))
    case .scenery: events.append(.struckBlock(at: path.end))
    case .nothing: break
    }
  }

  /// Which weapon each member carries, as the story bible has it: how a scripted shot sounds.
  private static func weaponKind(of member: PartyMember) -> Weapon.Kind {
    switch member {
    case .miki: .carbine
    case .laura: .lightBurst
    case .tom: .closeScatter
    }
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

  /// A hostile's shot at the leader, or at whom it aims: into the cover, which it chips, or
  /// falling short of someone out of range; otherwise just past them when it misses on purpose,
  /// or into them, who rock away from it. The shooter rocks back from its rifle.
  private func fire(
    _ id: String, from start: SIMD2<Float>, at point: SIMD2<Float>, victim: PartyMember,
    range: Float, shot: HostileState.Shot, isLeader: Bool
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
    shots.append(Shot(path: path, side: .hostile))
    report(path, firedBy: .rifle, byLeader: false)
    hostileJolts[id, default: BodyJolt()].push(towards: -direction, by: BodyJolt.recoil)
    if case .body = path.strike {
      jolts[victim, default: BodyJolt()].push(towards: direction, by: BodyJolt.hit)
      if isLeader { events.append(.leaderHit(at: point)) }
    }
  }

  // MARK: - Presentation values

  /// The assisted target before spread, so the stage can put the marker under it.
  private func updateTarget(leader: SIMD2<Float>, aiming: Bool, facing: SIMD2<Float>) {
    let path = isDrawn ? leaderShot(from: leader, aiming: aiming, facing: facing) : nil
    if case .body(let id) = path?.strike {
      target = hostiles[id]?.position
    } else {
      target = nil
    }
  }

  /// Advance the value reactions at the same point in the step as before the split.
  private func settleBodies(dt: Float) {
    for member in Array(jolts.keys) {
      jolts[member]?.settle(dt: dt)
      if jolts[member]?.isSettled == true { jolts[member] = nil }
    }
    var moving = Set(hostileJolts.keys)
    for id in Array(hostileJolts.keys) {
      hostileJolts[id]?.settle(dt: dt)
      if hostileJolts[id]?.isSettled == true { hostileJolts[id] = nil }
    }
    for (id, fall) in falls where !fall.isFinished {
      falls[id]?.advance(dt: dt)
      moving.insert(id)
    }
    for id in moving { capturePose(id) }
  }

  /// A standing hostile faces its target; a downed hostile retains its recorded fall.
  private func faceHostile(_ id: String, _ state: HostileState, facing point: SIMD2<Float>? = nil) {
    if state.isDown {
      if falls[id] == nil {
        falls[id] = Fall(away: .zero, yaw: hostileYaws[id] ?? 0, finished: true)
      }
    } else {
      let offset = (point ?? state.position + lookout) - state.position
      hostileYaws[id] = Movement.yaw(towards: offset)
    }
    capturePose(id)
  }

  /// Capture at the same original pose-update points, rather than making a newly received
  /// jolt visible one fixed step earlier when all rendering is applied at the end of the step.
  private func capturePose(_ id: String) {
    guard let state = hostiles[id] else { return }
    if state.isDown, let fall = falls[id] {
      let pose = fall.pose
      hostilePoses[id] = FigurePose(orientation: pose.orientation, position: pose.position)
      return
    }
    let turn = simd_quatf(angle: hostileYaws[id] ?? 0, axis: [0, 1, 0])
    let jolt = (hostileJolts[id] ?? BodyJolt()).pose(height: PartyBody.height)
    hostilePoses[id] = FigurePose(orientation: jolt.tilt * turn, position: jolt.offset)
  }

  /// A warning stays aimed at the same point the hostile used in this step.
  private func aimHostile(_ id: String, _ state: HostileState, at point: SIMD2<Float>) {
    if case .aiming = state.phase {
      hostileAimPoints[id] = point
    } else {
      hostileAimPoints[id] = nil
    }
  }
}
