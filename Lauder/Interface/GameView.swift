import GameController
import RealityKit
import SwiftUI
import UIKit

@MainActor
struct GameView: View {
  @Environment(\.scenePhase) private var scenePhase
  @State private var world = GameWorld()

  var body: some View {
    ZStack(alignment: .top) {
      Color.black.ignoresSafeArea()
      RealityView { [world] content in
        content.camera = .virtual
        content.add(world.root)
        world.attach(
          content.subscribe(to: PhysicsSimulationEvents.WillSimulate.self, on: world.root) {
            [weak world] event in
            world?.step(deltaTime: event.deltaTime)
          }
        )
        await world.load()
      }
      .realityViewCameraControls(.none)
      .ignoresSafeArea()

      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 5) {
          Text("Relay district").font(.headline)
          Text("Explore the depot and return to the shelter.")
            .font(.subheadline)
          Text(world.observation).font(.caption)
          Label(
            world.nearbyName.map { "Look at \($0)" } ?? "Look around",
            systemImage: world.controls.actionSymbol ?? "hand.tap"
          )
          .font(.caption).foregroundStyle(.secondary)
          Text(world.controls.sourceName).font(.caption2).foregroundStyle(.secondary)
          if case .loading = world.status {
            ProgressView("Loading…")
          } else if case .failed(let message) = world.status {
            Text(message).font(.caption).foregroundStyle(.red)
          }
          if case .failed(let message) = world.controls.status {
            Text(message).font(.caption).foregroundStyle(.red)
            Button("Retry controls") { world.controls.retry() }
          }
        }
        .frame(maxWidth: 330, alignment: .leading)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        Spacer()
        Button("Pause", systemImage: "pause.fill") { world.setPaused(true) }
          .buttonStyle(.borderedProminent)
      }
      .padding()

      if world.isPaused {
        Color.black.opacity(0.45).ignoresSafeArea()
        VStack(spacing: 16) {
          Text("Paused").font(.title2.bold())
          Button("Resume", systemImage: "play.fill") { world.setPaused(false) }
            .buttonStyle(.borderedProminent)
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .handlesGameControllerEvents(matching: .gamepad)
    .onChange(of: scenePhase, initial: true) { _, phase in
      world.setApplicationActive(phase == .active)
      UIApplication.shared.isIdleTimerDisabled = phase == .active
    }
    .onDisappear {
      world.stop()
      UIApplication.shared.isIdleTimerDisabled = false
    }
  }
}
