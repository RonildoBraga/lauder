/// Plays an encounter's cues in time: who steps out, what is said, who starts to fight. It
/// advances only with the simulation, so Pause and conversations hold it (ADR 0004).
struct StoryDirector {
  private var cues: [(at: Float, cue: Level.Cue)] = []
  private var elapsed: Float = 0
  private var next = 0

  var isPlaying: Bool { next < cues.count }

  mutating func start(_ cues: [(at: Float, cue: Level.Cue)]) {
    self.cues = cues.sorted { $0.at < $1.at }
    elapsed = 0
    next = 0
  }

  mutating func stop() {
    cues = []
    elapsed = 0
    next = 0
  }

  /// The cues whose time has come in this step, in order.
  mutating func step(dt: Float) -> [Level.Cue] {
    guard isPlaying else { return [] }
    elapsed += dt
    var due: [Level.Cue] = []
    while next < cues.count, cues[next].at <= elapsed {
      due.append(cues[next].cue)
      next += 1
    }
    return due
  }
}
