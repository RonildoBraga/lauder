import RealityKit
import Testing
import simd

@testable import Lauder

/// ADR 0004, milestone M1: Miki crosses the buried Brooklyn Bridge alone, trigger areas show
/// their lines once, and Restart returns everything to the Brooklyn end.
@MainActor
struct BridgeTests {
  @Test
  func mikiStartsAloneAtTheBrooklynEnd() throws {
    let world = GameWorld(level: BrooklynBridge.level)
    #expect(world.session.party == [.miki])
    #expect(world.session.leader == .miki)
    #expect(world.session.nextLeader == nil)
    #expect(world.objective == "Cross the bridge to Manhattan.")
    #expect(world.observation == BrooklynBridge.level.opening)
    #expect(position(world, .miki) == BrooklynBridge.level.spawn(.miki))
    // Tom waits hidden where his scene will be; Laura lies hurt in view at hers (M4).
    #expect(try #require(world.root.findEntity(named: "party.tom")).isEnabled == false)
    let laura = try #require(world.root.findEntity(named: "party.laura"))
    #expect(laura.isEnabled && !world.session.party.contains(.laura))
    #expect(position(world, .laura) == BrooklynBridge.level.spawn(.laura))
    #expect(try #require(world.root.findEntity(named: "party.miki")).isEnabled)
    // With nobody to switch to, Next changes nothing.
    world.session.cycleLeader()
    #expect(world.session.leader == .miki)
    #expect(world.companionTargets.isEmpty)
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
  func restartReturnsMikiAloneToTheStartWithNothingFired() {
    let world = GameWorld(level: BrooklynBridge.level)
    let entities = count(world.root)
    for _ in 0..<3 {
      walk(world, to: [6.5, 60])
      #expect(!world.session.firedTriggers.isEmpty)
      world.session.recruit(.tom)
      world.restart()
      #expect(world.session.party == [.miki])
      #expect(world.session.firedTriggers.isEmpty)
      #expect(world.observation == BrooklynBridge.level.opening)
      #expect(position(world, .miki) == BrooklynBridge.level.spawn(.miki))
      #expect(world.root.findEntity(named: "party.tom")?.isEnabled == false)
      #expect(count(world.root) == entities)
    }
  }

  /// Nothing stands on the buried road to look at, so a look points towards Manhattan.
  @Test
  func aLookWithNothingNearPointsTowardsManhattan() {
    let world = GameWorld(level: BrooklynBridge.level)
    walk(world, to: [6.5, 104])
    #expect(world.nearbyName == nil)
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

  @Test
  func membersJoinInOrderAndRestartLeavesMikiAlone() {
    let session = GameSession(level: BrooklynBridge.level)
    session.recruit(.tom)
    session.recruit(.tom)
    #expect(session.party == [.miki, .tom])
    #expect(session.nextLeader == .tom)
    session.cycleLeader()
    #expect(session.leader == .tom)
    session.recruit(.laura)
    #expect(session.nextLeader == .laura)
    session.cycleLeader()
    session.cycleLeader()
    #expect(session.leader == .miki)
    session.restart()
    #expect(session.party == [.miki])
    #expect(session.leader == .miki)
    #expect(session.nextLeader == nil)
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
  /// boxes and landmarks stand on the deck. Snow has buried the road and everything on it, so
  /// its only boxes are the towers', and it has no landmarks.
  @Test
  func theLayoutFileHoldsWhatTheBridgeUses() {
    let layout = BrooklynBridge.layout
    #expect(layout.boxes.allSatisfy { $0.name.contains("-tower-") }, "only the towers stand")
    #expect(layout.landmarks.isEmpty)
    #expect(abs(layout.ground.position.y + layout.ground.size.y / 2) < 0.005)
    for box in layout.boxes {
      #expect(abs(box.position.y - box.size.y / 2) < 0.005, "\(box.name) stands on the deck")
    }
    for landmark in layout.landmarks {
      #expect(abs(landmark.position.y) < 0.005, "\(landmark.name) stands on the deck")
    }
    // Each landmark, area and marker has its words or its part in BrooklynBridge.swift.
    let level = BrooklynBridge.level
    #expect(layout.landmarks.map(\.name) == level.points.map(\.id))
    #expect(
      layout.areas.map(\.name)
        == level.triggers.map(\.id) + ["stranger", "search.stranger", "laura.found", "help.laura"])
    #expect(
      layout.markers.map(\.name) == [
        "spawn.miki", "spawn.tom", "spawn.laura", "stranger.hidden", "stranger.stand",
        "stranger.retry", "attacker.hidden", "attacker.stand",
      ])
  }

  /// The bridge's look comes from its scene file, which Blender exports with the layout file from
  /// the level's Blender file (ADR 0002). The road and everything on it lie buried under a plain
  /// of snow level with the old deck, so the ground has no look of its own and only the towers
  /// stand above it: each box's look is a block that fills it. The decoration is in the scene
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
    // The decoration, the towers' tops over the arches and the snow plain, is in the scene file
    // alone, and nothing else shows.
    let decoration = ["tower-top-brooklyn", "tower-top-manhattan", "snow plain"]
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

  /// From the bridge's high camera a tower hides the party for some 40 m beyond it, so the whole
  /// tower, its legs, its pier and its top, fades while it does (the visual direction's camera
  /// and scale). Under its arches, and away from it, it shows.
  @Test
  func aTowerFadesWhileItHidesTheParty() throws {
    var level = BrooklynBridge.level
    level.encounters = []
    let world = GameWorld(level: level)
    let scene = try #require(world.root.findEntity(named: "brooklyn-bridge.scene"))
    func tower(_ end: String) throws -> [Entity] {
      let names =
        ["tower-top-\(end)"] + ["west", "pier", "east"].map { "\(end)-tower-\($0) block" }
      return try names.map { try #require(scene.findEntity(named: Self.sceneName($0)), "\($0)") }
    }
    let brooklyn = try tower("brooklyn")
    let manhattan = try tower("manhattan")
    // Every part of a tower shows as much as the others.
    func opacity(_ tower: [Entity]) -> Set<Float> {
      Set(tower.map { $0.components[OpacityComponent.self]?.opacity ?? 1 })
    }
    func standStill() {
      for _ in 0..<30 { world.advanceParty(movement: .zero, deltaTime: 1 / 60) }
    }
    #expect(opacity(brooklyn) == [1] && opacity(manhattan) == [1])
    // For the first half second a speck before the camera shows each tower's material
    // see-through, so the first fade does not stall; then it is disabled, and stays.
    let camera = try #require(world.root.findEntity(named: "camera"))
    let specks = camera.children.filter { $0.name == "landmark.speck" }
    #expect(specks.count == 2 && specks.allSatisfy(\.isEnabled))
    standStill()
    #expect(specks.allSatisfy { !$0.isEnabled })
    walk(world, to: [6.5, 66])
    walk(world, to: [6.5, 20])
    standStill()
    #expect(opacity(brooklyn) == [1], "Miki shows under the first tower's arches")
    walk(world, to: [6.5, -20])
    standStill()
    #expect(opacity(brooklyn) == [LandmarkFade.faded], "the first tower's top hides her")
    #expect(opacity(manhattan) == [1])
    walk(world, to: [6.5, -206.15])
    standStill()
    #expect(opacity(brooklyn) == [1] && opacity(manhattan) == [1], "nothing hides her mid-span")
    for point: SIMD2<Float> in [[6.5, -225.15], [-7, -228.15], [-7, -456.3], [-7, -502.3]] {
      walk(world, to: point)
    }
    standStill()
    #expect(opacity(manhattan) == [LandmarkFade.faded], "the camera hangs above the second tower")
    #expect(opacity(brooklyn) == [1])
    // Restart returns Miki to the Brooklyn end, and the tower shows again at once.
    world.restart()
    #expect(opacity(manhattan) == [1])
  }

  // MARK: - Helpers

  /// A layout name as the scene file has it: USD allows only letters, digits and underscores, so
  /// `car-a1 body` is `car_a1_body` there.
  private static func sceneName(_ name: String) -> String {
    String(name.map { $0.isASCII && ($0.isLetter || $0.isNumber) ? $0 : "_" })
  }

  /// Steer the leader straight to a point, reporting each new line the HUD shows.
  private func walk(
    _ world: GameWorld, to point: SIMD2<Float>, onLine: (String) -> Void = { _ in }
  ) {
    var line = world.observation
    for _ in 0..<(60 * 120) {
      let offset = point - position(world, world.session.leader)
      if simd_length(offset) < 0.15 { return }
      world.advanceParty(movement: stick(towards: offset), deltaTime: 1 / 60)
      if world.observation != line {
        line = world.observation
        onLine(line)
      }
    }
  }

  /// Screen-relative stick axes for a world direction under the bridge's camera.
  private func stick(towards direction: SIMD2<Float>) -> SIMD2<Float> {
    let offset = BrooklynBridge.cameraOffset
    let forward = -simd_normalize(SIMD2(offset.x, offset.z))
    let right = SIMD2(-forward.y, forward.x)
    let unit = simd_normalize(direction)
    // Slow down for the last metre so the walk stops close to the point.
    let strength = min(1, max(0.35, simd_length(direction)))
    return SIMD2(simd_dot(unit, right), simd_dot(unit, forward)) * strength
  }

  private func position(_ world: GameWorld, _ member: PartyMember) -> SIMD2<Float> {
    guard let body = world.root.findEntity(named: "party.\(member.rawValue)") else {
      return [.nan, .nan]
    }
    return SIMD2(body.position.x, body.position.z)
  }

  private func count(_ entity: Entity) -> Int {
    1 + entity.children.reduce(0) { $0 + count($1) }
  }
}
