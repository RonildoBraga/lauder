#if DEBUG
  import Foundation
  import simd

  /// Scripted playtests for the Simulator, run by `apple/scripts/playtest` (Debug builds only).
  ///
  /// A scenario drives the leader through the normal input path, so the rendered game, the
  /// input rules and the real frame timing are all exercised. The runner records every
  /// simulated frame and writes a trace and a summary into the app's Documents/playtest folder.
  struct PlaytestRunner {
    enum Step {
      case walk(SIMD2<Float>)
      case wait(seconds: Float)
      case mark(String)
      case act
      case talk
      case pause
      case menu(Int)
      case expectRestarted
      case expectTriggers(Int)
      case fire(seconds: Float)
      case expectBeat(StoryBeat)
      case expectDefeated(Int)
      case expectHits(Int)
      case expectParty([PartyMember])
      case formation
      case expectFormation(GameSession.Formation)
      case order(GameSession.Command)
      case touchOrder(GameSession.Command, at: SIMD2<Float>)
      case switchLeader
      case expectOrder(PartyMember, String)
      case awaitConversation(seconds: Float)
      case expectNear(PartyMember, SIMD2<Float>, within: Float)
      case expectApart(PartyMember, atLeast: Float)
      case expectRefused(Int)
      /// Observe the real simulation state, bounded so a broken guard fails the route.
      case waitForRobotPhase(RobotGuard.Phase, seconds: Float)
      case expectRobotShots(atLeast: Int)
      /// A press of the right stick, which locks the aim on a hostile (ADR 0020).
      case lock
      /// Whether a lock holds.
      case expectLock(Bool)
      /// A press of the weapon switch: the leader's other weapon (ADR 0021).
      case swap
    }

    /// What the runner can see of the game each frame.
    struct Snapshot {
      let level: Level
      let leader: PartyMember
      let party: [PartyMember]
      let positions: [PartyMember: SIMD2<Float>]
      let mode: GameSession.Mode
      let firedTriggers: Int
      let beat: StoryBeat
      let hitsTaken: Int
      let defeated: Int
      let formation: GameSession.Formation
      let orders: [PartyMember: GameSession.Order]
      let refusedOrders: Int
      /// The camera as it is now, for a screen of `screenAspect`, to aim touch orders.
      let camera: CameraProjection
      /// Native weapon state, observed by headless Pause/reload regressions.
      let weapon: EncounterSimulation.WeaponStatus
      /// Observed first-tower guard state. Defaults preserve unrelated test fixtures.
      var robotPhase: RobotGuard.Phase? = nil
      var robotShots = 0
      /// Whether the aim is locked on a hostile (ADR 0020).
      var locked = false
    }

    struct Frame {
      let dt: Float
      let leader: PartyMember
      let positions: [PartyMember: SIMD2<Float>]
      let targets: [PartyMember: SIMD2<Float>]
      let warning: String?
      let simulationMilliseconds: Double
    }

    struct Summary: Codable, Sendable {
      struct Mark: Codable, Sendable {
        let name: String
        let seconds: Double
        var robotPhase: String? = nil
        var robotShots = 0
      }
      struct Timing: Codable, Sendable {
        let mean: Double
        let p99: Double
        let max: Double
      }
      let scenario: String
      /// The interface orientation, so stills cut from a portrait recording can be turned.
      let orientation: String
      let passed: Bool
      let failures: [String]
      let marks: [Mark]
      let startedAt: Double
      let seconds: Double
      let frames: Int
      let stepsCompleted: Int
      let steps: Int
      let frameMilliseconds: Timing
      let simulationMilliseconds: Timing
      let warningFrames: Int
      let overlapFraction: Double
      let withinSlotWhileMoving: Double
      let worstLeaderGap: Double
    }

    static let scenarioNames = scenarios.map(\.name)
    /// The screen's width over its height for touch orders: the baseline iPhone's, in landscape.
    /// The world finds the ground with the same shape, so any shape aims the same point.
    static let screenAspect: Float = 2.16
    static let walkTimeout: Float = 120
    /// How long each conversation line stays on screen before the next press.
    static let lineSeconds: Float = 0.6

    let name: String
    private let steps: [Step]
    private var index = 0
    private var stepTime: Float = 0
    private var elapsed: Float = 0
    /// Frames into the current step's press.
    private var pressFrame = 0
    private var presses = 0
    private var sincePress: Float = 0
    private var talking = false
    private var startedAt: Date?
    private var marks: [Summary.Mark] = []
    private var failures: [String] = []
    private var trace =
      "t,dt,leader,miki_x,miki_z,laura_x,laura_z,tom_x,tom_z,"
      + "miki_tx,miki_tz,laura_tx,laura_tz,tom_tx,tom_tz,warning\n"
    private var frameTimes: [Double] = []
    private var simulationTimes: [Double] = []
    private var warningFrames = 0
    private var overlapFrames = 0
    private var movingSamples = 0
    private var withinSlot = 0
    private var worstGap: Float = 0
    private var previousLeaderPosition: SIMD2<Float>?
    private(set) var summary: Summary?
    /// Set by the world from the window scene; recorded in the summary.
    var orientation = "unknown"

    init?(scenario: String) {
      guard let steps = Self.steps(for: scenario) else { return nil }
      name = scenario
      self.steps = steps
    }

    var isFinished: Bool { summary != nil }

    var status: String {
      if let summary {
        return summary.passed
          ? "Playtest \(name) passed."
          : "Playtest \(name) failed: \(summary.failures.count) issue(s)."
      }
      return "Playtest \(name): step \(min(index + 1, steps.count)) of \(steps.count)."
    }

    /// The raw input for this frame. The first half second is neutral, so the release gate
    /// clears exactly as it does for a player.
    mutating func input(_ snapshot: Snapshot) -> InputRules.Raw {
      guard summary == nil else { return InputRules.Raw() }
      if startedAt == nil { startedAt = Date() }
      guard elapsed >= 0.5 else { return InputRules.Raw() }
      let leader = snapshot.leader
      let positions = snapshot.positions
      let leaderPosition = positions[leader] ?? .zero
      while index < steps.count {
        switch steps[index] {
        case .walk(let target):
          if let raw = steer(towards: target, from: leaderPosition, in: snapshot) { return raw }
        case .wait(let seconds):
          guard stepTime < seconds else {
            advance()
            continue
          }
          return InputRules.Raw()
        case .mark(let label):
          marks.append(
            Summary.Mark(
              name: label, seconds: Double(elapsed),
              robotPhase: snapshot.robotPhase.map { String(describing: $0) },
              robotShots: snapshot.robotShots))
          announce(label)
          advance()
        case .act:
          return press(InputRules.Raw(controllerAction: true))
        case .lock:
          return press(InputRules.Raw(controllerLock: true))
        case .swap:
          return press(InputRules.Raw(controllerSwap: true))
        case .expectLock(let locked):
          expect(
            snapshot.locked == locked, locked ? "nothing was locked" : "the lock still held")
        case .formation:
          return press(InputRules.Raw(controllerFormation: true))
        case .expectFormation(let formation):
          expect(
            snapshot.formation == formation,
            "the formation was \(snapshot.formation.name) instead of \(formation.name)")
        case .order(let command):
          let dpad =
            switch command {
            case .bothGo: InputRules.Raw(dpadUp: true)
            case .hold: InputRules.Raw(dpadDown: true)
            case .leftGoes: InputRules.Raw(dpadLeft: true)
            case .rightGoes: InputRules.Raw(dpadRight: true)
            }
          return press(dpad)
        case .touchOrder(let command, let point):
          var touch: InputRules.Raw?
          if pressFrame == 0 {
            if let screen = snapshot.camera.screen(ofGround: point),
              (0...1).contains(screen.x), (0...1).contains(screen.y)
            {
              let pressed = InputRules.ScreenPoint(
                x: screen.x, y: screen.y, aspect: snapshot.camera.aspect)
              touch = InputRules.Raw(
                touchOrder: InputRules.TouchOrder(command: command, point: pressed))
            } else {
              failures.append(
                "\(Self.describe(point)) was off the screen at \(Self.seconds(elapsed))")
            }
          }
          return press(touch)
        case .switchLeader:
          return press(InputRules.Raw(controllerSwitch: true))
        case .expectOrder(let member, let word):
          let actual = snapshot.orders[member]?.word ?? "following"
          expect(actual == word, "\(member.displayName) was \(actual) instead of \(word)")
        case .expectNear(let member, let point, let distance):
          let position = positions[member] ?? [.nan, .nan]
          expect(
            simd_distance(position, point) <= distance,
            "\(member.displayName) was at \(Self.describe(position)), not within \(distance) m "
              + "of \(Self.describe(point)),")
        case .expectApart(let member, let distance):
          let position = positions[member] ?? [.nan, .nan]
          expect(
            simd_distance(position, leaderPosition) >= distance,
            "\(member.displayName) was within \(distance) m of the leader")
        case .expectRefused(let count):
          expect(
            snapshot.refusedOrders == count,
            "\(snapshot.refusedOrders) order(s) were refused instead of \(count)")
        case .awaitConversation(let seconds):
          if snapshot.mode == .dialogue {
            advance()
            continue
          }
          if stepTime > seconds {
            failures.append("no conversation began within \(Int(seconds)) s")
            advance()
            continue
          }
          return InputRules.Raw()
        case .waitForRobotPhase(let phase, let seconds):
          if snapshot.robotPhase == phase {
            advance()
            continue
          }
          if stepTime > seconds {
            failures.append(
              "guard phase was \(String(describing: snapshot.robotPhase)), not \(phase), "
                + "after \(Int(seconds)) s")
            advance()
            continue
          }
          return InputRules.Raw()
        case .expectRobotShots(let count):
          expect(
            snapshot.robotShots >= count,
            "the guard fired \(snapshot.robotShots) shot(s), fewer than \(count)")
        case .talk:
          if snapshot.mode == .dialogue { talking = true }
          if talking, snapshot.mode == .exploring {
            advance()
            continue
          }
          if stepTime > 60 {
            failures.append("a conversation did not finish within 60 s")
            advance()
            continue
          }
          if pressFrame == 1 {
            pressFrame = 0
            return InputRules.Raw()
          }
          // A press can land on the frame that resumes play after a conversation, which is not
          // simulated, so an unanswered press is repeated a few times before it counts as a
          // failure.
          if !talking, presses >= 3, sincePress >= Self.lineSeconds {
            failures.append(
              "the action at \(Self.describe(leaderPosition)) started no conversation")
            advance()
            continue
          }
          if presses == 0 || sincePress >= Self.lineSeconds {
            presses += 1
            sincePress = 0
            pressFrame = 1
            return InputRules.Raw(controllerAction: true)
          }
          return InputRules.Raw()
        case .pause:
          return press(InputRules.Raw(controllerPause: true))
        case .menu(let direction):
          // Down on the stick (negative y) moves the choice down the menu.
          return press(InputRules.Raw(stick: [0, direction > 0 ? -1 : 1]))
        case .expectRestarted:
          let start = snapshot.level
          if snapshot.leader != start.party[0] || snapshot.party != start.party
            || snapshot.firedTriggers != 0 || snapshot.beat != .crossing || snapshot.defeated != 0
            || snapshot.hitsTaken != 0
            || snapshot.mode != .exploring || snapshot.formation != .close
            || !snapshot.orders.isEmpty || snapshot.refusedOrders != 0

          {
            failures.append(
              "after Restart \(snapshot.leader.displayName) led a party of "
                + "\(snapshot.party.count) in \(snapshot.formation.name), the story was at "
                + "\(snapshot.beat) and \(snapshot.firedTriggers) trigger(s) had fired")
          }
          for (member, position) in positions
          where simd_distance(position, start.spawn(member)) > 0.3 {
            failures.append(
              "\(member.displayName) was at \(Self.describe(position)) after Restart")
          }
          advance()
        case .expectTriggers(let count):
          expect(
            snapshot.firedTriggers == count,
            "\(snapshot.firedTriggers) trigger(s) had fired instead of \(count)")
        case .fire(let seconds):
          guard stepTime < seconds else {
            advance()
            return InputRules.Raw()
          }
          return InputRules.Raw(controllerFire: true)
        case .expectBeat(let beat):
          expect(snapshot.beat == beat, "the story was at \(snapshot.beat) instead of \(beat)")
        case .expectDefeated(let count):
          expect(
            snapshot.defeated == count,
            "\(snapshot.defeated) hostile(s) were down instead of \(count)")
        case .expectParty(let members):
          expect(
            snapshot.party == members,
            "the party was " + snapshot.party.map(\.displayName).joined(separator: ", "))
        case .expectHits(let count):
          expect(
            snapshot.hitsTaken == count,
            "the leader had taken \(snapshot.hitsTaken) hit(s) instead of \(count)")
        }
      }
      finish()
      return InputRules.Raw()
    }

    /// Presses for one frame, then ends the step with a neutral frame; with nothing to press, it
    /// ends the step at once.
    private mutating func press(_ raw: InputRules.Raw?) -> InputRules.Raw {
      pressFrame += 1
      if pressFrame == 1, let raw { return raw }
      advance()
      return InputRules.Raw()
    }

    /// Records a failure, saying what was found and when, unless the expectation holds, then
    /// ends the step.
    /// Steer the leader towards `target`: this frame's input, or nil once they are there, a
    /// conversation has begun or the walk has timed out, when the step is over.
    private mutating func steer(
      towards target: SIMD2<Float>, from leader: SIMD2<Float>, in snapshot: Snapshot
    ) -> InputRules.Raw? {
      let offset = target - leader
      if simd_length(offset) < 0.2 || snapshot.mode == .dialogue {
        advance()
        return nil
      }
      if stepTime > Self.walkTimeout {
        failures.append("did not reach \(Self.describe(target)) within \(Int(Self.walkTimeout)) s")
        advance()
        return nil
      }
      return InputRules.Raw(
        stick: Movement.stick(towards: offset, cameraOffset: snapshot.level.cameraOffset))
    }

    private mutating func expect(_ holds: Bool, _ found: String) {
      if !holds { failures.append("\(found) at \(Self.seconds(elapsed))") }
      advance()
    }

    /// Record one rendered frame's elapsed time, before any simulation runs.
    mutating func tick(dt: Float) {
      guard summary == nil, startedAt != nil else { return }
      elapsed += dt
      stepTime += dt
      sincePress += dt
      frameTimes.append(Double(dt) * 1000)
    }

    /// Record the state after the party moved this frame.
    mutating func record(_ frame: Frame) {
      guard summary == nil, startedAt != nil else { return }
      simulationTimes.append(frame.simulationMilliseconds)
      if frame.warning != nil { warningFrames += 1 }
      let members = PartyMember.allCases
      var overlapping = false
      for (index, first) in members.enumerated() {
        for second in members.dropFirst(index + 1) {
          guard let a = frame.positions[first], let b = frame.positions[second] else { continue }
          if simd_distance(a, b) < 2 * PartyBody.radius { overlapping = true }
        }
      }
      if overlapping { overlapFrames += 1 }
      if let leader = frame.positions[frame.leader] {
        let speed =
          previousLeaderPosition.map { simd_distance($0, leader) / max(frame.dt, 0.0001) } ?? 0
        previousLeaderPosition = leader
        for member in members where member != frame.leader {
          guard let position = frame.positions[member] else { continue }
          worstGap = max(worstGap, simd_distance(position, leader))
          if speed > 1, let target = frame.targets[member] {
            movingSamples += 1
            if simd_distance(position, target) <= 0.6 { withinSlot += 1 }
          }
        }
      }
      var row = "\(Self.decimal(elapsed)),\(Self.decimal(frame.dt)),\(frame.leader.rawValue)"
      for member in members {
        let point = frame.positions[member]
        row += ",\(Self.decimal(point?.x)),\(Self.decimal(point?.y))"
      }
      for member in members {
        let point = frame.targets[member]
        row += ",\(Self.decimal(point?.x)),\(Self.decimal(point?.y))"
      }
      row += ",\(frame.warning == nil ? 0 : 1)\n"
      trace += row
    }

    private mutating func advance() {
      index += 1
      stepTime = 0
      pressFrame = 0
      presses = 0
      talking = false
    }

    /// Append the mark to marks.log as it happens, so `apple/scripts/playtest` can take a
    /// screenshot at that moment: "<seconds since 1970>\t<orientation>\t<name>".
    private func announce(_ label: String) {
      guard let folder = Self.folder(for: name) else { return }
      try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let file = folder.appendingPathComponent("marks.log")
      let line = "\(Date().timeIntervalSince1970)\t\(orientation)\t\(label)\n"
      guard let data = line.data(using: .utf8) else { return }
      if let handle = try? FileHandle(forWritingTo: file) {
        handle.seekToEndOfFile()
        handle.write(data)
        try? handle.close()
      } else {
        try? data.write(to: file)
      }
    }

    private static func folder(for scenario: String) -> URL? {
      FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
        .appendingPathComponent("playtest/\(scenario)", isDirectory: true)
    }

    private mutating func finish() {
      guard summary == nil else { return }
      let result = Summary(
        scenario: name, orientation: orientation,
        passed: failures.isEmpty && warningFrames == 0,
        failures: failures
          + (warningFrames > 0 ? ["a companion warning showed for \(warningFrames) frames"] : []),
        marks: marks, startedAt: startedAt?.timeIntervalSince1970 ?? 0,
        seconds: Double(elapsed), frames: simulationTimes.count, stepsCompleted: index,
        steps: steps.count, frameMilliseconds: Self.timing(frameTimes),
        simulationMilliseconds: Self.timing(simulationTimes),
        warningFrames: warningFrames,
        overlapFraction: Double(overlapFrames) / Double(max(1, simulationTimes.count)),
        withinSlotWhileMoving: Double(withinSlot) / Double(max(1, movingSamples)),
        worstLeaderGap: Double(worstGap))
      summary = result
      write(result)
    }

    private func write(_ result: Summary) {
      guard let folder = Self.folder(for: name) else { return }
      try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      try? trace.write(
        to: folder.appendingPathComponent("trace.csv"), atomically: true, encoding: .utf8)
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      if let data = try? encoder.encode(result) {
        try? data.write(to: folder.appendingPathComponent("summary.json"), options: .atomic)
      }
    }

    // MARK: - Scenarios

    /// Restart from the pause menu: Pause, down to Restart, confirm. The check comes before the
    /// companions step into formation round Miki again.
    private static let restartRun: [Step] = [
      .pause, .wait(seconds: 0.5), .menu(1), .wait(seconds: 0.3), .mark("restart chosen"),
      .wait(seconds: 0.6), .act, .expectRestarted, .mark("restarted"), .wait(seconds: 1),
    ]

    /// The three from Brooklyn to Manhattan, resolving the first guard and crossing both towers.
    /// Each trigger shows its line once a run, even walked into again, and Restart clears them.
    private static let bridgeWalk: [Step] =
      [
        .mark("start"), .walk([6.5, 66]), .mark("buried road"), .walk([6.5, 20]),
        .mark("first tower"), .walk([6.5, 10]), .expectBeat(.stranger),
        .fire(seconds: 4), .expectDefeated(1), .mark("guard disabled"), .walk([6.5, -12]),
        .mark("beyond the first tower"), .walk([6.5, -206.15]), .mark("mid-span"),
        .walk([-7, -456.3]), .mark("second tower"), .walk([-7, -502.3]), .mark("Manhattan end"),
        .talk, .expectBeat(.arrived), .expectTriggers(5), .walk([-7, -494.3]),
        .walk([-7, -502.3]), .expectTriggers(5), .wait(seconds: 0.5),
      ] + restartRun + [.expectTriggers(0)]

    /// Through the east arch into the guard's acquisition range. The stable stranger beat is
    /// retained internally; the visible hostile and feedback are the C robot.
    private static let toTheStranger: [Step] = [
      .mark("start"), .walk([6.5, 66]), .walk([6.5, 10]), .mark("guard noticed"),
      .expectBeat(.stranger),
    ]

    /// Observe patrol from the covered west arch, then approach through the east arch and
    /// let a warned burst/recovery play before returning fire. Captures show actual motion and
    /// shooting, rather than killing the robot before its pattern can be seen.
    private static let firstFight: [Step] =
      [
        .mark("start"), .walk([6.5, 66]), .walk([-6.5, 30]), .walk([-6.5, 15]),
        .expectBeat(.stranger), .waitForRobotPhase(.patrol, seconds: 3),
        .wait(seconds: 1.8), .mark("guard patrol"),
        .walk([-6.5, 30]), .walk([6.5, 30]), .walk([6.5, 10]),
        .waitForRobotPhase(.tracking, seconds: 30), .mark("guard tracking"),
        .waitForRobotPhase(.committed, seconds: 3), .mark("guard committed"),
        .waitForRobotPhase(.burst, seconds: 2), .mark("guard burst"),
        .waitForRobotPhase(.recovering, seconds: 2), .expectRobotShots(atLeast: 3),
        .mark("guard recovery"),
        .fire(seconds: 4), .expectDefeated(1), .mark("guard disabled"), .expectHits(0),
        .wait(seconds: 1),
      ] + restartRun

    /// Standing in the open takes at most one hit per burst. The third starts the encounter
    /// again at its checkpoint with inventory restored; the second attempt returns fire.
    private static let fightRetry: [Step] =
      toTheStranger + [
        .wait(seconds: 20), .expectBeat(.crossing), .expectHits(0), .expectDefeated(0),
        .mark("retry"),
        .walk([6.5, 10]), .expectBeat(.stranger), .fire(seconds: 4),
        .expectDefeated(1), .mark("won after the retry"),
      ]

    /// The lock (ADR 0020) in the first fight: a press of the right stick locks on the guard and
    /// rings it in red, Fire takes it with the stick at rest, and once it is down the lock lets
    /// go.
    private static let lockOn: [Step] =
      toTheStranger + [
        .wait(seconds: 0.5), .lock, .expectLock(true), .wait(seconds: 0.6),
        .mark("locked on the guard"), .fire(seconds: 4), .expectDefeated(1), .expectLock(false),
        .mark("guard down, lock let go"), .wait(seconds: 1),
      ] + restartRun

    /// Tom's two weapons in the first fight (ADR 0021): he raises his dome against the guard's
    /// bursts and nobody is hurt, then switches to the minigun and brings the guard down.
    private static let weapons: [Step] =
      toTheStranger + [
        .switchLeader, .swap, .wait(seconds: 0.3), .fire(seconds: 2.5), .mark("Tom's dome"),
        .fire(seconds: 2), .expectHits(0), .swap, .wait(seconds: 0.3), .fire(seconds: 5),
        .expectDefeated(1), .mark("guard down to the minigun"), .wait(seconds: 1),
      ] + restartRun

    /// From the start through the first-tower guard's fight, then on beyond mid-span towards
    /// the second tower.
    private static let pastTheGuard: [Step] =
      toTheStranger + [
        .fire(seconds: 4), .expectDefeated(1), .mark("guard disabled"), .walk([6.5, -12]),
        .walk([6.5, -206.15]), .walk([-7, -240]), .mark("beyond mid-span"),
      ]

    /// The whole opening: the three from the Brooklyn end to the Manhattan end, through the
    /// guard's fight, then the closing exchange, then a Restart that starts them together again.
    private static let opening: [Step] =
      pastTheGuard + [
        .walk([-7, -456.3]), .mark("second tower"), .walk([-7, -502.3]), .talk,
        .expectBeat(.arrived), .mark("Manhattan, together"), .expectTriggers(5),
        .wait(seconds: 0.5),
      ] + restartRun + [.expectParty([.miki, .tom, .laura]), .expectTriggers(0)]

    /// Formations (M5): beyond mid-span, the formation button cycles Close, Spread and Column on
    /// the open snow. Spread keeps its width through the second tower's west arch, which is wide
    /// enough for it; the closing exchange keeps the formation, and Restart returns to Close.
    private static let formations: [Step] =
      pastTheGuard + [
        .expectFormation(.close), .formation, .expectFormation(.spread), .walk([-7, -250]),
        .mark("spread"), .walk([-7, -275]), .formation, .expectFormation(.column),
        .walk([-7, -295]), .mark("column"), .walk([-7, -300]), .formation,
        .expectFormation(.close), .walk([-7, -315]), .mark("close"), .walk([-7, -320]),
        .formation, .expectFormation(.spread), .walk([-7, -456.3]),
        .mark("second tower in spread"), .walk([-7, -472]), .mark("in the arch in spread"),
        .walk([-7, -502.3]), .talk, .expectBeat(.arrived), .expectFormation(.spread),
        .mark("Manhattan, together"), .wait(seconds: 0.5),
      ] + restartRun + [.expectFormation(.close)]

    /// Squad orders (ADR 0003, phase S3), beyond mid-span. The D-pad sends both companions
    /// ahead, and they hold there while Miki walks off until Formation calls them back. Then one
    /// companion goes while the other follows, the other goes beside the first, and Hold keeps
    /// both where they stand. A switch leaves the previous leader holding with them. Touch
    /// orders send both to a marked spot and refuse one aimed off the buried road, and the end of
    /// the opening waits for companions left holding until they are called back.
    private static let orders: [Step] =
      pastTheGuard + [
        .walk([-7, -270]), .wait(seconds: 1), .mark("ready"), .order(.bothGo),
        .expectOrder(.tom, "going"), .expectOrder(.laura, "going"), .wait(seconds: 0.5),
        .mark("both going"), .wait(seconds: 3.5), .expectOrder(.tom, "holding"),
        .expectOrder(.laura, "holding"), .expectNear(.tom, [-7, -276], within: 1),
        .expectNear(.laura, [-7, -276], within: 1), .mark("both holding ahead"),
        .walk([-7, -263]), .expectNear(.tom, [-7, -276], within: 1),
        .mark("they hold as Miki walks off"), .wait(seconds: 0.6), .formation,
        .expectOrder(.tom, "following"),
        .expectOrder(.laura, "following"), .expectFormation(.close), .wait(seconds: 4),
        .mark("called back"), .walk([-7, -270]), .wait(seconds: 1), .order(.rightGoes),
        .expectOrder(.tom, "going"), .expectOrder(.laura, "following"), .wait(seconds: 3.5),
        .expectOrder(.tom, "holding"), .mark("Tom holds, Laura follows"), .wait(seconds: 0.6),
        .order(.leftGoes),
        .wait(seconds: 3.5), .expectOrder(.laura, "holding"),
        .expectNear(.laura, [-8, -276], within: 0.6), .mark("Laura beside Tom"),
        .wait(seconds: 0.6), .formation,
        .wait(seconds: 3), .order(.hold), .expectOrder(.tom, "holding"),
        .expectOrder(.laura, "holding"), .walk([-7, -285]), .expectApart(.tom, atLeast: 8),
        .expectApart(.laura, atLeast: 8), .mark("both hold where they stood"), .wait(seconds: 0.6),
        .switchLeader,
        .expectOrder(.miki, "holding"), .expectOrder(.laura, "holding"), .wait(seconds: 0.5),
        .mark("Tom leads, Miki holds"), .wait(seconds: 0.6), .formation, .walk([-7, -290]),
        .wait(seconds: 3),
        .touchOrder(.bothGo, at: [-9.5, -297]), .wait(seconds: 0.5), .mark("touch: both go"),
        .wait(seconds: 4), .expectNear(.miki, [-9.5, -297], within: 1.2),
        .expectNear(.laura, [-9.5, -297], within: 1.2), .touchOrder(.leftGoes, at: [-16, -296]),
        .expectRefused(1), .mark("refused off the road"), .wait(seconds: 0.6), .formation,
        .walk([-7, -440]),
        .wait(seconds: 2), .order(.hold), .walk([-7, -502.3]), .wait(seconds: 2),
        .expectBeat(.stranger), .mark("waiting for the others"), .wait(seconds: 0.6), .formation,
        .awaitConversation(seconds: 45), .talk, .expectBeat(.arrived),
        .mark("Manhattan, together"), .wait(seconds: 0.5),
      ] + restartRun + [.expectParty([.miki, .tom, .laura])]

    /// Every bridge scenario, by the name `apple/scripts/playtest` gives it.
    private static let scenarios: [(name: String, steps: [Step])] = [
      ("bridge-walk", bridgeWalk), ("first-fight", firstFight), ("fight-retry", fightRetry),
      ("opening", opening), ("formations", formations), ("orders", orders), ("lock-on", lockOn),
      ("weapons", weapons),
    ]

    static func steps(for scenario: String) -> [Step]? {
      scenarios.first { $0.name == scenario }?.steps
    }

    // MARK: - Helpers

    private static func timing(_ values: [Double]) -> Summary.Timing {
      guard !values.isEmpty else { return Summary.Timing(mean: 0, p99: 0, max: 0) }
      let sorted = values.sorted()
      return Summary.Timing(
        mean: sorted.reduce(0, +) / Double(sorted.count),
        p99: sorted[Int(Double(sorted.count - 1) * 0.99)], max: sorted[sorted.count - 1])
    }

    private static func decimal(_ value: Float?) -> String {
      value.map { String(format: "%.4f", $0) } ?? ""
    }

    private static func describe(_ point: SIMD2<Float>) -> String {
      String(format: "(%.2f, %.2f)", point.x, point.y)
    }

    private static func seconds(_ value: Float) -> String {
      String(format: "%.1f s", value)
    }
  }
#endif
