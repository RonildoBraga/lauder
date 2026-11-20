import Foundation
import RealityKit
import Testing
import simd

@testable import Lauder

/// ADR 0004, milestone M3: searching the stranger, the ambush, Tom's shot and Tom joining. The
/// session's rules, the attacker's charge and the whole scene in the world, without rendering.
@MainActor
struct AmbushTests {
  // MARK: - Session

  @Test
  func theSearchComesAfterTheFightAndBeginsTheAmbushOnce() {
    let session = GameSession(level: BrooklynBridge.level)
    #expect(!session.offers(.searchStranger))
    #expect(session.perform(.searchStranger) == .notYet)
    #expect(session.beginEncounter(.stranger))
    session.defeat("stranger")
    // Not while the fight is still being settled.
    #expect(!session.offers(.searchStranger))
    session.endEncounter()
    #expect(session.offers(.searchStranger))
    #expect(session.perform(.searchStranger) == .done)
    #expect(session.beat == .ambush && session.inEncounter)
    #expect(!session.offers(.searchStranger))
    #expect(session.perform(.searchStranger) == .alreadyDone)
    // The loot is taken once, when the search finishes.
    let loot = BrooklynBridge.stranger.loot ?? Level.Loot()
    #expect(loot.rounds > 0 && loot.medicalKits == 1)
    #expect(session.search("stranger", loot: loot))
    #expect(!session.search("stranger", loot: loot))
    #expect(session.ammo == 12 + loot.rounds && session.medicalKits == 1)
    session.restart()
    #expect(session.searched.isEmpty && session.medicalKits == 0 && session.ammo == 12)
    #expect(session.beat == .alone && session.defeated.isEmpty)
  }

  @Test
  func theExchangeEndsWithTomJoiningUnlessARestartComesFirst() {
    let session = GameSession(level: BrooklynBridge.level)
    for _ in 0..<2 {
      #expect(session.beginEncounter(.stranger))
      session.defeat("stranger")
      session.endEncounter()
      #expect(session.perform(.searchStranger) == .done)
      #expect(session.converse(.metTom))
      #expect(session.mode == .dialogue && session.party == [.miki])
      #expect(!session.converse(.metTom))
      session.advanceDialogue()
      // A Restart in the middle of the exchange: nobody has joined.
      session.restart()
      #expect(session.party == [.miki] && session.beat == .alone && session.mode == .exploring)
    }
    #expect(session.beginEncounter(.stranger))
    session.defeat("stranger")
    session.endEncounter()
    #expect(session.perform(.searchStranger) == .done)
    #expect(session.converse(.metTom))
    for _ in MissionScript.lines(.metTom) { session.advanceDialogue() }
    #expect(session.mode == .exploring)
    #expect(session.party == [.miki, .tom] && session.beat == .withTom)
    #expect(session.nextLeader == .tom)
  }

  // MARK: - The attacker

  @Test
  func theAttackerStepsOutThenRunsAtTheLeaderAndStopsShortOfHer() {
    var attacker = HostileState(spec: BrooklynBridge.attacker)
    let target = SIMD2<Float>(4.4, 4.6)
    let dt = GameWorld.simulationStep
    attacker.reveal()
    attacker.engage()
    var shots = 0
    for _ in 0..<Int((HostileState.stepOutTime + 1) / dt) {
      if attacker.step(dt: dt, canHit: true, toward: target) != nil { shots += 1 }
    }
    // One second of running at five metres a second.
    let ran = simd_distance(attacker.position, BrooklynBridge.attacker.standAt)
    #expect(abs(ran - 5) < 0.1)
    for _ in 0..<Int(8 / dt) {
      if attacker.step(dt: dt, canHit: true, toward: target) != nil { shots += 1 }
    }
    #expect(shots == 0 && !attacker.isTargetable)
    #expect(abs(simd_distance(attacker.position, target) - HostileState.reach) < 0.01)
    attacker.knockDown()
    let down = attacker.position
    _ = attacker.step(dt: 1, canHit: true, toward: [0, 0])
    #expect(attacker.position == down)
  }

  // MARK: - The scene in the world

  @Test
  func theSearchIsOfferedOnceTheStrangerIsDownAndOnlyAtHisBody() {
    let world = GameWorld(level: BrooklynBridge.level)
    winTheFight(world)
    #expect(world.actionName == nil)
    walk(world, to: [4.4, 4.6])
    #expect(world.actionName == "Search")
  }

  @Test
  func theAmbushPlaysTheSameWayEveryTime() {
    let world = GameWorld(level: BrooklynBridge.level)
    var runs: [[String]] = []
    for _ in 0..<3 {
      winTheFight(world)
      walk(world, to: [4.4, 4.6])
      let searchedFrom = position(world, .miki)
      world.performAction()
      #expect(world.session.beat == .ambush)
      // The stick and Fire are held throughout; a scene holds Miki where she is.
      var trace: [String] = []
      for frame in 0..<(60 * 5) where world.session.mode == .exploring {
        world.advanceParty(
          movement: [0.6, 1], fireHeld: true, firePressed: frame == 0, deltaTime: 1 / 60)
        if frame % 6 == 0 { trace.append(describe(world)) }
      }
      #expect(world.session.mode == .dialogue)
      #expect(simd_distance(position(world, .miki), searchedFrom) < 0.001)
      runs.append(trace)
      world.restart()
    }
    #expect(runs[0].count > 30)
    #expect(runs[1] == runs[0])
    #expect(runs[2] == runs[0])
  }

  @Test
  func tomDropsTheAttackerShortOfMikiThenJoinsAndFollows() throws {
    let world = GameWorld(level: BrooklynBridge.level)
    let tom = try #require(world.root.findEntity(named: "party.tom"))
    let attacker = try #require(world.root.findEntity(named: "hostile.attacker"))
    winTheFight(world)
    walk(world, to: [4.4, 4.6])
    let ammo = world.session.ammo
    world.performAction()
    #expect(world.observation == BrooklynBridge.searchStranger.result)
    #expect(!tom.isEnabled && !attacker.isEnabled)
    #expect(run(world, upTo: 2) { world.threat == "The attacker is running at you." })
    #expect(attacker.isEnabled)
    #expect(run(world, upTo: 2) { world.session.medicalKits == 1 })
    #expect(world.observation == "Found 6 rounds and a medical kit.")
    #expect(world.session.ammo == ammo + 6)
    #expect(run(world, upTo: 2) { world.session.defeated.contains("attacker") })
    #expect(tom.isEnabled && world.session.party == [.miki] && world.threat == nil)
    // He falls well short of Miki, round the pier's corner, where Tom had a clear shot at him.
    let fell = SIMD2(attacker.position.x, attacker.position.z)
    #expect(simd_distance(fell, position(world, .miki)) > 5)
    #expect(
      LineOfSight.isClear(
        from: position(world, .tom), to: fell, obstacles: BrooklynBridge.level.obstacles))
    #expect(run(world, upTo: 2) { world.session.mode == .dialogue })
    #expect(world.session.currentLine?.speaker == "Tom")
    #expect(!world.session.inEncounter)
    finishConversation(world)
    #expect(world.session.party == [.miki, .tom] && world.session.beat == .withTom)
    #expect(world.session.nextLeader == .tom)
    // Tom follows Miki on towards Manhattan.
    walk(world, to: [6.5, -12])
    run(world, upTo: 3)
    #expect(simd_distance(position(world, .tom), position(world, .miki)) < 3)
    #expect(world.diagnostic == nil)
  }

  @Test
  func pauseHoldsTheSceneAndRestartPutsEverythingBack() throws {
    let world = GameWorld(level: BrooklynBridge.level)
    let entities = count(world.root)
    let attacker = try #require(world.root.findEntity(named: "hostile.attacker"))
    let tom = try #require(world.root.findEntity(named: "party.tom"))
    winTheFight(world)
    walk(world, to: [4.4, 4.6])
    world.performAction()
    #expect(run(world, upTo: 2) { world.threat != nil })
    let before = attacker.position
    pressPause(world)
    for _ in 0..<120 { world.update(with: .neutral, sampledIn: .paused, deltaTime: 1 / 60) }
    #expect(attacker.position == before && world.threat != nil)
    pressPause(world)
    #expect(run(world, upTo: 3) { world.session.mode == .dialogue })
    #expect(tom.isEnabled)
    world.restart()
    #expect(world.session.party == [.miki] && world.session.beat == .alone)
    #expect(world.session.medicalKits == 0 && world.session.ammo == 12)
    #expect(world.session.searched.isEmpty && world.session.defeated.isEmpty)
    #expect(world.session.mode == .exploring && world.session.currentLine == nil)
    #expect(!tom.isEnabled && !attacker.isEnabled)
    #expect(position(world, .tom) == BrooklynBridge.level.spawn(.tom))
    #expect(count(world.root) == entities)
  }

  // MARK: - Prompts, conversations and the pause menu in play

  @Test
  func theSearchPromptDoesNotOutliveAMove() {
    let world = GameWorld(level: BrooklynBridge.level)
    winTheFight(world)
    walk(world, to: [4.4, 4.6])
    #expect(world.actionName == "Search")
    walk(world, to: [4.4, 8.6])
    #expect(world.actionName == nil)
    world.performAction()
    #expect(world.session.searched.isEmpty && world.session.beat == .stranger)
  }

  @Test
  func inTheExchangeTheActionOnlyShowsTheNextLine() {
    let world = GameWorld(level: BrooklynBridge.level)
    winTheFight(world)
    walk(world, to: [4.4, 4.6])
    world.performAction()
    #expect(run(world, upTo: 6) { world.session.mode == .dialogue })
    let line = world.session.lineIndex
    let observation = world.observation
    let before = position(world, .miki)
    let press = InputRules.Input(
      movement: [1, 0], actionPressed: true, pausePressed: false, switchPressed: true)
    world.update(with: press, sampledIn: .dialogue, deltaTime: 1 / 60)
    #expect(world.session.lineIndex == line + 1)
    #expect(world.session.leader == .miki)
    #expect(position(world, .miki) == before)
    // Miki stands at the searched body, but the press only showed the next line.
    #expect(world.observation == observation)
  }

  @Test
  func thePauseMenuConfirmsItsChoiceAndNeverActsOnTheBody() {
    let world = GameWorld(level: BrooklynBridge.level)
    winTheFight(world)
    walk(world, to: [4.4, 4.6])
    #expect(world.actionName == "Search")
    let pause = InputRules.Input(
      movement: .zero, actionPressed: false, pausePressed: true, switchPressed: false)
    let action = InputRules.Input(
      movement: .zero, actionPressed: true, pausePressed: false, switchPressed: false)
    let down = InputRules.Input(
      movement: .zero, actionPressed: false, pausePressed: false, switchPressed: false,
      menuMove: 1)
    let before = position(world, .miki)
    // Confirming at once resumes: the menu opens on Resume. Nothing is searched.
    world.update(with: pause, sampledIn: .exploring, deltaTime: 1 / 60)
    #expect(world.session.isPaused)
    world.update(
      with: InputRules.Input(
        movement: [1, 0], actionPressed: false, pausePressed: false, switchPressed: false),
      sampledIn: .paused, deltaTime: 1 / 60)
    world.update(with: action, sampledIn: .paused, deltaTime: 1 / 60)
    #expect(world.session.mode == .exploring)
    #expect(world.session.searched.isEmpty && world.session.beat == .stranger)
    #expect(position(world, .miki) == before)
    #expect(world.controls.needsNeutralInput)
    // Down, then confirm, restarts.
    world.update(with: pause, sampledIn: .exploring, deltaTime: 1 / 60)
    world.update(with: down, sampledIn: .paused, deltaTime: 1 / 60)
    #expect(world.session.pauseChoice == .restart)
    world.update(with: action, sampledIn: .paused, deltaTime: 1 / 60)
    #expect(world.session.mode == .exploring)
    #expect(world.session.defeated.isEmpty && world.session.beat == .alone)
    #expect(position(world, .miki) == BrooklynBridge.level.spawn(.miki))
    #expect(world.controls.needsNeutralInput)
    // The touch Restart button restarts directly from the menu.
    walk(world, to: [6.5, 110])
    world.update(with: pause, sampledIn: .exploring, deltaTime: 1 / 60)
    world.update(
      with: InputRules.Input(
        movement: .zero, actionPressed: false, pausePressed: false, switchPressed: false,
        restartPressed: true),
      sampledIn: .paused, deltaTime: 1 / 60)
    #expect(world.session.mode == .exploring)
    #expect(position(world, .miki) == BrooklynBridge.level.spawn(.miki))
  }

  // MARK: - Helpers

  /// From the start of a run: walk into the stranger's fight and put him down after his miss.
  private func winTheFight(_ world: GameWorld) {
    walk(world, to: [6.5, 15])
    #expect(run(world, upTo: 4) { world.threat != nil })
    #expect(run(world, upTo: 2) { world.threat == nil })
    #expect(run(world, upTo: 2, fire: true) { world.session.defeated.contains("stranger") })
    #expect(run(world, upTo: 1) { !world.session.inEncounter })
  }

  /// What can be seen of the scene at a moment, to the centimetre.
  private func describe(_ world: GameWorld) -> String {
    let attacker = world.root.findEntity(named: "hostile.attacker")
    let place = attacker.map { String(format: "%.2f,%.2f", $0.position.x, $0.position.z) } ?? "-"
    let tom = world.root.findEntity(named: "party.tom")?.isEnabled == true
    return [
      place, "\(attacker?.isEnabled == true)", "tom \(tom)", world.observation,
      world.threat ?? "-", "ammo \(world.session.ammo)", "kits \(world.session.medicalKits)",
      "down \(world.session.defeated.count)",
    ].joined(separator: " | ")
  }
}
