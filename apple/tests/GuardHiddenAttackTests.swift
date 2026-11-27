import Testing
import simd

@testable import Lauder

@MainActor
struct GuardHiddenAttackTests {
  @Test(arguments: [false, true])
  func anActualCompanionHitEarnsRetaliationOnlyWhenTheGuardCanSeeItsAttacker(hidden: Bool) throws {
    let figures: [PartyMember: SIMD2<Float>] = [.tom: [6, 6], .miki: [0, 6], .laura: [-6, 6]]
    let height: Float = hidden ? 1.45 : 1.35
    // The near-guard wall separates two real rays: Miki's rising rifle-to-eye shot clears
    // it, while the guard's 1.52 m sight line to her 1.25 m body is blocked at the higher height.
    let wall = Level.Box.box("low-screen", at: [0, height / 2, 1.9], size: [2.4, height, 0.1])
    let hostile = Level.Hostile(
      id: "guard", name: "Guard", hiddenAt: .zero, standAt: .zero, hits: 6,
      attack: .robot, strategicGuard: true)
    let encounter = Level.Encounter(
      beat: .stranger, start: .area(.init(minimum: [-20, -20], maximum: [20, 20])),
      retryAt: nil, hostiles: [hostile], cues: [(0, .reveal("guard")), (0, .engage("guard"))])
    let level = Level(
      id: "real-hidden-companion", ground: .box("floor", at: [0, -0.15, 0], size: [60, 0.3, 60]),
      boxes: [wall], triggers: [], encounters: [encounter], party: [.tom, .miki, .laura],
      spawns: figures, heading: [0, -1], cameraOffset: BrooklynBridge.cameraOffset,
      fieldOfView: 22, opening: "Test", objective: "Test", lookAround: "Test", restartNote: "Test")
    let session = GameSession(level: level)
    session.setCombatStance(.attack)
    let fight = EncounterSimulation(level: level)
    let began = session.beginEncounter(encounter.beat)
    try #require(began)
    fight.begin(encounter)
    let ballistics = Ballistics(level: level)
    let miki = try #require(figures[.miki])
    let tom = try #require(figures[.tom])
    var warnings: [PartyMember] = []
    var hits: [DamageHit] = []
    var realClearShots = 0
    var retried = false
    for _ in 0..<120 * 12 where warnings.count < 2 {
      let robot = fight.hostiles["guard"]?.robot ?? RobotGuard(home: .zero)
      let eye = fight.weakpoints(for: "guard").first { $0.part == .eye }
      let target = eye?.ground ?? .zero
      let seesMiki = ballistics.isClear(
        from: ballistics.point(robot.position, above: 1.52), to: ballistics.point(miki))
      #expect(seesMiki == !hidden)
      #expect(
        ballistics.isClear(
          from: ballistics.point(robot.position, above: 1.52), to: ballistics.point(tom)))
      let health = fight.guardStrategies["guard"]?.health ?? GuardStrategy.maximumHealth
      let outcome = fight.step(
        dt: 1 / 120, leader: tom, facing: [0, -1], aiming: false, fireHeld: false,
        firePressed: false, figures: figures, session: session,
        companionIntents: [
          .miki: .init(
            lookAt: target, engaged: true, weapon: .longRifle, fire: eye != nil,
            activity: .attacking)
        ], facings: [.miki: simd_normalize(target - miki)])
      retried = retried || outcome.retry
      let events = fight.takeEvents()
      let stepHits = events.compactMap { event -> DamageHit? in
        if case .damaged(let hit) = event { return hit }
        return nil
      }
      #expect(
        health - (fight.guardStrategies["guard"]?.health ?? health)
          == stepHits.reduce(0) { $0 + $1.amount })
      hits += stepHits
      for shot in fight.shots where shot.actor == .miki {
        let trace = try #require(shot.trace)
        #expect(ballistics.isClear(from: trace.start, to: trace.end))
        #expect(shot.path.strike == .body("guard.eye"))
        #expect(stepHits.count == 1 && stepHits.first?.attacker == .miki)
        realClearShots += 1
      }
      for event in events {
        if case .guardTargeted(let member, _) = event { warnings.append(member) }
      }
    }
    #expect(realClearShots > 0 && !hits.isEmpty)
    #expect(fight.status(for: .miki).loaded < Weapon.longRifle.capacity)
    #expect(hits.allSatisfy { $0.attacker == .miki && $0.amount > 0 })
    #expect((fight.guardStrategies["guard"]?.health ?? .max) < GuardStrategy.maximumHealth)
    #expect(warnings == [.tom, hidden ? .tom : .miki])
    #expect(!retried && session.leader == .tom && session.combatStance == .attack)
  }
}
