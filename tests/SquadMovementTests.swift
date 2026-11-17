import RealityKit
import Testing
import simd

@testable import Lauder

/// ADR 0003 phase S1: natural following with the Close formation.
@MainActor
struct SquadMovementTests {
  private let grid = NavigationGrid.prototype
  private let motion = PartyMotion(
    radius: PrototypeLayout.characterRadius, obstacles: PrototypeLayout.obstacles)

  @Test
  func walkableCellsKeepTheBodyClearOfScenery() {
    var checked = 0
    for x in stride(from: Float(-13.9), through: 13.9, by: 0.37) {
      for z in stride(from: Float(-9.9), through: 9.9, by: 0.37) {
        guard let centre = grid.nearestWalkable(to: [x, z], within: 0.2) else { continue }
        checked += 1
        // canTraverse checks both endpoints for the full body radius plus skin.
        #expect(motion.canTraverse(from: centre, to: centre), "cell at \(centre)")
      }
    }
    #expect(checked > 1_000)
    #expect(!grid.isWalkable([-1.5, 1]), "the street wreck is blocked")
    #expect(grid.isWalkable([-8, 3]), "the spawn is walkable")
  }

  @Test
  func aRouteIntoTheDepotUsesTheServiceOpening() throws {
    let start = SIMD2<Float>(2.5, -2)
    let goal = SIMD2<Float>(6, -2)
    #expect(!motion.canTraverse(from: start, to: goal), "the depot's west wall is between them")
    let cells = try #require(grid.route(from: start, to: goal))
    let route = NavigationGrid.straightened([start] + cells + [goal]) {
      motion.canTraverse(from: $0, to: $1)
    }
    for (from, to) in zip(route, route.dropFirst()) {
      #expect(motion.canTraverse(from: from, to: to), "\(from) → \(to)")
    }
    // The west wall runs along x = 4; its opening spans z -5.4 to -3.6.
    let crossings = zip(route, route.dropFirst()).compactMap { from, to -> Float? in
      guard (from.x - 4) * (to.x - 4) <= 0, from.x != to.x else { return nil }
      return from.y + (to.y - from.y) * (4 - from.x) / (to.x - from.x)
    }
    #expect(crossings.count == 1)
    #expect(crossings.allSatisfy { $0 > -5.4 && $0 < -3.6 }, "crossings \(crossings)")
  }

  @Test
  func aTargetInsideABoxIsReplacedByTheNearestReachableSpot() throws {
    let goal = SIMD2<Float>(1, -2)
    let cells = try #require(grid.route(from: [-5, -2], to: goal))
    let end = try #require(cells.last)
    #expect(grid.isWalkable(end))
    #expect(simd_distance(end, goal) <= 1)
  }

  @Test
  func pointsOutsideTheGridAreRefusedWithoutFailing() {
    // A fallback slot behind a leader at the outer wall can fall beyond the floor.
    #expect(grid.nearestWalkable(to: [0, 50], within: 1) == nil)
    #expect(grid.nearestWalkable(to: [-40, -40], within: 1) == nil)
    #expect(grid.route(from: [0, 9], to: [0, 11.5]) == nil)
    #expect(grid.route(from: [0, 30], to: [0, 0]) == nil)
    #expect(!grid.isWalkable([0, 30]))
  }

  @Test
  func doorwaysAreTightAndOpenGroundIsNot() {
    #expect(grid.isWalkable([4, -4.5]))
    #expect(!grid.isRoomy([4, -4.5]), "the service opening")
    #expect(grid.isRoomy([-5, 5]), "the open street")
    #expect(grid.isRoomy([-5, 8.9]), "beside the long south wall")
  }

  @Test
  func routeMemoryMeasuresBackAlongTheLeadersPath() throws {
    var memory = RouteMemory(start: .zero)
    for step in 1...200 { memory.record([Float(step) * 0.05, 0]) }
    let current = SIMD2<Float>(10, 0)
    let back = try #require(memory.point(back: 1, from: current))
    #expect(simd_distance(back, [9, 0]) < 0.001)
    #expect(memory.point(back: 7, from: current) == nil, "only about 6 m is kept")
    for step in 1...10 { memory.record([10, Float(step) * 0.05]) }
    let around = try #require(memory.point(back: 1, from: [10, 0.5]))
    #expect(simd_distance(around, [9.5, 0]) < 0.001, "1 m back turns the corner")
    // Walking back the way the leader came starts the route again from the turning point, so
    // no place on it lies ahead of the leader.
    for step in 1...6 { memory.record([10, 0.5 - Float(step) * 0.05]) }
    #expect(memory.point(back: 1, from: [10, 0.2]) == nil)
    #expect(memory.points.allSatisfy { $0.x == 10 && $0.y <= 0.5 })
  }

  @Test
  func companionsKeepCloseSlotsBesideTheLeadersPathInOpenGround() throws {
    let world = GameWorld()
    var near = 0
    var samples = 0
    var offset: Float = 0
    for frame in 0..<(6 * 60) {
      world.advanceParty(movement: stick(towards: [1, 0]), deltaTime: 1 / 60)
      try #require(world.diagnostic == nil, "frame \(frame)")
      // Allow 1.5 s to form up from the spawn column and turn east.
      guard frame >= 90 else { continue }
      let leader = position(world, world.session.leader)
      for member in PartyMember.allCases where member != world.session.leader {
        let target = try #require(world.companionTargets[member])
        let body = position(world, member)
        samples += 1
        if simd_distance(body, target) <= 0.6 { near += 1 }
        offset += abs(body.y - leader.y)
      }
    }
    #expect(Float(near) >= 0.9 * Float(samples), "\(near) of \(samples) within 0.6 m")
    // The leader runs along one line; the companions walk about 0.9 m to either side of it.
    #expect(offset / Float(samples) > 0.6, "mean side offset \(offset / Float(samples))")
  }

  @Test
  func settledCompanionsStayStillWhileTheLeaderWaits() {
    let world = GameWorld()
    for _ in 0..<120 { world.advanceParty(movement: stick(towards: [1, 0]), deltaTime: 1 / 60) }
    for _ in 0..<120 { world.advanceParty(movement: .zero, deltaTime: 1 / 60) }
    let settled = PartyMember.allCases.map { position(world, $0) }
    var largest: Float = 0
    for _ in 0..<300 {
      world.advanceParty(movement: .zero, deltaTime: 1 / 60)
      for (member, start) in zip(PartyMember.allCases, settled) {
        largest = max(largest, simd_distance(position(world, member), start))
      }
    }
    #expect(largest == 0, "moved up to \(largest) m while waiting")
    #expect(world.diagnostic == nil)
  }

  @Test(arguments: PartyMember.allCases)
  func everyLeaderTakesThePartyThroughTheServiceOpeningAndBack(leader: PartyMember) throws {
    let world = GameWorld()
    // Party B's barrier closes the passage until Lara releases the latch.
    while world.session.leader != .lara { world.session.cycleLeader() }
    try walk(world, through: [[2.5, 3], [3.2, -5]], label: "to the latch")
    world.performAction()
    try #require(world.session.passageOpen)
    while world.session.leader != leader { world.session.cycleLeader() }
    let inward: [SIMD2<Float>] = [[2.5, 3], [2.5, -4.5], [5, -4.5], [6.5, -3]]
    let outward: [SIMD2<Float>] = [[5, -4.5], [2.5, -4.5], [2.5, 3], [-6, 3]]

    try walk(world, through: inward, label: "in")
    try wait(world, seconds: 2)
    for member in PartyMember.allCases {
      let body = position(world, member)
      #expect(
        body.x > 4.2 && body.y > -6.8 && body.y < -1.2,
        "\(member) is inside the depot at \(body)")
    }

    try walk(world, through: outward, label: "out")
    try wait(world, seconds: 2)
    let end = position(world, leader)
    for member in PartyMember.allCases where member != leader {
      let body = position(world, member)
      #expect(simd_distance(body, end) < 2.5, "\(member) is with the leader at \(body)")
    }
  }

  @Test
  func switchingAtTheOuterWallKeepsEveryoneOnTheFloor() throws {
    let world = GameWorld()
    try walk(world, through: [[-6, 8.9]], label: "to the south wall")
    for _ in 0..<60 { world.advanceParty(movement: stick(towards: [0, 1]), deltaTime: 1 / 60) }
    world.session.cycleLeader()
    for frame in 0..<180 {
      world.advanceParty(movement: stick(towards: [0, -1]), deltaTime: 1 / 60)
      try #require(world.diagnostic == nil, "frame \(frame)")
    }
    for member in PartyMember.allCases {
      let body = position(world, member)
      #expect(
        grid.isWalkable(body) || motion.canTraverse(from: body, to: body), "\(member) at \(body)")
    }
  }

  @Test
  func aPreviousLeaderJoinsTheFormationAfterASwitch() throws {
    let world = GameWorld()
    for _ in 0..<120 { world.advanceParty(movement: stick(towards: [1, 0]), deltaTime: 1 / 60) }
    let previous = world.session.leader
    world.session.cycleLeader()
    for frame in 0..<150 {
      world.advanceParty(movement: stick(towards: [1, 0]), deltaTime: 1 / 60)
      try #require(world.diagnostic == nil, "frame \(frame)")
    }
    let target = try #require(world.companionTargets[previous])
    #expect(simd_distance(position(world, previous), target) <= 0.6)
  }

  // MARK: - Helpers

  /// Screen-relative stick axes for a world heading, as GameWorld consumes them.
  private func stick(towards direction: SIMD2<Float>) -> SIMD2<Float> {
    let toCamera = SIMD2(PrototypeLayout.cameraOffset.x, PrototypeLayout.cameraOffset.z)
    let forward = -simd_normalize(toCamera)
    let right = SIMD2(-forward.y, forward.x)
    let unit = simd_normalize(direction)
    return SIMD2(simd_dot(unit, right), simd_dot(unit, forward))
  }

  private func position(_ world: GameWorld, _ member: PartyMember) -> SIMD2<Float> {
    guard let body = world.root.findEntity(named: "party.\(member.rawValue)") else {
      return [.nan, .nan]
    }
    return SIMD2(body.position.x, body.position.z)
  }

  private func walk(_ world: GameWorld, through points: [SIMD2<Float>], label: String) throws {
    var index = 0
    var frame = 0
    while index < points.count {
      let leader = position(world, world.session.leader)
      let offset = points[index] - leader
      if simd_length(offset) < 0.15 {
        index += 1
        continue
      }
      world.advanceParty(movement: stick(towards: offset), deltaTime: 1 / 60)
      frame += 1
      try #require(world.diagnostic == nil, "\(label), frame \(frame): \(world.diagnostic ?? "")")
      try #require(frame < 60 * 30, "\(label): the leader did not reach \(points[index])")
    }
  }

  private func wait(_ world: GameWorld, seconds: Float) throws {
    for frame in 0..<Int(seconds * 60) {
      world.advanceParty(movement: .zero, deltaTime: 1 / 60)
      try #require(world.diagnostic == nil, "waiting, frame \(frame)")
    }
  }
}
