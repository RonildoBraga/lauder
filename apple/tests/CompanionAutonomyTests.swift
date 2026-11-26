import Testing
import simd

@testable import Lauder

/// Companion decisions still execute through native actor-owned weapons and the real world.
@MainActor
struct CompanionAutonomyTests {
  #if DEBUG
    @Test
    func mikiCanKeepLeadingWhileLauraAndTomCompleteTheirOwnSteps() throws {
      let world = GameWorld(level: BrooklynBridge.level)
      walk(world, to: [6.5, 10])
      var runner = PlaytestRunner(steps: [.companionFight], name: "companion-contract")
      var sawLauraAttack = false
      var sawTomAttack = false
      let lauraStart = position(world, .laura)
      var lauraTravel: Float = 0
      for _ in 0..<(60 * 92) where !runner.isFinished {
        runner.tick(dt: 1 / 60)
        let before = world.playtestSnapshot
        let raw = runner.input(before)
        #expect(!raw.controllerSwitch && !raw.keyboardSwitch && !raw.touchSwitch)
        if before.guardStrategy?.sensorDisabled == true {
          #expect(!raw.controllerFire && !raw.keyboardFire && !raw.touchFire)
        }
        update(world, raw: raw)
        let after = world.playtestSnapshot
        #expect(after.leader == .miki)
        sawLauraAttack = sawLauraAttack || after.companionActivities[.laura] == .attacking
        sawTomAttack = sawTomAttack || after.companionActivities[.tom] == .attacking
        lauraTravel = max(lauraTravel, simd_distance(position(world, .laura), lauraStart))
        runner.record(
          PlaytestRunner.Frame(
            dt: 1 / 60, leader: after.leader, positions: after.positions,
            targets: world.companionTargets, warning: world.diagnostic, simulationMilliseconds: 0))
      }
      let summary = try #require(runner.summary)
      #expect(summary.passed, "\(summary.failures)")
      #expect(world.session.defeated == ["stranger"] && world.session.leader == .miki)
      #expect(sawLauraAttack && sawTomAttack && lauraTravel > 1)
      #expect(world.playtestSnapshot.guardStrategy?.phase == .complete)
    }

    @Test
    func autonomousMikiAndLauraCanPrepareTheCoreWhileTomKeepsPlayerControl() throws {
      let world = GameWorld(level: BrooklynBridge.level)
      update(world)
      update(world, raw: InputRules.Raw(controllerSwitch: true))
      update(world)
      try #require(world.session.leader == .tom)
      var sawMikiAttack = false
      var sawLauraAttack = false
      for destination: SIMD2<Float> in [[6.5, 30], [6.5, 10]] {
        for _ in 0..<60 * 60 {
          let offset = destination - position(world, .tom)
          if simd_length(offset) < 0.2 { break }
          update(
            world,
            raw: InputRules.Raw(
              stick: Movement.stick(
                towards: offset, cameraOffset: world.level.cameraOffset)))
          try #require(!world.isRetrying, "the ordinary approach retried")
          #expect(world.session.leader == .tom)
          sawMikiAttack =
            sawMikiAttack || world.playtestSnapshot.companionActivities[.miki] == .attacking
          sawLauraAttack =
            sawLauraAttack || world.playtestSnapshot.companionActivities[.laura] == .attacking
        }
        try #require(simd_distance(position(world, .tom), destination) < 0.2)
      }
      var lastDodge: Float = -10
      var releaseDodge = false
      for frame in 0..<60 * 60 {
        let snapshot = world.playtestSnapshot
        sawMikiAttack = sawMikiAttack || snapshot.companionActivities[.miki] == .attacking
        sawLauraAttack = sawLauraAttack || snapshot.companionActivities[.laura] == .attacking
        if snapshot.guardStrategy?.couplingBreached == true { break }
        let centre = try #require(snapshot.robotPosition)
        let facing = try #require(snapshot.robotFacing)
        let at = position(world, .tom)
        let radial = at - centre
        var raw = InputRules.Raw()
        if releaseDodge {
          releaseDodge = false
        } else if snapshot.robotPhase == .committed,
          Float(frame) / 60 - lastDodge > 1, simd_length(radial) > 0.1
        {
          let tangent = simd_normalize(SIMD2(-radial.y, radial.x))
          let movement = PartyMotion(radius: PartyBody.radius, obstacles: world.level.obstacles)
          let escape = movement.canTraverse(from: at, to: at + tangent * 3) ? tangent : -tangent
          raw.stick = Movement.stick(towards: escape, cameraOffset: world.level.cameraOffset)
          raw.controllerDodge = true
          releaseDodge = true
          lastDodge = Float(frame) / 60
        } else if snapshot.robotPhase != .committed && snapshot.robotPhase != .burst {
          let destination = centre + facing * 4.5
          if simd_distance(at, destination) > 0.25 {
            raw.stick = Movement.stick(
              towards: destination - at, cameraOffset: world.level.cameraOffset)
          }
        }
        // No player Fire, aim assistance, weapon swap or subsequent leader switch supplies
        // either prerequisite. These inputs only position/defend the player-controlled Tom.
        update(world, raw: raw)
        try #require(!world.isRetrying, "the autonomous prerequisite fight retried")
        #expect(world.session.leader == .tom)
      }
      let result = world.playtestSnapshot
      #expect(result.guardStrategy?.sensorDisabled == true)
      #expect(result.guardStrategy?.couplingBreached == true)
      #expect(result.guardStrategy?.phase == .reactor)
      #expect(sawMikiAttack && sawLauraAttack)
      #expect(result.guardStrategy?.reactorDamage == 0 && world.session.defeated.isEmpty)
      #expect(result.weapon.kind == .minigun && result.weapon.loaded == Weapon.minigun.capacity)
    }

    @Test
    func aQuietWestBypassDoesNotBecomeAnAutonomousFight() {
      let world = GameWorld(level: BrooklynBridge.level)
      walk(world, to: [-6.5, 30])
      walk(world, to: [-6.5, 15])
      for _ in 0..<60 * 6 { update(world) }
      let before = world.playtestSnapshot
      #expect(before.robotPhase == .patrol && before.robotShots == 0)
      #expect(before.guardStrategy?.sensorDisabled == false)
      #expect(!before.companionActivities.values.contains(.attacking))
      walk(world, to: [-6.5, -3])
      walk(world, to: [-8.5, -8])
      #expect(!world.session.inEncounter && world.session.defeated.isEmpty)
      #expect(world.session.leader == .miki && !world.isRetrying)
    }

    @Test
    func holdAnchorsAndGoDestinationsKeepMovementAuthorityInAnEngagedFight() throws {
      let world = GameWorld(level: BrooklynBridge.level)
      walk(world, to: [6.5, 10])
      update(world)
      update(world, raw: InputRules.Raw(dpadDown: true))
      update(world)
      var anchors: [PartyMember: SIMD2<Float>] = [:]
      for member in [PartyMember.laura, .tom] {
        if case .holding(let point?) = world.session.order(of: member) {
          anchors[member] = point
        } else {
          Issue.record("Hold did not establish an anchor for \(member)")
          return
        }
      }
      for _ in 0..<60 * 2 {
        update(world)
        for member in [PartyMember.laura, .tom] {
          #expect(world.session.order(of: member) == .holding(anchors[member]))
          #expect(world.companionTargets[member] == anchors[member])
        }
      }
      for member in [PartyMember.laura, .tom] {
        let anchor = try #require(anchors[member])
        // Hold pins the command-time anchor; the existing motor decelerates and settles
        // within its normal arrival distance, rather than teleporting onto that anchor.
        #expect(simd_distance(position(world, member), anchor) <= CompanionMotor.settleDistance)
        #expect(world.session.order(of: member) == .holding(anchor))
      }
      let start = position(world, .laura)
      let destination = start + [-1.5, 0]
      #expect(
        PartyMotion(radius: PartyBody.radius, obstacles: world.level.obstacles)
          .canTraverse(from: start, to: destination))
      #expect(world.session.send(.laura, to: destination))
      var observedOrdered = false
      for _ in 0..<60 * 3 {
        update(world)
        observedOrdered =
          observedOrdered || world.playtestSnapshot.companionActivities[.laura] == .ordered
        if case .holding = world.session.order(of: .laura) { break }
      }
      #expect(observedOrdered)
      #expect(world.session.order(of: .laura) == .holding(destination))
      #expect(simd_distance(position(world, .laura), destination) <= GameWorld.arrivalDistance)
      #expect(world.session.order(of: .tom) == .holding(anchors[.tom]))
      #expect(world.companionTargets[.tom] == anchors[.tom])
      #expect(
        simd_distance(position(world, .tom), try #require(anchors[.tom]))
          <= CompanionMotor.settleDistance)
      #expect(world.playtestSnapshot.guardStrategy?.couplingBreached == false)
    }

    @Test
    func pauseFreezesAutonomousMovementTurningAndGuardProgress() throws {
      let world = GameWorld(level: BrooklynBridge.level)
      walk(world, to: [6.5, 10])
      var runner = PlaytestRunner(steps: [.companionFight], name: "companion-pause")
      for _ in 0..<60 * 25 where world.playtestSnapshot.guardStrategy?.sensorDisabled != true {
        runner.tick(dt: 1 / 60)
        update(world, raw: runner.input(world.playtestSnapshot))
      }
      #expect(world.playtestSnapshot.guardStrategy?.sensorDisabled == true)
      pressPause(world)
      let before = world.playtestSnapshot
      let facings = Dictionary(
        uniqueKeysWithValues: PartyMember.allCases.map { ($0, world.facing(of: $0)) })
      for _ in 0..<60 * 3 {
        world.update(with: .neutral, sampledIn: .paused, deltaTime: 1 / 60)
      }
      let after = world.playtestSnapshot
      #expect(after.positions == before.positions && after.guardStrategy == before.guardStrategy)
      #expect(after.robotShots == before.robotShots && after.robotPhase == before.robotPhase)
      #expect(after.weapon.loaded == before.weapon.loaded)
      for member in PartyMember.allCases { #expect(world.facing(of: member) == facings[member]) }
    }

    private func update(_ world: GameWorld, raw: InputRules.Raw = InputRules.Raw()) {
      let mode = world.session.mode
      world.update(
        with: world.controls.resolve(raw, mode: mode), sampledIn: mode, deltaTime: 1 / 60)
    }
  #endif

  @Test
  func aCompanionUsesItsOwnMagazineCadenceAndPausedWeaponClock() throws {
    let range = try NativeRange()
    try range.openCore()
    let mikiLoaded = range.fight.status(for: .miki).loaded
    _ = try #require(range.firstTomShot())
    #expect(range.fight.status(for: .tom).loaded == Weapon.minigun.capacity - 1)
    for _ in 0..<5 {
      range.stepTom()
      #expect(!range.fight.shots.contains { $0.actor == .tom })
    }
    let before = range.fight.status(for: .tom)
    range.session.togglePause()
    for _ in 0..<240 { range.stepTom() }
    #expect(range.fight.status(for: .tom).loaded == before.loaded)
    #expect(range.fight.status(for: .tom).reloadRemaining == before.reloadRemaining)
    range.session.togglePause()
    var shots = 0
    for _ in 0..<5 {
      range.stepTom()
      shots += range.fight.shots.filter { $0.actor == .tom }.count
    }
    #expect(shots == 1 && range.fight.status(for: .tom).loaded == Weapon.minigun.capacity - 2)
    #expect(range.fight.status(for: .miki).loaded == mikiLoaded)
    #expect(
      range.fight.takeEvents().contains {
        if case .fired(.minigun, _, let byLeader) = $0 { !byLeader } else { false }
      })
  }

  @Test
  func aStaleCompanionIntentCannotFireTheNewPlayerLeader() throws {
    let range = try NativeRange()
    try range.openCore()
    _ = try #require(range.firstTomShot())
    let loaded = range.fight.status(for: .tom).loaded
    range.session.cycleLeader()
    #expect(range.session.leader == .tom)
    for _ in 0..<240 {
      range.stepTom()
      #expect(!range.fight.shots.contains { $0.actor == .tom })
    }
    #expect(range.fight.status(for: .tom).loaded == loaded)
    #expect(range.strategy.reactorDamage < GuardStrategy.reactorDamageRequired)
  }

  @Test
  func companionsMustActuallyTurnAndHaveUnobstructedRaysBeforeSpendingRounds() throws {
    let turning = try NativeRange()
    try turning.openCore()
    for _ in 0..<120 { turning.stepTom(facingAway: true) }
    #expect(turning.fight.status(for: .tom).loaded == Weapon.minigun.capacity)
    #expect(try #require(turning.firstTomShot()).actor == .tom)

    let wall = Level.Box.box("cover", at: [6, 2, 0], size: [0.5, 4, 30])
    let covered = try NativeRange(boxes: [wall])
    try covered.openCore()
    for _ in 0..<120 {
      covered.stepTom(at: [9, 0])
      #expect(!covered.fight.shots.contains { $0.actor == .tom })
    }
    #expect(covered.fight.status(for: .tom).loaded == Weapon.minigun.capacity)
    #expect(covered.strategy.reactorDamage == 0)
    #expect(try #require(covered.firstTomShot()).actor == .tom)
  }

  /// An ordinary native-combat fixture isolates weapon execution from world route planning.
  /// Positions are test inputs; no HP, component, ammo, timer or immunity state is changed.
  @MainActor
  private final class NativeRange {
    let session: GameSession
    let fight: EncounterSimulation
    private var figures: [PartyMember: SIMD2<Float>]
    private let dt: Float = 1 / 120

    var strategy: GuardStrategy { fight.guardStrategies["guard"] ?? GuardStrategy() }

    init(boxes: [Level.Box] = []) throws {
      let guardBot = Level.Hostile(
        id: "guard", name: "Guard", hiddenAt: .zero, standAt: .zero, hits: 6,
        attack: .robot, strategicGuard: true, range: 12)
      let encounter = Level.Encounter(
        beat: .stranger, start: .area(.init(minimum: [-20, -20], maximum: [20, 20])),
        retryAt: [0, 12], hostiles: [guardBot],
        cues: [(0, .reveal("guard")), (0, .engage("guard"))])
      figures = [.miki: [0, 8], .tom: [3.5, 0], .laura: [2.65, 0]]
      let level = Level(
        id: "autonomy-range", ground: .box("floor", at: [0, -0.15, 0], size: [60, 0.3, 60]),
        boxes: boxes, triggers: [], encounters: [encounter], party: [.miki, .tom, .laura],
        spawns: figures, heading: [0, -1], cameraOffset: BrooklynBridge.cameraOffset,
        fieldOfView: 22,
        opening: "Range", objective: "Test", lookAround: "Range", restartNote: "Restart")
      session = GameSession(level: level)
      fight = EncounterSimulation(level: level)
      #expect(session.beginEncounter(.stranger))
      fight.begin(encounter)
      step()
    }

    func openCore() throws {
      for _ in 0..<120 * 20 where strategy.phase == .sensor {
        guard let robot = fight.hostiles["guard"]?.robot,
          let point = fight.weakpoints(for: "guard").first
        else { continue }
        figures[.miki] = robot.position + simd_normalize(point.ground - robot.position) * 8
        step(playerFire: point.exposed)
      }
      try #require(strategy.phase == .coupling)
      for _ in 0..<120 * 5 where strategy.phase == .coupling {
        guard let robot = fight.hostiles["guard"]?.robot,
          let point = fight.weakpoints(for: "guard").max(by: { $0.ground.x < $1.ground.x })
        else { continue }
        figures[.laura] = robot.position + simd_normalize(point.ground - robot.position) * 2.65
        step(intents: [
          .laura: CompanionTactics.Intent(
            lookAt: point.ground, weapon: .energySword, fire: true, activity: .attacking)
        ])
      }
      try #require(strategy.phase == .reactor && strategy.windowRemaining > 0)
      // The support shooter needs a clear lane, rather than firing through Laura's stance.
      figures[.laura] = [-7, 0]
    }

    func firstTomShot() -> EncounterSimulation.Shot? {
      for _ in 0..<240 {
        stepTom()
        if let shot = fight.shots.first(where: { $0.actor == .tom }) { return shot }
      }
      return nil
    }

    func stepTom(at origin: SIMD2<Float>? = nil, facingAway: Bool = false) {
      guard let robot = fight.hostiles["guard"]?.robot,
        let point = fight.weakpoints(for: "guard").max(by: { $0.ground.x < $1.ground.x })
      else { return }
      figures[.tom] = origin ?? robot.position + simd_normalize(point.ground - robot.position) * 3.5
      step(
        intents: [
          .tom: CompanionTactics.Intent(
            lookAt: point.ground, weapon: .minigun, fire: true, activity: .attacking)
        ],
        facingAway: facingAway)
    }

    private func step(
      playerFire: Bool = false, intents: [PartyMember: CompanionTactics.Intent] = [:],
      facingAway: Bool = false
    ) {
      let leader = figures[session.leader] ?? .zero
      let point =
        fight.weakpoints(for: "guard").first?.ground
        ?? fight.hostiles["guard"]?.position ?? .zero
      var facings: [PartyMember: SIMD2<Float>] = [:]
      for member in session.party {
        let target = intents[member]?.lookAt ?? point
        let delta = target - (figures[member] ?? .zero)
        facings[member] = simd_length(delta) > 0.001 ? simd_normalize(delta) : [0, -1]
      }
      if facingAway { facings[.tom] = -(facings[.tom] ?? [0, -1]) }
      _ = fight.step(
        dt: dt, leader: leader, facing: facings[session.leader] ?? [0, -1], aiming: true,
        fireHeld: playerFire, firePressed: playerFire, figures: figures, session: session,
        companionIntents: intents, facings: facings)
    }
  }
}
