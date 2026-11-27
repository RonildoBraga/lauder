import Testing
import simd

@testable import Lauder

/// Native squad decisions and flight share the real world. No immunity, injected firing
/// intentions, altered health or artificial attack timers supply these contributions.
@MainActor
struct CompanionDroneTests {
  #if DEBUG
    @Test
    func attackPermitsRealCompanionDroneHitsAndDefendStopsThemWithoutTakingTheLeader() throws {
      let trial = WorldTrial()
      trial.frame()
      trial.frame(.init(dpadUp: true))
      trial.frame()
      try #require(trial.world.session.combatStance == .attack)
      var contributions: [PartyMember: Int] = [:]
      var firedAt: [Weapon.Kind: [Float]] = [:]
      for frame in 0..<120 * 25 {
        let before = trial.world.playtestSnapshot
        let health = trial.droneHealth
        let events = trial.frame(trial.evadeGuard())
        let after = trial.world.playtestSnapshot
        try #require(
          !trial.world.isRetrying, "The ordinary squad fight retried before contributing")
        #expect(after.leader == .laura)
        #expect(!events.contains { if case .fired(_, _, true) = $0 { true } else { false } })
        let hits = events.compactMap { event -> DamageHit? in
          if case .damaged(let hit) = event, Self.droneIDs.contains(hit.target) { hit } else { nil }
        }
        #expect(health - trial.droneHealth == hits.reduce(0) { $0 + $1.amount })
        for hit in hits {
          #expect(before.guardStrategy?.health ?? 0 > 0)
          #expect(before.defeated == 0)
          #expect(hit.attacker != .laura && hit.amount > 0 && hit.effectiveness == .normal)
          contributions[hit.attacker, default: 0] += hit.amount
        }
        for weapon in [Weapon.longRifle, .minigun] {
          let fired = events.filter {
            if case .fired(let kind, _, false) = $0 { kind == weapon.kind } else { false }
          }.count
          if fired > 0 {
            firedAt[weapon.kind, default: []] += Array(
              repeating: Float(frame + 1) / 120, count: fired)
          }
          let old = try #require(before.partyWeapons[weapon.kind == .longRifle ? .miki : .tom])
          let new = try #require(after.partyWeapons[weapon.kind == .longRifle ? .miki : .tom])
          let reloaded = new.loaded > old.loaded ? weapon.capacity : 0
          #expect(old.loaded + reloaded - new.loaded == fired)
        }
        if contributions[.miki, default: 0] > 0, contributions[.tom, default: 0] > 0,
          firedAt.values.allSatisfy({ $0.count >= 2 })
        {
          break
        }
      }
      #expect(contributions[.miki, default: 0] > 0 && contributions[.tom, default: 0] > 0)
      for weapon in [Weapon.longRifle, .minigun] {
        let times = try #require(firedAt[weapon.kind])
        try #require(times.count >= 2)
        #expect(times[0] >= max(weapon.drawTime, weapon.spinUp) - 1 / 120)
        for (first, second) in zip(times, times.dropFirst()) {
          #expect(second - first >= weapon.interval - 0.0001)
        }
      }
      try #require(trial.world.playtestSnapshot.guardStrategy?.health ?? 0 > 0)
      try #require(trial.world.playtestSnapshot.drones.contains { $0.phase != .down })
      trial.frame(.init(dpadDown: true))
      trial.frame()
      let stopped = trial.droneHealth
      for _ in 0..<120 {
        let events = trial.frame(trial.evadeGuard())
        #expect(
          !events.contains {
            if case .fired(let kind, _, false) = $0 { kind != .rifle } else { false }
          })
        #expect(!events.contains { if case .damaged = $0 { true } else { false } })
      }
      #expect(trial.droneHealth == stopped)
      #expect(trial.world.session.combatStance == .defend && trial.world.session.leader == .laura)
    }

    @Test
    func liveDronesRespectHoldGoAndPauseAndRestartRestoresTheirFight() throws {
      let trial = WorldTrial()
      trial.frame()
      trial.frame(.init(dpadUp: true))
      trial.frame()
      trial.frame(.init(keyboardHold: true))
      trial.frame()
      let anchors = trial.world.session.orders
      var diving = false
      for _ in 0..<120 * 15 {
        trial.frame(trial.evadeGuard())
        try #require(!trial.world.isRetrying)
        #expect(trial.world.session.orders == anchors)
        if trial.world.playtestSnapshot.drones.contains(where: { $0.phase == .diving }) {
          diving = true
          break
        }
      }
      try #require(diving, "The authority check must run during a native drone dive")
      for member in trial.world.session.companions {
        if case .holding(let anchor?) = anchors[member] {
          #expect(trial.world.companionTargets[member] == anchor)
          #expect(
            simd_distance(trial.world.playtestSnapshot.positions[member] ?? .zero, anchor)
              <= CompanionMotor.settleDistance)
        } else {
          Issue.record("The Hold command did not retain a real anchor")
        }
      }
      trial.frame(.init(keyboardPause: true))
      try #require(trial.world.session.mode == .paused)
      let paused = trial.world.playtestSnapshot
      for _ in 0..<120 {
        trial.frame(.init(controllerSwitch: true, controllerFire: true, dpadUp: true))
      }
      let frozen = trial.world.playtestSnapshot
      #expect(frozen.positions == paused.positions && frozen.robotShots == paused.robotShots)
      #expect(frozen.guardStrategy == paused.guardStrategy && trial.droneHealth > 0)
      for (first, second) in zip(paused.drones, frozen.drones) {
        #expect(
          first.id == second.id && first.phase == second.phase && first.position == second.position)
      }
      for member in trial.world.session.party {
        #expect(frozen.partyWeapons[member]?.loaded == paused.partyWeapons[member]?.loaded)
      }
      trial.frame()
      trial.frame(.init(keyboardPause: true))
      trial.frame()
      try #require(trial.world.session.mode == .exploring)
      let current = try #require(trial.world.playtestSnapshot.positions[.tom])
      let destination = current + [0, 2]
      try #require(trial.world.session.send(.tom, to: destination))
      var observedGoing = false
      for _ in 0..<120 {
        let order = trial.world.session.order(of: .tom)
        let events = trial.frame(trial.evadeGuard())
        if case .going = order {
          observedGoing = true
          #expect(trial.world.playtestSnapshot.companionActivities[.tom] == .ordered)
          #expect(
            !events.contains { if case .fired(.minigun, _, false) = $0 { true } else { false } })
        }
        if case .holding = trial.world.session.order(of: .tom) { break }
      }
      #expect(observedGoing && trial.world.session.leader == .laura)
      trial.world.restart()
      #expect(trial.world.session.defeated.isEmpty && trial.world.session.combatStance == .defend)
      #expect(trial.droneHealth == ScoutDrone.health * Self.droneIDs.count)
      #expect(trial.world.playtestSnapshot.drones.allSatisfy { $0.phase == .hidden })
    }

    @MainActor
    private final class WorldTrial {
      let world = GameWorld(level: CompanionDroneTests.level())
      private var lastDodge: Float = -10
      private var elapsed: Float = 0

      var droneHealth: Int {
        CompanionDroneTests.droneIDs.reduce(0) {
          $0 + world.session.remainingHealth(of: $1, toughness: ScoutDrone.health)
        }
      }

      @discardableResult
      func frame(_ raw: InputRules.Raw = .init()) -> [CombatEvent] {
        let mode = world.session.mode
        world.update(
          with: world.controls.resolve(raw, mode: mode), sampledIn: mode, deltaTime: 1 / 120)
        elapsed += 1 / 120
        return world.takeCombatEvents()
      }

      /// Ordinary player movement/roll only; the controlled Laura never fires or swaps.
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

  @Test
  func aRealAllyOrWallBlocksTheNativeDroneQuery() throws {
    let clear = try FlightTrial()
    try clear.waitForDive()
    let drone = try #require(clear.fight.hostiles[Self.droneIDs[0]]?.drone)
    let origin = try #require(clear.figures[.tom])
    let chosen = try #require(
      clear.fight.companionDrone(for: .tom, from: origin, figures: clear.figures))
    #expect(chosen.id == Self.droneIDs[0] && chosen.weapon == .minigun)
    var blocked = clear.figures
    blocked[.laura] = origin + (drone.position - origin) * 0.2
    #expect(clear.fight.companionDrone(for: .tom, from: origin, figures: blocked) == nil)

    let wall = try FlightTrial(wall: true)
    try wall.waitForDive()
    #expect(
      wall.fight.companionDrone(for: .tom, from: wall.figures[.tom] ?? .zero, figures: wall.figures)
        == nil)
  }

  @Test
  func nativeDroneBurstsHurtTheVulnerablePartyAndEventuallyRequestRetry() throws {
    let trial = try FlightTrial(guardPresent: false, droneOrbit: 0)
    var burstHits = 0
    var previous = ScoutDrone.Phase.hidden
    var rounds = 0
    var retried = false
    for _ in 0..<120 * 100 {
      let before = PartyMember.allCases.reduce(0) { $0 + trial.session.hits(of: $1) }
      let outcome = trial.step()
      let drone = try #require(trial.fight.hostiles[Self.droneIDs[0]]?.drone)
      if drone.phase == .diving, previous == .warning { burstHits = 0 }
      burstHits += PartyMember.allCases.reduce(0) { $0 + trial.session.hits(of: $1) } - before
      #expect(burstHits <= 1)
      rounds += trial.fight.shots.filter { $0.side == .hostile }.count
      if outcome.retry {
        retried = true
        break
      }
      previous = drone.phase
    }
    #expect(rounds >= ScoutDrone.burstRounds)
    #expect(PartyMember.allCases.contains { trial.session.hits(of: $0) == GameSession.hitsAllowed })
    #expect(retried && trial.session.defeated.isEmpty)
  }

  private static let droneIDs = ["drone.1", "drone.2"]

  private static func level(
    droneCount: Int = 2, guardPresent: Bool = true, wall: Bool = false, droneOrbit: Float = 0
  )
    -> Level
  {
    let guardian = Level.Hostile(
      id: "stranger", name: "Guard", hiddenAt: .zero, standAt: .zero, hits: 6,
      attack: .robot, strategicGuard: true, range: 12)
    let drones = (0..<droneCount).map { index in
      Level.Hostile(
        id: droneIDs[index], name: "Scout drone", hiddenAt: .zero, standAt: .zero,
        hits: ScoutDrone.health,
        attack: .drone(orbit: droneOrbit + Float(index) * .pi, slot: index))
    }
    let hostiles = (guardPresent ? [guardian] : []) + drones
    let cues: [(at: Float, cue: Level.Cue)] = hostiles.flatMap {
      [(0, .reveal($0.id)), (0, .engage($0.id))]
    }
    let encounter = Level.Encounter(
      beat: .stranger, start: .area(.init(minimum: [-20, -20], maximum: [20, 20])),
      retryAt: [0, 18], hostiles: hostiles,
      cues: cues)
    return Level(
      id: "companion-drone-range",
      ground: .box("floor", at: [0, -0.15, 0], size: [60, 0.3, 60]),
      boxes: wall ? [.box("wall", at: [3, 2.5, 0], size: [0.2, 5, 25])] : [],
      triggers: [], encounters: [encounter], party: [.laura, .miki, .tom],
      spawns: [.laura: [0, 8], .miki: [-2, 6], .tom: [2, 6]], heading: [0, -1],
      cameraOffset: BrooklynBridge.cameraOffset, fieldOfView: 22,
      opening: "Range", objective: "Test", lookAround: "Range", restartNote: "Restart")
  }

  /// Fixed positions isolate native flight, hurt and clear firing-lane queries. Motor and
  /// order behaviour is covered by WorldTrial; this fixture never supplies companion intents.
  @MainActor
  private final class FlightTrial {
    let fight: EncounterSimulation
    let session: GameSession
    let figures: [PartyMember: SIMD2<Float>] = [.miki: [0, 6], .laura: [-2, 8], .tom: [4.5, 1]]

    init(guardPresent: Bool = true, wall: Bool = false, droneOrbit: Float = .pi) throws {
      // Begin left of the wall, with the shooter to its right. Both variants can make a real
      // dive on the open left side; only the wall variant blocks the shooter's cross-wall ray.
      let level = CompanionDroneTests.level(
        droneCount: 1, guardPresent: guardPresent, wall: wall, droneOrbit: droneOrbit)
      session = GameSession(level: level)
      let encounter = try #require(level.encounters.first)
      let began = session.beginEncounter(encounter.beat)
      try #require(began)
      fight = EncounterSimulation(level: level)
      fight.begin(encounter)
    }

    @discardableResult
    func step() -> EncounterSimulation.Outcome {
      fight.step(
        dt: 1 / 120, leader: figures[.laura] ?? .zero, facing: [0, -1], aiming: false,
        fireHeld: false, firePressed: false, figures: figures, session: session)
    }

    func waitForDive() throws {
      for _ in 0..<120 * 20 {
        _ = step()
        _ = fight.takeEvents()
        if fight.hostiles[CompanionDroneTests.droneIDs[0]]?.drone?.phase == .diving { return }
      }
      Issue.record("A native drone never reached its dive")
      try #require(fight.hostiles[CompanionDroneTests.droneIDs[0]]?.drone?.phase == .diving)
    }
  }
}
