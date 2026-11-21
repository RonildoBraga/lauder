/// What the party has done in a salvage task (ADR 0006), and what whoever leads can do next.
/// The session keeps it, and Restart starts it afresh.
///
/// No step needs one particular member, but each makes some step better:
/// - Laura reaches the gate's latch, or Tom shifts its loose panel, and either opens it for
///   everyone.
/// - Miki inspects the cabinets and takes the right regulator.
/// - Anyone else can search a cabinet and take its regulator without knowing which it is.
/// - Nobody opens the live cabinet, and anyone can fit a regulator at the transmitter.
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

    /// What the action button reads.
    var name: String {
      switch self {
      case .reachLatch: "Reach the latch"
      case .shiftPanel: "Shift the panel"
      case .inspect: "Inspect"
      case .take: "Take the regulator"
      case .search: "Search"
      case .fit: "Fit the regulator"
      }
    }
  }

  private(set) var gateOpen = false
  /// Cabinets whose contents the party knows: inspected by Miki, or found live.
  private(set) var known: Set<String> = []
  /// Cabinets whose regulator is in the bag.
  private(set) var emptied: Set<String> = []
  /// The regulators in the shared bag, as they truly are, whether or not anyone knows.
  private(set) var regulators: [Level.Salvage.Contents] = []
  private(set) var repaired = false

  /// The action a member leading at `place` can take now; nil when there is none.
  func action(for member: PartyMember, at place: Place, in task: Level.Salvage) -> Action? {
    switch place {
    case .latch:
      return member == .laura && !gateOpen ? .reachLatch : nil
    case .panel:
      return member == .tom && !gateOpen ? .shiftPanel : nil
    case .cabinet(let id):
      guard let contents = task.contents(of: id), !emptied.contains(id) else { return nil }
      if member == .miki {
        guard known.contains(id) else { return .inspect(id) }
        return contents == .compatible ? .take(id) : nil
      }
      return known.contains(id) && contents == .live ? nil : .search(id)
    case .transmitter:
      return !repaired && !regulators.isEmpty ? .fit : nil
    }
  }

  /// What a member who can do nothing at the gate hears: who could open it.
  func hint(at place: Place) -> String? {
    guard !gateOpen else { return nil }
    switch place {
    case .latch: return "Laura could reach the latch."
    case .panel: return "Tom could shift the panel."
    case .cabinet, .transmitter: return nil
    }
  }

  /// Take the action, and say what happened, for the HUD.
  mutating func perform(_ action: Action, in task: Level.Salvage) -> String {
    switch action {
    case .reachLatch:
      gateOpen = true
      return "Laura reaches the latch, and the gate swings open."
    case .shiftPanel:
      gateOpen = true
      return "Tom shifts the loose panel, and the gate opens."
    case .inspect(let id):
      known.insert(id)
      switch task.contents(of: id) {
      case .compatible: return "A compatible regulator, disconnected. Safe to take."
      case .otherModel: return "A regulator of a different model. It won't fit."
      case .live, nil: return Self.liveLine
      }
    case .take(let id):
      emptied.insert(id)
      regulators.append(.compatible)
      return "Miki takes the regulator."
    case .search(let id):
      guard let contents = task.contents(of: id), contents != .live else {
        known.insert(id)
        return Self.liveLine
      }
      emptied.insert(id)
      regulators.append(contents)
      return "Found a regulator."
    case .fit:
      guard let index = regulators.firstIndex(of: .compatible) else {
        return "This regulator is a different model. It won't fit."
      }
      regulators.remove(at: index)
      repaired = true
      return "The regulator fits, and the transmitter answers."
    }
  }

  private static let liveLine = "Live: it still feeds the next shelter. Leave it connected."
}

extension Level.Salvage {
  /// What the cabinet with this id holds; nil when there is no such cabinet.
  func contents(of id: String) -> Contents? {
    cabinets.first { $0.id == id }?.contents
  }
}
