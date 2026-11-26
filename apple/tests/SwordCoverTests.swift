import Testing
import simd

@testable import Lauder

@MainActor
struct SwordCoverTests {
  /// A swing must not damage the guard through a solid wall. A low block below the combat
  /// plane, or a wall beside the swing, leaves the same in-range strike available.
  @Test(arguments: [
    (SIMD3<Float>(0, 1.5, 0.2), SIMD3<Float>(8, 3, 0.3), false),
    (SIMD3<Float>(0, 0.25, 0.2), SIMD3<Float>(8, 0.5, 0.3), true),
    (SIMD3<Float>(4, 1.5, 0.2), SIMD3<Float>(1, 3, 0.3), true),
  ])
  func aSwordRespectsTheActualCoverHeightAndPosition(
    coverPosition: SIMD3<Float>, coverSize: SIMD3<Float>, canStrike: Bool
  ) throws {
    let leader = SIMD2<Float>(0, 2)
    let guardPoint = SIMD2<Float>(0, -1.6)
    let guardSpec = Level.Hostile(
      id: "guard", name: "Guard", hiddenAt: guardPoint, standAt: guardPoint, hits: 3,
      attack: .robot, range: 12)
    let encounter = Level.Encounter(
      beat: .stranger, start: .area(PartyMotion.Box(minimum: [-10, -10], maximum: [10, 10])),
      retryAt: nil, hostiles: [guardSpec],
      cues: [(at: 0, cue: .reveal("guard")), (at: 0, cue: .engage("guard"))])
    let level = Level(
      id: "sword-cover-fixture",
      ground: .box("ground", at: [0, -0.15, 0], size: [30, 0.3, 30]),
      boxes: [.box("cover", at: coverPosition, size: coverSize)], triggers: [],
      encounters: [encounter], party: [.miki, .tom, .laura],
      spawns: [.miki: [-6, 6], .tom: [6, 6], .laura: leader], heading: [0, -1],
      cameraOffset: TestYard.cameraOffset, fieldOfView: 42,
      opening: "A range.", objective: "Test.", lookAround: "Snow.", restartNote: "Restart.")
    let session = GameSession(level: level)
    session.cycleLeader()
    session.cycleLeader()
    #expect(session.leader == .laura)
    let fight = EncounterSimulation(level: level)
    #expect(session.beginEncounter(encounter.beat))
    fight.begin(encounter)
    fight.swapWeapon(for: .laura)

    var swings = 0
    var bodyImpacts = 0
    for frame in 0..<120 {
      _ = fight.step(
        dt: 1 / 120, leader: leader, facing: [0, -1], aiming: true, fireHeld: true,
        firePressed: frame == 0, figures: [.laura: leader], session: session)
      for event in fight.takeEvents() {
        if case .fired(.energySword, _, _) = event { swings += 1 }
        if case .struckBody = event { bodyImpacts += 1 }
      }
    }
    #expect(swings > 0, "cover does not silently cancel the swing itself")
    #expect(session.defeated.contains("guard") == canStrike)
    #expect((bodyImpacts > 0) == canStrike, "a blocked swing must not report a body impact")
    if !canStrike {
      let guardState = try #require(fight.hostiles["guard"])
      #expect(guardState.isVisible && guardState.isTargetable && !guardState.isDown)
      #expect(
        simd_distance(guardState.position, leader)
          < Weapon.energySword.range + RobotModelGeometry.navigationRadius,
        "the wall, rather than distance, prevents the strike")
    }
  }
}
