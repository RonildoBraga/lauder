import SwiftUI

@main
struct LauderApp: App {
  @State private var world = GameWorld()

  var body: some Scene {
    WindowGroup {
      GameView(world: world)
    }
  }
}
