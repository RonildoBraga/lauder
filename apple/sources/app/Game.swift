import Foundation
import Observation

/// The app owns one bridge world. Restart resets its existing session and scene.
@MainActor
@Observable
final class Game {
  let world: GameWorld

  init() {
    #if DEBUG
      // A scripted Simulator playtest, requested with `-LauderPlaytest <scenario>`, plays the
      // level its route was written for (PlaytestRunner.level(for:)).
      let scenario = UserDefaults.standard.string(forKey: "LauderPlaytest")
      world = GameWorld(level: PlaytestRunner.level(for: scenario))
      if let scenario { world.startPlaytest(scenario) }
    #else
      world = GameWorld(level: BrooklynBridge.level)
    #endif
  }
}
