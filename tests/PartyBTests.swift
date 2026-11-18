import RealityKit
import Testing
import simd

@testable import Lauder

/// Party B: one closed barrier, opened by Lara's latch or Tomas's loose panel.
@MainActor
struct PartyBTests {
  private let latch = SIMD2<Float>(3.2, -5)
  private let panel = SIMD2<Float>(3.2, -4)

  @Test
  func theSessionAcceptsOnlyTheEligibleMemberAndOnlyOnce() {
    let session = GameSession()
    #expect(session.perform(.reachLatch, by: .miki) == .notEligible)
    #expect(session.perform(.reachLatch, by: .tomas) == .notEligible)
    #expect(session.perform(.shiftPanel, by: .lara) == .notEligible)
    #expect(!session.passageOpen)
    session.togglePause()
    #expect(session.perform(.reachLatch, by: .lara) == .unavailable)
    session.togglePause()
    #expect(session.perform(.reachLatch, by: .lara) == .done)
    #expect(session.passageOpen)
    #expect(session.perform(.shiftPanel, by: .tomas) == .alreadyDone)
    #expect(session.perform(.reachLatch, by: .miki) == .alreadyDone)
  }

  @Test
  func everyActionIsDefinedExactlyOnce() {
    for id in PrototypeLayout.ActionID.allCases {
      #expect(PrototypeLayout.interactions.filter { $0.id == id }.count == 1, "\(id.rawValue)")
    }
  }

  @Test
  func theClosedBarrierBlocksThePassageForEveryone() {
    let street = SIMD2<Float>(2.5, -4.5)
    let depot = SIMD2<Float>(6, -4.5)
    let closed = PartyMotion(
      radius: PrototypeLayout.characterRadius,
      obstacles: PrototypeLayout.obstacles(passageOpen: false))
    #expect(!closed.canTraverse(from: street, to: depot))
    #expect(NavigationGrid.forPassage(open: false).route(from: street, to: depot) == nil)
    #expect(NavigationGrid.forPassage(open: true).route(from: street, to: depot) != nil)
    // Both approaches are reachable on the street side while the barrier is closed.
    for interaction in [PrototypeLayout.ActionID.reachLatch, .shiftPanel].map(
      PrototypeLayout.interaction)
    {
      let centre = (interaction.approach.minimum + interaction.approach.maximum) / 2
      #expect(closed.canTraverse(from: centre, to: centre), "\(interaction.name)")
      #expect(NavigationGrid.forPassage(open: false).route(from: [-6, 3], to: centre) != nil)
    }
  }

  @Test(arguments: [PrototypeLayout.ActionID.reachLatch, .shiftPanel])
  func eitherMethodOpensThePassageForTheWholeParty(action: PrototypeLayout.ActionID) throws {
    let world = GameWorld()
    let interaction = PrototypeLayout.interaction(action)
    lead(world, try #require(interaction.member))
    try walk(world, to: [[2.5, 3], action == .reachLatch ? latch : panel])
    #expect(world.actionName == interaction.name)
    #expect(world.hint == nil)
    world.performAction()
    #expect(world.session.passageOpen)
    #expect(world.observation == interaction.result)
    #expect(world.actionName == nil)
    #expect(world.root.findEntity(named: "passage.barrier")?.isEnabled == false)

    // Everyone follows through the ordinary ground passage, in and back out.
    try walk(world, to: [[5, -4.5], [6.5, -3]])
    wait(world, seconds: 2)
    for member in PartyMember.allCases {
      #expect(isInDepot(position(world, member)), "\(member) inside")
    }
    try walk(world, to: [[5, -4.5], [2.5, -4.5], [2.5, 0]])
    wait(world, seconds: 2)
    for member in PartyMember.allCases {
      #expect(position(world, member).x < 3.6, "\(member) back on the street")
    }
    #expect(world.diagnostic == nil)
  }

  @Test
  func mikiExplainsBothMethodsAndCannotOpenEither() throws {
    let world = GameWorld()
    #expect(world.session.leader == .miki)
    try walk(world, to: [[2.5, 3], latch])
    #expect(world.actionName == nil)
    #expect(world.hint == PrototypeLayout.barrierHint)
    world.performAction()
    #expect(!world.session.passageOpen)
    #expect(world.observation == PrototypeLayout.barrierHint)
    try walk(world, to: [panel])
    world.performAction()
    #expect(!world.session.passageOpen)
  }

  @Test
  func promptsDoNotOutliveAMoveOrASwitch() throws {
    let world = GameWorld()
    lead(world, .lara)
    try walk(world, to: [[2.5, 3], latch])
    #expect(world.actionName == "Reach latch")
    // Moving away clears the prompt; a press there does not open anything.
    try walk(world, to: [[1.8, -5.2]])
    #expect(world.actionName == nil)
    world.performAction()
    #expect(!world.session.passageOpen)
    // Back at the latch, switching to Tomas turns the prompt into a suggestion.
    try walk(world, to: [latch])
    #expect(world.actionName == "Reach latch")
    world.session.cycleLeader()
    try walk(world, to: [latch])
    #expect(world.session.leader == .tomas)
    #expect(world.actionName == nil)
    #expect(world.hint == PrototypeLayout.interaction(.reachLatch).suggestion)
    world.performAction()
    #expect(!world.session.passageOpen)
  }

  @Test
  func repeatingEitherActionAfterOpeningChangesNothing() throws {
    let world = GameWorld()
    lead(world, .lara)
    try walk(world, to: [[2.5, 3], latch])
    world.performAction()
    #expect(world.session.passageOpen)
    world.performAction()
    #expect(world.observation == "The passage is already open.")
    lead(world, .tomas)
    try walk(world, to: [panel])
    #expect(world.actionName == nil)
    #expect(world.hint == nil)
    world.performAction()
    #expect(world.observation == "The passage is already open.")
    #expect(world.session.passageOpen)
  }

  @Test
  func companionsKeepClearOfTheApproachesWhileThePassageIsClosed() throws {
    let world = GameWorld()
    lead(world, .lara)
    try walk(world, to: [[2.5, 3], latch])
    wait(world, seconds: 3)
    for member in PartyMember.allCases where member != .lara {
      let body = position(world, member)
      for interaction in PrototypeLayout.interactions {
        #expect(!interaction.approach.contains(body), "\(member) stands in \(interaction.name)")
      }
    }
  }

  // MARK: - Helpers

  private func lead(_ world: GameWorld, _ member: PartyMember) {
    while world.session.leader != member { world.session.cycleLeader() }
  }

  /// Screen-relative stick axes for a world direction, as GameWorld consumes them.
  private func stick(towards direction: SIMD2<Float>) -> SIMD2<Float> {
    let toCamera = SIMD2(PrototypeLayout.cameraOffset.x, PrototypeLayout.cameraOffset.z)
    let forward = -simd_normalize(toCamera)
    let right = SIMD2(-forward.y, forward.x)
    let unit = simd_normalize(direction)
    return SIMD2(simd_dot(unit, right), simd_dot(unit, forward))
  }

  private func isInDepot(_ point: SIMD2<Float>) -> Bool {
    point.x > 4.2 && point.x < 9.8 && point.y > -6.8 && point.y < -1.2
  }

  private func position(_ world: GameWorld, _ member: PartyMember) -> SIMD2<Float> {
    guard let body = world.root.findEntity(named: "party.\(member.rawValue)") else {
      return [.nan, .nan]
    }
    return SIMD2(body.position.x, body.position.z)
  }

  private func walk(_ world: GameWorld, to points: [SIMD2<Float>]) throws {
    var frame = 0
    for point in points {
      while simd_distance(position(world, world.session.leader), point) >= 0.15 {
        world.advanceParty(
          movement: stick(towards: point - position(world, world.session.leader)),
          deltaTime: 1 / 60)
        frame += 1
        try #require(frame < 60 * 30, "the leader did not reach \(point)")
      }
    }
  }

  private func wait(_ world: GameWorld, seconds: Float) {
    for _ in 0..<Int(seconds * 60) { world.advanceParty(movement: .zero, deltaTime: 1 / 60) }
  }
}
