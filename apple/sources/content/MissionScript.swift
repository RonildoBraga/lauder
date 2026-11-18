/// The conversations: short, ordered and speaker-labelled.
///
/// The lines are provisional. The maintainer finalises the dialogue once the underlying
/// relationships are decided.
enum MissionScript {
  struct Line: Equatable, Sendable {
    let speaker: String
    let text: String
  }

  enum Conversation: String, CaseIterable, Sendable {
    /// On the bridge, after Tom's shot (ADR 0004, M3). When it ends, Tom joins.
    case metTom
  }

  static func lines(_ conversation: Conversation) -> [Line] {
    switch conversation {
    case .metTom:
      [
        Line(speaker: "Tom", text: "He was going for your back."),
        Line(speaker: "Miki", text: "I didn't see him. Thank you."),
        Line(speaker: "Tom", text: "Tom. You're crossing to Manhattan?"),
        Line(speaker: "Miki", text: "Miki. I am. Walk with me?"),
      ]
    }
  }
}
