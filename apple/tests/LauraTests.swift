import Foundation
import RealityKit
import Testing
import simd

@testable import Lauder

/// ADR 0004, milestone M4: Laura found hurt at mid-span, Help with the medical kit, Laura
/// joining, the three travelling on, and the end of the opening at the Manhattan end.
@MainActor
struct LauraTests {
  // MARK: - Session

  @Test
  func helpComesAfterTomAndUsesTheMedicalKitOnce() {
    let session = GameSession(level: BrooklynBridge.level)
    #expect(!session.offers(.helpLaura))
    #expect(session.perform(.helpLaura) == .notYet)
    joinTom(session)
    #expect(session.medicalKits == 1)
    // She is found only as the party nears her, and Help waits for that moment to pass.
    #expect(!session.offers(.helpLaura))
    #expect(session.beginEncounter(.lauraFound))
    #expect(!session.offers(.helpLaura))
    #expect(session.perform(.helpLaura) == .unavailable)
    #expect(session.medicalKits == 1)
    session.endEncounter()
    #expect(session.offers(.helpLaura))
    #expect(session.perform(.helpLaura) == .done)
    #expect(session.beat == .helpingLaura && session.inEncounter && session.medicalKits == 0)
    #expect(!session.offers(.helpLaura))
    #expect(session.perform(.helpLaura) == .alreadyDone)
    session.endEncounter()
    #expect(session.converse(.metLaura))
    // A Restart during the exchange would leave her behind; finishing it brings her along.
    for _ in MissionScript.lines(.metLaura) { session.advanceDialogue() }
    #expect(session.party == [.miki, .tom, .laura] && session.beat == .withLaura)
    #expect(session.perform(.helpLaura) == .alreadyDone)
    session.restart()
    #expect(session.party == [.miki] && session.beat == .alone && session.medicalKits == 0)
  }

  @Test
  func theOpeningEndsOnlyWithAllThree() {
    let session = GameSession(level: BrooklynBridge.level)
    joinTom(session)
    #expect(!session.beginEncounter(.arrived))
    #expect(session.beginEncounter(.lauraFound))
    session.endEncounter()
    #expect(!session.beginEncounter(.arrived))
    #expect(session.perform(.helpLaura) == .done)
    session.endEncounter()
    #expect(!session.beginEncounter(.arrived))
    #expect(session.converse(.metLaura))
    for _ in MissionScript.lines(.metLaura) { session.advanceDialogue() }
    #expect(session.beginEncounter(.arrived))
    #expect(session.beat == .arrived)
  }

  // MARK: - In play

  @Test
  func lauraLiesHurtInViewFromTheStart() throws {
    let world = GameWorld(level: BrooklynBridge.level)
    let laura = try #require(world.root.findEntity(named: "party.laura"))
    #expect(laura.isEnabled && !world.session.party.contains(.laura))
    #expect(position(world, .laura) == BrooklynBridge.level.spawn(.laura))
    let visual = try #require(laura.children.first)
    #expect(isLying(visual))
    #expect(try #require(world.root.findEntity(named: "party.tom")).isEnabled == false)
  }

  @Test
  func helpingLauraThenTheThreeReachManhattanTogether() throws {
    let world = GameWorld(level: BrooklynBridge.level)
    let entities = count(world.root)
    let laura = try #require(world.root.findEntity(named: "party.laura"))
    let visual = try #require(laura.children.first)
    joinTom(world)
    // Across the gap in the divider, a woman calls out. Until she joins, only Tom follows.
    walk(world, to: [6.5, -225.15])
    #expect(Set(world.companionTargets.keys) == [.tom])
    walk(world, to: [-6, -228.15])
    walk(world, to: [-6.5, -230.15])
    #expect(world.session.beat == .lauraFound)
    #expect(world.objective == "Help the woman between the cars.")
    #expect(run(world, upTo: 1) { world.observation == "A woman: “Please. Over here.”" })
    // The camera leans towards her while she calls out, then settles back behind Miki.
    let camera = try #require(world.root.findEntity(named: "camera"))
    let lean = { BrooklynBridge.cameraOffset.z - (camera.position.z - position(world, .miki).y) }
    #expect(run(world, upTo: 1.5) { lean() > 2 })
    #expect(run(world, upTo: 2) { !world.session.inEncounter })
    #expect(world.observation == "Miki: “Hold on. We're coming.”")
    #expect(run(world, upTo: 3) { abs(lean()) < 0.05 })
    walk(world, to: [-7, -234.15])
    #expect(world.actionName == "Help")
    world.performAction()
    #expect(world.observation == BrooklynBridge.helpLaura.result)
    #expect(world.session.medicalKits == 0)
    // The scene holds the leader despite the stick, and Laura gets up.
    let heldAt = position(world, .miki)
    for _ in 0..<(60 * 2) where world.session.mode == .exploring {
      world.advanceParty(movement: [1, 0], deltaTime: 1 / 60)
    }
    #expect(simd_distance(position(world, .miki), heldAt) < 0.001)
    #expect(!isLying(visual))
    #expect(run(world, upTo: 1) { world.session.mode == .dialogue })
    #expect(world.session.currentLine?.speaker == "Laura")
    finishConversation(world)
    #expect(world.session.party == [.miki, .tom, .laura] && world.session.beat == .withLaura)
    #expect(world.objective == "Cross to Manhattan together.")
    // Both companions follow up the west roadway.
    walk(world, to: [-7, -257.15])
    run(world, upTo: 3)
    for member in [PartyMember.tom, .laura] {
      #expect(simd_distance(position(world, member), position(world, .miki)) < 3, "\(member)")
    }
    #expect(world.diagnostic == nil)
    // At the Manhattan end the party stops for the closing exchange.
    walk(world, to: [-7, -502.3])
    #expect(world.session.mode == .dialogue)
    finishConversation(world)
    #expect(world.session.beat == .arrived && world.objective == "Manhattan, together.")
    // Restart puts Laura back on the deck, hurt, without adding entities.
    world.restart()
    #expect(world.session.party == [.miki] && world.session.beat == .alone)
    #expect(laura.isEnabled && isLying(visual))
    #expect(position(world, .laura) == BrooklynBridge.level.spawn(.laura))
    #expect(world.objective == "Cross the bridge to Manhattan.")
    #expect(count(world.root) == entities)
  }

  @Test
  func withTomLeadingHelpStillHoldsEveryoneAndTurnsMikiToLaura() {
    let world = GameWorld(level: BrooklynBridge.level)
    joinTom(world)
    findLaura(world)
    // Tom leads to her and helps; Miki follows as a companion.
    switchLeader(world)
    #expect(world.session.leader == .tom)
    walk(world, to: [-7, -234.15])
    #expect(world.actionName == "Help")
    world.performAction()
    #expect(world.session.beat == .helpingLaura)
    let mikiAt = position(world, .miki)
    let tomAt = position(world, .tom)
    // Despite the stick, nobody moves until the exchange, and then Miki and Laura face each other.
    for _ in 0..<(60 * 3) where world.session.mode == .exploring {
      world.advanceParty(movement: [1, 0], deltaTime: 1 / 60)
    }
    #expect(world.session.mode == .dialogue)
    #expect(simd_distance(position(world, .miki), mikiAt) < 0.001)
    #expect(simd_distance(position(world, .tom), tomAt) < 0.001)
    #expect(faces(world, .miki, .laura) && faces(world, .laura, .miki))
  }

  @Test
  func passingTheLeadToTomDuringHelpKeepsMikiFacingLaura() {
    let world = GameWorld(level: BrooklynBridge.level)
    joinTom(world)
    findLaura(world)
    walk(world, to: [-7, -234.15])
    world.performAction()
    #expect(world.session.beat == .helpingLaura)
    // Once the two have turned to each other, the lead passes to Tom before the exchange.
    #expect(run(world, upTo: 2) { faces(world, .miki, .laura) })
    #expect(world.session.mode == .exploring)
    let mikiAt = position(world, .miki)
    switchLeader(world)
    #expect(world.session.leader == .tom)
    for _ in 0..<60 where world.session.mode == .exploring {
      world.advanceParty(movement: [1, 0], deltaTime: 1 / 60)
    }
    #expect(world.session.mode == .dialogue)
    #expect(simd_distance(position(world, .miki), mikiAt) < 0.001)
    #expect(faces(world, .miki, .laura))
  }

  // MARK: - Helpers

  /// The session's way to Tom joining: the fight, the search and its loot, and the exchange.
  private func joinTom(_ session: GameSession) {
    #expect(session.beginEncounter(.stranger))
    session.defeat("stranger")
    session.endEncounter()
    #expect(session.perform(.searchStranger) == .done)
    #expect(session.search("stranger", loot: BrooklynBridge.stranger.loot ?? Level.Loot()))
    session.endEncounter()
    #expect(session.converse(.metTom))
    for _ in MissionScript.lines(.metTom) { session.advanceDialogue() }
    #expect(session.beat == .withTom)
  }

  /// The same in play, from the start of a run: the stranger's fight, the search, the ambush
  /// and the exchange.
  private func joinTom(_ world: GameWorld) {
    walk(world, to: [6.5, 51])
    #expect(run(world, upTo: 4) { world.threat != nil })
    #expect(run(world, upTo: 2) { world.threat == nil })
    #expect(run(world, upTo: 2, fire: true) { world.session.defeated.contains("stranger") })
    #expect(run(world, upTo: 1) { !world.session.inEncounter })
    walk(world, to: [6.5, 43])
    world.performAction()
    #expect(run(world, upTo: 6) { world.session.mode == .dialogue })
    finishConversation(world)
    #expect(world.session.beat == .withTom)
  }

  /// From Tom joining, across the gap in the divider until Laura has called out.
  private func findLaura(_ world: GameWorld) {
    walk(world, to: [6.5, -225.15])
    walk(world, to: [-6, -228.15])
    walk(world, to: [-6.5, -230.15])
    #expect(world.session.beat == .lauraFound)
    #expect(run(world, upTo: 3) { !world.session.inEncounter })
  }

  /// One press of the switch control, as the controls deliver it.
  private func switchLeader(_ world: GameWorld) {
    let press = InputRules.Input(
      movement: .zero, actionPressed: false, pausePressed: false, switchPressed: true)
    world.update(with: press, sampledIn: .exploring, deltaTime: 1 / 60)
  }

  /// Whether one member's stand-in faces another, within about 8°.
  private func faces(_ world: GameWorld, _ member: PartyMember, _ other: PartyMember) -> Bool {
    guard let visual = world.root.findEntity(named: "party.\(member.rawValue)")?.children.first
    else { return false }
    let forward = visual.orientation.act([0, 0, -1])
    let towards = position(world, other) - position(world, member)
    guard simd_length(towards) > 0.01 else { return false }
    return simd_dot(simd_normalize(SIMD2(forward.x, forward.z)), simd_normalize(towards)) > 0.99
  }

  /// A stand-in lying face down: its head points along the deck, and it rests on it.
  private func isLying(_ visual: Entity) -> Bool {
    abs(visual.orientation.act([0, 1, 0]).y) < 0.01 && visual.position.y < -0.5
  }

  private func finishConversation(_ world: GameWorld) {
    let press = InputRules.Input(
      movement: .zero, actionPressed: true, pausePressed: false, switchPressed: false)
    for _ in 0..<20 where world.session.mode == .dialogue {
      world.update(with: press, sampledIn: .dialogue, deltaTime: 1 / 60)
    }
  }

  /// Run the world until the condition holds, for at most the given time, and say whether it
  /// held. Fire is pressed on the first frame and held throughout.
  @discardableResult
  private func run(
    _ world: GameWorld, upTo seconds: Float, fire: Bool = false,
    until done: () -> Bool = { false }
  ) -> Bool {
    var pressed = fire
    for _ in 0..<Int(seconds * 60) {
      if done() { return true }
      if world.isRetrying {
        world.update(with: .neutral, sampledIn: world.session.mode, deltaTime: 1 / 60)
      } else {
        world.advanceParty(
          movement: .zero, fireHeld: fire, firePressed: pressed, deltaTime: 1 / 60)
        pressed = false
      }
    }
    return done()
  }

  /// Steer the leader straight to a point, slowing for the last metre. A scene that holds the
  /// leader stops the walk where it is.
  private func walk(_ world: GameWorld, to point: SIMD2<Float>) {
    let offset = BrooklynBridge.cameraOffset
    let forward = -simd_normalize(SIMD2(offset.x, offset.z))
    let right = SIMD2(-forward.y, forward.x)
    for _ in 0..<(60 * 120) where world.session.mode == .exploring {
      let towards = point - position(world, world.session.leader)
      if simd_length(towards) < 0.15 { return }
      let unit = simd_normalize(towards)
      let strength = min(1, max(0.35, simd_length(towards)))
      world.advanceParty(
        movement: SIMD2(simd_dot(unit, right), simd_dot(unit, forward)) * strength,
        deltaTime: 1 / 60)
    }
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
