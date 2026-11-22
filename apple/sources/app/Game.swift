import Foundation
import Observation

/// What the app plays: the world of the level in play. While the combat experiment lasts (ADR
/// 0005), the pause menu's third choice replaces it with a new run of the other level in a world
/// of its own, the combat yard from the bridge and the bridge from the yard, since a launch
/// switch cannot reach the yard on a phone that installed the game from TestFlight.
@MainActor
@Observable
final class Game {
  private(set) var world: GameWorld
  @ObservationIgnored private let navigationCache: NavigationCache

  init(level: Level = BrooklynBridge.level) {
    let navigationCache = NavigationCache()
    self.navigationCache = navigationCache
    world = GameWorld(level: level, navigationCache: navigationCache)
    connect()
    #if DEBUG
      // A scripted Simulator playtest (`apple/scripts/playtest`), started by the launch
      // argument `-LauderPlaytest <scenario>`.
      if let scenario = UserDefaults.standard.string(forKey: "LauderPlaytest") {
        world.startPlaytest(scenario)
      }
    #endif
  }

  /// A new run of `level` in a new world. The old world stops; the player's choices there,
  /// and a scripted playtest, carry over.
  func play(_ level: Level) {
    let previous = world
    previous.stop()
    world = GameWorld(level: level, navigationCache: navigationCache)
    world.takePreferences(from: previous)
    #if DEBUG
      world.continuePlaytest(from: previous)
    #endif
    connect()
  }

  private func connect() {
    world.leave = { [weak self] level in self?.play(level) }
  }
}
