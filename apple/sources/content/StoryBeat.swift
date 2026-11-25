/// The bridge opening's ordered story markers (ADR 0004), shared by authored content and
/// progression rules without depending on a live game session.
enum StoryBeat: Int, Comparable, Sendable {
  /// Miki, Tom and Laura cross together from the Brooklyn end towards the first tower.
  case crossing
  /// The first-tower guard; the authored identifier stays stable across the robot replacement.
  case stranger
  /// The three reach the Manhattan end together: the end of the opening.
  case arrived

  static func < (lhs: StoryBeat, rhs: StoryBeat) -> Bool { lhs.rawValue < rhs.rawValue }

  var next: StoryBeat? { StoryBeat(rawValue: rawValue + 1) }
}
