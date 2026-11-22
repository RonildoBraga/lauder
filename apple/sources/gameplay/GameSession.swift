import Observation

/// The single authority for mode, leader and party progress. Plain rules, no scene.
@MainActor
@Observable
final class GameSession {
  enum Mode: Equatable, Sendable {
    case exploring, dialogue, paused
  }

  /// The opening's story beats, in order (ADR 0004). Each begins once, after the one before.
  enum Beat: Int, Comparable, Sendable {
    case alone, stranger
    /// Searching the stranger's body begins the ambush (M3).
    case ambush
    /// After the exchange that follows Tom's shot, Tom travels with Miki.
    case withTom
    /// The party nears the place beyond mid-span where Laura lies hurt in the snow (M4).
    case lauraFound
    /// Helping Laura: the medical kit lets her stand (M4).
    case helpingLaura
    /// After the exchange that follows, Laura travels with them too.
    case withLaura
    /// The three reach the Manhattan end together: the end of the opening.
    case arrived

    static func < (lhs: Beat, rhs: Beat) -> Bool { lhs.rawValue < rhs.rawValue }
  }

  /// The pause menu's choices, in order. It opens on Resume.
  enum PauseChoice: CaseIterable, Sendable {
    case resume, restart
    /// While the combat experiment lasts, the other level as a new run: the combat yard from
    /// the bridge, and the bridge from the yard (ADR 0005).
    case otherLevel
    /// Turns vibration off or on again, staying in the menu (ADR 0008).
    case vibration
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
    /// Both companions go to spots around the marked point.
    case bothGo
    /// The companion on that side goes to the marked point.
    case leftGoes, rightGoes
    /// Both companions hold where they stand.
    case hold
  }

  /// Hits a member can take in an encounter; the last one starts it again, or falls the party
  /// back where the level has that rule (the placeholder hit rule of The Quiet Yard).
  static let hitsAllowed = 3

  /// What an encounter's retry returns to: the state when it began.
  private struct Checkpoint {
    let beat: Beat
    let ammo: Int
    let medicalKits: Int
    let defeated: Set<String>
    let searched: Set<String>
    let hitsDealt: [String: Int]
  }

  enum ActionResult: Equatable, Sendable {
    /// Accepted: progress changed.
    case done
    /// The action already succeeded; repeating it changes nothing.
    case alreadyDone
    /// The story has not reached this action yet.
    case notYet
    /// Not now: only while exploring, not while paused or in a conversation, and not while a
    /// scene that must finish first is still playing.
    case unavailable
  }

  private let startingParty: [PartyMember]
  private let startingAmmo: Int
  private let isArena: Bool
  /// Whether the formation button regroups the companions in a fight: in a level with combat
  /// positioning (ADR 0003, phase S4), such as the combat yard.
  private let regroupsInFights: Bool
  /// The beat each encounter-starting action begins, from the level's encounters.
  private let beatStarted: [Level.ActionID: Beat]
  /// The story's progress on the bridge.
  private(set) var beat = Beat.alone
  /// Hits each member has taken in the current encounter. On the bridge only the leader is hit.
  private var hits: [PartyMember: Int] = [:]
  /// Rounds left for the leader's weapon.
  private(set) var ammo: Int
  /// Hostiles defeated in this run.
  private(set) var defeated: Set<String> = []
  /// Bodies searched in this run.
  private(set) var searched: Set<String> = []
  /// Medical kits in the party's small shared inventory.
  private(set) var medicalKits = 0
  /// Hits dealt to hostiles still standing.
  private var hitsDealt: [String: Int] = [:]
  /// Set while an encounter is under way.
  private var checkpoint: Checkpoint?
  private(set) var mode = Mode.exploring
  private(set) var leader: PartyMember
  /// Who travels together, in switching order. A level can start with fewer than three; the
  /// others join through the story (ADR 0004).
  private(set) var party: [PartyMember]
  /// The trigger areas that have shown their line in this run.
  private(set) var firedTriggers: Set<String> = []
  private(set) var conversation: MissionScript.Conversation?
  private(set) var lineIndex = 0
  private(set) var pauseChoice = PauseChoice.resume
  /// The squad's formation. It stays Close until there are two companions.
  private(set) var formation = Formation.close
  /// Companions going to or holding a point; everyone else follows (ADR 0003, phase S3).
  private(set) var orders: [PartyMember: Order] = [:]
  /// What the party has done in the level's salvage task (ADR 0006).
  private(set) var salvage = SalvageProgress()
  /// The level's salvage task, whose cabinets each run deals afresh.
  private let salvageTask: Level.Salvage?
  /// Whether the companions are regrouping: in a fight they leave cover and firing positions,
  /// hold their fire and come back to the formation, until they are back in it or the fight
  /// ends (ADR 0003, phase S4).
  private(set) var regrouping = false
  /// Where Resume returns: exploring, or the conversation at its current line.
  private var resumeMode = Mode.exploring

  init(level: Level) {
    precondition(!level.party.isEmpty, "\(level.id) must start with someone.")
    startingParty = level.party
    startingAmmo = level.startingAmmo
    isArena = level.arena != nil
    regroupsInFights = level.combat.combatPositioning
    salvageTask = level.salvage
    salvage = Self.newSalvage(for: level.salvage)
    ammo = level.startingAmmo
    beatStarted = Dictionary(
      level.encounters.compactMap { encounter in
        if case .action(let action) = encounter.start { (action, encounter.beat) } else { nil }
      },
      uniquingKeysWith: { first, _ in first })
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
  var currentLine: MissionScript.Line? {
    conversation.map { MissionScript.lines($0)[lineIndex] }
  }

  /// Who Next would switch to, or nil while the leader travels alone.
  var nextLeader: PartyMember? {
    guard party.count > 1, let index = party.firstIndex(of: leader) else { return nil }
    return party[(index + 1) % party.count]
  }

  /// Who Previous would switch to: the member before the leader in switching order, the same as
  /// Next while there are two, or nil while the leader travels alone (ADR 0005).
  var previousLeader: PartyMember? {
    guard party.count > 1, let index = party.firstIndex(of: leader) else { return nil }
    return party[(index + party.count - 1) % party.count]
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

  /// Up (-1) and down (1) move the choice one place through Resume, Restart and the other level,
  /// stopping at either end.
  func movePauseChoice(by step: Int) {
    guard mode == .paused, step != 0 else { return }
    let all = PauseChoice.allCases
    let index = all.firstIndex(of: pauseChoice) ?? 0
    pauseChoice = all[min(max(index + step.signum(), 0), all.count - 1)]
  }

  /// Who the right D-pad direction sends: whoever Next would lead as, since R1 is on the right.
  var rightCompanion: PartyMember? { party.count > 2 ? nextLeader : nil }

  /// Who the left D-pad direction sends: the member before the leader in the switching order.
  /// The two sides keep this order for whoever leads, as the HUD's "◀ Laura · Tom ▶" shows.
  var leftCompanion: PartyMember? { party.count > 2 ? previousLeader : nil }

  /// The leader's companions, in switching order from the leader.
  var companions: [PartyMember] {
    guard let index = party.firstIndex(of: leader) else { return [] }
    return (1..<party.count).map { party[(index + $0) % party.count] }
  }

  /// Next: lead as the member after the leader, only while exploring.
  func cycleLeader() {
    guard let next = nextLeader else { return }
    lead(as: next)
  }

  /// Previous: lead as the member before the leader, on the same terms as Next (ADR 0005).
  func cycleLeaderBackwards() {
    guard let previous = previousLeader else { return }
    lead(as: previous)
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

  /// A companion goes to a point the world has checked they can reach, and holds there. False
  /// while orders are not offered, outside exploring, or for the leader.
  @discardableResult
  func send(_ member: PartyMember, to point: SIMD2<Float>) -> Bool {
    guard mode == .exploring, ordersAvailable, member != leader, party.contains(member) else {
      return false
    }
    orders[member] = .going(point)
    regrouping = false
    return true
  }

  /// Both companions hold where they stand; the world records where that is.
  @discardableResult
  func holdAll() -> Bool {
    guard mode == .exploring, ordersAvailable else { return false }
    for member in companions { orders[member] = .holding(nil) }
    regrouping = false
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

  /// The formation button (ADR 0003): in a fight where the level has combat positioning it
  /// regroups the companions; otherwise, with anyone going or holding, it calls everyone back to
  /// follow in the current formation, and else it cycles the formation.
  func pressFormation() {
    guard mode == .exploring, formationsAvailable else { return }
    if formationPressRegroups {
      orders = [:]
      regrouping = true
    } else if orders.isEmpty {
      cycleFormation()
    } else {
      orders = [:]
    }
  }

  /// Whether the formation button regroups the companions now, rather than changing the
  /// formation or calling them back: in a fight, in a level with combat positioning (ADR 0003,
  /// phase S4).
  var formationPressRegroups: Bool { regroupsInFights && inEncounter }

  /// The companions are back in the formation, and their regrouping ends.
  func endRegroup() {
    regrouping = false
  }

  /// What the squad is doing, for the HUD: "regrouping"; or "following", "going" or "holding"
  /// when the companions agree, otherwise who is not following, such as "Laura holding".
  var squadState: String {
    if regrouping { return "regrouping" }
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

  /// The beat after the current one, the only one that can begin; nil after the last.
  var nextBeat: Beat? { Beat(rawValue: beat.rawValue + 1) }

  /// An encounter's beat begins: only the next beat, only while exploring and only once. What
  /// the party has now is kept, so a retry can return to it.
  func beginEncounter(_ next: Beat) -> Bool {
    guard mode == .exploring, checkpoint == nil, next == nextBeat else { return false }
    checkpoint = Checkpoint(
      beat: beat, ammo: ammo, medicalKits: medicalKits, defeated: defeated, searched: searched,
      hitsDealt: hitsDealt)
    beat = next
    return true
  }

  /// One round leaves the leader's weapon; false when it is empty.
  func spendRound() -> Bool {
    guard mode == .exploring, ammo > 0 else { return false }
    ammo -= 1
    return true
  }

  /// The combat test reuses a fixed actor pool. Remove its previous-life records before a
  /// respawn, and recover the trio and ammunition during the warned inter-wave break.
  func prepareArena(hostiles ids: Set<String>, resupply: Bool = false) {
    guard isArena, mode == .exploring else { return }
    defeated.subtract(ids)
    searched.subtract(ids)
    for id in ids { hitsDealt[id] = nil }
    if resupply {
      ammo = startingAmmo
      hits = [:]
      regrouping = false
    }
  }

  /// A hit on a hostile; true when it takes the hostile down.
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

  /// A downed hostile's body is searched and its loot taken: true the first time.
  func search(_ body: String, loot: Level.Loot) -> Bool {
    guard mode == .exploring, defeated.contains(body), searched.insert(body).inserted else {
      return false
    }
    ammo += loot.rounds
    medicalKits += loot.medicalKits
    return true
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

  /// A member is hit; true on their last allowed hit, when the encounter must start again or,
  /// where the level has that rule, the party falls back.
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
    beat = checkpoint.beat
    ammo = checkpoint.ammo
    medicalKits = checkpoint.medicalKits
    defeated = checkpoint.defeated
    searched = checkpoint.searched
    hitsDealt = checkpoint.hitsDealt
    hits = [:]
    regrouping = false
    self.checkpoint = nil
  }

  /// The party falls back after the last allowed hit on anyone (ADR 0005). The encounter is no
  /// longer under way and can begin again, everyone's hits recover and every companion follows
  /// again; the hostiles keep the damage dealt, whoever is down stays down, and nothing else
  /// is undone.
  func fallBack() {
    guard let checkpoint else { return }
    beat = checkpoint.beat
    hits = [:]
    orders = [:]
    regrouping = false
    self.checkpoint = nil
  }

  /// The encounter is won; everyone's hits recover, and a regroup ends.
  func endEncounter() {
    checkpoint = nil
    hits = [:]
    regrouping = false
  }

  /// Whoever leads acts at a place in the level's salvage task (ADR 0006), and the line for
  /// the HUD comes back; nil when they can do nothing there. The world has checked where they
  /// stand; the session checks the mode and who leads, afresh.
  func performSalvage(at place: SalvageProgress.Place) -> String? {
    guard mode == .exploring, let action = salvage.action(for: leader, at: place) else {
      return nil
    }
    let repaired = salvage.repaired
    let line = salvage.perform(action, by: leader)
    if !repaired, salvage.repaired, let completion = salvageTask?.completion {
      _ = converse(completion)
    }
    return line
  }

  /// A new run's salvage progress, with the task's cabinets dealt afresh.
  private static func newSalvage(for task: Level.Salvage?) -> SalvageProgress {
    guard let task else { return SalvageProgress() }
    var generator = SystemRandomNumberGenerator()
    return .dealt(for: task, using: &generator)
  }

  /// Whether the action is offered at its approach now.
  func offers(_ action: Level.ActionID) -> Bool {
    switch action {
    case .searchStranger:
      defeated.contains("stranger") && !searched.contains("stranger") && beat == .stranger
        && !inEncounter
    case .helpLaura: beat == .lauraFound && !inEncounter
    }
  }

  /// Accept or reject a named action. The world has already checked that the leader stands in
  /// the action's approach area; the session checks mode and progress.
  func perform(_ action: Level.ActionID) -> ActionResult {
    guard mode == .exploring else { return .unavailable }
    switch action {
    case .searchStranger:
      // The search begins the ambush; the loot is taken when it finishes (ADR 0004, M3).
      guard defeated.contains("stranger") else { return .notYet }
      guard !searched.contains("stranger"), let beat = beatStarted[action],
        beginEncounter(beat)
      else { return .alreadyDone }
    case .helpLaura:
      // Helping uses the medical kit from the stranger's body and begins a short scene (M4).
      if beat > .lauraFound { return .alreadyDone }
      guard beat == .lauraFound, medicalKits > 0 else { return .notYet }
      // While she is still calling out, a press does nothing.
      guard !inEncounter, let next = beatStarted[action], beginEncounter(next) else {
        return .unavailable
      }
      medicalKits -= 1
    }
    return .done
  }

  /// The action press during a conversation: the next line, or after the last, what it settles
  /// takes effect and play resumes.
  func advanceDialogue() {
    guard mode == .dialogue, let conversation else { return }
    if lineIndex + 1 < MissionScript.lines(conversation).count {
      lineIndex += 1
    } else {
      switch conversation {
      case .metTom:
        // The exchange after Tom's shot ends with him joining (ADR 0004, M3).
        recruit(.tom)
        if beat == .ambush { beat = .withTom }
      case .metLaura:
        // And the one after Laura stands ends with her joining (M4).
        recruit(.laura)
        if beat == .helpingLaura { beat = .withLaura }
      case .arrival, .relayRestored:
        break
      }
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
    orders = [:]
    regrouping = false
    salvage = Self.newSalvage(for: salvageTask)
    firedTriggers = []
    beat = .alone
    hits = [:]
    ammo = startingAmmo
    defeated = []
    searched = []
    medicalKits = 0
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
