import RealityKit
import Testing
import simd

@testable import Lauder

/// Party C: the keeper's briefing, one regulator, the repair, the crew call, Read plan and an
/// in-place Restart.
@MainActor
struct PartyCTests {
  private let transmitter = SIMD2<Float>(-8.8, 2)
  private let housing = SIMD2<Float>(6.2, -4.2)
  private let latch = SIMD2<Float>(3.2, -5)
  private let panel = SIMD2<Float>(3.2, -4)
  private static let missionSteps: [(Level.ActionID, PartyMember)] = [
    (.hearBriefing, .miki), (.takeRegulator, .miki), (.repairTransmitter, .miki),
    (.callCrew, .laura),
  ]

  // MARK: - Session rules

  @Test
  func theMissionAdvancesThroughItsPhasesInOrderAndOnlyOnce() {
    let session = GameSession(level: RelayHouse.level)
    #expect(session.perform(.takeRegulator, by: .miki) == .notYet)
    #expect(session.perform(.repairTransmitter, by: .miki) == .notYet)
    #expect(session.perform(.callCrew, by: .laura) == .notYet)
    #expect(session.perform(.readPlan, by: .tom) == .notYet)
    // Any leader can hear the briefing.
    #expect(session.perform(.hearBriefing, by: .tom) == .done)
    finish(session)
    #expect(session.phase == .seekingRegulator)
    #expect(session.perform(.hearBriefing, by: .miki) == .alreadyDone)
    #expect(session.perform(.takeRegulator, by: .laura) == .notEligible)
    #expect(session.perform(.takeRegulator, by: .miki) == .done)
    finish(session)
    #expect(session.carriesRegulator)
    #expect(session.perform(.takeRegulator, by: .miki) == .alreadyDone)
    #expect(session.perform(.repairTransmitter, by: .tom) == .notEligible)
    #expect(session.perform(.repairTransmitter, by: .miki) == .done)
    finish(session)
    #expect(session.phase == .radioRepaired)
    #expect(!session.carriesRegulator)
    #expect(session.perform(.repairTransmitter, by: .miki) == .alreadyDone)
    #expect(session.perform(.callCrew, by: .laura) == .done)
    finish(session)
    #expect(session.phase == .meetingAgreed)
    #expect(session.perform(.callCrew, by: .tom) == .alreadyDone)
    // The passage is separate progress: still closed, and either method still works.
    #expect(!session.passageOpen)
    #expect(session.perform(.shiftPanel, by: .tom) == .done)
  }

  @Test
  func aStepTakesEffectWhenItsConversationEnds() {
    let session = session(at: .radioRepaired)
    #expect(session.perform(.callCrew, by: .tom) == .done)
    #expect(session.phase == .radioRepaired)
    session.togglePause()
    session.togglePause()
    #expect(session.phase == .radioRepaired)
    finish(session)
    #expect(session.phase == .meetingAgreed)
    // Restart part-way through a conversation discards its step.
    let restarted = self.session(at: .seekingRegulator)
    _ = restarted.perform(.takeRegulator, by: .miki)
    restarted.togglePause()
    restarted.restart()
    #expect(restarted.phase == .briefing)
    #expect(!restarted.carriesRegulator)
    #expect(restarted.conversation == nil)
  }

  @Test
  func repairWithoutThePartExplainsAndChangesNothing() {
    let session = session(at: .seekingRegulator)
    #expect(session.perform(.repairTransmitter, by: .miki) == .missingPart)
    #expect(session.phase == .seekingRegulator)
    #expect(session.mode == .exploring)
    #expect(session.conversation == nil)
  }

  @Test
  func readingThePlanRepeatsTheDetailsWithoutChangingProgress() {
    let session = session(at: .meetingAgreed)
    for member in PartyMember.allCases {
      #expect(session.perform(.readPlan, by: member) == .done)
      #expect(session.conversation == .plan)
      finish(session)
      #expect(session.phase == .meetingAgreed)
    }
  }

  @Test
  func eachPhaseOffersExactlyOneTransmitterAction() {
    let actions: [Level.ActionID] = [
      .hearBriefing, .repairTransmitter, .callCrew, .readPlan,
    ]
    for phase in GameSession.Phase.allCases {
      let session = session(at: phase)
      #expect(session.phase == phase)
      #expect(actions.filter { session.offers($0) }.count == 1, "\(phase)")
    }
  }

  @Test
  func aConversationHoldsActionsAndSwitchingUntilItsLastLine() {
    let session = GameSession(level: RelayHouse.level)
    #expect(session.perform(.hearBriefing, by: .miki) == .done)
    #expect(session.mode == .dialogue)
    #expect(session.currentLine == MissionScript.lines(.briefing).first)
    session.cycleLeader()
    #expect(session.leader == .miki)
    #expect(session.perform(.reachLatch, by: .laura) == .unavailable)
    for line in MissionScript.lines(.briefing).dropFirst() {
      session.advanceDialogue()
      #expect(session.currentLine == line)
    }
    session.advanceDialogue()
    #expect(session.mode == .exploring)
    #expect(session.currentLine == nil)
  }

  @Test
  func pauseKeepsTheConversationAtItsLine() {
    let session = GameSession(level: RelayHouse.level)
    _ = session.perform(.hearBriefing, by: .miki)
    session.advanceDialogue()
    let line = session.currentLine
    session.togglePause()
    #expect(session.mode == .paused)
    session.advanceDialogue()
    #expect(session.currentLine == line)
    session.togglePause()
    #expect(session.mode == .dialogue)
    #expect(session.currentLine == line)
  }

  @Test
  func thePauseMenuOpensOnResumeAndHasTwoChoices() {
    let session = GameSession(level: RelayHouse.level)
    session.movePauseChoice(by: 1)
    session.togglePause()
    #expect(session.pauseChoice == .resume)
    session.movePauseChoice(by: 1)
    #expect(session.pauseChoice == .restart)
    session.movePauseChoice(by: 1)
    #expect(session.pauseChoice == .restart)
    session.movePauseChoice(by: -1)
    #expect(session.pauseChoice == .resume)
    session.movePauseChoice(by: 1)
    session.togglePause()
    session.togglePause()
    #expect(session.pauseChoice == .resume)
  }

  @Test
  func sessionRestartReturnsToTheBeginning() {
    let session = session(at: .meetingAgreed)
    _ = session.perform(.reachLatch, by: .laura)
    session.cycleLeader()
    _ = session.perform(.readPlan, by: .laura)
    session.togglePause()
    session.movePauseChoice(by: 1)
    session.restart()
    #expect(session.mode == .exploring)
    #expect(session.leader == .miki)
    #expect(session.phase == .briefing)
    #expect(!session.passageOpen)
    #expect(session.conversation == nil)
    #expect(session.pauseChoice == .resume)
    // Pause after Restart resumes to exploring, not to the old conversation.
    session.togglePause()
    session.togglePause()
    #expect(session.mode == .exploring)
  }

  @Test
  func everyConversationAndLandmarkIsDefined() {
    for conversation in MissionScript.Conversation.allCases {
      let lines = MissionScript.lines(conversation)
      #expect(!lines.isEmpty, "\(conversation)")
      #expect(lines.allSatisfy { !$0.speaker.isEmpty && !$0.text.isEmpty })
    }
    for id in RelayHouse.PointID.allCases {
      #expect(RelayHouse.points.filter { $0.id == id.rawValue }.count == 1, "\(id.rawValue)")
    }
  }

  // MARK: - Approaches

  @Test
  func approachesAreOnTheUsableSideOfTheirWalls() {
    let closed = NavigationGrid(level: RelayHouse.level, passageOpen: false)
    let open = NavigationGrid(level: RelayHouse.level, passageOpen: true)
    // The housing's approach lies inside the depot, reachable only through the open passage.
    let depot = RelayHouse.housingApproach
    #expect(isInDepot(depot.minimum) && isInDepot(depot.maximum))
    #expect(closed.route(from: [-6, 3], to: housing) == nil)
    #expect(open.route(from: [-6, 3], to: housing) != nil)
    // The transmitter's lies inside the shelter, in front of its back wall, and the party
    // starts in it.
    let shelter = RelayHouse.box(.shelterBack)
    #expect(
      RelayHouse.transmitterApproach.minimum.y > shelter.position.z + shelter.size.z / 2)
    #expect(closed.route(from: [-6, 3], to: transmitter) != nil)
    let start = RelayHouse.spawn(for: .miki)
    #expect(RelayHouse.transmitterApproach.contains(SIMD2(start.x, start.z)))
  }

  // MARK: - The world

  @Test
  func theWholeLoopWorksAcrossLeaderChanges() throws {
    let world = GameWorld(level: RelayHouse.level)
    // The briefing, with Tom leading.
    lead(world, .tom)
    try walk(world, to: [transmitter])
    #expect(world.actionName == "Talk to keeper")
    world.performAction()
    #expect(world.session.mode == .dialogue)
    finish(world)
    #expect(world.session.phase == .seekingRegulator)
    // Tom opens the passage, then finds that only Miki can take the regulator.
    try walk(world, to: [[2.5, 3], panel])
    world.performAction()
    #expect(world.session.passageOpen)
    try walk(world, to: [[2.5, -4.5], [5, -4.5], housing])
    #expect(world.actionName == nil)
    #expect(world.hint == RelayHouse.interaction(.takeRegulator).suggestion)
    world.performAction()
    #expect(world.session.phase == .seekingRegulator)
    lead(world, .miki)
    try walk(world, to: [housing])
    #expect(world.actionName == "Take regulator")
    world.performAction()
    // Miki inspects first; the part leaves its housing when her conversation ends.
    #expect(world.session.conversation == .inspection)
    #expect(entity(world, "depot.regulator.part")?.isEnabled == true)
    finish(world)
    #expect(world.session.carriesRegulator)
    #expect(entity(world, "depot.regulator.part")?.isEnabled == false)
    // The part stays with the party through every switch.
    for _ in 0..<3 {
      world.session.cycleLeader()
      #expect(world.session.carriesRegulator)
    }
    // Back at the transmitter Laura cannot fit it; Miki can, once.
    lead(world, .laura)
    try walk(world, to: [[5, -4.5], [2.5, -4.5], [2.5, 3], transmitter])
    #expect(world.hint == RelayHouse.interaction(.repairTransmitter).suggestion)
    world.performAction()
    #expect(world.session.phase == .carryingRegulator)
    lead(world, .miki)
    try walk(world, to: [transmitter])
    #expect(world.actionName == "Repair")
    world.performAction()
    finish(world)
    #expect(world.session.phase == .radioRepaired)
    #expect(entity(world, "relay.transmitter.ready")?.isEnabled == true)
    #expect(entity(world, "relay.transmitter.fault")?.isEnabled == false)
    #expect(entity(world, "relay.transmitter.regulator")?.isEnabled == true)
    // Anyone can call. Then anyone can reread the plan, which changes nothing.
    lead(world, .tom)
    try walk(world, to: [transmitter])
    #expect(world.actionName == "Call")
    world.performAction()
    finish(world)
    #expect(world.session.phase == .meetingAgreed)
    #expect(world.observation == RelayHouse.interaction(.callCrew).result)
    #expect(world.actionName == "Read plan")
    world.performAction()
    #expect(world.session.conversation == .plan)
    finish(world)
    #expect(world.session.phase == .meetingAgreed)
    #expect(world.diagnostic == nil)
  }

  @Test
  func mikiCannotRepairWithoutTheRegulator() {
    let world = GameWorld(level: RelayHouse.level)
    world.performAction()
    finish(world)
    #expect(world.actionName == "Repair")
    world.performAction()
    #expect(world.observation == MissionScript.missingPart)
    #expect(world.session.phase == .seekingRegulator)
    #expect(world.session.mode == .exploring)
  }

  @Test
  func theRegulatorWaitsForTheBriefing() throws {
    let world = GameWorld(level: RelayHouse.level)
    lead(world, .laura)
    try walk(world, to: [[2.5, 3], latch])
    world.performAction()
    lead(world, .miki)
    try walk(world, to: [[2.5, -4.5], [5, -4.5], housing])
    #expect(world.actionName == nil)
    world.performAction()
    #expect(world.observation == RelayHouse.interaction(.takeRegulator).early)
    #expect(world.session.phase == .briefing)
    #expect(entity(world, "depot.regulator.part")?.isEnabled == true)
  }

  @Test
  func theRegulatorPromptDoesNotOutliveASwitchOrAMove() throws {
    let world = GameWorld(level: RelayHouse.level)
    world.performAction()
    finish(world)
    lead(world, .tom)
    try walk(world, to: [[2.5, 3], panel])
    world.performAction()
    lead(world, .miki)
    try walk(world, to: [[2.5, -4.5], [5, -4.5], housing])
    #expect(world.actionName == "Take regulator")
    world.session.cycleLeader()
    world.performAction()
    #expect(world.session.phase == .seekingRegulator)
    lead(world, .miki)
    try walk(world, to: [[5, -2]])
    #expect(world.actionName == nil)
    world.performAction()
    #expect(world.session.phase == .seekingRegulator)
  }

  @Test
  func inAConversationTheActionOnlyShowsTheNextLine() {
    let world = GameWorld(level: RelayHouse.level)
    clearReleaseGate(world)
    world.performAction()
    #expect(world.session.mode == .dialogue)
    let before = positions(world)
    let press = InputRules.Input(
      movement: [1, 0], actionPressed: true, pausePressed: false, switchPressed: true)
    world.update(with: press, sampledIn: .dialogue, deltaTime: 1 / 60)
    #expect(world.session.lineIndex == 1)
    #expect(world.session.leader == .miki)
    #expect(positions(world) == before)
  }

  @Test
  func thePauseMenuConfirmsItsChoiceAndNeverActsOnANearbyObject() throws {
    let world = GameWorld(level: RelayHouse.level)
    clearReleaseGate(world)
    lead(world, .laura)
    try walk(world, to: [[2.5, 3], latch])
    #expect(world.actionName == "Reach latch")
    let pause = InputRules.Input(
      movement: .zero, actionPressed: false, pausePressed: true, switchPressed: false)
    let action = InputRules.Input(
      movement: .zero, actionPressed: true, pausePressed: false, switchPressed: false)
    let down = InputRules.Input(
      movement: .zero, actionPressed: false, pausePressed: false, switchPressed: false,
      menuMove: 1)
    let before = positions(world)
    // Confirming at once resumes: the menu opens on Resume. The latch stays shut.
    world.update(with: pause, sampledIn: .exploring, deltaTime: 1 / 60)
    #expect(world.session.isPaused)
    world.update(
      with: InputRules.Input(
        movement: [1, 0], actionPressed: false, pausePressed: false, switchPressed: true),
      sampledIn: .paused, deltaTime: 1 / 60)
    #expect(world.session.leader == .laura)
    world.update(with: action, sampledIn: .paused, deltaTime: 1 / 60)
    #expect(world.session.mode == .exploring)
    #expect(!world.session.passageOpen)
    #expect(positions(world) == before)
    #expect(world.controls.needsNeutralInput)
    // Down, then confirm, restarts.
    world.performAction()
    #expect(world.session.passageOpen)
    world.update(with: pause, sampledIn: .exploring, deltaTime: 1 / 60)
    world.update(with: down, sampledIn: .paused, deltaTime: 1 / 60)
    #expect(world.session.pauseChoice == .restart)
    world.update(with: action, sampledIn: .paused, deltaTime: 1 / 60)
    #expect(world.session.mode == .exploring)
    #expect(!world.session.passageOpen)
    #expect(world.session.leader == .miki)
    #expect(world.controls.needsNeutralInput)
    // The touch Restart button restarts directly from the menu.
    lead(world, .tom)
    world.update(with: pause, sampledIn: .exploring, deltaTime: 1 / 60)
    world.update(
      with: InputRules.Input(
        movement: .zero, actionPressed: false, pausePressed: false, switchPressed: false,
        restartPressed: true),
      sampledIn: .paused, deltaTime: 1 / 60)
    #expect(world.session.leader == .miki)
    #expect(world.session.mode == .exploring)
  }

  @Test
  func restartResetsTheWorldInPlaceWithoutDuplicates() throws {
    let world = GameWorld(level: RelayHouse.level)
    let entities = descendants(world.root)
    // Some progress first: the briefing, the passage and the regulator.
    world.performAction()
    finish(world)
    lead(world, .laura)
    try walk(world, to: [[2.5, 3], latch])
    world.performAction()
    lead(world, .miki)
    try walk(world, to: [[2.5, -4.5], [5, -4.5], housing])
    world.performAction()
    finish(world)
    #expect(world.session.carriesRegulator)
    for _ in 0..<3 {
      world.restart()
      #expect(descendants(world.root) == entities)
      #expect(world.root.children.filter { $0.name.hasPrefix("party.") }.count == 3)
      #expect(world.session.phase == .briefing)
      #expect(world.session.leader == .miki)
      #expect(!world.session.passageOpen)
      #expect(world.session.mode == .exploring)
      for member in PartyMember.allCases {
        let spawn = RelayHouse.spawn(for: member)
        #expect(simd_distance(position(world, member), SIMD2(spawn.x, spawn.z)) < 0.001)
      }
      #expect(entity(world, "passage.barrier")?.isEnabled == true)
      #expect(entity(world, "depot.regulator.part")?.isEnabled == true)
      #expect(entity(world, "relay.transmitter.fault")?.isEnabled == true)
      #expect(entity(world, "relay.transmitter.ready")?.isEnabled == false)
      #expect(entity(world, "relay.transmitter.regulator")?.isEnabled == false)
      #expect(world.observation == MissionScript.opening)
      #expect(world.actionName == "Talk to keeper")
      #expect(world.diagnostic == nil)
    }
    // The barrier blocks again, and the new run plays from the start.
    try walk(world, to: [[2.5, 3], [2.5, -4.5]])
    try walk(world, to: [[5, -4.5]], allowFailure: true)
    #expect(position(world, .miki).x < 4)
    world.restart()
    world.performAction()
    finish(world)
    #expect(world.session.phase == .seekingRegulator)
  }

  // MARK: - Helpers

  private func session(at phase: GameSession.Phase) -> GameSession {
    let session = GameSession(level: RelayHouse.level)
    for (action, member) in Self.missionSteps where session.phase < phase {
      _ = session.perform(action, by: member)
      finish(session)
    }
    return session
  }

  private func finish(_ session: GameSession) {
    for _ in 0..<20 where session.mode == .dialogue { session.advanceDialogue() }
  }

  /// Show every line through the world's input path, so a step's effects appear as in play.
  private func finish(_ world: GameWorld) {
    let press = InputRules.Input(
      movement: .zero, actionPressed: true, pausePressed: false, switchPressed: false)
    for _ in 0..<20 where world.session.mode == .dialogue {
      world.update(with: press, sampledIn: .dialogue, deltaTime: 1 / 60)
    }
  }

  /// A neutral sample clears the release gate a new world starts with.
  private func clearReleaseGate(_ world: GameWorld) {
    _ = world.controls.resolve(InputRules.Raw(), mode: world.session.mode)
  }

  private func lead(_ world: GameWorld, _ member: PartyMember) {
    while world.session.leader != member { world.session.cycleLeader() }
  }

  private func stick(towards direction: SIMD2<Float>) -> SIMD2<Float> {
    let toCamera = SIMD2(RelayHouse.cameraOffset.x, RelayHouse.cameraOffset.z)
    let forward = -simd_normalize(toCamera)
    let right = SIMD2(-forward.y, forward.x)
    let unit = simd_normalize(direction)
    return SIMD2(simd_dot(unit, right), simd_dot(unit, forward))
  }

  private func isInDepot(_ point: SIMD2<Float>) -> Bool {
    point.x > 4.2 && point.x < 9.8 && point.y > -6.8 && point.y < -1.2
  }

  private func entity(_ world: GameWorld, _ name: String) -> Entity? {
    world.root.findEntity(named: name)
  }

  private func descendants(_ entity: Entity) -> Int {
    entity.children.reduce(entity.children.count) { $0 + descendants($1) }
  }

  private func position(_ world: GameWorld, _ member: PartyMember) -> SIMD2<Float> {
    guard let body = world.root.findEntity(named: "party.\(member.rawValue)") else {
      return [.nan, .nan]
    }
    return SIMD2(body.position.x, body.position.z)
  }

  private func positions(_ world: GameWorld) -> [PartyMember: SIMD2<Float>] {
    Dictionary(uniqueKeysWithValues: PartyMember.allCases.map { ($0, position(world, $0)) })
  }

  /// Steer the leader through the points. With `allowFailure`, stop quietly after five seconds
  /// at a point the leader cannot reach.
  private func walk(
    _ world: GameWorld, to points: [SIMD2<Float>], allowFailure: Bool = false
  ) throws {
    for point in points {
      var frame = 0
      while simd_distance(position(world, world.session.leader), point) >= 0.15 {
        world.advanceParty(
          movement: stick(towards: point - position(world, world.session.leader)),
          deltaTime: 1 / 60)
        frame += 1
        if allowFailure, frame > 60 * 5 { return }
        try #require(frame < 60 * 30, "the leader did not reach \(point)")
      }
    }
  }
}
