/// The bridge opening's ordered story markers (ADR 0004), shared by authored content and
/// progression rules without depending on a live game session.
enum StoryBeat: Int, Comparable, Sendable {
  case alone
  /// The first-tower guard; the authored identifier stays stable across the robot replacement.
  case stranger
  /// Opening the supply case begins the ambush (M3).
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

  static func < (lhs: StoryBeat, rhs: StoryBeat) -> Bool { lhs.rawValue < rhs.rawValue }

  var next: StoryBeat? { StoryBeat(rawValue: rawValue + 1) }
}
