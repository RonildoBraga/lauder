import Testing
import simd

@testable import Lauder

/// The pack's attacks give way to a companion's safety in the real world: its input rules,
/// plans and overrides, with no injected intents or timers (issues #201 and #208, and the
/// follow-up to the review of #203). Only a fixture's toughness differs, where a test needs an
/// attacker to survive long enough to aim at a companion.
@MainActor
struct PackAvoidanceTests {
  #if DEBUG
    @Test(arguments: [GameSession.CombatStance.defend, .attack])
    func aFreeCompanionIsNotRunIntoByARamAimedAtIt(stance: GameSession.CombatStance) throws {
      let trial = Trial(level: Self.level(crawlerToughness: Crawler.health * 40))
      try trial.choose(stance)
      var aimed = 0
      var rammed: [PartyMember] = []
      for _ in 0..<120 * 30 {
        let before = trial.world.playtestSnapshot
        let hits = Dictionary(
          uniqueKeysWithValues: PartyMember.allCases.map { ($0, trial.world.session.hits(of: $0)) })
        trial.frame(trial.evadeGuard())
        let after = trial.world.playtestSnapshot
        try #require(!trial.world.isRetrying, "The fight retried before the check finished")
        let crawler = try #require(after.crawlers.first)
        let previous = try #require(before.crawlers.first)
        if crawler.phase == .windingUp, previous.phase != .windingUp,
          let member = crawler.watching, trial.isFree(member)
        {
          aimed += 1
        }
        // A hit while the crawler rams and the guard fired nothing is the ram's.
        let ramming = crawler.phase == .ramming || previous.phase == .ramming
        if ramming, after.robotShots == before.robotShots {
          for member in trial.world.session.companions
          where trial.world.session.hits(of: member) > hits[member, default: 0]
            && trial.isFree(member)
          {
            rammed.append(member)
          }
        }
        if aimed >= 3, crawler.phase != .windingUp, crawler.phase != .ramming { break }
      }
      #expect(aimed >= 2, "Too few rams were aimed at a free companion to show anything")
      #expect(rammed.isEmpty, "Free companions were rammed: \(rammed)")
      #expect(trial.world.session.combatStance == stance)
    }

    @Test
    func aHeldCompanionKeepsItsPlaceUnderARamLine() throws {
      let trial = Trial(level: Self.level(crawlerToughness: Crawler.health * 40))
      try trial.choose(.defend)
      trial.frame(.init(keyboardHold: true))
      trial.frame()
      let anchors = trial.world.session.orders
      var covered = 0
      for _ in 0..<120 * 30 {
        trial.frame(trial.evadeGuard())
        try #require(!trial.world.isRetrying, "The fight retried before the check finished")
        let snapshot = trial.world.playtestSnapshot
        #expect(trial.world.session.orders == anchors)
        guard let crawler = snapshot.crawlers.first, crawler.phase == .windingUp,
          let start = crawler.ramStart, let end = crawler.ramEnd
        else { continue }
        for member in trial.world.session.companions {
          guard case .holding(let anchor?) = anchors[member],
            let at = snapshot.positions[member],
            Crawler.distance(from: at, toSegment: start, end) < Crawler.reach
          else { continue }
          covered += 1
          #expect(trial.world.companionTargets[member] == anchor)
          #expect(snapshot.companionActivities[member] != .avoiding)
        }
        if covered >= 30 { break }
      }
      #expect(covered > 0, "No ram line covered a held companion")
    }

    @Test
    func aCompanionInADivesWayAvoidsItBeforeShootingTheDrone() throws {
      let trial = Trial(level: Self.level(droneToughness: ScoutDrone.health * 20))
      try trial.choose(.attack)
      var inside = 0
      for _ in 0..<120 * 40 {
        trial.frame(trial.evadeGuard())
        try #require(!trial.world.isRetrying, "The fight retried before the check finished")
        let snapshot = trial.world.playtestSnapshot
        for drone in snapshot.drones where drone.phase == .diving {
          guard let member = drone.watching, trial.isFree(member),
            let point = drone.committedPoint, let at = snapshot.positions[member],
            simd_distance(at, point) < ScoutDrone.danger
          else { continue }
          // In the open nothing covers it, so its plan avoids, and the drone override leaves
          // an avoiding companion alone.
          inside += 1
          #expect(snapshot.companionActivities[member] == .avoiding)
        }
        if inside >= 30 { break }
      }
      #expect(inside > 0, "No dive committed to a free companion's place")
    }

    private static func level(crawlerToughness: Int? = nil, droneToughness: Int? = nil)
      -> Level
    {
      let guardian = Level.Hostile(
        id: "stranger", name: "Guard", hiddenAt: .zero, standAt: .zero, hits: 6,
        attack: .robot, strategicGuard: true)
      var hostiles = [guardian]
      if let droneToughness {
        hostiles.append(
          Level.Hostile(
            id: "drone.1", name: "Scout drone", hiddenAt: .zero, standAt: .zero,
            hits: droneToughness, attack: .drone(orbit: 0, slot: 0)))
      }
      if let crawlerToughness {
        // East of the party, nearer the companion on that side than the leader.
        hostiles.append(
          Level.Hostile(
            id: "crawler.1", name: "Crawler", hiddenAt: [7, 6], standAt: [7, 6],
            hits: crawlerToughness, attack: .crawler(slot: 0)))
      }
      let cues: [(at: Float, cue: Level.Cue)] = hostiles.flatMap {
        [(0, .reveal($0.id)), (0, .engage($0.id))]
      }
      let encounter = Level.Encounter(
        beat: .stranger, start: .area(.init(minimum: [-20, -20], maximum: [20, 20])),
        retryAt: [0, 18], hostiles: hostiles, cues: cues)
      return Level(
        id: "pack-avoidance-range",
        ground: .box("floor", at: [0, -0.15, 0], size: [60, 0.3, 60]), boxes: [],
        triggers: [], encounters: [encounter], party: [.laura, .miki, .tom],
        spawns: [.laura: [0, 9], .miki: [-2, 7.5], .tom: [2, 7.5]], heading: [0, -1],
        cameraOffset: BrooklynBridge.cameraOffset, fieldOfView: 22,
        opening: "Range", objective: "Test", lookAround: "Range", restartNote: "Restart")
    }

    @MainActor
    private final class Trial {
      let world: GameWorld
      private var lastDodge: Float = -10
      private var elapsed: Float = 0

      init(level: Level) {
        world = GameWorld(level: level)
      }

      @discardableResult
      func frame(_ raw: InputRules.Raw = .init()) -> [CombatEvent] {
        let mode = world.session.mode
        world.update(
          with: world.controls.resolve(raw, mode: mode), sampledIn: mode, deltaTime: 1 / 120)
        elapsed += 1 / 120
        return world.takeCombatEvents()
      }

      /// Attack with D-pad up, or keep the opening Defend; Laura leads throughout.
      func choose(_ stance: GameSession.CombatStance) throws {
        frame()
        if stance == .attack {
          frame(.init(dpadUp: true))
          frame()
        }
        try #require(world.session.combatStance == stance && world.session.leader == .laura)
      }

      func isFree(_ member: PartyMember) -> Bool {
        guard member != world.session.leader, case .following = world.session.order(of: member)
        else { return false }
        return true
      }

      /// Ordinary leader movement only: Laura rolls across the guard's committed line and
      /// never fires or swaps.
      func evadeGuard() -> InputRules.Raw {
        let snapshot = world.playtestSnapshot
        guard snapshot.robotPhase == .committed, elapsed - lastDodge > 1,
          let leader = snapshot.positions[.laura], let robot = snapshot.robotPosition,
          simd_distance(leader, robot) > 0.1
        else { return .init() }
        lastDodge = elapsed
        let radial = leader - robot
        return .init(
          stick: Movement.stick(
            towards: simd_normalize(SIMD2(-radial.y, radial.x)),
            cameraOffset: world.level.cameraOffset), controllerDodge: true)
      }
    }
  #endif
}
