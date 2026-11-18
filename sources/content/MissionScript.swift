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
    /// At mid-span, once Laura is on her feet (M4). When it ends, she joins.
    case metLaura
    /// At the Manhattan end, the three together: the end of the opening (M4).
    case arrival
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
    case .metLaura:
      [
        Line(speaker: "Laura", text: "Thank you. I couldn't get up."),
        Line(speaker: "Miki", text: "Can you walk?"),
        Line(speaker: "Laura", text: "Slowly. I'm Laura."),
        Line(speaker: "Miki", text: "Miki. That's Tom. Come with us."),
      ]
    case .arrival:
      [
        Line(speaker: "Laura", text: "Manhattan."),
        Line(speaker: "Tom", text: "We made it across."),
        Line(speaker: "Miki", text: "Together. Let's keep going."),
      ]
    }
  }
}
