/// The conversations: short, ordered and speaker-labelled.
///
/// The lines are provisional. The maintainer finalises the dialogue once the underlying
/// relationships are decided.
enum MissionScript {
  struct Line: Equatable, Sendable {
    let speaker: String
    let text: String
  }

  enum Conversation: Sendable {
    /// At the Manhattan end, the three together: the end of the opening (M4).
    case arrival
  }

  static func lines(_ conversation: Conversation) -> [Line] {
    switch conversation {
    case .arrival:
      [
        Line(speaker: "Laura", text: "Manhattan."),
        Line(speaker: "Tom", text: "We made it across."),
        Line(speaker: "Miki", text: "Together. Let's keep going."),
      ]
    }
  }
}
