import Testing
import simd

@testable import Lauder

/// A low block protects its crouched target without protecting an unrelated standing body.
@MainActor
struct CoveredTargetTests {
  private static let lowBlock = PartyMotion.Box(minimum: [-1, 2], maximum: [1, 2.5])
  private static let covered = Aim.Hostile(
    id: "covered", position: [0, 5], isTarget: true, blockers: [lowBlock])

  @Test
  func assistedAimExcludesConcealedTargetsAndARayStrikesTheirCover() throws {
    let standing = Aim.Hostile(id: "standing", position: [3, 5], isTarget: true)
    let assisted = try #require(
      Aim.shot(
        from: .zero, aim: nil, facing: [0, 1], range: 14,
        hostiles: [Self.covered, standing], blockers: []))
    #expect(assisted.strike == .body("standing"))
    // Manual aim keeps its direction when the concealed body is not an assistance candidate.
    let aimed = try #require(
      Aim.shot(
        from: .zero, aim: [0, 1], facing: [0, 1], range: 14,
        hostiles: [Self.covered, standing], blockers: []))
    #expect(aimed.strike == .scenery && aimed.end == [0, 2])
    let ray = try #require(
      Aim.ray(
        from: .zero, along: [0, 1], range: 14, hostiles: [Self.covered], blockers: []))
    #expect(ray.strike == .scenery && ray.end == [0, 2])
  }

  @Test
  func anExposedBodyAndAnUnmodifiedTargetCanBothBeHit() throws {
    var exposed = Self.covered
    exposed.blockers = []
    for hostile in [exposed, Aim.Hostile(id: "ordinary", position: [0, 5], isTarget: true)] {
      let shot = try #require(
        Aim.shot(
          from: .zero, aim: nil, facing: [0, 1], range: 14,
          hostiles: [hostile], blockers: []))
      #expect(shot.strike == .body(hostile.id) && shot.end == hostile.position)
    }
  }

  @Test
  func aDeviatedActualRayMeetsLowCoverAtCrouchedHeightAndPassesAboveItWhileStanding() {
    let low = Level.Box.box("low", at: [0, 0.55, 2.25], size: [2, 1.1, 0.5])
    let level = Level(
      id: "covered-ray", ground: .box("ground", at: [0, -0.15, 0], size: [30, 0.3, 30]),
      boxes: [low], interactions: [], triggers: [], party: [.miki], spawns: [.miki: .zero],
      heading: [0, 1], cameraOffset: [0, 10, 10], fieldOfView: 42,
      opening: "A range.", objective: "Test.", lookAround: "Low cover.", restartNote: "Restart.")
    let ballistics = Ballistics(level: level)
    let standing = FightSimulation.aimHeight
    let crouched = standing * 0.68
    let start = SIMD3<Float>(0, standing, 0)
    let angle: Float = 0.01
    let covered = ballistics.trace(
      from: start, direction: [sin(angle), (crouched - standing) / 5, cos(angle)], range: 14,
      targets: [.init(id: "covered", centre: [0, crouched, 5])])
    #expect(covered.strike == .scenery)
    #expect(abs(covered.end.z - 2) < 0.0001 && abs(covered.end.x) < 0.03)
    let exposed = ballistics.trace(
      from: start, direction: [sin(angle), 0, cos(angle)], range: 14,
      targets: [.init(id: "covered", centre: [0, standing, 5])])
    #expect(exposed.strike == .body("covered"))
    #expect(exposed.end.y == standing)
  }

  @Test
  func aTargetsBlockersDoNotProtectAnotherStandingBody() throws {
    // The low block lies before both bodies. Only its crouched owner gets its protection.
    let standing = Aim.Hostile(id: "standing", position: [0, 4], isTarget: true)
    let shot = try #require(
      Aim.ray(
        from: .zero, along: [0, 1], range: 14,
        hostiles: [Self.covered, standing], blockers: []))
    #expect(shot.strike == .body("standing") && shot.end == standing.position)
    let global = PartyMotion.Box(minimum: [-1, 1], maximum: [1, 1.5])
    let blocked = try #require(
      Aim.ray(
        from: .zero, along: [0, 1], range: 14,
        hostiles: [Self.covered, standing], blockers: [global]))
    #expect(blocked.strike == .scenery && blocked.end == [0, 1])
  }

  @Test
  func anUncoveredUnknownStillHoldsFireWhileItsCoverCanStopAShot() throws {
    let unknown = Aim.Hostile(id: "unknown", position: [0, 5], isTarget: false)
    #expect(
      Aim.ray(from: .zero, along: [0, 1], range: 14, hostiles: [unknown], blockers: []) == nil)
    var concealed = unknown
    concealed.blockers = [Self.lowBlock]
    let shot = try #require(
      Aim.ray(from: .zero, along: [0, 1], range: 14, hostiles: [concealed], blockers: []))
    #expect(shot.strike == .scenery && shot.end == [0, 2])
  }
}
