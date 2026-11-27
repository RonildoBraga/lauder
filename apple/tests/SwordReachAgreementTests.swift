import Testing
import simd

@testable import Lauder

/// Laura's plan and her real swing judge a guard's leg by one rule (issue #209, finding 4).
/// Wherever the plan says her sword reaches the nearest leg, a swing from there, facing it,
/// lands on that leg; wherever the plan says it cannot, the swing does not land on it.
@MainActor
struct SwordReachAgreementTests {
  private static let id = "guard"

  @Test
  func thePlanAndTheSwingAgreeOnTheNearestLeg() throws {
    var reached = 0
    var refused = 0
    for radius in stride(from: Float(1.2), through: 3.3, by: 0.3) {
      for step in 0..<16 {
        let angle = Float(step) * .pi / 8
        let trial = try Trial()
        let origin = trial.guardPosition + SIMD2(cos(angle), sin(angle)) * radius
        let landed = trial.swing(from: origin)
        // Judged on the legs as the swing found them, after the guard's own step.
        let leg = try #require(trial.nearestLeg(to: origin))
        guard case .leg(let index) = leg.part else { continue }
        let planned = trial.fight.companionCanFire(
          .laura, from: origin, at: leg, weapon: .energySword, figures: [.laura: origin])
        #expect(
          planned == landed.contains(index), "at \(origin): plan \(planned), swing \(landed)")
        if planned { reached += 1 } else { refused += 1 }
      }
    }
    #expect(reached > 0 && refused > 0)
  }

  @MainActor
  private final class Trial {
    let fight: EncounterSimulation
    let session: GameSession

    init() throws {
      let hostile = Level.Hostile(
        id: SwordReachAgreementTests.id, name: "Guard", hiddenAt: .zero, standAt: .zero,
        hits: 6, attack: .robot, strategicGuard: true, range: 12)
      let encounter = Level.Encounter(
        beat: .stranger, start: .area(.init(minimum: [-40, -40], maximum: [40, 40])),
        retryAt: [0, 6], hostiles: [hostile],
        cues: [(0, .reveal(hostile.id)), (0, .engage(hostile.id))])
      let level = Level(
        id: "sword-reach-fixture",
        ground: .box("floor", at: [0, -0.15, 0], size: [100, 0.3, 100]),
        boxes: [], triggers: [], encounters: [encounter], party: [.laura],
        spawns: [.laura: [0, 6], .miki: [-20, 20], .tom: [20, 20]], heading: [0, -1],
        cameraOffset: BrooklynBridge.cameraOffset, fieldOfView: 22, opening: "Range",
        objective: "Test", lookAround: "Range", restartNote: "Restart")
      fight = EncounterSimulation(level: level)
      session = GameSession(level: level)
      try #require(session.beginEncounter(encounter.beat))
      fight.begin(encounter)
      if fight.weapon(of: .laura).kind != .energySword { fight.swapWeapon(for: .laura) }
    }

    var guardPosition: SIMD2<Float> {
      fight.hostiles[SwordReachAgreementTests.id]?.position ?? .zero
    }

    func nearestLeg(to origin: SIMD2<Float>) -> GuardWeakpoint? {
      fight.weakpoints(for: SwordReachAgreementTests.id).filter {
        if case .leg = $0.part { return true }
        return false
      }.min { simd_distance_squared($0.ground, origin) < simd_distance_squared($1.ground, origin) }
    }

    /// Laura draws and swings once from `origin`, facing the leg nearest her: the legs the
    /// swing landed on.
    func swing(from origin: SIMD2<Float>) -> Set<Int> {
      for _ in 0..<120 {
        let facing = nearestLeg(to: origin).map { simd_normalize($0.ground - origin) } ?? [0, -1]
        _ = fight.step(
          dt: 1 / 120, leader: origin, facing: facing, aiming: true, fireHeld: true,
          firePressed: true, figures: [.laura: origin], session: session,
          untouchable: Set(PartyMember.allCases))
        let swung = fight.takeEvents().contains {
          if case .fired(.energySword, _, _) = $0 { return true }
          return false
        }
        if swung {
          let hits = fight.guardStrategies[SwordReachAgreementTests.id]?.swordHits ?? [:]
          return Set(hits.filter { $0.value > 0 }.keys)
        }
      }
      Issue.record("Laura never swung from \(origin)")
      return []
    }
  }
}
