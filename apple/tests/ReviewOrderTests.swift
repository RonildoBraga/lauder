import RealityKit
import Testing
import simd

@testable import Lauder

/// Resolved commands still use the world's real planner, movement, weapons and hull queries.
/// This open test fixture isolates orders from incoming injuries; it is not survival evidence.
@MainActor
struct ReviewOrderTests {
  #if DEBUG
    @Test(arguments: [GameSession.Command.hold, .leftGoes, .rightGoes, .bothGo])
    func aNewPositionOrderInterruptsRegroupWithoutSilencingAttack(command: GameSession.Command)
      throws
    {
      let world = fixture()
      try give(.attack, to: world)
      try #require(run(world, upTo: 4) { companionDamagedGuard(world) })
      try #require(
        world.session.companions.contains {
          simd_distance(position(world, $0), position(world, .miki)) > 2.6
        })
      var formation = InputRules.Input.neutral
      formation.formationPressed = true
      world.update(with: formation, sampledIn: .exploring, deltaTime: 0)
      let destination: SIMD2<Float>? =
        switch command {
        case .hold: nil
        case .leftGoes: [6, 4]
        case .rightGoes: [-6, 4]
        default: [-5, 11]
        }
      try give(command, to: world, touching: destination)
      try #require(world.session.combatStance == .attack && !world.session.orders.isEmpty)
      _ = world.takeCombatEvents()
      #expect(
        run(world, upTo: 6) { companionDamagedGuard(world) },
        "a new accepted position order must not leave the standing Attack stance suppressed")
      #expect(world.session.leader == .miki && !world.isRetrying)
    }

    @Test
    func aRefusedPositionOrderDoesNotCancelTheCurrentRegroup() throws {
      let world = fixture()
      try give(.attack, to: world)
      try #require(run(world, upTo: 4) { companionDamagedGuard(world) })
      var formation = InputRules.Input.neutral
      formation.formationPressed = true
      world.update(with: formation, sampledIn: .exploring, deltaTime: 0)
      let centre = try #require(world.playtestSnapshot.robotPosition)
      try give(.bothGo, to: world, touching: centre)
      try #require(world.refusedOrders == 1 && world.session.orders.isEmpty)
      _ = world.takeCombatEvents()
      let health = world.guardHealth
      #expect(!run(world, upTo: 0.5) { companionDamagedGuard(world) })
      #expect(world.guardHealth == health && world.session.combatStance == .attack)
    }

    @Test(arguments: [GameSession.Command.leftGoes, .rightGoes, .bothGo])
    func dpadOrdersStopAtTheLivingHullAndActuallyArrive(command: GameSession.Command) throws {
      let world = fixture()
      let centre = try #require(world.playtestSnapshot.robotPosition)
      // The old six-metre mark falls inside the machine while the leader faces it.
      try #require(
        simd_distance(position(world, .miki) + [0, -GameWorld.orderReach], centre) < 0.1)
      try give(command, to: world)
      let ordered = world.session.companions.filter { world.session.order(of: $0) != .following }
      try #require(!ordered.isEmpty && world.refusedOrders == 0)
      for member in ordered {
        guard case .going(let point) = world.session.order(of: member) else {
          Issue.record("the accepted order did not supply a Go point")
          continue
        }
        #expect(simd_distance(point, centre) >= hullClearance)
      }
      #expect(
        run(world, upTo: 6) {
          ordered.allSatisfy {
            if case .holding = world.session.order(of: $0) { true } else { false }
          }
        }, "the companions must settle instead of circling an impossible destination")
      #expect(world.diagnostic == nil)
    }

    @Test(arguments: [GameSession.Command.leftGoes, .rightGoes, .bothGo])
    func aTouchPointDeepInsideTheLivingHullIsRefused(command: GameSession.Command) throws {
      let world = fixture()
      let centre = try #require(world.playtestSnapshot.robotPosition)
      try give(command, to: world, touching: centre)
      #expect(world.session.orders.isEmpty && world.refusedOrders == 1)
      let cross = try #require(world.root.findEntity(named: "order.refused"))
      #expect(cross.isEnabled)
    }

    @Test(arguments: [GameSession.Command.leftGoes, .rightGoes, .bothGo])
    func aTouchPointNearTheHullCanSnapToLegalNearbyGround(command: GameSession.Command) throws {
      let world = fixture()
      let centre = try #require(world.playtestSnapshot.robotPosition)
      let marked = centre + SIMD2<Float>(1.2, 0)
      try give(command, to: world, touching: marked)
      try #require(!world.session.orders.isEmpty && world.refusedOrders == 0)
      for member in world.session.companions {
        if case .going(let point) = world.session.order(of: member) {
          #expect(simd_distance(point, centre) >= hullClearance)
          #expect(simd_distance(point, marked) <= GameWorld.orderSnap + GameWorld.spotSpacing)
        }
      }
    }

    private var hullClearance: Float {
      RobotModelGeometry.bodyRadius + PartyBody.radius + PartyMotion.skin
    }

    private func fixture() -> GameWorld {
      let guardSpec = Level.Hostile(
        id: "stranger", name: "Guard", hiddenAt: .zero, standAt: .zero, hits: 6,
        attack: .robot, strategicGuard: true, range: 12)
      let encounter = Level.Encounter(
        beat: .stranger, start: .area(.init(minimum: [-15, -15], maximum: [15, 15])),
        retryAt: nil, hostiles: [guardSpec],
        cues: [(0, .reveal("stranger")), (0, .engage("stranger"))])
      let level = Level(
        id: "review-order-fixture",
        ground: .box("floor", at: [0, -0.15, 0], size: [40, 0.3, 40]), boxes: [], triggers: [],
        encounters: [encounter], party: [.miki, .tom, .laura],
        spawns: [.miki: [0, 6], .tom: [-4, 8], .laura: [4, 8]], heading: [0, -1],
        cameraOffset: TestYard.cameraOffset, fieldOfView: 42,
        opening: "Range", objective: "Test", lookAround: "Range", restartNote: "Restart")
      let world = GameWorld(level: level)
      for _ in 0..<3 { world.advanceParty(movement: .zero, deltaTime: 1 / 60) }
      return world
    }

    private func give(
      _ command: GameSession.Command, to world: GameWorld, touching point: SIMD2<Float>? = nil
    ) throws {
      var input = InputRules.Input.neutral
      input.command = command
      if let point {
        let screen = try #require(world.projection(aspect: 2.16).screen(ofGround: point))
        input.commandPoint = InputRules.ScreenPoint(x: screen.x, y: screen.y, aspect: 2.16)
      }
      world.update(with: input, sampledIn: .exploring, deltaTime: 0)
    }

    private func companionDamagedGuard(_ world: GameWorld) -> Bool {
      world.takeCombatEvents().contains {
        if case .damaged(let hit) = $0 { hit.attacker != .miki } else { false }
      }
    }
  #endif
}
