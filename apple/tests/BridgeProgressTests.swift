import Observation
import Testing

@testable import Lauder

/// Progression is a value inside the session, while the session keeps authority over mode,
/// inventory and retry. These checks cover the boundaries affected by that separation.
@MainActor
struct BridgeProgressTests {
  @Test
  func retryingHelpRestoresTheStoryAndTheKitFromBeforeTheCost() {
    let session = readyToHelp()
    #expect(session.perform(.helpLaura) == .done)
    #expect(session.beat == .helpingLaura && session.medicalKits == 0)
    for _ in 0..<GameSession.hitsAllowed { _ = session.takeHit() }
    session.retryEncounter()
    #expect(session.beat == .lauraFound && !session.inEncounter)
    #expect(session.medicalKits == 1 && session.offers(.helpLaura))
    #expect(session.party == [.miki, .tom] && session.searched == ["stranger"])
    #expect(session.perform(.helpLaura) == .done)
    #expect(session.medicalKits == 0)
    #expect(session.perform(.helpLaura) == .alreadyDone)
    #expect(session.medicalKits == 0)
  }

  @Test
  func aPausedActionCannotBeginProgressOrSpendItsCost() {
    let session = readyToHelp()
    session.togglePause()
    #expect(session.perform(.helpLaura) == .unavailable)
    #expect(session.beat == .lauraFound && session.medicalKits == 1 && !session.inEncounter)
    session.togglePause()
    #expect(session.perform(.helpLaura) == .done)
    #expect(session.beat == .helpingLaura && session.medicalKits == 0)
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

  @Test
  func aStoryBeatNotificationSeesTheMemberAlreadyRecruited() async {
    let session = GameSession(level: BrooklynBridge.level)
    #expect(session.beginEncounter(.stranger))
    session.defeat("stranger")
    session.endEncounter()
    #expect(session.perform(.searchStranger) == .done)
    session.endEncounter()
    #expect(session.converse(.metTom))
    for _ in MissionScript.lines(.metTom).dropLast() { session.advanceDialogue() }
    #expect(session.beat == .ambush && session.party == [.miki])
    await confirmation { changed in
      withObservationTracking {
        _ = session.beat
      } onChange: {
        MainActor.assumeIsolated {
          #expect(session.party == [.miki, .tom])
          // Observation notifies before the property changes, after recruitment commits.
          #expect(session.beat == .ambush)
          changed()
        }
      }
      session.advanceDialogue()
    }
    #expect(session.party == [.miki, .tom] && session.beat == .withTom)
    #expect(session.mode == .exploring)
  }

  private func readyToHelp() -> GameSession {
    let session = GameSession(level: BrooklynBridge.level)
    #expect(session.beginEncounter(.stranger))
    session.defeat("stranger")
    session.endEncounter()
    #expect(session.perform(.searchStranger) == .done)
    #expect(session.search("stranger", loot: BrooklynBridge.stranger.loot ?? Level.Loot()))
    session.endEncounter()
    #expect(session.converse(.metTom))
    for _ in MissionScript.lines(.metTom) { session.advanceDialogue() }
    #expect(session.beginEncounter(.lauraFound))
    session.endEncounter()
    #expect(session.beat == .lauraFound && session.medicalKits == 1)
    return session
  }
}
