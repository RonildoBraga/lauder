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
  /// The leader's contextual action here, such as "Search"; nil when there is none.
  private(set) var actionName: String?
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
  @ObservationIgnored private let motion: PartyMotion
  @ObservationIgnored private let grid: NavigationGrid
  @ObservationIgnored private var route: RouteMemory
  @ObservationIgnored private var planner: SquadPlanner
  @ObservationIgnored private var motors: [PartyMember: CompanionMotor]
  @ObservationIgnored private var squadLeader: PartyMember
  @ObservationIgnored private var yaw: [PartyMember: Float] = [:]
  /// Members lying hurt where they wait, until a scene stands them up (Laura, M4).
  @ObservationIgnored private var lying: Set<PartyMember>
  /// Where each companion is heading in the latest step. Tests read it.
  @ObservationIgnored private(set) var companionTargets: [PartyMember: SIMD2<Float>] = [:]
  #if DEBUG
    /// A scripted Simulator playtest (`apple/scripts/playtest`), started by the launch argument
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
  /// How far a lying stand-in sits below a standing one, so it rests on the deck.
  static let lyingDrop: Float = -0.67

  var isPaused: Bool { session.isPaused }
  /// Whether the weapon's controls show: during a fight, or while the weapon is drawn.
  var showsWeapon: Bool { session.inEncounter || weaponDrawn }
  /// Whether an encounter's retry is under way.
  var isRetrying: Bool { retryElapsed != nil }
  /// The HUD's objective: the level's own, until the story changes it.
  var objective: String {
    level.objectiveChanges.last { $0.beat <= session.beat }?.text ?? level.objective
  }

  init(level: Level = BrooklynBridge.level) {
    self.level = level
    session = GameSession(level: level)
    observation = level.opening
    motion = PartyMotion(radius: PartyBody.radius, obstacles: level.obstacles)
    // Build the route grid while loading, not on the first frame of play.
    grid = NavigationGrid(level: level)
    squadLeader = level.party[0]
    lying = level.lying
    route = RouteMemory(start: level.spawn(level.party[0]))
    planner = SquadPlanner(heading: level.heading)
    motors = Self.freshMotors()
    cameraTarget = Self.startingCameraTarget(level)
    let style = SceneStyle()
    stage = EncounterStage(level: level, style: style)
    root.name = level.id
    if let scene = level.scene {
      root.addChild(Self.loadScene(named: scene, for: level))
    } else {
      for box in [level.ground] + level.boxes {
        let entity: Entity =
          box.surface == .vehicle
          ? style.vehicle(size: box.size, at: box.position)
          : style.block(
            size: box.size, at: box.position, material: style.material(for: box.surface))
        entity.name = box.name
        root.addChild(entity)
      }
      for point in level.points {
        let entity = style.landmark(for: point)
        entity.name = point.id
        root.addChild(entity)
      }
    }
    // Every action the session can refer to here must be defined exactly once, checked at load.
    for interaction in level.interactions {
      precondition(
        level.interactions.filter { $0.id == interaction.id }.count == 1,
        "\(level.id) defines \(interaction.id.rawValue) more than once.")
    }
    root.addChild(stage.container)
    if level.scene == nil {
      SceneDressing.add(to: root, style: style, level: level)
    }
    style.addLights(level.lights, to: root)
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
    updateCamera(deltaTime: 0)
    updateNearby()
    #if DEBUG
      if let scenario = UserDefaults.standard.string(forKey: "LauderPlaytest") {
        startPlaytest(scenario, style: style)
      }
    #endif
  }

  /// Everything the player sees of the level, from its scene file in the app's bundle (ADR
  /// 0006). It loads once, while the world is made; Restart keeps it.
  private static func loadScene(named name: String, for level: Level) -> Entity {
    do {
      let scene = try Entity.load(named: name, in: .main)
      scene.name = "\(level.id).scene"
      return scene
    } catch {
      preconditionFailure("\(level.id)'s scene file, \(name).usdz, did not load: \(error)")
    }
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
        // What a finished conversation settles has just taken effect.
        if session.mode != .dialogue { updateNearby() }
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
    guard session.mode == .exploring, !stage.holdsParty, let body = bodies[session.leader] else {
      return
    }
    let position = SIMD2(body.position.x, body.position.z)
    let here = level.interactions.filter { $0.approach.contains(position) }
    // Several actions can share an approach; the one offered now comes first.
    if let interaction = here.first(where: { session.offers($0.id) }) ?? here.first {
      switch session.perform(interaction.id) {
      case .done:
        observation = interaction.result
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
      case .unavailable:
        break
      }
      updateNearby()
      return
    }
    observation = nearby?.observation ?? level.lookAround
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
    observation = level.opening
    nearby = nil
    nearbyName = nil
    updateCamera(deltaTime: 0)
    updateNearby()
    // Like Resume, the new run waits for every button, key and finger to be released.
    controls.requireNeutralInput()
  }

  /// Every body at its spawn point, facing the level's starting direction. Members who have
  /// not joined yet stay out of the squad, and hidden unless they lie hurt where they wait. A
  /// lying member lies across that direction, which the camera looks along, so the pose reads.
  private func placeParty() {
    let facing = atan2(-level.heading.x, -level.heading.y)
    lying = level.lying
    for member in PartyMember.allCases {
      place(member, at: level.spawn(member))
      setYaw(member, lying.contains(member) ? facing - .pi / 2 : facing)
      bodies[member]?.isEnabled = session.party.contains(member) || lying.contains(member)
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
    // remainder, always under one step, carries to the next frame. A retry, or a conversation a
    // cue has just begun, stops the rest.
    unsimulatedTime += elapsed
    while unsimulatedTime >= Self.simulationStep, retryElapsed == nil, session.mode == .exploring {
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
    // A scripted scene holds the party where they stand, whoever leads; only its cues place and
    // turn anyone, and switching leader during it moves no one.
    let held = stage.holdsParty
    let movement = held ? .zero : movement
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
    // The hold lasts through the step whose cue ends the scene and begins its exchange.
    if held || session.mode != .exploring {
      companionTargets = [:]
      return
    }

    // Companions choose their own routes to formation slots (ADR 0003); every movement is
    // still resolved against the authored footprints.
    let current = positions
    let isClear: (SIMD2<Float>, SIMD2<Float>) -> Bool = { from, to in
      motion.canTraverse(from: from, to: to)
    }
    let targets = planner.targets(
      for: SquadPlanner.Input(
        leader: leader, leaderPosition: leaderEnd, leaderVelocity: leaderVelocity,
        positions: current, route: route, dt: dt),
      grid: grid, isClear: isClear)
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
    let armed = leader == .miki && !stage.holdsParty
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
    for member in outcome.stood {
      lying.remove(member)
      showPose(member)
    }
    if let shooter = outcome.shooter {
      setYaw(shooter.member, atan2(-shooter.facing.x, -shooter.facing.y))
    }
    if let (first, second) = outcome.face { faceEachOther(first, second) }
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
    showPose(member)
  }

  /// A member's facing, and whether they lie face down on the deck.
  private func showPose(_ member: PartyMember) {
    let facing = simd_quatf(angle: yaw[member] ?? 0, axis: [0, 1, 0])
    let isLying = lying.contains(member)
    visuals[member]?.orientation =
      isLying ? facing * simd_quatf(angle: -.pi / 2, axis: [1, 0, 0]) : facing
    visuals[member]?.position = isLying ? [0, Self.lyingDrop, 0] : .zero
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

  /// The leader's action prompt where they stand.
  private func updatePrompt(at position: SIMD2<Float>) {
    let name = level.interactions.first {
      $0.approach.contains(position) && session.offers($0.id)
    }?.name
    if actionName != name { actionName = name }
  }

  private static func freshMotors() -> [PartyMember: CompanionMotor] {
    Dictionary(
      uniqueKeysWithValues: PartyMember.allCases.map {
        ($0, CompanionMotor(reactionDelay: CompanionMotor.reactionDelay(for: $0)))
      })
  }
}
