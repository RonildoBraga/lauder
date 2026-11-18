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
          Text(world.objective)
            .font(.subheadline)
          if world.session.carriesRegulator {
            // Derived from the mission phase: the part belongs to the party, not to a leader.
            Label("Carrying the regulator", systemImage: "shippingbox.fill")
              .font(.caption).foregroundStyle(Color(red: 0.62, green: 0.87, blue: 0.77))
          }
          HStack(spacing: 8) {
            ForEach(world.session.party, id: \.self) { member in
              Text(member.displayName)
                .font(.caption2)
                .fontWeight(member == world.session.leader ? .bold : .regular)
                .underline(member == world.session.leader)
            }
          }
          // During a conversation its panel carries the text and the Continue hint; the result
          // of the step appears here once the conversation ends.
          let talking = world.session.mode == .dialogue
          if !world.controls.touchControlsEnabled && !talking,
            let next = world.session.nextLeader
          {
            Text("\(world.controls.switchButtonName) · Lead as \(next.displayName)")
              .font(.caption)
          }
          if !talking {
            Text(world.observation).font(.caption)
            if let hint = world.hint {
              Text(hint).font(.caption).foregroundStyle(Color(red: 1, green: 0.84, blue: 0.6))
            }
          }
          if let diagnostic = world.diagnostic {
            Text(diagnostic).font(.caption).foregroundStyle(.orange)
          }
          if !world.controls.touchControlsEnabled {
            if !talking {
              Label(
                world.actionName ?? world.nearbyName.map { "Look at \($0)" } ?? "Look around",
                systemImage: world.controls.actionSymbol ?? "a.circle"
              )
              .font(.caption).foregroundStyle(Color(red: 0.66, green: 0.77, blue: 0.72))
            }
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

      if let line = world.session.currentLine {
        // Pause keeps the conversation at this line; Resume returns to it.
        VStack(alignment: .leading, spacing: 6) {
          Text(line.speaker).font(.headline)
          Text(line.text).fixedSize(horizontal: false, vertical: true)
          if !world.controls.touchControlsEnabled {
            Label("Continue", systemImage: world.controls.actionSymbol ?? "a.circle")
              .font(.caption).foregroundStyle(Color(red: 0.66, green: 0.77, blue: 0.72))
          }
        }
        .frame(maxWidth: 400, alignment: .leading)
        .padding(16)
        .foregroundStyle(Color(red: 0.91, green: 0.93, blue: 0.85))
        .background(
          Color(red: 0.075, green: 0.13, blue: 0.14), in: RoundedRectangle(cornerRadius: 14)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 20)
        .allowsHitTesting(false)
      }

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
        VStack(spacing: 14) {
          Text("Paused").font(.title2.bold())
          if world.controls.touchControlsEnabled {
            Text("Tap Resume to continue, or Restart to begin a new run.")
          } else {
            // The minimal pause menu: it opens on Resume; up or down chooses, action confirms.
            VStack(spacing: 6) {
              ForEach(GameSession.PauseChoice.allCases, id: \.self) { choice in
                let chosen = choice == world.session.pauseChoice
                Text(choice == .resume ? "Resume" : "Restart")
                  .font(.headline)
                  .frame(width: 180, height: 36)
                  .background(
                    chosen ? Color(red: 0.2, green: 0.33, blue: 0.33) : .clear,
                    in: RoundedRectangle(cornerRadius: 8)
                  )
                  .overlay(
                    RoundedRectangle(cornerRadius: 8)
                      .stroke(chosen ? Color(red: 0.62, green: 0.87, blue: 0.77) : .clear)
                  )
              }
            }
            Text(world.level.restartNote).font(.caption)
            HStack(spacing: 12) {
              Text("Up or down to choose").font(.caption)
              Label("Confirm", systemImage: world.controls.actionSymbol ?? "a.circle")
                .font(.caption)
              Text("\(world.controls.pauseButtonName) · Resume").font(.caption)
            }
            .foregroundStyle(Color(red: 0.66, green: 0.77, blue: 0.72))
          }
          if world.controls.needsNeutralInput {
            Text(releaseGuidance).font(.caption)
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
          actionTitle: touchActionTitle,
          nextLeaderName: world.session.nextLeader?.displayName,
          mode: world.session.mode)
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

  /// The touch action button: Restart in the pause menu, Continue in a conversation, otherwise
  /// the leader's action here or Look.
  private var touchActionTitle: String {
    switch world.session.mode {
    case .paused: "Restart"
    case .dialogue: "Continue"
    case .exploring: world.actionName ?? "Look"
    }
  }

  private var releaseGuidance: String {
    world.controls.touchControlsEnabled
      ? "Lift your fingers and release all keys to continue."
      : "Centre the stick and release all buttons and keys to continue."
  }
}
