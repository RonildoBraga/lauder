/// The result of a contextual gameplay action, independent of session ownership or story rules.
enum ActionResult: Equatable, Sendable {
  /// Accepted: progress changed.
  case done
  /// The action already succeeded; repeating it changes nothing.
  case alreadyDone
  /// The story has not reached this action yet.
  case notYet
  /// The current mode, encounter or required scene prevents the action.
  case unavailable
}
