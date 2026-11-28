#if DEBUG
  import Foundation
  import UIKit
  import simd

  /// Debug-only command drivers. No route changes health, poses, actions or enemy decisions.
  @MainActor
  final class PlaytestRunner {
    enum Route: Sendable { case attack, defence, recovery, focus }
    private nonisolated static let attack = Route.attack
    private nonisolated static let defence = Route.defence
    private nonisolated static let recovery = Route.recovery
    private nonisolated static let focus = Route.focus
    nonisolated static let scenarios: [(String, Route)] = [
      ("duel-attack", attack),
      ("duel-defence", defence),
      ("duel-recovery", recovery),
      ("duel-focus", focus),
    ]
    nonisolated static var scenarioNames: [String] { scenarios.map(\.0) }

    struct Metrics: Codable {
      let mean: Double
      let p99: Double
      let max: Double

      init(_ samples: [Double]) {
        let ordered = samples.sorted()
        mean = samples.isEmpty ? 0 : samples.reduce(0, +) / Double(samples.count)
        max = ordered.last ?? 0
        p99 =
          ordered.isEmpty ? 0 : ordered[min(ordered.count - 1, Int(Double(ordered.count) * 0.99))]
      }
    }

    struct Mark: Codable {
      let name: String
      let time: Float
    }

    struct Summary: Codable {
      let scenario: String
      let passed: Bool
      let seconds: Float
      let stepsCompleted: Int
      let steps: Int
      let frames: Int
      let failures: [String]
      let frameMilliseconds: Metrics
      let simulationMilliseconds: Metrics
      let outcome: String
      let heroHealth: Float
      let enemyHealth: Float
      let stamina: Float
      let heroHits: Int
      let blocks: Int
      let evasions: Int
      let retries: Int
      let focused: Bool
      let cameraPitch: Float
      let cameraOffset: [Float]
      let marks: [Mark]
    }

    let name: String
    let route: Route
    private(set) var summary: Summary?
    private(set) var frames = 0
    private(set) var seconds: Float = 0
    private var stage = 0
    private var stageSeconds: Float = 0
    private var completed = 0
    private var marks: [Mark] = []
    private var failures: [String] = []
    private var frameTimes: [Double] = []
    private var simulationTimes: [Double] = []
    private var frozenTime: Float = 0
    private var movementStart = SIMD2<Float>.zero
    private var retreating = false
    private var seenThreats: Set<String> = []
    private var folder: URL?
    private var orientation = "unknown"

    var isFinished: Bool { summary != nil }
    var status: String {
      "\(name) · \(completed)/\(steps)" + (isFinished ? (failures.isEmpty ? " PASS" : " FAIL") : "")
    }
    private var steps: Int {
      switch route {
      case .attack: 2
      case .defence: 2
      case .recovery: 4
      case .focus: 5
      }
    }

    init?(scenario: String, recording: Bool = false) {
      guard let route = Self.scenarios.first(where: { $0.0 == scenario })?.1 else { return nil }
      name = scenario
      self.route = route
      if recording {
        folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
          .appendingPathComponent("playtest/\(scenario)", isDirectory: true)
        if let folder {
          do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try
              "seconds,heroX,heroZ,enemyX,enemyZ,heroHealth,enemyHealth,stamina,mode,focused,heroYaw\n"
              .write(
                to: folder.appendingPathComponent("trace.csv"), atomically: true, encoding: .utf8)
            try "".write(
              to: folder.appendingPathComponent("marks.log"), atomically: true, encoding: .utf8)
          } catch {
            failures.append("Could not prepare playtest evidence: \(error.localizedDescription)")
          }
        }
      }
    }

    func input(world: GameWorld) -> InputRules.Raw {
      guard !isFinished else { return .init() }
      if frames < 3 { return .init() }
      switch route {
      case .attack: return attackInput(world)
      case .defence: return defenceInput(world)
      case .recovery: return recoveryInput(world)
      case .focus: return focusInput(world)
      }
    }

    private func stick(towards direction: SIMD2<Float>) -> SIMD2<Float> {
      Movement.stick(towards: direction, cameraOffset: WorldCamera.offset)
    }

    private func attackInput(_ world: GameWorld) -> InputRules.Raw {
      let simulation = world.simulation
      if simulation.outcome == .lost {
        fail("The attack route lost its only attempt", world: world)
        return .init()
      }
      if simulation.hitsLanded > 0, completed == 0 {
        completed = 1
        mark("native sword contact")
      }
      if simulation.outcome == .won {
        completed = 2
        mark("duel won")
        finish(world)
        return .init()
      }
      return combatInput(world)
    }

    private func combatInput(_ world: GameWorld) -> InputRules.Raw {
      let simulation = world.simulation
      let offset = simulation.enemy.position - simulation.hero.position
      let distance = simd_length(offset)
      var raw = InputRules.Raw()
      if simulation.hero.stamina < 35 { retreating = true }
      if simulation.hero.stamina >= 80 { retreating = false }
      if retreating, simulation.enemy.action?.phase != .active {
        raw.stick = stick(towards: -offset)
        return raw
      }
      if let action = simulation.enemy.action {
        if action.phase == .active || (action.phase == .windup && action.phaseProgress > 0.55) {
          raw.controllerGuard = true
          return raw
        }
        if action.phase == .recovery,
          action.duration - action.elapsed > 0.4,
          simulation.hero.action == nil, distance <= 2.1
        {
          raw.controllerAttack = frames.isMultiple(of: 2)
          return raw
        }
      }
      if distance > 1.8 {
        raw.stick = stick(towards: offset)
      }
      return raw
    }

    private func focusInput(_ world: GameWorld) -> InputRules.Raw {
      let simulation = world.simulation
      if simulation.outcome == .lost {
        fail("The focused route lost its only attempt", world: world)
        return .init()
      }
      if stage == 0 {
        frozenTime = simulation.elapsed
        advance()
        return .init(controllerFocus: true)
      }
      if stage == 1 {
        // A render frame may arrive before the next fixed simulation tick accepts the edge.
        if simulation.elapsed == frozenTime && stageSeconds < 0.1 { return .init() }
        guard simulation.isFocused else {
          fail("Fresh Focus did not acquire the enemy", world: world)
          return .init()
        }
        completed = 1
        movementStart = simulation.hero.position
        mark("enemy focused")
        advance()
      }
      if stage == 2 || stage == 3 {
        let towards = simulation.enemy.position - simulation.hero.position
        if stageSeconds < (stage == 2 ? 0.85 : 0.4) {
          let direction = stage == 2 ? -towards : SIMD2(-towards.y, towards.x)
          return .init(stick: stick(towards: direction))
        }
        let facing = Movement.facing(yaw: simulation.hero.yaw)
        guard simd_distance(movementStart, simulation.hero.position) > 0.35,
          simd_dot(facing, simd_normalize(towards)) > 0.98
        else {
          fail("Focused movement failed to travel while facing the enemy", world: world)
          return .init()
        }
        if stage == 2, simulation.hero.position.y < DuelArena.halfDepth - 0.5 {
          fail("Focused retreat did not reach the near boundary for the camera check", world: world)
          return .init()
        }
        completed += 1
        mark(stage == 2 ? "focused backpedal" : "focused strafe")
        movementStart = simulation.hero.position
        advance()
        return .init()
      }
      if simulation.hitsLanded > 0, completed == 3 {
        completed = 4
        mark("focused sword contact")
      }
      if simulation.outcome == .won {
        guard !simulation.isFocused else {
          fail("Defeated enemy retained Focus", world: world)
          return .init()
        }
        completed = 5
        mark("focused duel won and released")
        finish(world)
        return .init()
      }
      return combatInput(world)
    }

    private func defenceInput(_ world: GameWorld) -> InputRules.Raw {
      let simulation = world.simulation
      if simulation.hero.health < DuelSimulation.heroMaxHealth {
        fail("The defence route took health damage", world: world)
        return .init()
      }
      if simulation.blocks == 0 { return .init(controllerGuard: true) }
      if stage == 0 {
        completed = 1
        mark("directional shield block")
        advance()
      }
      if simulation.evasions > 0 {
        completed = 2
        mark("timed dodge contact")
        finish(world)
        return .init()
      }
      if let action = simulation.enemy.action, action.phase == .windup,
        action.phaseProgress >= 0.9, stage == 1
      {
        advance()
        return .init(
          stick: stick(towards: simulation.enemy.position - simulation.hero.position),
          controllerDodge: true)
      }
      return .init()
    }

    private func recoveryInput(_ world: GameWorld) -> InputRules.Raw {
      switch stage {
      case 0:
        guard world.simulation.elapsed > 0.6 else { return .init() }
        frozenTime = world.simulation.elapsed
        advance()
        return .init(keyboardPause: true)
      case 1:
        guard world.session.mode == .paused else {
          fail("Pause did not become authoritative", world: world)
          return .init()
        }
        if abs(world.simulation.elapsed - frozenTime) > 0.0001 {
          fail("Simulation advanced while paused", world: world)
          return .init()
        }
        if stageSeconds < 0.2 { return .init() }
        if stageSeconds < 0.6 {
          return .init(controllerAttack: true, controllerDodge: true, up: true)
        }
        completed = 1
        mark("paused inputs ignored")
        advance()
        return .init()
      case 2:
        guard stageSeconds > 0.2 else { return .init() }
        advance()
        return .init(keyboardPause: true)
      case 3:
        guard world.session.mode == .exploring, !world.controls.needsNeutralInput else {
          return .init()
        }
        if stageSeconds < 0.25 { return .init() }
        if world.simulation.hero.action != nil {
          fail("Paused attack or dodge replayed after Resume", world: world)
          return .init()
        }
        completed = 2
        movementStart = world.simulation.hero.position
        mark("released controls resume")
        advance()
        return .init()
      case 4:
        if stageSeconds < 0.3 { return .init(right: true) }
        guard simd_distance(movementStart, world.simulation.hero.position) > 0.4 else {
          fail("Fresh movement did not work after Resume", world: world)
          return .init()
        }
        completed = 3
        mark("fresh movement")
        advance()
        return .init(keyboardPause: true)
      case 5:
        guard stageSeconds > 0.2 else { return .init() }
        advance()
        return .init(arrowDown: true)
      case 6:
        guard stageSeconds > 0.1 else { return .init() }
        advance()
        return .init(keyboardAction: true)
      default:
        guard stageSeconds > 0.15 else { return .init() }
        guard world.retries == 1, world.simulation.hitsLanded == 0,
          world.simulation.hero.health == DuelSimulation.heroMaxHealth,
          world.simulation.enemy.health == DuelSimulation.enemyMaxHealth,
          world.simulation.hero.action == nil,
          simd_distance(world.simulation.hero.position, DuelArena.heroSpawn) < 0.001
        else {
          fail("Restart did not restore the real duel", world: world)
          return .init()
        }
        completed = 4
        mark("native menu Retry")
        finish(world)
        return .init()
      }
    }

    func record(world: GameWorld, deltaTime: Float, milliseconds: Double) {
      guard !isFinished, deltaTime.isFinite, deltaTime > 0 else { return }
      frames += 1
      seconds += min(deltaTime, 0.2)
      stageSeconds += min(deltaTime, 0.2)
      frameTimes.append(Double(deltaTime) * 1_000)
      simulationTimes.append(milliseconds)
      if let action = world.simulation.enemy.action, action.phase == .windup,
        action.phaseProgress > 0.2
      {
        let name = action.kind == .thrust ? "thrust wind-up" : "sweep wind-up"
        if seenThreats.insert(name).inserted { mark(name) }
      }
      if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
        orientation =
          switch scene.effectiveGeometry.interfaceOrientation {
          case .landscapeLeft: "landscapeLeft"
          case .landscapeRight: "landscapeRight"
          default: "unknown"
          }
      }
      if let folder {
        let hero = world.simulation.hero
        let enemy = world.simulation.enemy
        append(
          "\(seconds),\(hero.position.x),\(hero.position.y),\(enemy.position.x),\(enemy.position.y),"
            + "\(hero.health),\(enemy.health),\(hero.stamina),\(world.session.mode),"
            + "\(world.simulation.isFocused),\(hero.yaw)\n",
          to: folder.appendingPathComponent("trace.csv"))
      }
      if seconds > 90 { fail("Scenario exceeded its 90-second budget", world: world) }
    }

    private func advance() {
      stage += 1
      stageSeconds = 0
    }

    private func mark(_ name: String) {
      marks.append(Mark(name: name, time: seconds))
      if let folder {
        append(
          "\(seconds)\t\(orientation)\t\(name)\n", to: folder.appendingPathComponent("marks.log"))
      }
    }

    private func fail(_ reason: String, world: GameWorld) {
      failures.append(reason)
      finish(world)
    }

    private func finish(_ world: GameWorld) {
      guard !isFinished else { return }
      let simulation = world.simulation
      let outcome =
        switch simulation.outcome {
        case .fighting: "fighting"
        case .won: "won"
        case .lost: "lost"
        }
      summary = Summary(
        scenario: name, passed: failures.isEmpty && completed == steps,
        seconds: seconds, stepsCompleted: completed, steps: steps, frames: frames,
        failures: failures, frameMilliseconds: Metrics(frameTimes),
        simulationMilliseconds: Metrics(simulationTimes), outcome: outcome,
        heroHealth: simulation.hero.health, enemyHealth: simulation.enemy.health,
        stamina: simulation.hero.stamina, heroHits: simulation.hitsLanded,
        blocks: simulation.blocks, evasions: simulation.evasions, retries: world.retries,
        focused: simulation.isFocused,
        cameraPitch: WorldCamera.pitchDegrees,
        cameraOffset: [WorldCamera.offset.x, WorldCamera.offset.y, WorldCamera.offset.z],
        marks: marks)
      if let folder, let summary {
        do {
          let data = try JSONEncoder().encode(summary)
          try data.write(to: folder.appendingPathComponent("summary.json"), options: .atomic)
        } catch {
          // Keep the failure visible to the operator; the recorder will also time out without a summary.
          failures.append("Could not write final playtest evidence")
        }
      }
    }

    private func append(_ line: String, to path: URL) {
      guard let data = line.data(using: .utf8),
        let handle = try? FileHandle(forWritingTo: path)
      else { return }
      defer { try? handle.close() }
      _ = try? handle.seekToEnd()
      try? handle.write(contentsOf: data)
    }
  }
#endif
