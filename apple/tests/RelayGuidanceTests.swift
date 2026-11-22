import Testing
import simd

@testable import Lauder

/// Guidance follows what the party knows, and the closing exchange requires their real return.
@MainActor
struct RelayGuidanceTests {
  @Test
  func anUnknownWrongModelLeadsHomeUntilAnActualFailedFitRevealsIt() throws {
    let world = GameWorld(level: RelayRun.level)
    let task = RelayRun.salvage
    #expect(world.objective == world.level.objective)
    #expect(world.compass?.name == task.depotGoal?.name)

    let wrong = try #require(
      task.cabinets.first { world.session.salvage.contents[$0.id] == .otherModel })
    world.session.cycleLeader()
    #expect(world.session.leader == .tom)
    // Set up a blind find through the same session action the cabinet's world interaction uses.
    // The party must not learn the hidden model from an omniscient objective or compass.
    try #require(world.session.performSalvage(at: .cabinet(wrong.id)) != nil)
    world.advanceParty(movement: .zero, deltaTime: 1 / 60)
    #expect(world.session.salvage.regulators.map(\.known) == [false])
    #expect(world.session.salvage.regulators.map(\.model) == [.otherModel])
    #expect(world.objective == task.returnObjective)
    #expect(world.compass?.name == task.returnGoal?.name)

    walk(world, to: RelayRun.transmitterPoint)
    try #require(run(world, upTo: 8) { gathered(world) })
    try #require(world.actionName == "Fit regulator")
    world.performAction()
    #expect(!world.session.salvage.repaired && world.session.mode == .exploring)
    #expect(world.observation == "This regulator is a different model. It won't fit.")
    #expect(world.session.salvage.regulators.map(\.known) == [true])
    #expect(world.objective == world.level.objective)
    #expect(world.compass?.name == task.depotGoal?.name)
    #expect(world.actionName == nil)
    world.performAction()
    #expect(world.observation == "This regulator won't fit. Miki could tell the models apart.")
  }

  @Test
  func theRepairWaitsForAHeldCompanionAndStartsItsExchangeOnlyOnceAfterRegroup() throws {
    let world = GameWorld(level: RelayRun.level)
    let task = RelayRun.salvage
    let right = try #require(
      task.cabinets.first { world.session.salvage.contents[$0.id] == .compatible })
    // Establish a collected part; movement/approach validation is covered by the full journey.
    try #require(world.session.performSalvage(at: .cabinet(right.id)) != nil)
    try #require(world.session.performSalvage(at: .cabinet(right.id)) != nil)
    #expect(world.session.salvage.regulators.map(\.model) == [.compatible])

    // Tom really walks to a distant point and holds there while the other two return home.
    #expect(world.session.send(.tom, to: [-12.5, 5]))
    try #require(run(world, upTo: 12) { world.session.order(of: .tom).word == "holding" })
    walk(world, to: RelayRun.transmitterPoint)
    try #require(simd_distance(position(world, .tom), position(world, .miki)) > 5)
    try #require(world.actionName == "Fit regulator")
    let bag = world.session.salvage.regulators
    for _ in 0..<2 {
      world.performAction()
      #expect(world.observation == "Bring everyone back to the transmitter.")
      #expect(!world.session.salvage.repaired && world.session.salvage.regulators == bag)
      #expect(world.session.mode == .exploring && world.session.conversation == nil)
    }

    world.session.pressFormation()
    try #require(run(world, upTo: 12) { gathered(world) })
    world.performAction()
    #expect(world.session.salvage.repaired && world.session.salvage.regulators.isEmpty)
    #expect(world.session.mode == .dialogue && world.session.conversation == .relayRestored)
    #expect(world.session.lineIndex == 0)
    world.performAction()
    #expect(world.session.lineIndex == 0 && world.session.conversation == .relayRestored)
    finishConversation(world)
    #expect(world.session.mode == .exploring && world.session.conversation == nil)
    world.performAction()
    #expect(world.session.mode == .exploring && world.session.conversation == nil)
    #expect(world.session.salvage.repaired && world.session.salvage.regulators.isEmpty)
    #expect(world.objective == task.doneObjective && world.compass == nil)
  }

  private func gathered(_ world: GameWorld) -> Bool {
    let leader = position(world, world.session.leader)
    return world.session.party.allSatisfy { simd_distance(position(world, $0), leader) < 4 }
  }
}
