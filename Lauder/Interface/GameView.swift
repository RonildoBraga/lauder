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
            systemImage: world.controls.actionSymbol ?? "xmark.circle"
          )
          .font(.caption).foregroundStyle(.secondary)
          Text(world.controls.sourceName).font(.caption2).foregroundStyle(.secondary)
          if case .loading = world.status {
            ProgressView("Loading…")
          } else if case .failed(let message) = world.status {
            Text(message).font(.caption).foregroundStyle(.red)
          }
        }
        .frame(maxWidth: 330, alignment: .leading)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        Spacer()
        Text("Options · Pause").font(.caption)
          .padding(12)
          .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
      }
      .padding()

      if world.status == .ready && world.controls.status != .ready {
        Color.black.opacity(0.45).ignoresSafeArea()
        VStack(spacing: 12) {
          Text("Connect your PS5 controller").font(.title2.bold())
          Text("Centre the stick and release the buttons to continue.")
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if world.isPaused {
        Color.black.opacity(0.45).ignoresSafeArea()
        VStack(spacing: 16) {
          Text("Paused").font(.title2.bold())
          Text("Press Options to resume.")
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
