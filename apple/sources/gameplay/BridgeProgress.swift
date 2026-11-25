/// The bridge's progression: its story beats, in order. The session owns mode, encounters and
/// checkpoints. This value can be copied into a checkpoint without retaining a live session or
/// presentation state.
struct BridgeProgress: Sendable {
  private(set) var beat = StoryBeat.crossing

  var nextBeat: StoryBeat? { beat.next }

  @discardableResult
  mutating func begin(_ next: StoryBeat) -> Bool {
    guard next == nextBeat else { return false }
    beat = next
    return true
  }

  mutating func restart() {
    beat = .crossing
  }
}
