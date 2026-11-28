import Observation

/// The single authority for mode, leader and party progress. Plain rules, no scene.
@MainActor
@Observable
final class GameSession {
  enum Mode: Equatable, Sendable {
    case exploring, dialogue, paused
  }

  /// The pause menu's choices, in order. It opens on Resume.
  enum PauseChoice: CaseIterable, Sendable {
    case resume, restart
    /// Turns vibration off or on again, staying in the menu (ADR 0008).
    case vibration
    /// Hides the status panel or shows it again, staying in the menu.
    case statusPanel
  }

  /// How the companions arrange themselves around the leader, in the order the formation
  /// button cycles them (ADR 0003, phase S2).
  enum Formation: CaseIterable, Sendable {
    /// Beside and just behind the leader: ordinary travel.
    case close
    /// Wider to each side: open ground.
    case spread
    /// Single file on the leader's own route: tight places.
    case column

    var name: String {
      switch self {
      case .close: "Close"
      case .spread: "Spread"
      case .column: "Column"
      }
    }
  }

  /// What a companion is doing (ADR 0003, phase S3). Orders persist until replaced.
  enum Order: Equatable, Sendable {
    /// Keeping their place in the formation.
    case following
    /// Walking to a point the leader marked, to hold there.
    case going(SIMD2<Float>)
    /// Staying at a point until called back. Nil until the world records where they stand,
    /// for an order to hold where they are.
    case holding(SIMD2<Float>?)

    /// The word the HUD shows for it.
    var word: String {
      switch self {
      case .following: "following"
      case .going: "going"
      case .holding: "holding"
      }
    }
  }

  /// A squad command from the D-pad, the arrow keys or the touch menu (ADR 0003, phase S3).
  enum Command: Equatable, Sendable {
    /// Permit the companions' own role-aware attacks until Defend is ordered.
    case attack
    /// Cease companion attacks and recall them using nearby cover.
    case defend
    /// Both companions go to spots around the marked point.
    case bothGo
    /// The companion on that side goes to the marked point.
    case leftGoes, rightGoes
    /// Both companions hold where they stand.
    case hold
  }

  /// Permission to fight belongs to the squad, independently of the selected leader.
  enum CombatStance: String, Sendable {
    case attack, defend
  }

  /// Hits the leader can take in an encounter; the last one starts it again.
  static let hitsAllowed = 3

  /// What an encounter's retry returns to: the state when it began.
  private struct Checkpoint {
    let progress: BridgeProgress
    let defeated: Set<String>
    let hitsDealt: [String: Int]
  }

  private let startingParty: [PartyMember]
  /// Story policy is a checkpointable value; the session retains mode and shared progress.
  private var progress: BridgeProgress
  var beat: StoryBeat { progress.beat }
  /// Hits each member has taken in the current encounter, including companion crossfire.
  private var hits: [PartyMember: Int] = [:]
  /// Hostiles defeated in this run.
  private(set) var defeated: Set<String> = []
  /// Hits dealt to hostiles still standing.
  private var hitsDealt: [String: Int] = [:]
  /// Set while an encounter is under way.
  private var checkpoint: Checkpoint?
  private(set) var mode = Mode.exploring
  private(set) var leader: PartyMember
  /// Who travels together, in formation order. Laura remains an AI support companion when
  /// leadership switches between Miki and Tom.
  private(set) var party: [PartyMember]
  /// The trigger areas that have shown their line in this run.
  private(set) var firedTriggers: Set<String> = []
  private(set) var conversation: MissionScript.Conversation?
  private(set) var lineIndex = 0
  private(set) var pauseChoice = PauseChoice.resume
  /// The squad's formation. It stays Close until there are two companions.
  private(set) var formation = Formation.close
  /// Companions stay defensive until the player explicitly orders Attack.
  private(set) var combatStance = CombatStance.defend
  /// Companions going to or holding a point; everyone else follows (ADR 0003, phase S3).
  private(set) var orders: [PartyMember: Order] = [:]
  /// Where Resume returns: exploring, or the conversation at its current line.
  private var resumeMode = Mode.exploring

  init(level: Level) {
    precondition(!level.party.isEmpty, "\(level.id) must start with someone.")
    startingParty = level.party
    progress = BridgeProgress()
    party = level.party
    leader = level.party[0]
  }

  /// Whether an encounter is under way.
  var inEncounter: Bool { checkpoint != nil }

  /// Hits the leader has taken in the current encounter.
  var hitsTaken: Int { hits(of: leader) }

  /// Hits a member has taken in the current encounter.
  func hits(of member: PartyMember) -> Int {
    hits[member] ?? 0
  }

  var isPaused: Bool { mode == .paused }
  var availablePauseChoices: [PauseChoice] { PauseChoice.allCases }
  var currentLine: MissionScript.Line? {
    conversation.map { MissionScript.lines($0)[lineIndex] }
  }

  /// Next toggles between the available fighters; Laura stays computer-controlled.
  var nextLeader: PartyMember? {
    let fighters = party.filter { $0 != .laura }
    guard let index = fighters.firstIndex(of: leader) else { return fighters.first }
    return fighters.count > 1 ? fighters[(index + 1) % fighters.count] : nil
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

  /// Up (-1) and down (1) move through the choices, stopping at either end.
  func movePauseChoice(by step: Int) {
    guard mode == .paused, step != 0 else { return }
    let all = availablePauseChoices
    let index = all.firstIndex(of: pauseChoice) ?? 0
    pauseChoice = all[min(max(index + step.signum(), 0), all.count - 1)]
  }

  /// Position orders address both actual companions, independently of who can lead.
  var rightCompanion: PartyMember? { party.count > 2 ? companions.first : nil }

  /// The other companion, keeping the two D-pad destinations distinct after a leader switch.
  var leftCompanion: PartyMember? { party.count > 2 ? companions.last : nil }

  /// The leader's companions, in formation order from the leader.
  var companions: [PartyMember] {
    guard let index = party.firstIndex(of: leader) else { return [] }
    return (1..<party.count).map { party[(index + $0) % party.count] }
  }

  /// Next: change fighter, only while exploring.
  func cycleLeader() {
    guard let next = nextLeader else { return }
    lead(as: next)
  }

  /// A switch clears the new leader's order. The previous leader takes the squad's state: if
  /// the others are going or holding, they hold where they stand; otherwise they follow.
  private func lead(as member: PartyMember) {
    guard mode == .exploring else { return }
    let previous = leader
    leader = member
    orders[member] = nil
    if !orders.isEmpty { orders[previous] = .holding(nil) }
  }

  /// Whether squad orders are offered: with the formation button, once the leader has two
  /// companions, since that button also calls everyone back (ADR 0003, phase S3).
  var ordersAvailable: Bool { formationsAvailable }

  func order(of member: PartyMember) -> Order {
    orders[member] ?? .following
  }

  /// Defend is also a recall: replace old position orders without cycling the formation.
  @discardableResult
  func setCombatStance(_ stance: CombatStance) -> Bool {
    guard mode == .exploring, ordersAvailable else { return false }
    combatStance = stance
    if stance == .defend { orders = [:] }
    return true
  }

  /// A companion goes to a point the world has checked they can reach, and holds there. False
  /// while orders are not offered, outside exploring, or for the leader.
  @discardableResult
  func send(_ member: PartyMember, to point: SIMD2<Float>) -> Bool {
    guard mode == .exploring, ordersAvailable, member != leader, party.contains(member) else {
      return false
    }
    orders[member] = .going(point)
    return true
  }

  /// Both companions hold where they stand; the world records where that is.
  @discardableResult
  func holdAll() -> Bool {
    guard mode == .exploring, ordersAvailable else { return false }
    for member in companions { orders[member] = .holding(nil) }
    return true
  }

  /// The world records where a companion told to hold where they are stands.
  func pin(_ member: PartyMember, at point: SIMD2<Float>) {
    guard orders[member] == .holding(nil) else { return }
    orders[member] = .holding(point)
  }

  /// A going companion has reached their point and holds there.
  func arrived(_ member: PartyMember) {
    guard case .going(let point) = orders[member] else { return }
    orders[member] = .holding(point)
  }

  /// After an order, call everyone back; otherwise cycle the formation (ADR 0003).
  func pressFormation() {
    guard mode == .exploring, formationsAvailable else { return }
    if orders.isEmpty {
      cycleFormation()
    } else {
      orders = [:]
    }
  }

  /// What the squad is doing, for the HUD: following, going or holding.
  var squadState: String {
    let words = companions.map { order(of: $0).word }
    if let first = words.first, words.allSatisfy({ $0 == first }) { return first }
    return companions.filter { orders[$0] != nil }
      .map { "\($0.displayName) \(order(of: $0).word)" }
      .joined(separator: ", ")
  }

  /// Whether the formation button is offered: once the leader has two companions (ADR 0004,
  /// M5). Until then the one companion follows in the Close formation.
  var formationsAvailable: Bool { party.count >= 3 }

  /// The formation button: Close, then Spread, then Column, then Close again. Only while
  /// exploring, so Pause and conversations block it as they block switching.
  func cycleFormation() {
    guard mode == .exploring, formationsAvailable else { return }
    let all = Formation.allCases
    let index = all.firstIndex(of: formation) ?? 0
    formation = all[(index + 1) % all.count]
  }

  /// A member joins the party. Joining twice changes nothing.
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

  /// The beat after the current one, the only one that can begin; nil after the last.
  var nextBeat: StoryBeat? { progress.nextBeat }

  /// An encounter's beat begins: only the next beat, only while exploring and only once. What
  /// the party has now is kept, so a retry can return to it.
  func beginEncounter(_ next: StoryBeat) -> Bool {
    guard mode == .exploring, checkpoint == nil, next == nextBeat else { return false }
    checkpoint = Checkpoint(progress: progress, defeated: defeated, hitsDealt: hitsDealt)
    progress.begin(next)
    return true
  }

  /// Remaining generic enemy health in the session's existing damage-unit ledger.
  func remainingHealth(of hostile: String, toughness: Int) -> Int {
    defeated.contains(hostile) ? 0 : max(0, toughness - (hitsDealt[hostile] ?? 0))
  }

  /// One damage unit on a hostile; true when it takes the hostile down.
  func hit(_ hostile: String, toughness: Int) -> Bool {
    guard mode == .exploring, !defeated.contains(hostile) else { return false }
    let dealt = (hitsDealt[hostile] ?? 0) + 1
    guard dealt >= toughness else {
      hitsDealt[hostile] = dealt
      return false
    }
    hitsDealt[hostile] = nil
    defeated.insert(hostile)
    return true
  }

  /// A scripted takedown, such as Tom's shot: the hostile is down.
  func defeat(_ hostile: String) {
    guard mode == .exploring else { return }
    hitsDealt[hostile] = nil
    defeated.insert(hostile)
  }

  /// A conversation that a scene starts, rather than an action: true if it began.
  func converse(_ conversation: MissionScript.Conversation) -> Bool {
    guard mode == .exploring else { return false }
    tell(conversation)
    return true
  }

  /// The leader is hit; true on the last allowed hit, when the encounter must start again.
  func takeHit() -> Bool {
    takeHit(leader)
  }

  /// A member is hit; true on their last allowed hit, when the encounter must start again.
  func takeHit(_ member: PartyMember) -> Bool {
    guard mode == .exploring, inEncounter else { return false }
    let taken = hits(of: member) + 1
    hits[member] = taken
    return taken >= Self.hitsAllowed
  }

  /// The encounter starts again from its beginning: everything from before it stays, and
  /// everything that happened in it is undone.
  func retryEncounter() {
    guard let checkpoint else { return }
    progress = checkpoint.progress
    defeated = checkpoint.defeated
    hitsDealt = checkpoint.hitsDealt
    hits = [:]
    combatStance = .defend
    self.checkpoint = nil
  }

  /// The encounter is resolved by victory or safe bypass; everyone's temporary hits recover.
  func endEncounter() {
    checkpoint = nil
    hits = [:]
  }

  /// The action press during a conversation: the next line, or after the last, play resumes.
  func advanceDialogue() {
    guard mode == .dialogue, let conversation else { return }
    if lineIndex + 1 < MissionScript.lines(conversation).count {
      lineIndex += 1
    } else {
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
    formation = .close
    combatStance = .defend
    orders = [:]
    firedTriggers = []
    progress.restart()
    hits = [:]
    defeated = []
    hitsDealt = [:]
    checkpoint = nil
    conversation = nil
    lineIndex = 0
  }

  private func tell(_ conversation: MissionScript.Conversation) {
    self.conversation = conversation
    lineIndex = 0
    mode = .dialogue
  }
}
