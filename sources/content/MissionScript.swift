/// The conversations: short, ordered and speaker-labelled. Most are Party C's mission at Relay
/// House, with what its HUD says in each phase; `metTom` is the bridge's exchange after the
/// ambush (ADR 0004, M3).
///
/// The lines are provisional. Most come from the gameplay walkthrough; the keeper's lines, Miki's
/// inspection and the meeting plan were added to connect them. The maintainer finalises the
/// dialogue once the underlying relationships are decided. Until then the walkthrough's
/// water-tap exchange, which awaits review, and its meal coda stay out of the game.
enum MissionScript {
  struct Line: Equatable, Sendable {
    let speaker: String
    let text: String
  }

  enum Conversation: String, CaseIterable, Sendable {
    case briefing, inspection, repair, call, plan
    /// On the bridge, after Tom's shot. When it ends, Tom joins.
    case metTom
  }

  static let opening = "Relay House can hear the coastal operator but cannot answer."
  static let missingPart =
    "The transmitter needs a compatible regulator first. The depot may have one."

  static func lines(_ conversation: Conversation) -> [Line] {
    switch conversation {
    case .briefing:
      [
        Line(
          speaker: "Keeper",
          text: "East Span is closed. The dry detour is longer than your water will last."),
        Line(speaker: "Keeper", text: "We can hear the coastal operator, but we can't answer."),
        Line(speaker: "Miki", text: "The receiver works. The regulator cuts out when we transmit."),
        Line(
          speaker: "Tom",
          text: "The depot used emergency sets like this. There may be one in a protected bay."),
        Line(speaker: "Laura", text: "Then we check the side access. We come back together."),
      ]
    case .inspection:
      [
        Line(
          speaker: "Miki",
          text: "This housing is disconnected, and its regulator matches the transmitter."),
        Line(
          speaker: "Miki",
          text: "The bypass beside it still carries water to the next block. That stays connected."),
      ]
    case .repair:
      [Line(speaker: "Miki", text: "Regulator fitted. It holds when we transmit.")]
    case .call:
      [
        Line(speaker: "Miki", text: "Relay House calling the coast. East Span is closed."),
        Line(
          speaker: "Coastal operator",
          text: "Then the canal path is your way. There's a water stop on it."),
        Line(
          speaker: "Coastal operator",
          text: "The crew can meet you at Old Lock tomorrow afternoon."),
        Line(speaker: "Laura", text: "We'll take the canal path. Keep the next check-in for us."),
        Line(speaker: "Tom", text: "I'll mark the closure for anyone coming after us."),
      ]
    case .plan:
      [
        Line(speaker: "Meeting plan", text: "Meet the water crew at Old Lock tomorrow afternoon."),
        Line(speaker: "Meeting plan", text: "Take the canal path and refill at the water stop."),
        Line(speaker: "Meeting plan", text: "If the route fails, call at the next radio check-in."),
      ]
    case .metTom:
      [
        Line(speaker: "Tom", text: "He was going for your back."),
        Line(speaker: "Miki", text: "I didn't see him. Thank you."),
        Line(speaker: "Tom", text: "Tom. You're crossing to Manhattan?"),
        Line(speaker: "Miki", text: "Miki. I am. Walk with me?"),
      ]
    }
  }

  /// The objective line, derived from the phase rather than stored.
  static func objective(_ phase: GameSession.Phase) -> String {
    switch phase {
    case .briefing: "Talk to the keeper at the transmitter."
    case .seekingRegulator: "Find a compatible regulator at the depot."
    case .carryingRegulator: "Return to Relay House."
    case .radioRepaired: "Call the coastal operator."
    case .meetingAgreed: "Transmitter restored. Meeting agreed at Old Lock."
    }
  }

  /// What a look around shows away from the landmarks.
  static func guidance(_ phase: GameSession.Phase, passageOpen: Bool) -> String {
    switch phase {
    case .briefing: "The keeper is waiting at the transmitter."
    case .seekingRegulator:
      passageOpen
        ? "The front entrance is blocked. The service passage is open."
        : RelayHouse.barrierHint
    case .carryingRegulator: "Take the regulator back to the transmitter."
    case .radioRepaired: "The transmitter is ready for the call."
    case .meetingAgreed: "The meeting at Old Lock is agreed. Anyone can read the plan again."
    }
  }
}
