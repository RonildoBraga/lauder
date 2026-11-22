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
    var scale: Float = 1
  }

  /// The active character's cover, as geometry, exposure and presentation agree on it.
  struct CoverState: Sendable {
    let boxID: String
    let isLow: Bool
    let position: SIMD2<Float>
    let normal: SIMD2<Float>
    let offset: SIMD2<Float>
    let firing: Bool
    let exposed: Bool
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
  var isDrawn: Bool { handling[weaponLeader]?.isDrawn == true }
  var leaderWeapon: Weapon { Weapon.forMember(weaponLeader) }
  var drawnWeapons: Set<PartyMember> { Set(handling.filter { $0.value.isDrawn }.keys) }

  struct WeaponStatus: Sendable {
    let kind: Weapon.Kind
    let loaded: Int
    let reloadRemaining: Float
    let isDrawn: Bool
  }

  func status(for member: PartyMember) -> WeaponStatus {
    let weapon = Weapon.forMember(member)
    let state = handling[member] ?? WeaponHandling(weapon: weapon)
    return WeaponStatus(
      kind: weapon.kind, loaded: state.magazineRemaining,
      reloadRemaining: state.reloadRemaining, isDrawn: state.isDrawn)
  }
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
  private(set) var weaponPoses: [PartyMember: WeaponPose] = [:]
  var pose: WeaponPose { weaponPoses[weaponLeader] ?? WeaponPose(kind: leaderWeapon.kind) }
  /// What players hear and feel since the world last took them (ADR 0008).
  private(set) var events: [CombatEvent] = []
  private(set) var coverStates: [PartyMember: CoverState] = [:]
  var coverState: CoverState? { coverStates[weaponLeader] }
  private(set) var companionTargetIDs: [PartyMember: String] = [:]
  private(set) var enemyCoverStates: [String: CoverState] = [:]
  private(set) var grenades: [Grenade] = []
  private(set) var explosions: [SIMD2<Float>] = []
  private(set) var grenadesThrown = 0
  private(set) var grenadesExploded = 0
  private(set) var movedEnemies: Set<String> = []
  private var nextGrenadeID = 0
  private var tactics: EnemyTactics
  private var enemyStances: [String: CoverStance] = [:]

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
        position: hostileFiringPoint(
          spec.id, toward: state.position + (facings[spec.id] ?? lookout)),
        range: spec.range, aimingAt: victims[spec.id],
        isTarget: state.isTargetable, facing: facings[spec.id] ?? lookout)
    }
  }

  private var weaponLeader: PartyMember
  private let startingLeader: PartyMember
  private var weapon: Weapon { leaderWeapon }
  private var handling: [PartyMember: WeaponHandling] = [:]
  private let specs: [String: Level.Hostile]
  private let obstacles: [PartyMotion.Box]
  /// What stops the leader's shots: the level's blocks that rise above shoulder height, and a
  /// salvage task's gate as it stands (ADR 0007).
  private let shotBlockers: [PartyMotion.Box]
  private var gate: PartyMotion.Box?
  private let rules: Level.Combat
  private let coverRules: LeaderCover?
  private var stances: [PartyMember: CoverStance] = [:]
  private var companionReady: Set<PartyMember> = []
  /// Which way a hostile waiting in view faces: back along the level's starting heading,
  /// towards where the party comes from.
  private let lookout: SIMD2<Float>
  private var encounter: Level.Encounter?
  /// Whom each hostile that aims at anyone began its current wind-up at.
  private var victims: [String: PartyMember] = [:]
  /// Which way each hostile in the fight faces: towards whom it aims at, as a unit vector.
  private var facings: [String: SIMD2<Float>] = [:]
  private var director = StoryDirector()
  /// The target marker and the hostiles' warnings as last shown by the rules.
  private(set) var target: SIMD2<Float>?
  private(set) var hostileAimPoints: [String: SIMD2<Float>] = [:]
  private(set) var hostileAimOrigins: [String: SIMD2<Float>] = [:]
  private(set) var hostilePoses: [String: FigurePose] = [:]
  /// Visual shots from this step only, in firing order; the stage reads them immediately.
  private(set) var shots: [Shot] = []
  private var reportedEmpty = false
  /// Each member keeps spread and its random sequence through changes between roles.
  private var scatters: [PartyMember: Scatter] = [:]
  private var random: [PartyMember: SeededRandom] = [:]
  private var lastMotion: [PartyMember: (position: SIMD2<Float>, facing: SIMD2<Float>)] = [:]
  /// Each standing hostile's turn, how it rocks after firing or being hit, and the fall of each
  /// one downed (ADR 0008).
  private var hostileYaws: [String: Float] = [:]
  private(set) var hostileJolts: [String: BodyJolt] = [:]
  private(set) var falls: [String: Fall] = [:]

  init(level: Level, grid: NavigationGrid? = nil) {
    tactics = EnemyTactics(level: level, grid: grid)
    startingLeader = level.party[0]
    weaponLeader = level.party[0]
    obstacles = level.obstacles
    shotBlockers = Aim.blockers(level.boxes, above: Self.aimHeight)
    rules = level.combat
    coverRules =
      level.combat.leaderCover
      ? LeaderCover(boxes: level.boxes, ground: level.ground.footprint) : nil
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
    grenadesThrown = 0
    grenadesExploded = 0
    movedEnemies = []
    nextGrenadeID = 0
    disrupts = 0
    random = Dictionary(
      uniqueKeysWithValues: PartyMember.allCases.enumerated().map {
        ($0.element, SeededRandom(seed: Self.seed + UInt64($0.offset)))
      })
    weaponLeader = startingLeader
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
    clearCover()
    tactics.reset()
    enemyStances = [:]
    enemyCoverStates = [:]
    grenades = []
    explosions = []
    encounter = nil
    director.stop()
    handling = Dictionary(
      uniqueKeysWithValues: PartyMember.allCases.map {
        ($0, WeaponHandling(weapon: .forMember($0)))
      })
    threat = nil
    reportedEmpty = false
    weaponPoses = Dictionary(
      uniqueKeysWithValues: PartyMember.allCases.map {
        ($0, WeaponPose(kind: Weapon.forMember($0).kind))
      })
    scatters = [:]
    lastMotion = [:]
    endFight()
    hostileAimPoints = [:]
    hostileAimOrigins = [:]
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
    for member in handling.keys { handling[member]?.releaseTrigger() }
    lastMotion = lastMotion.filter { $0.key == weaponLeader }
    aims = [:]
    companionReady = []
    companionTargetIDs = [:]
    stances = stances.filter { $0.key == weaponLeader }
    coverStates = coverStates.filter { $0.key == weaponLeader }
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
    explosions.removeAll(keepingCapacity: true)
    settleBodies(dt: dt)
    if weaponLeader != session.leader {
      clearCover()
      handling[weaponLeader]?.releaseTrigger()
      handling[session.leader]?.releaseTrigger()
      lastMotion[session.leader] = nil
      weaponLeader = session.leader
      reportedEmpty = false
    }
    if firePressed || aiming { handling[weaponLeader]?.draw() }
    if !fireHeld { handling[weaponLeader]?.releaseTrigger() }
    for member in PartyMember.allCases {
      handling[member]?.advance(dt: dt)
      scatters[member, default: Scatter()].settle(dt: dt, spread: Weapon.forMember(member).spread)
      weaponPoses[member]?.step(
        dt: dt,
        aiming: member == weaponLeader ? isDrawn && (aiming || fireHeld) : aims[member] != nil)
    }
    let motion = shooterMotion(of: weaponLeader, at: leader, facing: facing, dt: dt)
    guard let encounter else {
      prepareCover(
        at: leader, facing: facing, dt: dt, fireHeld: fireHeld, aiming: aiming,
        inFight: false, session: session)
      fireLeader(
        leader: leader, aiming: aiming, facing: facing, motion: motion, fireHeld: fireHeld,
        inFight: false, session: session, outcome: &outcome)
      updateTarget(leader: leader, aiming: aiming, facing: facing)
      showCover(at: leader, facing: facing)
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
        handling[member]?.draw()
        weaponPoses[member]?.fired()
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
    let tactical = tactics.step(hostiles: hostiles, party: party, dt: dt)
    for (id, point) in tactical.positions { hostiles[id]?.reposition(to: point) }
    movedEnemies.formUnion(tactical.moving)
    prepareEnemies(dt: dt, party: party, leader: leader)
    prepareCover(
      at: leader, facing: facing, dt: dt, fireHeld: fireHeld, aiming: aiming,
      inFight: true, session: session)
    prepareCompanions(
      dt: dt, party: party, leader: leader, facing: facing, aiming: aiming, session: session)
    advanceGrenades(dt: dt, party: party, session: session, outcome: &outcome)
    if outcome.retry { return outcome }
    // Disrupt comes before the hostiles move on, so a press on the step that a wind-up would
    // end still answers it.
    let signaturePoint = firingPoint(from: leader, facing: facing)
    if mayDisrupt, signaturePressed, let id = disruptable(from: signaturePoint, in: encounter) {
      exposeCover(at: leader, facing: facing)
      disrupt(id, from: signaturePoint, facing: facing, session: session, outcome: &outcome)
    }
    var threatNow: String?
    for spec in encounter.hostiles {
      guard var state = hostiles[spec.id] else { continue }
      // The leader, or whoever a hostile that aims at anyone began its wind-up at.
      let victim = spec.targetsAnyone ? victims[spec.id] ?? session.leader : session.leader
      let aimedAt = incomingPoint(for: victim, at: party[victim] ?? leader)
      let incoming = incomingBlockers(for: victim)
      let origin = hostileFiringPoint(spec.id, toward: aimedAt)
      let inRange = simd_distance(origin, aimedAt) <= spec.range
      let canHit =
        inRange
        && LineOfSight.isClear(
          from: origin, to: aimedAt,
          obstacles: spec.attack == .throwGrenade ? shotBlockers : incoming)
      if let shot = state.step(
        dt: dt, canHit: canHit, toward: leader, canAttack: !tactical.moving.contains(spec.id))
      {
        if shot == .grenade, !grenades.contains(where: { $0.owner == spec.id }) {
          nextGrenadeID += 1
          grenades.append(Grenade(id: nextGrenadeID, owner: spec.id, from: origin, at: aimedAt))
          grenadesThrown += 1
          outcome.line = "Grenade — leave the marked ground."
        } else if spec.attack != .throwGrenade {
          if let coverRules {
            enemyStances[spec.id]?.fired(facing: aimedAt - state.position, using: coverRules)
            showEnemyCover(spec.id, party: party)
          }
          fire(
            spec.id, from: origin, at: aimedAt, victim: victim, range: spec.range,
            shot: shot, isLeader: victim == session.leader, blockers: incoming)
          if shot == .miss, let line = spec.missLine { outcome.line = line }
          if shot == .hit, session.takeHit(victim) { outcome.retry = true }
        }
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
      let aimPosition = incomingPoint(for: aim, at: party[aim] ?? leader)
      switch state.phase {
      case .aiming where spec.attack == .throwGrenade:
        threatNow = "\(spec.name) is preparing a grenade."
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
    canDisrupt = mayDisrupt && disruptable(from: signaturePoint, in: encounter) != nil
    for member in session.party { showCover(for: member) }
    for id in enemyStances.keys { showEnemyCover(id, party: party) }
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
      for member in session.companions {
        handling[member]?.releaseTrigger()
        lastMotion[member] = nil
      }
    }
    // A fight ends once everyone in it is down; a scene also plays its timeline to the end.
    if !director.isPlaying, grenades.isEmpty,
      encounter.hostiles.allSatisfy({ session.defeated.contains($0.id) })
    {
      session.endEncounter()
      self.encounter = nil
      director.stop()
      threat = nil
      hostileAimPoints = [:]
      if let line = encounter.clearedLine { outcome.line = line }
      endFight()
    }
    updateTarget(leader: leader, aiming: aiming, facing: facing)
    showCover(at: leader, facing: facing)
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
    let origin = firingPoint(from: leader, facing: facing)
    guard fireHeld, isDrawn, let aimed = leaderShot(from: origin, aiming: aiming, facing: facing)
    else { return }
    // Without the stick, Fire turns her towards the assisted target, and she fires once she
    // faces it within the help's angle.
    if !aiming, case .body = aimed.strike, simd_distance(aimed.end, origin) > 0.001 {
      let towards = simd_normalize(aimed.end - origin)
      outcome.facing = towards
    }
    guard readyToFire(aimed, from: origin, facing: facing, aiming: aiming) else { return }
    if inFight {
      guard session.spendRound() else {
        handling[weaponLeader]?.emptyClick()
        events.append(.empty(at: leader))
        if !reportedEmpty {
          reportedEmpty = true
          outcome.line = "Out of ammunition."
        }
        return
      }
      fightUnderWay = true
    }
    handling[weaponLeader]?.fired()
    exposeCover(at: leader, facing: facing)
    let path = scattered(
      aimed, by: weaponLeader, weapon: weapon, motion: motion, blockers: blockers)
    weaponPoses[weaponLeader]?.fired()
    jolts[session.leader, default: BodyJolt()].push(towards: -facing, by: BodyJolt.recoil)
    shots.append(
      Shot(
        path: path, side: .party,
        muzzle: WeaponPose.muzzle(from: origin, facing: facing, kind: weapon.kind)))
    report(path, firedBy: weapon.kind, byLeader: true)
    if inFight, case .body(let id) = path.strike {
      hit(id, from: origin, damage: weapon.damage, session: session, outcome: &outcome)
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
      Aim.Hostile(
        id: $0.spec.id, position: hostilePoint($0.spec.id),
        isTarget: $0.isTargetable, blockers: hostileBlockers($0.spec.id))
    }
  }

  /// What stops the leader's shots now.
  private var blockers: [PartyMotion.Box] { shotBlockers + (gate.map { [$0] } ?? []) }

  // MARK: - Shared party cover

  /// Switching, fallback and Restart discard temporary exposure for every member.
  func clearCover() {
    stances = [:]
    coverStates = [:]
    companionReady = []
    companionTargetIDs = [:]
  }

  private func firingPoint(from point: SIMD2<Float>, facing: SIMD2<Float>) -> SIMD2<Float> {
    guard let coverRules, let stance = stances[weaponLeader] else { return point }
    return stance.firingPoint(facing: facing, using: coverRules)
  }

  private func readyToFire(
    _ shot: ShotPath, from origin: SIMD2<Float>, facing: SIMD2<Float>, aiming: Bool
  ) -> Bool {
    guard handling[weaponLeader]?.isReady == true else { return false }
    if !aiming, case .body = shot.strike, simd_distance(shot.end, origin) > 0.001 {
      return simd_dot(simd_normalize(shot.end - origin), facing) >= cos(Aim.helpAngle)
    }
    return true
  }

  /// Predict exposure before incoming shots, including a wind-up ending on this exact step.
  private func prepareCover(
    at point: SIMD2<Float>, facing: SIMD2<Float>, dt: Float, fireHeld: Bool, aiming: Bool,
    inFight: Bool, session: GameSession
  ) {
    guard let coverRules else { return }
    stances[weaponLeader, default: CoverStance()].advance(
      at: point, facing: facing, dt: dt, using: coverRules)
    let origin = firingPoint(from: point, facing: facing)
    if fireHeld, isDrawn, !inFight || session.ammo > 0,
      let shot = leaderShot(from: origin, aiming: aiming, facing: facing),
      readyToFire(shot, from: origin, facing: facing, aiming: aiming)
    {
      exposeCover(at: point, facing: facing)
    } else {
      showCover(at: point, facing: facing)
    }
  }

  private func exposeCover(at point: SIMD2<Float>, facing: SIMD2<Float>) {
    guard let coverRules else { return }
    stances[weaponLeader]?.fired(facing: facing, using: coverRules)
    showCover(at: point, facing: facing)
  }

  private func showCover(at point: SIMD2<Float>, facing: SIMD2<Float>) {
    showCover(for: weaponLeader)
  }

  private func showCover(for member: PartyMember) {
    guard let coverRules, let stance = stances[member], let shelter = stance.shelter else {
      coverStates[member] = nil
      return
    }
    let origin = stance.incomingPoint(using: coverRules)
    let incoming = stance.incomingBlockers(using: coverRules)
    let exposed = threats.contains {
      simd_distance($0.position, origin) <= $0.range
        && LineOfSight.isClear(from: $0.position, to: origin, obstacles: incoming)
    }
    coverStates[member] = CoverState(
      boxID: shelter.boxID, isLow: shelter.isLow, position: stance.position, normal: shelter.normal,
      offset: origin - stance.position, firing: stance.firing, exposed: exposed)
  }

  private func incomingPoint(for member: PartyMember, at point: SIMD2<Float>) -> SIMD2<Float> {
    guard let coverRules else { return point }
    return stances[member]?.incomingPoint(using: coverRules) ?? point
  }

  private func incomingBlockers(for member: PartyMember) -> [PartyMotion.Box] {
    guard let coverRules else { return obstacles }
    return stances[member]?.incomingBlockers(using: coverRules)
      ?? coverRules.incomingBlockers(in: nil, exposed: false)
  }

  private func prepareCompanions(
    dt: Float, party: [PartyMember: SIMD2<Float>], leader: SIMD2<Float>,
    facing: SIMD2<Float>, aiming: Bool, session: GameSession
  ) {
    companionReady = []
    companionTargetIDs = [:]
    let preferred: String?
    if isDrawn,
      case .body(let id) = leaderShot(
        from: firingPoint(from: leader, facing: facing), aiming: aiming, facing: facing)?.strike
    {
      preferred = id
    } else {
      preferred = nil
    }
    let mayFire = fightUnderWay && !holdsParty && !session.regrouping
    for member in session.companions {
      guard let point = party[member] else { continue }
      let towards = preferred.flatMap { hostiles[$0]?.position } ?? aims[member] ?? point - lookout
      let offset = towards - point
      let direction = simd_length_squared(offset) > 0.000001 ? simd_normalize(offset) : -lookout
      if let coverRules {
        stances[member, default: CoverStance()].advance(
          at: point, facing: direction, dt: dt, using: coverRules)
      }
      guard rules.companionWeapons[member] != nil else {
        showCover(for: member)
        continue
      }
      if mayFire { handling[member]?.draw() }
      if let target = companionTarget(for: member, at: point, preferred: preferred) {
        companionTargetIDs[member] = target.id
        var ducking = false
        if let coverRules, let shelter = stances[member]?.shelter {
          let protection = coverRules.incomingBlockers(in: shelter, exposed: false)
          ducking = threats.contains {
            $0.aimingAt == member
              && !LineOfSight.isClear(from: $0.position, to: point, obstacles: protection)
          }
        }
        if mayFire, !ducking, handling[member]?.isReady == true {
          companionReady.insert(member)
          if let coverRules {
            stances[member]?.fired(facing: target.direction, using: coverRules)
          }
        } else if !mayFire || ducking {
          handling[member]?.releaseTrigger()
        }
      } else {
        handling[member]?.releaseTrigger()
        lastMotion[member] = nil
      }
      showCover(for: member)
    }
  }

  private func companionTarget(
    for member: PartyMember, at point: SIMD2<Float>, preferred: String?
  ) -> (id: String, origin: SIMD2<Float>, direction: SIMD2<Float>)? {
    guard let weapon = rules.companionWeapons[member] else { return nil }
    let outgoing = coverRules == nil ? obstacles : shotBlockers
    func candidate(_ id: String) -> (id: String, origin: SIMD2<Float>, direction: SIMD2<Float>)? {
      guard let state = hostiles[id], state.isTargetable else { return nil }
      let destination = hostilePoint(id)
      let offset = destination - point
      let direction = simd_length_squared(offset) > 0.000001 ? simd_normalize(offset) : -lookout
      let origin =
        coverRules.flatMap { rules in
          stances[member]?.firingPoint(facing: direction, using: rules)
        } ?? point
      guard simd_distance(origin, destination) <= weapon.range,
        LineOfSight.isClear(
          from: origin, to: destination, obstacles: outgoing + hostileBlockers(id))
      else { return nil }
      return (id, origin, direction)
    }
    if let preferred, let chosen = candidate(preferred) { return chosen }
    return hostiles.keys.sorted().compactMap(candidate).min {
      simd_distance_squared(hostiles[$0.id]!.position, point)
        < simd_distance_squared(hostiles[$1.id]!.position, point)
    }
  }

  // MARK: - Tactical enemies and warned blasts

  private func prepareEnemies(
    dt: Float, party: [PartyMember: SIMD2<Float>], leader: SIMD2<Float>
  ) {
    guard let coverRules else { return }
    for id in hostiles.keys.sorted() {
      guard let state = hostiles[id], state.spec.behavior != .stationary,
        state.isVisible, !state.isDown
      else { continue }
      let target = victims[id].flatMap { party[$0] } ?? leader
      let direction = target - state.position
      enemyStances[id, default: CoverStance()].advance(
        at: state.position, facing: direction, dt: dt, using: coverRules)
      showEnemyCover(id, party: party)
    }
  }

  private func showEnemyCover(_ id: String, party: [PartyMember: SIMD2<Float>]) {
    guard let coverRules, let stance = enemyStances[id], let shelter = stance.shelter else {
      enemyCoverStates[id] = nil
      return
    }
    let origin = stance.incomingPoint(using: coverRules)
    let incoming = stance.incomingBlockers(using: coverRules)
    let exposed = party.contains { member, point in
      var attacker = stances[member] ?? CoverStance()
      attacker.advance(at: point, facing: origin - point, dt: 0, using: coverRules)
      let source = attacker.firingPoint(facing: origin - point, using: coverRules)
      return simd_distance(source, origin) <= Weapon.forMember(member).range
        && LineOfSight.isClear(from: source, to: origin, obstacles: incoming)
    }
    enemyCoverStates[id] = CoverState(
      boxID: shelter.boxID, isLow: shelter.isLow, position: stance.position,
      normal: shelter.normal, offset: origin - stance.position,
      firing: stance.firing, exposed: exposed)
  }

  private func hostilePoint(_ id: String) -> SIMD2<Float> {
    guard let state = hostiles[id] else { return .zero }
    guard let coverRules, let stance = enemyStances[id] else { return state.position }
    return stance.incomingPoint(using: coverRules)
  }

  private func hostileFiringPoint(_ id: String, toward point: SIMD2<Float>) -> SIMD2<Float> {
    guard let state = hostiles[id] else { return .zero }
    guard let coverRules, let stance = enemyStances[id] else { return state.position }
    return stance.firingPoint(facing: point - state.position, using: coverRules)
  }

  private func hostileBlockers(_ id: String) -> [PartyMotion.Box] {
    guard let coverRules, let stance = enemyStances[id] else { return [] }
    return stance.incomingBlockers(using: coverRules)
  }

  private func advanceGrenades(
    dt: Float, party: [PartyMember: SIMD2<Float>], session: GameSession, outcome: inout Outcome
  ) {
    for index in grenades.indices {
      guard grenades[index].advance(dt: dt) else { continue }
      let grenade = grenades[index]
      explosions.append(grenade.position)
      grenadesExploded += 1
      events.append(.struckBlock(at: grenade.position))
      for member in session.party {
        guard let point = party[member], grenade.contains(point),
          LineOfSight.isClear(from: grenade.position, to: point, obstacles: shotBlockers)
        else { continue }
        jolts[member, default: BodyJolt()].push(towards: point - grenade.position, by: BodyJolt.hit)
        events.append(.struckBody(at: point))
        if member == session.leader { events.append(.leaderHit(at: point)) }
        if session.takeHit(member) { outcome.retry = true }
      }
    }
    grenades.removeAll { $0.remaining == 0 }
  }

  /// A salvage task's gate as it stands, shut in the fence or swung open, which stops the
  /// leader's shots as it stops movement (ADR 0006, ADR 0007).
  func setGate(_ footprint: PartyMotion.Box?) {
    gate = footprint
  }

  /// How fast the leader moves and turns in this step, each as a share of her full speed.
  private func shooterMotion(
    of member: PartyMember, at position: SIMD2<Float>, facing: SIMD2<Float>, dt: Float
  )
    -> (speed: Float, turning: Float)
  {
    defer { lastMotion[member] = (position, facing) }
    guard let last = lastMotion[member], dt > 0 else { return (0, 0) }
    let speed = simd_distance(position, last.position) / (PartyBody.speed * dt)
    let turned = acos(min(max(simd_dot(facing, last.facing), -1), 1))
    return (speed, turned / (Movement.leaderTurnRate * dt))
  }

  private func scattered(
    _ path: ShotPath, by member: PartyMember, weapon: Weapon,
    motion: (speed: Float, turning: Float), blockers: [PartyMotion.Box]
  ) -> ShotPath {
    var scatter = scatters[member] ?? Scatter()
    var generator = random[member] ?? SeededRandom(seed: Self.seed)
    let cone = scatter.angle(spread: weapon.spread, speed: motion.speed, turning: motion.turning)
    let result = Aim.scattered(
      path, by: Scatter.deviation(within: cone, using: &generator), range: weapon.range,
      hostiles: standingHostiles, blockers: blockers)
    scatter.fired(spread: weapon.spread)
    scatters[member] = scatter
    random[member] = generator
    return result
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
      guard let weapon = rules.companionWeapons[member], let from = party[member],
        let selected = companionTarget(
          for: member, at: from, preferred: companionTargetIDs[member]),
        let state = hostiles[selected.id]
      else { continue }
      let destination = hostilePoint(selected.id)
      aims[member] = destination
      let motion = shooterMotion(of: member, at: from, facing: selected.direction, dt: dt)
      guard companionReady.contains(member), handling[member]?.isReady == true else { continue }
      handling[member]?.fired()
      let aimed = ShotPath(start: selected.origin, end: destination, strike: .body(selected.id))
      let path = scattered(
        aimed, by: member, weapon: weapon, motion: motion,
        blockers: coverRules == nil ? obstacles : shotBlockers)
      shots.append(
        Shot(
          path: path, side: .party,
          muzzle: WeaponPose.muzzle(
            from: selected.origin, facing: selected.direction, kind: weapon.kind)))
      report(path, firedBy: weapon.kind, byLeader: false)
      rock(member, awayFrom: state.position, at: from)
      weaponPoses[member]?.fired()
      companionShots[member, default: 0] += 1
      if case .body(let hitID) = path.strike {
        hit(
          hitID, from: selected.origin, damage: weapon.damage, session: session, outcome: &outcome)
      }
      showCover(for: member)
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
    party.compactMap { member, point -> (member: PartyMember, distance: Float)? in
      let destination = incomingPoint(for: member, at: point)
      let origin = hostileFiringPoint(state.spec.id, toward: destination)
      let distance = simd_distance(origin, destination)
      let incoming =
        state.spec.attack == .throwGrenade ? shotBlockers : incomingBlockers(for: member)
      guard distance <= state.spec.range,
        LineOfSight.isClear(from: origin, to: destination, obstacles: incoming)
      else { return nil }
      return (member, distance)
    }.min { $0.distance < $1.distance }?.member
  }

  /// A signature must reach the same exposed body as an ordinary shot.
  private func disruptable(from leader: SIMD2<Float>, in encounter: Level.Encounter) -> String? {
    let visible = encounter.hostiles.compactMap { hostiles[$0.id] }.filter {
      LineOfSight.isClear(
        from: leader, to: hostilePoint($0.spec.id),
        obstacles: (coverRules == nil ? obstacles : blockers) + hostileBlockers($0.spec.id))
    }
    return Disrupt.target(
      from: leader, hostiles: visible, point: { hostilePoint($0.spec.id) },
      isClear: { _, _ in true })
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
    let destination = hostilePoint(id)
    let path = ShotPath(start: leader, end: destination, strike: .body(id))
    let offset = destination - leader
    let towards = simd_length(offset) > 0.001 ? simd_normalize(offset) : facing
    handling[session.leader]?.draw()
    weaponPoses[session.leader]?.fired()
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
    hostileAimOrigins[id] = nil
    enemyStances[id] = nil
    enemyCoverStates[id] = nil
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
    range: Float, shot: HostileState.Shot, isLeader: Bool, blockers: [PartyMotion.Box]
  ) {
    let distance = simd_distance(start, point)
    guard distance > 0.001 else { return }
    let block = LineOfSight.firstBlock(from: start, to: point, obstacles: blockers) ?? 1
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
    let path =
      isDrawn
      ? leaderShot(from: firingPoint(from: leader, facing: facing), aiming: aiming, facing: facing)
      : nil
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
    let cover = enemyCoverStates[id]
    let scale: Float = cover != nil && cover?.firing == false ? 0.68 : 1
    let offset = cover?.offset ?? .zero
    let jolt = (hostileJolts[id] ?? BodyJolt()).pose(height: PartyBody.height * scale)
    hostilePoses[id] = FigurePose(
      orientation: jolt.tilt * turn,
      position: jolt.offset + [offset.x, -PartyBody.height * (1 - scale) / 2, offset.y],
      scale: scale)
  }

  /// A warning stays aimed at the same point the hostile used in this step.
  private func aimHostile(_ id: String, _ state: HostileState, at point: SIMD2<Float>) {
    if case .aiming = state.phase {
      hostileAimPoints[id] = point
      hostileAimOrigins[id] = hostileFiringPoint(id, toward: point)
    } else {
      hostileAimPoints[id] = nil
      hostileAimOrigins[id] = nil
    }
  }
}
