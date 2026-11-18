import RealityKit
import Testing
import simd

@testable import Lauder

/// ADR 0004, milestone M1: Miki crosses the greybox Brooklyn Bridge alone, trigger areas show
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
      [6.5, 66], [6.5, 20], [6.5, -9], [6.5, -28], [-7, -31], [-7, -70], [-7, -108],
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
    walk(world, to: [-7, -100])
    world.performAction()
    walk(world, to: [-7, -108])
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

  @Test
  func aLookWithNothingNearPointsTowardsManhattan() {
    let world = GameWorld(level: BrooklynBridge.level)
    walk(world, to: [6.5, 104])
    world.performAction()
    #expect(world.observation == BrooklynBridge.level.lookAround)
    // The checkpoint booth beside the start can be looked at.
    walk(world, to: [2.2, 113])
    #expect(world.nearbyName == "Checkpoint booth")
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

  /// The layout file that Blender edits (ADR 0005) holds only what the bridge uses, and its
  /// boxes and landmarks stand on the deck.
  @Test
  func theLayoutFileHoldsWhatTheBridgeUses() {
    let layout = BrooklynBridge.layout
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

  /// The bridge's decoration and camera come from the layout file too: the game draws each
  /// piece where the file puts it, turned as it says, and its camera takes the file's offset and
  /// field of view.
  @Test
  func theGameDrawsThePiecesAndTheCameraFromTheLayoutFile() throws {
    let layout = BrooklynBridge.layout
    #expect(layout.pieces.count > 100)
    #expect(Set(layout.pieces.map(\.name)).count == layout.pieces.count)
    let level = BrooklynBridge.level
    #expect(level.cameraOffset == layout.camera.offset)
    #expect(level.fieldOfView == layout.camera.fieldOfView)
    let world = GameWorld(level: level)
    for piece in layout.pieces {
      let entity = try #require(world.root.findEntity(named: "dressing.\(piece.name)"))
      #expect(simd_distance(entity.position(relativeTo: nil), piece.position) < 0.001)
      let turn = entity.orientation(relativeTo: nil).vector
      #expect(abs(simd_dot(turn, piece.rotation.vector)) > 0.9999, "\(piece.name) is turned")
    }
    let camera = try #require(world.root.findEntity(named: "camera") as? PerspectiveCamera)
    #expect(camera.camera.fieldOfViewInDegrees == layout.camera.fieldOfView)
  }

  // MARK: - Helpers

  /// Steer the leader straight to a point, reporting each new line the HUD shows.
  private func walk(
    _ world: GameWorld, to point: SIMD2<Float>, onLine: (String) -> Void = { _ in }
  ) {
    var line = world.observation
    for _ in 0..<(60 * 40) {
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
