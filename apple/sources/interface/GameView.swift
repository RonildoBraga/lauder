import GameController
import RealityKit
import SwiftUI
import UIKit

@MainActor
struct GameView: View {
  @Environment(\.scenePhase) private var scenePhase
  let world: GameWorld

  var body: some View {
    let talking = world.session.mode == .dialogue
    ZStack(alignment: .top) {
      HUDStyle.snow.ignoresSafeArea()
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

      if let compass = world.compass, !world.isPaused {
        compassChip(compass)
      }

      HStack(alignment: .top) {
        if world.showsPanel {
          status(talking: talking)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 10) {
          if world.controls.touchControlsEnabled {
            // The touch surface owns Pause/Resume in this top-right space.
            Color.clear.frame(width: 100, height: 44).allowsHitTesting(false)
          } else {
            Text("\(world.controls.pauseButtonName) · Pause").font(.caption2)
              .padding(.horizontal, 10)
              .padding(.vertical, 6)
              .frostedPanel(cornerRadius: 8)
          }
          if world.controls.hasController {
            Button {
              if world.controls.touchControlsEnabled {
                world.controls.useController()
              } else {
                world.controls.useTouchControls()
              }
            } label: {
              Text(world.controls.touchControlsEnabled ? "Use controller" : "Use touch controls")
                .font(.caption)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .frostedPanel(cornerRadius: 22)
            }
            .buttonStyle(.plain)
          }
        }
      }
      .padding()

      if !world.controls.touchControlsEnabled && !talking && !world.isPaused
        && world.controls.status == .ready
      {
        hints
      }

      if let line = world.session.currentLine {
        // Pause keeps the conversation at this line; Resume returns to it.
        VStack(alignment: .leading, spacing: 6) {
          Text(line.speaker).font(.headline)
          Text(line.text).fixedSize(horizontal: false, vertical: true)
          if !world.controls.touchControlsEnabled {
            Label("Continue", systemImage: world.controls.actionSymbol ?? "a.circle")
              .font(.caption).foregroundStyle(HUDStyle.muted)
          }
        }
        .frame(maxWidth: 400, alignment: .leading)
        .padding(14)
        .frostedPanel(cornerRadius: 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 20)
        .allowsHitTesting(false)
      }

      if world.fade > 0 {
        // An encounter starting again after the last allowed hit.
        Color.black.opacity(Double(world.fade)).ignoresSafeArea().allowsHitTesting(false)
      }

      if world.controls.status != .ready {
        Color.black.opacity(0.35).ignoresSafeArea().allowsHitTesting(false)
        VStack(spacing: 12) {
          Text(world.controls.sourceName).font(.title2.bold())
        }
        .padding(28)
        .frostedPanel(cornerRadius: 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
      } else if world.isPaused {
        Color.black.opacity(0.35).ignoresSafeArea().allowsHitTesting(false)
        VStack(spacing: 14) {
          Text("Paused").font(.title2.bold())
          if world.controls.touchControlsEnabled {
            Text(
              "Tap Resume to continue, Restart to begin a new run, or \(world.otherLevel.name)."
            )
            Text(world.otherLevel.note).font(.caption)
          } else {
            // The minimal pause menu: it opens on Resume; up or down chooses, action confirms.
            VStack(spacing: 6) {
              ForEach(GameSession.PauseChoice.allCases, id: \.self) { choice in
                let chosen = choice == world.session.pauseChoice
                Text(pauseChoiceName(choice))
                  .font(.headline)
                  .frame(width: 180, height: 36)
                  .background(
                    chosen ? HUDStyle.ink.opacity(0.1) : .clear,
                    in: RoundedRectangle(cornerRadius: 8)
                  )
                  .overlay(
                    RoundedRectangle(cornerRadius: 8)
                      .stroke(chosen ? HUDStyle.ink.opacity(0.6) : .clear)
                  )
              }
            }
            Text(world.level.restartNote).font(.caption)
            Text(world.otherLevel.note).font(.caption)
            HStack(spacing: 12) {
              Text("Up or down to choose").font(.caption)
              Label("Confirm", systemImage: world.controls.actionSymbol ?? "a.circle")
                .font(.caption)
              Text("\(world.controls.pauseButtonName) · Resume").font(.caption)
            }
            .foregroundStyle(HUDStyle.muted)
          }
          if world.controls.needsNeutralInput {
            Text(releaseGuidance).font(.caption)
          }
          // Which build this is, as TestFlight lists it, so a tester knows what they play.
          Text("Lauder \(AppVersion.current)").font(.caption2).foregroundStyle(HUDStyle.muted)
        }
        .padding(28)
        .frostedPanel(cornerRadius: 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
      }

      if world.controls.touchControlsEnabled {
        TouchControls(
          controls: world.controls, generation: world.controls.touchGeneration,
          actionTitle: touchActionTitle,
          nextLeaderName: world.session.nextLeader?.displayName,
          showsFire: world.showsWeapon,
          showsSignature: world.showsSignature,
          showsFormation: world.session.formationsAvailable,
          formationTitle: formationAction,
          orderNames: orderNames,
          otherLevelTitle: world.otherLevel.name,
          mode: world.session.mode)
      }
    }
    .handlesGameControllerEvents(matching: .gamepad)
    // The app keeps the screen awake while the game is in the foreground; this world only
    // follows whether it is active.
    .onChange(of: scenePhase, initial: true) { _, phase in
      world.setApplicationActive(phase == .active)
    }
    .onDisappear {
      world.stop()
    }
  }

  /// What the pause menu calls each choice: the third names the level it starts.
  private func pauseChoiceName(_ choice: GameSession.PauseChoice) -> String {
    switch choice {
    case .resume: "Resume"
    case .restart: "Restart"
    case .otherLevel: world.otherLevel.name
    }
  }

  /// Where to go: an arrow turned towards the story's current goal, its name and how far away
  /// it is, in a small chip at the top centre, so the white plain still shows the way.
  private func compassChip(_ compass: GameWorld.Compass) -> some View {
    HStack(spacing: 6) {
      Image(systemName: "location.north.fill")
        .rotationEffect(.radians(Double(compass.angle)))
      Text("\(compass.name) · \(compass.metres) m")
    }
    .font(.footnote.weight(.semibold))
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .frostedPanel(cornerRadius: 14)
    .padding(.top)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Goal: \(compass.name), \(compass.metres) metres")
    .allowsHitTesting(false)
  }

  /// The status panel, small and with just the essentials: who leads, marked, and who follows,
  /// with the leader's hits during a fight, or everyone's in the combat yard, and the squad's
  /// formation. A new objective or line shows for a few seconds; a threat, the carbine's rounds,
  /// a warning or the release guidance only while they matter. The panel button hides it, and
  /// shows it again.
  private func status(talking: Bool) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack(spacing: 6) {
        ForEach(world.session.party, id: \.self) { member in
          let leading = member == world.session.leader
          Text(member.displayName)
            .fontWeight(leading ? .semibold : .regular)
            .underline(leading)
          if world.session.inEncounter, leading || world.showsEveryonesHits {
            // The placeholder hit rule: three hits, shown beside the name.
            Text(hitPips(of: member)).foregroundStyle(HUDStyle.threat)
          }
        }
        if world.session.formationsAvailable, !world.showsEveryonesHits {
          // The squad's formation and what it is doing (ADR 0003, phases S2 and S3).
          Text("· \(world.session.formation.name) · \(world.session.squadState)")
            .foregroundStyle(HUDStyle.muted)
        }
      }
      .font(.caption)
      if world.session.formationsAvailable, world.showsEveryonesHits {
        // With everyone's hits beside their names, the formation takes a line of its own.
        Text("\(world.session.formation.name) · \(world.session.squadState)")
          .font(.caption).foregroundStyle(HUDStyle.muted)
      }
      if world.objectiveIsFresh {
        Text(world.objective).font(.subheadline.weight(.semibold))
      }
      // During a conversation its panel carries the words; the result of the step appears here
      // once the conversation ends.
      if !talking && world.lineIsFresh {
        Text(world.observation).font(.caption)
      }
      if let threat = world.threat {
        Text(threat).font(.caption.bold()).foregroundStyle(HUDStyle.threat)
      }
      if let cue = world.signatureCue {
        // Who can answer the wind-up (ADR 0005).
        Text(cue).font(.caption.bold())
      }
      if world.showsWeapon {
        Text("Carbine · \(world.session.ammo)").font(.caption)
      }
      if world.level.salvage != nil, let bag = world.session.salvage.bag {
        // The shared bag (ADR 0006): what it holds, and a regulator known not to fit.
        Text("Bag · \(bag)").font(.caption)
      }
      if let diagnostic = world.diagnostic {
        Text(diagnostic).font(.caption).foregroundStyle(HUDStyle.warning)
      }
      if world.controls.status == .ready && world.controls.needsNeutralInput
        && !world.isPaused
      {
        Text(releaseGuidance).font(.caption)
      }
    }
    .frame(maxWidth: 220, alignment: .leading)
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .frostedPanel()
    .allowsHitTesting(false)
  }

  /// A controller's or keyboard's controls that apply now, in one small strip at the bottom
  /// left, out of the way of the scene. Touch shows its own buttons instead.
  private var hints: some View {
    let look = world.actionName ?? "Look around"
    var others: [String] = []
    if world.showsWeapon {
      others.append("\(world.controls.fireButtonName) · Fire")
    }
    if world.showsSignature {
      others.append("\(world.controls.signatureButtonName) · Disrupt")
    }
    if let next = world.session.nextLeader {
      others.append("\(world.controls.switchButtonName) · Lead as \(next.displayName)")
    }
    if let previous = world.session.previousLeader, previous != world.session.nextLeader {
      // With two in the party, Previous leads as the same member as Next.
      others.append("\(world.controls.previousButtonName) · Lead as \(previous.displayName)")
    }
    if world.session.formationsAvailable {
      others.append("\(world.controls.formationButtonName) · \(formationAction)")
    }
    others.append(
      "\(world.controls.panelButtonName) · \(world.panelHidden ? "Show" : "Hide") panel")
    if let left = world.session.leftCompanion, let right = world.session.rightCompanion {
      // The D-pad's or arrow keys' orders, with the companions in their fixed order.
      others.append("◀ \(left.displayName) · \(right.displayName) ▶ · ▲ Both · ▼ Hold")
    }
    let symbol = Image(systemName: world.controls.actionSymbol ?? "a.circle")
    let rest = others.map { "     \($0)" }.joined()
    return Text("\(symbol) \(look)\(rest)")
      .font(.caption2)
      .foregroundStyle(HUDStyle.muted)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .frostedPanel(cornerRadius: 8)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
      .padding()
      .allowsHitTesting(false)
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

  /// The formation button's job: in a fight where the level has combat positioning it regroups
  /// the companions, and otherwise after an order it calls everyone back (ADR 0003).
  private var formationAction: String {
    if world.session.formationPressRegroups { return "Regroup" }
    return world.session.orders.isEmpty ? "Formation" : "Follow"
  }

  /// The companions the touch order menu offers on its left and right, once orders are offered.
  private var orderNames: (left: String, right: String)? {
    guard world.session.ordersAvailable, let left = world.session.leftCompanion,
      let right = world.session.rightCompanion
    else { return nil }
    return (left.displayName, right.displayName)
  }

  /// A member's hits left in this encounter, then those taken.
  private func hitPips(of member: PartyMember) -> String {
    let taken = min(world.session.hits(of: member), GameSession.hitsAllowed)
    return String(repeating: "●", count: GameSession.hitsAllowed - taken)
      + String(repeating: "○", count: taken)
  }

  private var releaseGuidance: String {
    world.controls.touchControlsEnabled
      ? "Lift your fingers and release all keys to continue."
      : "Centre the stick and release all buttons and keys to continue."
  }
}
