import Foundation
import Observation
import RealityKit
import simd

#if DEBUG
  import UIKit
#endif

@MainActor
@Observable
final class GameWorld {
  /// Party movement advances in whole steps of this length inside the scene update.
  static let simulationStep: Float = 1 / 120

  let level: Level
  let root = Entity()
  let controls = GameControls()
  let session: GameSession
  private(set) var nearbyName: String?
  private(set) var observation: String
  private(set) var diagnostic: String?
  /// The leader's contextual action here, such as "Reach latch"; nil when there is none.
  private(set) var actionName: String?
  /// Role feedback, such as which member could act here.
  private(set) var hint: String?
  /// A hostile winding up a shot, such as "The stranger is aiming."
  private(set) var threat: String?
  /// Whether the leader's weapon is drawn.
  private(set) var weaponDrawn = false
  /// How dark the screen is while an encounter starts again, from 0 to 1.
  private(set) var fade: Float = 0

  @ObservationIgnored private var bodies: [PartyMember: Entity] = [:]
  @ObservationIgnored private var visuals: [PartyMember: Entity] = [:]
  @ObservationIgnored private var markers: [PartyMember: Entity] = [:]
  @ObservationIgnored private let camera = PerspectiveCamera()
  // Movement and routes follow the session's passage flag; the world keeps no copy of it.
  @ObservationIgnored private let closedMotion: PartyMotion
  @ObservationIgnored private let openMotion: PartyMotion
  @ObservationIgnored private let closedGrid: NavigationGrid
  @ObservationIgnored private let openGrid: NavigationGrid
  // Scene parts that show the session's progress. They hold no progress of their own.
  @ObservationIgnored private var barrierParts: [Entity] = []
  @ObservationIgnored private var regulatorPart: Entity?
  @ObservationIgnored private var installedRegulator: Entity?
  @ObservationIgnored private var faultLight: Entity?
  @ObservationIgnored private var readyLight: Entity?
  @ObservationIgnored private var route: RouteMemory
  @ObservationIgnored private var planner: SquadPlanner
  @ObservationIgnored private var motors: [PartyMember: CompanionMotor]
  @ObservationIgnored private var squadLeader: PartyMember
  @ObservationIgnored private var yaw: [PartyMember: Float] = [:]
  /// Where each companion is heading in the latest step. Tests read it.
  @ObservationIgnored private(set) var companionTargets: [PartyMember: SIMD2<Float>] = [:]
  #if DEBUG
    /// A scripted Simulator playtest (`scripts/playtest`), started by the launch argument
    /// `-LauderPlaytest <scenario>`. Debug builds only.
    @ObservationIgnored private(set) var playtest: PlaytestRunner?
    @ObservationIgnored private var targetMarkers: [PartyMember: Entity] = [:]
  #endif
  @ObservationIgnored private var subscription: EventSubscription?
  @ObservationIgnored private var isPresented = false
  @ObservationIgnored private var isApplicationActive = false
  @ObservationIgnored private var skipNextStep = true
  @ObservationIgnored private var wasRunning = false
  @ObservationIgnored private var nearby: Level.PointOfInterest?
  @ObservationIgnored private var cameraTarget: SIMD3<Float>
  @ObservationIgnored private var cameraStart: SIMD3<Float>?
  @ObservationIgnored private var cameraElapsed: Float = 0
  @ObservationIgnored private var unsimulatedTime: Float = 0
  // The level's fights (ADR 0004, M2).
  @ObservationIgnored private let stage: EncounterStage
  @ObservationIgnored private var fireHeld = false
  @ObservationIgnored private var firePressPending = false
  /// Where the current encounter's retry places the leader.
  @ObservationIgnored private var retrySpot: SIMD2<Float>?
  /// Time into an encounter's retry: the fade out, the reset, the fade back in.
  @ObservationIgnored private var retryElapsed: Float?
  /// How far the camera's target leans from the leader towards a fight, eased.
  @ObservationIgnored private var cameraLean: SIMD2<Float> = .zero

  static let retryFadeOut: Float = 0.6
  static let retryFadeIn: Float = 0.4
  /// How quickly the camera's lean follows a fight: about 95% of the way in a second.
  static let cameraLeanRate: Float = 3

  var isPaused: Bool { session.isPaused }
  /// Whether the weapon's controls show: during a fight, or while the weapon is drawn.
  var showsWeapon: Bool { session.inEncounter || weaponDrawn }
  /// Whether an encounter's retry is under way.
  var isRetrying: Bool { retryElapsed != nil }
  /// The HUD's objective: the level's own, or Party C's mission at Relay House.
  var objective: String { level.objective ?? MissionScript.objective(session.phase) }

  private var motion: PartyMotion { session.passageOpen ? openMotion : closedMotion }
  private var grid: NavigationGrid { session.passageOpen ? openGrid : closedGrid }

  /// The bridge, unless a Debug launch argument picks a playtest's level or `-LauderLevel`.
  init(level: Level? = nil) {
    let level = level ?? Self.launchLevel
    self.level = level
    session = GameSession(level: level)
    observation = level.opening
    closedMotion = PartyMotion(
      radius: PartyBody.radius, obstacles: level.obstacles(passageOpen: false))
    openMotion = PartyMotion(
      radius: PartyBody.radius, obstacles: level.obstacles(passageOpen: true))
    // Build the route grids while loading, not on the first frame of play or the frame the
    // passage opens.
    closedGrid = NavigationGrid(level: level, passageOpen: false)
    openGrid = level.passage == nil ? closedGrid : NavigationGrid(level: level, passageOpen: true)
    squadLeader = level.party[0]
    route = RouteMemory(start: level.spawn(level.party[0]))
    planner = SquadPlanner(heading: level.heading)
    motors = Self.freshMotors()
    cameraTarget = Self.startingCameraTarget(level)
    let style = SceneStyle()
    stage = EncounterStage(level: level, style: style)
    root.name = level.id.rawValue
    for box in [level.ground] + level.boxes {
      let entity: Entity =
        box.surface == .vehicle
        ? style.vehicle(size: box.size, at: box.position)
        : style.block(size: box.size, at: box.position, material: style.material(for: box.surface))
      entity.name = box.name
      root.addChild(entity)
    }
    for point in level.points {
      let entity = style.landmark(for: point)
      entity.name = point.id
      root.addChild(entity)
    }
    // Every action the session can refer to here must be defined exactly once, checked at load.
    for interaction in level.interactions {
      precondition(
        level.interactions.filter { $0.id == interaction.id }.count == 1,
        "\(level.id.rawValue) defines \(interaction.id.rawValue) more than once.")
    }
    if level.id == .relayHouse {
      addRelayHouseParts(style: style)
    }
    root.addChild(stage.container)
    SceneDressing.add(to: root, style: style, level: level)
    style.addLighting(to: root)
    camera.camera.fieldOfViewInDegrees = level.fieldOfView
    camera.name = "camera"
    root.addChild(camera)
    for member in PartyMember.allCases {
      let body = Entity()
      body.name = "party.\(member.rawValue)"
      let visual = style.partyMember(member)
      body.addChild(visual)
      let marker = ModelEntity(
        mesh: .generateCylinder(height: 0.015, radius: 0.34), materials: [style.warm])
      marker.position.y = -PartyBody.height / 2 + 0.025
      body.addChild(marker)
      bodies[member] = body
      visuals[member] = visual
      markers[member] = marker
      root.addChild(body)
    }
    // Miki carries the carbine; it shows while drawn.
    visuals[.miki]?.addChild(stage.weaponProp)
    placeParty()
    showProgress()
    updateCamera(deltaTime: 0)
    updateNearby()
    #if DEBUG
      if let scenario = UserDefaults.standard.string(forKey: "LauderPlaytest") {
        startPlaytest(scenario, style: style)
      }
    #endif
  }

  private static var launchLevel: Level {
    #if DEBUG
      let defaults = UserDefaults.standard
      if let scenario = defaults.string(forKey: "LauderPlaytest") {
        return Level.level(PlaytestRunner.level(for: scenario))
      }
      if let name = defaults.string(forKey: "LauderLevel"), let id = Level.ID(rawValue: name) {
        return Level.level(id)
      }
    #endif
    return BrooklynBridge.level
  }

  private static func startingCameraTarget(_ level: Level) -> SIMD3<Float> {
    let start = level.spawn(level.party[0])
    return [start.x, PartyBody.height / 2 + 0.1, start.y]
  }

  func attach(_ subscription: EventSubscription) {
    self.subscription?.cancel()
    self.subscription = subscription
    isPresented = true
    updateActivity()
  }

  func setApplicationActive(_ active: Bool) {
    guard active != isApplicationActive else { return }
    isApplicationActive = active
    updateActivity()
  }

  func stop() {
    isPresented = false
    subscription?.cancel()
    subscription = nil
    updateActivity()
  }

  // The next active step observes the preceding collision-checked body positions.
  func step(deltaTime: TimeInterval) {
    MainActor.preconditionIsolated()
    guard isPresented, isApplicationActive else { return }
    #if DEBUG
      if playtest != nil {
        playtest?.tick(dt: Float(deltaTime))
        controls.scriptedRaw = playtest?.input(playtestSnapshot)
      }
    #endif
    let mode = session.mode
    let input = controls.sample(mode: mode)
    update(
      with: input, sampledIn: mode, deltaTime: Float(deltaTime),
      inputReady: controls.status == .ready)
  }

  /// One frame after sampling: the command the input means in the mode it was sampled in, then
  /// party movement while exploring, then the leader's action. Headless tests call it directly.
  func update(
    with input: InputRules.Input, sampledIn mode: GameSession.Mode, deltaTime: Float,
    inputReady: Bool = true
  ) {
    respond(to: input, in: mode)
    if retryElapsed != nil {
      // An encounter is starting again; Pause holds the fade where it is.
      if session.mode == .exploring { advanceRetry(deltaTime: deltaTime) }
      return
    }
    let running = session.mode == .exploring && inputReady && !controls.needsNeutralInput
    if running != wasRunning {
      wasRunning = running
      skipNextStep = true
    }
    guard running else { return }
    guard !skipNextStep else {
      // Time owed from before an interruption is not replayed afterwards.
      skipNextStep = false
      unsimulatedTime = 0
      return
    }
    #if DEBUG
      let started = DispatchTime.now().uptimeNanoseconds
    #endif
    advanceParty(
      movement: input.movement, fireHeld: input.fireHeld, firePressed: input.firePressed,
      deltaTime: deltaTime)
    #if DEBUG
      recordPlaytest(
        dt: deltaTime,
        milliseconds: Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000)
    #endif
    if mode == .exploring, input.actionPressed { performAction() }
  }

  /// Dialogue and Pause controls stay distinct from world actions: in those modes the action
  /// press shows the next line or confirms the pause menu's choice, and nothing else.
  private func respond(to input: InputRules.Input, in mode: GameSession.Mode) {
    switch mode {
    case .paused:
      if input.pausePressed {
        togglePause()
      } else if input.restartPressed {
        restart()
      } else if input.actionPressed {
        if session.pauseChoice == .restart { restart() } else { togglePause() }
      } else if input.menuMove != 0 {
        session.movePauseChoice(by: input.menuMove)
      }
    case .dialogue:
      if input.pausePressed {
        togglePause()
      } else if input.actionPressed {
        session.advanceDialogue()
        // A finished conversation's step has just taken effect.
        if session.mode != .dialogue {
          showProgress()
          updateNearby()
        }
      }
    case .exploring:
      if input.pausePressed {
        togglePause()
      } else if input.switchPressed, session.nextLeader != nil {
        session.cycleLeader()
        cameraStart = cameraTarget
        cameraElapsed = 0
        showLeaderMarker()
        updateNearby()
      }
    }
  }

  private func togglePause() {
    session.togglePause()
    controls.requireNeutralInput()
  }

  /// The leader's action press. Identity, approach and progress are checked afresh, so a
  /// prompt left over from before a move or a switch cannot act.
  func performAction() {
    guard session.mode == .exploring, !stage.holdsLeader, let body = bodies[session.leader] else {
      return
    }
    let position = SIMD2(body.position.x, body.position.z)
    let here = level.interactions.filter { $0.approach.contains(position) }
    // Several actions can share an approach; the one offered now comes first.
    if let interaction = here.first(where: { session.offers($0.id) }) ?? here.first {
      switch session.perform(interaction.id, by: session.leader) {
      case .done:
        observation = interaction.result
        showProgress()
        // An action can begin a scene, as the search begins the ambush (ADR 0004, M3).
        if let encounter = level.encounters.first(where: {
          if case .action(let action) = $0.start { action == interaction.id } else { false }
        }) {
          stage.begin(encounter)
          retrySpot = encounter.retryAt
        }
      case .alreadyDone:
        observation = interaction.repeated
      case .notYet:
        observation = interaction.early
      case .notEligible:
        observation = feedback(for: interaction)
      case .missingPart:
        observation = MissionScript.missingPart
      case .unavailable:
        break
      }
      updateNearby()
      return
    }
    observation =
      nearby?.observation(at: session.phase)
      ?? level.lookAround
      ?? MissionScript.guidance(session.phase, passageOpen: session.passageOpen)
  }

  /// The in-place Restart: the same scene, bodies and update subscription, returned to the
  /// beginning of a run. Nothing is rebuilt or reloaded.
  func restart() {
    session.restart()
    stage.reset()
    retryElapsed = nil
    retrySpot = nil
    fade = 0
    threat = nil
    weaponDrawn = false
    fireHeld = false
    firePressPending = false
    placeParty()
    squadLeader = session.leader
    route = RouteMemory(start: level.spawn(session.leader))
    planner = SquadPlanner(heading: level.heading)
    motors = Self.freshMotors()
    companionTargets = [:]
    diagnostic = nil
    cameraStart = nil
    cameraElapsed = 0
    cameraLean = .zero
    cameraTarget = Self.startingCameraTarget(level)
    unsimulatedTime = 0
    skipNextStep = true
    showProgress()
    observation = level.opening
    nearby = nil
    nearbyName = nil
    updateCamera(deltaTime: 0)
    updateNearby()
    // Like Resume, the new run waits for every button, key and finger to be released.
    controls.requireNeutralInput()
  }

  /// Every body at its spawn point, facing the level's starting direction. Members who have
  /// not joined yet stay hidden and out of the squad.
  private func placeParty() {
    let facing = atan2(-level.heading.x, -level.heading.y)
    for member in PartyMember.allCases {
      place(member, at: level.spawn(member))
      setYaw(member, facing)
      bodies[member]?.isEnabled = session.party.contains(member)
    }
    showLeaderMarker()
  }

  // Production spatial update, also exercised by deterministic route/soak tests.
  // Input availability, Pause and fresh-edge handling remain in step/InputRules.
  func advanceParty(
    movement: SIMD2<Float>, fireHeld: Bool = false, firePressed: Bool = false, deltaTime: Float
  ) {
    guard session.mode == .exploring, deltaTime.isFinite, deltaTime > 0 else { return }
    self.fireHeld = fireHeld
    if firePressed { firePressPending = true }
    let elapsed = min(deltaTime, 1 / 30)
    // Equal steps keep party movement independent of the display's frame times (#28). The
    // remainder, always under one step, carries to the next frame. A retry stops the rest.
    unsimulatedTime += elapsed
    while unsimulatedTime >= Self.simulationStep, retryElapsed == nil {
      unsimulatedTime -= Self.simulationStep
      simulateStep(movement: movement, dt: Self.simulationStep)
    }
    updateCamera(deltaTime: elapsed)
    updateNearby()
    checkTriggers()
  }

  private func simulateStep(movement: SIMD2<Float>, dt: Float) {
    if squadLeader != session.leader { changeLeader() }
    let leader = session.leader
    guard let leaderBody = bodies[leader] else { return }
    let motion = self.motion
    let grid = self.grid
    // A scripted scene holds the leader where they stand.
    let movement = stage.holdsLeader ? .zero : movement
    let direction = Movement.direction(for: movement, cameraOffset: level.cameraOffset)
    let leaderDelta = SIMD2(direction.x, direction.z) * PartyBody.speed * dt
    let leaderStart = SIMD2(leaderBody.position.x, leaderBody.position.z)
    let leaderEnd = motion.resolve(start: leaderStart, delta: leaderDelta)
    place(leader, at: leaderEnd)
    if simd_length_squared(leaderDelta) > 0.000001 {
      setYaw(leader, atan2(-leaderDelta.x, -leaderDelta.y))
    }
    let leaderVelocity = (leaderEnd - leaderStart) / dt
    route.record(leaderEnd)
    if !level.encounters.isEmpty {
      stepEncounter(leader: leader, at: leaderEnd, dt: dt)
      if retryElapsed != nil { return }
    }

    // Companions choose their own routes to formation slots (ADR 0003); every movement is
    // still resolved against the authored footprints.
    let current = positions
    let isClear: (SIMD2<Float>, SIMD2<Float>) -> Bool = { from, to in
      motion.canTraverse(from: from, to: to)
    }
    // Companions keep clear of the spots where a specialist must stand while that action is
    // offered, such as Relay House's latch and panel.
    let keepClear = level.interactions
      .filter { $0.keepClear && session.offers($0.id) }.map(\.approach)
    let targets = planner.targets(
      for: SquadPlanner.Input(
        leader: leader, leaderPosition: leaderEnd, leaderVelocity: leaderVelocity,
        positions: current, route: route, dt: dt),
      grid: grid, isClear: isClear,
      avoid: { point in keepClear.contains { $0.contains(point) } })
    companionTargets = targets
    for member in session.party where member != leader {
      guard let start = current[member], let target = targets[member],
        var motor = motors[member]
      else { continue }
      let context = CompanionMotor.Context(
        target: target, leaderPosition: leaderEnd, leaderVelocity: leaderVelocity,
        others: current.compactMap { $0.key == member ? nil : $0.value },
        speed: PartyBody.speed, dt: dt)
      let delta = motor.step(from: start, context: context, grid: grid, isClear: isClear)
      let end = motion.resolve(start: start, delta: delta)
      motor.absorb(end - start, dt: dt)
      motors[member] = motor
      place(member, at: end)
      turn(member, moved: end - start, dt: dt)
    }
    let stuck = session.party.first { $0 != leader && motors[$0]?.cannotReach == true }
    let message = stuck.map { "\($0.displayName) can't reach you" }
    if diagnostic != message { diagnostic = message }
  }

  /// A trigger area shows its line the first time the leader walks into it in a run, and an
  /// encounter's area begins its fight once its beat is next.
  private func checkTriggers() {
    guard retryElapsed == nil, let body = bodies[session.leader] else { return }
    let position = SIMD2(body.position.x, body.position.z)
    for trigger in level.triggers where trigger.area.contains(position) {
      if session.fire(trigger.id) { observation = trigger.line }
    }
    for encounter in level.encounters {
      guard case .area(let area) = encounter.start, area.contains(position) else { continue }
      if session.beginEncounter(encounter.beat) {
        stage.begin(encounter)
        retrySpot = encounter.retryAt
      }
    }
  }

  // MARK: - Fights

  /// One step of the fight: the stage plays the encounter and fires the leader's weapon; the
  /// world turns the leader, shows lines and the threat, and starts a retry after the last hit.
  /// Only Miki carries the carbine, and not while a scene holds her.
  private func stepEncounter(leader: PartyMember, at position: SIMD2<Float>, dt: Float) {
    let angle = yaw[leader] ?? 0
    let armed = leader == .miki && !stage.holdsLeader
    let figures = Dictionary(
      uniqueKeysWithValues: PartyMember.allCases.compactMap { member in
        bodies[member].flatMap {
          $0.isEnabled ? (member, SIMD2($0.position.x, $0.position.z)) : nil
        }
      })
    let outcome = stage.step(
      dt: dt, leader: position, facing: SIMD2(-sin(angle), -cos(angle)),
      fireHeld: armed && fireHeld, firePressed: armed && firePressPending, figures: figures,
      session: session)
    firePressPending = false
    if let facing = outcome.facing { setYaw(leader, atan2(-facing.x, -facing.y)) }
    if let line = outcome.line { observation = line }
    for member in outcome.appeared { appear(member) }
    if let shooter = outcome.shooter {
      setYaw(shooter.member, atan2(-shooter.facing.x, -shooter.facing.y))
    }
    if let member = outcome.face { faceEachOther(leader, member) }
    let threat = stage.threat
    if self.threat != threat { self.threat = threat }
    if weaponDrawn != stage.isDrawn { weaponDrawn = stage.isDrawn }
    if outcome.retry { retryElapsed = 0 }
  }

  /// A member who has not joined appears where they wait, turned towards the nearest hostile
  /// in the open, or else towards the leader.
  private func appear(_ member: PartyMember) {
    guard let body = bodies[member] else { return }
    body.isEnabled = true
    let here = SIMD2(body.position.x, body.position.z)
    let standing = stage.hostiles.values.filter { $0.isVisible && !$0.isDown }.map(\.position)
    let leaderPosition = bodies[session.leader].map { SIMD2($0.position.x, $0.position.z) }
    let focus =
      standing.min { simd_distance_squared($0, here) < simd_distance_squared($1, here) }
      ?? leaderPosition
    if let focus, simd_distance(focus, here) > 0.01 {
      let offset = focus - here
      setYaw(member, atan2(-offset.x, -offset.y))
    }
  }

  /// Two members turn to face each other, as before a conversation.
  private func faceEachOther(_ first: PartyMember, _ second: PartyMember) {
    guard first != second, let a = bodies[first], let b = bodies[second] else { return }
    let offset = SIMD2(b.position.x - a.position.x, b.position.z - a.position.z)
    guard simd_length(offset) > 0.01 else { return }
    setYaw(first, atan2(-offset.x, -offset.y))
    setYaw(second, atan2(offset.x, offset.y))
  }

  /// The encounter starts again after the leader's last allowed hit: the screen fades out,
  /// the fight is put back as it began with the leader just outside its area, and the screen
  /// fades back in. Like Resume, play then waits for every control to be released.
  private func advanceRetry(deltaTime: Float) {
    guard let before = retryElapsed, deltaTime.isFinite, deltaTime > 0 else { return }
    let elapsed = before + min(deltaTime, 1 / 30)
    if before < Self.retryFadeOut, elapsed >= Self.retryFadeOut { performRetry() }
    guard elapsed < Self.retryFadeOut + Self.retryFadeIn else {
      retryElapsed = nil
      fade = 0
      skipNextStep = true
      controls.requireNeutralInput()
      return
    }
    retryElapsed = elapsed
    fade =
      elapsed < Self.retryFadeOut
      ? elapsed / Self.retryFadeOut : 1 - (elapsed - Self.retryFadeOut) / Self.retryFadeIn
  }

  private func performRetry() {
    session.retryEncounter()
    stage.reset()
    threat = nil
    weaponDrawn = false
    fireHeld = false
    firePressPending = false
    let leader = session.leader
    let spot = retrySpot ?? level.spawn(leader)
    place(leader, at: spot)
    setYaw(leader, atan2(-level.heading.x, -level.heading.y))
    squadLeader = leader
    route = RouteMemory(start: spot)
    planner = SquadPlanner(heading: level.heading)
    motors = Self.freshMotors()
    companionTargets = [:]
    unsimulatedTime = 0
    cameraStart = nil
    cameraLean = .zero
    cameraTarget = [spot.x, PartyBody.height / 2 + 0.1, spot.y]
    updateCamera(deltaTime: 0)
    updateNearby()
    observation = "Try again."
  }

  private func changeLeader() {
    let previous = squadLeader
    let leader = session.leader
    squadLeader = leader
    if let body = bodies[leader] { route.reset(to: SIMD2(body.position.x, body.position.z)) }
    planner.reset()
    for member in [previous, leader] {
      motors[member] = CompanionMotor(reactionDelay: CompanionMotor.reactionDelay(for: member))
    }
    showLeaderMarker()
  }

  private func showLeaderMarker() {
    for member in PartyMember.allCases {
      markers[member]?.isEnabled = member == session.leader
    }
  }

  private func place(_ member: PartyMember, at point: SIMD2<Float>) {
    bodies[member]?.position = [point.x, PartyBody.height / 2, point.y]
  }

  /// Companions turn towards their movement, or to the formation's heading once settled, at a
  /// limited rate so they never snap round.
  private func turn(_ member: PartyMember, moved delta: SIMD2<Float>, dt: Float) {
    let wanted: Float
    if simd_length(delta) > 0.2 * dt {
      wanted = atan2(-delta.x, -delta.y)
    } else if motors[member]?.isSettled == true {
      wanted = atan2(-planner.heading.x, -planner.heading.y)
    } else {
      return
    }
    let current = yaw[member] ?? wanted
    let limit = 3 * Float.pi * dt
    let change = max(-limit, min(limit, (wanted - current).remainder(dividingBy: 2 * .pi)))
    setYaw(member, current + change)
  }

  private func setYaw(_ member: PartyMember, _ angle: Float) {
    yaw[member] = angle
    visuals[member]?.orientation = simd_quatf(angle: angle, axis: [0, 1, 0])
  }

  /// Where each member of the party stands. Members who have not joined are not included.
  private var positions: [PartyMember: SIMD2<Float>] {
    Dictionary(
      uniqueKeysWithValues: session.party.compactMap { member in
        bodies[member].map { (member, SIMD2($0.position.x, $0.position.z)) }
      })
  }

  private func updateActivity() {
    controls.setActive(isPresented && isApplicationActive)
    controls.requireNeutralInput()
    skipNextStep = true
  }

  private func updateCamera(deltaTime: Float) {
    guard let body = bodies[session.leader] else { return }
    // During a fight the target leans towards the threat, so both stay on screen.
    let wanted = stage.cameraLean(leader: SIMD2(body.position.x, body.position.z))
    cameraLean += (wanted - cameraLean) * min(1, deltaTime * Self.cameraLeanRate)
    let target = body.position + [cameraLean.x, 0.1, cameraLean.y]
    if let start = cameraStart {
      cameraElapsed = min(0.25, cameraElapsed + deltaTime)
      let amount = cameraElapsed / 0.25
      let eased = amount * amount * (3 - 2 * amount)
      cameraTarget = start + (target - start) * eased
      if cameraElapsed >= 0.25 { cameraStart = nil }
    } else {
      cameraTarget = target
    }
    camera.look(at: cameraTarget, from: cameraTarget + level.cameraOffset, relativeTo: nil)
  }

  private func updateNearby() {
    guard let player = bodies[session.leader] else { return }
    updatePrompt(at: SIMD2(player.position.x, player.position.z))
    let position = player.position * [1, 0, 1]
    let closest = level.points.min {
      simd_distance_squared($0.position, position) < simd_distance_squared($1.position, position)
    }
    let point = closest.flatMap {
      simd_distance($0.position, position) < Level.interactionRadius ? $0 : nil
    }
    if nearby?.id != point?.id {
      nearby = point
      nearbyName = point?.name
    }
  }

  #if DEBUG
    /// What a scripted playtest can see each frame.
    var playtestSnapshot: PlaytestRunner.Snapshot {
      PlaytestRunner.Snapshot(
        leader: session.leader, party: session.party, positions: positions, mode: session.mode,
        phase: session.phase, passageOpen: session.passageOpen,
        firedTriggers: session.firedTriggers.count, beat: session.beat,
        hitsTaken: session.hitsTaken, defeated: session.defeated.count, ammo: session.ammo,
        retrying: isRetrying)
    }

    /// Start a scripted playtest; an unknown scenario name is reported on the HUD.
    func startPlaytest(_ scenario: String, style: SceneStyle = SceneStyle()) {
      guard let runner = PlaytestRunner(scenario: scenario) else {
        observation =
          "Unknown playtest \"\(scenario)\". Try: "
          + PlaytestRunner.scenarioNames.joined(separator: ", ") + "."
        return
      }
      playtest = runner
      observation = runner.status
      // Small discs at each companion's target, so screenshots show where they are heading.
      for member in PartyMember.allCases {
        let disc = ModelEntity(
          mesh: .generateCylinder(height: 0.01, radius: 0.12), materials: [style.signal])
        disc.isEnabled = false
        root.addChild(disc)
        targetMarkers[member] = disc
      }
    }

    private func recordPlaytest(dt: Float, milliseconds: Double) {
      guard playtest != nil else { return }
      if playtest?.orientation == "unknown",
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
      {
        playtest?.orientation =
          switch scene.effectiveGeometry.interfaceOrientation {
          case .landscapeLeft: "landscapeLeft"
          case .landscapeRight: "landscapeRight"
          case .portrait, .portraitUpsideDown: "portrait"
          default: "unknown"
          }
      }
      playtest?.record(
        PlaytestRunner.Frame(
          dt: dt, leader: session.leader, positions: positions, targets: companionTargets,
          warning: diagnostic, simulationMilliseconds: milliseconds))
      for (member, disc) in targetMarkers {
        let target = companionTargets[member]
        disc.isEnabled = target != nil && member != session.leader
        if let target { disc.position = [target.x, 0.012, target.y] }
      }
      if let status = playtest?.status, observation != status { observation = status }
    }
  #endif

  /// The action prompt or role feedback for the active body where it stands.
  private func updatePrompt(at position: SIMD2<Float>) {
    var name: String?
    var feedback: String?
    if let interaction = level.interactions.first(where: {
      $0.approach.contains(position) && session.offers($0.id)
    }) {
      if session.isEligible(session.leader, for: interaction.id) {
        name = interaction.name
      } else {
        feedback = self.feedback(for: interaction)
      }
    } else if let passage = level.passage, !session.passageOpen {
      let centre = SIMD2(passage.barrier.position.x, passage.barrier.position.z)
      if simd_distance(position, centre) < Level.interactionRadius {
        feedback = passage.hint
      }
    }
    if actionName != name { actionName = name }
    if hint != feedback { hint = feedback }
  }

  /// For a leader who cannot act here: who can. At the passage Miki explains both ways.
  private func feedback(for interaction: Level.Interaction) -> String {
    session.leader == .miki
      ? interaction.mikiSuggestion ?? interaction.suggestion : interaction.suggestion
  }

  /// Make the scene show the session's progress: the barrier, the regulator in its housing or
  /// in the transmitter, and the transmitter's status light. Movement and routes read the
  /// passage flag directly.
  private func showProgress() {
    for part in barrierParts { part.isEnabled = !session.passageOpen }
    regulatorPart?.isEnabled = session.phase < .carryingRegulator
    installedRegulator?.isEnabled = session.phase >= .radioRepaired
    faultLight?.isEnabled = session.phase < .radioRepaired
    readyLight?.isEnabled = session.phase >= .radioRepaired
  }

  private static func freshMotors() -> [PartyMember: CompanionMotor] {
    Dictionary(
      uniqueKeysWithValues: PartyMember.allCases.map {
        ($0, CompanionMotor(reactionDelay: CompanionMotor.reactionDelay(for: $0)))
      })
  }

  // MARK: - Relay House

  /// The parts that show Party B's barrier and Party C's progress at Relay House.
  private func addRelayHouseParts(style: SceneStyle) {
    addBarrier(style: style)
    addMissionParts(style: style)
  }

  /// The closed barrier, with a latch at its top for Laura and a loose panel at its foot for
  /// Tom, both visible from the street side.
  private func addBarrier(style: SceneStyle) {
    let position = RelayHouse.barrierPosition
    let size = RelayHouse.barrierSize
    let barrier = style.block(
      size: size, at: position, material: style.material(for: .hazard))
    barrier.name = "passage.barrier"
    let latch = style.block(
      size: [0.12, 0.12, 0.3], at: position + [-0.12, size.y / 2 + 0.06, -0.55],
      material: style.signal)
    latch.name = "passage.latch"
    let panel = style.block(
      size: [0.04, 0.45, 0.55], at: position + [-size.x / 2 - 0.02, -0.3, 0.5],
      material: style.material(for: .depot))
    panel.name = "passage.panel"
    barrierParts = [barrier, latch, panel]
    for part in barrierParts { root.addChild(part) }
  }

  private func addMissionParts(style: SceneStyle) {
    // The transmitter's status light, amber until the repair, and the regulator Miki fits on top.
    let transmitter = RelayHouse.point(.transmitter)
    let light =
      transmitter.position + [-0.19, transmitter.size.y / 2 - 0.16, transmitter.size.z / 2 + 0.02]
    faultLight = addPart(
      "relay.transmitter.fault", size: [0.14, 0.04, 0.03], at: light, material: style.warm,
      style: style)
    readyLight = addPart(
      "relay.transmitter.ready", size: [0.14, 0.04, 0.03], at: light, material: style.signal,
      style: style)
    installedRegulator = addPart(
      "relay.transmitter.regulator", size: [0.24, 0.12, 0.2],
      at: transmitter.position + [-0.05, transmitter.size.y + 0.06, 0], material: style.signal,
      style: style)
    // The regulator on its disconnected housing, and the water bypass beside it that Miki
    // leaves connected, running to the depot's back wall.
    let housing = RelayHouse.point(.regulator)
    regulatorPart = addPart(
      "depot.regulator.part", size: [0.3, 0.12, 0.22],
      at: housing.position + [0, housing.size.y + 0.06, 0], material: style.signal, style: style)
    let wall = RelayHouse.box(.depotBack)
    let start = housing.position.z - housing.size.z / 2
    let end = wall.position.z + wall.size.z / 2
    let x = housing.position.x + 0.15
    _ = addPart(
      "depot.water-bypass", size: [0.08, 0.08, start - end], at: [x, 0.04, (start + end) / 2],
      material: style.water, style: style)
    _ = addPart(
      "depot.water-riser", size: [0.08, wall.size.y, 0.08], at: [x, wall.size.y / 2, end + 0.04],
      material: style.water, style: style)
    for position in RelayHouse.serviceMarkerPositions {
      let marker = ModelEntity(
        mesh: .generateBox(size: RelayHouse.serviceMarkerSize), materials: [style.signal])
      marker.position = position
      root.addChild(marker)
    }
  }

  private func addPart(
    _ name: String, size: SIMD3<Float>, at position: SIMD3<Float>, material: any Material,
    style: SceneStyle
  ) -> Entity {
    let part = style.block(size: size, at: position, material: material)
    part.name = name
    root.addChild(part)
    return part
  }
}
