import Observation

/// The single authority for mode, leader and party progress. Plain rules, no scene.
@MainActor
@Observable
final class GameSession {
  enum Mode: Equatable, Sendable {
    case exploring, dialogue, paused
  }

  /// Party C's mission progress, in order. The carried part, the regulator's place in the world,
  /// the transmitter's state and the objective are all derived from it.
  enum Phase: Int, CaseIterable, Comparable, Sendable {
    case briefing, seekingRegulator, carryingRegulator, radioRepaired, meetingAgreed

    static func < (lhs: Phase, rhs: Phase) -> Bool { lhs.rawValue < rhs.rawValue }
  }

  /// The pause menu's two choices. It opens on Resume.
  enum PauseChoice: CaseIterable, Sendable {
    case resume, restart
  }

  enum ActionResult: Equatable, Sendable {
    /// Accepted: progress changed, or the plan was read.
    case done
    /// The action already succeeded; repeating it changes nothing.
    case alreadyDone
    /// The mission has not reached this action yet.
    case notYet
    case notEligible
    /// Repair without the regulator explains what is missing and changes nothing.
    case missingPart
    /// Only while exploring, not while paused or in a conversation.
    case unavailable
  }

  private let startingParty: [PartyMember]
  private let interactions: [Level.Interaction]
  private(set) var mode = Mode.exploring
  private(set) var leader: PartyMember
  /// Who travels together, in switching order. A level can start with fewer than three; the
  /// others join through the story (ADR 0004).
  private(set) var party: [PartyMember]
  /// The trigger areas that have shown their line in this run.
  private(set) var firedTriggers: Set<String> = []
  /// Party B's shared progress: either specialist action opens the passage for everyone. It is
  /// separate from the phase, because opening access is not a mission step.
  private(set) var passageOpen = false
  private(set) var phase = Phase.briefing
  private(set) var conversation: MissionScript.Conversation?
  private(set) var lineIndex = 0
  private(set) var pauseChoice = PauseChoice.resume
  /// Where Resume returns: exploring, or the conversation at its current line.
  private var resumeMode = Mode.exploring
  /// The phase the current conversation leads to. A step takes effect when its conversation
  /// ends, so finishing the call secures the meeting and Restart mid-conversation discards it.
  private var pendingPhase: Phase?

  init(level: Level) {
    precondition(!level.party.isEmpty, "\(level.id.rawValue) must start with someone.")
    startingParty = level.party
    interactions = level.interactions
    party = level.party
    leader = level.party[0]
  }

  var isPaused: Bool { mode == .paused }
  var carriesRegulator: Bool { phase == .carryingRegulator }
  var currentLine: MissionScript.Line? {
    conversation.map { MissionScript.lines($0)[lineIndex] }
  }

  /// Who Next would switch to, or nil while the leader travels alone.
  var nextLeader: PartyMember? {
    guard party.count > 1, let index = party.firstIndex(of: leader) else { return nil }
    return party[(index + 1) % party.count]
  }

  func togglePause() {
    if mode == .paused {
      mode = resumeMode
    } else {
      resumeMode = mode
      pauseChoice = .resume
      mode = .paused
    }
  }

  /// Up (-1) chooses Resume and down (1) chooses Restart.
  func movePauseChoice(by step: Int) {
    guard mode == .paused, step != 0 else { return }
    pauseChoice = step < 0 ? .resume : .restart
  }

  func cycleLeader() {
    guard mode == .exploring, let next = nextLeader else { return }
    leader = next
  }

  /// A member joins the party and can lead from now on. Joining twice changes nothing.
  func recruit(_ member: PartyMember) {
    guard !party.contains(member) else { return }
    party.append(member)
  }

  /// The leader walked into a trigger area: true the first time in a run, so its line shows
  /// once, and false afterwards or outside exploring.
  func fire(_ trigger: String) -> Bool {
    guard mode == .exploring else { return false }
    return firedTriggers.insert(trigger).inserted
  }

  /// Whether the action is offered at its approach now. Exactly one transmitter action is
  /// offered in each phase.
  func offers(_ action: Level.ActionID) -> Bool {
    switch action {
    case .reachLatch, .shiftPanel: !passageOpen
    case .hearBriefing: phase == .briefing
    case .takeRegulator: phase == .seekingRegulator
    case .repairTransmitter: phase == .seekingRegulator || phase == .carryingRegulator
    case .callCrew: phase == .radioRepaired
    case .readPlan: phase == .meetingAgreed
    }
  }

  func isEligible(_ member: PartyMember, for action: Level.ActionID) -> Bool {
    interactions.first { $0.id == action }?.member.map { $0 == member } ?? true
  }

  /// Accept or reject a named action. The world has already checked that the active body
  /// stands in the action's approach area; the session checks mode, progress and eligibility.
  /// An accepted mission step starts its conversation and takes effect when it ends.
  func perform(_ action: Level.ActionID, by member: PartyMember) -> ActionResult {
    guard mode == .exploring else { return .unavailable }
    switch action {
    case .reachLatch, .shiftPanel:
      // Repeating either method, by anyone, has no further effect once the passage is open.
      guard !passageOpen else { return .alreadyDone }
      guard isEligible(member, for: action) else { return .notEligible }
      passageOpen = true
    case .hearBriefing:
      guard phase == .briefing else { return .alreadyDone }
      advance(to: .seekingRegulator, telling: .briefing)
    case .takeRegulator:
      guard phase <= .seekingRegulator else { return .alreadyDone }
      guard phase == .seekingRegulator else { return .notYet }
      guard isEligible(member, for: action) else { return .notEligible }
      advance(to: .carryingRegulator, telling: .inspection)
    case .repairTransmitter:
      guard phase <= .carryingRegulator else { return .alreadyDone }
      guard phase > .briefing else { return .notYet }
      guard isEligible(member, for: action) else { return .notEligible }
      guard phase == .carryingRegulator else { return .missingPart }
      advance(to: .radioRepaired, telling: .repair)
    case .callCrew:
      guard phase <= .radioRepaired else { return .alreadyDone }
      guard phase == .radioRepaired else { return .notYet }
      advance(to: .meetingAgreed, telling: .call)
    case .readPlan:
      // Reading the plan repeats the meeting details and changes no progress.
      guard phase == .meetingAgreed else { return .notYet }
      tell(.plan)
    }
    return .done
  }

  /// The action press during a conversation: the next line, or after the last, the step takes
  /// effect and play resumes.
  func advanceDialogue() {
    guard mode == .dialogue, let conversation else { return }
    if lineIndex + 1 < MissionScript.lines(conversation).count {
      lineIndex += 1
    } else {
      if let pendingPhase { phase = pendingPhase }
      pendingPhase = nil
      self.conversation = nil
      lineIndex = 0
      mode = .exploring
    }
  }

  /// A new run from the beginning, kept in memory like the first one.
  func restart() {
    mode = .exploring
    resumeMode = .exploring
    pauseChoice = .resume
    party = startingParty
    leader = startingParty[0]
    firedTriggers = []
    passageOpen = false
    phase = .briefing
    pendingPhase = nil
    conversation = nil
    lineIndex = 0
  }

  private func advance(to next: Phase, telling conversation: MissionScript.Conversation) {
    pendingPhase = next
    tell(conversation)
  }

  private func tell(_ conversation: MissionScript.Conversation) {
    self.conversation = conversation
    lineIndex = 0
    mode = .dialogue
  }
}
