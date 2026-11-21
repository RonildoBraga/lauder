/// The pause menu's third choice while the experiments last (ADR 0005, ADR 0006): it names the
/// next level in a cycle and starts a new run of it. From the bridge, or any other level, it
/// reads Combat test; in the combat yard, Salvage test; and in the salvage yard, Bridge.
enum LevelCycle {
  /// What the choice reads in `level`, what the pause menu says it does, and the level it
  /// starts.
  static func next(after level: Level) -> (name: String, note: String, level: Level) {
    switch level.id {
    case CombatYard.level.id:
      ("Salvage test", "Salvage test opens the salvage yard, outside the story.", SalvageYard.level)
    case SalvageYard.level.id:
      ("Bridge", "Bridge returns to a new run of the opening.", BrooklynBridge.level)
    default:
      ("Combat test", "Combat test opens the combat yard, outside the story.", CombatYard.level)
    }
  }
}
