import RealityKit
import Testing
import simd

@testable import Lauder

/// The shipped fight retries through its native injuries, fade and input gate, with its
/// guard, drones and crawlers present. No fixture damage, immunity or body placement is used.
@MainActor
struct ShippedBridgeRetryTests {
  #if DEBUG
    @Test
    func aLivePackFightRetriesAndAcceptsFreshPlayFromItsCheckpoint() throws {
      let trial = Trial()
      let world = trial.world
      let party = world.session.party
      let enemyIDs = Set(BrooklynBridge.strangerEncounter.hostiles.map(\.id))
      try #require(party == [.miki, .tom, .laura] && enemyIDs.count == 6)
      try #require(BrooklynBridge.drones.count == 2 && BrooklynBridge.crawlers.count == 3)
      try trial.frame()
      try trial.frame()
      try trial.walk(to: [6.5, 19])
      try #require(!world.session.inEncounter && world.session.beat == .crossing)
      let triggers = world.session.firedTriggers
      try #require(!triggers.isEmpty)

      try trial.walk(to: [6.5, 10])
      for _ in 0..<60 * 8 where !Self.packIsActive(world.playtestSnapshot) {
        try trial.frame()
      }
      try #require(Self.packIsActive(world.playtestSnapshot))
      try #require(world.session.inEncounter && !world.isRetrying)
      // Stand ahead of the two approach blocks so native incoming shots and rams can reach
      // Miki. Keep the companions on Defend until the last injury is due, rather than letting
      // them win the fight before Retry can be exercised.
      try trial.walk(to: [6.5, 8])
      try #require(world.session.combatStance == .defend)
      try trial.frame(.init(controllerSwap: true))
      try trial.frame()
      let target = world.playtestSnapshot
      let guardPoint = try #require(target.robotPosition)
      let screen = try #require(
        target.camera.screen(ofWorld: [guardPoint.x, 0.9, guardPoint.y]))
      try trial.frame(
        .init(
          touchTarget: .tap(
            .init(
              point: .init(x: screen.x, y: screen.y, aspect: target.camera.aspect),
              viewHeight: 428))))
      try trial.frame()
      try #require(world.lockedHostile == BrooklynBridge.stranger.id)

      // A real leader hit on the guard makes its restored health nonvacuous; damage to a
      // crawler or drone alone cannot satisfy this precondition.
      var leaderDamagedGuard = false
      for _ in 0..<60 * 6 where !leaderDamagedGuard {
        let events = try trial.frame(.init(controllerFire: true))
        leaderDamagedGuard = events.contains {
          if case .damaged(let hit) = $0 {
            hit.attacker == .miki && hit.amount > 0 && hit.target == BrooklynBridge.stranger.id
          } else {
            false
          }
        }
        try #require(!world.isRetrying, "Retry began before the native shot was observed")
      }
      try #require(leaderDamagedGuard)
      let hitGuard = try #require(world.playtestSnapshot.guardStrategy)
      try #require(hitGuard.health < GuardStrategy.maximumHealth)
      for _ in 0..<60 * 45
      where !world.isRetrying
        && !party.contains(where: { world.session.hits(of: $0) >= GameSession.hitsAllowed - 1 })
      {
        try trial.frame()
      }
      try #require(
        !world.isRetrying
          && party.contains { world.session.hits(of: $0) == GameSession.hitsAllowed - 1 },
        "No two-injury native warning window: \(trial.diagnostics)")
      try trial.frame(.init(arrowUp: true))
      try #require(world.session.combatStance == .attack)
      for _ in 0..<60 * 60 where !world.isRetrying { try trial.frame() }
      try #require(
        world.isRetrying && trial.sawNativeInjury && trial.sawActivePack,
        "Native Retry was not reached: \(trial.diagnostics)")
      try #require(party.contains { world.session.hits(of: $0) >= GameSession.hitsAllowed })
      try #require(world.session.combatStance == .attack)
      let damagedGuard = try #require(world.playtestSnapshot.guardStrategy)
      try #require(damagedGuard.health > 0 && damagedGuard.health < GuardStrategy.maximumHealth)
      let recordedDamageHits = world.playtestSnapshot.damage.hits

      // Keep controls held across the actual fade. They must not move or draw/fire the
      // restored leader until they are released; no synthetic Input is supplied to the world.
      let held = InputRules.Raw(stick: stick(world, towards: [1, 0]), controllerFire: true)
      for _ in 0..<60 * 2 where world.isRetrying { try trial.frame(held) }
      try #require(!world.isRetrying && world.controls.needsNeutralInput)
      let restored = world.playtestSnapshot
      let checkpoint = try #require(BrooklynBridge.strangerEncounter.retryAt)
      #expect(simd_distance(position(world, .miki), checkpoint) < 0.01)
      #expect(restored.mode == .exploring && restored.beat == .crossing)
      #expect(restored.party == party && restored.leader == .miki)
      #expect(!world.session.inEncounter && world.session.defeated.isEmpty)
      #expect(world.session.firedTriggers == triggers)
      #expect(restored.partyHits.values.allSatisfy { $0 == 0 })
      #expect(restored.combatStance == .defend)
      #expect(restored.robotPhase == .hidden && restored.robotShots == 0)
      #expect(restored.guardTarget == nil && restored.robotCommittedPoint == nil)
      #expect(restored.guardStrategy?.health == GuardStrategy.maximumHealth)
      #expect(restored.guardStrategy?.detachedLegs.isEmpty == true)
      #expect(restored.guardStrategy?.swordHits.isEmpty == true)
      #expect(restored.drones.count == 2 && restored.crawlers.count == 3)
      #expect(restored.dronesDown == 0 && restored.crawlersDown == 0)
      #expect(restored.drones.allSatisfy { $0.phase == .hidden && $0.watching == nil })
      #expect(
        restored.crawlers.allSatisfy {
          $0.phase == .hidden && $0.watching == nil && $0.ramStart == nil && $0.ramEnd == nil
        })
      #expect(restored.damage.hits == recordedDamageHits && restored.damageLabelCount == 0)
      #expect(restored.grenadeCooldown == 0 && !restored.grenadeInFlight)
      #expect(!restored.locked && world.threat == nil && world.guardTarget == nil)
      for id in enemyIDs {
        #expect(world.root.findEntity(named: "hostile.\(id)")?.isEnabled == false)
      }
      for member in party {
        let weapon = try #require(restored.partyWeapons[member])
        let initial = Weapon.pair(for: member)[0]
        #expect(weapon.kind == initial.kind && weapon.loaded == initial.capacity)
        #expect(!weapon.isDrawn && weapon.reloadRemaining == 0)
        #expect(world.root.findEntity(named: "party.\(member.rawValue)")?.isEnabled == true)
      }
      for _ in 0..<30 {
        let events = try trial.frame(held)
        #expect(world.controls.needsNeutralInput)
        #expect(simd_distance(position(world, .miki), checkpoint) < 0.01)
        #expect(!world.playtestSnapshot.weapon.isDrawn && !world.session.inEncounter)
        #expect(!events.contains { if case .fired(_, _, true) = $0 { true } else { false } })
      }
      try trial.frame()
      try trial.frame()
      #expect(!world.controls.needsNeutralInput && !world.playtestSnapshot.weapon.isDrawn)

      // Retry returns the stance to Defend; it does not invent a different Go/Hold policy.
      // Fresh native commands still have authority, including a new Hold and its recall.
      try trial.frame(.init(keyboardHold: true))
      try trial.frame()
      try #require(world.session.orders.count == 2)
      for member in world.session.companions {
        guard case .holding(let anchor?) = world.session.order(of: member) else {
          Issue.record("The fresh Hold did not pin a companion after Retry")
          continue
        }
        #expect(anchor.x.isFinite && anchor.y.isFinite)
      }
      try trial.frame(.init(arrowDown: true))
      try trial.frame()
      #expect(world.session.orders.isEmpty && world.session.combatStance == .defend)
      for _ in 0..<12 { try trial.frame(.init(stick: stick(world, towards: [1, 0]))) }
      #expect(simd_distance(position(world, .miki), checkpoint) > 0.1)

      try trial.walk(to: [6.5, 10])
      for _ in 0..<60 * 12 where !Self.packIsActive(world.playtestSnapshot) {
        try trial.frame()
      }
      try #require(Self.packIsActive(world.playtestSnapshot) && world.session.inEncounter)
      try #require(world.session.leader == .miki && !world.isRetrying)
      #expect(world.session.combatStance == .defend)
      try trial.frame(.init(arrowUp: true))
      #expect(world.session.combatStance == .attack)
    }

    private static func packIsActive(_ snapshot: PlaytestRunner.Snapshot) -> Bool {
      guard let phase = snapshot.robotPhase, ![.hidden, .down, .cleared].contains(phase) else {
        return false
      }
      return snapshot.drones.count == 2 && snapshot.crawlers.count == 3
        && snapshot.drones.allSatisfy { ![.hidden, .down, .cleared].contains($0.phase) }
        && snapshot.crawlers.allSatisfy {
          [Crawler.Phase.approaching, .windingUp, .ramming, .recovering].contains($0.phase)
        }
    }

    @MainActor
    private final class Trial {
      let world = GameWorld(level: BrooklynBridge.level)
      private(set) var sawActivePack = false
      private(set) var sawNativeInjury = false

      var diagnostics: String {
        let snapshot = world.playtestSnapshot
        return
          "encounter=\(world.session.inEncounter), phase=\(String(describing: snapshot.robotPhase)), "
          + "guardHealth=\(snapshot.guardStrategy?.health ?? -1), hits=\(snapshot.partyHits), "
          + "defeated=\(world.session.defeated), miki=\(position(world, .miki))"
      }

      @discardableResult
      func frame(_ raw: InputRules.Raw = .init()) throws -> [CombatEvent] {
        let before = world.playtestSnapshot
        sawActivePack = sawActivePack || ShippedBridgeRetryTests.packIsActive(before)
        let mode = world.session.mode
        world.update(
          with: world.controls.resolve(raw, mode: mode), sampledIn: mode, deltaTime: 1 / 60)
        for member in world.session.party
        where world.session.hits(of: member) > before.partyHits[member, default: 0] {
          try #require(sawActivePack, "A native injury arrived before the whole pack was awake")
          sawNativeInjury = true
        }
        return world.takeCombatEvents()
      }

      func walk(to point: SIMD2<Float>) throws {
        for _ in 0..<60 * 70 {
          let offset = point - position(world, world.session.leader)
          try #require(offset.x.isFinite && offset.y.isFinite)
          if simd_length(offset) < 0.15 { return }
          let strength = min(1, max(0.35, simd_length(offset)))
          try frame(.init(stick: stick(world, towards: offset) * strength))
          try #require(!world.isRetrying && world.diagnostic == nil)
        }
        Issue.record("The native leader did not reach \(point)")
        try #require(simd_distance(position(world, world.session.leader), point) < 0.15)
      }
    }
  #endif
}
