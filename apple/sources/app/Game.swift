import Foundation
import Observation

/// The app owns one bridge world. Restart resets its existing session and scene.
@MainActor
@Observable
final class Game {
  let world: GameWorld

  init() {
    world = GameWorld(level: BrooklynBridge.level)
    #if DEBUG
      // A scripted Simulator playtest, requested with `-LauderPlaytest <scenario>`.
      if let scenario = UserDefaults.standard.string(forKey: "LauderPlaytest") {
        world.startPlaytest(scenario)
      }
    #endif
  }
}
