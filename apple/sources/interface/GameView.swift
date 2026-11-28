import GameController
import RealityKit
import SwiftUI

@MainActor
struct GameView: View {
  @Environment(\.scenePhase) private var scenePhase
  let world: GameWorld

  var body: some View {
    ZStack {
      Color(red: 0.08, green: 0.10, blue: 0.12).ignoresSafeArea()
      RealityView { [world] content in
        content.camera = .virtual
        content.add(world.root)
        world.attach(
          content.subscribe(to: SceneEvents.Update.self) { [weak world] event in
            world?.step(deltaTime: event.deltaTime)
          })
      }
      .realityViewCameraControls(.none)
      .ignoresSafeArea()

      VStack(spacing: 10) {
        topBar
        Spacer(minLength: 0)
        if !world.isPaused && world.run.outcome == .fighting {
          Text(world.observation)
            .font(.caption.weight(.medium))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frostedPanel()
            .frame(maxWidth: 300)
            .allowsHitTesting(false)
        }
      }
      .padding(16)

      if world.isPaused {
        Color.black.opacity(0.3).ignoresSafeArea().allowsHitTesting(false)
        pauseMenu
      } else if world.run.outcome != .fighting {
        outcomePanel
      }

      if world.controls.needsNeutralInput {
        Text("Release all controls to continue")
          .font(.caption.weight(.semibold))
          .padding(10)
          .frostedPanel()
          .frame(maxHeight: .infinity, alignment: .top)
          .padding(.top, 112)
          .allowsHitTesting(false)
      }

      if world.controls.touchControlsEnabled {
        // Never unmount on Pause: every captured finger must lift to clear the neutral gate.
        TouchControls(
          controls: world.controls, generation: world.controls.touchGeneration,
          mode: world.session.mode, isFocused: world.simulation.isFocused
        )
        .ignoresSafeArea()
      }
    }
    .handlesGameControllerEvents(matching: .gamepad)
    .onChange(of: scenePhase, initial: true) { _, phase in
      world.setActive(phase == .active)
    }
    .onDisappear { world.stop() }
  }

  private var topBar: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 14) {
          meter(
            "Health", value: world.simulation.hero.health,
            maximum: DuelSimulation.heroMaxHealth, tint: HUDStyle.threat)
          meter(
            "Stamina", value: world.simulation.hero.stamina,
            maximum: DuelSimulation.maxStamina, tint: HUDStyle.stamina)
        }
        if let enemy = world.run.enemy {
          meter(
            "Enemy", value: enemy.health,
            maximum: DuelSimulation.enemyMaxHealth, tint: HUDStyle.ink)
          Text(enemyIntent).font(.caption2.weight(.semibold))
        }
        Text(world.run.objective).font(.caption2.weight(.semibold))
      }
      .padding(10)
      .frostedPanel()
      .allowsHitTesting(false)
      Spacer(minLength: 0)
      VStack(alignment: .trailing, spacing: 6) {
        Text(world.controls.sourceName).font(.caption2)
        if world.controls.hasController {
          Button {
            if world.controls.touchControlsEnabled {
              world.controls.useController()
            } else {
              world.controls.useTouchControls()
            }
          } label: {
            Text(world.controls.touchControlsEnabled ? "Use controller" : "Use touch controls")
              .font(.caption2.weight(.medium))
              .padding(.horizontal, 12)
              .frame(minHeight: 44)
              .frostedPanel()
          }
          .buttonStyle(.plain)
        }
        if !world.controls.touchControlsEnabled {
          Text("\(world.controls.pauseButtonName) · Pause")
            .font(.caption2)
          Text(world.run.isFocused ? "Enemy focused" : "\(world.controls.focusButtonName) · Focus")
            .font(.caption2)
        }
      }
      .padding(8)
      .frostedPanel()
      // The native touch Pause/Restart targets own the far-right column.
      .padding(.trailing, world.controls.touchControlsEnabled ? 110 : 0)
    }
  }

  private func meter(_ name: String, value: Float, maximum: Float, tint: Color) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text("\(name) \(Int(max(0, value).rounded(.up)))")
        .font(.caption2.monospacedDigit())
      ProgressView(value: Double(min(1, max(0, value / maximum))))
        .tint(tint)
    }
    .frame(width: 108)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(name)
    .accessibilityValue("\(Int(max(0, value))) of \(Int(maximum))")
  }

  private var enemyIntent: String {
    guard let enemy = world.run.enemy else { return "Passage clear" }
    guard let action = enemy.action else {
      return "Watch the enemy's weapon"
    }
    let name = action.kind == .thrust ? "Thrust" : "Sweep"
    switch action.phase {
    case .windup: return "\(name) · preparing"
    case .active: return "\(name) · striking"
    case .recovery: return "Recovering · your opening"
    }
  }

  private var pauseMenu: some View {
    VStack(spacing: 10) {
      Text("Paused").font(.title3.bold())
      if world.controls.touchControlsEnabled {
        Text("Use Resume or Restart at the top right.").font(.caption)
      } else {
        ForEach(world.session.availablePauseChoices, id: \.self) { choice in
          Text(choice == .resume ? "Resume" : "Restart")
            .font(.headline)
            .frame(width: 190, height: 36)
            .background(
              world.session.pauseChoice == choice ? HUDStyle.ink.opacity(0.1) : .clear,
              in: RoundedRectangle(cornerRadius: 8))
        }
        Label("Confirm · Up/Down chooses", systemImage: world.controls.actionSymbol ?? "a.circle")
          .font(.caption)
      }
      Text("Release Guard to turn freely and regain stamina.")
        .font(.caption2)
      Text(
        "\(world.controls.attackButtonName) Attack · \(world.controls.guardButtonName) Guard\n"
          + "\(world.controls.dodgeButtonName) Dodge · \(world.controls.focusButtonName) Focus\n"
          + "Keyboard: WASD · F Attack · Q Guard · Space Dodge · Tab Focus"
      )
      .font(.caption2)
      .multilineTextAlignment(.center)
    }
    .padding(18)
    .frostedPanel(cornerRadius: 14)
    .allowsHitTesting(false)
  }

  private var outcomePanel: some View {
    VStack(spacing: 12) {
      Text(world.run.outcome == .won ? "Route cleared" : "Try another approach")
        .font(.title3.bold())
      Text(
        world.run.outcome == .won
          ? "You found the way through. Start again to try a different approach."
          : "Return to the checkpoint. An opened shortcut stays open."
      )
      .font(.caption)
      Button(world.run.outcome == .won ? "Run again" : "Return to checkpoint") {
        if world.run.outcome == .won { world.restart() } else { world.retry() }
      }
      .font(.headline)
      .buttonStyle(.borderedProminent)
      .tint(HUDStyle.ink)
      .frame(minHeight: 44)
      if !world.controls.touchControlsEnabled {
        Label("Retry", systemImage: world.controls.actionSymbol ?? "a.circle")
          .font(.caption)
      }
    }
    .padding(20)
    .frostedPanel(cornerRadius: 14)
  }
}
