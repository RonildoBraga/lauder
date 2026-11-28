import Foundation
import Observation

/// One stable prototype world; Retry resets its rules and keeps the same scene.
@MainActor
@Observable
final class Game {
  let world = GameWorld()

  init() {
    #if DEBUG
      if let scenario = UserDefaults.standard.string(forKey: "LauderPlaytest") {
        world.startPlaytest(scenario)
      }
    #endif
  }
}
