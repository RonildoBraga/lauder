import RealityKit
import Testing
import simd

@testable import Lauder

/// ADR 0004, milestone M1: Miki crosses the buried Brooklyn Bridge alone, trigger areas show
/// their lines once, and Restart returns everything to the Brooklyn end.
@MainActor
struct BridgeTests {
  @Test
  func theThreeStartTogetherAtTheBrooklynEnd() throws {
    let world = GameWorld(level: BrooklynBridge.level)
    #expect(world.session.party == [.miki, .tom, .laura])
    #expect(world.session.leader == .miki && world.session.nextLeader == .tom)
    #expect(world.objective == "Cross the bridge to Manhattan.")
    #expect(world.observation == BrooklynBridge.level.opening)
    for member in PartyMember.allCases {
      #expect(position(world, member) == BrooklynBridge.level.spawn(member))
      #expect(try #require(world.root.findEntity(named: "party.\(member.rawValue)")).isEnabled)
    }
    #expect(world.session.formationsAvailable && world.session.ordersAvailable)
  }

  @Test
  func eachTriggerShowsItsLineOnceAlongTheCrossing() {
    // The lines alone: FirstFightTests plays the stranger's fight on the way.
    var level = BrooklynBridge.level
    level.encounters = []
    let world = GameWorld(level: level)
    var seen: [String] = []
    let route: [SIMD2<Float>] = [
      [6.5, 66], [6.5, 20], [6.5, -206.15], [-7, -228.15], [-7, -456.3], [-7, -502.3],
    ]
    for point in route {
      walk(world, to: point) { line in
        if seen.last != line { seen.append(line) }
      }
      #expect(simd_distance(position(world, .miki), point) < 0.3, "stopped short of \(point)")
    }
    let lines = BrooklynBridge.triggers.map(\.line)
    #expect(seen.filter(lines.contains) == lines)
    #expect(world.session.firedTriggers.count == BrooklynBridge.triggers.count)
    // Walking back out of the last area and in again shows nothing new.
    walk(world, to: [-7, -494.3])
    world.performAction()
    walk(world, to: [-7, -502.3])
    #expect(world.observation != BrooklynBridge.triggers.last?.line)
    #expect(world.session.firedTriggers.count == BrooklynBridge.triggers.count)
  }

  @Test
  func restartReturnsTheThreeToTheStartWithNothingFired() {
    let world = GameWorld(level: BrooklynBridge.level)
    let entities = count(world.root)
    for _ in 0..<3 {
      walk(world, to: [6.5, 60])
      #expect(!world.session.firedTriggers.isEmpty)
      world.restart()
      #expect(world.session.party == [.miki, .tom, .laura])
      #expect(world.session.firedTriggers.isEmpty)
      #expect(world.observation == BrooklynBridge.level.opening)
      for member in PartyMember.allCases {
        #expect(position(world, member) == BrooklynBridge.level.spawn(member))
        #expect(world.root.findEntity(named: "party.\(member.rawValue)")?.isEnabled == true)
      }
      #expect(count(world.root) == entities)
    }
  }

  /// The three start together, Tom and Laura in the Close formation's places behind Miki: Tom on
  /// the right and Laura on the left, the sides the D-pad's orders send.
  @Test
  func theThreeStartTogetherInTheCloseFormation() {
    let level = BrooklynBridge.level
    let miki = level.spawn(.miki)
    #expect(level.party == [.miki, .tom, .laura] && level.lying.isEmpty)
    #expect(level.spawn(.tom) == miki + SquadPlanner.closeSlots[0])
    #expect(level.spawn(.laura) == miki + SquadPlanner.closeSlots[1])
    let session = GameSession(level: level)
    #expect(session.rightCompanion == .tom && session.leftCompanion == .laura)
  }

  /// With nothing on the bridge to search or help with, the action press looks around, and a
  /// look points towards Manhattan.
  @Test
  func aLookPointsTowardsManhattan() {
    let world = GameWorld(level: BrooklynBridge.level)
    walk(world, to: [6.5, 104])
    world.performAction()
    #expect(world.observation == BrooklynBridge.level.lookAround)
  }

  /// The party keeps to the buried road: an invisible edge at its width stops anyone walking off
  /// onto the snow on either side, or past the Brooklyn end behind the start.
  @Test
  func anInvisibleEdgeKeepsThePartyOnTheRoad() {
    let world = GameWorld(level: BrooklynBridge.level)
    let deck = BrooklynBridge.level.bounds
    // Right, left, and down the screen, towards Brooklyn.
    for push: SIMD2<Float> in [[1, 0], [-1, 0], [0, -1]] {
      world.restart()
      for _ in 0..<(60 * 10) {
        world.advanceParty(movement: push, deltaTime: 1 / 60)
      }
      #expect(deck.contains(position(world, .miki)), "Miki stays on the road pushing \(push)")
    }
  }

  /// Next goes round the three, and Restart starts them together again with Miki leading.
  @Test
  func nextGoesRoundTheThreeAndRestartKeepsThemTogether() {
    let session = GameSession(level: BrooklynBridge.level)
    session.recruit(.tom)
    #expect(session.party == [.miki, .tom, .laura], "joining twice changes nothing")
    for expected in [PartyMember.tom, .laura, .miki] {
      #expect(session.nextLeader == expected)
      session.cycleLeader()
      #expect(session.leader == expected)
    }
    session.cycleLeader()
    session.restart()
    #expect(session.party == [.miki, .tom, .laura] && session.leader == .miki)
  }

  @Test
  func aTriggerFiresOnceAndNotWhilePaused() {
    let session = GameSession(level: BrooklynBridge.level)
    session.togglePause()
    #expect(!session.fire("mid-span"))
    session.togglePause()
    #expect(session.fire("mid-span"))
    #expect(!session.fire("mid-span"))
    session.restart()
    #expect(session.fire("mid-span"))
  }

  /// One companion takes a Close slot behind the leader, as Tom will before Laura joins.
  @Test
  func oneCompanionFollowsInTheCloseFormation() {
    var planner = SquadPlanner(heading: [0, -1])
    let grid = NavigationGrid(level: BrooklynBridge.level)
    let motion = PartyMotion(
      radius: PartyBody.radius, obstacles: BrooklynBridge.level.obstacles)
    let leader: SIMD2<Float> = [6.5, 90]
    let targets = planner.targets(
      for: SquadPlanner.Input(
        leader: .miki, leaderPosition: leader, leaderVelocity: [0, -2.6],
        positions: [.miki: leader, .tom: [6.5, 92]], route: RouteMemory(start: leader),
        dt: GameWorld.simulationStep),
      grid: grid, isClear: { motion.canTraverse(from: $0, to: $1) })
    #expect(Set(targets.keys) == [.tom])
    let target = targets[.tom] ?? .zero
    #expect(simd_distance(target, leader) < 1.5)
    #expect(target.y > leader.y)
  }

  /// The layout file that Blender exports (ADR 0002) holds only what the bridge uses, and its
  /// boxes stand on the deck. Snow has buried the road; the six tower piers and the two authored
  /// cover blocks are its only gameplay boxes.
  @Test
  func theLayoutFileHoldsWhatTheBridgeUses() {
    let layout = BrooklynBridge.layout
    let coverNames: Set<String> = ["bridge-cover-west", "bridge-cover-east"]
    #expect(layout.boxes.filter { $0.name.contains("-tower-") }.count == 6)
    #expect(Set(layout.boxes.filter { !$0.name.contains("-tower-") }.map(\.name)) == coverNames)
    #expect(abs(layout.ground.position.y + layout.ground.size.y / 2) < 0.005)
    for box in layout.boxes {
      #expect(abs(box.position.y - box.size.y / 2) < 0.005, "\(box.name) stands on the deck")
    }
    // Each area and marker has its words or its part in BrooklynBridge.swift.
    let level = BrooklynBridge.level
    #expect(
      layout.areas.map(\.name)
        == level.triggers.map(\.id)
        + ["stranger", "search.stranger", "laura.found", "help.laura", "robot.exit"])
    #expect(
      layout.markers.map(\.name) == [
        "spawn.miki", "spawn.tom", "spawn.laura", "stranger.hidden", "stranger.stand",
        "stranger.retry", "attacker.hidden", "attacker.stand", "supply.case",
      ])
  }

  /// The bridge's look comes from its scene file, which Blender exports with the layout file from
  /// the level's Blender file (ADR 0002). The road and everything on it lie buried under a plain
  /// of snow level with the old deck, so the ground has no look of its own. Towers and the two
  /// cover blocks stand above it: each box's look fills it. The decoration is in the scene
  /// file alone, and the camera takes the layout file's offset and field of view.
  @Test
  func theSceneFileShowsTheBridgeWhereItsBoxesStand() throws {
    let layout = BrooklynBridge.layout
    let level = BrooklynBridge.level
    #expect(level.cameraOffset == layout.camera.offset)
    #expect(level.fieldOfView == layout.camera.fieldOfView)
    let world = GameWorld(level: level)
    let scene = try #require(world.root.findEntity(named: "brooklyn-bridge.scene"))
    func part(_ name: String) -> Entity? { scene.findEntity(named: Self.sceneName(name)) }
    // The snow plain covers the deck the party walks on, its top level with the deck's.
    let deck = layout.ground
    let deckLow = deck.position - deck.size / 2
    let deckHigh = deck.position + deck.size / 2
    #expect(part("\(deck.name) block") == nil, "the road lies buried")
    let snow = try #require(part("snow plain"), "the snow plain is shown")
      .visualBounds(relativeTo: nil)
    #expect(abs(snow.max.y - deckHigh.y) < 0.001, "the snow lies level with the deck")
    #expect(snow.min.x <= deckLow.x && snow.max.x >= deckHigh.x, "the snow covers the deck's width")
    #expect(snow.min.z <= deckLow.z && snow.max.z >= deckHigh.z, "the snow covers its length")
    for box in layout.boxes {
      let block = try #require(part("\(box.name) block"), "\(box.name) has a look")
      let bounds = block.visualBounds(relativeTo: nil)
      #expect(simd_distance(bounds.center, box.position) < 0.001, "\(box.name) stands as written")
      #expect(simd_distance(bounds.extents, box.size) < 0.001, "\(box.name)'s look fills it")
    }
    // The decoration, including cable fans and low off-route snow drifts, is in the scene file
    // alone, and nothing else shows.
    let decoration = [
      "tower-top-brooklyn", "tower-top-manhattan", "tower-shadow-brooklyn",
      "tower-shadow-manhattan", "snow plain", "route poles", "route flags",
      "cable-fan-brooklyn-west", "cable-fan-brooklyn-east",
      "cable-fan-manhattan-west", "cable-fan-manhattan-east",
      "snow-drifts-west", "snow-drifts-east", "bridge-supply-case",
    ]
    for name in decoration {
      #expect(part(name)?.components.has(ModelComponent.self) == true, "\(name) is shown")
    }
    func shown(_ entity: Entity) -> [String] {
      (entity.components.has(ModelComponent.self) ? [entity.name] : [])
        + entity.children.flatMap(shown)
    }
    let looks = layout.boxes.map { "\($0.name) block" } + decoration
    #expect(Set(shown(scene)) == Set(looks.map(Self.sceneName)))
    let camera = try #require(world.root.findEntity(named: "camera") as? PerspectiveCamera)
    #expect(camera.camera.fieldOfViewInDegrees == layout.camera.fieldOfView)
  }

  /// The supply case stays on the outgoing west side as scenery, with nothing in it to search:
  /// it shows, blocks nobody, and the west exit round it lies outside the guard's whole reach.
  @Test
  func theSupplyCaseIsSceneryOutsideTheWholeGuardEnvelope() throws {
    let level = BrooklynBridge.level
    let world = GameWorld(level: level)
    let scene = try #require(world.root.findEntity(named: "brooklyn-bridge.scene"))
    let box = try #require(scene.findEntity(named: Self.sceneName("bridge-supply-case")))
    let bounds = box.visualBounds(relativeTo: nil)
    let point = SIMD2(bounds.center.x, bounds.center.z)
    #expect(abs(bounds.min.y) < 0.01 && bounds.max.y < PartyBody.height)
    #expect(!level.boxes.contains { $0.name.contains("supply") })
    let movement = PartyMotion(radius: PartyBody.radius, obstacles: level.obstacles)
    #expect(movement.canTraverse(from: point - [1, 0], to: point + [1, 0]))
    let exit = try #require(BrooklynBridge.strangerEncounter.safeExit)
    #expect(exit.contains(point))
    let guardArea = RobotGuard(home: BrooklynBridge.stranger.standAt).guardArea
    for x in [exit.minimum.x, exit.maximum.x] {
      for y in [exit.minimum.y, exit.maximum.y] {
        let corner = SIMD2(x, y)
        let closest = simd_min(simd_max(corner, guardArea.minimum), guardArea.maximum)
        #expect(simd_distance(corner, closest) > RobotGuard.detectionRange)
      }
    }
  }

  /// From the bridge's high camera a tower hides the party for some 40 m beyond it, so the whole
  /// tower, its legs, its pier and its top, fades to a see-through ghost of itself while it does
  /// (the visual direction's camera and scale), and the player still sees what stands in the
  /// way. Under its arches, and away from it, it shows. Its shadow, baked into the snow, stays.
  @Test
  func aTowerFadesWhileItHidesTheParty() throws {
    var level = BrooklynBridge.level
    level.encounters = []
    let world = GameWorld(level: level)
    let scene = try #require(world.root.findEntity(named: "brooklyn-bridge.scene"))
    func tower(_ end: String) throws -> [Entity] {
      let names =
        ["tower-top-\(end)"] + ["west", "pier", "east"].map { "\(end)-tower-\($0) block" }
        + ["west", "east"].map { "cable-fan-\(end)-\($0)" }
      return try names.map { try #require(scene.findEntity(named: Self.sceneName($0)), "\($0)") }
    }
    let brooklyn = try tower("brooklyn")
    let manhattan = try tower("manhattan")
    let shadows = try ["brooklyn", "manhattan"].map { end in
      try #require(scene.findEntity(named: Self.sceneName("tower-shadow-\(end)")), "\(end)")
    }
    // Every part of a tower shows as much as the others.
    func opacity(_ tower: [Entity]) -> Set<Float> {
      Set(tower.map { $0.components[OpacityComponent.self]?.opacity ?? 1 })
    }
    // A fading tower wears unlit ghosts of its materials, and a shown one its own.
    func ghostly(_ tower: [Entity]) -> Set<Bool> {
      Set(
        tower.flatMap { part in
          (part.components[ModelComponent.self]?.materials ?? []).map { $0 is UnlitMaterial }
        })
    }
    func standStill() {
      for _ in 0..<30 { world.advanceParty(movement: .zero, deltaTime: 1 / 60) }
    }
    #expect(opacity(brooklyn) == [1] && opacity(manhattan) == [1])
    #expect(ghostly(brooklyn) == [false] && ghostly(manhattan) == [false])
    // For the first half second a speck before the camera shows each tower's ghost, so the
    // first fade does not stall; then it is disabled, and stays.
    let camera = try #require(world.root.findEntity(named: "camera"))
    let specks = camera.children.filter { $0.name == "landmark.speck" }
    #expect(specks.count == 2 && specks.allSatisfy(\.isEnabled))
    #expect(ghostly(specks) == [true])
    standStill()
    #expect(specks.allSatisfy { !$0.isEnabled })
    walk(world, to: [6.5, 66])
    walk(world, to: [6.5, 20])
    standStill()
    #expect(opacity(brooklyn) == [1], "Miki shows under the first tower's arches")
    walk(world, to: [6.5, -20])
    standStill()
    #expect(opacity(brooklyn) == [LandmarkFade.faded], "the first tower's top hides her")
    #expect(ghostly(brooklyn) == [true], "she sees the tower's ghost")
    #expect(opacity(shadows) == [1] && shadows.allSatisfy(\.isEnabled), "its shadow stays")
    #expect(opacity(manhattan) == [1] && ghostly(manhattan) == [false])
    walk(world, to: [6.5, -206.15])
    standStill()
    #expect(opacity(brooklyn) == [1] && opacity(manhattan) == [1], "nothing hides her mid-span")
    #expect(ghostly(brooklyn) == [false], "the tower wears its own materials again")
    for point: SIMD2<Float> in [[6.5, -225.15], [-7, -228.15], [-7, -456.3], [-7, -502.3]] {
      walk(world, to: point)
    }
    standStill()
    #expect(opacity(manhattan) == [LandmarkFade.faded], "the camera hangs above the second tower")
    #expect(ghostly(manhattan) == [true] && opacity(shadows) == [1])
    #expect(opacity(brooklyn) == [1] && ghostly(brooklyn) == [false])
    // Restart returns Miki to the Brooklyn end, and the tower shows again at once.
    world.restart()
    #expect(opacity(manhattan) == [1] && ghostly(manhattan) == [false])
  }

  /// A tower casts no live shadow, because it fades while it hides the party and its shadow must
  /// stay. Blender bakes each tower's shadow into the snow instead: it lies just above the snow,
  /// where the level's sun throws the tower's parts, so moving the sun or a tower without baking
  /// the shadow again fails here.
  @Test
  func eachTowersShadowLiesBakedWhereTheSunThrowsIt() throws {
    let suns = BrooklynBridge.layout.lights.compactMap { light -> SIMD3<Float>? in
      guard light.castsShadows, case .sun(let source, _) = light.kind else { return nil }
      return simd_normalize(source)
    }
    let source = try #require(suns.first, "a sun casts the level's shadow")
    #expect(source.y > 0, "the sun stands above the horizon")
    let world = GameWorld(level: BrooklynBridge.level)
    let scene = try #require(world.root.findEntity(named: "brooklyn-bridge.scene"))
    for end in ["brooklyn", "manhattan"] {
      let names =
        ["tower-top-\(end)"] + ["west", "pier", "east"].map { "\(end)-tower-\($0) block" }
      var low = SIMD2<Float>(repeating: .infinity)
      var high = SIMD2<Float>(repeating: -.infinity)
      for name in names {
        let part = try #require(scene.findEntity(named: Self.sceneName(name)), "\(name)")
        let live = part.components[DynamicLightShadowComponent.self]?.castsShadow
        #expect(live == false, "\(name) casts no live shadow")
        // Each corner's shadow falls where the line from it away from the sun meets the snow.
        let bounds = part.visualBounds(relativeTo: nil)
        for corner in 0..<8 {
          let point = SIMD3<Float>(
            corner & 1 == 0 ? bounds.min.x : bounds.max.x,
            corner & 2 == 0 ? bounds.min.y : bounds.max.y,
            corner & 4 == 0 ? bounds.min.z : bounds.max.z)
          let ground = point - source * (point.y / source.y)
          low = simd_min(low, [ground.x, ground.z])
          high = simd_max(high, [ground.x, ground.z])
        }
      }
      let shadow = try #require(scene.findEntity(named: Self.sceneName("tower-shadow-\(end)")))
        .visualBounds(relativeTo: nil)
      #expect(shadow.min.y > 0 && shadow.max.y < 0.05, "\(end)'s shadow lies on the snow")
      #expect(simd_distance([shadow.min.x, shadow.min.z], low) < 0.1, "where the sun throws it")
      #expect(simd_distance([shadow.max.x, shadow.max.z], high) < 0.1, "where the sun throws it")
    }
  }

  /// Thin poles with small flags mark the buried road's edges along its whole length, just
  /// outside the invisible edge, so the way and the party's movement read on the white. They
  /// stand on the snow, and are decoration: nothing in the layout blocks there for them.
  @Test
  func routePolesMarkTheBuriedRoadsEdges() throws {
    let world = GameWorld(level: BrooklynBridge.level)
    let scene = try #require(world.root.findEntity(named: "brooklyn-bridge.scene"))
    let poles = try #require(scene.findEntity(named: Self.sceneName("route poles")))
      .visualBounds(relativeTo: nil)
    let road = BrooklynBridge.level.bounds
    #expect(poles.min.x < road.minimum.x && poles.max.x > road.maximum.x, "on both sides")
    #expect(poles.max.x - road.maximum.x < 1.5, "close beside the road")
    #expect(abs(poles.min.y) < 0.001 && abs(poles.max.y - 2) < 0.001, "2 m tall, on the snow")
    #expect(poles.min.z < road.minimum.y + 25 && poles.max.z > road.maximum.y - 25)
    #expect(scene.findEntity(named: Self.sceneName("route flags")) != nil)
    #expect(!BrooklynBridge.layout.boxes.contains { $0.name.contains("pole") })
  }

  /// Snow drifts provide broad facets beside the route without becoming terrain or cover on
  /// the flat ground the party uses. They add neither gameplay blockers nor scene collisions.
  @Test
  func offRouteSnowDriftsStayLowAndNonblocking() throws {
    let world = GameWorld(level: BrooklynBridge.level)
    let scene = try #require(world.root.findEntity(named: "brooklyn-bridge.scene"))
    let road = BrooklynBridge.level.bounds
    #expect(!BrooklynBridge.layout.boxes.contains { $0.name.hasPrefix("snow-drifts-") })
    func collides(_ entity: Entity) -> Bool {
      entity.components.has(CollisionComponent.self) || entity.children.contains(where: collides)
    }
    for side in ["west", "east"] {
      let drift = try #require(
        scene.findEntity(named: Self.sceneName("snow-drifts-\(side)")), "\(side)'s snow drifts")
      let bounds = drift.visualBounds(relativeTo: nil)
      if side == "west" {
        #expect(bounds.max.x <= road.minimum.x, "all western snow stays outside the walkable road")
      } else {
        #expect(bounds.min.x >= road.maximum.x, "all eastern snow stays outside the walkable road")
      }
      #expect(bounds.max.y > 0 && bounds.max.y < 6, "\(side)'s drifts stay below 6 m")
      #expect(!collides(drift), "\(side)'s decorative drifts have no collision components")
    }
  }

  /// The pause menu's Status panel choice hides the status panel and shows it again, staying
  /// in the menu; it stays as it was across Restart. No button does it any more.
  @Test
  func thePauseMenusStatusPanelChoiceHidesAndShowsIt() {
    let world = GameWorld(level: BrooklynBridge.level)
    let confirm = InputRules.Input(
      movement: .zero, actionPressed: true, pausePressed: false, switchPressed: false)
    #expect(!world.panelHidden)
    pressPause(world)
    for _ in 0..<3 { world.session.movePauseChoice(by: 1) }
    #expect(world.session.pauseChoice == .statusPanel)
    world.update(with: confirm, sampledIn: .paused, deltaTime: 1 / 60)
    #expect(world.panelHidden && world.isPaused)
    // Touch now has the same pause choice and retains the player's panel preference.
    #expect(world.controls.touchControlsEnabled && !world.showsPanel)
    world.restart()
    #expect(world.panelHidden)
    pressPause(world)
    for _ in 0..<3 { world.session.movePauseChoice(by: 1) }
    world.update(with: confirm, sampledIn: .paused, deltaTime: 1 / 60)
    #expect(!world.panelHidden && world.isPaused)
  }

  /// The status panel keeps to the essentials: a new line or objective shows for a few seconds
  /// of play, then leaves it; Restart shows the opening and the objective afresh.
  @Test
  func newLinesAndObjectivesShowForAFewSecondsThenGo() {
    let world = GameWorld(level: BrooklynBridge.level)
    #expect(world.lineIsFresh && world.objectiveIsFresh)
    for _ in 0..<(Int(GameWorld.lineTime * 60) + 5) {
      world.advanceParty(movement: .zero, deltaTime: 1 / 60)
    }
    #expect(!world.lineIsFresh && !world.objectiveIsFresh)
    // The buried road's line, at its trigger area, shows afresh; the objective has not changed.
    walk(world, to: [6.5, 66])
    #expect(world.observation == BrooklynBridge.triggers[0].line)
    #expect(world.lineIsFresh && !world.objectiveIsFresh)
    world.restart()
    #expect(world.lineIsFresh && world.objectiveIsFresh)
  }

  /// A response that repeats the last line, such as a second look in the same place, shows
  /// again once the first has gone.
  @Test
  func aRepeatedResponseShowsAgain() {
    let world = GameWorld(level: BrooklynBridge.level)
    walk(world, to: [6.5, 104])
    world.performAction()
    #expect(world.observation == BrooklynBridge.level.lookAround && world.lineIsFresh)
    for _ in 0..<(Int(GameWorld.lineTime * 60) + 5) {
      world.advanceParty(movement: .zero, deltaTime: 1 / 60)
    }
    #expect(!world.lineIsFresh)
    world.performAction()
    world.advanceParty(movement: .zero, deltaTime: 1 / 60)
    #expect(world.observation == BrooklynBridge.level.lookAround && world.lineIsFresh)
  }

  // MARK: - Helpers

  /// A layout name as the scene file has it: USD allows only letters, digits and underscores, so
  /// `brooklyn-tower-pier block` is `brooklyn_tower_pier_block` there.
  private static func sceneName(_ name: String) -> String {
    String(name.map { $0.isASCII && ($0.isLetter || $0.isNumber) ? $0 : "_" })
  }
}
