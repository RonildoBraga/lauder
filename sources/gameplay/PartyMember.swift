enum PartyMember: String, CaseIterable, Sendable {
  case miki, lara, tomas

  var displayName: String {
    switch self {
    case .miki: "Miki"
    case .lara: "Lara"
    case .tomas: "Tomas"
    }
  }

  var role: String {
    switch self {
    case .miki: "Systems"
    case .lara: "Agility"
    case .tomas: "Strength"
    }
  }

  var next: PartyMember {
    switch self {
    case .miki: .lara
    case .lara: .tomas
    case .tomas: .miki
    }
  }
}
