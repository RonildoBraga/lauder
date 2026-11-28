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
    var actor: PartyMember? = nil
  }

  struct FigurePose {
    let orientation: simd_quatf
    let position: SIMD3<Float>
  }

  struct Outcome {
    var line: String?
    var facing: SIMD2<Float>?
    var retry = false
    var shooter: (member: PartyMember, facing: SIMD2<Float>)?
  }

  static let aimHeight: Float = 1.25
  static let cameraLeanShare: Float = 0.4
  static let cameraLeanLimit: Float = 3
  static let seed: UInt64 = 8

  private(set) var hostiles: [String: HostileState] = [:]
  private(set) var guardStrategies: [String: GuardStrategy] = [:]
  private var aggressiveGuards: Set<String> = []
  private var guardTargets: [String: GuardTargeting] = [:]
  private var autonomousMembers: Set<PartyMember> = []
  private var memberFacings: [PartyMember: SIMD2<Float>] = [:]

  /// The selected member is stable throughout a warned cycle, including recovery.
  func guardTarget(for id: String) -> PartyMember? { guardTargets[id]?.member }
  /// The member a warning scout drone watches (issue #201).
  func droneTarget(for id: String) -> PartyMember? { droneTargets[id] }
  /// The member a pack crawler is going for (issue #208).
  func crawlerTarget(for id: String) -> PartyMember? { crawlerTargets[id] }

  /// Presentation names the threatened member only while a real attack is being warned/fired.
  var guardTarget: PartyMember? {
    guard let id = encounter?.hostiles.first(where: { $0.strategicGuard })?.id,
      let robot = hostiles[id]?.robot,
      [.notice, .tracking, .committed, .burst].contains(robot.phase)
    else { return nil }
    return guardTarget(for: id)
  }

  func weakpoints(for id: String) -> [GuardWeakpoint] {
    guard let strategy = guardStrategies[id], let state = hostiles[id],
      state.isVisible, !state.isDown, let robot = state.robot, !robot.isCleared
    else { return [] }
    return GuardWeakpoint.make(id: id, robot: robot, strategy: strategy)
  }

  var guardHealth: Int? {
    guard let id = encounter?.hostiles.first(where: { $0.strategicGuard })?.id,
      let state = hostiles[id], state.isVisible, !state.isDown,
      let robot = state.robot, !robot.isCleared
    else { return nil }
    return guardStrategies[id]?.health
  }

  /// Persistent, short guidance alongside the current enemy warning. Switching never erases
  /// a component already broken; only Retry/Restart restores the machine.
  var guardHint: String? {
    guard let id = encounter?.hostiles.first(where: { $0.strategicGuard })?.id,
      let strategy = guardStrategies[id], let robot = hostiles[id]?.robot,
      !robot.isDown, !robot.isCleared
    else { return nil }
    guard strategy.health > 0 else { return nil }
    let lost = strategy.detachedLegs.count
    return "Eye hits: critical · Sword: break a leg (3 hits) · \(lost)/4 legs lost"
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
    case .minigun: return spin[weaponLeader, default: 0] > 0 ? weapon.walking : 1
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
  private var spin: [PartyMember: Float] = [:]
  /// Tom's dome, which runs down while held and recharges otherwise.
  private(set) var shield = ShieldDome()
  /// The dome as it stood after the last step, so each change is heard once.
  private var heardDome = (up: false, remaining: ShieldDome.duration)
  /// The leader's facing in the current step, for which shots Laura's sword turns.
  private var leaderFacing = SIMD2<Float>(0, -1)
  private var aimOrigin = SIMD2<Float>.zero
  private let specs: [String: Level.Hostile]
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
  /// One shared squad grenade; switching leaders cannot reset its recharge.
  private(set) var grenade: Grenade?
  private(set) var grenadeCooldown: Float = 0
  /// Whether the grenade in flight was thrown during the encounter. A throw made before it began
  /// is practice, as gunfire is: the maintainer chose that on #200.
  private var grenadeCounts = false
  /// Consumed by presentation in this fixed step, never used as damage authority.
  private(set) var blasts: [SIMD3<Float>] = []
  private var scatters: [PartyMember: Scatter] = [:]
  private var random: [PartyMember: SeededRandom] = [:]
  private var lastMotion: [PartyMember: (position: SIMD2<Float>, facing: SIMD2<Float>)] = [:]
  private var currentMotion: [PartyMember: (speed: Float, turning: Float)] = [:]
  private var hostileYaws: [String: Float] = [:]
  private(set) var hostileJolts: [String: BodyJolt] = [:]
  private(set) var falls: [String: Fall] = [:]
  /// Where scout drones may fly over this level (issue #201).
  private let airspace: ScoutDrone.Airspace
  /// The member each warning drone watches, kept until its dive commits.
  private var droneTargets: [String: PartyMember] = [:]
  /// Pack members that have been hit, which attack before their guard has noticed the party.
  private var alertedPack: Set<String> = []
  /// The member each crawler is going for.
  private var crawlerTargets: [String: PartyMember] = [:]
  /// The level's blockers at a crawler's radius, for its walking and its rams (issue #208).
  private let crawlerMotion: PartyMotion

  init(level: Level) {
    ballistics = Ballistics(level: level)
    airspace = ScoutDrone.Airspace(level: level)
    crawlerMotion = PartyMotion(radius: Crawler.radius, obstacles: level.obstacles)
    startingLeader = level.party[0]
    weaponLeader = level.party[0]
    movementObstacles = level.obstacles
    lookout = -level.heading
    specs = Dictionary(
      uniqueKeysWithValues: level.encounters.flatMap(\.hostiles).map { ($0.id, $0) })
    reset()
  }

  /// Restart and a failed encounter both restore authored hostile and weapon state.
  func reset() {
    hostiles = specs.mapValues { HostileState(spec: $0) }
    aggressiveGuards = []
    droneTargets = [:]
    alertedPack = []
    crawlerTargets = [:]
    guardTargets = specs.filter { $0.value.strategicGuard }.mapValues { _ in GuardTargeting() }
    autonomousMembers = []
    memberFacings = [:]
    guardStrategies = specs.filter { $0.value.strategicGuard }.mapValues { _ in GuardStrategy() }
    grenade = nil
    grenadeCooldown = 0
    blasts.removeAll(keepingCapacity: true)
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
    spin = [:]
    shield = ShieldDome()
    heardDome = (false, ShieldDome.duration)
    threat = nil
    weaponPoses = Dictionary(
      uniqueKeysWithValues: PartyMember.allCases.map {
        ($0, WeaponPose(kind: Weapon.pair(for: $0)[0].kind))
      })
    scatters = [:]
    lastMotion = [:]
    currentMotion = [:]
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
    for spec in encounter?.hostiles ?? [] where spec.isPack {
      hostiles[spec.id]?.clearDrone()
      hostiles[spec.id]?.clearCrawler()
      droneTargets[spec.id] = nil
      crawlerTargets[spec.id] = nil
    }
    grenade = nil
    blasts.removeAll(keepingCapacity: true)
    aggressiveGuards.remove(id)
    guardTargets[id]?.reset()
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

  /// Only a machine that has noticed the party or taken a real player hit authorises AI
  /// combat. Merely entering the encounter trigger must leave the quiet west bypass intact.
  func companionGuard(near leader: SIMD2<Float>) -> (
    id: String, robot: RobotGuard, strategy: GuardStrategy
  )? {
    guard let encounter else { return nil }
    for spec in encounter.hostiles where spec.strategicGuard && aggressiveGuards.contains(spec.id) {
      if let state = hostiles[spec.id], state.isVisible, !state.isDown, state.isTargetable,
        let robot = state.robot, !robot.isCleared,
        simd_distance(leader, state.position) <= RobotGuard.detectionRange,
        let strategy = guardStrategies[spec.id]
      {
        return (spec.id, robot, strategy)
      }
    }
    return nil
  }

  func companionCanFire(
    _ member: PartyMember, from origin: SIMD2<Float>, at point: GuardWeakpoint,
    weapon kind: Weapon.Kind, figures: [PartyMember: SIMD2<Float>]
  ) -> Bool {
    guard let weapon = Weapon.pair(for: member).first(where: { $0.kind == kind }),
      let state = hostiles[point.hostileID], state.isTargetable, !state.isDown,
      weakpoints(for: point.hostileID).contains(where: { $0.id == point.id })
    else { return false }
    let start = ballistics.point(origin)
    let delta = point.centre - start
    let friends = allyTargets(of: member, among: figures)
    if kind == .energySword {
      guard swordReaches(point, of: state.position, from: origin, reach: weapon.range) else {
        return false
      }
      let trace = ballistics.trace(
        from: start, direction: delta, range: simd_length(delta), targets: friends)
      if case .body = trace.strike { return false }
      return true
    }
    guard simd_length(delta) <= weapon.range else { return false }
    let trace = traceCombat(
      from: start, direction: delta,
      targets: [hostileTarget(point.hostileID)] + weakpoints(for: point.hostileID).map(\.target)
        + friends)
    return trace.strike == .body(point.id)
  }

  func companionCanFireAtBody(
    _ member: PartyMember, from origin: SIMD2<Float>, at id: String,
    weapon kind: Weapon.Kind, figures: [PartyMember: SIMD2<Float>]
  ) -> Bool {
    guard let weapon = Weapon.pair(for: member).first(where: { $0.kind == kind }),
      kind.shoots, let state = hostiles[id], state.isTargetable, !state.isDown
    else { return false }
    let start = ballistics.point(origin)
    let target = hostileTarget(id)
    let delta = target.centre - start
    guard simd_length(delta) <= weapon.range else { return false }
    let friends = allyTargets(of: member, among: figures)
    let points = weakpoints(for: id)
    let trace = traceCombat(
      from: start, direction: delta, targets: [target] + points.map(\.target) + friends)
    guard case .body(let hitID) = trace.strike else { return false }
    return hitID == id || points.contains { $0.id == hitID }
  }

  func companionHasCover(at point: SIMD2<Float>, from robot: RobotGuard) -> Bool {
    (0..<2).allSatisfy {
      !ballistics.isClear(from: robot.muzzle(gun: $0), to: ballistics.point(point))
    }
  }

  func companionIsThreatened(at point: SIMD2<Float>, by robot: RobotGuard) -> Bool {
    guard robot.phase == .committed || robot.phase == .burst,
      let committed = robot.committedPoint, simd_distance(committed, robot.position) > 0.001
    else { return false }
    let direction = simd_normalize(committed - robot.position)
    let offset = point - robot.position
    let along = simd_dot(offset, direction)
    let width: Float =
      robot.pattern == .fan ? max(0, along) * tan(RobotGuard.gunYawLimit) + 0.8 : 1.1
    return along > 0 && along <= RobotGuard.attackRange + 2
      && simd_length(offset - direction * along) < width
  }

  private func prepareCompanions(
    _ intents: [PartyMember: CompanionTactics.Intent], figures: [PartyMember: SIMD2<Float>],
    session: GameSession, dt: Float
  ) {
    let active =
      session.combatStance == .attack && session.inEncounter
        && companionGuard(near: aimOrigin) != nil
      ? Set(
        intents.keys.filter {
          $0 != session.leader && session.party.contains($0) && intents[$0]?.engaged == true
        })
      : []
    for member in autonomousMembers.subtracting(active) where member != session.leader {
      handling[slot(of: member)]?.holster()
      spin[member] = 0
    }
    for member in active.subtracting(autonomousMembers) { lastMotion[member] = nil }
    autonomousMembers = active
    for member in active {
      if let kind = intents[member]?.weapon,
        Weapon.pair(for: member).contains(where: { $0.kind == kind }),
        weapon(of: member).kind != kind
      {
        swapWeapon(for: member)
      }
      handling[slot(of: member)]?.draw()
      let weapon = weapon(of: member)
      let held = intents[member]?.fire == true
      if !held { handling[slot(of: member)]?.releaseTrigger() }
      let spun = spin[member, default: 0]
      spin[member] = held && weapon.spinUp > 0 ? min(weapon.spinUp, spun + dt) : 0
      if spun == 0, spin[member, default: 0] > 0, let point = figures[member] {
        events.append(.spinUp(at: point, byLeader: false))
      }
    }
  }

  /// Each change of Tom's dome since the last step, heard at `point`. Only Tom as leader raises
  /// it, and a switch, a roll or a scene can drop it between steps; the recharge is heard only
  /// while the dome is in his hands.
  private func reportDome(at point: SIMD2<Float>, inHand: Bool) {
    let before = heardDome
    heardDome = (shield.isUp, shield.remaining)
    if shield.isUp, !before.up {
      events.append(.dome(.raised, at: point))
    } else if !shield.isUp, before.up {
      events.append(.dome(shield.remaining > 0 ? .lowered : .collapsed, at: point))
    }
    if shield.isUp, shield.remaining <= ShieldDome.warning,
      before.remaining > ShieldDome.warning || !before.up
    {
      events.append(.dome(.fading, at: point))
    }
    if inHand, !shield.isUp, before.remaining < ShieldDome.duration,
      shield.remaining >= ShieldDome.duration
    {
      events.append(.dome(.recharged, at: point))
    }
  }

  private func fireCompanions(
    _ intents: [PartyMember: CompanionTactics.Intent], figures: [PartyMember: SIMD2<Float>],
    session: GameSession, outcome: inout Outcome
  ) {
    guard session.combatStance == .attack, let leader = figures[session.leader],
      let guardState = companionGuard(near: leader)
    else {
      return
    }
    for member in session.companions where autonomousMembers.contains(member) {
      guard intents[member]?.fire == true, let origin = figures[member],
        let facing = memberFacings[member], let look = intents[member]?.lookAt
      else { continue }
      let weapon = weapon(of: member)
      let end: SIMD2<Float>
      let height: Float
      var struck = guardState.id
      if let id = intents[member]?.drone ?? intents[member]?.crawler {
        guard
          companionCanFireAtBody(
            member, from: origin, at: id, weapon: weapon.kind, figures: figures)
        else { continue }
        end = hostilePoint(id)
        height = hostileTarget(id).centre.y
        struck = id
      } else if intents[member]?.targetsBody == true {
        guard
          companionCanFireAtBody(
            member, from: origin, at: guardState.id, weapon: weapon.kind, figures: figures)
        else { continue }
        end = guardState.robot.position
        height = hostileTarget(guardState.id).centre.y
      } else {
        guard
          let point = weakpoints(for: guardState.id).min(by: {
            simd_distance_squared($0.ground, look) < simd_distance_squared($1.ground, look)
          }),
          companionCanFire(member, from: origin, at: point, weapon: weapon.kind, figures: figures)
        else { continue }
        end = point.ground
        height = point.centre.y
      }
      let motion = currentMotion[member] ?? (speed: 0, turning: 0)
      fireWeapon(
        by: member, from: origin, facing: facing, aiming: true,
        path: ShotPath(start: origin, end: end, strike: .body(struck)),
        motion: motion, fireHeld: true, inFight: true, allies: figures,
        session: session, outcome: &outcome, targetHeight: height)
    }
  }

  /// Only actual native discharges during an engaged nearby guard fight supply threat
  /// evidence. Drawing, spinning up, an empty trigger or a planner intention does not.
  private func recordGuardAttack(by member: PartyMember, from origin: SIMD2<Float>) {
    guard let encounter else { return }
    for spec in encounter.hostiles
    where spec.strategicGuard && aggressiveGuards.contains(spec.id) {
      guard let state = hostiles[spec.id], state.isVisible, !state.isDown, state.isTargetable,
        simd_distance(origin, state.position) <= RobotGuard.detectionRange
      else { continue }
      guardTargets[spec.id]?.recordAttack(by: member)
    }
  }

  /// Cues, hostile attacks and leader fire share one fixed step. Visible figures also supply
  /// scripted shots, including Tom's intervention. Practice shots spend no shared ammunition.
  /// Hostile shots pass through `untouchable` members, such as a leader mid-roll, though
  /// hostiles still see and follow them.
  func step(
    dt: Float, leader: SIMD2<Float>, facing: SIMD2<Float>, aiming: Bool, fireHeld: Bool,
    firePressed: Bool, figures: [PartyMember: SIMD2<Float>], session: GameSession,
    grenadePressed: Bool = false,
    untouchable: Set<PartyMember> = [],
    companionIntents: [PartyMember: CompanionTactics.Intent] = [:],
    facings: [PartyMember: SIMD2<Float>] = [:]
  ) -> Outcome {
    var outcome = Outcome()
    shots.removeAll(keepingCapacity: true)
    guard session.mode == .exploring, dt.isFinite, dt > 0 else { return outcome }
    blasts.removeAll(keepingCapacity: true)
    grenadeCooldown = max(0, grenadeCooldown - dt)
    let throwing =
      grenadePressed
      && throwGrenade(from: leader, facing: facing, aiming: aiming, by: session.leader)
    let firing = fireHeld && !throwing
    let pressed = firePressed && !throwing
    advanceGrenade(dt: dt, session: session, outcome: &outcome)
    lockPressAge = lockPressAge.map { $0 + dt }
    // A hostile downed, cleared or left behind in this step is no longer locked for the next.
    defer { keepLock(from: leader) }
    settleBodies(dt: dt)
    if weaponLeader != session.leader {
      spin[weaponLeader] = 0
      handling[slot(of: weaponLeader)]?.releaseTrigger()
      handling[slot(of: session.leader)]?.releaseTrigger()
      lastMotion[session.leader] = nil
      weaponLeader = session.leader
      spin[weaponLeader] = 0
      shield.drop()
    }
    leaderFacing = facing
    memberFacings = facings
    memberFacings[session.leader] = facing
    aimOrigin = leader
    if pressed || aiming { handling[slot(of: weaponLeader)]?.draw() }
    if !firing { handling[slot(of: weaponLeader)]?.releaseTrigger() }
    // Tom's dome stays up while Fire is held with it in hand; otherwise it recharges.
    let domeInHand = weaponLeader == .tom && leaderWeapon.kind == .shieldDome
    shield.step(dt: dt, held: firing && domeInHand)
    reportDome(at: weaponLeader == .tom ? leader : figures[.tom] ?? leader, inHand: domeInHand)
    // A rotary gun spins while Fire is held with it drawn, and fires once it is up to speed.
    let leaderSpin = spin[weaponLeader, default: 0]
    spin[weaponLeader] =
      firing && isDrawn && leaderWeapon.spinUp > 0
      ? min(leaderWeapon.spinUp, leaderSpin + dt) : 0
    if leaderSpin == 0, spin[weaponLeader, default: 0] > 0 {
      events.append(.spinUp(at: leader, byLeader: true))
    }
    prepareCompanions(companionIntents, figures: figures, session: session, dt: dt)
    for key in handling.keys { handling[key]?.advance(dt: dt) }
    for member in PartyMember.allCases {
      scatters[member, default: Scatter()].settle(dt: dt, spread: weapon(of: member).spread)
      weaponPoses[member]?.step(
        dt: dt,
        aiming: member == weaponLeader
          ? isDrawn && (aiming || firing) : autonomousMembers.contains(member))
    }
    let motion = shooterMotion(of: weaponLeader, at: leader, facing: facing, dt: dt)
    for member in autonomousMembers {
      if let position = figures[member], let facing = memberFacings[member] {
        currentMotion[member] = shooterMotion(of: member, at: position, facing: facing, dt: dt)
      }
    }
    guard let encounter else {
      settlePack(dt: dt)
      fireLeader(
        leader: leader, aiming: aiming, facing: facing, motion: motion, fireHeld: firing,
        inFight: false, session: session, outcome: &outcome)
      updateTarget(leader: leader, aiming: aiming, facing: facing)
      return outcome
    }
    for cue in director.step(dt: dt) {
      switch cue {
      case .reveal(let id): hostiles[id]?.reveal()
      case .engage(let id): hostiles[id]?.engage()
      case .say(let speaker, let line): outcome.line = "\(speaker): “\(line)”"
      case .shot(let member, let id):
        guard let from = figures[member], let state = hostiles[id], !state.isDown else { break }
        // This fight has no cinematic damage shortcut: only actual damaging contacts count.
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
      case .talk(let conversation): _ = session.converse(conversation)
      }
    }
    let party = figures.filter { session.party.contains($0.key) }
    let targets = party.filter { !untouchable.contains($0.key) }
    var threatNow: String?
    // A pack member's warning outranks the guard's status, such as its recovery, which is
    // exactly when the pack attacks, but never the guard's own warned attack.
    var packThreat: String?
    var guardWarns = false
    for spec in encounter.hostiles {
      guard var state = hostiles[spec.id] else { continue }
      if spec.attack == .robot {
        let previousPhase = state.robot?.phase
        var chosenMember: PartyMember? = session.leader
        var chosenPoint = leader
        // A robot hostile always has its robot.
        var hasSight = state.robot.map { guardSees(leader, from: $0) } ?? false
        var retaliation = false
        if spec.strategicGuard, let robot = state.robot {
          let visible = Set(
            party.compactMap { member, point -> PartyMember? in
              simd_distance(point, state.position) <= RobotGuard.detectionRange
                && guardSees(point, from: robot)
                ? member : nil
            })
          // Retaliation must be able to reach commitment. Keep the wider sight set for
          // quiet detection and the fixed target's complete pre-commit warning.
          let eligible = Set(
            visible.filter { member in
              party[member].map { simd_distance($0, state.position) <= RobotGuard.attackRange }
                ?? false
            })
          var selection = guardTargets[spec.id] ?? GuardTargeting()
          selection.advance(dt: dt)
          let selected = selection.select(
            leader: session.leader, phase: robot.phase,
            engaged: aggressiveGuards.contains(spec.id), eligible: eligible)
          guardTargets[spec.id] = selection
          // A missing/occluded chosen member cannot redirect an unfinished warning to the
          // new leader. The robot enters search, or finishes its already committed point.
          chosenMember = selected
          chosenPoint =
            selected.flatMap { party[$0] }
            ?? robot.committedPoint ?? state.position
          hasSight = selected.map { visible.contains($0) } ?? false
          retaliation = selection.isRetaliation
        }
        if let discharge = state.stepRobot(
          dt: dt, target: chosenPoint, hasSight: hasSight, obstacles: movementObstacles,
          party: Array(party.values), awareOfTarget: retaliation,
          speedMultiplier: guardStrategies[spec.id]?.speedMultiplier ?? 1,
          turnMultiplier: guardStrategies[spec.id]?.turnMultiplier ?? 1,
          grounded: guardStrategies[spec.id]?.detachedLegs.count == GuardStrategy.legCount)
        {
          fireRobot(discharge, state: &state, party: targets, session: session, outcome: &outcome)
        }
        if let robot = state.robot {
          if spec.strategicGuard, robot.phase == .notice, previousPhase != .notice,
            let member = chosenMember, party[member] != nil
          {
            events.append(.guardTargeted(member, at: chosenPoint))
          }
          if [.notice, .tracking, .committed, .burst, .recovering, .searching].contains(robot.phase)
          {
            aggressiveGuards.insert(spec.id)
          }
          let targetName = chosenMember?.displayName ?? "Squad"
          if [.notice, .tracking, .committed, .burst].contains(robot.phase) { guardWarns = true }
          switch robot.phase {
          case .notice, .tracking:
            threatNow =
              spec.strategicGuard
              ? "\(targetName) targeted · \(robot.pattern.name): bracing."
              : "\(robot.pattern.name): bracing."
          case .committed:
            threatNow =
              spec.strategicGuard
              ? "\(targetName) targeted · \(robot.pattern.name) committed. Move or use cover."
              : "\(robot.pattern.name) committed. Move or use cover."
          case .burst:
            threatNow =
              spec.strategicGuard
              ? "\(targetName) targeted · \(robot.pattern.name): firing."
              : "\(robot.pattern.name): firing."
          case .recovering: threatNow = "\(spec.name) is recovering."
          case .staggered: threatNow = "Leg broken — guard staggered. Reposition."
          default: break
          }
          hostiles[spec.id] = state
          faceHostile(spec.id, state, facing: state.position + robot.facing)
        }
        continue
      }
      if spec.isDrone {
        stepDrone(
          spec, state: &state, in: encounter, party: party, targets: targets,
          session: session, dt: dt, threat: &packThreat, outcome: &outcome)
        hostiles[spec.id] = state
        continue
      }
      if spec.isCrawler {
        stepCrawler(
          spec, state: &state, in: encounter, party: party, targets: targets,
          session: session, dt: dt, threat: &packThreat, outcome: &outcome)
        hostiles[spec.id] = state
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
      if let shot = state.step(dt: dt, canHit: canHit, canFire: inRange),
        spec.attack == .shoot
      {
        rifle.begin(deliberateMiss: shot == .miss)
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
      default: break
      }
      hostiles[spec.id] = state
      faceHostile(spec.id, state, facing: state.position + rifle.facing)
    }
    if let packThreat, !guardWarns { threatNow = packThreat }
    threat = threatNow
    if outcome.retry { return outcome }
    fireLeader(
      leader: leader, aiming: aiming, facing: facing, motion: motion, fireHeld: firing,
      inFight: true, session: session, outcome: &outcome)
    fireCompanions(companionIntents, figures: party, session: session, outcome: &outcome)
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
    guard fireHeld, isDrawn else { return }
    let path =
      weapon.kind == .energySword || weapon.kind == .shieldDome
      ? nil : leaderShot(from: leader, aiming: aiming, facing: facing)
    fireWeapon(
      by: session.leader, from: leader, facing: facing, aiming: aiming, path: path,
      motion: motion, fireHeld: fireHeld, inFight: inFight, allies: [:], session: session,
      outcome: &outcome)
  }

  /// Both sources use the same native weapon, timing, scatter and contact rules. AI supplies
  /// an intention; it cannot replace the actor identity or turn a component hit into a cue.
  private func fireWeapon(
    by member: PartyMember, from origin: SIMD2<Float>, facing: SIMD2<Float>, aiming: Bool,
    path: ShotPath?, motion: (speed: Float, turning: Float), fireHeld: Bool, inFight: Bool,
    allies: [PartyMember: SIMD2<Float>], session: GameSession, outcome: inout Outcome,
    targetHeight: Float? = nil
  ) {
    let weapon = weapon(of: member)
    let player = member == session.leader
    guard fireHeld, handling[slot(of: member)]?.isDrawn == true else { return }
    if weapon.kind == .shieldDome { return }
    if weapon.kind == .energySword {
      swing(
        by: member, from: origin, facing: facing, aiming: aiming, inFight: inFight,
        session: session, outcome: &outcome)
      return
    }
    guard spin[member, default: 0] >= weapon.spinUp, let aimed = path else { return }
    if player, !aiming, lock == nil, case .body = aimed.strike,
      simd_distance(aimed.end, origin) > 0.001
    {
      outcome.facing = simd_normalize(aimed.end - origin)
    }
    guard handling[slot(of: member)]?.isReady == true else { return }
    if player {
      guard readyToFire(aimed, from: origin, facing: facing, aiming: aiming) else { return }
    } else {
      let offset = aimed.end - origin
      guard simd_length(offset) > 0.001,
        simd_dot(simd_normalize(offset), facing) >= cos(Aim.helpAngle)
      else { return }
    }
    handling[slot(of: member)]?.fired()
    if inFight { recordGuardAttack(by: member, from: origin) }
    let trace = scattered(
      aimed, by: member, weapon: weapon, motion: motion, allies: allies, targetHeight: targetHeight)
    let path = trace.path
    let armoured: Bool
    if case .body(let id) = path.strike {
      armoured = id.hasPrefix(Self.allyPrefix)
    } else {
      armoured = false
    }
    weaponPoses[member]?.fired()
    jolts[member, default: BodyJolt()].push(towards: -facing, by: BodyJolt.recoil)
    shots.append(
      Shot(
        path: path, side: .party,
        muzzle: WeaponPose.muzzle(from: origin, facing: facing, kind: weapon.kind), trace: trace,
        armoured: armoured, actor: member))
    report(
      armoured ? ShotPath(start: path.start, end: path.end, strike: .scenery) : path,
      firedBy: weapon.kind, byLeader: player)
    if inFight, case .body(let id) = path.strike {
      hit(
        id, by: member, weapon: weapon.kind, from: origin,
        damage: weapon.damage(at: simd_distance(trace.start, trace.end)),
        session: session, outcome: &outcome, impact: trace.end)
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
    let points = weakpoints(for: id)
    let preferred =
      leaderWeapon.kind == .energySword
      ? points.filter {
        if case .leg = $0.part { return true }
        return false
      }
      : points.filter { $0.part == .eye }
    if let drone = hostiles[id]?.drone { return drone.centre }
    if let crawler = hostiles[id]?.crawler { return crawler.centre }
    return preferred.min {
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

  func traceCombat(
    from start: SIMD3<Float>, direction: SIMD3<Float>, targets: [Ballistics.Target]
  ) -> Ballistics.Trace {
    let broad = ballistics.traceAcrossLevel(from: start, direction: direction, targets: targets)
    guard case .body(let id) = broad.strike, let robot = hostiles[id]?.robot,
      let eye = weakpoints(for: id).first(where: { $0.part == .eye }),
      targets.contains(where: { $0.id == eye.id })
    else { return broad }
    let offset = SIMD2(start.x, start.z) - robot.position
    // The recessed eye shows only to shots from within its view angle of the guard's facing.
    let fromEye = SIMD2(start.x, start.z) - eye.ground
    let seesEye =
      simd_length(fromEye) > 0.0001
      && simd_dot(simd_normalize(fromEye), robot.facing) >= cos(GuardWeakpoint.eyeViewAngle)
    guard simd_length(offset) > RobotModelGeometry.bodyRadius, seesEye
    else { return broad }
    let refined = ballistics.traceAcrossLevel(
      from: start, direction: direction, targets: targets.filter { $0.id != id })
    return refined.strike == .body(eye.id) ? refined : broad
  }

  /// Whether a guard sees `point`, looking out from its sight height, which drops with its body.
  func guardSees(_ point: SIMD2<Float>, from robot: RobotGuard) -> Bool {
    ballistics.isClear(
      from: ballistics.point(robot.position, above: robot.sightHeight),
      to: ballistics.point(point))
  }

  private func scattered(
    _ path: ShotPath, by member: PartyMember, weapon: Weapon,
    motion: (speed: Float, turning: Float), allies: [PartyMember: SIMD2<Float>] = [:],
    targetHeight: Float? = nil
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
    if let targetHeight, simd_length(offset) > 0.001 {
      height = (targetHeight - start.y) / simd_length(offset)
    } else if case .body(let id) = path.strike,
      let point = weakpoints(for: id).first(where: { $0.part == .eye }),
      simd_length(offset) > 0.001
    {
      height = (point.centre.y - start.y) / simd_length(offset)
    } else if case .body(let id) = path.strike, let drone = hostiles[id]?.drone,
      simd_length(offset) > 0.001
    {
      // Assistance raises the round to a drone it has chosen; a manual ray stays level.
      height = (drone.height - start.y) / simd_length(offset)
    } else if case .body(let id) = path.strike, hostiles[id]?.crawler != nil,
      simd_length(offset) > 0.001
    {
      // And lowers it to a crawler on the snow.
      height = (Crawler.centreHeight - start.y) / simd_length(offset)
    } else {
      height = 0
    }
    let ray = SIMD3(turned.x, height, turned.y)
    let result = traceCombat(
      from: start, direction: ray,
      targets: hostiles.values.filter { $0.isVisible && !$0.isDown }
        .flatMap { [hostileTarget($0.spec.id)] + weakpoints(for: $0.spec.id).map(\.target) }
        + allyTargets(of: member, among: allies))
    scatter.fired(spread: weapon.spread)
    scatters[member] = scatter
    random[member] = generator
    return result
  }

  /// The shared recharge/projectile eligibility for the controlled member. The world adds its
  /// spatial roll gate before queuing a request; actual launch checks these same rules again.
  func canThrowGrenade(by member: PartyMember) -> Bool {
    member == .tom && !holdsParty && grenade == nil && grenadeCooldown == 0
  }

  private func throwGrenade(
    from origin: SIMD2<Float>, facing: SIMD2<Float>, aiming: Bool, by member: PartyMember
  ) -> Bool {
    guard canThrowGrenade(by: member) else { return false }
    // Without a lock, the throw takes an enemy its arc lands on. The arc clears low cover that
    // a bullet line can't, though tall cover still stops it (#200).
    let inRange = hostiles.values.filter {
      $0.isTargetable && !$0.isDown && simd_distance(origin, $0.position) <= Grenade.maximumRange
    }.sorted { $0.spec.id < $1.spec.id }
    let destination: SIMD2<Float>
    if let lock, let state = hostiles[lock], state.isTargetable, !state.isDown {
      destination = state.position
    } else if aiming,
      let aimed = Targeting.aimed(
        along: facing, within: Aim.helpAngle, from: origin,
        candidates: inRange.map { Targeting.Candidate(id: $0.spec.id, position: $0.position) },
        range: Grenade.maximumRange, isClear: { self.grenadeLands(from: $0, at: $1) }),
      let state = hostiles[aimed]
    {
      // Aimed like the guns' help: an enemy in the narrow aim cone takes the throw.
      destination = state.position
    } else if !aiming,
      let nearest = inRange.filter({ grenadeLands(from: origin, at: $0.position) }).min(by: {
        let a = simd_distance_squared(origin, $0.position)
        let b = simd_distance_squared(origin, $1.position)
        return a == b ? $0.spec.id < $1.spec.id : a < b
      })
    {
      destination = nearest.position
    } else {
      destination = origin + facing * Grenade.maximumRange
    }
    guard let thrown = Grenade(from: ballistics.point(origin), toward: destination, by: member)
    else { return false }
    grenade = thrown
    grenadeCounts = encounter != nil
    grenadeCooldown = Grenade.cooldown
    recordGuardAttack(by: member, from: origin)
    return true
  }

  /// Whether a throw from `origin` at `point` lands there, rather than stopping short on cover.
  private func grenadeLands(from origin: SIMD2<Float>, at point: SIMD2<Float>) -> Bool {
    guard var trial = Grenade(from: ballistics.point(origin), toward: point, by: .tom)
    else { return false }
    _ = trial.step(dt: Grenade.flightDuration, trace: grenadeTrace)
    return simd_distance(SIMD2(trial.position.x, trial.position.z), point) < 0.25
  }

  /// A grenade's flight meets scenery, never bodies.
  private func grenadeTrace(_ start: SIMD3<Float>, _ end: SIMD3<Float>) -> Ballistics.Trace {
    let delta = end - start
    return ballistics.trace(from: start, direction: delta, range: simd_length(delta), targets: [])
  }

  private func advanceGrenade(dt: Float, session: GameSession, outcome: inout Outcome) {
    guard var thrown = grenade else { return }
    let explosion = thrown.step(dt: dt, trace: grenadeTrace)
    grenade = thrown.isFinished ? nil : thrown
    guard let centre = explosion else { return }
    blasts.append(centre)
    // Reuse the existing one impact-sound event; damage numbers never emit duplicate sound.
    events.append(.struckBlock(at: [centre.x, centre.z]))
    guard session.inEncounter, grenadeCounts else { return }
    for state in hostiles.values.sorted(by: { $0.spec.id < $1.spec.id })
    where state.isTargetable && !state.isDown {
      let target = hostileTarget(state.spec.id)
      let distance = max(0, simd_distance(centre, target.centre) - target.radius)
      let damage = Grenade.damage(at: distance)
      guard damage > 0, ballistics.isClear(from: centre, to: target.centre) else { continue }
      hit(
        state.spec.id, by: thrown.thrower, weapon: nil, from: [centre.x, centre.z],
        damage: damage, session: session, outcome: &outcome,
        impact: target.centre)
    }
  }

  private func hit(
    _ id: String, by member: PartyMember, weapon: Weapon.Kind?, from shooter: SIMD2<Float>,
    damage: Int,
    session: GameSession,
    outcome: inout Outcome, impact: SIMD3<Float>? = nil
  ) {
    guard session.mode == .exploring, damage > 0 else { return }
    let point = guardStrategies.keys.flatMap({ weakpoints(for: $0) }).first(where: {
      $0.id == id
    })
    let targetID = point?.hostileID ?? id
    guard let state = hostiles[targetID], state.isTargetable, !state.isDown else { return }
    let contact = impact ?? point?.centre ?? ballistics.point(state.position)
    if var strategy = guardStrategies[targetID] {
      guard
        let result = strategy.accept(
          weapon: weapon, part: point?.part, damage: damage)
      else { return }
      guardStrategies[targetID] = strategy
      aggressiveGuards.insert(targetID)
      guardTargets[targetID]?.recordAttack(by: member)
      events.append(
        .damaged(
          DamageHit(
            target: targetID, attacker: member, weapon: weapon, amount: result.amount,
            position: contact, effectiveness: result.effectiveness,
            brokeComponent: result.brokeComponent)))
      if result.defeated {
        session.defeat(targetID)
        knockDown(targetID, from: shooter)
        let dropped = dropPack(session: session, from: shooter)
        outcome.line =
          dropped.isEmpty
          ? "The guard robot is down."
          : "The guard robot is down, and its \(dropped.joined(separator: " and ")) go down with it."
      } else if result.brokeComponent {
        var staggered = state
        if staggered.staggerRobot() {
          hostiles[targetID] = staggered
          events.append(.guardLegBroken(at: state.position))
          threat = "Leg broken — guard staggered. Reposition."
        }
        outcome.line = "Leg detached. Guard staggered."
      }
      return
    }
    let before = session.remainingHealth(of: targetID, toughness: state.spec.hits)
    let applied = min(damage, before)
    guard applied > 0 else { return }
    var defeated = false
    for _ in 0..<applied {
      if session.hit(targetID, toughness: state.spec.hits) {
        defeated = true
        break
      }
    }
    events.append(
      .damaged(
        DamageHit(
          target: targetID, attacker: member, weapon: weapon, amount: applied,
          position: contact, effectiveness: .normal, brokeComponent: false)))
    if state.drone != nil || state.crawler != nil { alertPack(targetID, by: member) }
    if defeated {
      knockDown(targetID, from: shooter)
      outcome.line = "\(state.spec.name) is down."
    } else {
      hostiles[targetID]?.flinch()
      hostileJolts[targetID, default: BodyJolt()].push(
        towards: state.position - shooter, by: BodyJolt.hit)
    }
  }

  private func knockDown(_ id: String, from shooter: SIMD2<Float>) {
    guard let state = hostiles[id] else { return }
    hostiles[id]?.knockDown()
    guardTargets[id]?.reset()
    enemyHandling[id]?.cancel()
    droneTargets[id] = nil
    crawlerTargets[id] = nil
    // The robot settles in place; a drone falls and a crawler collapses in their own motion.
    if state.robot == nil, state.drone == nil, state.crawler == nil {
      falls[id] = Fall(away: state.position - shooter, yaw: hostileYaws[id] ?? 0)
    }
    hostileJolts[id] = nil
    if let down = hostiles[id] { faceHostile(id, down) }
  }

  private func rock(_ member: PartyMember, awayFrom target: SIMD2<Float>, at position: SIMD2<Float>)
  {
    jolts[member, default: BodyJolt()].push(towards: position - target, by: BodyJolt.recoil)
  }

  /// The prefix that marks a member as an ally in a shot's way, not its target.
  static let allyPrefix = "ally."

  /// The party as targets of a hostile's round, each by its member's ID.
  private func partyTargets(_ party: [PartyMember: SIMD2<Float>]) -> [Ballistics.Target] {
    party.map { Ballistics.Target(id: $0.key.rawValue, centre: ballistics.point($0.value)) }
  }

  /// Everyone but `member`, as allies a shot of theirs could strike instead of its target.
  private func allyTargets(
    of member: PartyMember, among figures: [PartyMember: SIMD2<Float>]
  ) -> [Ballistics.Target] {
    figures.filter { $0.key != member }.map {
      Ballistics.Target(id: Self.allyPrefix + $0.key.rawValue, centre: ballistics.point($0.value))
    }
  }

  /// A hostile's hit on a member: they jolt along `push`, a hit on the leader is felt, and it
  /// counts towards the encounter's retry. Each caller first decides whether its attack can
  /// still hurt anyone, since a burst or a ram hurts at most once.
  private func hurt(
    _ member: PartyMember, along push: SIMD2<Float>, at point: SIMD2<Float>,
    session: GameSession, outcome: inout Outcome
  ) {
    if simd_length_squared(push) > 0 {
      jolts[member, default: BodyJolt()].push(towards: push, by: BodyJolt.hit)
    }
    if member == session.leader { events.append(.leaderHit(at: point)) }
    if session.takeHit(member) { outcome.retry = true }
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
    let current = Set(encounter.hostiles.map(\.id))
    guard
      // Circling drones would sway the camera; it leans towards the ground's hostiles.
      let nearest = hostiles.values.filter({
        current.contains($0.spec.id) && $0.isVisible && !$0.isDown && $0.robot?.isCleared != true
          && $0.drone == nil && $0.crawler == nil
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
    // A drone's and a crawler's presentations read their own motion, falls included.
    if let drone = state.drone {
      hostileYaws[id] = Movement.yaw(towards: drone.facing)
      return
    }
    if let crawler = state.crawler {
      hostileYaws[id] = Movement.yaw(towards: crawler.facing)
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
    if let robot = hostiles[id]?.robot {
      return Ballistics.Target(
        id: id,
        centre: ballistics.point(
          hostilePoint(id), above: RobotModelGeometry.halfHeight - robot.bodyDrop),
        halfHeight: RobotModelGeometry.halfHeight, radius: RobotModelGeometry.bodyRadius)
    }
    if let drone = hostiles[id]?.drone {
      return Ballistics.Target(
        id: id, centre: drone.centre, halfHeight: ScoutDrone.halfHeight,
        radius: ScoutDrone.radius)
    }
    if let crawler = hostiles[id]?.crawler {
      return Ballistics.Target(
        id: id, centre: crawler.centre, halfHeight: Crawler.halfHeight, radius: Crawler.radius)
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
        targets: partyTargets(party)), party: party)
    shots.append(
      Shot(
        path: trace.path, side: .hostile,
        muzzle: [discharge.origin.x, discharge.origin.z], trace: trace, gun: discharge.gun))
    report(
      trace.path, firedBy: discharge.pattern == .fan ? .shotgun : .rifle, byLeader: false)
    if case .body(let id) = trace.strike, let member = PartyMember(rawValue: id),
      state.acceptRobotBurstHit()
    {
      hurt(
        member, along: [direction.x, direction.z], at: trace.path.end, session: session,
        outcome: &outcome)
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
        targets: discharge.deliberateMiss ? [] : partyTargets(party)), party: party)
    let muzzle = WeaponPose.muzzle(
      from: start, facing: enemyHandling[id]?.facing ?? discharge.direction, kind: .rifle)
    shots.append(Shot(path: trace.path, side: .hostile, muzzle: muzzle, trace: trace))
    report(trace.path, firedBy: .rifle, byLeader: false)
    hostileJolts[id, default: BodyJolt()].push(towards: -discharge.direction, by: BodyJolt.recoil)
    if case .body(let body) = trace.strike, let member = PartyMember(rawValue: body) {
      hurt(
        member, along: discharge.direction, at: trace.path.end, session: session,
        outcome: &outcome)
    }
  }

  // MARK: - Scout drones (issue #201)

  /// A scout drone circles its guard and, once that fight is engaged or the drone has been
  /// hit, dives at a member it can see, one drone at a time (docs/scout-drones.md).
  private func stepDrone(
    _ spec: Level.Hostile, state: inout HostileState, in encounter: Level.Encounter,
    party: [PartyMember: SIMD2<Float>], targets: [PartyMember: SIMD2<Float>],
    session: GameSession, dt: Float, threat: inout String?, outcome: inout Outcome
  ) {
    guard let drone = state.drone else { return }
    let guardian = encounter.hostiles.first(where: \.strategicGuard)
    let centre = guardian.flatMap { hostiles[$0.id]?.position } ?? drone.home
    let engaged =
      alertedPack.contains(spec.id)
      || guardian.map { aggressiveGuards.contains($0.id) } ?? true
    let othersAttack = encounter.hostiles.contains {
      $0.id != spec.id && hostiles[$0.id]?.drone?.isAttacking == true
    }
    // One major attack at a time: a drone starts its warning only while its guard patrols,
    // recovers or searches, never over the guard's own warning, burst or another opening.
    let guardBusy =
      guardian.flatMap { hostiles[$0.id]?.robot }.map {
        ![.patrol, .recovering, .searching].contains($0.phase)
      } ?? false
    let eye = drone.centre
    func sees(_ member: PartyMember) -> Bool {
      guard let point = party[member] else { return false }
      return simd_distance(point, drone.position) <= ScoutDrone.attackRange
        && ballistics.isClear(from: eye, to: ballistics.point(point))
    }
    // A warning stays with the member it named (#207). Out of sight, the drone keeps their
    // last-seen point; a different member is only ever targeted by a new, full warning.
    let warned = drone.phase == .warning ? droneTargets[spec.id] : nil
    let watched =
      warned
      ?? PartyMember.allCases.filter(sees).min {
        simd_distance(party[$0] ?? .zero, drone.position)
          < simd_distance(party[$1] ?? .zero, drone.position)
      }
    droneTargets[spec.id] = watched
    let seen = watched.flatMap { sees($0) ? party[$0] : nil }
    let discharge = state.stepDrone(
      dt: dt, centre: centre, target: seen,
      mayAttack: engaged && !othersAttack && !guardBusy, airspace: airspace)
    if let discharge {
      fireDrone(discharge, state: &state, party: targets, session: session, outcome: &outcome)
    }
    guard let now = state.drone else { return }
    if now.phase == .warning, drone.phase != .warning {
      events.append(.droneWarning(at: now.position))
    }
    switch now.phase {
    case .warning:
      threat =
        threat
        ?? "\(spec.name) targeting \(watched?.displayName ?? "the squad"). Move or use cover."
    case .diving:
      threat = "\(spec.name) diving. Move or use cover."
    default:
      break
    }
  }

  /// One round of a dive's burst. Cover, the dome and Laura's sword stop it as they stop
  /// the guard's rounds, and a whole burst hurts at most one member once.
  private func fireDrone(
    _ discharge: ScoutDrone.Discharge, state: inout HostileState,
    party: [PartyMember: SIMD2<Float>], session: GameSession, outcome: inout Outcome
  ) {
    var generator = enemyRandom[state.spec.id] ?? SeededRandom(seed: Self.seed)
    let deviation = Scatter.deviation(within: Spread.degrees(1.5), using: &generator)
    enemyRandom[state.spec.id] = generator
    let ray = discharge.direction
    let direction = SIMD3(
      ray.x * cos(deviation) - ray.z * sin(deviation), ray.y,
      ray.x * sin(deviation) + ray.z * cos(deviation))
    let trace = guarded(
      ballistics.traceAcrossLevel(
        from: discharge.origin, direction: direction,
        targets: partyTargets(party)), party: party)
    shots.append(
      Shot(
        path: trace.path, side: .hostile, muzzle: [discharge.origin.x, discharge.origin.z],
        trace: trace))
    report(trace.path, firedBy: .rifle, byLeader: false)
    if case .body(let id) = trace.strike, let member = PartyMember(rawValue: id),
      state.acceptDroneBurstHit()
    {
      hurt(
        member, along: [direction.x, direction.z], at: trace.path.end, session: session,
        outcome: &outcome)
    }
  }

  /// Whether standing at `point` is in a drone's way: near where a warning drone last saw its
  /// member, or near the point a diving drone has committed to. Its rounds aim there.
  func droneThreatens(_ point: SIMD2<Float>) -> Bool {
    hostiles.values.contains { state in
      guard let drone = state.drone, !state.isDown else { return false }
      return drone.aimPoint.map { simd_distance($0, point) < ScoutDrone.danger } ?? false
    }
  }

  /// Once their fight is over, a downed drone still falls to the snow and one cleared by the
  /// quiet exit keeps circling its guard; a downed crawler collapses and a cleared one walks
  /// back to its place and folds. None can attack again.
  private func settlePack(dt: Float) {
    let guardian = specs.values.first(where: \.strategicGuard).flatMap { hostiles[$0.id] }
    for id in hostiles.keys.sorted() {
      guard var state = hostiles[id] else { continue }
      if let drone = state.drone, drone.phase == .down || drone.phase == .cleared {
        _ = state.stepDrone(
          dt: dt, centre: guardian?.position ?? drone.home, target: nil, mayAttack: false,
          airspace: airspace)
        hostiles[id] = state
      } else if let crawler = state.crawler, crawler.phase == .down || crawler.phase == .cleared {
        _ = state.stepCrawler(
          dt: dt, target: nil, engaged: false, mayWindUp: false, motion: crawlerMotion,
          guardian: nil, others: [])
        hostiles[id] = state
      }
    }
  }

  /// When their guard goes down, its drones and crawlers go down with it, so the fight still
  /// ends with it. Names the kinds that were still active, for the line.
  private func dropPack(session: GameSession, from shooter: SIMD2<Float>) -> [String] {
    guard let encounter else { return [] }
    var kinds: [String] = []
    for spec in encounter.hostiles where spec.isPack {
      guard let state = hostiles[spec.id], !state.isDown else { continue }
      session.defeat(spec.id)
      knockDown(spec.id, from: shooter)
      let kind = spec.isDrone ? "drones" : "crawlers"
      if !kinds.contains(kind) { kinds.append(kind) }
    }
    return kinds.sorted()
  }

  /// A hit on a drone or crawler wakes it, and its guard, as a hit on the guard would.
  private func alertPack(_ id: String, by member: PartyMember) {
    alertedPack.insert(id)
    guard let guardian = encounter?.hostiles.first(where: \.strategicGuard) else { return }
    aggressiveGuards.insert(guardian.id)
    guardTargets[guardian.id]?.recordAttack(by: member)
  }

  /// A drone a companion under Attack can shoot now: the nearest that is diving or climbing
  /// back from a dive, with a clear line from one of the companion's guns, the gun in hand
  /// first. Circling drones are left to the player.
  func companionDrone(
    for member: PartyMember, from origin: SIMD2<Float>, figures: [PartyMember: SIMD2<Float>]
  ) -> (id: String, position: SIMD2<Float>, weapon: Weapon.Kind)? {
    guard let encounter else { return nil }
    let kinds = [weapon(of: member).kind, otherWeapon(of: member).kind].filter(\.shoots)
    return encounter.hostiles.compactMap {
      spec -> (id: String, position: SIMD2<Float>, weapon: Weapon.Kind)? in
      guard spec.isDrone, let state = hostiles[spec.id], let drone = state.drone,
        state.isVisible, !state.isDown, state.isTargetable,
        drone.phase == .diving || drone.phase == .climbing,
        let kind = kinds.first(where: {
          companionCanFireAtBody(member, from: origin, at: spec.id, weapon: $0, figures: figures)
        })
      else { return nil }
      return (spec.id, drone.position, kind)
    }.min {
      simd_distance($0.position, origin) < simd_distance($1.position, origin)
    }
  }

  // MARK: - Pack crawlers (issue #208)

  /// A pack crawler gets up once its guard's fight is engaged or it is hit, walks up to a
  /// member it senses and rams them, never over the guard's own attacks and never two on one
  /// member at once (docs/crawler-pack.md).
  private func stepCrawler(
    _ spec: Level.Hostile, state: inout HostileState, in encounter: Level.Encounter,
    party: [PartyMember: SIMD2<Float>], targets: [PartyMember: SIMD2<Float>],
    session: GameSession, dt: Float, threat: inout String?, outcome: inout Outcome
  ) {
    guard let crawler = state.crawler else { return }
    let guardian = encounter.hostiles.first(where: \.strategicGuard)
    let guardState = guardian.flatMap { hostiles[$0.id] }
    let engaged =
      alertedPack.contains(spec.id)
      || guardian.map { aggressiveGuards.contains($0.id) } ?? true
    let guardBusy =
      guardState?.robot.map { ![.patrol, .recovering, .searching].contains($0.phase) } ?? false
    // It senses over the low cover; only stone hides a member from it.
    let senses = ballistics.point(crawler.position, above: 2)
    func sees(_ member: PartyMember) -> Bool {
      guard let point = party[member] else { return false }
      return simd_distance(point, crawler.position) <= Crawler.leash
        && ballistics.isClear(from: senses, to: ballistics.point(point, above: 2))
    }
    let claimed = Set(
      encounter.hostiles.compactMap { other -> PartyMember? in
        guard other.id != spec.id, hostiles[other.id]?.crawler?.isAttacking == true else {
          return nil
        }
        return crawlerTargets[other.id]
      })
    // The named member stays with the fixed ram line through the wind-up and ram, even out
    // of sight. Between attacks it keeps a sensed member or chooses the nearest, preferring
    // one no other crawler is already ramming.
    var watched = crawlerTargets[spec.id]
    if !crawler.isAttacking {
      watched = watched.flatMap { sees($0) ? $0 : nil }
      if watched == nil {
        func cost(_ member: PartyMember) -> Float {
          simd_distance(party[member] ?? .zero, crawler.position)
            + (claimed.contains(member) ? 4 : 0)
        }
        watched = PartyMember.allCases.filter(sees).min { cost($0) < cost($1) }
      }
    }
    crawlerTargets[spec.id] = watched
    let others = encounter.hostiles.compactMap { other -> SIMD2<Float>? in
      guard other.id != spec.id, let pack = hostiles[other.id]?.crawler, !pack.isDown else {
        return nil
      }
      return pack.position
    }
    let hull = guardState.flatMap { guardState -> (centre: SIMD2<Float>, radius: Float)? in
      guard let robot = guardState.robot, guardState.isVisible, !guardState.isDown,
        !robot.isCleared
      else { return nil }
      return (guardState.position, RobotModelGeometry.bodyRadius)
    }
    let before = crawler.phase
    if let ram = state.stepCrawler(
      dt: dt, target: watched.flatMap { party[$0] }, engaged: engaged,
      mayWindUp: engaged && !guardBusy && !(watched.map(claimed.contains) ?? false),
      motion: crawlerMotion, guardian: hull, others: others)
    {
      resolveRam(ram, state: &state, party: targets, session: session, outcome: &outcome)
    }
    guard let now = state.crawler else { return }
    // Only a wind-up on the leader is heard: the light shows every one.
    if now.phase == .windingUp, before != .windingUp, watched == session.leader {
      events.append(.crawlerWarning(at: now.position))
    }
    switch now.phase {
    case .windingUp:
      threat =
        threat ?? "\(spec.name) winding up on \(watched?.displayName ?? "the squad"). Step aside."
    case .ramming:
      threat = threat ?? "\(spec.name) ramming. Step aside."
    default:
      break
    }
  }

  /// A ram's sweep in this step hits the first member in its way, once per ram. Tom's raised
  /// dome shelters whoever is inside it from a crawler that started outside.
  private func resolveRam(
    _ ram: Crawler.Ram, state: inout HostileState, party: [PartyMember: SIMD2<Float>],
    session: GameSession, outcome: inout Outcome
  ) {
    guard
      let struck = party.filter({ Crawler.runsInto($0.value, along: ram) }).min(by: {
        simd_distance($0.value, ram.from) < simd_distance($1.value, ram.from)
          || simd_distance($0.value, ram.from) == simd_distance($1.value, ram.from)
            && $0.key.rawValue < $1.key.rawValue
      }),
      state.acceptRamHit()
    else { return }
    if shieldIsUp, let tom = party[.tom], simd_distance(struck.value, tom) <= ShieldDome.radius,
      simd_distance(ram.origin, tom) > ShieldDome.radius
    {
      events.append(.struckBlock(at: struck.value))
      return
    }
    let direction = ram.to - ram.from
    events.append(.struckBody(at: struck.value))
    hurt(
      struck.key, along: simd_length(direction) > 0.0001 ? simd_normalize(direction) : .zero,
      at: struck.value, session: session, outcome: &outcome)
  }

  /// Whether standing at `point` is in a crawler's way: near the fixed line of one winding up
  /// or ramming.
  func crawlerThreatens(_ point: SIMD2<Float>, margin: Float = 0.25) -> Bool {
    hostiles.values.contains {
      !$0.isDown && $0.crawler?.threatens(point, margin: margin) == true
    }
  }

  /// Whether walking straight from `start` to `end` passes through a crawler's ram line.
  func crawlerThreatens(from start: SIMD2<Float>, to end: SIMD2<Float>) -> Bool {
    let steps = max(1, Int((simd_distance(start, end) / 0.25).rounded(.up)))
    return (0...steps).contains {
      crawlerThreatens(start + (end - start) * (Float($0) / Float(steps)))
    }
  }

  /// Where a companion at `point` steps aside to from every crawler's ram line, among places
  /// `isFree` allows (issue #208). It stays put if it is already clear, and keeps an earlier
  /// choice that is still clear so it doesn't waver. Otherwise it takes the nearest place well
  /// clear, so that it is still moving briskly as it leaves the line.
  func crawlerAside(
    from point: SIMD2<Float>, keeping earlier: SIMD2<Float>? = nil,
    isFree: (SIMD2<Float>) -> Bool
  ) -> SIMD2<Float>? {
    for kept in [point] + (earlier.map { [$0] } ?? [])
    where !crawlerThreatens(kept, margin: 0.45) && isFree(kept) {
      return kept
    }
    let rings: [Float] = [1.25, 1.75, 2.5, 3]
    let around = rings.flatMap { radius in
      (0..<12).map { index in
        let angle = Float(index) * .pi / 6
        return point + SIMD2(cos(angle), sin(angle)) * radius
      }
    }
    return around.first { !crawlerThreatens($0, margin: 0.75) && isFree($0) }
  }

  /// A crawler a companion under Attack can shoot now: the nearest that is winding up,
  /// ramming, recovering or within 6 m, with a clear line from one of the companion's guns,
  /// the gun in hand first.
  func companionCrawler(
    for member: PartyMember, from origin: SIMD2<Float>, figures: [PartyMember: SIMD2<Float>]
  ) -> (id: String, position: SIMD2<Float>, weapon: Weapon.Kind)? {
    guard let encounter else { return nil }
    let kinds = [weapon(of: member).kind, otherWeapon(of: member).kind].filter(\.shoots)
    return encounter.hostiles.compactMap {
      spec -> (id: String, position: SIMD2<Float>, weapon: Weapon.Kind)? in
      guard spec.isCrawler, let state = hostiles[spec.id], let crawler = state.crawler,
        state.isVisible, !state.isDown, state.isTargetable, crawler.phase != .folded,
        crawler.isAttacking || crawler.phase == .recovering
          || simd_distance(crawler.position, origin) <= 6,
        let kind = kinds.first(where: {
          companionCanFireAtBody(member, from: origin, at: spec.id, weapon: $0, figures: figures)
        })
      else { return nil }
      return (spec.id, crawler.position, kind)
    }.min {
      simd_distance($0.position, origin) < simd_distance($1.position, origin)
    }
  }

  // MARK: - Paired weapons (ADR 0021)

  /// How wide Laura's swing reaches round her facing, and from how far round it her sword turns
  /// a shot.
  static let swingArc: Float = 110 * .pi / 180
  static let blockArc: Float = 120 * .pi / 180
  /// How far round the guard from a leg a sword still reaches it: the least cosine between
  /// the ways from the guard's centre to the swinger and to the leg.
  static let swordSide: Float = 0.55

  /// Whether a sword swung from `origin` reaches this leg of the guard standing at `centre`:
  /// from outside its hull, on the leg's side, within reach and past nothing solid. The swing
  /// adds its arc, and a companion's plan adds a lane clear of the others.
  private func swordReaches(
    _ point: GuardWeakpoint, of centre: SIMD2<Float>, from origin: SIMD2<Float>, reach: Float
  ) -> Bool {
    let radial = origin - centre
    let side = point.ground - centre
    return simd_length(radial) >= GuardCollision.pawnClearance
      && simd_length(side) > 0.001
      && simd_dot(simd_normalize(radial), simd_normalize(side)) >= Self.swordSide
      && simd_distance(origin, point.ground) <= reach + point.radius
      && ballistics.isClear(from: ballistics.point(origin), to: point.centre)
  }

  /// The weapon switch: the member's other weapon comes into hand, drawn if this one was, after
  /// its own draw time. The one put away keeps its magazine, and any reload goes on.
  func swapWeapon(for member: PartyMember) {
    let current = slot(of: member)
    let wasDrawn = handling[current]?.isDrawn == true
    handling[current]?.holster()
    selected[member] = (current.index + 1) % Weapon.pair(for: member).count
    weaponPoses[member] = WeaponPose(kind: weapon(of: member).kind)
    if member == weaponLeader {
      shield.drop()
    }
    spin[member] = 0
    if wasDrawn { handling[slot(of: member)]?.draw() }
  }

  /// Laura's swing: it strikes every hostile who is a target, within the sword's reach of their
  /// body and inside the swing's arc in front of her, for the sword's hits. Without the stick or
  /// a lock, Fire turns her towards the nearest target close by, as it turns a gun.
  private func swing(
    by member: PartyMember, from origin: SIMD2<Float>, facing: SIMD2<Float>, aiming: Bool,
    inFight: Bool,
    session: GameSession, outcome: inout Outcome
  ) {
    let weapon = weapon(of: member)
    let reach = weapon.range
    // A drone is out of a sword's reach until it comes down for its low pass.
    let targets = hostiles.values.filter {
      $0.isVisible && !$0.isDown && $0.isTargetable && $0.drone?.isLow != false
    }
    if member == session.leader, !aiming, lock == nil,
      let nearest = targets.min(by: {
        simd_distance($0.position, origin) < simd_distance($1.position, origin)
      }),
      simd_distance(nearest.position, origin) <= reach + bodyRadius(nearest.spec.id) + 1.5,
      simd_distance(nearest.position, origin) > 0.001
    {
      outcome.facing = simd_normalize(nearest.position - origin)
    }
    guard handling[slot(of: member)]?.isReady == true else { return }
    handling[slot(of: member)]?.fired()
    weaponPoses[member]?.fired()
    events.append(.fired(.energySword, at: origin, byLeader: member == session.leader))
    for target in targets {
      if guardStrategies[target.spec.id] != nil {
        // Prefer a real reached component, with a body contact as the ordinary-damage
        // fallback. One swing can damage this enemy only once.
        var contact: GuardWeakpoint?
        let legs = weakpoints(for: target.spec.id).filter {
          if case .leg = $0.part { return true }
          return false
        }.sorted {
          simd_distance_squared($0.ground, origin) < simd_distance_squared($1.ground, origin)
        }
        for point in legs {
          let offset = point.ground - origin
          let distance = simd_length(offset)
          guard distance < 0.001 || simd_dot(offset / distance, facing) >= cos(Self.swingArc / 2),
            swordReaches(point, of: target.position, from: origin, reach: reach)
          else { continue }
          contact = point
          break
        }
        if let point = contact {
          events.append(.struckBody(at: point.ground))
          if inFight {
            hit(
              point.id, by: member, weapon: weapon.kind, from: origin, damage: weapon.damage,
              session: session, outcome: &outcome, impact: point.centre)
          }
          continue
        }
      }
      let offset = target.position - origin
      let distance = simd_length(offset)
      let radius = target.robot == nil ? bodyRadius(target.spec.id) : RobotModelGeometry.bodyRadius
      if target.robot != nil, distance < GuardCollision.pawnClearance {
        continue
      }
      guard distance <= reach + radius,
        distance < 0.001 || simd_dot(offset / distance, facing) >= cos(Self.swingArc / 2),
        ballistics.isClear(from: ballistics.point(origin), to: ballistics.point(target.position))
      else { continue }
      events.append(.struckBody(at: target.position))
      if inFight {
        hit(
          target.spec.id, by: member, weapon: weapon.kind, from: origin, damage: weapon.damage,
          session: session, outcome: &outcome)
      }
    }
  }

  /// How far a hostile's body reaches from its centre: the robot's legs, or a person.
  private func bodyRadius(_ id: String) -> Float {
    if hostiles[id]?.drone != nil { return ScoutDrone.radius }
    if hostiles[id]?.crawler != nil { return Crawler.radius }
    return hostiles[id]?.robot != nil ? RobotModelGeometry.navigationRadius : Aim.bodyRadius
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
    let swordFacing = member == weaponLeader ? leaderFacing : memberFacings[member] ?? .zero
    if member == .laura, weapon(of: member).kind == .energySword,
      handling[slot(of: member)]?.isDrawn == true,
      member == weaponLeader || autonomousMembers.contains(member),
      simd_length(from) > 0.001,
      simd_dot(simd_normalize(from), swordFacing) >= cos(Self.blockArc / 2)
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
    selectLock(from: leader, facing: facing, up: up, right: right, advancing: true)
    lockPressAge = 0
  }

  /// Explicit accessibility commands acquire or cycle without the controller's quick-second
  /// press gesture. Acquire keeps a valid current lock; Next advances it deliberately.
  func selectLock(
    from leader: SIMD2<Float>, facing: SIMD2<Float>, up: SIMD2<Float>, right: SIMD2<Float>,
    advancing: Bool
  ) {
    keepLock(from: leader)
    lockPressAge = nil
    guard advancing || lock == nil else { return }
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

  /// A tap chooses one native lock candidate by its projected body, rather than a component.
  /// Empty ground clears an entirely offscreen lock, so touch can let go without chasing it.
  /// A visible body's lock stays until that body, or another eligible enemy, is tapped.
  func tapLock(
    at point: SIMD2<Float>, viewHeight: Float, projection: CameraProjection,
    from leader: SIMD2<Float>
  ) {
    keepLock(from: leader)
    guard point.x.isFinite, point.y.isFinite, (0...1).contains(point.x),
      (0...1).contains(point.y), viewHeight.isFinite, viewHeight > 0,
      (projection.aspect * viewHeight).isFinite, projection.aspect * viewHeight > 0,
      projection.screen(ofWorld: projection.target) != nil
    else { return }
    guard
      let selected = Targeting.touched(
        at: point, viewHeight: viewHeight, projection: projection,
        candidates: lockable(from: leader),
        height: { self.touchHeight(of: $0) }, radius: { self.touchRadius(of: $0) })
    else {
      if let lock, hostiles[lock] != nil,
        !Targeting.bodyIsOnScreen(
          at: hostilePoint(lock), height: touchHeight(of: lock), radius: touchRadius(of: lock),
          projection: projection)
      {
        releaseLock()
      }
      return
    }
    lockPressAge = nil
    lock = selected == lock ? nil : selected
  }

  /// How tall a hostile's tap target stands: a person, the robot, or a drone's whole column
  /// from its shadow to its body, so a tap on either takes it.
  private func touchHeight(of id: String) -> Float {
    if let drone = hostiles[id]?.drone { return drone.height + ScoutDrone.halfHeight + 0.2 }
    if hostiles[id]?.crawler != nil { return Crawler.centreHeight + Crawler.halfHeight + 0.2 }
    return hostiles[id]?.robot == nil ? PartyBody.height : RobotModelGeometry.halfHeight * 2
  }

  private func touchRadius(of id: String) -> Float {
    if hostiles[id]?.drone != nil { return ScoutDrone.radius + 0.15 }
    if hostiles[id]?.crawler != nil { return Crawler.radius + 0.2 }
    return hostiles[id]?.robot == nil ? Aim.bodyRadius : RobotModelGeometry.navigationRadius
  }

  /// Lets go of the lock, as a quick second controller press or an explicit touch command does.
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
