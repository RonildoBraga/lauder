import Testing
import simd

@testable import Lauder

/// #227: a hostile's shot is told apart from the party's, a conversation holds the cues after it
/// until it ends, and a scripted takedown counts only when the session accepts it.
@MainActor
struct CombatEventsAndCuesTests {
  private static let figures: [PartyMember: SIMD2<Float>] = [
    .miki: [0, 2], .tom: [-1, 3], .laura: [1, 3],
  ]

  @Test
  func aHostilesShotIsReportedApartFromThePartysFire() throws {
    let (fight, session) = try Self.fight(cues: [(0, .reveal("shooter")), (0, .engage("shooter"))])
    var events: [CombatEvent] = []
    for _ in 0..<120 * 4 {
      step(fight, session)
      events += fight.takeEvents()
    }
    #expect(
      events.contains {
        if case .hostileFired(.rifle, let point) = $0 {
          simd_distance(point, [0, -4]) < 1
        } else {
          false
        }
      })
    // Nobody in the party fired, so no event claims a party weapon.
    #expect(!events.contains { if case .fired = $0 { true } else { false } })
  }

  @Test
  func cuesAfterAConversationWaitUntilItEnds() throws {
    let (fight, session) = try Self.fight(cues: [(0, .talk(.arrival)), (0, .reveal("shooter"))])
    step(fight, session)
    #expect(session.mode == .dialogue)
    #expect(fight.hostiles["shooter"]?.isVisible == false)
    finishDialogue(session)
    step(fight, session)
    #expect(fight.hostiles["shooter"]?.isVisible == true)
  }

  @Test
  func aScriptedShotAfterAConversationCountsItsTakedown() throws {
    let (fight, session) = try Self.fight(cues: [
      (0, .reveal("shooter")), (0, .talk(.arrival)), (0, .shot(by: .tom, at: "shooter")),
    ])
    step(fight, session)
    #expect(session.mode == .dialogue)
    #expect(fight.hostiles["shooter"]?.isDown == false && !session.defeated.contains("shooter"))
    finishDialogue(session)
    step(fight, session)
    #expect(fight.hostiles["shooter"]?.isDown == true && session.defeated.contains("shooter"))
  }

  @Test
  func aTakedownOutsideExplorationChangesNothing() throws {
    let (_, session) = try Self.fight(cues: [])
    #expect(session.converse(.arrival) && session.mode == .dialogue)
    #expect(!session.defeat("shooter"))
    #expect(session.defeated.isEmpty)
    finishDialogue(session)
    #expect(session.defeat("shooter") && session.defeated == ["shooter"])
  }

  private func step(_ fight: EncounterSimulation, _ session: GameSession) {
    _ = fight.step(
      dt: 1 / 120, leader: Self.figures[.miki] ?? .zero, facing: [0, -1], aiming: false,
      fireHeld: false, firePressed: false, figures: Self.figures, session: session,
      untouchable: Set(PartyMember.allCases))
  }

  private func finishDialogue(_ session: GameSession) {
    for _ in 0..<20 where session.mode == .dialogue { session.advanceDialogue() }
  }

  /// A plain shooter 6 m ahead of Miki, with the encounter begun.
  private static func fight(
    cues: [(at: Float, cue: Level.Cue)]
  ) throws -> (EncounterSimulation, GameSession) {
    let shooter = Level.Hostile(
      id: "shooter", name: "Shooter", hiddenAt: [0, -4], standAt: [0, -4], hits: 50,
      attack: .shoot, windUp: 1.5, recovery: 1.4, range: 14)
    let encounter = Level.Encounter(
      beat: .stranger, start: .area(.init(minimum: [-15, -15], maximum: [15, 15])),
      retryAt: [0, 2], hostiles: [shooter], cues: cues)
    let level = Level(
      id: "events-and-cues", ground: .box("ground", at: [0, -0.15, 0], size: [30, 0.3, 30]),
      boxes: [], triggers: [], encounters: [encounter], party: [.miki, .tom, .laura],
      spawns: figures, heading: [0, -1], cameraOffset: TestYard.cameraOffset, fieldOfView: 42,
      opening: "A range.", objective: "Test.", lookAround: "Snow.", restartNote: "Restart.")
    let session = GameSession(level: level)
    let fight = EncounterSimulation(level: level)
    try #require(session.beginEncounter(encounter.beat))
    fight.begin(encounter)
    return (fight, session)
  }
}
