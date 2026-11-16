import GameController
import RealityKit
import SwiftUI
import UIKit

@MainActor
struct GameView: View {
  @Environment(\.scenePhase) private var scenePhase
  let world: GameWorld

  var body: some View {
    ZStack(alignment: .top) {
      Color(red: 0.055, green: 0.09, blue: 0.09).ignoresSafeArea()
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
          Text("Explore the depot, then return.")
            .font(.subheadline)
          Text(world.observation).font(.caption)
          Label(
            world.nearbyName.map { "Look at \($0)" } ?? "Look around",
            systemImage: world.controls.actionSymbol ?? "a.circle"
          )
          .font(.caption).foregroundStyle(Color(red: 0.66, green: 0.77, blue: 0.72))
          Text(world.controls.sourceName).font(.caption2)
            .foregroundStyle(Color(red: 0.66, green: 0.77, blue: 0.72))
          if world.status == .ready && world.controls.status == .ready
            && world.controls.needsNeutralInput && !world.isPaused
          {
            Text("Centre the stick and release all buttons and keys to continue.")
              .font(.caption)
          }
          if case .loading = world.status {
            ProgressView("Loading…")
          } else if case .failed(let message) = world.status {
            Text(message).font(.caption).foregroundStyle(.red)
          }
        }
        .frame(maxWidth: 290, alignment: .leading)
        .padding(12)
        .foregroundStyle(Color(red: 0.91, green: 0.93, blue: 0.85))
        .background(
          Color(red: 0.075, green: 0.13, blue: 0.14), in: RoundedRectangle(cornerRadius: 12))
        Spacer()
        Text("\(world.controls.pauseButtonName) · Pause").font(.caption)
          .padding(12)
          .foregroundStyle(Color(red: 0.91, green: 0.93, blue: 0.85))
          .background(
            Color(red: 0.075, green: 0.13, blue: 0.14), in: RoundedRectangle(cornerRadius: 12))
      }
      .padding()

      if world.status == .ready && world.controls.status != .ready {
        Color.black.opacity(0.45).ignoresSafeArea()
        VStack(spacing: 12) {
          Text(world.controls.sourceName).font(.title2.bold())
        }
        .padding(28)
        .foregroundStyle(Color(red: 0.91, green: 0.93, blue: 0.85))
        .background(
          Color(red: 0.075, green: 0.13, blue: 0.14), in: RoundedRectangle(cornerRadius: 18)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if world.status == .ready && world.isPaused {
        Color.black.opacity(0.45).ignoresSafeArea()
        VStack(spacing: 16) {
          Text("Paused").font(.title2.bold())
          if world.controls.needsNeutralInput {
            Text("Centre the stick and release all buttons and keys to continue.")
          } else {
            Text("Press \(world.controls.pauseButtonName) to resume.")
          }
        }
        .padding(28)
        .foregroundStyle(Color(red: 0.91, green: 0.93, blue: 0.85))
        .background(
          Color(red: 0.075, green: 0.13, blue: 0.14), in: RoundedRectangle(cornerRadius: 18)
        )
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
