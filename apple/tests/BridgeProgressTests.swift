import Observation
import Testing

@testable import Lauder

/// Progression is a value inside the session, while the session keeps authority over mode and
/// retry. The three cross together, so the bridge's story is the guard's fight, then the
/// Manhattan end.
@MainActor
struct BridgeProgressTests {
  @Test
  func theThreeStartTogetherAndTheBeatsComeInOrder() {
    let session = GameSession(level: BrooklynBridge.level)
    #expect(session.party == [.miki, .tom, .laura] && session.leader == .miki)
    #expect(session.beat == .crossing && session.formationsAvailable)
    #expect(!session.beginEncounter(.arrived), "Manhattan comes after the guard")
    #expect(session.beginEncounter(.stranger))
    #expect(!session.beginEncounter(.arrived), "not during the fight")
    session.endEncounter()
    #expect(session.beginEncounter(.arrived))
    #expect(session.beat == .arrived && session.nextBeat == nil)
    session.restart()
    #expect(session.beat == .crossing && session.party == [.miki, .tom, .laura])
  }

  /// A safe bypass ends the guard's encounter without inventing a defeat, and the Manhattan end
  /// still follows.
  @Test
  func aResolvedBypassLeadsOnToManhattanWithoutARobotDefeat() {
    let session = GameSession(level: BrooklynBridge.level)
    #expect(session.beginEncounter(.stranger))
    session.endEncounter()
    #expect(session.defeated.isEmpty && session.beat == .stranger)
    #expect(session.beginEncounter(.arrived))
  }

  @Test
  func retryingTheFightRestoresTheStoryFromBeforeIt() {
    let session = GameSession(level: BrooklynBridge.level)
    #expect(session.beginEncounter(.stranger))
    for _ in 0..<GameSession.hitsAllowed { _ = session.takeHit() }
    session.retryEncounter()
    #expect(session.beat == .crossing && !session.inEncounter)
    #expect(session.beginEncounter(.stranger))
  }

  @Test
  func storyChangesStillNotifyObserversThroughTheSession() async {
    let session = GameSession(level: BrooklynBridge.level)
    await confirmation { changed in
      withObservationTracking {
        _ = session.beat
      } onChange: {
        changed()
      }
      #expect(session.beginEncounter(.stranger))
    }
  }

  /// The closing exchange at the Manhattan end ends the opening; nobody joins any more.
  @Test
  func theClosingExchangeChangesNobody() {
    let session = GameSession(level: BrooklynBridge.level)
    #expect(session.beginEncounter(.stranger))
    session.endEncounter()
    #expect(session.beginEncounter(.arrived))
    #expect(session.converse(.arrival))
    for _ in MissionScript.lines(.arrival) { session.advanceDialogue() }
    #expect(session.mode == .exploring && session.party == [.miki, .tom, .laura])
    #expect(session.beat == .arrived)
  }
}
