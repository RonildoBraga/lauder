import Testing
import simd

@testable import Lauder

/// The rest of ADR 0003's combat positioning, phase S4, tried in the combat yard: each member's
/// own preference in cover, routes that keep off the ground the shooters see, and the formation
/// button regrouping the companions in a fight. Cover near the slot has `CoverTests`.
@MainActor
struct CombatPositioningTests {
  // MARK: - Each member's preference

  @Test
  func eachMembersPreferenceWeighsTheirChoice() {
    // A threat at the origin, facing along +z.
    let threat = CoverPlanner.Threat(position: [0, 0], range: 14, facing: [0, 1])
    func cost(
      _ member: PartyMember, at spot: SIMD2<Float>, firing: SIMD2<Float>? = nil,
      target: SIMD2<Float>? = nil, teammates: [SIMD2<Float>] = []
    ) -> Float {
      CoverPlanner.personality(
        of: member, at: spot, firing: firing, target: target, threats: [threat], danger: 0,
        teammates: teammates)
    }
    // Miki: 6–10 m from her target is free; each metre nearer or further costs 0.5.
    #expect(cost(.miki, at: [0, 8], firing: [0, 8], target: [0, 0]) == 0)
    #expect(abs(cost(.miki, at: [0, 3], firing: [0, 3], target: [0, 0]) - 1.5) < 0.001)
    #expect(abs(cost(.miki, at: [0, 12], firing: [0, 12], target: [0, 0]) - 1) < 0.001)
    // With nobody she could fire at, she has no preference.
    #expect(cost(.miki, at: [0, 3], firing: [0, 3]) == 0)
    // Laura: straight in front of the threat's facing costs 2, at its side or behind nothing.
    #expect(abs(cost(.laura, at: [0, 5]) - 2) < 0.001)
    #expect(abs(cost(.laura, at: [5, 5]) - 2 * Float(0.5).squareRoot()) < 0.001)
    #expect(abs(cost(.laura, at: [5, 0])) < 0.001)
    #expect(cost(.laura, at: [0, -5]) == 0)
    // Where she steps out to fire counts, not where she hides.
    #expect(cost(.laura, at: [0, 5], firing: [5, 0]) < 0.001)
    // Tom: on the line between a close threat and the teammate nearest it is free; each metre
    // off it costs 0.5, up to three metres.
    let teammates: [SIMD2<Float>] = [[0, 6], [9, 9]]
    #expect(cost(.tom, at: [0, 3], teammates: teammates) == 0)
    #expect(abs(cost(.tom, at: [2, 3], teammates: teammates) - 1) < 0.001)
    #expect(abs(cost(.tom, at: [6, 3], teammates: teammates) - 1.5) < 0.001)
    // A threat more than 10 m away is not close.
    #expect(cost(.tom, at: [0, 30], teammates: teammates) == 0)
  }

  @Test
  func aCompanionsTargetIsTheNearestTheyCanShoot() {
    // The nearer shooter stands behind a wall, so a companion at the origin would fire at the
    // other one, and Miki's preferred range is measured to that one.
    let wall = [PartyMotion.Box(minimum: [-1, 2], maximum: [1, 2.5])]
    let threats = [
      CoverPlanner.Threat(position: [0, 5], range: 14),
      CoverPlanner.Threat(position: [6, 6], range: 14),
    ]
    func target(
      range: Float = 14, among threats: [CoverPlanner.Threat], blockers: [PartyMotion.Box] = wall
    )
      -> SIMD2<Float>?
    {
      CoverPlanner.target(from: [0, 0], threats: threats, weaponRange: range, obstacles: blockers)
    }
    #expect(target(among: threats) == [6, 6])
    // Out of the weapon's reach, or not yet a target, a shooter is not chosen.
    #expect(target(range: 7, among: threats) == nil)
    var notYet = threats
    notYet[1].isTarget = false
    #expect(target(among: notYet) == nil)
    // With nothing in the way, the nearest.
    #expect(target(among: threats, blockers: []) == [0, 5])
  }

  // MARK: - Open ground

  @Test
  func onlyALongWayAcrossSeenGroundCrossesOpenGround() {
    let level = Self.gap(positioning: true)
    let ground = OpenGround(
      threats: [CoverPlanner.Threat(position: Self.shooter, range: 20)], obstacles: level.obstacles)
    // The shooter sees through the gap, and not behind the walls or the screen.
    #expect(ground.isSeen([0, 0.5]) && ground.extraCost(at: [0, 0.5]) == OpenGround.extraCost)
    #expect(!ground.isSeen([-4, 0.5]) && ground.extraCost(at: [-4, 0.5]) == 0)
    #expect(!ground.isSeen([0, 3]))
    // The straight way between the walls crosses the gap's view; a way behind the screen does
    // not, and nor does a short step, wherever it is.
    #expect(ground.crosses(from: [-4, 0.5], to: [4, 0.5]))
    #expect(!ground.crosses(from: [-3, 3], to: [3, 3]))
    #expect(!ground.crosses(from: [-0.6, 0.5], to: [0.6, 0.5]))
  }

  @Test
  func whatTheShootersSeeIsRememberedUntilTheyChange() {
    let memo = SightMemo()
    let shooters = [CoverPlanner.Threat(position: [0, 0], range: 10)]
    var looks = 0
    func ask() -> Bool {
      memo.isSeen([1, 1]) {
        looks += 1
        return true
      }
    }
    memo.prepare(for: shooters)
    #expect(ask() && ask() && looks == 1)
    // The same shooters where they were: still remembered.
    memo.prepare(for: shooters)
    #expect(ask() && looks == 1)
    // One falls: forgotten, and worked out again.
    memo.prepare(for: [])
    #expect(ask() && looks == 2)
  }

  @Test
  func routesPayMoreForCostlyCells() throws {
    let level = Level(
      id: "open-snow", ground: .box("ground", at: [0, -0.15, 0], size: [20, 0.3, 20]), boxes: [],
      interactions: [], triggers: [], party: [.miki], spawns: [.miki: [0, 0]], heading: [0, -1],
      cameraOffset: CombatYard.level.cameraOffset, fieldOfView: CombatYard.level.fieldOfView,
      opening: "Snow.", objective: "Test.", lookAround: "Snow.", restartNote: "Restart.")
    let grid = NavigationGrid(level: level)
    // Straight across open snow, unless a strip along the straight way costs four times as much.
    let straight = try #require(grid.route(from: [-3, 0], to: [3, 0]))
    #expect(straight.allSatisfy { abs($0.y) < 0.5 })
    let around = try #require(
      grid.route(from: [-3, 0], to: [3, 0], extraCost: { abs($0.y) < 0.5 ? 3 : 0 }))
    #expect(around.contains { abs($0.y) >= 0.5 })
  }

  @Test
  func inAFightACompanionGoesRoundTheGroundTheShooterSees() {
    // Laura goes from behind one wall to behind the other. The straight way crosses what the
    // shooter sees through the gap between them; behind the screen beyond the gap, it sees
    // nothing.
    func trip(positioning: Bool) -> (end: SIMD2<Float>, highest: Float, seen: Int) {
      let world = GameWorld(level: Self.gap(positioning: positioning))
      #expect(world.session.holdAll())
      // The fight is under way once the shooter aims.
      #expect(run(world, upTo: 1) { world.threat != nil })
      #expect(world.session.send(.laura, to: Self.goal))
      var highest = -Float.infinity
      var seen = 0
      for _ in 0..<(12 * 60) {
        world.advanceParty(movement: .zero, deltaTime: 1 / 60)
        let here = position(world, .laura)
        highest = max(highest, here.y)
        if LineOfSight.isClear(from: Self.shooter, to: here, obstacles: world.level.obstacles) {
          seen += 1
        }
        if simd_distance(here, Self.goal) < 0.4 { break }
      }
      return (position(world, .laura), highest, seen)
    }
    // With combat positioning she goes round behind the screen, unseen.
    let aware = trip(positioning: true)
    #expect(simd_distance(aware.end, Self.goal) < 0.6)
    #expect(aware.highest > 2.4)
    #expect(aware.seen == 0)
    // Without it she walks straight across, in the shooter's sight.
    let straight = trip(positioning: false)
    #expect(simd_distance(straight.end, Self.goal) < 0.6)
    #expect(straight.highest < 1.5)
    #expect(straight.seen > 0)
  }

  // MARK: - Regroup

  @Test
  func theFormationButtonRegroupsOnlyInAFightWithCombatPositioning() {
    let session = GameSession(level: CombatYard.level)
    // Outside a fight it changes the formation, as everywhere.
    #expect(!session.formationPressRegroups)
    session.pressFormation()
    #expect(session.formation == .spread && !session.regrouping)
    // In a fight it clears the orders and regroups the companions, keeping the formation.
    #expect(session.beginEncounter(.stranger))
    #expect(session.formationPressRegroups && session.holdAll())
    session.pressFormation()
    #expect(session.regrouping && session.orders.isEmpty && session.formation == .spread)
    #expect(session.squadState == "regrouping")
    // A new order ends the regroup, and so does the end of the fight.
    #expect(session.send(.laura, to: [1, 1]))
    #expect(!session.regrouping)
    session.pressFormation()
    #expect(session.regrouping)
    session.endEncounter()
    #expect(!session.regrouping && session.squadState == "following")
    // The opening has no combat positioning: in its fights the button keeps its meaning.
    let bridge = GameSession(level: BrooklynBridge.level)
    #expect(bridge.beginEncounter(.stranger))
    #expect(!bridge.formationPressRegroups)
  }

  // MARK: - Helpers

  /// The shooter, beyond the gap between the two walls.
  private static let shooter: SIMD2<Float> = [0, -10]
  /// Where Laura goes: behind the east wall, as she starts behind the west one.
  private static let goal: SIMD2<Float> = [4, 0.5]

  /// Open snow 30 m across with the combat yard's rules: two walls across z = -1 with a 2 m gap
  /// between them, a screen 4 m wide across z = 2.2 beyond the gap, and one shooter, 10 m
  /// beyond the walls, that sees through the gap. The party waits behind the west wall, and the
  /// fight begins at once.
  private static func gap(positioning: Bool) -> Level {
    let hostile = Level.Hostile(
      id: "a", name: "Shooter A", hiddenAt: shooter, standAt: shooter, hits: 50, windUp: 1.5,
      recovery: 1.4, range: 20, inView: true, targetsAnyone: true, targetFromWindUp: true)
    let fight = Level.Encounter(
      beat: .stranger, start: .area(PartyMotion.Box(minimum: [-15, -15], maximum: [15, 15])),
      retryAt: [-6, 3], hostiles: [hostile], cues: [(at: 0, cue: .engage("a"))])
    var rules = CombatYard.combat
    rules.combatPositioning = positioning
    return Level(
      id: "gap", ground: .box("ground", at: [0, -0.15, 0], size: [30, 0.3, 30]),
      boxes: [
        .box("west-wall", at: [-6.5, 1.5, -1], size: [11, 3, 0.5]),
        .box("east-wall", at: [6.5, 1.5, -1], size: [11, 3, 0.5]),
        .box("screen", at: [0, 1.5, 2.2], size: [4, 3, 0.4]),
      ],
      interactions: [], triggers: [], encounters: [fight], startingAmmo: 60,
      party: [.miki, .tom, .laura],
      spawns: [.miki: [-6, 3], .tom: [-7.5, 3.5], .laura: [-4, 0.5]],
      heading: [0, -1], cameraOffset: CombatYard.level.cameraOffset,
      fieldOfView: CombatYard.level.fieldOfView, opening: "A gap.", objective: "Test.",
      lookAround: "Two walls and a screen.", restartNote: "Restart.", combat: rules)
  }
}
