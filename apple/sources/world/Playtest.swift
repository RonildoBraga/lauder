#if DEBUG
  import Foundation
  import UIKit
  import simd

  /// Native command routes through the actual dungeon; never inject damage, poses or progress.
  @MainActor
  final class PlaytestRunner {
    enum Route: Sendable { case journey, defence, recovery, focus }
    private nonisolated static let journey = Route.journey
    private nonisolated static let defence = Route.defence
    private nonisolated static let recovery = Route.recovery
    private nonisolated static let focus = Route.focus
    nonisolated static let scenarios: [(String, Route)] = [
      ("dungeon-journey", journey),
      ("dungeon-defence", defence),
      ("dungeon-recovery", recovery),
      ("dungeon-focus", focus),
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
      let cameraProjection: String
      let orthographicHeight: Float?
      let warningsShown: [String]
      let encountersCleared: [Int]
      let shortcutOpen: Bool
      let healingUsed: Bool
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
    private var waypoint = 0
    private var marks: [Mark] = []
    private var failures: [String] = []
    private var frameTimes: [Double] = []
    private var simulationTimes: [Double] = []
    private var frozenTime: Float = 0
    private var movementStart = SIMD2<Float>.zero
    private var retreating = false
    private var seenThreats: Set<String> = []
    private var seenWarnings: Set<String> = []
    private var folder: URL?
    private var orientation = "unknown"

    var isFinished: Bool { summary != nil }
    var status: String {
      "\(name) · \(completed)/\(steps)" + (isFinished ? (failures.isEmpty ? " PASS" : " FAIL") : "")
    }
    private var steps: Int {
      switch route {
      case .journey: 7
      case .defence: 3
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
              "seconds,heroX,heroZ,enemyX,enemyZ,heroHealth,enemyHealth,stamina,mode,focused,heroYaw,encounter,cleared,shortcut,healing\n"
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
      if world.run.outcome == .lost {
        fail("The route lost its only attempt", world: world)
        return .init()
      }
      switch route {
      case .journey: return journeyInput(world)
      case .defence: return defenceInput(world)
      case .recovery: return recoveryInput(world)
      case .focus: return focusInput(world)
      }
    }

    private func stick(towards direction: SIMD2<Float>) -> SIMD2<Float> {
      Movement.stick(towards: direction, cameraOffset: WorldCamera.offset)
    }

    private func walk(_ world: GameWorld, through path: [SIMD2<Float>]) -> InputRules.Raw? {
      while waypoint < path.count {
        let offset = path[waypoint] - world.run.hero.position
        if simd_length(offset) < 0.13 {
          waypoint += 1
        } else {
          return .init(stick: stick(towards: offset))
        }
      }
      return nil
    }

    private func enterFirstRoom(_ world: GameWorld) -> InputRules.Raw? {
      if world.run.activeEncounter == 0, simd_distance(world.run.hero.position, [0, 1.2]) < 0.13 {
        return nil
      }
      return walk(world, through: [[0, 7], [0, 5.2], [3.2, 5.2], [3.2, 1.2], [0, 1.2]]) ?? .init()
    }

    private func combatInput(_ world: GameWorld) -> InputRules.Raw {
      let simulation = world.simulation
      guard let enemy = world.run.enemy else { return .init() }
      let offset = enemy.position - world.run.hero.position
      let distance = simd_length(offset)
      if !world.run.isFocused {
        if !simulation.canFocusEnemy, let id = world.run.activeEncounter {
          // A retreat may leave local Focus range; walk back instead of retrying an invalid toggle.
          retreating = false
          return .init(
            stick: stick(towards: DungeonLayout.encounters[id].home - world.run.hero.position))
        }
        return .init(controllerFocus: frames.isMultiple(of: 2))
      }
      if simulation.hero.stamina < 35 { retreating = true }
      if simulation.hero.stamina >= 80 { retreating = false }
      if retreating, enemy.action?.phase != .active, let id = world.run.activeEncounter {
        let home = DungeonLayout.encounters[id].home
        // Recover stamina inside the room instead of fleeing beyond the encounter's leash.
        return simd_distance(world.run.hero.position, home) < 4
          ? .init(stick: stick(towards: -offset)) : .init()
      }
      if let action = enemy.action {
        if action.phase == .active || (action.phase == .windup && action.phaseProgress > 0.55) {
          return .init(controllerGuard: true)
        }
        if action.phase == .recovery, action.duration - action.elapsed > 0.4,
          simulation.hero.action == nil, distance <= 2.1
        {
          return .init(controllerAttack: frames.isMultiple(of: 2))
        }
      }
      return distance > 1.8 ? .init(stick: stick(towards: offset)) : .init()
    }

    private func journeyInput(_ world: GameWorld) -> InputRules.Raw {
      switch stage {
      case 0:
        if let input = enterFirstRoom(world) { return input }
        completed = 1
        mark("first room entered")
        advance()
      case 1:
        // A real native injury makes the optional recovery find meaningful; no injected health.
        if world.simulation.hitsTaken == 0 { return .init() }
        if !world.run.clearedEncounters.contains(0) { return combatInput(world) }
        guard world.run.outcome == .fighting else {
          fail("Clearing the first room ended exploration", world: world)
          return .init()
        }
        completed = 2
        mark("first room cleared")
        advance()
      case 2:
        if let input = walk(world, through: [[-4, -1.8], [-8.5, -1.8], [-8.5, 1]]) {
          return input
        }
        guard world.run.healingUsed else {
          fail("The useful recovery find did not heal a real injury", world: world)
          return .init()
        }
        completed = 3
        mark("healing alcove discovered")
        advance()
      case 3:
        if world.run.activeEncounter == nil {
          // Finish comfortably inside the activation area, beyond the waypoint tolerance.
          return walk(world, through: [[-8.5, -1.8], [-10.5, -1.8], [-11.8, -1.8]]) ?? .init()
        }
        completed = 4
        mark("second room entered")
        advance()
      case 4:
        if !world.run.clearedEncounters.contains(1) { return combatInput(world) }
        completed = 5
        mark("second room cleared")
        advance()
      case 5:
        if let input = walk(
          world,
          through: [
            [-11.8, -1.8], [-14.5, -1.8], [-14.5, 3.5], [-14.5, 7], [-3.2, 7], [0, 7], [0, 10.5],
          ])
        {
          return input
        }
        guard world.run.shortcutOpen else {
          fail("The far-side return did not open the shortcut", world: world)
          return .init()
        }
        completed = 6
        mark("shortcut returned to checkpoint")
        advance()
      default:
        if world.run.outcome != .won {
          return walk(
            world,
            through: [[0, 7], [-3.2, 7], [-14.5, 7], [-14.5, 3.5], [-14.5, -3], [-20.5, -3]])
            ?? .init()
        }
        guard world.run.clearedEncounters.count == 2, world.run.healingUsed, world.run.shortcutOpen
        else {
          fail("The exit did not retain the completed journey", world: world)
          return .init()
        }
        completed = 7
        mark("dungeon exit reached")
        finish(world)
      }
      return .init()
    }

    private func defenceInput(_ world: GameWorld) -> InputRules.Raw {
      if stage == 0 {
        if let input = enterFirstRoom(world) { return input }
        completed = 1
        mark("first room entered")
        advance()
      }
      if !world.run.isFocused { return .init(controllerFocus: frames.isMultiple(of: 2)) }
      guard world.run.hero.health == DuelSimulation.heroMaxHealth else {
        fail("The defence route took health damage", world: world)
        return .init()
      }
      if world.simulation.blocks == 0 { return .init(controllerGuard: true) }
      if stage == 1 {
        completed = 2
        mark("directional shield block")
        advance()
      }
      if world.simulation.evasions > 0 {
        completed = 3
        mark("timed dodge contact")
        finish(world)
      }
      if let action = world.run.enemy?.action, action.phase == .windup,
        action.phaseProgress >= 0.9, stage == 2
      {
        advance()
        return .init(
          stick: stick(towards: world.simulation.enemy.position - world.run.hero.position),
          controllerDodge: true)
      }
      return .init()
    }

    private func focusInput(_ world: GameWorld) -> InputRules.Raw {
      if stage == 0 {
        if let input = enterFirstRoom(world) { return input }
        movementStart = world.run.hero.position
        frozenTime = world.simulation.elapsed
        advance()
        return .init(controllerFocus: true)
      }
      if stage == 1 {
        if world.simulation.elapsed == frozenTime && stageSeconds < 0.1 { return .init() }
        guard world.run.isFocused else {
          fail("Fresh Focus did not acquire the active guard", world: world)
          return .init()
        }
        completed = 1
        mark("active guard focused")
        advance()
      }
      if stage == 2 || stage == 3 {
        let towards = world.simulation.enemy.position - world.run.hero.position
        if stageSeconds < (stage == 2 ? 0.32 : 0.22) {
          return .init(stick: stick(towards: stage == 2 ? -towards : SIMD2(-towards.y, towards.x)))
        }
        guard world.run.isFocused,
          simd_distance(movementStart, world.run.hero.position) > 0.35,
          simd_dot(Movement.facing(yaw: world.run.hero.yaw), simd_normalize(towards)) > 0.95
        else {
          fail("Focused movement did not travel while retaining enemy facing", world: world)
          return .init()
        }
        completed += 1
        mark(stage == 2 ? "focused backpedal" : "focused strafe")
        movementStart = world.run.hero.position
        advance()
        return .init()
      }
      if stage == 4 {
        if !world.run.clearedEncounters.contains(0) { return combatInput(world) }
        guard !world.run.isFocused, world.run.outcome == .fighting else {
          fail("The cleared room retained Focus or ended the journey", world: world)
          return .init()
        }
        completed = 4
        movementStart = world.run.hero.position
        mark("guard cleared and focus released")
        advance()
      }
      if stage == 5 {
        if world.run.hero.action != nil {
          movementStart = world.run.hero.position
          stageSeconds = 0
          return .init()
        }
        if stageSeconds < 0.35 {
          return .init(stick: stick(towards: [-4, 0] - world.run.hero.position))
        }
        guard simd_distance(movementStart, world.run.hero.position) > 0.4 else {
          fail("Exploration did not continue after the fight", world: world)
          return .init()
        }
        completed = 5
        mark("exploration continues")
        finish(world)
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
        guard world.isPaused, abs(world.simulation.elapsed - frozenTime) < 0.0001 else {
          fail("Pause did not freeze the run", world: world)
          return .init()
        }
        if stageSeconds < 0.2 { return .init() }
        if stageSeconds < 0.6 {
          return .init(controllerAttack: true, controllerDodge: true, up: true)
        }
        completed = 1
        mark("paused inputs ignored")
        advance()
      case 2:
        guard stageSeconds > 0.2 else { return .init() }
        advance()
        return .init(keyboardPause: true)
      case 3:
        guard !world.isPaused, !world.controls.needsNeutralInput, stageSeconds > 0.25 else {
          return .init()
        }
        guard world.run.hero.action == nil else {
          fail("Paused combat replayed after Resume", world: world)
          return .init()
        }
        completed = 2
        movementStart = world.run.hero.position
        mark("released controls resume")
        advance()
      case 4:
        if stageSeconds < 0.3 { return .init(stick: stick(towards: [0, -1])) }
        guard simd_distance(movementStart, world.run.hero.position) > 0.4 else {
          fail("Fresh movement failed after Resume", world: world)
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
        guard world.retries == 1, world.run.clearedEncounters.isEmpty,
          !world.run.shortcutOpen, !world.run.healingUsed,
          world.run.hero.health == DuelSimulation.heroMaxHealth,
          world.run.hero.action == nil,
          simd_distance(world.run.hero.position, DungeonLayout.heroSpawn) < 0.001
        else {
          fail("Restart did not restore the dungeon", world: world)
          return .init()
        }
        completed = 4
        mark("native menu restart")
        finish(world)
      }
      return .init()
    }

    func record(world: GameWorld, deltaTime: Float, milliseconds: Double) {
      guard !isFinished, deltaTime.isFinite, deltaTime > 0 else { return }
      frames += 1
      seconds += min(deltaTime, 0.2)
      stageSeconds += min(deltaTime, 0.2)
      frameTimes.append(Double(deltaTime) * 1_000)
      simulationTimes.append(milliseconds)
      if let action = world.run.enemy?.action, action.phase == .windup, action.phaseProgress > 0.2 {
        let name = action.kind == .thrust ? "thrust wind-up" : "sweep wind-up"
        if !world.isPaused, !world.controls.needsNeutralInput,
          world.root.findEntity(named: "duel.attack-warning")?.isEnabled == true
        {
          seenWarnings.insert(action.kind == .thrust ? "thrust" : "sweep")
        }
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
        let hero = world.run.hero
        let enemy = world.simulation.enemy
        append(
          "\(seconds),\(hero.position.x),\(hero.position.y),\(enemy.position.x),\(enemy.position.y),"
            + "\(hero.health),\(enemy.health),\(hero.stamina),\(world.session.mode),\(world.run.isFocused),\(hero.yaw),"
            + "\(world.run.activeEncounter ?? -1),\(world.run.clearedEncounters.count),\(world.run.shortcutOpen),\(world.run.healingUsed)\n",
          to: folder.appendingPathComponent("trace.csv"))
      }
      if seconds > 180 { fail("Scenario exceeded its 180-second budget", world: world) }
    }

    private func advance() {
      stage += 1
      stageSeconds = 0
      waypoint = 0
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
        switch world.run.outcome {
        case .fighting: "fighting"
        case .won: "won"
        case .lost: "lost"
        }
      summary = Summary(
        scenario: name, passed: failures.isEmpty && completed == steps,
        seconds: seconds, stepsCompleted: completed, steps: steps, frames: frames,
        failures: failures, frameMilliseconds: Metrics(frameTimes),
        simulationMilliseconds: Metrics(simulationTimes),
        outcome: outcome, heroHealth: world.run.hero.health, enemyHealth: simulation.enemy.health,
        stamina: world.run.hero.stamina, heroHits: simulation.hitsLanded, blocks: simulation.blocks,
        evasions: simulation.evasions, retries: world.retries, focused: world.run.isFocused,
        cameraPitch: WorldCamera.pitchDegrees,
        cameraOffset: [WorldCamera.offset.x, WorldCamera.offset.y, WorldCamera.offset.z],
        cameraProjection: WorldCamera.projectionKind,
        orthographicHeight: WorldCamera.orthographicHeight,
        warningsShown: seenWarnings.sorted(),
        encountersCleared: world.run.clearedEncounters.sorted(),
        shortcutOpen: world.run.shortcutOpen, healingUsed: world.run.healingUsed, marks: marks)
      if let folder, let summary {
        do {
          try JSONEncoder().encode(summary).write(
            to: folder.appendingPathComponent("summary.json"), options: .atomic)
        } catch { failures.append("Could not write final playtest evidence") }
      }
    }

    private func append(_ line: String, to path: URL) {
      guard let data = line.data(using: .utf8), let handle = try? FileHandle(forWritingTo: path)
      else { return }
      defer { try? handle.close() }
      _ = try? handle.seekToEnd()
      try? handle.write(contentsOf: data)
    }
  }
#endif
