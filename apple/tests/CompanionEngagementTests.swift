import Testing
import simd

@testable import Lauder

@MainActor
struct CompanionEngagementTests {
  private enum FixtureFailure: Error {
    case missingGuardComponent
  }

  /// A real, protected sword contact is still the player's attack. Before that contact,
  /// explicit stale AI fire intents must not turn the quiet approach into a fight.
  @Test
  func protectedPlayerSwordContactActivatesCompanionsOutsideTheDetectionCone() throws {
    let angle: Float = 53 * .pi / 180
    let initialLeader = SIMD2<Float>(-sin(angle), cos(angle)) * 2.3
    let hostile = Level.Hostile(
      id: "guard", name: "Guard", hiddenAt: .zero, standAt: .zero, hits: 6,
      attack: .robot, strategicGuard: true, range: 12)
    let encounter = Level.Encounter(
      beat: .stranger, start: .area(.init(minimum: [-10, -10], maximum: [10, 10])),
      retryAt: nil, hostiles: [hostile],
      cues: [(0, .reveal("guard")), (0, .engage("guard"))])
    let level = Level(
      id: "companion-engagement-fixture",
      ground: .box("floor", at: [0, -0.15, 0], size: [40, 0.3, 40]),
      boxes: [], triggers: [], encounters: [encounter], party: [.laura, .miki, .tom],
      spawns: [.laura: initialLeader, .miki: [0, 6], .tom: [6, 0]], heading: [0, -1],
      cameraOffset: BrooklynBridge.cameraOffset, fieldOfView: 22,
      opening: "Range", objective: "Test", lookAround: "Range", restartNote: "Restart")
    let session = GameSession(level: level)
    session.setCombatStance(.attack)
    let fight = EncounterSimulation(level: level)
    #expect(session.beginEncounter(encounter.beat))
    fight.begin(encounter)
    fight.swapWeapon(for: .laura)
    _ = fight.step(
      dt: 1 / 120, leader: initialLeader, facing: [0, -1], aiming: true, fireHeld: false,
      firePressed: false, figures: level.spawns, session: session)

    @discardableResult
    func step(attack: Bool = false) throws -> SIMD2<Float> {
      guard let robot = fight.hostiles["guard"]?.robot,
        let point = fight.weakpoints(for: "guard").first
      else {
        Issue.record("The engagement fixture lost its live guard or sensor component")
        throw FixtureFailure.missingGuardComponent
      }
      let front = simd_normalize(point.ground - robot.position)
      let radial = SIMD2(
        front.x * cos(angle) - front.y * sin(angle),
        front.x * sin(angle) + front.y * cos(angle))
      let leader = robot.position + radial * 2.3
      let figures: [PartyMember: SIMD2<Float>] = [
        .laura: leader, .miki: robot.position + front * 6,
        .tom: robot.position + SIMD2(front.y, -front.x) * 6,
      ]
      for position in figures.values {
        #expect(
          simd_distance(position, robot.position)
            > RobotModelGeometry.bodyRadius + PartyBody.radius)
      }
      #expect(simd_dot(radial, robot.facing) < cos(50 * .pi / 180))
      #expect(simd_distance(leader, point.ground) < Weapon.energySword.range + point.radius)
      _ = fight.step(
        dt: 1 / 120, leader: leader, facing: simd_normalize(point.ground - leader),
        aiming: true, fireHeld: attack, firePressed: attack, figures: figures, session: session,
        companionIntents: [
          .miki: .init(
            lookAt: point.ground, weapon: .longRifle, fire: true, activity: .attacking)
        ], facings: [.miki: -front])
      return leader
    }

    for _ in 0..<120 {
      let leader = try step()
      #expect(fight.companionGuard(near: leader) == nil)
      #expect(!fight.drawnWeapons.contains(.miki))
      #expect(!fight.shots.contains { $0.actor == .miki })
    }
    #expect(fight.isDrawn && fight.leaderWeapon.kind == .energySword)
    #expect(fight.hostiles["guard"]?.robot?.phase == .patrol)
    _ = fight.takeEvents()

    let contactPosition = try step(attack: true)
    let events = fight.takeEvents()
    #expect(events.contains { if case .fired(.energySword, _, true) = $0 { true } else { false } })
    #expect(events.contains { if case .struckBlock = $0 { true } else { false } })
    #expect(fight.guardStrategies["guard"]?.sensorDisabled == false)
    #expect(fight.companionGuard(near: contactPosition) != nil)
    #expect(fight.hostiles["guard"]?.robot?.phase == .patrol)
    try step()
    #expect(
      fight.drawnWeapons.contains(.miki), "the real player contact permits companion preparation")
  }
}
