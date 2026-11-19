import RealityKit
import Testing
import simd

@testable import Lauder

/// ADR 0003 phase S2, the opening's M5: once there are two companions, the formation button
/// cycles Close, Spread and Column. The shapes are checked in the test yard, whose 1.8 m opening
/// is narrower than any gap on the bridge.
@MainActor
struct FormationTests {
  /// The start of the yard's open lane, between the wreck and the south wall: wide enough for
  /// Spread from end to end.
  private static let laneStart: SIMD2<Float> = [-6, 6]

  // MARK: - The session

  @Test
  func theButtonCyclesCloseSpreadAndColumn() {
    let session = GameSession(level: TestYard.level)
    #expect(session.formation == .close)
    for expected in [GameSession.Formation.spread, .column, .close, .spread] {
      session.cycleFormation()
      #expect(session.formation == expected)
    }
  }

  @Test
  func formationsWaitForTheSecondCompanion() {
    let session = GameSession(level: BrooklynBridge.level)
    #expect(!session.formationsAvailable)
    session.cycleFormation()
    #expect(session.formation == .close)
    session.recruit(.tom)
    #expect(!session.formationsAvailable, "Tom alone follows in Close")
    session.cycleFormation()
    #expect(session.formation == .close)
    session.recruit(.laura)
    #expect(session.formationsAvailable)
    session.cycleFormation()
    #expect(session.formation == .spread)
  }

  @Test
  func pauseAndConversationsBlockTheButton() {
    let session = GameSession(level: TestYard.level)
    session.togglePause()
    session.cycleFormation()
    #expect(session.formation == .close)
    session.togglePause()
    #expect(session.converse(.arrival))
    session.cycleFormation()
    #expect(session.formation == .close)
  }

  @Test
  func switchingKeepsTheFormationAndRestartReturnsToClose() {
    let session = GameSession(level: TestYard.level)
    session.cycleFormation()
    session.cycleLeader()
    #expect(session.formation == .spread)
    session.restart()
    #expect(session.formation == .close)
  }

  @Test
  func aFormationPressReachesTheSessionOnlyWhileExploring() {
    let world = GameWorld(level: TestYard.level)
    var press = InputRules.Input.neutral
    press.formationPressed = true
    world.update(with: press, sampledIn: .exploring, deltaTime: 1 / 60)
    #expect(world.session.formation == .spread)
    world.session.togglePause()
    world.update(with: press, sampledIn: .paused, deltaTime: 1 / 60)
    #expect(world.session.formation == .spread)
    world.restart()
    #expect(world.session.formation == .close)
  }

  // MARK: - The shapes

  @Test(arguments: GameSession.Formation.allCases)
  func eachFormationHoldsItsShapeInOpenGround(formation: GameSession.Formation) throws {
    let world = GameWorld(level: TestYard.level)
    choose(formation, in: world)
    try walk(world, through: [[-11, 6]], label: "to the west end of the lane")
    try wait(world, seconds: 1)
    var near = 0
    var samples = 0
    var sideways: [PartyMember: Float] = [:]
    var behind: [PartyMember: Float] = [:]
    for frame in 0..<Int(7.5 * 60) {
      world.advanceParty(movement: stick(towards: [1, 0]), deltaTime: 1 / 60)
      try #require(world.diagnostic == nil, "\(formation), frame \(frame)")
      // Allow 4.5 s to form up and turn east. A companion left behind at the start catches up
      // at no more than 1.25 times the leader's full speed (ADR 0003), so Spread's far side
      // takes the longest.
      guard frame >= 270 else { continue }
      let leader = position(world, world.session.leader)
      for member in PartyMember.allCases where member != world.session.leader {
        let target = try #require(world.companionTargets[member])
        let body = position(world, member)
        samples += 1
        if simd_distance(body, target) <= 0.6 { near += 1 }
        sideways[member, default: 0] += abs(body.y - leader.y)
        behind[member, default: 0] += leader.x - body.x
      }
    }
    #expect(
      Float(near) >= 0.9 * Float(samples), "\(formation): \(near) of \(samples) within 0.6 m")
    let each = Float(samples / 2)
    let sides = sideways.values.map { $0 / each }.sorted()
    let backs = behind.values.map { $0 / each }.sorted()
    switch formation {
    case .close:
      #expect(sides.allSatisfy { $0 > 0.6 && $0 < 1.2 }, "side offsets \(sides)")
    case .spread:
      #expect(sides.allSatisfy { $0 > 1.8 && $0 < 2.6 }, "side offsets \(sides)")
    case .column:
      // Single file on the leader's own line, about 1 m and 2 m back.
      #expect(sides.allSatisfy { $0 < 0.3 }, "side offsets \(sides)")
      #expect(abs(backs[0] - 1) < 0.4 && abs(backs[1] - 2) < 0.4, "distances behind \(backs)")
    }
  }

  @Test(arguments: zip(GameSession.Formation.allCases, PartyMember.allCases))
  func everyFormationSqueezesThroughTheOpeningAndReforms(
    formation: GameSession.Formation, leader: PartyMember
  ) throws {
    let world = GameWorld(level: TestYard.level)
    while world.session.leader != leader { world.session.cycleLeader() }
    choose(formation, in: world)
    let inward: [SIMD2<Float>] = [[2.5, 3], [2.5, -4.5], [5, -4.5], [6.5, -3]]
    let outward: [SIMD2<Float>] = [[5, -4.5], [2.5, -4.5], [2.5, 6], [-4, 6]]

    try walk(world, through: inward, label: "\(formation) in")
    try wait(world, seconds: 2)
    for member in PartyMember.allCases {
      let body = position(world, member)
      #expect(TestYard.isInRoom(body), "\(formation): \(member) is inside the room at \(body)")
    }

    try walk(world, through: outward, label: "\(formation) out")
    try wait(world, seconds: 2)
    // Back in the open lane the shape is whole again: each companion at their own place, as
    // far from the leader as the formation puts them.
    let end = position(world, leader)
    let expected: [Float] =
      switch formation {
      case .close: SquadPlanner.closeSlots.map { simd_length($0) }
      case .spread: SquadPlanner.spreadSlots.map { simd_length($0) }
      case .column: [1, 2]
      }
    var distances: [Float] = []
    for member in PartyMember.allCases where member != leader {
      let target = try #require(world.companionTargets[member])
      distances.append(simd_distance(target, end))
      let body = position(world, member)
      #expect(simd_distance(body, target) < 0.6, "\(formation): \(member) at \(body)")
    }
    for (distance, wanted) in zip(distances.sorted(), expected.sorted()) {
      #expect(abs(distance - wanted) < 0.15, "\(formation): places \(distances) from the leader")
    }
  }

  @Test(arguments: GameSession.Formation.allCases)
  func changingFormationMidRunCrossesNoPaths(from start: GameSession.Formation) throws {
    let world = GameWorld(level: TestYard.level)
    choose(start, in: world)
    try walk(world, through: [Self.laneStart], label: "to the lane")
    try wait(world, seconds: 1)
    let east = stick(towards: [1, 0])
    for _ in 0..<90 { world.advanceParty(movement: east, deltaTime: 1 / 60) }
    world.session.cycleFormation()
    let changed = world.session.formation
    let companions = PartyMember.allCases.filter { $0 != world.session.leader }
    for frame in 0..<(3 * 60) {
      world.advanceParty(movement: east, deltaTime: 1 / 60)
      try #require(world.diagnostic == nil, "\(start) → \(changed), frame \(frame)")
      let first = position(world, companions[0])
      let second = position(world, companions[1])
      let firstTarget = try #require(world.companionTargets[companions[0]])
      let secondTarget = try #require(world.companionTargets[companions[1]])
      // Each companion's way to their new place stays clear of the other's.
      #expect(
        !crosses(first, firstTarget, second, secondTarget),
        "\(start) → \(changed), frame \(frame): \(first) → \(firstTarget), \(second) → \(secondTarget)"
      )
      #expect(
        simd_distance(first, second) >= 2 * PartyBody.radius, "\(start) → \(changed), \(frame)")
    }
  }

  // MARK: - Helpers

  private func choose(_ formation: GameSession.Formation, in world: GameWorld) {
    for _ in GameSession.Formation.allCases where world.session.formation != formation {
      world.session.cycleFormation()
    }
  }

  /// Whether two segments cross at a point inside both, rather than touching or overlapping.
  private func crosses(
    _ p1: SIMD2<Float>, _ p2: SIMD2<Float>, _ q1: SIMD2<Float>, _ q2: SIMD2<Float>
  ) -> Bool {
    func side(_ a: SIMD2<Float>, _ b: SIMD2<Float>, _ c: SIMD2<Float>) -> Float {
      (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
    }
    return side(q1, q2, p1) * side(q1, q2, p2) < 0 && side(p1, p2, q1) * side(p1, p2, q2) < 0
  }

  /// Screen-relative stick axes for a world heading, as GameWorld consumes them.
  private func stick(towards direction: SIMD2<Float>) -> SIMD2<Float> {
    let toCamera = SIMD2(TestYard.cameraOffset.x, TestYard.cameraOffset.z)
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
