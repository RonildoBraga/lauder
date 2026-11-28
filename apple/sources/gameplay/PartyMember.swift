/// The three travellers. The session owns membership, formation order and the two-fighter
/// leadership cycle; Laura remains an AI support companion.
enum PartyMember: String, CaseIterable, Sendable {
  case miki, laura, tom

  var displayName: String {
    switch self {
    case .miki: "Miki"
    case .laura: "Laura"
    case .tom: "Tom"
    }
  }
}
