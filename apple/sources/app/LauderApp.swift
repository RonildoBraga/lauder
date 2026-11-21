import SwiftUI
import UIKit

@main
struct LauderApp: App {
  @Environment(\.scenePhase) private var scenePhase
  @State private var game = Game()

  var body: some Scene {
    WindowGroup {
      // Each level's world comes with a view and a scene of its own, so a new level makes them
      // afresh rather than reusing the old world's.
      GameView(world: game.world).id(ObjectIdentifier(game.world))
    }
    .onChange(of: scenePhase, initial: true) { _, phase in
      // The foreground game stays awake, Pause included, whichever level is in play; normal
      // idle locking resumes on leaving it.
      UIApplication.shared.isIdleTimerDisabled = phase == .active
    }
  }
}
