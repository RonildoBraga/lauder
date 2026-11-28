import Testing
import simd

@testable import Lauder

/// The maintainer's choices on #200 items 3 and 9. Without a lock, an aimed throw lands on the
/// enemy in the aim cone, and an unaimed throw takes an enemy behind low cover that its arc
/// clears. A grenade thrown before the fight is harmless practice.
@MainActor
struct GrenadeTargetingTests {
  @Test
  func anAimedThrowLandsOnTheEnemyInTheAimConeInsteadOfFlyingTheFullRange() throws {
    // Aimed at the guard from 4 m, 5° off: the throw used to land 6 m beyond it.
    let range = try Range(tom: [0, 4], facing: Self.turned([0, -1], by: 5))
    range.step(throwing: true, aiming: true)
    let landing = try #require(range.fight.grenade?.destination)
    #expect(simd_distance(SIMD2(landing.x, landing.z), .zero) < 0.01)
    #expect(range.blastHits().count == 1)
  }

  @Test
  func anAimedThrowWithNoEnemyInTheConeStillFliesTheFullRange() throws {
    let facing = Self.turned([0, -1], by: 30)
    let range = try Range(tom: [0, 4], facing: facing)
    range.step(throwing: true, aiming: true)
    let landing = try #require(range.fight.grenade?.destination)
    let expected = SIMD2<Float>(0, 4) + facing * Grenade.maximumRange
    #expect(simd_distance(SIMD2(landing.x, landing.z), expected) < 0.01)
  }

  @Test
  func anUnaimedThrowTakesAGuardBehindLowCoverThatTheArcClears() throws {
    // The bridge's 1.65 m cover, halfway to the guard, blocks a bullet line but not the arc.
    let cover = Level.Box.box("cover", at: [0, 0.825, 3], size: [6, 1.65, 0.2])
    let range = try Range(boxes: [cover], tom: [0, 6], facing: [0, -1])
    range.step(throwing: true)
    let landing = try #require(range.fight.grenade?.destination)
    #expect(simd_distance(SIMD2(landing.x, landing.z), .zero) < 0.01)
    #expect(range.blastHits().count == 1)
  }

  @Test
  func tallCoverStillKeepsAnUnaimedThrowFromTakingTheGuard() throws {
    let wall = Level.Box.box("wall", at: [0, 2, 3], size: [20, 4, 0.5])
    let range = try Range(boxes: [wall], tom: [0, 6], facing: [0, -1])
    range.step(throwing: true)
    let landing = try #require(range.fight.grenade?.destination)
    // With no enemy it can land on, the throw goes its full range ahead, and the wall stops it.
    #expect(simd_distance(SIMD2(landing.x, landing.z), [0, -4]) < 0.01)
    #expect(range.blastHits().isEmpty)
  }

  @Test(arguments: [false, true])
  func aGrenadeThrownBeforeTheFightIsHarmlessPractice(inFight: Bool) throws {
    // Tom throws at the guard's hidden spot, and the encounter begins while the grenade flies.
    let range = try Range(tom: [0, 10], facing: [0, -1], begun: inFight)
    range.step(throwing: true)
    let landing = try #require(range.fight.grenade?.destination)
    #expect(simd_distance(SIMD2(landing.x, landing.z), .zero) < 0.01)
    if !inFight { try range.beginEncounter() }
    let hits = range.blastHits()
    #expect(range.blastCount == 1)
    #expect(hits.count == (inFight ? 1 : 0))
    #expect(
      range.fight.guardStrategies["guard"]?.health
        == GuardStrategy.maximumHealth - hits.reduce(0) { $0 + $1.amount })
  }

  private static func turned(_ vector: SIMD2<Float>, by degrees: Float) -> SIMD2<Float> {
    let angle = degrees * .pi / 180
    return [
      vector.x * cos(angle) - vector.y * sin(angle), vector.x * sin(angle) + vector.y * cos(angle),
    ]
  }

  /// Tom alone with the guard at the origin, so he leads without switching.
  @MainActor
  private final class Range {
    let fight: EncounterSimulation
    let session: GameSession
    let encounter: Level.Encounter
    let figures: [PartyMember: SIMD2<Float>]
    let facing: SIMD2<Float>
    private(set) var blastCount = 0

    init(
      boxes: [Level.Box] = [], tom: SIMD2<Float>, facing: SIMD2<Float>, begun: Bool = true
    ) throws {
      figures = [.tom: tom]
      self.facing = facing
      let hostile = Level.Hostile(
        id: "guard", name: "Guard", hiddenAt: .zero, standAt: .zero, hits: 6,
        attack: .robot, strategicGuard: true, range: 12)
      encounter = Level.Encounter(
        beat: .stranger, start: .area(.init(minimum: [-20, -20], maximum: [20, 20])),
        retryAt: nil, hostiles: [hostile], cues: [(0, .reveal("guard")), (0, .engage("guard"))])
      let level = Level(
        id: "grenade-targeting", ground: .box("floor", at: [0, -0.15, 0], size: [60, 0.3, 60]),
        boxes: boxes, triggers: [], encounters: [encounter], party: [.tom], spawns: figures,
        heading: [0, -1], cameraOffset: BrooklynBridge.cameraOffset, fieldOfView: 22,
        opening: "Range", objective: "Test", lookAround: "Test", restartNote: "Test")
      session = GameSession(level: level)
      fight = EncounterSimulation(level: level)
      if begun { try beginEncounter() }
      step()
      _ = fight.takeEvents()
    }

    func beginEncounter() throws {
      try #require(session.beginEncounter(encounter.beat))
      fight.begin(encounter)
    }

    func step(throwing: Bool = false, aiming: Bool = false) {
      _ = fight.step(
        dt: 1 / 120, leader: figures[.tom] ?? .zero, facing: facing, aiming: aiming,
        fireHeld: false, firePressed: false, figures: figures, session: session,
        grenadePressed: throwing, untouchable: Set(session.party))
      blastCount += fight.blasts.count
    }

    /// Steps until the grenade has long gone off, returning the damage its blast did.
    func blastHits() -> [DamageHit] {
      var hits: [DamageHit] = []
      for _ in 0..<120 * 3 {
        step()
        hits += fight.takeEvents().compactMap {
          if case .damaged(let hit) = $0 { hit } else { nil }
        }
      }
      return hits
    }
  }
}
