/// The bridge's progression and interaction policy. The session supplies current inventory and
/// encounter facts, then owns mode, checkpoints and accepted effects. This value can be copied
/// into a checkpoint without retaining a live session or presentation state.
struct BridgeProgress: Sendable {
  enum Action {
    case refused(ActionResult)
    /// Begin this authored encounter before spending its kit cost. A rejected start uses the
    /// action's existing result: a repeated search, or Help while its scene is still active.
    case begin(beat: StoryBeat, medicalKits: Int, otherwise: ActionResult)
  }

  private let beatStarted: [Level.ActionID: StoryBeat]
  private(set) var beat = StoryBeat.alone

  init(encounters: [Level.Encounter]) {
    beatStarted = Dictionary(
      encounters.compactMap { encounter in
        if case .action(let action) = encounter.start { (action, encounter.beat) } else { nil }
      },
      uniquingKeysWith: { first, _ in first })
  }

  var nextBeat: StoryBeat? { beat.next }

  @discardableResult
  mutating func begin(_ next: StoryBeat) -> Bool {
    guard next == nextBeat else { return false }
    beat = next
    return true
  }

  func offers(
    _ action: Level.ActionID, searched: Set<String>, inEncounter: Bool
  ) -> Bool {
    switch action {
    case .searchStranger:
      !searched.contains(BrooklynBridge.supplyCaseID) && beat == .stranger && !inEncounter
    case .helpLaura: beat == .lauraFound && !inEncounter
    }
  }

  /// Plans an action without changing progress or inventory. The session checkpoints the
  /// accepted encounter first, so retry restores the kit that Help subsequently spends.
  func action(
    _ action: Level.ActionID, searched: Set<String>, medicalKits: Int,
    inEncounter: Bool
  ) -> Action {
    switch action {
    case .searchStranger:
      guard beat >= .stranger else { return .refused(.notYet) }
      guard !searched.contains(BrooklynBridge.supplyCaseID), let next = beatStarted[action],
        beat == .stranger
      else {
        return .refused(.alreadyDone)
      }
      guard !inEncounter else { return .refused(.notYet) }
      return .begin(beat: next, medicalKits: 0, otherwise: .alreadyDone)
    case .helpLaura:
      if beat > .lauraFound { return .refused(.alreadyDone) }
      guard beat == .lauraFound, medicalKits > 0 else { return .refused(.notYet) }
      guard !inEncounter, let next = beatStarted[action] else {
        return .refused(.unavailable)
      }
      return .begin(beat: next, medicalKits: 1, otherwise: .unavailable)
    }
  }

  struct Completion {
    let recruit: PartyMember?
    let nextBeat: StoryBeat?
  }

  /// Plan the final line's effects without mutation. The session first recruits the member,
  /// then applies progression, preserving what observers see as the beat changes.
  func completion(of conversation: MissionScript.Conversation) -> Completion {
    switch conversation {
    case .metTom:
      Completion(recruit: .tom, nextBeat: beat == .ambush ? .withTom : nil)
    case .metLaura:
      Completion(recruit: .laura, nextBeat: beat == .helpingLaura ? .withLaura : nil)
    case .arrival:
      Completion(recruit: nil, nextBeat: nil)
    }
  }

  mutating func finish(_ completion: Completion) {
    if let next = completion.nextBeat { beat = next }
  }

  mutating func restart() {
    beat = .alone
  }
}
