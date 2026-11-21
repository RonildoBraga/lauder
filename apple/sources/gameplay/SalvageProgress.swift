/// What the party has done in a salvage task (ADR 0006), and what whoever leads can do next.
/// The session keeps it, and each run, Restart included, deals the cabinets' contents afresh, so
/// that only an inspection tells them apart.
///
/// No step needs one particular member, but each makes some step better:
/// - Laura reaches the gate's latch, or Tom shifts its loose panel, and either opens it for
///   everyone.
/// - Miki inspects the cabinets, and the right regulator is then anyone's to take.
/// - Anyone else can search a cabinet and take its regulator without knowing which it is.
/// - Nobody opens the live cabinet or takes a regulator the party knows will not fit.
/// - Anyone fits a regulator that might fit at the transmitter.
struct SalvageProgress: Equatable, Sendable {
  /// Where in the task the leader stands.
  enum Place: Equatable, Sendable {
    case latch, panel
    case cabinet(String)
    case transmitter
  }

  /// What the leader can do there.
  enum Action: Equatable, Sendable {
    case reachLatch, shiftPanel
    case inspect(String)
    case take(String)
    case search(String)
    case fit

    /// What the action button reads, short enough to fit the touch button.
    var name: String {
      switch self {
      case .reachLatch: "Reach the latch"
      case .shiftPanel: "Shift the panel"
      case .inspect: "Inspect"
      case .take: "Take regulator"
      case .search: "Search"
      case .fit: "Fit regulator"
      }
    }
  }

  /// A regulator in the shared bag: what it truly is, and whether the party knows it.
  struct Regulator: Equatable, Sendable {
    let model: Level.Salvage.Contents
    var known: Bool

    /// Whether it might fit: unless the party knows it is another model.
    var mightFit: Bool { !known || model == .compatible }
  }

  /// What each cabinet holds in this run.
  private(set) var contents: [String: Level.Salvage.Contents]
  private(set) var gateOpen = false
  /// Cabinets whose contents the party knows: inspected by Miki, or found live.
  private(set) var known: Set<String> = []
  /// Cabinets whose regulator is in the bag.
  private(set) var emptied: Set<String> = []
  /// The regulators in the shared bag, as they truly are, and whether the party knows it.
  private(set) var regulators: [Regulator] = []
  private(set) var repaired = false

  /// A run's progress with these contents in its cabinets, by id; none for a level without a
  /// salvage task.
  init(contents: [String: Level.Salvage.Contents] = [:]) {
    self.contents = contents
  }

  /// A new run's progress, with the task's contents dealt to its cabinets in a random order.
  static func dealt(
    for task: Level.Salvage, using generator: inout some RandomNumberGenerator
  ) -> SalvageProgress {
    let shuffled = task.cabinets.map(\.contents).shuffled(using: &generator)
    return SalvageProgress(
      contents: Dictionary(uniqueKeysWithValues: zip(task.cabinets.map(\.id), shuffled)))
  }

  /// A run's progress with the contents where the task authors them.
  static func authored(for task: Level.Salvage) -> SalvageProgress {
    SalvageProgress(
      contents: Dictionary(uniqueKeysWithValues: task.cabinets.map { ($0.id, $0.contents) }))
  }

  /// The action a member leading at `place` can take now; nil when there is none.
  func action(for member: PartyMember, at place: Place) -> Action? {
    switch place {
    case .latch:
      return member == .laura && !gateOpen ? .reachLatch : nil
    case .panel:
      return member == .tom && !gateOpen ? .shiftPanel : nil
    case .cabinet(let id):
      guard let contents = contents[id], !emptied.contains(id) else { return nil }
      guard known.contains(id) else { return member == .miki ? .inspect(id) : .search(id) }
      // Once the party knows a cabinet, anyone takes the right regulator from it, and nobody
      // takes anything else.
      return contents == .compatible ? .take(id) : nil
    case .transmitter:
      return !repaired && regulators.contains(where: \.mightFit) ? .fit : nil
    }
  }

  /// What a member who can do nothing at a place hears: at the gate, who could open it; at the
  /// transmitter, with only a regulator the party knows will not fit, who could tell the models
  /// apart.
  func hint(at place: Place) -> String? {
    switch place {
    case .latch: return gateOpen ? nil : "Laura could reach the latch."
    case .panel: return gateOpen ? nil : "Tom could shift the panel."
    case .cabinet: return nil
    case .transmitter:
      guard !repaired, !regulators.isEmpty, !regulators.contains(where: \.mightFit) else {
        return nil
      }
      return "This regulator won't fit. Miki could tell the models apart."
    }
  }

  /// What the HUD's panel lists in the shared bag, naming a regulator the party knows will not
  /// fit; nil when the bag is empty.
  var bag: String? {
    let wrong = regulators.filter { !$0.mightFit }.count
    switch (regulators.count, wrong) {
    case (0, _): return nil
    case (1, 0): return "a regulator"
    case (1, _): return "a regulator of a different model"
    case (let count, 0): return "\(count) regulators"
    case (let count, let wrong): return "\(count) regulators, \(wrong) of a different model"
    }
  }

  /// Take the action, with `member` leading, and say what happened, for the HUD.
  mutating func perform(_ action: Action, by member: PartyMember) -> String {
    switch action {
    case .reachLatch:
      gateOpen = true
      return "Laura reaches the latch, and the gate swings open."
    case .shiftPanel:
      gateOpen = true
      return "Tom shifts the loose panel, and the gate swings open."
    case .inspect(let id):
      known.insert(id)
      switch contents[id] {
      case .compatible: return "A compatible regulator, disconnected. Safe to take."
      case .otherModel: return "A regulator of a different model. It won't fit."
      case .live, nil: return Self.liveLine
      }
    case .take(let id):
      emptied.insert(id)
      regulators.append(Regulator(model: .compatible, known: true))
      return "\(member.displayName) takes the regulator."
    case .search(let id):
      guard let contents = contents[id], contents != .live else {
        known.insert(id)
        return Self.liveLine
      }
      emptied.insert(id)
      regulators.append(Regulator(model: contents, known: false))
      return "\(member.displayName) takes a regulator, but only Miki can tell its model."
    case .fit:
      guard let index = regulators.firstIndex(where: { $0.model == .compatible }) else {
        // Trying it tells the party what the bag holds.
        for index in regulators.indices { regulators[index].known = true }
        return "This regulator is a different model. It won't fit."
      }
      regulators.remove(at: index)
      repaired = true
      return "The regulator fits, and the transmitter answers."
    }
  }

  private static let liveLine = "Live: it still feeds the next shelter. Leave it connected."
}
