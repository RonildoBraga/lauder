#if DEBUG
  /// Elapsed time in the world's initializer body, excluding stored-property initialisation
  /// and later view/renderer setup. A playtest keeps one record per world it visits; these
  /// Debug measurements do not establish phone performance.
  struct WorldLoadTiming: Codable, Sendable {
    struct Stage: Codable, Sendable {
      let name: String
      let milliseconds: Double
    }

    let level: String
    let totalMilliseconds: Double
    let stages: [Stage]

    init(
      level: String, total: Duration, navigation: Duration, fight: Duration, scene: Duration,
      party: Duration
    ) {
      self.level = level
      totalMilliseconds = Self.milliseconds(total)
      let measured = [
        Stage(name: "navigation", milliseconds: Self.milliseconds(navigation)),
        Stage(name: "fight", milliseconds: Self.milliseconds(fight)),
        Stage(name: "scene", milliseconds: Self.milliseconds(scene)),
        Stage(name: "party", milliseconds: Self.milliseconds(party)),
      ]
      stages =
        measured
        + [
          Stage(
            name: "remaining",
            milliseconds: max(0, totalMilliseconds - measured.reduce(0) { $0 + $1.milliseconds }))
        ]
    }

    private static func milliseconds(_ duration: Duration) -> Double {
      let parts = duration.components
      return Double(parts.seconds) * 1_000 + Double(parts.attoseconds) / 1_000_000_000_000_000
    }
  }
#endif
