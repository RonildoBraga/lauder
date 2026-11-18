#if DEBUG
  import Foundation
  import simd

  /// Scripted playtests for the Simulator, run by `scripts/playtest` (Debug builds only).
  ///
  /// A scenario drives the leader through the normal input path, so the rendered game, the
  /// input rules and the real frame timing are all exercised. The runner records every
  /// simulated frame and writes a trace and a summary into the app's Documents/playtest folder.
  struct PlaytestRunner {
    enum Step {
      /// Steer the leader to a point; fails after 30 s.
      case walk(SIMD2<Float>)
      /// Hold the stick towards a world direction.
      case push(SIMD2<Float>, seconds: Float)
      case wait(seconds: Float)
      case switchLeader
      /// A named moment, for stills cut from the screen recording.
      case mark(String)
      case expectTogether(maxDistance: Float)
      case expectInDepot
      /// Switch until this member leads.
      case lead(PartyMember)
      /// Press the action for one frame. While paused it confirms the menu's choice.
      case act
      case expectPassage(open: Bool)
      /// Press the action to start a conversation, then once per line until play resumes.
      case talk
      case expectPhase(GameSession.Phase)
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
    }

    /// What the runner can see of the game each frame.
    struct Snapshot {
      let leader: PartyMember
      let party: [PartyMember]
      let positions: [PartyMember: SIMD2<Float>]
      let mode: GameSession.Mode
      let phase: GameSession.Phase
      let passageOpen: Bool
      let firedTriggers: Int
      let beat: GameSession.Beat
      let hitsTaken: Int
      let defeated: Int
      let ammo: Int
      let retrying: Bool
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

    static let scenarioNames = [
      "route", "panel", "closed", "leaders", "reversals", "switches", "walls", "mission", "all",
      "bridge-walk", "first-fight", "fight-retry",
    ]
    static let walkTimeout: Float = 30
    /// How long each conversation line stays on screen before the next press.
    static let lineSeconds: Float = 0.6

    let name: String
    /// The level the scenario plays; GameWorld loads it for the launch argument.
    let level: Level.ID
    private let steps: [Step]
    private var index = 0
    private var stepTime: Float = 0
    private var elapsed: Float = 0
    private var switchFrame = 0
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
      level = Self.level(for: scenario)
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
          if simd_length(offset) < 0.2 {
            advance()
            continue
          }
          if stepTime > Self.walkTimeout {
            failures.append("did not reach \(Self.describe(target)) within 30 s")
            advance()
            continue
          }
          return InputRules.Raw(stick: stick(towards: offset))
        case .push(let direction, let seconds):
          guard stepTime < seconds else {
            advance()
            continue
          }
          return InputRules.Raw(stick: stick(towards: direction))
        case .wait(let seconds):
          guard stepTime < seconds else {
            advance()
            continue
          }
          return InputRules.Raw()
        case .switchLeader:
          // Press for one frame and release for one, so InputRules sees a fresh edge.
          switchFrame += 1
          if switchFrame == 1 { return InputRules.Raw(controllerSwitch: true) }
          switchFrame = 0
          advance()
          return InputRules.Raw()
        case .mark(let label):
          marks.append(Summary.Mark(name: label, seconds: Double(elapsed)))
          announce(label)
          advance()
        case .expectTogether(let maximum):
          for (member, position) in positions
          where simd_distance(position, leaderPosition) > maximum {
            failures.append(
              "\(member.displayName) was \(Self.metres(simd_distance(position, leaderPosition))) "
                + "from the leader at \(Self.seconds(elapsed)) (allowed \(Self.metres(maximum)))")
          }
          advance()
        case .expectInDepot:
          for (member, position) in positions where !Self.isInDepot(position) {
            failures.append(
              "\(member.displayName) was outside the depot at \(Self.describe(position))")
          }
          advance()
        case .lead(let member):
          if leader == member {
            switchFrame = 0
            presses = 0
            advance()
            continue
          }
          // One press, one release, then look again; three presses reach anyone.
          switchFrame += 1
          if switchFrame == 1 {
            presses += 1
            if presses > 3 {
              failures.append("could not switch to \(member.displayName)")
              switchFrame = 0
              presses = 0
              advance()
              continue
            }
            return InputRules.Raw(controllerSwitch: true)
          }
          switchFrame = 0
          return InputRules.Raw()
        case .act:
          switchFrame += 1
          if switchFrame == 1 { return InputRules.Raw(controllerAction: true) }
          switchFrame = 0
          advance()
          return InputRules.Raw()
        case .expectPassage(let open):
          if snapshot.passageOpen != open {
            failures.append(
              "the passage was \(snapshot.passageOpen ? "open" : "closed") "
                + "at \(Self.seconds(elapsed))")
          }
          advance()
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
          if switchFrame == 1 {
            switchFrame = 0
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
            switchFrame = 1
            return InputRules.Raw(controllerAction: true)
          }
          return InputRules.Raw()
        case .expectPhase(let phase):
          if snapshot.phase != phase {
            failures.append(
              "the mission was at \(snapshot.phase) instead of \(phase) "
                + "at \(Self.seconds(elapsed))")
          }
          advance()
        case .pause:
          switchFrame += 1
          if switchFrame == 1 { return InputRules.Raw(controllerPause: true) }
          advance()
          return InputRules.Raw()
        case .menu(let direction):
          // Down on the stick (negative y) moves the choice down the menu.
          switchFrame += 1
          if switchFrame == 1 {
            return InputRules.Raw(stick: [0, direction > 0 ? -1 : 1])
          }
          advance()
          return InputRules.Raw()
        case .expectRestarted:
          let start = Level.level(level)
          if snapshot.leader != start.party[0] || snapshot.party != start.party
            || snapshot.phase != .briefing || snapshot.passageOpen || snapshot.firedTriggers != 0
            || snapshot.beat != .alone || snapshot.defeated != 0 || snapshot.hitsTaken != 0
            || snapshot.ammo != start.startingAmmo || snapshot.mode != .exploring
          {
            failures.append(
              "after Restart \(snapshot.leader.displayName) led a party of "
                + "\(snapshot.party.count), the mission was at \(snapshot.phase), the passage "
                + "was \(snapshot.passageOpen ? "open" : "closed") and "
                + "\(snapshot.firedTriggers) trigger(s) had fired")
          }
          for (member, position) in positions
          where simd_distance(position, start.spawn(member)) > 0.3 {
            failures.append(
              "\(member.displayName) was at \(Self.describe(position)) after Restart")
          }
          advance()
        case .expectTriggers(let count):
          if snapshot.firedTriggers != count {
            failures.append(
              "\(snapshot.firedTriggers) trigger(s) had fired instead of \(count) "
                + "at \(Self.seconds(elapsed))")
          }
          advance()
        case .fire(let seconds):
          guard stepTime < seconds else {
            advance()
            return InputRules.Raw()
          }
          return InputRules.Raw(controllerFire: true)
        case .expectBeat(let beat):
          if snapshot.beat != beat {
            failures.append(
              "the story was at \(snapshot.beat) instead of \(beat) at \(Self.seconds(elapsed))")
          }
          advance()
        case .expectDefeated(let count):
          if snapshot.defeated != count {
            failures.append(
              "\(snapshot.defeated) hostile(s) were down instead of \(count) "
                + "at \(Self.seconds(elapsed))")
          }
          advance()
        case .expectHits(let count):
          if snapshot.hitsTaken != count {
            failures.append(
              "the leader had taken \(snapshot.hitsTaken) hit(s) instead of \(count) "
                + "at \(Self.seconds(elapsed))")
          }
          advance()
        }
      }
      finish()
      return InputRules.Raw()
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
      switchFrame = 0
      presses = 0
      talking = false
    }

    /// Append the mark to marks.log as it happens, so `scripts/playtest` can take a screenshot
    /// at that moment: "<seconds since 1970>\t<orientation>\t<name>".
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

    /// Laura opens the service passage from the latch approach (Party B).
    private static let openWithLaura: [Step] = [
      .lead(.laura), .walk([2.5, 3]), .walk([3.2, -5]), .mark("at the latch"),
      .wait(seconds: 1), .act,
      .expectPassage(open: true), .mark("passage open"),
    ]

    /// Through the open passage into the depot and back to the street.
    private static let roundTrip: [Step] = [
      .walk([2.5, 3]), .walk([2.5, -4.5]), .mark("doorway in"), .walk([5, -4.5]),
      .walk([6.5, -3]), .wait(seconds: 2), .expectInDepot, .mark("in the depot"),
      .walk([5, -4.5]), .mark("doorway out"), .walk([2.5, -4.5]), .walk([2.5, 3]),
      .walk([-6, 3]), .wait(seconds: 2), .expectTogether(maxDistance: 2.5),
      .mark("back on the street"),
    ]

    private static let route = openWithLaura + roundTrip

    /// Tom opens the passage from the loose-panel approach instead.
    private static let panel: [Step] = [
      .lead(.tom), .walk([2.5, 3]), .walk([3.2, -4]), .mark("at the panel"),
      .wait(seconds: 1), .act,
      .expectPassage(open: true), .walk([5, -4.2]), .walk([6.5, -3]), .wait(seconds: 2),
      .expectInDepot, .mark("in the depot"),
    ]

    /// Miki cannot open the passage, and nor can Tom from the latch.
    private static let closed: [Step] = [
      .lead(.miki), .walk([2.5, 3]), .walk([3.2, -5]), .mark("Miki at the latch"),
      .wait(seconds: 1), .act, .expectPassage(open: false), .lead(.tom), .walk([3.2, -5]),
      .mark("Tom at the latch"), .wait(seconds: 1), .act, .expectPassage(open: false),
      .wait(seconds: 1.5),
      .expectTogether(maxDistance: 2.5),
    ]

    private static let reversals: [Step] = [
      .walk([-4, 5]), .wait(seconds: 1),
      .push([1, 0], seconds: 1.2), .mark("reversal 1"), .push([-1, 0], seconds: 1.2),
      .mark("reversal 2"), .push([1, 0], seconds: 1.2), .mark("reversal 3"),
      .push([-1, 0], seconds: 1.2), .mark("sharp turn"), .push([1, -1], seconds: 1),
      .push([-1, 1], seconds: 1), .wait(seconds: 2), .expectTogether(maxDistance: 2.5),
      .mark("settled after reversals"),
    ]

    private static let switches: [Step] = [
      .walk([-4, 5]), .push([1, 0], seconds: 0.8), .switchLeader, .mark("switch while moving"),
      .push([1, 0], seconds: 0.8), .switchLeader, .push([-1, 0], seconds: 0.8), .switchLeader,
      .wait(seconds: 1), .switchLeader, .mark("switch while standing"), .wait(seconds: 2),
      .expectTogether(maxDistance: 2.5), .mark("settled after switches"),
    ]

    private static let walls: [Step] =
      [.walk([-10, 8.6]), .push([1, 0.15], seconds: 3), .mark("wall slide"), .wait(seconds: 1)]
      + openWithLaura + [
        .walk([2.5, -4.5]), .walk([5, -4.5]), .walk([9.3, -6.3]),
        .push([1, -1], seconds: 1.5), .mark("depot corner"), .wait(seconds: 2),
        .expectInDepot, .expectTogether(maxDistance: 2.5),
      ]

    /// Restart from the pause menu: Pause, down to Restart, confirm. The check comes before the
    /// companions step into formation around Miki.
    private static let restartRun: [Step] = [
      .pause, .wait(seconds: 0.5), .menu(1), .wait(seconds: 0.3), .mark("restart chosen"),
      .wait(seconds: 0.6), .act, .expectRestarted, .mark("restarted"), .wait(seconds: 1),
    ]

    /// Party C's loop from a fresh run: the briefing, Laura's latch, Miki's regulator, the return
    /// with Tom leading, the repair, Laura's call and the plan, then a Restart and a new briefing.
    private static let mission: [Step] =
      [
        .mark("start"), .wait(seconds: 0.6), .act, .wait(seconds: 0.4), .mark("briefing"),
        .talk, .expectPhase(.seekingRegulator), .mark("briefed"),
      ]
      + openWithLaura + [
        .lead(.miki), .walk([2.5, -4.5]), .walk([5, -4.5]), .walk([6.2, -4.2]),
        .mark("at the housing"), .wait(seconds: 0.6), .talk, .expectPhase(.carryingRegulator),
        .mark("regulator taken"), .wait(seconds: 0.6),
        .lead(.tom), .walk([5, -4.5]), .walk([2.5, -4.5]), .walk([2.5, 3]),
        .walk([-8.4, 2.4]), .wait(seconds: 1), .act, .mark("Tom at the transmitter"),
        .wait(seconds: 0.6), .expectPhase(.carryingRegulator),
        .lead(.miki), .walk([-8.8, 2]), .talk, .expectPhase(.radioRepaired), .mark("repaired"),
        .wait(seconds: 0.6), .lead(.laura), .walk([-9, 2.6]), .act, .wait(seconds: 0.4),
        .mark("call"), .talk, .expectPhase(.meetingAgreed), .mark("meeting agreed"),
        .wait(seconds: 0.6), .talk, .expectPhase(.meetingAgreed), .mark("plan read"),
      ] + restartRun + [.talk, .expectPhase(.seekingRegulator), .mark("briefed again")]

    /// Miki alone from the Brooklyn end to the Manhattan end (ADR 0004, M1 and M2): up the east
    /// roadway, past the stranger once he is down, through the first tower, across the collapsed
    /// divider beside the jammed bus, then up the west roadway through the second tower. Each
    /// trigger area shows its line once, then a Restart returns her to the start with none fired.
    private static let bridgeWalk: [Step] =
      [
        .mark("start"), .walk([6.5, 66]), .mark("cars ahead"), .walk([6.5, 51]),
        .expectBeat(.stranger), .wait(seconds: 3.4), .fire(seconds: 2), .expectDefeated(1),
        .mark("stranger down"), .walk([6.5, 20]),
        .mark("first tower"), .walk([6.5, -9]), .mark("mid-span"), .walk([6.5, -28]),
        .mark("blocked lanes"), .walk([-7, -31]), .mark("across the divider"),
        .walk([-7, -70]), .mark("second tower"), .walk([-7, -108]), .mark("Manhattan end"),
        .expectTriggers(6), .walk([-7, -100]), .walk([-7, -108]), .expectTriggers(6),
        .wait(seconds: 0.5),
      ] + restartRun + [.expectTriggers(0)]

    /// Up to the stranger's area: his fight begins as Miki stops in the open lane.
    private static let toTheStranger: [Step] = [
      .mark("start"), .walk([6.5, 66]), .walk([6.5, 51]), .mark("Friendly!"),
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
        .walk([6.5, 51]), .expectBeat(.stranger), .wait(seconds: 3.4), .fire(seconds: 2),
        .expectDefeated(1), .mark("won after the retry"),
      ]

    /// The level a scenario plays: the bridge for the opening's, Relay House for the others.
    static func level(for scenario: String) -> Level.ID {
      ["bridge-walk", "first-fight", "fight-retry"].contains(scenario)
        ? .brooklynBridge : .relayHouse
    }

    static func steps(for scenario: String) -> [Step]? {
      switch scenario {
      case "route": route
      case "panel": panel
      case "closed": closed
      case "leaders":
        openWithLaura + [.lead(.miki)] + roundTrip + [.lead(.laura)] + roundTrip
          + [.lead(.tom)] + roundTrip
      case "reversals": reversals
      case "switches": switches
      case "walls": walls
      case "mission": mission
      case "all": closed + route + reversals + switches + walls + restartRun + mission
      case "bridge-walk": bridgeWalk
      case "first-fight": firstFight
      case "fight-retry": fightRetry
      default: nil
      }
    }

    // MARK: - Helpers

    /// Stick axes for a world direction under this scenario's level's camera.
    private func stick(towards direction: SIMD2<Float>) -> SIMD2<Float> {
      Self.stick(towards: direction, cameraOffset: Level.level(level).cameraOffset)
    }

    /// Screen-relative stick axes for a world direction, as Movement interprets them.
    static func stick(towards direction: SIMD2<Float>, cameraOffset: SIMD3<Float>) -> SIMD2<Float> {
      guard simd_length(direction) > 0.0001 else { return .zero }
      let toCamera = SIMD2(cameraOffset.x, cameraOffset.z)
      let forward = -simd_normalize(toCamera)
      let right = SIMD2(-forward.y, forward.x)
      let unit = simd_normalize(direction)
      return SIMD2(simd_dot(unit, right), simd_dot(unit, forward))
    }

    /// The depot's interior, inside its walls.
    static func isInDepot(_ point: SIMD2<Float>) -> Bool {
      point.x > 4.2 && point.x < 9.8 && point.y > -6.8 && point.y < -1.2
    }

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

    private static func metres(_ value: Float) -> String {
      String(format: "%.2f m", value)
    }

    private static func seconds(_ value: Float) -> String {
      String(format: "%.1f s", value)
    }
  }
#endif
