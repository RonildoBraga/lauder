import RealityKit
import Testing
import simd

@testable import Lauder

@MainActor
struct TouchTargetTests {
  private let leader = SIMD2<Float>(0, 8)
  private let aspect: Float = 2.16
  private let viewHeight: Float = 428

  @Test(arguments: [Float(200), 428, 1000])
  func aTapUsesTheSameThirtyPointRadiusAtDifferentScreenSizes(height: Float) throws {
    let projection = camera()
    let body = Targeting.Candidate(id: "body", position: .zero)
    let centre = try bodyCentre(.zero, in: projection)
    let width = height * projection.aspect
    let inside = centre + SIMD2<Float>(29.9 / width, 0)
    let outside = centre + SIMD2<Float>(30.1 / width, 0)
    #expect(pick(inside, height: height, bodies: [body], camera: projection) == "body")
    #expect(pick(outside, height: height, bodies: [body], camera: projection) == nil)
    #expect(pick(centre, height: height, bodies: [], camera: projection) == nil)
  }

  @Test
  func theNearestProjectedBodyWinsAndExactTiesUseStableIDs() throws {
    let projection = camera()
    let bodies = [
      Targeting.Candidate(id: "left", position: [-0.5, 0]),
      Targeting.Candidate(id: "right", position: [0.5, 0]),
    ]
    let right = try bodyCentre([0.5, 0], in: projection)
    #expect(pick(right, bodies: bodies, camera: projection) == "right")
    let tied = [
      Targeting.Candidate(id: "z", position: .zero),
      Targeting.Candidate(id: "a", position: .zero),
    ]
    let middle = try bodyCentre(.zero, in: projection)
    #expect(pick(middle, bodies: tied, camera: projection) == "a")
    #expect(pick(middle, bodies: Array(tied.reversed()), camera: projection) == "a")
  }

  @Test
  func theWholeProjectedBodyCountsAndOffscreenOrBehindBodiesDoNot() throws {
    let projection = CameraProjection(
      eye: [0, 5, 5], target: .zero, fieldOfView: 35, aspect: aspect)
    let body = Targeting.Candidate(id: "body", position: .zero)
    let head = try #require(projection.screen(ofWorld: [0, PartyBody.height, 0]))
    let feet = try #require(projection.screen(ofGround: .zero))
    try #require(abs(head.y - feet.y) * viewHeight > 30)
    #expect(pick(head, bodies: [body], camera: projection) == "body")
    #expect(
      Targeting.touched(
        at: head, viewHeight: viewHeight, projection: projection, candidates: [body],
        height: { _ in 0.1 }) == nil)
    let outside = try #require(projection.ground(atScreen: [1.01, 0.5]))
    #expect(
      pick([0.99, 0.5], bodies: [.init(id: "offscreen", position: outside)], camera: projection)
        == nil)
    #expect(
      pick([0.5, 0.5], bodies: [.init(id: "behind", position: [0, 30])], camera: projection)
        == nil)
    let partlyVisible = try #require(projection.ground(atScreen: [0.5, 1.02]))
    #expect(
      pick([0.5, 0.99], bodies: [.init(id: "edge", position: partlyVisible)], camera: projection)
        == "edge")
  }

  @Test
  func invalidTapDimensionsBodyDataAndProjectionCannotPickAHostile() {
    let body = Targeting.Candidate(id: "body", position: .zero)
    for point: SIMD2<Float> in [[.nan, 0.5], [0.5, .infinity], [-0.01, 0.5], [0.5, 1.01]] {
      #expect(pick(point, bodies: [body]) == nil)
    }
    for height: Float in [0, -1, .nan, .infinity] {
      #expect(pick([0.5, 0.5], height: height, bodies: [body]) == nil)
    }
    for aspect: Float in [0, -1, .nan, .infinity] {
      #expect(pick([0.5, 0.5], bodies: [body], camera: camera(aspect: aspect)) == nil)
    }
    for height: Float in [0, -1, .nan, .infinity] {
      #expect(
        Targeting.touched(
          at: [0.5, 0.5], viewHeight: viewHeight, projection: camera(), candidates: [body],
          height: { _ in height }) == nil)
    }
    #expect(pick([0.5, 0.5], bodies: [.init(id: "bad", position: [.nan, 0])]) == nil)
    let badCamera = CameraProjection(eye: .zero, target: .zero, fieldOfView: 35, aspect: aspect)
    #expect(pick([0.5, 0.5], bodies: [body], camera: badCamera) == nil)
  }

  @Test
  func nativeTapsSelectChangeAndReleaseWithoutFiringOrChoosingComponents() throws {
    let (fight, session) = try nativeFight()
    let projection = camera()
    let front = try bodyCentre(.zero, in: projection, height: RobotModelGeometry.halfHeight * 2)
    let right = try bodyCentre([6, 0], in: projection, height: RobotModelGeometry.halfHeight * 2)
    fight.tapLock(at: front, viewHeight: viewHeight, projection: projection, from: leader)
    #expect(fight.lock == "front")
    fight.tapLock(at: right, viewHeight: viewHeight, projection: projection, from: leader)
    #expect(fight.lock == "right")
    fight.tapLock(at: [0.01, 0.99], viewHeight: viewHeight, projection: projection, from: leader)
    #expect(fight.lock == "right", "empty ground leaves the selection alone")
    fight.tapLock(at: right, viewHeight: viewHeight, projection: projection, from: leader)
    #expect(fight.lock == nil)
    #expect(fight.shots.isEmpty && session.combatStance == .defend)
    #expect(!fight.takeEvents().contains { if case .fired = $0 { true } else { false } })
  }

  @Test
  func onlyNativeVisibleTargetableHostilesInsideThirtyMetresCanBeTapped() throws {
    let (fight, _) = try nativeFight()
    for (id, position): (String, SIMD2<Float>) in [
      ("hidden", [-6, 0]), ("unarmed", [0, -6]), ("far", [0, -23.5]),
    ] {
      let projection = camera(over: position)
      let point = try bodyCentre(
        position, in: projection, height: RobotModelGeometry.halfHeight * 2)
      fight.tapLock(at: point, viewHeight: viewHeight, projection: projection, from: leader)
      #expect(fight.lock == nil, "\(id) is not a native lock candidate")
    }
  }

  @Test
  func explicitAcquireAndNextDoNotUseTheControllerDoublePressTimer() throws {
    let (fight, _) = try nativeFight()
    func select(_ advance: Bool) {
      fight.selectLock(
        from: leader, facing: [0, -1], up: [0, -1], right: [1, 0], advancing: advance)
    }
    select(false)
    #expect(fight.lock == "front")
    select(true)
    #expect(fight.lock == "right")
    select(false)
    #expect(fight.lock == "right", "acquire keeps the existing selection")
    select(true)
    #expect(fight.lock == "front", "rapid explicit Next cycles rather than releasing")
    fight.releaseLock()
    #expect(fight.lock == nil)
  }

  @Test
  func worldTouchTargetingShowsTheRingAndFacesTheEnemyWhileWalkingWithoutFire() throws {
    let world = readyWorld()
    let point = try worldTap(world, at: [6, 0])
    frame(world, .init(touchTarget: .tap(point)))
    #expect(world.lockedHostile == "right" && world.controls.touchControlsEnabled)
    let ring = try #require(world.root.findEntity(named: "combat.lock"))
    #expect(ring.isEnabled && ring.isEnabledInHierarchy)
    for _ in 0..<60 {
      frame(
        world, .init(touchStick: stick(world, towards: [-1, 0]), touchIsTouching: true))
    }
    let direction = simd_normalize(SIMD2<Float>(6, 0) - position(world, .miki))
    #expect(position(world, .miki).x < -2)
    #expect(simd_dot(world.facing(of: .miki), direction) > 0.98)
    #expect(
      !world.takeCombatEvents().contains { if case .fired(_, _, true) = $0 { true } else { false } }
    )
  }

  @Test
  func neutralAndSkippedFramesCannotBankATargetCommandOrDropAValidLock() throws {
    let world = readyWorld()
    let tap = try worldTap(world, at: .zero)
    frame(world, .init(touchTarget: .tap(tap)))
    try #require(world.lockedHostile == "front")
    world.controls.requireNeutralInput()
    var release = InputRules.Input.neutral
    release.targetCommand = .release
    world.update(with: release, sampledIn: .exploring, deltaTime: 1 / 60)
    #expect(world.lockedHostile == "front")
    for _ in 0..<3 { frame(world) }
    #expect(world.lockedHostile == "front", "neutral input cannot replay the dropped release")
    frame(world, .init(touchTarget: .release))
    try #require(world.lockedHostile == nil)
    var target = InputRules.Input.neutral
    target.targetCommand = .tap(tap)
    world.update(with: target, sampledIn: .exploring, deltaTime: 1 / 60, inputReady: false)
    // The first fresh running frame is deliberately skipped after that input loss.
    world.update(with: target, sampledIn: .exploring, deltaTime: 1 / 60)
    for _ in 0..<3 { frame(world) }
    #expect(world.lockedHostile == nil)
    frame(world, .init(touchTarget: .tap(try worldTap(world, at: .zero))))
    #expect(world.lockedHostile == "front")
    world.restart()
    for _ in 0..<4 { frame(world) }
    #expect(world.lockedHostile == nil)
  }

  @Test
  func pauseDialogueAndStaleModeSamplesConsumeTargetsInsteadOfReplayingThem() throws {
    let world = readyWorld()
    var target = InputRules.Input.neutral
    target.targetCommand = .tap(try worldTap(world, at: .zero))
    pressPause(world)
    world.update(with: target, sampledIn: .paused, deltaTime: 1 / 60)
    #expect(world.lockedHostile == nil)
    pressPause(world)
    for _ in 0..<4 { frame(world) }
    world.update(with: target, sampledIn: .paused, deltaTime: 1 / 60)
    #expect(world.lockedHostile == nil, "a stale paused sample is not an exploring tap")
    try #require(world.session.converse(.arrival))
    world.update(with: target, sampledIn: .dialogue, deltaTime: 1 / 60)
    finishConversation(world)
    for _ in 0..<4 { frame(world) }
    #expect(world.lockedHostile == nil)
  }

  @Test
  func theTouchStatusChoiceOnlyTogglesFromPauseAndSurvivesRestart() {
    let world = readyWorld()
    var panel = InputRules.Input.neutral
    panel.panelPressed = true
    world.update(with: panel, sampledIn: .exploring, deltaTime: 1 / 60)
    world.update(with: panel, sampledIn: .paused, deltaTime: 1 / 60)
    #expect(!world.panelHidden && world.showsPanel)
    pressPause(world)
    world.update(with: panel, sampledIn: .paused, deltaTime: 1 / 60)
    #expect(world.panelHidden && !world.showsPanel && world.isPaused)
    world.restart()
    #expect(world.panelHidden && !world.showsPanel)
    pressPause(world)
    world.update(with: panel, sampledIn: .paused, deltaTime: 1 / 60)
    #expect(!world.panelHidden && world.showsPanel && world.isPaused)
  }

  private func pick(
    _ point: SIMD2<Float>, height: Float = 428, bodies: [Targeting.Candidate],
    camera projection: CameraProjection? = nil
  ) -> String? {
    Targeting.touched(
      at: point, viewHeight: height, projection: projection ?? camera(), candidates: bodies,
      height: { _ in PartyBody.height })
  }

  private func camera(over point: SIMD2<Float> = .zero, aspect: Float = 2.16) -> CameraProjection {
    CameraProjection(
      eye: [point.x, 10, point.y + 10], target: [point.x, 0, point.y], fieldOfView: 60,
      aspect: aspect)
  }

  private func bodyCentre(
    _ point: SIMD2<Float>, in projection: CameraProjection, height: Float = PartyBody.height
  ) throws -> SIMD2<Float> {
    let feet = try #require(projection.screen(ofGround: point))
    let head = try #require(projection.screen(ofWorld: [point.x, height, point.y]))
    return (feet + head) / 2
  }

  private func nativeFight() throws -> (EncounterSimulation, GameSession) {
    let level = range()
    let fight = EncounterSimulation(level: level)
    let session = GameSession(level: level)
    let encounter = try #require(level.encounters.first)
    try #require(session.beginEncounter(encounter.beat))
    fight.begin(encounter)
    _ = fight.step(
      dt: 1 / 120, leader: leader, facing: [0, -1], aiming: false, fireHeld: false,
      firePressed: false, figures: [.miki: leader], session: session)
    return (fight, session)
  }

  private func readyWorld() -> GameWorld {
    let world = GameWorld(level: range())
    world.setApplicationActive(true)
    world.controls.useTouchControls()
    for _ in 0..<5 { frame(world) }
    return world
  }

  private func frame(_ world: GameWorld, _ raw: InputRules.Raw = .init()) {
    let mode = world.session.mode
    world.update(
      with: world.controls.resolve(raw, mode: mode), sampledIn: mode, deltaTime: 1 / 60)
  }

  private func worldTap(_ world: GameWorld, at point: SIMD2<Float>) throws -> InputRules.TargetTap {
    let projection = world.projection(aspect: aspect)
    let centre = try bodyCentre(point, in: projection, height: RobotModelGeometry.halfHeight * 2)
    return .init(point: .init(x: centre.x, y: centre.y, aspect: aspect), viewHeight: viewHeight)
  }

  private func range() -> Level {
    let points: [(String, SIMD2<Float>)] = [
      ("front", .zero), ("right", [6, 0]), ("hidden", [-6, 0]),
      ("unarmed", [0, -6]), ("far", [0, -23.5]),
    ]
    let robots = points.map { id, point in
      Level.Hostile(
        id: id, name: id, hiddenAt: point, standAt: point, hits: 50, attack: .robot, range: 12)
    }
    let cues: [(at: Float, cue: Level.Cue)] = points.flatMap {
      id, _ -> [(at: Float, cue: Level.Cue)] in
      if id == "hidden" { return [] }
      if id == "unarmed" { return [(at: 0, cue: .reveal(id))] }
      return [(at: 0, cue: .reveal(id)), (at: 0, cue: .engage(id))]
    }
    let encounter = Level.Encounter(
      beat: .stranger, start: .area(.init(minimum: [-40, -40], maximum: [40, 40])),
      retryAt: leader, hostiles: robots, cues: cues)
    return Level(
      id: "touch-target-fixture", ground: .box("floor", at: [0, -0.15, 0], size: [100, 0.3, 100]),
      boxes: [], triggers: [], encounters: [encounter], party: [.miki],
      spawns: [.miki: leader], heading: [0, -1], cameraOffset: BrooklynBridge.cameraOffset,
      fieldOfView: 22, opening: "Range", objective: "Test", lookAround: "Range",
      restartNote: "Restart")
  }
}
