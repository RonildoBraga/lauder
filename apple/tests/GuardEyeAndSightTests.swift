import Testing
import simd

@testable import Lauder

/// The maintainer's choices on #200 and #226: an eye critical needs a shot from within 60° of
/// the guard's facing, a crippled guard's sight drops with its body, and the party still walks
/// through a downed guard's wreck.
@MainActor
struct GuardEyeAndSightTests {
  private static let id = "guard"

  @Test
  func eyeCriticalsNeedAShotFromWithinSixtyDegreesOfTheGuardsFacing() throws {
    let fight = try Self.fight()
    let robot = try #require(fight.hostiles[Self.id]?.robot)
    let eye = try #require(fight.weakpoints(for: Self.id).first { $0.part == .eye })
    let side = SIMD2(-robot.facing.y, robot.facing.x)
    for degrees: Float in [0, 25, 50, 55, -55, 65, -65, 70, 80] {
      let angle = degrees * .pi / 180
      let shooter = eye.ground + (robot.facing * cos(angle) + side * sin(angle)) * 6
      let figures: [PartyMember: SIMD2<Float>] = [.miki: shooter]
      // Aimed straight at the eye: within the view angle it scores, beyond it the body does.
      let critical = fight.companionCanFire(
        .miki, from: shooter, at: eye, weapon: .longRifle, figures: figures)
      #expect(critical == (abs(degrees) < 60), "\(degrees)° off the guard's facing")
      #expect(
        fight.companionCanFireAtBody(
          .miki, from: shooter, at: Self.id, weapon: .longRifle, figures: figures),
        "the guard itself is still hit from \(degrees)°")
    }
  }

  @Test
  func aCrippledGuardsSightDropsWithItsBodyAndLosesOverLowCover() throws {
    var standing = RobotGuard(home: .zero, strategicPatterns: true)
    standing.reveal()
    var grounded = standing
    for _ in 0..<120 {
      _ = grounded.step(
        dt: 1 / 120, target: [0, 30], hasSight: false, obstacles: [], party: [],
        speedMultiplier: 0, grounded: true)
    }
    // The guard looks out from its guns, and its sight settles with its belly.
    #expect(abs(standing.sightHeight - RobotModelGeometry.gunMounts[0].y) < 0.0001)
    #expect(
      abs(grounded.sightHeight - (RobotGuard.standingSightHeight - RobotGuard.groundedDrop))
        < 0.0001)
    #expect(abs(grounded.sightHeight - grounded.muzzle(gun: 0).y) < 0.05)

    // A 1.2 m wall halfway to Miki: the standing guard's sight clears it, the grounded one's
    // doesn't. Behind the bridge's 1.65 m cover, neither sees her, as before.
    let miki: SIMD2<Float> = [0, 6]
    let low = try Self.fight(boxes: [.box("low-wall", at: [0, 0.6, 3], size: [6, 1.2, 0.2])])
    #expect(low.guardSees(miki, from: standing))
    #expect(!low.guardSees(miki, from: grounded))
    let cover = try Self.fight(boxes: [.box("cover", at: [0, 0.825, 3], size: [6, 1.65, 0.2])])
    #expect(!cover.guardSees(miki, from: standing) && !cover.guardSees(miki, from: grounded))
  }

  @Test
  func theWreckOfADownedGuardNoLongerBlocksTheParty() {
    var state = HostileState(spec: Self.guardSpec)
    #expect(!state.blocksParty)
    state.reveal()
    #expect(state.blocksParty)
    state.knockDown()
    #expect(!state.blocksParty)
  }

  private static let guardSpec = Level.Hostile(
    id: id, name: "Guard", hiddenAt: .zero, standAt: .zero, hits: 6, attack: .robot,
    strategicGuard: true)

  /// A revealed, engaged guard at the origin, with Miki far beyond its detection range.
  private static func fight(boxes: [Level.Box] = []) throws -> EncounterSimulation {
    let encounter = Level.Encounter(
      beat: .stranger, start: .area(.init(minimum: [-30, -30], maximum: [30, 30])),
      retryAt: nil, hostiles: [guardSpec], cues: [(0, .reveal(id)), (0, .engage(id))])
    let figures: [PartyMember: SIMD2<Float>] = [.miki: [0, 28]]
    let level = Level(
      id: "guard-eye-sight", ground: .box("floor", at: [0, -0.15, 0], size: [80, 0.3, 80]),
      boxes: boxes, triggers: [], encounters: [encounter], party: [.miki], spawns: figures,
      heading: [0, -1], cameraOffset: BrooklynBridge.cameraOffset, fieldOfView: 22,
      opening: "Test", objective: "Test", lookAround: "Test", restartNote: "Test")
    let session = GameSession(level: level)
    try #require(session.beginEncounter(encounter.beat))
    let fight = EncounterSimulation(level: level)
    fight.begin(encounter)
    _ = fight.step(
      dt: 1 / 120, leader: [0, 28], facing: [0, -1], aiming: false, fireHeld: false,
      firePressed: false, figures: figures, session: session)
    return fight
  }
}
