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

  var next: PartyMember {
    switch self {
    case .miki: .laura
    case .laura: .tom
    case .tom: .miki
    }
  }
}
