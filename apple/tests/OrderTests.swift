import RealityKit
import Testing
import simd

@testable import Lauder

/// ADR 0003 phase S3: squad orders. Once the leader has two companions, the D-pad, the arrow
/// keys or the touch menu send both companions, or one of them, to a marked point, or tell them
/// to hold; the formation button calls them back. The world checks are in the test yard, whose
/// party is Miki, Laura and Tom: for Miki, Tom is on the left and Laura on the right.
@MainActor
struct OrderTests {
  /// The start of the yard's open lane, between the wreck and the south wall.
  private static let laneStart: SIMD2<Float> = [-6, 6]

  // MARK: - The session

  @Test
  func ordersWaitForTheSecondCompanion() {
    let session = GameSession(level: BrooklynBridge.level)
    session.recruit(.tom)
    #expect(!session.ordersAvailable, "Tom alone follows")
    #expect(!session.send(.tom, to: [0, 0]))
    #expect(!session.holdAll())
    #expect(session.orders.isEmpty)
    session.recruit(.laura)
    #expect(session.ordersAvailable)
    #expect(session.send(.tom, to: [1, 2]))
    #expect(session.order(of: .tom) == .going([1, 2]))
    #expect(!session.send(.miki, to: [1, 2]), "the leader takes no order")
  }

  @Test
  func theSidesKeepTheSwitchingOrderForWhoeverLeads() {
    // The bridge's party joins as Miki, Tom and Laura. Right is whoever Next would lead as.
    let session = GameSession(level: BrooklynBridge.level)
    session.recruit(.tom)
    #expect(session.leftCompanion == nil && session.rightCompanion == nil)
    session.recruit(.laura)
    let expected: [(PartyMember, PartyMember, PartyMember)] = [
      (.miki, .laura, .tom), (.tom, .miki, .laura), (.laura, .tom, .miki),
    ]
    for (leader, left, right) in expected {
      #expect(session.leader == leader)
      #expect(session.leftCompanion == left, "left of \(leader)")
      #expect(session.rightCompanion == right, "right of \(leader)")
      session.cycleLeader()
    }
  }

  @Test
  func theFormationButtonCallsEveryoneBackBeforeItCycles() {
    let session = GameSession(level: TestYard.level)
    session.send(.laura, to: [1, 1])
    session.pressFormation()
    #expect(session.orders.isEmpty)
    #expect(session.formation == .close, "the press called back rather than cycled")
    session.pressFormation()
    #expect(session.formation == .spread)
    session.holdAll()
    session.pressFormation()
    #expect(session.orders.isEmpty && session.formation == .spread)
  }

  @Test
  func pauseAndConversationsRefuseOrders() {
    let session = GameSession(level: TestYard.level)
    session.togglePause()
    #expect(!session.send(.laura, to: [1, 1]))
    #expect(!session.holdAll())
    session.togglePause()
    #expect(session.converse(.arrival))
    #expect(!session.send(.laura, to: [1, 1]))
    session.pressFormation()
    #expect(session.orders.isEmpty && session.formation == .close)
  }

  @Test
  func aSwitchClearsTheNewLeadersOrderAndTheOldLeaderJoinsTheSquad() {
    let session = GameSession(level: TestYard.level)
    // Everyone following: the old leader follows too.
    session.cycleLeader()
    #expect(session.leader == .laura && session.orders.isEmpty)
    // Everyone holding: the new leader's hold ends and the old leader holds where they stand.
    session.holdAll()
    session.cycleLeader()
    #expect(session.leader == .tom)
    #expect(session.order(of: .tom) == .following)
    #expect(session.order(of: .laura) == .holding(nil))
    #expect(session.order(of: .miki) == .holding(nil))
    // Only the new leader had an order: nobody else holds, so the old leader follows.
    session.pressFormation()
    session.send(.miki, to: [2, 2])
    session.cycleLeader()
    #expect(session.leader == .miki && session.orders.isEmpty)
  }

  @Test
  func arrivingTurnsGoingIntoHoldingAndRestartClearsEveryOrder() {
    let session = GameSession(level: TestYard.level)
    session.send(.laura, to: [3, 4])
    session.pin(.laura, at: [9, 9])
    #expect(session.order(of: .laura) == .going([3, 4]), "only a hold in place is pinned")
    session.arrived(.laura)
    #expect(session.order(of: .laura) == .holding([3, 4]))
    session.holdAll()
    session.pin(.tom, at: [5, 6])
    #expect(session.order(of: .tom) == .holding([5, 6]))
    session.restart()
    #expect(session.orders.isEmpty)
  }

  @Test
  func theSquadStateNamesWhoIsNotFollowing() {
    let session = GameSession(level: TestYard.level)
    #expect(session.squadState == "following")
    session.send(.laura, to: [1, 1])
    #expect(session.squadState == "Laura going")
    session.send(.tom, to: [2, 2])
    #expect(session.squadState == "going")
    session.arrived(.tom)
    #expect(session.squadState == "Laura going, Tom holding")
    session.holdAll()
    #expect(session.squadState == "holding")
  }

  // MARK: - The world

  @Test
  func bothGoAheadToSpotsSideBySideAndHoldWhileTheLeaderWalksOff() throws {
    let world = GameWorld(level: TestYard.level)
    try faceEast(world)
    let leader = position(world, .miki)
    give(.bothGo, to: world)
    let points = try [PartyMember.laura, .tom].map { member in
      guard case .going(let point) = world.session.order(of: member) else {
        throw Failure("\(member) is \(world.session.order(of: member))")
      }
      return point
    }
    #expect(simd_distance(points[0], points[1]) > 0.95, "\(points)")
    let middle = (points[0] + points[1]) / 2
    #expect(abs(simd_distance(middle, leader) - GameWorld.orderReach) < 0.2, "\(middle)")
    #expect(ring(world, .laura).isEnabled && ring(world, .tom).isEnabled)
    try wait(world, seconds: 4)
    for (member, point) in zip([PartyMember.laura, .tom], points) {
      #expect(world.session.order(of: member) == .holding(point))
      #expect(simd_distance(position(world, member), point) < 0.4)
      #expect(!ring(world, member).isEnabled, "the ring goes once \(member) arrives")
    }
    try walk(world, through: [[-9, 6]])
    try wait(world, seconds: 1)
    for (member, point) in zip([PartyMember.laura, .tom], points) {
      #expect(simd_distance(position(world, member), point) < 0.6, "\(member) held")
    }
  }

  @Test
  func oneGoesWhileTheOtherKeepsFollowing() throws {
    let world = GameWorld(level: TestYard.level)
    try faceEast(world)
    give(.rightGoes, to: world)
    #expect(world.session.rightCompanion == .laura)
    guard case .going(let point) = world.session.order(of: .laura) else {
      Issue.record("Laura is \(world.session.order(of: .laura))")
      return
    }
    #expect(world.session.order(of: .tom) == .following)
    try wait(world, seconds: 4)
    #expect(world.session.order(of: .laura) == .holding(point))
    // The left companion goes too, beside the first rather than onto the same spot.
    give(.leftGoes, to: world)
    guard case .going(let beside) = world.session.order(of: .tom) else {
      Issue.record("Tom is \(world.session.order(of: .tom))")
      return
    }
    #expect(simd_distance(beside, point) >= GameWorld.spotSpacing - 0.01)
    // Facing east, Tom on the left goes to the north of Laura's point, not through her.
    #expect(beside.y < point.y - 0.9 && abs(beside.x - point.x) < 0.2, "\(beside)")
    try wait(world, seconds: 4)
    #expect(simd_distance(position(world, .tom), position(world, .laura)) > 0.9)
  }

  @Test
  func holdKeepsBothWhereTheyStoodUntilCalledBack() throws {
    let world = GameWorld(level: TestYard.level)
    try faceEast(world)
    let stood = [PartyMember.laura, .tom].map { position(world, $0) }
    give(.hold, to: world)
    #expect(world.session.order(of: .laura) == .holding(stood[0]))
    try walk(world, through: [[-1, 7]])
    for (member, point) in zip([PartyMember.laura, .tom], stood) {
      #expect(simd_distance(position(world, member), point) < 0.3, "\(member) held")
    }
    var press = InputRules.Input.neutral
    press.formationPressed = true
    world.update(with: press, sampledIn: .exploring, deltaTime: 0)
    #expect(world.session.orders.isEmpty && world.session.formation == .close)
    try wait(world, seconds: 4)
    for member in [PartyMember.laura, .tom] {
      let target = try #require(world.companionTargets[member])
      #expect(simd_distance(position(world, member), target) < 0.6, "\(member) is back")
    }
  }

  @Test
  func theDpadPointStopsShortOfAWall() throws {
    // Facing the south wall from 2 m away, the point 6 m ahead moves back in front of it.
    let world = GameWorld(level: TestYard.level)
    try walk(world, through: [Self.laneStart, [-6, 7.4]])
    try wait(world, seconds: 1)
    give(.bothGo, to: world)
    for member in [PartyMember.laura, .tom] {
      guard case .going(let point) = world.session.order(of: member) else {
        Issue.record("\(member) is \(world.session.order(of: member))")
        continue
      }
      #expect(point.y > 7.4 && point.y < 9.4 - PartyBody.radius, "\(member): \(point)")
    }
    #expect(world.refusedOrders == 0)
  }

  @Test
  func aTouchOrderMarksTheGroundUnderTheFinger() throws {
    let world = GameWorld(level: TestYard.level)
    try faceEast(world)
    let wanted: SIMD2<Float> = [-2.5, 7]
    give(.rightGoes, to: world, touching: wanted)
    guard case .going(let point) = world.session.order(of: .laura) else {
      Issue.record("Laura is \(world.session.order(of: .laura))")
      return
    }
    #expect(simd_distance(point, wanted) < 0.05, "\(point)")
  }

  @Test
  func aTouchOrderKeepsThePointMarkedWhenItsMenuOpened() throws {
    let world = GameWorld(level: TestYard.level)
    try faceEast(world)
    let wanted: SIMD2<Float> = [-2.5, 7]
    let aspect: Float = 2.16
    let screen = try #require(world.projection(aspect: aspect).screen(ofGround: wanted))
    let press = InputRules.ScreenPoint(x: screen.x, y: screen.y, aspect: aspect)
    var opened = InputRules.Input.neutral
    opened.markPoint = press
    world.update(with: opened, sampledIn: .exploring, deltaTime: 0)
    // The leader walks on while the finger holds the menu open, and the camera follows.
    try walk(world, through: [[-3.5, 6]])
    var released = InputRules.Input.neutral
    released.command = .rightGoes
    released.commandPoint = press
    world.update(with: released, sampledIn: .exploring, deltaTime: 0)
    guard case .going(let point) = world.session.order(of: .laura) else {
      Issue.record("Laura is \(world.session.order(of: .laura))")
      return
    }
    #expect(simd_distance(point, wanted) < 0.05, "\(point)")
  }

  @Test
  func aPointNobodyCanReachIsRefusedWithABriefCross() throws {
    let world = GameWorld(level: TestYard.level)
    try walk(world, through: [Self.laneStart, [-6, 8]])
    // Beyond the south wall, off the yard's ground.
    give(.bothGo, to: world, touching: [-6, 11])
    #expect(world.session.orders.isEmpty)
    #expect(world.refusedOrders == 1)
    let cross = try #require(world.root.findEntity(named: "order.refused"))
    #expect(cross.isEnabled)
    try wait(world, seconds: GameWorld.crossTime + 0.2)
    #expect(!cross.isEnabled)
  }

  @Test
  func ordersReachTheWorldOnlyWhileExploringAndOnceOffered() {
    let world = GameWorld(level: BrooklynBridge.level)
    give(.bothGo, to: world)
    #expect(world.session.orders.isEmpty, "Miki is alone")
    let yard = GameWorld(level: TestYard.level)
    yard.session.togglePause()
    var input = InputRules.Input.neutral
    input.command = .hold
    yard.update(with: input, sampledIn: .paused, deltaTime: 1 / 60)
    #expect(yard.session.orders.isEmpty)
    yard.session.togglePause()
    yard.update(with: input, sampledIn: .exploring, deltaTime: 1 / 60)
    #expect(yard.session.order(of: .laura).word == "holding")
    yard.restart()
    #expect(yard.session.orders.isEmpty && yard.refusedOrders == 0)
  }

  // MARK: - Helpers

  private struct Failure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
  }

  /// Walk to the lane and a little east, then stop, so Miki faces east with open ground ahead.
  private func faceEast(_ world: GameWorld) throws {
    try walk(world, through: [Self.laneStart, [-5, 6]])
    try wait(world, seconds: 1.5)
  }

  /// An order as the world receives it: from the D-pad, or from the touch menu at the screen
  /// point where a point of the ground shows.
  private func give(
    _ command: GameSession.Command, to world: GameWorld, touching ground: SIMD2<Float>? = nil
  ) {
    var input = InputRules.Input.neutral
    input.command = command
    if let ground {
      let aspect: Float = 2.16
      if let screen = world.projection(aspect: aspect).screen(ofGround: ground) {
        input.commandPoint = InputRules.ScreenPoint(x: screen.x, y: screen.y, aspect: aspect)
      }
    }
    world.update(with: input, sampledIn: .exploring, deltaTime: 0)
  }

  private func ring(_ world: GameWorld, _ member: PartyMember) -> Entity {
    world.root.findEntity(named: "order.\(member.rawValue)") ?? Entity()
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

  private func walk(_ world: GameWorld, through points: [SIMD2<Float>]) throws {
    var index = 0
    var frame = 0
    while index < points.count {
      let offset = points[index] - position(world, world.session.leader)
      if simd_length(offset) < 0.15 {
        index += 1
        continue
      }
      world.advanceParty(movement: stick(towards: offset), deltaTime: 1 / 60)
      frame += 1
      try #require(world.diagnostic == nil, "frame \(frame): \(world.diagnostic ?? "")")
      try #require(frame < 60 * 30, "the leader did not reach \(points[index])")
    }
  }

  private func wait(_ world: GameWorld, seconds: Float) throws {
    for frame in 0..<Int(seconds * 60) {
      world.advanceParty(movement: .zero, deltaTime: 1 / 60)
      try #require(world.diagnostic == nil, "waiting, frame \(frame)")
    }
  }
}
