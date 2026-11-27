import simd

/// The bridge's fights and scripted cues as values. The fixed step advances hostiles,
/// native weapons, spread and reactions; the world presents the resulting shots and poses.
@MainActor
final class EncounterSimulation {
  struct Shot {
    enum Side { case party, hostile }
    let path: ShotPath
    let side: Side
    var muzzle: SIMD2<Float>? = nil
    var trace: Ballistics.Trace? = nil
    var gun: Int? = nil
    var armoured = false
  }

  struct FigurePose {
    let orientation: simd_quatf
    let position: SIMD3<Float>
  }

  struct Outcome {
    var line: String?
    var facing: SIMD2<Float>?
    var retry = false
    var appeared: [PartyMember] = []
    var stood: [PartyMember] = []
    var shooter: (member: PartyMember, facing: SIMD2<Float>)?
    var face: (PartyMember, PartyMember)?
  }

  static let aimHeight: Float = 1.25
  static let cameraLeanShare: Float = 0.4
  static let cameraLeanLimit: Float = 3
  static let focusShare: Float = 0.8
  static let focusLimit: Float = 7
  static let seed: UInt64 = 8

  private(set) var hostiles: [String: HostileState] = [:]
  private(set) var guardStrategies: [String: GuardStrategy] = [:]

  func weakpoints(for id: String) -> [GuardWeakpoint] {
    guard let strategy = guardStrategies[id], let state = hostiles[id],
      state.isVisible, !state.isDown, let robot = state.robot, !robot.isCleared
    else { return [] }
    return GuardWeakpoint.make(id: id, robot: robot, strategy: strategy)
  }

  /// Persistent, short guidance alongside the current enemy warning. Switching never erases
  /// a component already broken; only Retry/Restart restores the machine.
  var guardHint: String? {
    guard let id = encounter?.hostiles.first(where: { $0.strategicGuard })?.id,
      let strategy = guardStrategies[id], let robot = hostiles[id]?.robot,
      !robot.isDown, !robot.isCleared
    else { return nil }
    switch strategy.phase {
    case .sensor:
      return robot.phase == .recovering
        ? "1/3 · Miki: long rifle → front sensor. Open!"
        : "1/3 · Miki: long rifle → front sensor after a volley."
    case .coupling:
      return "2/3 · Sensor disabled. Laura: sword → either side coupling."
    case .reactor:
      let left = GuardStrategy.reactorDamageRequired - strategy.reactorDamage
      return strategy.windowRemaining > 0
        ? String(
          format: "3/3 · Tom: minigun → side core · %d rounds · %.1f s", left,
          strategy.windowRemaining)
        : "3/3 · Coupling breached. Tom: side core opens after each volley."
    case .complete:
      return nil
    }
  }
  var isDrawn: Bool { handling[slot(of: weaponLeader)]?.isDrawn == true }
  var leaderWeapon: Weapon { weapon(of: weaponLeader) }
  /// Whoever has the weapon in their hand drawn.
  var drawnWeapons: Set<PartyMember> {
    Set(PartyMember.allCases.filter { handling[slot(of: $0)]?.isDrawn == true })
  }

  /// One of a member's two weapons (ADR 0021): which member, and which of `Weapon.pair`.
  struct WeaponSlot: Hashable, Sendable {
    let member: PartyMember
    let index: Int
  }

  /// The weapon in a member's hand: the first of their pair until they switch.
  func weapon(of member: PartyMember) -> Weapon {
    let pair = Weapon.pair(for: member)
    return pair[(selected[member] ?? 0) % pair.count]
  }

  /// The member's other weapon, which the switch brings into their hand.
  func otherWeapon(of member: PartyMember) -> Weapon {
    let pair = Weapon.pair(for: member)
    return pair[((selected[member] ?? 0) + 1) % pair.count]
  }

  private func slot(of member: PartyMember) -> WeaponSlot {
    WeaponSlot(member: member, index: (selected[member] ?? 0) % Weapon.pair(for: member).count)
  }

  struct WeaponStatus: Sendable {
    let kind: Weapon.Kind
    let loaded: Int
    let reloadRemaining: Float
    let isDrawn: Bool
    /// Seconds of Tom's dome left, for the shield; nil for every other weapon.
    var shieldRemaining: Float?
  }

  func status(for member: PartyMember) -> WeaponStatus {
    let weapon = weapon(of: member)
    let state = handling[slot(of: member)] ?? WeaponHandling(weapon: weapon)
    return WeaponStatus(
      kind: weapon.kind, loaded: state.magazineRemaining,
      reloadRemaining: state.reloadRemaining, isDrawn: state.isDrawn,
      shieldRemaining: weapon.kind == .shieldDome ? shield.remaining : nil)
  }

  /// How fast the leader walks with what is in hand now: slower behind a running minigun or
  /// the raised dome (ADR 0021).
  var leaderWalking: Float {
    let weapon = leaderWeapon
    switch weapon.kind {
    case .shieldDome: return shield.isUp ? weapon.walking : 1
    case .minigun: return spin > 0 ? weapon.walking : 1
    default: return 1
    }
  }

  /// Whether Tom leads with his dome raised.
  var shieldIsUp: Bool { shield.isUp && weaponLeader == .tom }

  private(set) var threat: String?
  private(set) var jolts: [PartyMember: BodyJolt] = [:]
  private(set) var weaponPoses: [PartyMember: WeaponPose] = [:]
  var pose: WeaponPose { weaponPoses[weaponLeader] ?? WeaponPose(kind: leaderWeapon.kind) }
  private(set) var events: [CombatEvent] = []
  private var enemyHandling: [String: HostileHandling] = [:]
  private var enemyRandom: [String: SeededRandom] = [:]
  private(set) var hostileWeaponPoses: [String: WeaponPose] = [:]
  private let ballistics: Ballistics
  var holdsParty: Bool { encounter?.holdsParty == true }
  private var weaponLeader: PartyMember
  private let startingLeader: PartyMember
  private var weapon: Weapon { leaderWeapon }
  /// Which of each member's two weapons is in hand, as an index into `Weapon.pair`.
  private(set) var selected: [PartyMember: Int] = [:]
  /// Each weapon's timing, kept while the other is in hand (ADR 0021).
  private var handling: [WeaponSlot: WeaponHandling] = [:]
  /// How long Fire has been held with a rotary gun in hand, for its spin-up.
  private var spin: Float = 0
  /// Tom's dome, which runs down while held and recharges otherwise.
  private(set) var shield = ShieldDome()
  /// The leader's facing in the current step, for which shots Laura's sword turns.
  private var leaderFacing = SIMD2<Float>(0, -1)
  private var aimOrigin = SIMD2<Float>.zero
  private let specs: [String: Level.Hostile]
  private let blockers: [PartyMotion.Box]
  private let movementObstacles: [PartyMotion.Box]
  private let lookout: SIMD2<Float>
  private var encounter: Level.Encounter?
  private var director = StoryDirector()
  private(set) var target: SIMD2<Float>?
  /// The hostile the leader's aim is locked on, or nil (ADR 0020). While it holds, the world
  /// turns the leader to face them and Fire takes them.
  private(set) var lock: String?
  /// Play time since the latest lock press, which tells a quick second press apart.
  private var lockPressAge: Float?
  private(set) var hostilePoses: [String: FigurePose] = [:]
  private(set) var shots: [Shot] = []
  private var scatters: [PartyMember: Scatter] = [:]
  private var random: [PartyMember: SeededRandom] = [:]
  private var lastMotion: [PartyMember: (position: SIMD2<Float>, facing: SIMD2<Float>)] = [:]
  private var hostileYaws: [String: Float] = [:]
  private(set) var hostileJolts: [String: BodyJolt] = [:]
  private(set) var falls: [String: Fall] = [:]

  init(level: Level) {
    ballistics = Ballistics(level: level)
    startingLeader = level.party[0]
    weaponLeader = level.party[0]
    blockers = Aim.blockers(level.boxes, above: Self.aimHeight)
    movementObstacles = level.obstacles
    lookout = -level.heading
    specs = Dictionary(
      uniqueKeysWithValues: level.encounters.flatMap(\.hostiles).map { ($0.id, $0) })
    reset()
  }

  /// Restart and a failed encounter both restore authored hostile and weapon state.
  func reset() {
    hostiles = specs.mapValues { HostileState(spec: $0) }
    guardStrategies = specs.filter { $0.value.strategicGuard }.mapValues { _ in GuardStrategy() }
    random = Dictionary(
      uniqueKeysWithValues: PartyMember.allCases.enumerated().map {
        ($0.element, SeededRandom(seed: Self.seed + UInt64($0.offset)))
      })
    weaponLeader = startingLeader
    falls = [:]
    hostileJolts = [:]
    jolts = [:]
    enemyHandling = specs.mapValues { _ in HostileHandling(facing: lookout) }
    enemyRandom = Dictionary(
      uniqueKeysWithValues: specs.keys.sorted().enumerated().map {
        ($0.element, SeededRandom(seed: Self.seed + 100 + UInt64($0.offset)))
      })
    hostileWeaponPoses = enemyHandling.mapValues(\.pose)
    encounter = nil
    director.stop()
    selected = [:]
    handling = Dictionary(
      uniqueKeysWithValues: PartyMember.allCases.flatMap { member in
        Weapon.pair(for: member).enumerated().map {
          (WeaponSlot(member: member, index: $0.offset), WeaponHandling(weapon: $0.element))
        }
      })
    spin = 0
    shield = ShieldDome()
    threat = nil
    weaponPoses = Dictionary(
      uniqueKeysWithValues: PartyMember.allCases.map {
        ($0, WeaponPose(kind: Weapon.pair(for: $0)[0].kind))
      })
    scatters = [:]
    lastMotion = [:]
    target = nil
    lock = nil
    lockPressAge = nil
    shots.removeAll(keepingCapacity: true)
    events.removeAll(keepingCapacity: true)
    for (id, state) in hostiles { faceHostile(id, state) }
  }

  func begin(_ encounter: Level.Encounter) {
    self.encounter = encounter
    director.start(encounter.cues)
  }

  /// An authored, verified safe exit resolves this guard without inventing a kill or loot.
  @discardableResult
  func resolveRobotBypass(id: String, session: GameSession) -> Bool {
    guard session.mode == .exploring, session.inEncounter,
      encounter?.hostiles.contains(where: { $0.id == id && $0.attack == .robot }) == true,
      let state = hostiles[id], let robot = state.robot,
      !robot.isDown, !robot.isCleared
    else { return false }
    hostiles[id]?.clearGuard()
    enemyHandling[id]?.cancel()
    shots.removeAll(keepingCapacity: true)
    threat = nil
    target = nil
    encounter = nil
    director.stop()
    session.endEncounter()
    for key in handling.keys { handling[key]?.releaseTrigger() }
    capturePose(id)
    return true
  }

  func takeEvents() -> [CombatEvent] {
    defer { events.removeAll(keepingCapacity: true) }
    return events
  }

  /// Cues, hostile attacks and leader fire share one fixed step. Visible figures also supply
  /// scripted shots, including Tom's intervention. Practice shots spend no shared ammunition.
  /// Hostile shots pass through `untouchable` members, such as a leader mid-roll, though
  /// hostiles still see and follow them.
  func step(
    dt: Float, leader: SIMD2<Float>, facing: SIMD2<Float>, aiming: Bool, fireHeld: Bool,
    firePressed: Bool, figures: [PartyMember: SIMD2<Float>], session: GameSession,
    untouchable: Set<PartyMember> = []
  ) -> Outcome {
    var outcome = Outcome()
    shots.removeAll(keepingCapacity: true)
    guard session.mode == .exploring else { return outcome }
    lockPressAge = lockPressAge.map { $0 + dt }
    // A hostile downed, cleared or left behind in this step is no longer locked for the next.
    defer { keepLock(from: leader) }
    settleBodies(dt: dt)
    if weaponLeader != session.leader {
      handling[slot(of: weaponLeader)]?.releaseTrigger()
      handling[slot(of: session.leader)]?.releaseTrigger()
      lastMotion[session.leader] = nil
      weaponLeader = session.leader
      spin = 0
      shield.drop()
    }
    leaderFacing = facing
    aimOrigin = leader
    if firePressed || aiming { handling[slot(of: weaponLeader)]?.draw() }
    if !fireHeld { handling[slot(of: weaponLeader)]?.releaseTrigger() }
    // Tom's dome stays up while Fire is held with it in hand; otherwise it recharges.
    shield.step(dt: dt, held: fireHeld && weaponLeader == .tom && leaderWeapon.kind == .shieldDome)
    // A rotary gun spins while Fire is held with it drawn, and fires once it is up to speed.
    spin = fireHeld && isDrawn && leaderWeapon.spinUp > 0 ? min(leaderWeapon.spinUp, spin + dt) : 0
    for key in handling.keys { handling[key]?.advance(dt: dt) }
    for member in PartyMember.allCases {
      scatters[member, default: Scatter()].settle(dt: dt, spread: weapon(of: member).spread)
      weaponPoses[member]?.step(
        dt: dt, aiming: member == weaponLeader && isDrawn && (aiming || fireHeld))
    }
    let motion = shooterMotion(of: weaponLeader, at: leader, facing: facing, dt: dt)
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
      case .appear(let member): outcome.appeared.append(member)
      case .stand(let member): outcome.stood.append(member)
      case .shot(let member, let id):
        guard let from = figures[member], let state = hostiles[id], !state.isDown else { break }
        // This fight has no cinematic damage shortcut: only real component contacts count.
        guard guardStrategies[id] == nil else { break }
        let path = ShotPath(start: from, end: state.position, strike: .body(id))
        shots.append(Shot(path: path, side: .party))
        handling[slot(of: member)]?.draw()
        weaponPoses[member]?.fired()
        report(path, firedBy: weapon(of: member).kind, byLeader: false)
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
    let party = figures.filter { session.party.contains($0.key) }
    let targets = party.filter { !untouchable.contains($0.key) }
    var threatNow: String?
    for spec in encounter.hostiles {
      guard var state = hostiles[spec.id] else { continue }
      if spec.attack == .robot {
        let hasSight = ballistics.isClear(
          from: ballistics.point(state.position, above: 1.52), to: ballistics.point(leader))
        if let discharge = state.stepRobot(
          dt: dt, target: leader, hasSight: hasSight, obstacles: movementObstacles,
          party: Array(party.values))
        {
          fireRobot(discharge, state: &state, party: targets, session: session, outcome: &outcome)
        }
        if let robot = state.robot {
          guardStrategies[spec.id]?.advance(delta: dt, recovering: robot.phase == .recovering)
          switch robot.phase {
          case .notice, .tracking: threatNow = "\(robot.pattern.name): bracing."
          case .committed: threatNow = "\(robot.pattern.name) committed. Move or use cover."
          case .burst: threatNow = "\(robot.pattern.name): firing."
          case .recovering: threatNow = "\(spec.name) is recovering."
          default: break
          }
          hostiles[spec.id] = state
          faceHostile(spec.id, state, facing: state.position + robot.facing)
        }
        continue
      }
      let origin = state.position
      let inRange = simd_distance(ballistics.point(origin), ballistics.point(leader)) <= spec.range
      let canHit =
        inRange && ballistics.isClear(from: ballistics.point(origin), to: ballistics.point(leader))
      if !inRange, case .aiming = state.phase { state.restartWindUp() }
      var rifle = enemyHandling[spec.id] ?? HostileHandling(facing: lookout)
      let aimingNow: Bool
      if case .aiming = state.phase { aimingNow = inRange } else { aimingNow = false }
      rifle.advance(dt: dt, toward: leader - origin, aiming: state.isVisible && aimingNow)
      if !state.isVisible || state.isDown { rifle.cancel() }
      if let shot = state.step(dt: dt, canHit: canHit, toward: leader, canFire: inRange),
        spec.attack == .shoot
      {
        rifle.begin(deliberateMiss: shot == .miss)
        if shot == .miss, let line = spec.missLine { outcome.line = line }
      }
      if spec.attack == .shoot, state.isVisible, !state.isDown {
        var generator = enemyRandom[spec.id] ?? SeededRandom(seed: Self.seed)
        if let discharge = rifle.takeShot(using: &generator) {
          fireHostile(
            spec.id, from: origin, discharge: discharge,
            party: targets, session: session, outcome: &outcome)
        }
        enemyRandom[spec.id] = generator
      }
      enemyHandling[spec.id] = rifle
      hostileWeaponPoses[spec.id] = rifle.pose
      switch state.phase {
      case .aiming where aimingNow: threatNow = "\(spec.name) is aiming."
      case .charging: threatNow = "\(spec.name) is running at you."
      default: break
      }
      hostiles[spec.id] = state
      let direction = spec.attack == .shoot ? rifle.facing : leader - state.position
      faceHostile(spec.id, state, facing: state.position + direction)
    }
    threat = threatNow
    if outcome.retry { return outcome }
    fireLeader(
      leader: leader, aiming: aiming, facing: facing, motion: motion, fireHeld: fireHeld,
      inFight: true, session: session, outcome: &outcome)
    if !director.isPlaying, encounter.hostiles.allSatisfy({ session.defeated.contains($0.id) }) {
      session.endEncounter()
      self.encounter = nil
      director.stop()
      threat = nil
      for key in handling.keys { handling[key]?.releaseTrigger() }
      lastMotion = lastMotion.filter { $0.key == weaponLeader }
    }
    updateTarget(leader: leader, aiming: aiming, facing: facing)
    return outcome
  }
  private func fireLeader(
    leader: SIMD2<Float>, aiming: Bool, facing: SIMD2<Float>,
    motion: (speed: Float, turning: Float),
    fireHeld: Bool, inFight: Bool, session: GameSession, outcome: inout Outcome
  ) {
    let origin = leader
    guard fireHeld, isDrawn else { return }
    switch weapon.kind {
    case .shieldDome:
      // The dome is the shield's whole use: it stays up in the step itself while Fire is held.
      return
    case .energySword:
      swing(
        from: origin, facing: facing, aiming: aiming, inFight: inFight, session: session,
        outcome: &outcome)
      return
    default:
      break
    }
    // A rotary gun fires only once it has spun up.
    guard spin >= weapon.spinUp,
      let aimed = leaderShot(from: origin, aiming: aiming, facing: facing)
    else { return }
    // Without the stick or a lock, Fire turns her towards the assisted target, and she fires
    // once she faces it within the help's angle.
    if !aiming, lock == nil, case .body = aimed.strike, simd_distance(aimed.end, origin) > 0.001 {
      let towards = simd_normalize(aimed.end - origin)
      outcome.facing = towards
    }
    guard readyToFire(aimed, from: origin, facing: facing, aiming: aiming) else { return }
    handling[slot(of: weaponLeader)]?.fired()
    let trace = scattered(
      aimed, by: weaponLeader, weapon: weapon, motion: motion)
    let path = trace.path
    let armoured: Bool
    if case .body(let id) = path.strike { armoured = guardBlocks(id) } else { armoured = false }
    weaponPoses[weaponLeader]?.fired()
    jolts[session.leader, default: BodyJolt()].push(towards: -facing, by: BodyJolt.recoil)
    shots.append(
      Shot(
        path: path, side: .party,
        muzzle: WeaponPose.muzzle(from: origin, facing: facing, kind: weapon.kind), trace: trace,
        armoured: armoured))
    report(
      armoured ? ShotPath(start: path.start, end: path.end, strike: .scenery) : path,
      firedBy: weapon.kind, byLeader: true)
    if inFight, case .body(let id) = path.strike {
      hit(
        id, from: origin, damage: weapon.damage(at: simd_distance(trace.start, trace.end)),
        session: session, outcome: &outcome)
    }
  }

  private func leaderShot(from leader: SIMD2<Float>, aiming: Bool, facing: SIMD2<Float>)
    -> ShotPath?
  {
    // Assistance stays local even though the fired round travels to the bridge boundary.
    let targetReach = weapon.range
    let candidates = standingHostiles(from: leader).filter {
      let point = aimTargetPoint($0.id, from: leader)
      return simd_distance(ballistics.point(leader), point) <= targetReach
        && ballistics.isClear(from: ballistics.point(leader), to: point)
    }.map { candidate in
      Aim.Hostile(id: candidate.id, position: candidate.position, isTarget: candidate.isTarget)
    }
    guard
      let aimed = Aim.shot(
        from: leader, aim: aiming && lock == nil ? facing : nil, locked: lock, facing: facing,
        // Visibility above is the real muzzle-to-component query; a second ground-height
        // projection would wrongly hide an elevated component behind low cover. The fired
        // round still meets real scenery in scattered(), including an unassisted manual ray.
        range: targetReach, hostiles: candidates, blockers: [])
    else { return nil }
    // The first-fire safety rule also applies beyond the short assistance radius. A manual
    // map-length shot cannot intentionally pass through someone who is not yet hostile.
    if hostiles.values.contains(where: { $0.isVisible && !$0.isDown && !$0.isTargetable }) {
      let offset = aimed.end - leader
      let start = ballistics.point(leader)
      let trace = ballistics.traceAcrossLevel(
        from: start, direction: [offset.x, 0, offset.y],
        targets: hostiles.values.filter { $0.isVisible && !$0.isDown }.map {
          hostileTarget($0.spec.id)
        })
      if case .body(let id) = trace.strike, hostiles[id]?.isTargetable == false {
        return nil
      }
    }
    return aimed
  }

  private func standingHostiles(from origin: SIMD2<Float>) -> [Aim.Hostile] {
    hostiles.values.filter { $0.isVisible && !$0.isDown }.map {
      Aim.Hostile(
        id: $0.spec.id, position: aimPoint($0.spec.id, from: origin),
        isTarget: $0.isTargetable)
    }
  }

  private func aimPoint(_ id: String, from origin: SIMD2<Float>) -> SIMD2<Float> {
    let point = aimTargetPoint(id, from: origin)
    return [point.x, point.z]
  }

  private func aimTargetPoint(_ id: String, from origin: SIMD2<Float>) -> SIMD3<Float> {
    weakpoints(for: id).min {
      simd_distance_squared($0.ground, origin) < simd_distance_squared($1.ground, origin)
    }?.centre ?? ballistics.point(hostilePoint(id))
  }

  private func readyToFire(
    _ shot: ShotPath, from origin: SIMD2<Float>, facing: SIMD2<Float>, aiming: Bool
  ) -> Bool {
    guard handling[slot(of: weaponLeader)]?.isReady == true else { return false }
    // With a lock she fires once she faces them, as the help's angle allows (ADR 0020).
    if let point = lockPoint, simd_distance(point, origin) > 0.001 {
      return simd_dot(simd_normalize(point - origin), facing) >= cos(Aim.helpAngle)
    }
    if !aiming, case .body = shot.strike, simd_distance(shot.end, origin) > 0.001 {
      return simd_dot(simd_normalize(shot.end - origin), facing) >= cos(Aim.helpAngle)
    }
    return true
  }

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
    motion: (speed: Float, turning: Float)
  ) -> Ballistics.Trace {
    var scatter = scatters[member] ?? Scatter()
    var generator = random[member] ?? SeededRandom(seed: Self.seed)
    let cone = scatter.angle(spread: weapon.spread, speed: motion.speed, turning: motion.turning)
    let angle = Scatter.deviation(within: cone, using: &generator)
    let offset = path.end - path.start
    let direction =
      simd_length_squared(offset) > 0.000001 ? simd_normalize(offset) : SIMD2<Float>(0, -1)
    let turned = SIMD2(
      direction.x * cos(angle) - direction.y * sin(angle),
      direction.x * sin(angle) + direction.y * cos(angle))
    let start = ballistics.point(path.start)
    // Assistance supplies elevation to the visible component too. A manual ray still uses
    // the same collision query and cannot pass through the armour or a stone pier.
    let height: Float
    if case .body(let id) = path.strike,
      let point = weakpoints(for: id).min(by: {
        simd_distance_squared($0.ground, path.end) < simd_distance_squared($1.ground, path.end)
      }), simd_length(offset) > 0.001
    {
      height = (point.centre.y - start.y) / simd_length(offset)
    } else {
      height = 0
    }
    let ray = SIMD3(turned.x, height, turned.y)
    let result = ballistics.traceAcrossLevel(
      from: start, direction: ray,
      targets: hostiles.values.filter { $0.isVisible && !$0.isDown }
        .flatMap { [hostileTarget($0.spec.id)] + weakpoints(for: $0.spec.id).map(\.target) })
    scatter.fired(spread: weapon.spread)
    scatters[member] = scatter
    random[member] = generator
    return result
  }

  private func hit(
    _ id: String, from shooter: SIMD2<Float>, damage: Int, session: GameSession,
    outcome: inout Outcome
  ) {
    if let point = guardStrategies.keys.flatMap({ weakpoints(for: $0) }).first(where: {
      $0.id == id
    }) {
      strikeGuard(point, from: shooter, session: session, outcome: &outcome)
      return
    }
    guard let state = hostiles[id], state.isTargetable else { return }
    if guardStrategies[id] != nil {
      outcome.line = "Armour deflected the hit. \(guardHint ?? "")"
      return
    }
    for _ in 0..<damage where session.hit(id, toughness: state.spec.hits) {
      knockDown(id, from: shooter)
      outcome.line = "\(state.spec.name) is down."
      return
    }
    hostiles[id]?.flinch()
    hostileJolts[id, default: BodyJolt()].push(towards: state.position - shooter, by: BodyJolt.hit)
  }

  private func strikeGuard(
    _ point: GuardWeakpoint, from shooter: SIMD2<Float>, session: GameSession,
    outcome: inout Outcome
  ) {
    let id = point.hostileID
    guard let state = hostiles[id], state.isTargetable, let robot = state.robot else { return }
    let result = guardStrategies[id]?.accept(
      member: weaponLeader, weapon: weapon.kind, part: point.part,
      recovering: robot.phase == .recovering)
    switch result {
    case .defeated:
      session.defeat(id)
      knockDown(id, from: shooter)
      outcome.line = "The guard robot is down."
    case .progressed:
      outcome.line =
        point.part == .sensor
        ? "Miki: Sensor out. Laura, breach a side coupling."
        : "Laura: Coupling breached. Tom, the core opens when it cools."
    case .damaged:
      break
    default:
      outcome.line = "Protected component. \(guardHint ?? "")"
    }
  }

  /// Armour has stone-like impact feedback while preserving the actual contact in the trace.
  private func guardBlocks(_ id: String) -> Bool {
    if guardStrategies[id] != nil { return true }
    guard
      let point = guardStrategies.keys.flatMap({ weakpoints(for: $0) }).first(where: { $0.id == id }
      ),
      var strategy = guardStrategies[point.hostileID], let robot = hostiles[point.hostileID]?.robot
    else { return false }
    return strategy.accept(
      member: weaponLeader, weapon: weapon.kind, part: point.part,
      recovering: robot.phase == .recovering) == .blocked
  }

  private func knockDown(_ id: String, from shooter: SIMD2<Float>) {
    guard let state = hostiles[id] else { return }
    hostiles[id]?.knockDown()
    enemyHandling[id]?.cancel()
    if state.robot == nil {
      falls[id] = Fall(away: state.position - shooter, yaw: hostileYaws[id] ?? 0)
    }
    hostileJolts[id] = nil
    if let down = hostiles[id] { faceHostile(id, down) }
  }

  private func rock(_ member: PartyMember, awayFrom target: SIMD2<Float>, at position: SIMD2<Float>)
  {
    jolts[member, default: BodyJolt()].push(towards: position - target, by: BodyJolt.recoil)
  }

  private func report(_ path: ShotPath, firedBy kind: Weapon.Kind, byLeader: Bool) {
    events.append(.fired(kind, at: path.start, byLeader: byLeader))
    switch path.strike {
    case .body: events.append(.struckBody(at: path.end))
    case .scenery: events.append(.struckBlock(at: path.end))
    case .nothing: break
    }
  }

  func cameraLean(leader: SIMD2<Float>) -> SIMD2<Float> {
    guard let encounter else { return .zero }
    if let focus = encounter.focus {
      return Self.lean(from: leader, towards: focus, share: Self.focusShare, limit: Self.focusLimit)
    }
    let current = Set(encounter.hostiles.map(\.id))
    guard
      let nearest = hostiles.values.filter({
        current.contains($0.spec.id) && $0.isVisible && !$0.isDown && $0.robot?.isCleared != true
      }).min(by: {
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

  private func faceHostile(_ id: String, _ state: HostileState, facing point: SIMD2<Float>? = nil) {
    if let robot = state.robot {
      hostileYaws[id] = Movement.yaw(towards: robot.facing)
      capturePose(id)
      return
    }
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

  private func hostilePoint(_ id: String) -> SIMD2<Float> { hostiles[id]?.position ?? .zero }

  private func hostileTarget(_ id: String) -> Ballistics.Target {
    if hostiles[id]?.robot != nil {
      return Ballistics.Target(
        id: id, centre: ballistics.point(hostilePoint(id), above: RobotModelGeometry.halfHeight),
        halfHeight: RobotModelGeometry.halfHeight, radius: RobotModelGeometry.bodyRadius)
    }
    return Ballistics.Target(id: id, centre: ballistics.point(hostilePoint(id)))
  }

  private func fireRobot(
    _ discharge: RobotGuard.Discharge, state: inout HostileState,
    party: [PartyMember: SIMD2<Float>], session: GameSession, outcome: inout Outcome
  ) {
    var generator = enemyRandom[state.spec.id] ?? SeededRandom(seed: Self.seed)
    let deviation = Scatter.deviation(within: Spread.degrees(0.6), using: &generator)
    enemyRandom[state.spec.id] = generator
    let ray = discharge.direction
    let direction = SIMD3(
      ray.x * cos(deviation) - ray.z * sin(deviation), ray.y,
      ray.x * sin(deviation) + ray.z * cos(deviation))
    let trace = guarded(
      ballistics.traceAcrossLevel(
        from: discharge.origin, direction: direction,
        targets: party.map {
          Ballistics.Target(id: $0.key.rawValue, centre: ballistics.point($0.value))
        }), party: party)
    shots.append(
      Shot(
        path: trace.path, side: .hostile,
        muzzle: [discharge.origin.x, discharge.origin.z], trace: trace, gun: discharge.gun))
    report(
      trace.path, firedBy: discharge.pattern == .fan ? .shotgun : .rifle, byLeader: false)
    if case .body(let id) = trace.strike, let member = PartyMember(rawValue: id),
      state.acceptRobotBurstHit()
    {
      jolts[member, default: BodyJolt()].push(
        towards: [direction.x, direction.z], by: BodyJolt.hit)
      if member == session.leader { events.append(.leaderHit(at: trace.path.end)) }
      if session.takeHit(member) { outcome.retry = true }
    }
  }

  private func fireHostile(
    _ id: String, from start: SIMD2<Float>,
    discharge: HostileHandling.Discharge, party: [PartyMember: SIMD2<Float>],
    session: GameSession, outcome: inout Outcome
  ) {
    let trace = guarded(
      ballistics.traceAcrossLevel(
        from: ballistics.point(start),
        direction: [discharge.direction.x, 0, discharge.direction.y],
        targets: discharge.deliberateMiss
          ? []
          : party.map {
            Ballistics.Target(id: $0.key.rawValue, centre: ballistics.point($0.value))
          }), party: party)
    let muzzle = WeaponPose.muzzle(
      from: start, facing: enemyHandling[id]?.facing ?? discharge.direction, kind: .rifle)
    shots.append(Shot(path: trace.path, side: .hostile, muzzle: muzzle, trace: trace))
    report(trace.path, firedBy: .rifle, byLeader: false)
    hostileJolts[id, default: BodyJolt()].push(towards: -discharge.direction, by: BodyJolt.recoil)
    if case .body(let body) = trace.strike, let member = PartyMember(rawValue: body) {
      jolts[member, default: BodyJolt()].push(towards: discharge.direction, by: BodyJolt.hit)
      if member == session.leader { events.append(.leaderHit(at: trace.path.end)) }
      if session.takeHit(member) { outcome.retry = true }
    }
  }

  // MARK: - Paired weapons (ADR 0021)

  /// How wide Laura's swing reaches round her facing, and from how far round it her sword turns
  /// a shot.
  static let swingArc: Float = 110 * .pi / 180
  static let blockArc: Float = 120 * .pi / 180

  /// The weapon switch: the member's other weapon comes into hand, drawn if this one was, after
  /// its own draw time. The one put away keeps its magazine, and any reload goes on.
  func swapWeapon(for member: PartyMember) {
    let current = slot(of: member)
    let wasDrawn = handling[current]?.isDrawn == true
    handling[current]?.holster()
    selected[member] = (current.index + 1) % Weapon.pair(for: member).count
    weaponPoses[member] = WeaponPose(kind: weapon(of: member).kind)
    if member == weaponLeader {
      spin = 0
      shield.drop()
    }
    if wasDrawn { handling[slot(of: member)]?.draw() }
  }

  /// Laura's swing: it strikes every hostile who is a target, within the sword's reach of their
  /// body and inside the swing's arc in front of her, for the sword's hits. Without the stick or
  /// a lock, Fire turns her towards the nearest target close by, as it turns a gun.
  private func swing(
    from origin: SIMD2<Float>, facing: SIMD2<Float>, aiming: Bool, inFight: Bool,
    session: GameSession, outcome: inout Outcome
  ) {
    let reach = weapon.range
    let targets = hostiles.values.filter { $0.isVisible && !$0.isDown && $0.isTargetable }
    if !aiming, lock == nil,
      let nearest = targets.min(by: {
        simd_distance($0.position, origin) < simd_distance($1.position, origin)
      }),
      simd_distance(nearest.position, origin) <= reach + bodyRadius(nearest.spec.id) + 1.5,
      simd_distance(nearest.position, origin) > 0.001
    {
      outcome.facing = simd_normalize(nearest.position - origin)
    }
    guard handling[slot(of: weaponLeader)]?.isReady == true else { return }
    handling[slot(of: weaponLeader)]?.fired()
    weaponPoses[weaponLeader]?.fired()
    events.append(.fired(.energySword, at: origin, byLeader: true))
    for target in targets {
      if guardStrategies[target.spec.id] != nil {
        // A sword must reach an actual surface component, not any of the broad leg footprint.
        for point in weakpoints(for: target.spec.id) {
          let offset = point.ground - origin
          let distance = simd_length(offset)
          let radial = origin - target.position
          let side = point.ground - target.position
          guard simd_length(radial) >= RobotModelGeometry.bodyRadius + PartyBody.radius,
            simd_dot(simd_normalize(radial), simd_normalize(side)) >= 0.55,
            distance <= reach + point.radius,
            distance < 0.001 || simd_dot(offset / distance, facing) >= cos(Self.swingArc / 2),
            ballistics.isClear(from: ballistics.point(origin), to: point.centre)
          else { continue }
          events.append(
            guardBlocks(point.id) ? .struckBlock(at: point.ground) : .struckBody(at: point.ground))
          if inFight { strikeGuard(point, from: origin, session: session, outcome: &outcome) }
          break
        }
        continue
      }
      let offset = target.position - origin
      let distance = simd_length(offset)
      guard distance <= reach + bodyRadius(target.spec.id),
        distance < 0.001 || simd_dot(offset / distance, facing) >= cos(Self.swingArc / 2),
        ballistics.isClear(from: ballistics.point(origin), to: ballistics.point(target.position))
      else { continue }
      events.append(.struckBody(at: target.position))
      if inFight {
        hit(
          target.spec.id, from: origin, damage: weapon.damage, session: session, outcome: &outcome)
      }
    }
  }

  /// How far a hostile's body reaches from its centre: the robot's legs, or a person.
  private func bodyRadius(_ id: String) -> Float {
    hostiles[id]?.robot != nil ? RobotModelGeometry.navigationRadius : Aim.bodyRadius
  }

  /// A hostile's shot stops short of a protected member: at Tom's dome while he leads with it
  /// raised, for anyone inside it when the shooter stands outside, or on Laura's sword while she
  /// leads with it drawn and the shot comes from in front of her. A stopped shot strikes like a
  /// block and hurts nobody.
  private func guarded(_ trace: Ballistics.Trace, party: [PartyMember: SIMD2<Float>])
    -> Ballistics.Trace
  {
    guard case .body(let id) = trace.strike, let member = PartyMember(rawValue: id),
      let position = party[member]
    else { return trace }
    let start = SIMD2(trace.start.x, trace.start.z)
    if shieldIsUp, let tom = party[.tom], simd_distance(position, tom) <= ShieldDome.radius,
      simd_distance(start, tom) > ShieldDome.radius,
      let entry = Self.entry(from: start, to: position, circle: tom, radius: ShieldDome.radius)
    {
      return stopped(trace, at: entry)
    }
    let from = start - position
    if member == .laura, weaponLeader == .laura, leaderWeapon.kind == .energySword, isDrawn,
      simd_length(from) > 0.001,
      simd_dot(simd_normalize(from), leaderFacing) >= cos(Self.blockArc / 2)
    {
      return stopped(trace, at: position + simd_normalize(from) * 0.4)
    }
    return trace
  }

  private func stopped(_ trace: Ballistics.Trace, at point: SIMD2<Float>) -> Ballistics.Trace {
    Ballistics.Trace(start: trace.start, end: [point.x, trace.end.y, point.y], strike: .scenery)
  }

  /// Where a path from `start`, outside the circle, to `end`, inside it, first crosses it.
  static func entry(
    from start: SIMD2<Float>, to end: SIMD2<Float>, circle centre: SIMD2<Float>, radius: Float
  ) -> SIMD2<Float>? {
    let direction = end - start
    let offset = start - centre
    let a = simd_dot(direction, direction)
    let b = 2 * simd_dot(offset, direction)
    let c = simd_dot(offset, offset) - radius * radius
    let discriminant = b * b - 4 * a * c
    guard a > 0.000001, discriminant >= 0 else { return nil }
    let t = (-b - discriminant.squareRoot()) / (2 * a)
    guard t >= 0, t <= 1 else { return nil }
    return start + direction * t
  }

  // MARK: - The lock (ADR 0020)

  /// How far from the leader a hostile can be locked, and stays locked.
  static let lockRange: Float = 30
  /// A second lock press within this many seconds of play after the last lets go.
  static let releaseTime: Float = 0.3

  /// Where the locked hostile stands, while the lock holds.
  var lockPoint: SIMD2<Float>? { lock.map { aimPoint($0, from: aimOrigin) } }

  /// A lock press. Without a lock it locks on the hostile Fire would take, or else the
  /// nearest; with one, it moves the lock to the next hostile clockwise round the leader, as
  /// the screen shows the ground with `up` and `right`. A press within `releaseTime` of the
  /// last lets go instead, so the stick aims again.
  func pressLock(
    from leader: SIMD2<Float>, facing: SIMD2<Float>, up: SIMD2<Float>, right: SIMD2<Float>
  ) {
    keepLock(from: leader)
    if let age = lockPressAge, age <= Self.releaseTime {
      releaseLock()
      return
    }
    lockPressAge = 0
    let candidates = lockable(from: leader)
    if let current = lock,
      let next = Targeting.nextLock(
        after: current, around: leader, candidates: candidates, up: up, right: right)
    {
      lock = next
    } else {
      let ballistics = self.ballistics
      lock = Targeting.firstLock(
        from: leader, facing: facing, candidates: candidates,
        isClear: { ballistics.isClear(from: ballistics.point($0), to: ballistics.point($1)) })
    }
  }

  /// Lets go of the lock, as a quick second press or the touch controls taking over do.
  func releaseLock() {
    lock = nil
    lockPressAge = nil
  }

  /// Keeps the lock only while its hostile can still be locked.
  private func keepLock(from leader: SIMD2<Float>) {
    guard let id = lock, !lockable(from: leader).contains(where: { $0.id == id }) else { return }
    lock = nil
  }

  /// The hostiles a lock can take: standing in view, a target, and within `lockRange`.
  private func lockable(from leader: SIMD2<Float>) -> [Targeting.Candidate] {
    hostiles.values.filter {
      $0.isVisible && !$0.isDown && $0.isTargetable
        && simd_distance($0.position, leader) <= Self.lockRange
    }.map { Targeting.Candidate(id: $0.spec.id, position: $0.position) }.sorted { $0.id < $1.id }
  }

  private func updateTarget(leader: SIMD2<Float>, aiming: Bool, facing: SIMD2<Float>) {
    let path = isDrawn ? leaderShot(from: leader, aiming: aiming, facing: facing) : nil
    if case .body(let id) = path?.strike { target = hostilePoint(id) } else { target = nil }
  }

  private func capturePose(_ id: String) {
    guard let state = hostiles[id] else { return }
    if state.robot != nil {
      hostilePoses[id] = FigurePose(
        orientation: simd_quatf(angle: hostileYaws[id] ?? 0, axis: [0, 1, 0]), position: .zero)
      return
    }
    if state.isDown, let fall = falls[id] {
      let pose = fall.pose
      hostilePoses[id] = FigurePose(orientation: pose.orientation, position: pose.position)
      return
    }
    let turn = simd_quatf(angle: hostileYaws[id] ?? 0, axis: [0, 1, 0])
    let jolt = (hostileJolts[id] ?? BodyJolt()).pose(height: PartyBody.height)
    hostilePoses[id] = FigurePose(orientation: jolt.tilt * turn, position: jolt.offset)
  }
}
