/// The three playable characters. Who is in the party, and the switching order, belong to the
/// session; a level can start with fewer than three.
enum PartyMember: String, CaseIterable, Sendable {
  case miki, laura, tom

  var displayName: String {
    switch self {
    case .miki: "Miki"
    case .laura: "Laura"
    case .tom: "Tom"
    }
  }

  var role: String {
    switch self {
    case .miki: "Systems"
    case .laura: "Agility"
    case .tom: "Strength"
    }
  }
}
