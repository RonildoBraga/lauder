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
  var isDrawn: Bool { handling[weaponLeader]?.isDrawn == true }
  var leaderWeapon: Weapon { .forMember(weaponLeader) }
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
  private var handling: [PartyMember: WeaponHandling] = [:]
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
  private var reportedEmpty = false
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
    for member in handling.keys { handling[member]?.releaseTrigger() }
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
        let path = ShotPath(start: from, end: state.position, strike: .body(id))
        shots.append(Shot(path: path, side: .party))
        handling[member]?.draw()
        weaponPoses[member]?.fired()
        report(path, firedBy: Weapon.forMember(member).kind, byLeader: false)
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
          switch robot.phase {
          case .notice, .tracking: threatNow = "\(spec.name) is bracing."
          case .committed: threatNow = "\(spec.name) has committed. Move or use cover."
          case .burst: threatNow = "\(spec.name) is firing."
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
      for member in handling.keys { handling[member]?.releaseTrigger() }
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
    guard fireHeld, isDrawn, let aimed = leaderShot(from: origin, aiming: aiming, facing: facing)
    else { return }
    // Without the stick or a lock, Fire turns her towards the assisted target, and she fires
    // once she faces it within the help's angle.
    if !aiming, lock == nil, case .body = aimed.strike, simd_distance(aimed.end, origin) > 0.001 {
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
    }
    handling[weaponLeader]?.fired()
    let trace = scattered(
      aimed, by: weaponLeader, weapon: weapon, motion: motion)
    let path = trace.path
    weaponPoses[weaponLeader]?.fired()
    jolts[session.leader, default: BodyJolt()].push(towards: -facing, by: BodyJolt.recoil)
    shots.append(
      Shot(
        path: path, side: .party,
        muzzle: WeaponPose.muzzle(from: origin, facing: facing, kind: weapon.kind), trace: trace))
    report(path, firedBy: weapon.kind, byLeader: true)
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
    let candidates = standingHostiles.filter {
      simd_distance(ballistics.point(leader), ballistics.point($0.position)) <= targetReach
        && ballistics.isClear(from: ballistics.point(leader), to: ballistics.point($0.position))
    }.map { candidate in
      Aim.Hostile(id: candidate.id, position: candidate.position, isTarget: candidate.isTarget)
    }
    guard
      let aimed = Aim.shot(
        from: leader, aim: aiming && lock == nil ? facing : nil, locked: lock, facing: facing,
        range: targetReach, hostiles: candidates, blockers: blockers)
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

  private var standingHostiles: [Aim.Hostile] {
    hostiles.values.filter { $0.isVisible && !$0.isDown }.map {
      Aim.Hostile(
        id: $0.spec.id, position: hostilePoint($0.spec.id),
        isTarget: $0.isTargetable)
    }
  }

  private func readyToFire(
    _ shot: ShotPath, from origin: SIMD2<Float>, facing: SIMD2<Float>, aiming: Bool
  ) -> Bool {
    guard handling[weaponLeader]?.isReady == true else { return false }
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
    let ray = SIMD3(turned.x, Float(0), turned.y)
    let result = ballistics.traceAcrossLevel(
      from: start, direction: ray,
      targets: hostiles.values.filter { $0.isVisible && !$0.isDown }
        .map { hostileTarget($0.spec.id) })
    scatter.fired(spread: weapon.spread)
    scatters[member] = scatter
    random[member] = generator
    return result
  }

  private func hit(
    _ id: String, from shooter: SIMD2<Float>, damage: Int, session: GameSession,
    outcome: inout Outcome
  ) {
    guard let state = hostiles[id], state.isTargetable else { return }
    for _ in 0..<damage where session.hit(id, toughness: state.spec.hits) {
      knockDown(id, from: shooter)
      outcome.line = "\(state.spec.name) is down."
      return
    }
    hostiles[id]?.flinch()
    hostileJolts[id, default: BodyJolt()].push(towards: state.position - shooter, by: BodyJolt.hit)
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
    let trace = ballistics.traceAcrossLevel(
      from: discharge.origin, direction: direction,
      targets: party.map {
        Ballistics.Target(id: $0.key.rawValue, centre: ballistics.point($0.value))
      })
    shots.append(
      Shot(
        path: trace.path, side: .hostile,
        muzzle: [discharge.origin.x, discharge.origin.z], trace: trace, gun: discharge.gun))
    report(trace.path, firedBy: .rifle, byLeader: false)
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
    let trace = ballistics.traceAcrossLevel(
      from: ballistics.point(start), direction: [discharge.direction.x, 0, discharge.direction.y],
      targets: discharge.deliberateMiss
        ? []
        : party.map {
          Ballistics.Target(id: $0.key.rawValue, centre: ballistics.point($0.value))
        })
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

  // MARK: - The lock (ADR 0020)

  /// How far from the leader a hostile can be locked, and stays locked.
  static let lockRange: Float = 30
  /// A second lock press within this many seconds of play after the last lets go.
  static let releaseTime: Float = 0.3

  /// Where the locked hostile stands, while the lock holds.
  var lockPoint: SIMD2<Float>? { lock.map(hostilePoint) }

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
