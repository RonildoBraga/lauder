import SwiftUI
import UIKit

@main
struct LauderApp: App {
  @Environment(\.scenePhase) private var scenePhase
  @State private var game = Game()

  var body: some Scene {
    WindowGroup {
      GameView(world: game.world)
    }
    .onChange(of: scenePhase, initial: true) { _, phase in
      // The foreground game stays awake, Pause included; normal
      // idle locking resumes on leaving it.
      UIApplication.shared.isIdleTimerDisabled = phase == .active
    }
  }
}
