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
      /// Steer the leader to a point; fails after two minutes, long enough to walk between the
      /// bridge's towers. A conversation that starts on the way, as at the end of the opening,
      /// ends the walk.
      case walk(SIMD2<Float>)
      case wait(seconds: Float)
      /// A named moment, for stills cut from the screen recording.
      case mark(String)
      /// Press the action for one frame. While paused it confirms the menu's choice.
      case act
      /// Press the action to start a conversation, then once per line until play resumes.
      case talk
      /// Press Pause for one frame.
      case pause
      /// Move the pause menu's choice: -1 up, 1 down.
      case menu(Int)
      /// Everyone back where a new run starts, with the level's starting party and no progress.
      case expectRestarted
      /// How many trigger areas have shown their line in this run.
      case expectTriggers(Int)
      /// Hold Fire, which draws the weapon and then shoots at the assisted target.
      case fire(seconds: Float)
      case expectBeat(GameSession.Beat)
      /// How many hostiles are down in this run.
      case expectDefeated(Int)
      /// How many hits the leader has taken in the current encounter.
      case expectHits(Int)
      /// Who travels together, in switching order.
      case expectParty([PartyMember])
      /// Press the formation button for one frame.
      case formation
      case expectFormation(GameSession.Formation)
      /// Press a D-pad direction for one frame: a squad order (ADR 0003, phase S3).
      case order(GameSession.Command)
      /// Give an order from the touch menu, pressing where this point of the ground shows.
      case touchOrder(GameSession.Command, at: SIMD2<Float>)
      /// Press R1 for one frame, to lead as the next member.
      case switchLeader
      /// A member's order: "following", "going" or "holding".
      case expectOrder(PartyMember, String)
      /// What the squad is doing, as the HUD says it, such as "following" or "regrouping".
      case expectSquad(String)
      /// Wait until the squad is doing this, as the HUD says it; fails after this many seconds.
      case awaitSquad(String, seconds: Float)
      /// A member stands within this distance of a point.
      case expectNear(PartyMember, SIMD2<Float>, within: Float)
      /// A member stands at least this far from the leader.
      case expectApart(PartyMember, atLeast: Float)
      /// How many orders were refused in this run, each with a brief cross.
      case expectRefused(Int)
      /// Wait until a conversation begins; fails after this many seconds.
      case awaitConversation(seconds: Float)
      /// The level in play, by its id, such as "combat-yard" after the pause menu's third choice.
      case expectLevel(String)
      /// Press Square for one frame: the leader's signature, such as Miki's Disrupt.
      case signature
      /// Wait until the HUD says Miki can Disrupt; fails after this many seconds.
      case awaitDisrupt(seconds: Float)
      /// How many wind-ups Disrupt has cancelled in this run.
      case expectDisrupts(Int)
      /// A member has fired by themselves as a companion in this run.
      case expectFired(PartyMember)
      /// Wait until the party has fallen back this many times in this run; fails after this
      /// many seconds.
      case awaitFallBacks(Int, seconds: Float)
      /// How many times the party has fallen back in this run.
      case expectFallBacks(Int)
      /// Hold Fire until this many hostiles are down in this run; fails after this many seconds.
      case fireUntilDefeated(Int, seconds: Float)
    }

    /// What the runner can see of the game each frame.
    struct Snapshot {
      /// The level in play, which the pause menu's third choice can change.
      let level: Level
      let leader: PartyMember
      let party: [PartyMember]
      let positions: [PartyMember: SIMD2<Float>]
      let mode: GameSession.Mode
      let firedTriggers: Int
      let beat: GameSession.Beat
      let hitsTaken: Int
      let defeated: Int
      let ammo: Int
      let formation: GameSession.Formation
      let orders: [PartyMember: GameSession.Order]
      /// What the squad is doing, as the HUD says it.
      let squadState: String
      let refusedOrders: Int
      /// The camera as it is now, for a screen of `screenAspect`, to aim touch orders.
      let camera: CameraProjection
      /// Whether the HUD says Miki can Disrupt.
      let canDisrupt: Bool
      let disrupts: Int
      let companionShots: [PartyMember: Int]
      let fallBacks: Int
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
          let offset = target - leaderPosition
          if simd_length(offset) < 0.2 || snapshot.mode == .dialogue {
            advance()
            continue
          }
          if stepTime > Self.walkTimeout {
            failures.append(
              "did not reach \(Self.describe(target)) within \(Int(Self.walkTimeout)) s")
            advance()
            continue
          }
          return InputRules.Raw(
            stick: Movement.stick(towards: offset, cameraOffset: snapshot.level.cameraOffset))
        case .wait(let seconds):
          guard stepTime < seconds else {
            advance()
            continue
          }
          return InputRules.Raw()
        case .mark(let label):
          marks.append(Summary.Mark(name: label, seconds: Double(elapsed)))
          announce(label)
          advance()
        case .act:
          return press(InputRules.Raw(controllerAction: true))
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
        case .expectSquad(let state):
          expect(
            snapshot.squadState == state,
            "the squad was \(snapshot.squadState) instead of \(state)")
        case .awaitSquad(let state, let seconds):
          if snapshot.squadState == state {
            advance()
            continue
          }
          if stepTime > seconds {
            failures.append("the squad was not \(state) within \(Int(seconds)) s")
            advance()
            continue
          }
          return InputRules.Raw()
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
            || snapshot.firedTriggers != 0 || snapshot.beat != .alone || snapshot.defeated != 0
            || snapshot.hitsTaken != 0 || snapshot.ammo != start.startingAmmo
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
        case .expectLevel(let id):
          expect(snapshot.level.id == id, "the level was \(snapshot.level.id) instead of \(id)")
        case .signature:
          return press(InputRules.Raw(controllerSignature: true))
        case .awaitDisrupt(let seconds):
          if snapshot.canDisrupt {
            advance()
            continue
          }
          if stepTime > seconds {
            failures.append("Miki could not Disrupt within \(Int(seconds)) s")
            advance()
            continue
          }
          return InputRules.Raw()
        case .expectDisrupts(let count):
          expect(
            snapshot.disrupts == count,
            "Disrupt had cancelled \(snapshot.disrupts) wind-up(s) instead of \(count)")
        case .expectFired(let member):
          expect(
            snapshot.companionShots[member, default: 0] > 0,
            "\(member.displayName) had not fired by themselves")
        case .awaitFallBacks(let count, let seconds):
          if snapshot.fallBacks >= count {
            advance()
            continue
          }
          if stepTime > seconds {
            failures.append(
              "the party had not fallen back \(count) time(s) within \(Int(seconds)) s")
            advance()
            continue
          }
          return InputRules.Raw()
        case .expectFallBacks(let count):
          expect(
            snapshot.fallBacks == count,
            "the party had fallen back \(snapshot.fallBacks) time(s) instead of \(count)")
        case .fireUntilDefeated(let count, let seconds):
          if snapshot.defeated >= count {
            advance()
            return InputRules.Raw()
          }
          if stepTime > seconds {
            failures.append(
              "\(snapshot.defeated) hostile(s) were down after \(Int(seconds)) s of fire")
            advance()
            return InputRules.Raw()
          }
          return InputRules.Raw(controllerFire: true)
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
        simulationMilliseconds: Self.timing(simulationTimes), warningFrames: warningFrames,
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
    /// companions step into formation around Miki.
    private static let restartRun: [Step] = [
      .pause, .wait(seconds: 0.5), .menu(1), .wait(seconds: 0.3), .mark("restart chosen"),
      .wait(seconds: 0.6), .act, .expectRestarted, .mark("restarted"), .wait(seconds: 1),
    ]

    /// Miki alone from the Brooklyn end to the Manhattan end (ADR 0004, M1 and M2), along the
    /// buried road: through the first tower's east arch, where the stranger steps out from behind
    /// the pier, past him once he is down and on beyond the tower, which fades while it hides
    /// her, then across to the west side and through the second tower. Each trigger area shows
    /// its line once, then a Restart returns her to the start with none fired.
    private static let bridgeWalk: [Step] =
      [
        .mark("start"), .walk([6.5, 66]), .mark("buried road"), .walk([6.5, 20]),
        .mark("first tower"), .walk([6.5, 15]), .expectBeat(.stranger), .wait(seconds: 3.4),
        .fire(seconds: 2), .expectDefeated(1), .mark("stranger down"), .walk([6.5, -12]),
        .mark("beyond the first tower"), .walk([6.5, -206.15]), .mark("mid-span"),
        .walk([-7, -456.3]), .mark("second tower"), .walk([-7, -502.3]), .mark("Manhattan end"),
        .expectTriggers(5), .walk([-7, -494.3]), .walk([-7, -502.3]), .expectTriggers(5),
        .wait(seconds: 0.5),
      ] + restartRun + [.expectTriggers(0)]

    /// Up to the stranger's area: his fight begins as Miki stops in the first tower's east arch.
    private static let toTheStranger: [Step] = [
      .mark("start"), .walk([6.5, 66]), .walk([6.5, 15]), .mark("Friendly!"),
      .expectBeat(.stranger),
    ]

    /// The first fight (ADR 0004, M2): the stranger steps out, Miki calls "Friendly!", his first
    /// shot misses on purpose, and two of her shots put him down before he fires again. Then a
    /// Restart puts him back, unseen.
    private static let firstFight: [Step] =
      toTheStranger + [
        .wait(seconds: 3.4), .mark("near miss"), .expectHits(0), .fire(seconds: 2),
        .expectDefeated(1), .mark("stranger down"), .expectHits(0), .wait(seconds: 1),
      ] + restartRun

    /// Standing in the open: after the deliberate miss, three hits start the fight again with
    /// Miki just outside the area and nothing lost. She walks back in and wins.
    private static let fightRetry: [Step] =
      toTheStranger + [
        .wait(seconds: 7), .expectHits(1), .mark("hit"), .wait(seconds: 7.5),
        .expectBeat(.alone), .expectHits(0), .expectDefeated(0), .mark("retry"),
        .walk([6.5, 15]), .expectBeat(.stranger), .wait(seconds: 3.4), .fire(seconds: 2),
        .expectDefeated(1), .mark("won after the retry"),
      ]

    /// From the start to Tom joining: the first fight, the search and the ambush.
    private static let toTom: [Step] =
      toTheStranger + [
        .wait(seconds: 3.4), .fire(seconds: 2), .expectDefeated(1), .walk([4.4, 4.6]),
        .mark("at the body"), .act, .wait(seconds: 2.3), .mark("the attacker"),
        .wait(seconds: 1.3), .talk, .expectBeat(.withTom), .expectParty([.miki, .tom]),
        .expectDefeated(2), .mark("Tom joins"),
      ]

    /// The ambush (ADR 0004, M3): after the first fight Miki searches the stranger, the attacker
    /// runs at her out of the west arch, Tom drops him and joins after a short exchange. Tom then
    /// follows her on to mid-span, and a Restart leaves Miki alone again.
    private static let ambush: [Step] =
      toTom + [
        .walk([6.5, -12]), .mark("beyond the tower with Tom"), .walk([6.5, -206.15]),
        .mark("mid-span with Tom"), .wait(seconds: 0.5),
      ] + restartRun + [.expectParty([.miki])]

    /// From the start to Laura joining (M4): with Tom, beyond mid-span, where a woman calls out;
    /// Help uses the medical kit, she stands, and the exchange ends with her joining.
    private static let toLaura: [Step] =
      toTom + [
        .walk([6.5, -206.15]), .walk([6.5, -225.15]), .walk([-6.5, -230.15]),
        .wait(seconds: 0.6), .expectBeat(.lauraFound), .mark("Laura found"),
        .wait(seconds: 2), .walk([-7, -234.15]),
        .mark("at Laura"), .act, .wait(seconds: 1.8), .mark("on her feet"), .wait(seconds: 0.8),
        .talk, .expectBeat(.withLaura), .expectParty([.miki, .tom, .laura]),
        .mark("Laura joins"),
      ]

    /// Laura (M4): she joins, then both companions follow Miki on towards Manhattan, and a
    /// Restart leaves Miki alone again.
    private static let laura: [Step] =
      toLaura + [.walk([-7, -257.15]), .mark("three together"), .wait(seconds: 0.5)] + restartRun
      + [.expectParty([.miki])]

    /// The whole opening (M4): from the Brooklyn end to the Manhattan end, through the fight, the
    /// ambush and Laura, then the closing exchange with all three, then a Restart.
    private static let opening: [Step] =
      toLaura + [
        .walk([-7, -456.3]), .mark("second tower"), .walk([-7, -502.3]), .talk,
        .expectBeat(.arrived), .mark("Manhattan, together"), .expectTriggers(5),
        .wait(seconds: 0.5),
      ] + restartRun + [.expectParty([.miki]), .expectTriggers(0)]

    /// Formations (M5): once Laura joins, the formation button cycles Close, Spread and Column
    /// on the open snow. Spread keeps its width through the second tower's west arch, which is
    /// wide enough for it; the closing exchange keeps the formation, and Restart returns to Close
    /// with Miki alone.
    private static let formations: [Step] =
      toLaura + [
        .expectFormation(.close), .formation, .expectFormation(.spread), .walk([-7, -250]),
        .mark("spread"), .walk([-7, -275]), .formation, .expectFormation(.column),
        .walk([-7, -295]), .mark("column"), .walk([-7, -300]), .formation,
        .expectFormation(.close), .walk([-7, -315]), .mark("close"), .walk([-7, -320]),
        .formation, .expectFormation(.spread), .walk([-7, -456.3]),
        .mark("second tower in spread"), .walk([-7, -472]), .mark("in the arch in spread"),
        .walk([-7, -502.3]), .talk, .expectBeat(.arrived), .expectFormation(.spread),
        .mark("Manhattan, together"), .wait(seconds: 0.5),
      ] + restartRun + [.expectParty([.miki])]

    /// Squad orders (ADR 0003, phase S3), once Laura joins. The D-pad sends both companions
    /// ahead, and they hold there while Miki walks off until Formation calls them back. Then one
    /// companion goes while the other follows, the other goes beside the first, and Hold keeps
    /// both where they stand. A switch leaves the previous leader holding with them. Touch
    /// orders send both to a marked spot and refuse one aimed off the buried road, and the end of
    /// the opening waits for companions left holding until they are called back.
    private static let orders: [Step] =
      toLaura + [
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
        .expectBeat(.withLaura), .mark("waiting for the others"), .wait(seconds: 0.6), .formation,
        .awaitConversation(seconds: 45), .talk, .expectBeat(.arrived),
        .mark("Manhattan, together"), .wait(seconds: 0.5),
      ] + restartRun + [.expectParty([.miki])]

    /// The pause menu's third choice: Pause, down twice, confirm.
    private static let otherLevel: [Step] = [
      .pause, .wait(seconds: 0.5), .menu(1), .wait(seconds: 0.3), .menu(1), .wait(seconds: 0.3),
      .mark("third choice"), .wait(seconds: 0.6), .act, .wait(seconds: 1),
    ]

    /// The combat yard (ADR 0005), entered from the bridge through the pause menu's third
    /// choice. The companions hold behind the wall while Miki steps out past its east end alone,
    /// where both shooters can see her; the formation button, which regroups in a fight, calls
    /// them to her, and the shooters' third hit falls the party back to the entrance. Then all
    /// three go round together: Miki disrupts a wind-up, the companions take cover and fire by
    /// themselves, and Miki's carbine and theirs clear the yard, after which the formation
    /// button changes the formation again. Restart begins the yard again, and the third choice
    /// returns to the bridge.
    private static let combatYard: [Step] =
      [.mark("the bridge")] + otherLevel + [
        .expectLevel("combat-yard"), .expectParty([.miki, .tom, .laura]), .mark("the yard"),
        .walk([0, 2.5]), .wait(seconds: 1), .order(.hold), .expectOrder(.tom, "holding"),
        .walk([6.5, 2.5]), .walk([6.5, -1.5]), .expectBeat(.stranger),
        .mark("alone beyond the wall"), .formation, .expectSquad("regrouping"),
        .expectOrder(.tom, "following"), .mark("regroup"), .awaitFallBacks(1, seconds: 20),
        .mark("falling back"), .wait(seconds: 1.2), .expectHits(0), .expectSquad("following"),
        .expectOrder(.laura, "following"), .expectNear(.miki, [0, 6], within: 0.3),
        .expectDefeated(0), .mark("fell back"), .walk([6.5, 2.5]), .walk([6.5, -1.5]),
        .awaitDisrupt(seconds: 6), .signature, .expectDisrupts(1), .mark("Miki disrupts"),
        .wait(seconds: 1.5), .mark("the companions fire"), .fireUntilDefeated(2, seconds: 30),
        .expectFired(.laura), .expectFired(.tom), .expectFallBacks(1),
        .mark("the yard is clear"), .formation, .expectFormation(.spread), .wait(seconds: 1),
      ] + restartRun + [.expectLevel("combat-yard")] + otherLevel + [
        .expectLevel("brooklyn-bridge"), .expectParty([.miki]), .mark("back on the bridge"),
      ]

    /// Every scenario, by the name `apple/scripts/playtest` gives it.
    private static let scenarios: [(name: String, steps: [Step])] = [
      ("bridge-walk", bridgeWalk), ("first-fight", firstFight), ("fight-retry", fightRetry),
      ("ambush", ambush), ("laura", laura), ("opening", opening), ("formations", formations),
      ("orders", orders), ("combat-yard", combatYard),
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
