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
  /// How many events a world keeps for the frame to play (ADR 0008): headless runs play none.
  static let keptEvents = 64

  let level: Level
  let root = Entity()
  let controls = GameControls()
  let session: GameSession
  #if DEBUG
    /// Elapsed initializer-body time, recorded once for scripted Simulator playtests.
    @ObservationIgnored private(set) var loadTiming: WorldLoadTiming?
  #endif
  /// Asks the world's owner for a new run of another level, in a world of its own: the pause
  /// menu's third choice while the combat experiment lasts (ADR 0005). Without an owner, as in
  /// most tests, the choice does nothing.
  @ObservationIgnored var leave: ((Level) -> Void)?
  /// The latest line the HUD shows: a place's words, an action's result, a beat's line. Every
  /// line counts as new, even one that repeats the last, so it shows again in the status panel.
  private(set) var observation: String {
    get { shownLine }
    set {
      shownLine = newValue
      lineCount &+= 1
      #if DEBUG
        gameLine = newValue
      #endif
    }
  }
  private var shownLine: String
  @ObservationIgnored private var lineCount = 0
  #if DEBUG
    /// The latest line the game itself showed, which a scripted playtest's status then covers
    /// on the HUD. Playtests read it.
    @ObservationIgnored private(set) var gameLine = ""
  #endif
  private(set) var diagnostic: String?
  /// The leader's contextual action here, such as "Search"; nil when there is none.
  private(set) var actionName: String?
  /// A hostile winding up a shot, such as "The stranger is aiming."
  private(set) var threat: String?
  /// Who can answer a wind-up, such as "Miki can Disrupt" (ADR 0005); nil when nobody can.
  private(set) var signatureCue: String?
  /// Whether the leader's weapon is drawn.
  private(set) var weaponDrawn = false
  /// How dark the screen is while an encounter starts again, from 0 to 1.
  private(set) var fade: Float = 0
  /// The compass to the level's current goal; nil when there is none.
  private(set) var compass: Compass?
  /// Whether the player has hidden the status panel. It stays hidden or shown across Restart.
  private(set) var panelHidden = false
  /// Whether the phone or the controller vibrates in play (ADR 0008): the pause menu's choice,
  /// on until the player turns it off.
  private(set) var vibrationEnabled = true
  /// Whether the status panel shows: unless the player has hidden it, and always with touch
  /// controls, which have no button to show it again.
  var showsPanel: Bool { !panelHidden || controls.touchControlsEnabled }
  /// Whether the latest line and the objective are new enough to show in the status panel.
  private(set) var lineIsFresh = true
  private(set) var objectiveIsFresh = true

  /// What the HUD's compass shows: the goal's name, how far away it is, and which way, as an
  /// angle clockwise from straight up the screen.
  struct Compass: Equatable {
    let name: String
    let metres: Int
    /// Radians, to the nearest degree.
    let angle: Float
  }

  @ObservationIgnored private var bodies: [PartyMember: Entity] = [:]
  @ObservationIgnored private var visuals: [PartyMember: Entity] = [:]
  @ObservationIgnored private var markers: [PartyMember: Entity] = [:]
  /// Rings where going companions are heading, in their colours (ADR 0003, phase S3).
  @ObservationIgnored private var orderMarkers: [PartyMember: Entity] = [:]
  /// The brief cross where an order's point could not be reached.
  @ObservationIgnored private var refusalCross = Entity()
  @ObservationIgnored private var crossRemaining: Float = 0
  /// Orders refused in this run because nobody could reach their point. Tests read it.
  @ObservationIgnored private(set) var refusedOrders = 0
  /// How often the party has fallen back in this run (ADR 0005). Tests and playtests read it.
  @ObservationIgnored private(set) var fallBacks = 0
  /// Whether the leader has been told, on this visit to a gathering area, who is missing.
  @ObservationIgnored private var toldWhoIsMissing = false
  /// What the touch order menu marked as it opened: its point on the screen, and what the ray
  /// through it met then. The order that follows uses it, though the camera has moved since.
  @ObservationIgnored private var touchMark: (screen: InputRules.ScreenPoint, hit: SIMD3<Float>?)?
  @ObservationIgnored private let camera = PerspectiveCamera()
  /// Movement against the level's blockers, and the salvage gate as it stands (ADR 0006).
  @ObservationIgnored private var motion: PartyMotion
  @ObservationIgnored private var grid: NavigationGrid
  /// Both of those with the salvage gate shut and open, made while loading, so that the gate
  /// opening or shutting stalls no frame (ADR 0006).
  @ObservationIgnored private var gateWays:
    (
      shut: (motion: PartyMotion, grid: NavigationGrid),
      open: (motion: PartyMotion, grid: NavigationGrid)
    )?
  /// The salvage gate's hinge, which swings it open into the depot; how far open it shows, from
  /// 0 shut to 1 open; and whether the blockers have it open, so they change only when that
  /// does (ADR 0006).
  @ObservationIgnored private var gateHinge: Entity?
  @ObservationIgnored private var gateSwing: Float = 0
  @ObservationIgnored private var gateShownOpen = false
  /// How a salvage task shows what the party has done (ADR 0006).
  @ObservationIgnored private var salvageLooks: SalvageLooks?
  @ObservationIgnored private var route: RouteMemory
  @ObservationIgnored private var planner: SquadPlanner
  /// Where companions take cover in a fight, in a level with combat positioning (ADR 0003,
  /// phase S4).
  @ObservationIgnored private var cover: CoverPlanner
  /// What blocks sight, for what the shooters can see: the level's blockers, worked out once.
  @ObservationIgnored private let sightBlockers: [PartyMotion.Box]
  /// What the shooters see, remembered across the routes planned in a fight.
  @ObservationIgnored private let sightMemo = SightMemo()
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
  @ObservationIgnored private var cameraTarget: SIMD3<Float>
  /// The line and objective the status panel last saw change, and for how long they have shown.
  @ObservationIgnored private var agedLineCount = 0
  @ObservationIgnored private var agedObjective = ""
  @ObservationIgnored private var lineAge: Float = 0
  @ObservationIgnored private var objectiveAge: Float = 0
  @ObservationIgnored private var cameraStart: SIMD3<Float>?
  /// Tall landmarks, such as the towers, that fade while they hide the party.
  @ObservationIgnored private var landmarkFade = LandmarkFade()
  @ObservationIgnored private var cameraElapsed: Float = 0
  @ObservationIgnored private var unsimulatedTime: Float = 0
  /// The level's fight rules and presentation, kept separate (ADR 0004, ADR 0008).
  @ObservationIgnored private let fight: FightSimulation
  @ObservationIgnored private let stage: EncounterStage
  @ObservationIgnored private var fireHeld = false
  /// Where the right stick aims, in the stick's terms, and where that is on the ground while the
  /// leader is armed to aim (ADR 0007).
  @ObservationIgnored private var aimStick: SIMD2<Float>?
  @ObservationIgnored private var aimDirection: SIMD2<Float>?
  /// Where the fight last asked the leader to turn, such as towards the assisted target while
  /// Fire is held, until she faces it (ADR 0008).
  @ObservationIgnored private var facingGoal: SIMD2<Float>?
  /// Members still rocking from a shot or a hit in the latest step (ADR 0008).
  @ObservationIgnored private var joltedMembers: Set<PartyMember> = []
  @ObservationIgnored private var posedCoverLeader: PartyMember?
  /// What players hear and feel, waiting for the frame to play it (ADR 0008). Headless runs,
  /// which play nothing, keep only the latest.
  @ObservationIgnored private var combatEvents: [CombatEvent] = []
  /// The camera's lens now, in degrees: the level's own while exploring, narrowing in a fight or
  /// while the right stick aims (ADR 0007).
  @ObservationIgnored private var lens: Float
  @ObservationIgnored private var firePressPending = false
  @ObservationIgnored private var signaturePressPending = false
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
  /// How far ahead of the leader the D-pad marks its point, before a wall shortens it (ADR 0003).
  static let orderReach: Float = 6
  /// How far a marked point may move to reach somewhere a companion can stand.
  static let orderSnap: Float = 1
  /// How far apart two companions sent together stand.
  static let spotSpacing: Float = 1
  /// How close a going companion comes to their point before they hold there.
  static let arrivalDistance: Float = 0.35
  /// How close every companion must be to their place in the formation for a regroup to end
  /// (ADR 0003, phase S4).
  static let regroupDistance: Float = 1
  /// How long the cross shows where an order could not go.
  static let crossTime: Float = 1
  /// How close every companion must be before a scene that gathers the party begins.
  static let gatherRadius: Float = 5
  /// How long a new line or objective shows in the status panel, in seconds of play.
  static let lineTime: Float = 6
  /// How much the lens narrows in a fight or while the right stick aims, and roughly how long
  /// it takes to get there, in seconds (ADR 0007): about 14° from the bridge's 20°.
  static let fightLens: Float = 0.7
  static let lensTime: Float = 0.3

  var isPaused: Bool { session.isPaused }
  /// Whether the weapon's controls show: while Miki leads, since she carries the carbine and can
  /// fire it in a fight or out of one (ADR 0007).
  var showsWeapon: Bool { session.leader == .miki }
  /// Whether the carbine's rounds show: during a fight, or while the weapon is drawn.
  var showsAmmo: Bool { session.inEncounter || weaponDrawn }
  /// Whether an encounter's retry, or the party's fall back, is under way.
  var isRetrying: Bool { retryElapsed != nil }
  /// Whether the HUD shows everyone's hits during a fight, as the combat yard does, rather than
  /// only the leader's.
  var showsEveryonesHits: Bool { session.inEncounter && level.combat.fallsBack }
  /// Whether the leader has a signature to use: Miki's Disrupt, in a level that has it (ADR
  /// 0005). The others' signatures are left out of the experiment.
  var leaderHasSignature: Bool { level.combat.disrupt && session.leader == .miki }
  /// Whether the signature's controls show: during a fight, while the leader has one.
  var showsSignature: Bool { session.inEncounter && leaderHasSignature }
  /// How many shots each companion has fired by themselves in this run. Tests and playtests
  /// read it.
  var companionShots: [PartyMember: Int] { fight.companionShots }
  /// How many shots' marks show on blocks now (ADR 0007). Tests and playtests read it.
  var shotMarks: Int { stage.effects.marksShown }
  /// The camera's lens now, in degrees (ADR 0007). Tests read it.
  var cameraLens: Float { lens }
  /// The direction on the ground a member faces. Tests read it.
  func facing(of member: PartyMember) -> SIMD2<Float> { Movement.facing(yaw: yaw[member] ?? 0) }
  /// How many wind-ups Disrupt has cancelled in this run. Tests and playtests read it.
  var disrupts: Int { fight.disrupts }
  /// The HUD's objective: the level's own, until the story changes it or a salvage task's
  /// repair is done.
  var objective: String {
    if let task = level.salvage, session.salvage.repaired { return task.doneObjective }
    return level.objectiveChanges.last { $0.beat <= session.beat }?.text ?? level.objective
  }
  /// The pause menu's third choice: what it reads, what it does and the level it starts.
  var otherLevel: (name: String, note: String, level: Level) {
    LevelCycle.next(after: level)
  }

  init(level: Level = BrooklynBridge.level) {
    #if DEBUG
      let loadStarted = ContinuousClock.now
    #endif
    self.level = level
    session = GameSession(level: level)
    shownLine = level.opening
    lens = level.fieldOfView
    // Build the route grid while loading, not on the first frame of play, and in a salvage
    // task the gate's open one as well.
    func ways(adding gate: [PartyMotion.Box]) -> (motion: PartyMotion, grid: NavigationGrid) {
      (
        PartyMotion(radius: PartyBody.radius, obstacles: level.obstacles + gate),
        NavigationGrid(level: level, adding: gate)
      )
    }
    #if DEBUG
      let navigationStarted = ContinuousClock.now
    #endif
    let start = ways(adding: level.salvage.map { [$0.gate.footprint] } ?? [])
    (motion, grid) = start
    gateWays = level.salvage.map { (shut: start, open: ways(adding: [$0.openGate])) }
    #if DEBUG
      let navigationFinished = ContinuousClock.now
    #endif
    squadLeader = level.party[0]
    lying = level.lying
    route = RouteMemory(start: level.spawn(level.party[0]))
    planner = SquadPlanner(heading: level.heading)
    sightBlockers = level.obstacles
    cover = CoverPlanner(obstacles: sightBlockers)
    motors = Self.freshMotors()
    cameraTarget = Self.cameraTarget(over: level.spawn(level.party[0]))
    let style = SceneStyle(
      markerScale: SceneStyle.markerScale(
        cameraOffset: level.cameraOffset, fieldOfView: level.fieldOfView))
    #if DEBUG
      let fightStarted = ContinuousClock.now
    #endif
    fight = FightSimulation(level: level)
    stage = EncounterStage(level: level, style: style)
    stage.reset(fight)
    #if DEBUG
      let fightFinished = ContinuousClock.now
      let sceneStarted = fightFinished
    #endif
    root.name = level.id
    if let scene = level.scene {
      root.addChild(Self.loadScene(named: scene, for: level))
    } else {
      // A greybox, such as the combat yard or a test's level: snow underfoot, and plain blocks.
      for box in [level.ground] + level.boxes {
        let material = box.name == level.ground.name ? style.snow : style.scenery
        let entity = style.block(size: box.size, at: box.position, material: material)
        entity.name = box.name
        root.addChild(entity)
      }
    }
    #if DEBUG
      let sceneFinished = ContinuousClock.now
    #endif
    // A salvage task's gate, which swings open, and the looks that show the party's progress
    // (ADR 0006).
    if let task = level.salvage {
      gateHinge = Self.addGate(task.gate, to: root, style: style)
      salvageLooks = SalvageLooks(task: task, in: root, style: style)
    }
    landmarkFade = LandmarkFade(look: root)
    // The session refers to each action by its name, so no action is defined twice.
    let actions = level.interactions.map(\.id)
    precondition(Set(actions).count == actions.count, "\(level.id) defines an action twice.")
    root.addChild(stage.container)
    style.addLights(level.lights, to: root)
    camera.camera.fieldOfViewInDegrees = level.fieldOfView
    camera.name = "camera"
    root.addChild(camera)
    landmarkFade.prepare(before: camera)
    #if DEBUG
      let partyStarted = ContinuousClock.now
    #endif
    for member in PartyMember.allCases {
      let body = Entity()
      body.name = "party.\(member.rawValue)"
      let visual = style.partyMember(member)
      body.addChild(visual)
      let marker = style.leaderMarker()
      marker.name = "\(member.rawValue).marker"
      body.addChild(marker)
      bodies[member] = body
      visuals[member] = visual
      markers[member] = marker
      root.addChild(body)
      let ring = style.orderMarker(for: member)
      ring.name = "order.\(member.rawValue)"
      ring.isEnabled = false
      orderMarkers[member] = ring
      root.addChild(ring)
    }
    refusalCross = style.refusalCross()
    refusalCross.name = "order.refused"
    refusalCross.isEnabled = false
    root.addChild(refusalCross)
    // Miki carries the carbine; it shows while drawn.
    visuals[.miki]?.addChild(stage.weaponProp)
    #if DEBUG
      let partyFinished = ContinuousClock.now
    #endif
    placeParty()
    showSalvage()
    updateCamera(deltaTime: 0)
    updatePromptAndCompass()
    #if DEBUG
      loadTiming = WorldLoadTiming(
        level: level.id, total: loadStarted.duration(to: .now),
        navigation: navigationStarted.duration(to: navigationFinished),
        fight: fightStarted.duration(to: fightFinished),
        scene: sceneStarted.duration(to: sceneFinished),
        party: partyStarted.duration(to: partyFinished))
    #endif
  }

  /// Everything the player sees of the level, from its scene file in the app's bundle (ADR
  /// 0002). It loads once, while the world is made; Restart keeps it.
  private static func loadScene(named name: String, for level: Level) -> Entity {
    do {
      let scene = try Entity.load(named: name, in: .main)
      scene.name = "\(level.id).scene"
      return scene
    } catch {
      preconditionFailure("\(level.id)'s scene file, \(name).usdz, did not load: \(error)")
    }
  }

  /// Where the camera looks while it is settled behind a leader standing at this point: just
  /// above the body's centre.
  private static func cameraTarget(over point: SIMD2<Float>) -> SIMD3<Float> {
    [point.x, PartyBody.height / 2 + 0.1, point.y]
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

  /// The pause menu's Vibration choice (ADR 0008).
  func toggleVibration() {
    vibrationEnabled.toggle()
  }

  /// What players have heard and felt since the last call, which empties the list (ADR 0008).
  /// The frame plays them; tests read them.
  func takeCombatEvents() -> [CombatEvent] {
    defer { combatEvents.removeAll(keepingCapacity: true) }
    return combatEvents
  }

  /// The frame's feedback context. Only the interface plays the events; headless simulation
  /// keeps no sound, vibration or controller-trigger dependency.
  var listenerPoint: SIMD2<Float> { SIMD2(cameraTarget.x, cameraTarget.z) }
  var screenRight: SIMD2<Float> { Movement.axes(cameraOffset: level.cameraOffset).right }
  var canFire: Bool { session.mode == .exploring && showsWeapon && !fight.holdsParty }
  var isActive: Bool { isPresented && isApplicationActive }

  /// What the player chose in another level's world carries over to this one: a hidden status
  /// panel, the vibration choice, and touch controls in place of an attached controller.
  func takePreferences(from other: GameWorld) {
    panelHidden = other.panelHidden
    vibrationEnabled = other.vibrationEnabled
    if other.controls.prefersTouch { controls.useTouchControls() }
  }

  /// The scene's update: this frame's input, sampled in the session's mode, then `update`. Each
  /// active step starts from the body positions that the one before checked against collisions.
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
      movement: input.movement, aim: input.aim, fireHeld: input.fireHeld,
      firePressed: input.firePressed, signaturePressed: input.signaturePressed,
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
      } else if input.otherLevelPressed {
        leave?(otherLevel.level)
      } else if input.vibrationPressed {
        toggleVibration()
      } else if input.actionPressed {
        switch session.pauseChoice {
        case .resume: togglePause()
        case .restart: restart()
        case .otherLevel: leave?(otherLevel.level)
        case .vibration: toggleVibration()
        }
      } else if input.menuMove != 0 {
        session.movePauseChoice(by: input.menuMove)
      }
    case .dialogue:
      if input.panelPressed { panelHidden.toggle() }
      if input.pausePressed {
        togglePause()
      } else if input.actionPressed {
        session.advanceDialogue()
        // What a finished conversation settles has just taken effect.
        if session.mode != .dialogue { updatePromptAndCompass() }
      }
    case .exploring:
      if input.panelPressed { panelHidden.toggle() }
      if input.pausePressed {
        togglePause()
      } else if input.switchPressed, session.nextLeader != nil {
        session.cycleLeader()
        followNewLeader()
      } else if input.previousPressed, session.previousLeader != nil {
        session.cycleLeaderBackwards()
        followNewLeader()
      }
      // The squad's planner takes the new formation in the next step (ADR 0003, phase S2). After
      // an order the button calls everyone back instead.
      if input.formationPressed {
        session.pressFormation()
        showOrders()
      }
      if let mark = input.markPoint { touchMark = (mark, firstHit(at: mark)) }
      if let command = input.command { give(command, at: input.commandPoint) }
    }
  }

  private func togglePause() {
    session.togglePause()
    controls.requireNeutralInput()
  }

  /// After Next or Previous: the camera eases to the new leader, and a previous leader who
  /// joins a holding squad holds where they stand.
  private func followNewLeader() {
    pinHolds()
    cameraStart = cameraTarget
    cameraElapsed = 0
    showLeaderMarker()
    updatePromptAndCompass()
  }

  /// The leader's action press. Identity, approach and progress are checked afresh, so a
  /// prompt left over from before a move or a switch cannot act.
  func performAction() {
    guard session.mode == .exploring, !fight.holdsParty,
      let position = self.position(of: session.leader)
    else { return }
    // In a salvage task, the place decides; at the gate, whoever cannot open it hears who can
    // (ADR 0006).
    if let task = level.salvage, let place = Self.place(at: position, in: task) {
      observation =
        session.performSalvage(at: place) ?? session.salvage.hint(at: place)
        ?? level.lookAround
      showSalvage()
      updatePromptAndCompass()
      return
    }
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
          fight.begin(encounter)
          retrySpot = encounter.retryAt
        }
      case .alreadyDone:
        observation = interaction.repeated
      case .notYet:
        observation = interaction.early
      case .unavailable:
        break
      }
      updatePromptAndCompass()
      return
    }
    observation = level.lookAround
  }

  /// The in-place Restart: the same scene, bodies and update subscription, returned to the
  /// beginning of a run. Nothing is rebuilt or reloaded.
  func restart() {
    session.restart()
    showSalvage()
    retryElapsed = nil
    retrySpot = nil
    fade = 0
    placeParty()
    diagnostic = nil
    refusedOrders = 0
    fallBacks = 0
    touchMark = nil
    crossRemaining = 0
    refusalCross.isEnabled = false
    toldWhoIsMissing = false
    showOrders()
    skipNextStep = true
    observation = level.opening
    lineAge = 0
    objectiveAge = 0
    lineIsFresh = true
    objectiveIsFresh = true
    resetPlay(around: level.spawn(session.leader))
    // Like Resume, the new run waits for every button, key and finger to be released.
    controls.requireNeutralInput()
  }

  /// What Restart and an encounter's retry both put back, once the leader stands at `spot`:
  /// the fights as they began, with the weapon holstered, the squad's movement around the
  /// leader, and the camera settled behind them.
  private func resetPlay(around spot: SIMD2<Float>) {
    fight.reset()
    stage.reset(fight)
    for member in PartyMember.allCases { showPose(member) }
    joltedMembers = []
    posedCoverLeader = nil
    resetSquad(around: spot)
  }

  /// What a fall back puts back too, once the leader stands at `spot`: the squad's movement
  /// around the leader and the camera settled behind them, with the weapon holstered.
  private func resetSquad(around spot: SIMD2<Float>) {
    threat = nil
    weaponDrawn = false
    fireHeld = false
    aimStick = nil
    aimDirection = nil
    facingGoal = nil
    firePressPending = false
    signaturePressPending = false
    signatureCue = nil
    squadLeader = session.leader
    route = RouteMemory(start: spot)
    planner = SquadPlanner(heading: level.heading)
    cover.reset()
    motors = Self.freshMotors()
    companionTargets = [:]
    unsimulatedTime = 0
    cameraStart = nil
    cameraElapsed = 0
    cameraLean = .zero
    cameraTarget = Self.cameraTarget(over: spot)
    lens = level.fieldOfView
    updateCamera(deltaTime: 0)
    updatePromptAndCompass()
  }

  /// Every body at its spawn point, facing the level's starting direction. Members who have
  /// not joined yet stay out of the squad, and hidden unless they lie hurt where they wait. A
  /// lying member lies across that direction, which the camera looks along, so the pose reads.
  private func placeParty() {
    let facing = Movement.yaw(towards: level.heading)
    lying = level.lying
    for member in PartyMember.allCases {
      place(member, at: level.spawn(member))
      setYaw(member, lying.contains(member) ? facing - .pi / 2 : facing)
      bodies[member]?.isEnabled = session.party.contains(member) || lying.contains(member)
    }
    showLeaderMarker()
  }

  /// The party's movement, the fight, the camera and the HUD's lines for one frame of play, as in
  /// production; deterministic route and soak tests drive it too. Input availability, Pause and
  /// fresh-edge handling remain in `step` and InputRules.
  func advanceParty(
    movement: SIMD2<Float>, aim: SIMD2<Float>? = nil, fireHeld: Bool = false,
    firePressed: Bool = false, signaturePressed: Bool = false, deltaTime: Float
  ) {
    guard session.mode == .exploring, deltaTime.isFinite, deltaTime > 0 else { return }
    self.fireHeld = fireHeld
    aimStick = aim
    if firePressed { firePressPending = true }
    if signaturePressed { signaturePressPending = true }
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
    swingGate(by: elapsed)
    ageLines(by: elapsed)
    updatePromptAndCompass()
    checkTriggers()
    if crossRemaining > 0 {
      crossRemaining -= elapsed
      if crossRemaining <= 0 { refusalCross.isEnabled = false }
    }
  }

  private func simulateStep(movement: SIMD2<Float>, dt: Float) {
    if squadLeader != session.leader { changeLeader() }
    pinHolds()
    let leader = session.leader
    guard let leaderStart = position(of: leader) else { return }
    let motion = self.motion
    let grid = self.grid
    // A scripted scene holds the party where they stand, whoever leads; only its cues place and
    // turn anyone, and switching leader during it moves no one.
    let held = fight.holdsParty
    let movement = held ? .zero : movement
    let direction = Movement.direction(for: movement, cameraOffset: level.cameraOffset)
    let leaderDelta = SIMD2(direction.x, direction.z) * PartyBody.speed * dt
    let leaderEnd = motion.resolve(start: leaderStart, delta: leaderDelta)
    place(leader, at: leaderEnd)
    // Only Miki carries the carbine, and not while a scene holds her. While the right stick aims
    // it, she turns towards her aim, whichever way she moves (ADR 0007); otherwise towards where
    // the fight turns her, or where she moves. She never turns faster than her turn rate, and
    // her shots leave the way she faces (ADR 0008).
    let armed = leader == .miki && !held
    aimDirection =
      armed ? aimStick.map { Movement.aim(for: $0, cameraOffset: level.cameraOffset) } : nil
    let moving = simd_length_squared(leaderDelta) > 0.000001 ? leaderDelta : nil
    if let wanted = aimDirection ?? facingGoal ?? moving {
      turnLeader(leader, towards: wanted, dt: dt)
    }
    let leaderVelocity = (leaderEnd - leaderStart) / dt
    route.record(leaderEnd)
    stepStage(leader: leader, at: leaderEnd, armed: armed, dt: dt)
    if retryElapsed != nil { return }
    // The hold lasts through the step whose cue ends the scene and begins its exchange.
    if held || session.mode != .exploring {
      companionTargets = [:]
      return
    }

    // Companions choose their own routes to formation slots (ADR 0003); every movement is
    // still resolved against the authored footprints. A companion with an order keeps to its
    // point, and the others share the formation's places (phase S3).
    let current = positions
    let isClear: (SIMD2<Float>, SIMD2<Float>) -> Bool = { from, to in
      motion.canTraverse(from: from, to: to)
    }
    let session = self.session
    let following = current.filter { member, _ in
      member == leader || session.order(of: member) == .following
    }
    var targets = planner.targets(
      for: SquadPlanner.Input(
        leader: leader, leaderPosition: leaderEnd, leaderVelocity: leaderVelocity,
        positions: following, route: route, formation: session.formation, dt: dt),
      grid: grid, isClear: isClear)
    for member in session.party where member != leader {
      if let point = Self.point(of: session.order(of: member)) { targets[member] = point }
    }
    // Once a fight is under way in a level with combat positioning (ADR 0003, phase S4),
    // companions keep off the ground the shooters see, and take cover near those places unless
    // they are regrouping, which ends once everyone is back in the formation.
    let positioning = level.combat.combatPositioning && fight.fightUnderWay
    let threats = positioning ? fight.threats : []
    sightMemo.prepare(for: threats)
    let openGround =
      threats.isEmpty
      ? nil : OpenGround(threats: threats, obstacles: sightBlockers, memo: sightMemo)
    if session.regrouping,
      session.companions.allSatisfy({ member in
        guard let here = current[member], let place = targets[member] else { return true }
        return simd_distance(here, place) <= Self.regroupDistance
      })
    {
      session.endRegroup()
    }
    let takingCover = positioning && !session.regrouping
    if takingCover {
      targets = cover.targets(
        for: CoverPlanner.Input(
          places: targets, positions: current, leaderPosition: leaderEnd,
          formation: session.formation, threats: threats,
          weaponRanges: level.combat.companionWeapons.mapValues(\.range), dt: dt),
        grid: grid)
    } else {
      cover.reset()
    }
    let previousTargets = companionTargets
    companionTargets = targets
    for member in session.party where member != leader {
      guard let start = current[member], let target = targets[member],
        var motor = motors[member]
      else { continue }
      // Into cover, or out to fire: a settled companion moves off however short the step.
      if takingCover, let before = previousTargets[member],
        simd_distance(before, target) > CompanionMotor.settleDistance
      {
        motor.wake()
      }
      let order = session.order(of: member)
      // A spot of cover stays where it is; a formation slot moves with the leader.
      let inCover = takingCover && cover.isTakingCover(member)
      let context = CompanionMotor.Context(
        target: target, leaderPosition: leaderEnd, leaderVelocity: leaderVelocity,
        others: current.compactMap { $0.key == member ? nil : $0.value },
        speed: PartyBody.speed, dt: dt, targetMoves: order == .following && !inCover,
        openGround: openGround)
      let delta = motor.step(from: start, context: context, grid: grid, isClear: isClear)
      let end = motion.resolve(start: start, delta: delta)
      motor.absorb(end - start, dt: dt)
      motors[member] = motor
      place(member, at: end)
      turn(member, moved: end - start, dt: dt)
      // A going companion arrives at their point, or in cover at their spot near it.
      if case .going(let point) = order,
        simd_distance(end, takingCover ? target : point) <= Self.arrivalDistance
      {
        session.arrived(member)
      }
    }
    showOrders()
    let stuck = session.party.first { $0 != leader && motors[$0]?.cannotReach == true }
    let message = stuck.map {
      session.order(of: $0) == .following
        ? "\($0.displayName) can't reach you" : "\($0.displayName) can't get there"
    }
    if diagnostic != message { diagnostic = message }
  }

  // MARK: - Squad orders

  /// The point an order keeps a companion to; nil while following, or while a hold waits
  /// for its place to be recorded.
  private static func point(of order: GameSession.Order) -> SIMD2<Float>? {
    switch order {
    case .following: nil
    case .going(let point): point
    case .holding(let point): point
    }
  }

  /// A squad order (ADR 0003, phase S3). The D-pad's point lies up to 6 m ahead of the leader,
  /// shortened by the first wall; a touch order's is the ground under the finger. Either moves
  /// up to a metre to somewhere the companions can reach, or shows a brief cross and does
  /// nothing.
  private func give(_ command: GameSession.Command, at screen: InputRules.ScreenPoint?) {
    guard session.mode == .exploring, session.ordersAvailable, !fight.holdsParty,
      let leader = position(of: session.leader)
    else { return }
    if command == .hold {
      session.holdAll()
      pinHolds()
      showOrders()
      return
    }
    // A touch marks what the finger's ray met first, a block or the ground, as the menu opened;
    // a touch above the ground marks nothing.
    let pressed: SIMD3<Float>?
    if let screen {
      pressed = touchMark?.screen == screen ? touchMark?.hit : firstHit(at: screen)
      touchMark = nil
    } else {
      let ahead = pointAhead(of: leader)
      pressed = SIMD3(ahead.x, 0, ahead.y)
    }
    guard let pressed else { return }
    let marked = SIMD2(pressed.x, pressed.z)
    guard let region = region(near: leader), let point = reachable(near: marked, in: region)
    else {
      refuse(at: pressed)
      return
    }
    switch command {
    case .bothGo:
      guard let spots = spots(around: point, from: leader, in: region) else {
        refuse(at: pressed)
        return
      }
      // Each takes the spot that makes the least walking in total, so their ways do not cross.
      let members = session.companions
      guard members.count == 2, let first = position(of: members[0]),
        let second = position(of: members[1])
      else { return }
      let kept =
        simd_distance(first, spots[0]) + simd_distance(second, spots[1])
        <= simd_distance(first, spots[1]) + simd_distance(second, spots[0])
      session.send(members[0], to: kept ? spots[0] : spots[1])
      session.send(members[1], to: kept ? spots[1] : spots[0])
      for member in members { motors[member]?.wake() }
    case .leftGoes, .rightGoes:
      guard
        let member = command == .leftGoes ? session.leftCompanion : session.rightCompanion
      else { return }
      var target = point
      // Not onto the other companion's own point, where neither could settle: beside it, on
      // the side the order names, so neither walks through the other.
      if let other = session.companions.first(where: { $0 != member }),
        let taken = Self.point(of: session.order(of: other)),
        simd_distance(taken, point) < Self.spotSpacing,
        let beside = spot(
          beside: taken, from: leader, onRight: command == .rightGoes, in: region)
      {
        target = beside
      }
      session.send(member, to: target)
      motors[member]?.wake()
    case .hold:
      break
    }
    showOrders()
  }

  /// Up to `orderReach` ahead along the leader's facing, shortened by the first wall.
  private func pointAhead(of leader: SIMD2<Float>) -> SIMD2<Float> {
    let heading = Movement.facing(yaw: yaw[session.leader] ?? 0)
    let far = leader + heading * Self.orderReach
    if motion.canTraverse(from: leader, to: far) { return far }
    var clear: Float = 0
    var blocked = Self.orderReach
    for _ in 0..<12 {
      let middle = (clear + blocked) / 2
      if motion.canTraverse(from: leader, to: leader + heading * middle) {
        clear = middle
      } else {
        blocked = middle
      }
    }
    return leader + heading * clear
  }

  /// The connected area the leader stands in, from the nearest walkable cell.
  private func region(near point: SIMD2<Float>) -> Int32? {
    grid.nearestWalkable(to: point, within: 0.6).flatMap { grid.region(at: $0) }
  }

  /// The marked point, or the nearest place within `orderSnap` of it in the leader's area,
  /// out of doorways where there is a choice.
  private func reachable(near point: SIMD2<Float>, in region: Int32) -> SIMD2<Float>? {
    if grid.isRoomy(point), grid.region(at: point) == region { return point }
    return grid.nearestWalkable(
      to: point, within: Self.orderSnap, region: region, where: { grid.isRoomy($0) })
      ?? grid.nearestWalkable(to: point, within: Self.orderSnap, region: region)
  }

  /// Two spots `spotSpacing` apart around a point: side by side across the line from the
  /// leader, else one behind the other, else the point and the nearest place far enough away.
  private func spots(around point: SIMD2<Float>, from leader: SIMD2<Float>, in region: Int32)
    -> [SIMD2<Float>]?
  {
    let (along, across) = axes(of: point, from: leader)
    let half = Self.spotSpacing / 2
    for axis in [across, along] {
      let pair = [point + axis * half, point - axis * half]
      if pair.allSatisfy({ fits($0, near: point, in: region) }) { return pair }
    }
    let second = grid.nearestWalkable(
      to: point, within: Self.orderSnap + Self.spotSpacing, region: region,
      where: { simd_distance($0, point) >= Self.spotSpacing && fits($0, near: point, in: region) })
    return second.map { [point, $0] }
  }

  /// A spot `spotSpacing` beside another companion's point: on the named side of the line from
  /// the leader where it fits, else the other side, else the nearest place far enough away.
  private func spot(
    beside taken: SIMD2<Float>, from leader: SIMD2<Float>, onRight: Bool, in region: Int32
  ) -> SIMD2<Float>? {
    let across = axes(of: taken, from: leader).across * (onRight ? 1 : -1)
    for candidate in [taken + across * Self.spotSpacing, taken - across * Self.spotSpacing]
    where fits(candidate, near: taken, in: region) {
      return candidate
    }
    return grid.nearestWalkable(
      to: taken, within: Self.orderSnap + Self.spotSpacing, region: region,
      where: { simd_distance($0, taken) >= Self.spotSpacing && fits($0, near: taken, in: region) })
  }

  /// The line from the leader to a point, and the direction to its right, which is screen right
  /// under a camera behind the leader. A point at the leader's feet takes the leader's facing.
  private func axes(of point: SIMD2<Float>, from leader: SIMD2<Float>)
    -> (along: SIMD2<Float>, across: SIMD2<Float>)
  {
    let offset = point - leader
    let along =
      simd_length(offset) > 0.01
      ? simd_normalize(offset) : Movement.facing(yaw: yaw[session.leader] ?? 0)
    return (along, SIMD2(-along.y, along.x))
  }

  /// Somewhere a companion can stand, in the leader's area, reached straight from `origin`.
  private func fits(_ spot: SIMD2<Float>, near origin: SIMD2<Float>, in region: Int32) -> Bool {
    grid.isWalkable(spot) && grid.region(at: spot) == region
      && motion.canTraverse(from: origin, to: spot)
  }

  /// Show the cross where an order could not go, briefly: standing where the finger pressed,
  /// or where the D-pad marked, and facing the camera so it reads on a block's side too.
  private func refuse(at point: SIMD3<Float>) {
    refusedOrders += 1
    crossRemaining = Self.crossTime
    let eye = cameraTarget + level.cameraOffset
    let toCamera = simd_normalize(eye - point)
    let standing = point + toCamera * 0.3 + [0, point.y < 0.01 ? 0.4 : 0, 0]
    refusalCross.look(at: eye, from: standing, relativeTo: nil)
    refusalCross.isEnabled = true
  }

  /// What the ray through a touch order's point meets first: one of the level's blocks, or the
  /// ground; nil when it meets neither.
  private func firstHit(at screen: InputRules.ScreenPoint) -> SIMD3<Float>? {
    let blocks = level.boxes.map { (centre: $0.position, size: $0.size) }
    return projection(aspect: screen.aspect).firstHit(
      atScreen: [screen.x, screen.y], blocks: blocks)
  }

  /// Companions told to hold where they are hold where they stand now.
  private func pinHolds() {
    for member in session.party where session.order(of: member) == .holding(nil) {
      if let point = position(of: member) { session.pin(member, at: point) }
    }
  }

  /// A ring at each going companion's point, until they arrive.
  private func showOrders() {
    for (member, ring) in orderMarkers {
      if member != session.leader, case .going(let point) = session.order(of: member) {
        ring.position = [point.x, 0.02, point.y]
        ring.isEnabled = true
      } else {
        ring.isEnabled = false
      }
    }
  }

  /// The camera's mapping between the screen and the ground, for a screen of this shape, through
  /// its lens as it is now.
  func projection(aspect: Float) -> CameraProjection {
    CameraProjection(
      eye: cameraTarget + level.cameraOffset, target: cameraTarget, fieldOfView: lens,
      aspect: aspect)
  }

  /// Where a member's body stands on the ground.
  private func position(of member: PartyMember) -> SIMD2<Float>? {
    bodies[member].map { SIMD2($0.position.x, $0.position.z) }
  }

  /// A trigger area shows its line the first time the leader walks into it in a run, and an
  /// encounter's area begins its fight once its beat is next.
  private func checkTriggers() {
    guard retryElapsed == nil, let position = self.position(of: session.leader) else { return }
    for trigger in level.triggers where trigger.area.contains(position) {
      if session.fire(trigger.id) { observation = trigger.line }
    }
    var inGatheringArea = false
    for encounter in level.encounters {
      guard case .area(let area) = encounter.start, area.contains(position) else { continue }
      // A scene for the whole party, such as the end of the opening, waits until everyone is
      // close; companions holding elsewhere must be called back first.
      if encounter.gathersParty, encounter.beat == session.nextBeat {
        inGatheringArea = true
        let missing = session.companions.filter { member in
          guard let point = self.position(of: member) else { return true }
          return simd_distance(point, position) > Self.gatherRadius
        }
        if !missing.isEmpty {
          if !toldWhoIsMissing, missing.contains(where: { session.order(of: $0) != .following }) {
            toldWhoIsMissing = true
            let names = missing.map(\.displayName).joined(separator: " and ")
            observation = "\(names) \(missing.count == 1 ? "is" : "are") not with you yet."
          }
          continue
        }
      }
      if session.beginEncounter(encounter.beat) {
        fight.begin(encounter)
        retrySpot = encounter.retryAt
      }
    }
    if !inGatheringArea { toldWhoIsMissing = false }
  }

  // MARK: - Fights

  /// One step of the fight rules, then their stage presentation; the world turns the leader,
  /// shows lines, the threat and who can answer it, and starts a retry
  /// or a fall back after the last hit. Only Miki carries the carbine and has Disrupt, and not
  /// while a scene holds her; outside an encounter, only her carbine acts (ADR 0007).
  private func stepStage(
    leader: PartyMember, at position: SIMD2<Float>, armed: Bool, dt: Float
  ) {
    let figures = Dictionary(
      uniqueKeysWithValues: PartyMember.allCases.compactMap { member in
        bodies[member]?.isEnabled == true ? self.position(of: member).map { (member, $0) } : nil
      })
    let outcome = fight.step(
      dt: dt, leader: position, facing: Movement.facing(yaw: yaw[leader] ?? 0),
      aiming: aimDirection != nil, fireHeld: armed && fireHeld,
      firePressed: armed && firePressPending,
      mayDisrupt: leaderHasSignature && !fight.holdsParty,
      signaturePressed: signaturePressPending, figures: figures, session: session)
    stage.update(fight, dt: dt)
    firePressPending = false
    signaturePressPending = false
    let cue = fight.canDisrupt ? "\(leader.displayName) can Disrupt" : nil
    if signatureCue != cue { signatureCue = cue }
    // The leader turns there in the steps to come, at her turn rate (ADR 0008).
    if let facing = outcome.facing { facingGoal = facing }
    // Members still rocking from a shot or a hit show it, and those that just settled stand
    // straight again.
    let jolted = Set(fight.jolts.keys)
    for member in jolted.union(joltedMembers) { showPose(member) }
    if let posedCoverLeader { showPose(posedCoverLeader) }
    if fight.coverState != nil { showPose(leader) }
    posedCoverLeader = fight.coverState == nil ? nil : leader
    joltedMembers = jolted
    combatEvents.append(contentsOf: fight.takeEvents())
    if combatEvents.count > Self.keptEvents {
      combatEvents.removeFirst(combatEvents.count - Self.keptEvents)
    }
    if let line = outcome.line { observation = line }
    for member in outcome.appeared { appear(member) }
    for member in outcome.stood {
      lying.remove(member)
      showPose(member)
    }
    if let shooter = outcome.shooter {
      setYaw(shooter.member, Movement.yaw(towards: shooter.facing))
    }
    if let (first, second) = outcome.face { faceEachOther(first, second) }
    let threat = fight.threat
    if self.threat != threat { self.threat = threat }
    if weaponDrawn != fight.isDrawn { weaponDrawn = fight.isDrawn }
    if outcome.retry { retryElapsed = 0 }
  }

  /// A member who has not joined appears where they wait, turned towards the nearest hostile
  /// in the open, or else towards the leader.
  private func appear(_ member: PartyMember) {
    guard let body = bodies[member], let here = position(of: member) else { return }
    body.isEnabled = true
    let standing = fight.hostiles.values.filter { $0.isVisible && !$0.isDown }.map(\.position)
    let focus =
      standing.min { simd_distance_squared($0, here) < simd_distance_squared($1, here) }
      ?? position(of: session.leader)
    if let focus, simd_distance(focus, here) > 0.01 {
      setYaw(member, Movement.yaw(towards: focus - here))
    }
  }

  /// Two members turn to face each other, as before a conversation.
  private func faceEachOther(_ first: PartyMember, _ second: PartyMember) {
    guard first != second, let a = position(of: first), let b = position(of: second) else {
      return
    }
    let offset = b - a
    guard simd_length(offset) > 0.01 else { return }
    setYaw(first, Movement.yaw(towards: offset))
    setYaw(second, Movement.yaw(towards: -offset))
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
    if level.combat.fallsBack {
      fallBack()
      return
    }
    session.retryEncounter()
    let spot = retrySpot ?? level.spawn(session.leader)
    place(session.leader, at: spot)
    setYaw(session.leader, Movement.yaw(towards: level.heading))
    resetPlay(around: spot)
    observation = "Try again."
  }

  /// The whole party falls back to the level's spawn points after the last allowed hit on
  /// anyone (ADR 0005): everyone's hits recover and every companion follows again, while the
  /// hostiles keep the damage dealt and wait where they stand, and whoever is down stays down.
  private func fallBack() {
    session.fallBack()
    fight.fallBack()
    stage.reset(fight)
    let facing = Movement.yaw(towards: level.heading)
    for member in session.party {
      place(member, at: level.spawn(member))
      setYaw(member, facing)
    }
    fallBacks += 1
    resetSquad(around: level.spawn(session.leader))
    showOrders()
    observation = "The party falls back to the entrance."
  }

  private func changeLeader() {
    let previous = squadLeader
    let leader = session.leader
    squadLeader = leader
    fight.clearCover()
    showPose(previous)
    facingGoal = nil
    if let point = position(of: leader) { route.reset(to: point) }
    planner.reset()
    cover.reset()
    for member in [previous, leader] { motors[member] = CompanionMotor(for: member) }
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

  /// Companions turn towards their movement, or towards their target while they fire by
  /// themselves, or to the formation's heading once settled, at a limited rate so they never
  /// snap round.
  private func turn(_ member: PartyMember, moved delta: SIMD2<Float>, dt: Float) {
    let wanted: Float
    if simd_length(delta) > 0.2 * dt {
      wanted = Movement.yaw(towards: delta)
    } else if let aim = fight.aims[member], let here = position(of: member),
      simd_distance(aim, here) > 0.01
    {
      // A companion firing by themselves faces their target (ADR 0005).
      wanted = Movement.yaw(towards: aim - here)
    } else if motors[member]?.isSettled == true {
      wanted = Movement.yaw(towards: planner.heading)
    } else {
      return
    }
    let current = yaw[member] ?? wanted
    setYaw(
      member,
      Movement.turn(from: current, towards: wanted, limit: Movement.companionTurnRate * dt))
  }

  /// The leader turns towards `direction` at her turn rate (ADR 0008). Once she faces where the
  /// fight asked her to turn, that request is done.
  private func turnLeader(_ leader: PartyMember, towards direction: SIMD2<Float>, dt: Float) {
    let wanted = Movement.yaw(towards: direction)
    let current = yaw[leader] ?? wanted
    let turned = Movement.turn(from: current, towards: wanted, limit: Movement.leaderTurnRate * dt)
    setYaw(leader, turned)
    if let goal = facingGoal, simd_length_squared(goal) > 0.000001,
      simd_dot(Movement.facing(yaw: turned), simd_normalize(goal)) > 0.99995
    {
      facingGoal = nil
    }
  }

  private func setYaw(_ member: PartyMember, _ angle: Float) {
    yaw[member] = angle
    showPose(member)
  }

  /// A member's facing, whether they lie face down on the deck, and how they rock for a moment
  /// after firing or being hit (ADR 0008).
  private func showPose(_ member: PartyMember) {
    let facing = simd_quatf(angle: yaw[member] ?? 0, axis: [0, 1, 0])
    if lying.contains(member) {
      visuals[member]?.scale = [1, 1, 1]
      visuals[member]?.orientation = facing * simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
      visuals[member]?.position = [0, Self.lyingDrop, 0]
      return
    }
    let cover = member == session.leader ? fight.coverState : nil
    let scale: Float = cover != nil && cover?.firing == false ? 0.68 : 1
    let offset = cover?.offset ?? .zero
    let jolt = (fight.jolts[member] ?? BodyJolt()).pose(height: PartyBody.height * scale)
    visuals[member]?.scale = [1, scale, 1]
    visuals[member]?.orientation = jolt.tilt * facing
    visuals[member]?.position =
      jolt.offset + [offset.x, -PartyBody.height * (1 - scale) / 2, offset.y]
  }

  /// Where each member of the party stands. Members who have not joined are not included.
  private var positions: [PartyMember: SIMD2<Float>] {
    Dictionary(
      uniqueKeysWithValues: session.party.compactMap { member in
        position(of: member).map { (member, $0) }
      })
  }

  private func updateActivity() {
    controls.setActive(isPresented && isApplicationActive)
    controls.requireNeutralInput()
    skipNextStep = true
  }

  private func updateCamera(deltaTime: Float) {
    guard let leader = position(of: session.leader) else { return }
    // During a fight the target leans towards the threat, so both stay on screen.
    let wanted = fight.cameraLean(leader: leader)
    cameraLean += (wanted - cameraLean) * min(1, deltaTime * Self.cameraLeanRate)
    let target = Self.cameraTarget(over: leader + cameraLean)
    if let start = cameraStart {
      cameraElapsed = min(0.25, cameraElapsed + deltaTime)
      let amount = cameraElapsed / 0.25
      let eased = amount * amount * (3 - 2 * amount)
      cameraTarget = start + (target - start) * eased
      if cameraElapsed >= 0.25 { cameraStart = nil }
    } else {
      cameraTarget = target
    }
    let eye = cameraTarget + level.cameraOffset
    camera.look(at: cameraTarget, from: eye, relativeTo: nil)
    // In a fight, or while the right stick aims, the lens narrows so the camera comes closer
    // through it, keeping its height and angle (ADR 0007, the visual direction); a scene keeps
    // the level's lens for its framing.
    let close = (session.inEncounter && !fight.holdsParty) || aimDirection != nil
    let goal = level.fieldOfView * (close ? Self.fightLens : 1)
    lens += (goal - lens) * min(1, deltaTime / Self.lensTime)
    if abs(camera.camera.fieldOfViewInDegrees - lens) > 0.001 {
      camera.camera.fieldOfViewInDegrees = lens
    }
    let party = ([session.leader] + session.companions).compactMap { bodies[$0]?.position }
    landmarkFade.update(eye: eye, seeing: party + [cameraTarget], deltaTime: deltaTime)
  }

  /// A new line or objective shows in the status panel for `lineTime` seconds of play, then
  /// leaves it to the essentials; Pause and conversations hold the time.
  private func ageLines(by dt: Float) {
    if lineCount != agedLineCount {
      agedLineCount = lineCount
      lineAge = 0
    } else {
      lineAge += dt
    }
    if objective != agedObjective {
      agedObjective = objective
      objectiveAge = 0
    } else {
      objectiveAge += dt
    }
    if (lineAge < Self.lineTime) != lineIsFresh { lineIsFresh.toggle() }
    if (objectiveAge < Self.lineTime) != objectiveIsFresh { objectiveIsFresh.toggle() }
  }

  /// The compass to the goal for the story's beat: its name, the distance from the leader, and
  /// its direction on screen, turned from up the screen towards its right.
  private func updateCompass() {
    guard let goal = level.goals.last(where: { $0.beat <= session.beat })?.goal,
      let leader = position(of: session.leader)
    else {
      if compass != nil { compass = nil }
      return
    }
    let toward = goal.point - leader
    let (forward, right) = Movement.axes(cameraOffset: level.cameraOffset)
    let degrees = (atan2(simd_dot(toward, right), simd_dot(toward, forward)) * 180 / .pi).rounded()
    let next = Compass(
      name: goal.name, metres: Int(simd_length(toward).rounded()), angle: degrees * .pi / 180)
    if next != compass { compass = next }
  }

  /// The compass, and the leader's action prompt where they stand.
  private func updatePromptAndCompass() {
    updateCompass()
    guard let player = bodies[session.leader] else { return }
    updatePrompt(at: SIMD2(player.position.x, player.position.z))
  }

  #if DEBUG
    /// What a scripted playtest can see each frame.
    var playtestSnapshot: PlaytestRunner.Snapshot {
      PlaytestRunner.Snapshot(
        level: level, leader: session.leader, party: session.party, positions: positions,
        mode: session.mode, firedTriggers: session.firedTriggers.count, beat: session.beat,
        hitsTaken: session.hitsTaken, defeated: session.defeated.count, ammo: session.ammo,
        formation: session.formation, orders: session.orders, squadState: session.squadState,
        line: gameLine, salvageContents: session.salvage.contents,
        refusedOrders: refusedOrders,
        camera: projection(aspect: PlaytestRunner.screenAspect), canDisrupt: signatureCue != nil,
        disrupts: disrupts, companionShots: companionShots, fallBacks: fallBacks,
        shotMarks: shotMarks, leaderCover: fight.coverState)
    }

    /// Start a scripted playtest; an unknown scenario name is reported on the HUD.
    func startPlaytest(_ scenario: String) {
      guard let runner = PlaytestRunner(scenario: scenario) else {
        observation =
          "Unknown playtest \"\(scenario)\". Try: "
          + PlaytestRunner.scenarioNames.joined(separator: ", ") + "."
        return
      }
      install(runner)
    }

    /// A playtest that another level's world began carries on here, after the pause menu's
    /// third choice made this world.
    func continuePlaytest(from other: GameWorld) {
      guard let runner = other.playtest else { return }
      other.playtest = nil
      install(runner)
    }

    private func install(_ runner: PlaytestRunner) {
      playtest = runner
      if let loadTiming { playtest?.recordLoad(loadTiming) }
      observation = runner.status
      // Small discs at each companion's target, so screenshots show where they are heading.
      let style = SceneStyle()
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
      // The playtest's status covers the HUD's line, while the game's own stays in `gameLine`.
      if let status = playtest?.status, shownLine != status {
        shownLine = status
        lineCount &+= 1
      }
    }
  #endif

  /// The leader's action prompt where they stand: a salvage task's action for whoever leads,
  /// or an interaction the session offers.
  private func updatePrompt(at position: SIMD2<Float>) {
    let salvage = level.salvage.flatMap { task in
      Self.place(at: position, in: task).flatMap {
        session.salvage.action(for: session.leader, at: $0)
      }
    }
    let name =
      salvage?.name
      ?? level.interactions.first { $0.approach.contains(position) && session.offers($0.id) }?.name
    if actionName != name { actionName = name }
  }

  // MARK: - Salvage

  /// Where in a salvage task a point lies, if anywhere (ADR 0006).
  private static func place(at point: SIMD2<Float>, in task: Level.Salvage)
    -> SalvageProgress.Place?
  {
    if task.latch.contains(point) { return .latch }
    if task.panel.contains(point) { return .panel }
    if let cabinet = task.cabinets.first(where: { $0.approach.contains(point) }) {
      return .cabinet(cabinet.id)
    }
    return task.transmitterApproach.contains(point) ? .transmitter : nil
  }

  /// Shows the salvage task as the session has it. Movement's blockers have the gate shut, or
  /// open as a thin wall into the depot, and change only when it does; the gate then swings
  /// open over a moment, or Restart shuts it at once. The rest shows in the looks.
  private func showSalvage() {
    guard let task = level.salvage, let ways = gateWays else { return }
    let progress = session.salvage
    if progress.gateOpen != gateShownOpen {
      gateShownOpen = progress.gateOpen
      (motion, grid) = progress.gateOpen ? ways.open : ways.shut
      if !progress.gateOpen {
        gateSwing = 0
        gateHinge?.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
      }
    }
    fight.setGate(progress.gateOpen ? task.openGate : task.gate.footprint)
    salvageLooks?.show(progress)
  }

  /// How long the salvage gate takes to swing open.
  static let gateSwingTime: Float = 0.8

  /// Swings the salvage gate on towards open while the session has it open, slowing as it goes.
  private func swingGate(by dt: Float) {
    guard let hinge = gateHinge, session.salvage.gateOpen, gateSwing < 1 else { return }
    gateSwing = min(1, gateSwing + dt / Self.gateSwingTime)
    let eased = 1 - (1 - gateSwing) * (1 - gateSwing)
    hinge.orientation = simd_quatf(angle: eased * .pi / 2, axis: [0, 1, 0])
  }

  /// The salvage gate, in rust like the world's other barriers, on a hinge at its west end: a
  /// quarter turn of the hinge swings it into the depot.
  private static func addGate(_ gate: Level.Box, to root: Entity, style: SceneStyle) -> Entity {
    let hinge = Entity()
    hinge.name = "\(gate.name).hinge"
    hinge.position = [gate.position.x - gate.size.x / 2, gate.position.y, gate.position.z]
    let leaf = style.block(size: gate.size, at: [gate.size.x / 2, 0, 0], material: style.rust)
    leaf.name = gate.name
    hinge.addChild(leaf)
    root.addChild(hinge)
    return hinge
  }

  /// How a salvage task shows what the party has done (ADR 0006), in the palette's meanings:
  /// - **The latch and the panel:** amber, as things to use, until the gate opens.
  /// - **The transmitter:** faded teal under ink aerials, then amber once repaired.
  /// - **Each cabinet:** a tag on its top once the party knows what it holds, amber for the right
  ///   regulator, stone for the wrong model and rust for the live equipment; ink once emptied.
  @MainActor
  private struct SalvageLooks {
    let marks: [ModelEntity]
    let transmitter: ModelEntity?
    let cabinets: [(id: String, body: ModelEntity, tag: ModelEntity)]
    let use: any Material
    let plain: any Material
    let broken: any Material
    let otherModel: any Material
    let live: any Material
    let empty: any Material

    /// The looks for a task whose blocks are already in `root`, by name, with the marks, the
    /// aerials and the cabinets' tags added to it.
    init(task: Level.Salvage, in root: Entity, style: SceneStyle) {
      func add(_ box: Level.Box, _ material: any Material) -> ModelEntity {
        let entity = style.block(size: box.size, at: box.position, material: material)
        entity.name = box.name
        root.addChild(entity)
        return entity
      }
      marks = [task.latchMark, task.panelMark].map { add($0, style.warm) }
      for part in task.aerial { _ = add(part, style.ink) }
      transmitter = root.findEntity(named: task.transmitter.name) as? ModelEntity
      cabinets = task.cabinets.compactMap { cabinet in
        guard let body = root.findEntity(named: cabinet.box.name) as? ModelEntity else {
          return nil
        }
        let box = cabinet.box
        let tag = add(
          .box(
            "\(cabinet.id).tag", at: box.position + [0, box.size.y / 2 + 0.04, 0],
            size: [box.size.x - 0.2, 0.08, box.size.z - 0.2]), style.warm)
        tag.isEnabled = false
        return (cabinet.id, body, tag)
      }
      use = style.warm
      plain = style.scenery
      broken = style.fadedTeal
      otherModel = style.stone
      live = style.rust
      empty = style.ink
    }

    func show(_ progress: SalvageProgress) {
      for mark in marks { mark.model?.materials = [progress.gateOpen ? plain : use] }
      transmitter?.model?.materials = [progress.repaired ? use : broken]
      for cabinet in cabinets {
        let emptied = progress.emptied.contains(cabinet.id)
        cabinet.body.model?.materials = [emptied ? empty : plain]
        let tag: (any Material)? =
          if emptied || !progress.known.contains(cabinet.id) {
            nil
          } else {
            switch progress.contents[cabinet.id] {
            case .compatible: use
            case .otherModel: otherModel
            case .live, nil: live
            }
          }
        cabinet.tag.isEnabled = tag != nil
        if let tag { cabinet.tag.model?.materials = [tag] }
      }
    }
  }

  private static func freshMotors() -> [PartyMember: CompanionMotor] {
    Dictionary(uniqueKeysWithValues: PartyMember.allCases.map { ($0, CompanionMotor(for: $0)) })
  }
}
