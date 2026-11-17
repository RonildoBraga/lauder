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
          content.subscribe(to: SceneEvents.Update.self) {
            [weak world] event in
            world?.step(deltaTime: event.deltaTime)
          }
        )
      }
      .realityViewCameraControls(.none)
      .ignoresSafeArea()

      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 5) {
          Text("\(world.session.leader.displayName) · \(world.session.leader.role)").font(.headline)
          Text("Party A · Explore the depot, then return.")
            .font(.subheadline)
          HStack(spacing: 8) {
            ForEach(PartyMember.allCases, id: \.self) { member in
              Text(member.displayName)
                .font(.caption2)
                .fontWeight(member == world.session.leader ? .bold : .regular)
                .underline(member == world.session.leader)
            }
          }
          if !world.controls.touchControlsEnabled {
            Text(
              "\(world.controls.switchButtonName) · Lead as \(world.session.leader.next.displayName)"
            )
            .font(.caption)
          }
          Text(world.observation).font(.caption)
          if let diagnostic = world.diagnostic {
            Text(diagnostic).font(.caption).foregroundStyle(.orange)
          }
          if !world.controls.touchControlsEnabled {
            Label(
              world.nearbyName.map { "Look at \($0)" } ?? "Look around",
              systemImage: world.controls.actionSymbol ?? "a.circle"
            )
            .font(.caption).foregroundStyle(Color(red: 0.66, green: 0.77, blue: 0.72))
            Text(world.controls.sourceName).font(.caption2)
              .foregroundStyle(Color(red: 0.66, green: 0.77, blue: 0.72))
          }
          if world.controls.status == .ready
            && world.controls.needsNeutralInput && !world.isPaused
          {
            Text(releaseGuidance)
              .font(.caption)
          }
        }
        .frame(maxWidth: 290, alignment: .leading)
        .padding(12)
        .foregroundStyle(Color(red: 0.91, green: 0.93, blue: 0.85))
        .background(
          Color(red: 0.075, green: 0.13, blue: 0.14), in: RoundedRectangle(cornerRadius: 12)
        )
        .allowsHitTesting(false)
        Spacer()
        VStack(alignment: .trailing, spacing: 12) {
          if world.controls.touchControlsEnabled {
            // The touch surface owns Pause/Resume in this top-right space.
            Color.clear.frame(width: 100, height: 44).allowsHitTesting(false)
          } else {
            Text("\(world.controls.pauseButtonName) · Pause").font(.caption)
              .padding(12)
              .foregroundStyle(Color(red: 0.91, green: 0.93, blue: 0.85))
              .background(
                Color(red: 0.075, green: 0.13, blue: 0.14),
                in: RoundedRectangle(cornerRadius: 12))
          }
          if world.controls.hasController {
            Button(world.controls.touchControlsEnabled ? "Use controller" : "Use touch controls") {
              if world.controls.touchControlsEnabled {
                world.controls.useController()
              } else {
                world.controls.useTouchControls()
              }
            }
            .font(.caption)
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.075, green: 0.13, blue: 0.14))
            .frame(minHeight: 44)
          }
        }
      }
      .padding()

      if world.controls.status != .ready {
        Color.black.opacity(0.45).ignoresSafeArea().allowsHitTesting(false)
        VStack(spacing: 12) {
          Text(world.controls.sourceName).font(.title2.bold())
        }
        .padding(28)
        .foregroundStyle(Color(red: 0.91, green: 0.93, blue: 0.85))
        .background(
          Color(red: 0.075, green: 0.13, blue: 0.14), in: RoundedRectangle(cornerRadius: 18)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
      } else if world.isPaused {
        Color.black.opacity(0.45).ignoresSafeArea().allowsHitTesting(false)
        VStack(spacing: 16) {
          Text("Paused").font(.title2.bold())
          if world.controls.needsNeutralInput {
            Text(releaseGuidance)
          } else if world.controls.touchControlsEnabled {
            Text("Tap Resume to continue.")
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
        .allowsHitTesting(false)
      }

      if world.controls.touchControlsEnabled {
        TouchControls(
          controls: world.controls, generation: world.controls.touchGeneration,
          nextLeaderName: world.session.leader.next.displayName,
          isPaused: world.isPaused)
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

  private var releaseGuidance: String {
    world.controls.touchControlsEnabled
      ? "Lift your fingers and release all keys to continue."
      : "Centre the stick and release all buttons and keys to continue."
  }
}
