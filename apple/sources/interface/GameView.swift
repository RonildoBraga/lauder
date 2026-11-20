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
          if world.session.medicalKits > 0 {
            // The party's small shared inventory (ADR 0004, M3).
            Label(
              world.session.medicalKits == 1
                ? "Medical kit" : "Medical kits · \(world.session.medicalKits)",
              systemImage: "cross.case.fill"
            )
            .font(.caption).foregroundStyle(Color(red: 0.62, green: 0.87, blue: 0.77))
          }
          HStack(spacing: 8) {
            ForEach(world.session.party, id: \.self) { member in
              Text(member.displayName)
                .font(.caption2)
                .fontWeight(member == world.session.leader ? .bold : .regular)
                .underline(member == world.session.leader)
              if world.session.inEncounter, member == world.session.leader {
                // The placeholder hit rule: three hits, shown beside the name.
                Text(hitPips).font(.caption2).foregroundStyle(threatColour)
              }
            }
            if world.session.formationsAvailable {
              // The squad's formation and what it is doing (ADR 0003, phases S2 and S3), on the
              // party's own line so the panel grows no taller over the scene.
              Text("· \(world.session.formation.name) · \(world.session.squadState)")
                .font(.caption2)
            }
          }
          if world.showsWeapon {
            HStack(spacing: 8) {
              Text("Carbine · \(world.session.ammo)").font(.caption)
              if !world.controls.touchControlsEnabled {
                Text("\(world.controls.fireButtonName) · Fire").font(.caption)
                  .foregroundStyle(Color(red: 0.66, green: 0.77, blue: 0.72))
              }
            }
          }
          if let threat = world.threat {
            Text(threat).font(.caption.bold()).foregroundStyle(threatColour)
          }
          // During a conversation its panel carries the text and the Continue hint; the result
          // of the step appears here once the conversation ends.
          let talking = world.session.mode == .dialogue
          if !world.controls.touchControlsEnabled && !talking,
            let next = world.session.nextLeader
          {
            HStack(spacing: 8) {
              Text("\(world.controls.switchButtonName) · Lead as \(next.displayName)")
              if world.session.formationsAvailable {
                Text("\(world.controls.formationButtonName) · \(formationAction)")
              }
            }
            .font(.caption)
            if let left = world.session.leftCompanion, let right = world.session.rightCompanion {
              // The D-pad's or arrow keys' orders, with the companions in their fixed order.
              Text("◀ \(left.displayName) · \(right.displayName) ▶ · ▲ Both · ▼ Hold")
                .font(.caption)
            }
          }
          if !talking {
            Text(world.observation).font(.caption)
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

      if world.fade > 0 {
        // An encounter starting again after the last allowed hit.
        Color.black.opacity(Double(world.fade)).ignoresSafeArea().allowsHitTesting(false)
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
          showsFire: world.showsWeapon,
          showsFormation: world.session.formationsAvailable,
          formationTitle: formationAction,
          orderNames: orderNames,
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

  private var threatColour: Color { Color(red: 1, green: 0.45, blue: 0.38) }

  /// The formation button's job: after an order it calls everyone back (ADR 0003).
  private var formationAction: String {
    world.session.orders.isEmpty ? "Formation" : "Follow"
  }

  /// The companions the touch order menu offers on its left and right, once orders are offered.
  private var orderNames: (left: String, right: String)? {
    guard world.session.ordersAvailable, let left = world.session.leftCompanion,
      let right = world.session.rightCompanion
    else { return nil }
    return (left.displayName, right.displayName)
  }

  /// The leader's hits left in this encounter, then those taken.
  private var hitPips: String {
    let taken = min(world.session.hitsTaken, GameSession.hitsAllowed)
    return String(repeating: "●", count: GameSession.hitsAllowed - taken)
      + String(repeating: "○", count: taken)
  }

  private var releaseGuidance: String {
    world.controls.touchControlsEnabled
      ? "Lift your fingers and release all keys to continue."
      : "Centre the stick and release all buttons and keys to continue."
  }
}
