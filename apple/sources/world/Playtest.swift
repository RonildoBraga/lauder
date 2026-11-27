#if DEBUG
  import Foundation
  import simd

  /// Scripted playtests for the Simulator, run by `apple/scripts/playtest` (Debug builds only).
  ///
  /// A scenario drives the leader through the normal input path, so the rendered game, the
  /// input rules and the real frame timing are all exercised. The runner records every
  /// simulated frame and writes a trace and a summary into the app's Documents/playtest folder.
  struct PlaytestRunner {
    struct DamageTally: Codable, Sendable {
      var normal = 0
      var weakpoint = 0
      var hits = 0
      var grenade = 0
      var byMember: [String: Int] = [:]
      var byTarget: [String: [String: Int]] = [:]

      mutating func record(_ hit: DamageHit) {
        if hit.effectiveness == .normal { normal += hit.amount } else { weakpoint += hit.amount }
        hits += 1
        if hit.weapon == nil { grenade += hit.amount }
        byMember[hit.attacker.rawValue, default: 0] += hit.amount
        byTarget[hit.target, default: [:]][hit.attacker.rawValue, default: 0] += hit.amount
      }
    }

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
      /// Dodge the observed commitment through the ordinary roll input.
      case dodgeGuard
      case expectDamageFeedback
      /// A press of the right stick, which locks the aim on a hostile (ADR 0020).
      case lock
      /// Whether a lock holds.
      case expectLock(Bool)
      /// A press of the weapon switch: the leader's other weapon (ADR 0021).
      case swap
      case grenade
      case expectGrenadeDamage
      case expectLegLoss
      /// Dismantle the guard through ordinary movement, leader/weapon switches and Fire.
      case dismantleGuard
      /// Miki shoots down every scout drone with the aim help, stepping out of each dive and
      /// rolling across the guard's committed bursts (issue #201).
      case downDrones
      /// Followers down a drone while the guard lives and the player never fires.
      case companionDrones
      case expectDronesDown(Int)
      /// Miki shoots down every pack crawler, rolling out of their rams and the guard's
      /// committed bursts (issue #208).
      case downCrawlers
      case expectCrawlersDown(Int)
      case waitForRetry(seconds: Float)
      /// Miki stays under player control; Laura and Tom supply their own combat contributions.
      case companionFight
      case companionPrerequisites
      case defendGuard(seconds: Float)
      /// Observe both actual followers settling into separate real cover after Defend.
      case settleDefendCover(seconds: Float, hold: Float)
      case expectCombatStance(GameSession.CombatStance)
      case provokeRetaliation
      case leadWarnedMember
      case finishRetaliationCycle
      /// Touch-only targeting and combat, without an unavailable manual aim stick.
      case touchTarget
      case touchPress(InputRules.Raw)
      case touchFight
      case expectPanel(Bool)
      case expectTouchDamage
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
      /// Hostiles down other than the guard's pack, its drones and crawlers, which go down with it.
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
      var guardStrategy: GuardStrategy? = nil
      var guardPoints: [GuardWeakpoint] = []
      var robotPosition: SIMD2<Float>? = nil
      var robotFacing: SIMD2<Float>? = nil
      var isRetrying = false
      var companionActivities: [PartyMember: CompanionTactics.Activity] = [:]
      var combatStance = GameSession.CombatStance.defend
      var partyWeapons: [PartyMember: EncounterSimulation.WeaponStatus] = [:]
      var guardTarget: PartyMember? = nil
      var robotCommittedPoint: SIMD2<Float>? = nil
      var partyHits: [PartyMember: Int] = [:]
      var companionTargets: [PartyMember: SIMD2<Float>] = [:]
      var coveredMembers: Set<PartyMember> = []
      var damage = DamageTally()
      var damageLabelCount = 0
      var showsPanel = true
      var grenadeCooldown: Float = 0
      var grenadeInFlight = false
      /// Scout drones down, whether shot down or fallen with their guard.
      var dronesDown = 0
      /// Each scout drone as the route can see it: where it flies, what it is doing, the
      /// member a warning drone watches and the point a diving drone has committed to.
      var drones: [Drone] = []

      struct Drone {
        let id: String
        let position: SIMD2<Float>
        let phase: ScoutDrone.Phase
        let watching: PartyMember?
        let committedPoint: SIMD2<Float>?
      }

      /// Pack crawlers down, whether shot down or gone down with their guard.
      var crawlersDown = 0
      /// Each pack crawler as the route can see it: where it is, what it is doing and the
      /// fixed line of a wind-up or ram.
      var crawlers: [CrawlerView] = []

      struct CrawlerView {
        let id: String
        let position: SIMD2<Float>
        let phase: Crawler.Phase
        let watching: PartyMember?
        let ramStart: SIMD2<Float>?
        let ramEnd: SIMD2<Float>?
      }
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
      /// Samples of the first real, nonlethal leg break, retained through victory and Restart.
      struct LegStagger: Codable, Sendable {
        var firstShotSerial = 0
        var lastShotSerial = 0
        var staggeredSamples = 0
        var observedSeconds: Double = 0
        var shotsDuringStagger = 0
        var completed = false
        var freshWarningObserved = false
      }

      struct Mark: Codable, Sendable {
        let name: String
        let seconds: Double
        var robotPhase: String? = nil
        var robotShots = 0
        var guardPhase: String? = nil
        var legsLost: Int? = nil
        var companionActivities: [String: String]? = nil
        var combatStance: String? = nil
        var guardTarget: String? = nil
        var committedPoint: [Float]? = nil
        var partyPositions: [String: [Float]]? = nil
        var companionTargets: [String: [Float]]? = nil
        var coveredMembers: [String]? = nil
        var longestCoverHoldSeconds: Float? = nil
        var health: Int? = nil
        var damage: DamageTally? = nil
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
      /// Highest observed encounter injury count, retained after victory, retry and Restart.
      var peakPartyHits: [String: Int] = [:]
      /// Rising retry transitions, rather than the number of frames spent fading/retrying.
      var retryCount = 0
      var damage = DamageTally()
      var maximumDamageLabels = 0
      var nonTouchInputFrames: Int? = nil
      var legStagger: LegStagger? = nil
    }

    static let scenarioNames = scenarios.map(\.name)
    /// The screen's width over its height for touch orders: the baseline iPhone's, in landscape.
    /// The world finds the ground with the same shape, so any shape aims the same point.
    static let screenAspect: Float = 2.16
    static let walkTimeout: Float = 120
    /// How long each conversation line stays on screen before the next press.
    static let lineSeconds: Float = 0.6

    let name: String
    private var usesTouch: Bool { name == "touch-fight" }
    private let steps: [Step]
    private var index = 0
    private var stepTime: Float = 0
    private var elapsed: Float = 0
    /// Frames into the current step's press.
    private var pressFrame = 0
    private var presses = 0
    private var sincePress: Float = 0
    private var talking = false
    private var guardRelease = false
    private var lastGuardDodge: Float = -10
    private var guardStageSeen: GuardStrategy.Phase?
    private var companionMarks: Set<String> = []
    private var defendBaseline: GuardStrategy?
    private var defendLoaded: [PartyMember: Int] = [:]
    private var defendDistances: [PartyMember: Float] = [:]
    private var defendClosestDistances: [PartyMember: Float] = [:]
    private var defendApproach: [PartyMember: Float] = [:]
    private var defendPreviousPositions: [PartyMember: SIMD2<Float>] = [:]
    private var retaliationMember: PartyMember?
    private var retaliationPoint: SIMD2<Float>?
    private var retaliationDodged = false
    private var coverStableSince: Float?
    private var coverStablePositions: [PartyMember: SIMD2<Float>] = [:]
    private var longestCoverHold: Float = 0
    private var peakPartyHits: [PartyMember: Int] = [:]
    private var retryCount = 0
    private var wasRetrying = false
    private var observedDamage = DamageTally()
    private var maximumDamageLabels = 0
    private var nonTouchInputFrames = 0
    private var previousLegsLost: Int?
    private var legStagger: Summary.LegStagger?
    private var legStaggerStartedAt: Float = 0
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

    /// A focused contract run uses the same input driver as the named rendered routes.
    init(steps: [Step], name: String) {
      self.name = name
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
      let raw = nextInput(snapshot)
      if usesTouch,
        raw.hasControllerInput || raw.hasKeyboardInput || raw.stick != .zero
          || raw.aimStick != .zero
      {
        if nonTouchInputFrames == 0 { failures.append("touch-fight emitted input outside touch") }
        nonTouchInputFrames += 1
      }
      return raw
    }

    private mutating func nextInput(_ snapshot: Snapshot) -> InputRules.Raw {
      guard summary == nil else { return InputRules.Raw() }
      observedDamage = snapshot.damage
      maximumDamageLabels = max(maximumDamageLabels, snapshot.damageLabelCount)
      for (member, hits) in snapshot.partyHits {
        peakPartyHits[member] = max(peakPartyHits[member, default: 0], hits)
      }
      if snapshot.isRetrying && !wasRetrying { retryCount += 1 }
      wasRetrying = snapshot.isRetrying
      if name == "robot-parts" { observeLegStagger(snapshot) }
      if startedAt == nil { startedAt = Date() }
      guard elapsed >= 0.5 else { return InputRules.Raw() }
      let leader = snapshot.leader
      let positions = snapshot.positions
      let leaderPosition = positions[leader] ?? .zero
      while index < steps.count {
        switch steps[index] {
        case .walk(let target):
          if let raw = steer(towards: target, from: leaderPosition, in: snapshot) { return raw }
        case .touchPress(let raw):
          return press(raw)
        case .touchTarget:
          guard let raw = targetTap(snapshot) else {
            failures.append("the real guard was not on screen for a touch target tap")
            advance()
            continue
          }
          return press(raw)
        case .touchFight:
          if let raw = touchFight(snapshot) { return raw }
        case .expectPanel(let shown):
          expect(
            snapshot.showsPanel == shown, "the status panel visibility was \(snapshot.showsPanel)")
        case .expectTouchDamage:
          expect(
            snapshot.damage.byMember[PartyMember.miki.rawValue, default: 0] > 0
              && snapshot.damage.hits > 0 && maximumDamageLabels > 0,
            "touch Fire did not cause Miki damage with visible feedback")
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
              robotShots: snapshot.robotShots,
              guardPhase: snapshot.guardStrategy.map { String(describing: $0.phase) },
              legsLost: snapshot.guardStrategy?.detachedLegs.count,
              combatStance: String(describing: snapshot.combatStance),
              guardTarget: snapshot.guardTarget?.rawValue,
              committedPoint: snapshot.robotCommittedPoint.map { [$0.x, $0.y] },
              health: snapshot.guardStrategy?.health, damage: snapshot.damage))
          announce(label)
          advance()
        case .act:
          return press(
            usesTouch ? InputRules.Raw(touchAction: true) : InputRules.Raw(controllerAction: true))
        case .lock:
          return press(InputRules.Raw(controllerLock: true))
        case .swap:
          return press(InputRules.Raw(controllerSwap: true))
        case .grenade:
          return press(InputRules.Raw(controllerGrenade: true))
        case .expectGrenadeDamage:
          expect(
            snapshot.damage.grenade > 0 && snapshot.grenadeCooldown > 0,
            "Tom's manual grenade did not cause native blast damage")
        case .expectLegLoss:
          expect(
            snapshot.guardStrategy?.detachedLegs.isEmpty == false,
            "no leg detached through native sword contacts")
        case .dismantleGuard:
          if let raw = dismantleGuard(snapshot) { return raw }
        case .downDrones:
          if let raw = downDrones(snapshot) { return raw }
        case .companionDrones:
          if let raw = companionDrones(snapshot) { return raw }
        case .expectDronesDown(let count):
          expect(
            snapshot.dronesDown == count, "\(snapshot.dronesDown) drone(s) were down, not \(count)")
        case .downCrawlers:
          if let raw = downCrawlers(snapshot) { return raw }
        case .expectCrawlersDown(let count):
          expect(
            snapshot.crawlersDown == count,
            "\(snapshot.crawlersDown) crawler(s) were down, not \(count)")
        case .companionFight:
          if let raw = companionFight(snapshot) { return raw }
        case .companionPrerequisites:
          if (snapshot.guardStrategy?.health ?? GuardStrategy.maximumHealth) < GuardStrategy
            .maximumHealth - 150
          {
            advance()
            continue
          }
          if let raw = companionFight(snapshot) { return raw }
        case .defendGuard(let seconds):
          if let raw = defendGuard(snapshot, seconds: seconds) { return raw }
        case .settleDefendCover(let seconds, let hold):
          if let raw = settleDefendCover(snapshot, seconds: seconds, hold: hold) { return raw }
        case .expectCombatStance(let stance):
          expect(snapshot.combatStance == stance, "combat stance was \(snapshot.combatStance)")
        case .provokeRetaliation:
          if let raw = provokeRetaliation(snapshot) { return raw }
        case .leadWarnedMember:
          guard let member = retaliationMember, stepTime < 3 else {
            failures.append("no actual warned member was available for the control switch")
            advance()
            continue
          }
          if snapshot.leader == member {
            advance()
            continue
          }
          if guardRelease {
            guardRelease = false
            return InputRules.Raw()
          }
          guardRelease = true
          return InputRules.Raw(controllerSwitch: true)
        case .finishRetaliationCycle:
          if let raw = finishRetaliationCycle(snapshot) { return raw }
        case .waitForRetry(let seconds):
          if snapshot.beat == .crossing && snapshot.robotPhase == .hidden && !snapshot.isRetrying {
            // Retry restores the content before its fade finishes. Once it has finished,
            // release through the real input gate before attempting fresh movement.
            pressFrame += 1
            if pressFrame >= 3 { advance() }
            return InputRules.Raw()
          }
          if stepTime > seconds {
            failures.append("the encounter did not retry within \(Int(seconds)) s")
            advance()
            continue
          }
          return InputRules.Raw()
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
            case .attack: InputRules.Raw(dpadUp: true)
            case .defend: InputRules.Raw(dpadDown: true)
            case .bothGo: InputRules.Raw(keyboardBothGo: true)
            case .hold: InputRules.Raw(keyboardHold: true)
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
        case .dodgeGuard:
          guard let centre = snapshot.robotPosition,
            simd_distance(leaderPosition, centre) > 0.1
          else {
            failures.append("no guard was available for the ordinary dodge")
            advance()
            continue
          }
          let radial = leaderPosition - centre
          let tangent = simd_normalize(SIMD2(-radial.y, radial.x))
          let movement = PartyMotion(radius: PartyBody.radius, obstacles: snapshot.level.obstacles)
          let escape =
            movement.canTraverse(from: leaderPosition, to: leaderPosition + tangent * 3)
            ? tangent : -tangent
          return press(
            InputRules.Raw(
              stick: Movement.stick(towards: escape, cameraOffset: snapshot.level.cameraOffset),
              controllerDodge: true))
        case .expectDamageFeedback:
          expect(
            snapshot.damage.normal > 0 && snapshot.damage.weakpoint > 0
              && maximumDamageLabels > 0 && maximumDamageLabels <= DamageFeedback.maximumLabels,
            "ordinary and matched damage with bounded numbers were not observed")
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
            || snapshot.combatStance != .defend
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
      let stick = Movement.stick(towards: offset, cameraOffset: snapshot.level.cameraOffset)
      return usesTouch
        ? InputRules.Raw(touchStick: stick, touchIsTouching: true)
        : InputRules.Raw(stick: stick)
    }

    /// A real body tap, projected into the same normalized screen coordinates as UIKit.
    /// The test viewport is the baseline phone's 428 pt landscape height, not image pixels.
    private func targetTap(_ snapshot: Snapshot) -> InputRules.Raw? {
      guard let at = snapshot.robotPosition,
        let screen = snapshot.camera.screen(ofWorld: [at.x, 0.9, at.y]),
        (0...1).contains(screen.x), (0...1).contains(screen.y)
      else { return nil }
      return InputRules.Raw(
        touchTarget: .tap(
          InputRules.TargetTap(
            point: InputRules.ScreenPoint(x: screen.x, y: screen.y, aspect: snapshot.camera.aspect),
            viewHeight: 428)))
    }

    /// This driver has no manual aim. It holds Fire with the native touch lock and lets the
    /// explicitly ordered companions contribute, repositioning/rolling through touch movement.
    private mutating func touchFight(_ snapshot: Snapshot) -> InputRules.Raw? {
      if snapshot.defeated > 0 {
        advance()
        return nil
      }
      guard snapshot.combatStance == .attack, !snapshot.isRetrying,
        snapshot.beat == .stranger, stepTime <= 90,
        let centre = snapshot.robotPosition, let at = snapshot.positions[snapshot.leader]
      else {
        failures.append("touch-only combat failed to finish without a retry")
        advance()
        return nil
      }
      if guardRelease {
        guardRelease = false
        return InputRules.Raw()
      }
      if !snapshot.locked {
        guardRelease = true
        return targetTap(snapshot) ?? InputRules.Raw()
      }
      var raw = InputRules.Raw(touchFire: true)
      let radial = at - centre
      let committed = snapshot.robotPhase == .committed || snapshot.robotPhase == .burst
      if !committed {
        let destination = centre + (snapshot.robotFacing ?? [0, 1]) * 4.5
        if simd_distance(at, destination) > 0.25 {
          raw.touchStick = Movement.stick(
            towards: destination - at, cameraOffset: snapshot.level.cameraOffset)
          raw.touchIsTouching = true
        }
      }
      if snapshot.robotPhase == .committed, elapsed - lastGuardDodge > 1,
        simd_length(radial) > 0.1
      {
        let tangent = simd_normalize(SIMD2(-radial.y, radial.x))
        let movement = PartyMotion(radius: PartyBody.radius, obstacles: snapshot.level.obstacles)
        let escape = movement.canTraverse(from: at, to: at + tangent * 3) ? tangent : -tangent
        raw.touchStick = Movement.stick(towards: escape, cameraOffset: snapshot.level.cameraOffset)
        raw.touchIsTouching = true
        raw.touchDodge = true
        lastGuardDodge = elapsed
        guardRelease = true
      }
      return raw
    }

    private mutating func expect(_ holds: Bool, _ found: String) {
      if !holds { failures.append("\(found) at \(Self.seconds(elapsed))") }
      advance()
    }

    /// Native cooperation with no automatic leader switch or fire after Miki's opening hit.
    /// The script may reposition/roll Miki to keep the fight engaged, just as a player can.
    private mutating func companionFight(
      _ snapshot: Snapshot, allowLeaderFire: Bool = true
    ) -> InputRules.Raw? {
      guard snapshot.leader == .miki else {
        failures.append("companion fight took control from Miki")
        advance()
        return nil
      }
      guard snapshot.combatStance == .attack else {
        failures.append("companion fight requires an explicit Attack order")
        advance()
        return nil
      }
      if snapshot.defeated > 0 {
        advance()
        return nil
      }
      if snapshot.isRetrying || snapshot.beat != .stranger || stepTime > 90 {
        failures.append(
          "companions did not dismantle the guard without a retry; "
            + "stage \(String(describing: snapshot.guardStrategy?.phase)), "
            + "legs lost \(snapshot.guardStrategy?.detachedLegs.count ?? 0), "
            + "activities \(snapshot.companionActivities)")
        advance()
        return nil
      }
      guard let strategy = snapshot.guardStrategy, let centre = snapshot.robotPosition,
        let at = snapshot.positions[.miki]
      else { return InputRules.Raw() }
      for member in [PartyMember.laura, .tom] {
        guard let activity = snapshot.companionActivities[member],
          [.approaching, .attacking, .avoiding].contains(activity)
        else { continue }
        let label = "\(member.displayName) \(activity.rawValue) \(strategy.phase)"
        if companionMarks.insert(label).inserted {
          recordGuardMark(label, snapshot: snapshot)
        }
      }
      if guardStageSeen != strategy.phase {
        guardStageSeen = strategy.phase
        recordGuardMark("companions: \(strategy.phase)", snapshot: snapshot)
      }
      if guardRelease {
        guardRelease = false
        return InputRules.Raw()
      }
      if snapshot.damage.byMember[PartyMember.miki.rawValue, default: 0] == 0
        && snapshot.weapon.kind != .longRifle
      {
        guardRelease = true
        return InputRules.Raw(controllerSwap: true)
      }
      if !snapshot.locked {
        guardRelease = true
        return InputRules.Raw(controllerLock: true)
      }
      var raw = InputRules.Raw()
      let radial = at - centre
      let distance = simd_length(radial)
      let committed = snapshot.robotPhase == .committed || snapshot.robotPhase == .burst
      if !committed {
        // Close enough that both side specialists remain inside their ordinary 8 m leash,
        // while staying outside the solid hull. Front positioning provokes repeat openings.
        let direction = snapshot.robotFacing ?? [0, 1]
        let destination = centre + direction * 4.5
        if simd_distance(at, destination) > 0.25 {
          raw.stick = Movement.stick(
            towards: destination - at, cameraOffset: snapshot.level.cameraOffset)
        }
      }
      if snapshot.robotPhase == .committed, elapsed - lastGuardDodge > 1, distance > 0.1 {
        let tangent = simd_normalize(SIMD2(-radial.y, radial.x))
        let movement = PartyMotion(radius: PartyBody.radius, obstacles: snapshot.level.obstacles)
        let escape = movement.canTraverse(from: at, to: at + tangent * 3) ? tangent : -tangent
        raw.stick = Movement.stick(
          towards: escape, cameraOffset: snapshot.level.cameraOffset)
        raw.controllerDodge = true
        lastGuardDodge = elapsed
        guardRelease = true
        return raw
      }
      if allowLeaderFire,
        snapshot.damage.byMember[PartyMember.miki.rawValue, default: 0] == 0,
        let point = snapshot.guardPoints.first(where: { $0.part == .eye })
      {
        raw.aimStick = Movement.stick(
          towards: point.ground - at, cameraOffset: snapshot.level.cameraOffset)
        raw.controllerFire = point.exposed
      }
      return raw
    }

    /// Observe ordinary simulation snapshots; never prolong the opening or stop player fire.
    private mutating func observeLegStagger(_ snapshot: Snapshot) {
      let previous = previousLegsLost
      previousLegsLost = snapshot.guardStrategy?.detachedLegs.count
      if legStagger == nil, previous == 0, let count = previousLegsLost, count > 0,
        let health = snapshot.guardStrategy?.health, health > 0
      {
        guard snapshot.robotPhase == .staggered else {
          failures.append("the first nonlethal leg break did not enter stagger")
          recordGuardMark("leg break missed stagger", snapshot: snapshot)
          return
        }
        // A shot may already have resolved earlier in this same fixed step. Only subsequent
        // continuously staggered observations can establish a shot during the opening.
        legStagger = Summary.LegStagger(
          firstShotSerial: snapshot.robotShots, lastShotSerial: snapshot.robotShots,
          staggeredSamples: 1)
        legStaggerStartedAt = elapsed
        recordGuardMark("leg-break stagger begins", snapshot: snapshot)
        return
      }
      guard var observed = legStagger else { return }
      if !observed.completed {
        if snapshot.robotPhase == .staggered {
          let extraShots = max(0, snapshot.robotShots - observed.lastShotSerial)
          if extraShots > 0 && observed.shotsDuringStagger == 0 {
            failures.append("the guard fired during a continuously observed leg-break stagger")
          }
          observed.shotsDuringStagger += extraShots
          observed.lastShotSerial = snapshot.robotShots
          observed.staggeredSamples += 1
          observed.observedSeconds = Double(max(0, elapsed - legStaggerStartedAt))
        } else {
          observed.completed = true
          recordGuardMark("leg-break stagger ends", snapshot: snapshot)
        }
      }
      if observed.completed, !observed.freshWarningObserved, snapshot.robotPhase == .notice,
        snapshot.guardTarget != nil
      {
        observed.freshWarningObserved = true
        recordGuardMark("fresh warning after leg-break stagger", snapshot: snapshot)
      }
      legStagger = observed
    }

    private mutating func recordGuardMark(
      _ label: String, snapshot: Snapshot, longestCoverHoldSeconds: Float? = nil
    ) {
      marks.append(
        Summary.Mark(
          name: label, seconds: Double(elapsed),
          robotPhase: snapshot.robotPhase.map { String(describing: $0) },
          robotShots: snapshot.robotShots,
          guardPhase: snapshot.guardStrategy.map { String(describing: $0.phase) },
          legsLost: snapshot.guardStrategy?.detachedLegs.count,
          companionActivities: Dictionary(
            uniqueKeysWithValues: snapshot.companionActivities.map {
              ($0.key.rawValue, $0.value.rawValue)
            }), combatStance: String(describing: snapshot.combatStance),
          guardTarget: snapshot.guardTarget?.rawValue,
          committedPoint: snapshot.robotCommittedPoint.map { [$0.x, $0.y] },
          partyPositions: Dictionary(
            uniqueKeysWithValues: snapshot.positions.map {
              ($0.key.rawValue, [$0.value.x, $0.value.y])
            }),
          companionTargets: Dictionary(
            uniqueKeysWithValues: snapshot.companionTargets.map {
              ($0.key.rawValue, [$0.value.x, $0.value.y])
            }),
          coveredMembers: snapshot.coveredMembers.map(\.rawValue).sorted(),
          longestCoverHoldSeconds: longestCoverHoldSeconds,
          health: snapshot.guardStrategy?.health, damage: snapshot.damage))
      announce(label)
    }

    /// Tom supplies no Fire: real Miki/Laura attacks must provoke a later named warning.
    private mutating func provokeRetaliation(_ snapshot: Snapshot) -> InputRules.Raw? {
      guard snapshot.leader == .tom, snapshot.combatStance == .attack,
        !snapshot.isRetrying, snapshot.defeated == 0, stepTime <= 60
      else {
        failures.append(
          "no live companion retaliation warning within the player-controlled attempt")
        advance()
        return nil
      }
      if let member = snapshot.guardTarget, member != snapshot.leader,
        snapshot.robotPhase == .notice || snapshot.robotPhase == .tracking
      {
        retaliationMember = member
        recordGuardMark("Guard warns \(member.displayName)", snapshot: snapshot)
        advance()
        return nil
      }
      return retaliationFootwork(snapshot)
    }

    /// A switch and Defend cannot transfer an attack that has already named its target.
    private mutating func finishRetaliationCycle(_ snapshot: Snapshot) -> InputRules.Raw? {
      guard let member = retaliationMember, !snapshot.isRetrying, stepTime <= 20 else {
        failures.append("the warned retaliation cycle did not complete safely")
        advance()
        return nil
      }
      let phases: [RobotGuard.Phase] = [.notice, .tracking, .committed, .burst, .recovering]
      guard let phase = snapshot.robotPhase, phases.contains(phase), snapshot.guardTarget == member
      else {
        failures.append("the guard changed its warned member during the cycle")
        advance()
        return nil
      }
      if let point = snapshot.robotCommittedPoint {
        if let previous = retaliationPoint, point != previous {
          failures.append("the committed point followed the new leader or moving target")
          advance()
          return nil
        }
        if retaliationPoint == nil {
          retaliationPoint = point
          recordGuardMark("Retaliation committed to \(member.displayName)", snapshot: snapshot)
        }
      }
      if phase == .recovering {
        if retaliationPoint == nil || !retaliationDodged {
          failures.append("the retaliation route missed the real commitment or escape input")
        }
        recordGuardMark("Retaliation recovered on the same target", snapshot: snapshot)
        advance()
        return nil
      }
      if guardRelease {
        guardRelease = false
        return InputRules.Raw()
      }
      if phase == .committed, !retaliationDodged,
        let centre = snapshot.robotPosition, let at = snapshot.positions[snapshot.leader],
        simd_distance(at, centre) > 0.1
      {
        let radial = at - centre
        let tangent = simd_normalize(SIMD2(-radial.y, radial.x))
        let movement = PartyMotion(radius: PartyBody.radius, obstacles: snapshot.level.obstacles)
        let escape = movement.canTraverse(from: at, to: at + tangent * 3) ? tangent : -tangent
        retaliationDodged = true
        guardRelease = true
        return InputRules.Raw(
          stick: Movement.stick(towards: escape, cameraOffset: snapshot.level.cameraOffset),
          controllerDodge: true)
      }
      return InputRules.Raw()
    }

    private mutating func retaliationFootwork(_ snapshot: Snapshot) -> InputRules.Raw {
      guard let centre = snapshot.robotPosition, let at = snapshot.positions[snapshot.leader]
      else { return InputRules.Raw() }
      if guardRelease {
        guardRelease = false
        return InputRules.Raw()
      }
      var raw = InputRules.Raw()
      let radial = at - centre
      if snapshot.robotPhase == .committed, elapsed - lastGuardDodge > 1,
        simd_length(radial) > 0.1
      {
        let tangent = simd_normalize(SIMD2(-radial.y, radial.x))
        let movement = PartyMotion(radius: PartyBody.radius, obstacles: snapshot.level.obstacles)
        let escape = movement.canTraverse(from: at, to: at + tangent * 3) ? tangent : -tangent
        raw.stick = Movement.stick(towards: escape, cameraOffset: snapshot.level.cameraOffset)
        raw.controllerDodge = true
        lastGuardDodge = elapsed
        guardRelease = true
      } else if snapshot.robotPhase != .committed && snapshot.robotPhase != .burst {
        let destination = centre + (snapshot.robotFacing ?? [0, 1]) * 4.5
        if simd_distance(at, destination) > 0.25 {
          raw.stick = Movement.stick(
            towards: destination - at, cameraOffset: snapshot.level.cameraOffset)
        }
      }
      return raw
    }

    /// Observe an actual cease-fire while returning companions remain subject to real
    /// movement, cover and incoming attacks. Only the player's ordinary escape inputs run.
    private mutating func defendGuard(_ snapshot: Snapshot, seconds: Float) -> InputRules.Raw? {
      guard snapshot.combatStance == .defend, snapshot.orders.isEmpty,
        !snapshot.isRetrying, let current = snapshot.guardStrategy,
        let leader = snapshot.positions[snapshot.leader]
      else {
        failures.append("Defend did not clear orders and maintain the active fight")
        advance()
        return nil
      }
      if defendBaseline == nil {
        defendBaseline = current
        defendLoaded = snapshot.partyWeapons.mapValues(\.loaded)
        defendDistances = Dictionary(
          uniqueKeysWithValues: snapshot.positions.compactMap {
            $0.key == snapshot.leader ? nil : ($0.key, simd_distance($0.value, leader))
          })
        defendClosestDistances = defendDistances
        defendPreviousPositions = snapshot.positions
      }
      for member in defendDistances.keys {
        guard let position = snapshot.positions[member],
          let previous = defendPreviousPositions[member]
        else { continue }
        let gap = simd_distance(position, leader)
        defendClosestDistances[member] = min(defendClosestDistances[member] ?? gap, gap)
        // Compare both follower positions against this frame's leader. A leader moving
        // towards a stationary follower cannot supply the companion's return evidence.
        defendApproach[member, default: 0] += max(0, simd_distance(previous, leader) - gap)
      }
      defendPreviousPositions = snapshot.positions
      let stopped =
        current.health == defendBaseline?.health
        && current.detachedLegs == defendBaseline?.detachedLegs
        && current.swordHits == defendBaseline?.swordHits
      let spent = snapshot.partyWeapons.contains { member, state in
        member != snapshot.leader && state.loaded < (defendLoaded[member] ?? state.loaded)
      }
      if !stopped || spent || snapshot.companionActivities.values.contains(.attacking) {
        failures.append("a companion attacked or spent rounds after Defend")
        advance()
        return nil
      }
      defendLoaded = snapshot.partyWeapons.mapValues(\.loaded)
      if stepTime >= seconds {
        let distant = defendDistances.filter { $0.value > 3 }
        let returned =
          distant.isEmpty
          || distant.contains { member, gap in
            guard snapshot.positions[member] != nil,
              defendApproach[member, default: 0] >= 0.5,
              let closest = defendClosestDistances[member]
            else { return false }
            // The ordinary late roll can widen the final gap after a successful return.
            return closest < gap - 0.5 || closest <= 2.6
          }
        if !returned {
          failures.append("Defend did not bring a distant companion toward the leader")
        }
        recordGuardMark("Defend recalled without companion fire", snapshot: snapshot)
        advance()
        return nil
      }
      var raw = InputRules.Raw()
      if guardRelease {
        guardRelease = false
      } else if snapshot.robotPhase == .committed, elapsed - lastGuardDodge > 1,
        let centre = snapshot.robotPosition, simd_distance(leader, centre) > 0.1
      {
        let radial = leader - centre
        let tangent = simd_normalize(SIMD2(-radial.y, radial.x))
        let movement = PartyMotion(radius: PartyBody.radius, obstacles: snapshot.level.obstacles)
        let escape =
          movement.canTraverse(from: leader, to: leader + tangent * 3) ? tangent : -tangent
        raw.stick = Movement.stick(towards: escape, cameraOffset: snapshot.level.cameraOffset)
        raw.controllerDodge = true
        lastGuardDodge = elapsed
        guardRelease = true
      }
      return raw
    }

    /// Cover destinations alone cannot pass: both actual bodies must arrive, remain behind
    /// the real two-barrel cover query and keep useful clearance for a continuous interval.
    private mutating func settleDefendCover(
      _ snapshot: Snapshot, seconds: Float, hold: Float
    ) -> InputRules.Raw? {
      guard snapshot.mode == .exploring, snapshot.combatStance == .defend,
        snapshot.orders.isEmpty, snapshot.beat == .stranger, !snapshot.isRetrying,
        snapshot.defeated == 0, snapshot.robotPosition != nil,
        let phase = snapshot.robotPhase, ![.hidden, .down, .cleared].contains(phase),
        let strategy = snapshot.guardStrategy, let leader = snapshot.positions[snapshot.leader],
        seconds.isFinite, seconds > 0, hold.isFinite, hold >= 0.5, hold <= seconds
      else {
        failures.append("cover settlement requires an active defended guard fight")
        advance()
        return nil
      }
      if defendBaseline == nil {
        defendBaseline = strategy
        defendLoaded = snapshot.partyWeapons.mapValues(\.loaded)
      }
      let progressed =
        strategy.health != defendBaseline?.health
        || strategy.detachedLegs != defendBaseline?.detachedLegs
        || strategy.swordHits != defendBaseline?.swordHits
      let spent = snapshot.partyWeapons.contains { member, weapon in
        member != snapshot.leader && weapon.loaded < (defendLoaded[member] ?? weapon.loaded)
      }
      if progressed || spent || snapshot.companionActivities.values.contains(.attacking) {
        failures.append("a companion attacked while settling behind cover")
        advance()
        return nil
      }
      defendLoaded = snapshot.partyWeapons.mapValues(\.loaded)
      let followers = snapshot.party.filter { $0 != snapshot.leader }
      let staging = SIMD2<Float>(6.5, 10)
      let atStaging = simd_distance(leader, staging) <= 0.25
      let settled =
        atStaging && followers.count == 2
        && followers.allSatisfy { member in
          guard let body = snapshot.positions[member],
            let target = snapshot.companionTargets[member]
          else { return false }
          return snapshot.coveredMembers.contains(member)
            && simd_distance(body, target) <= 0.35
            && simd_distance(body, leader) >= 1.2 && simd_distance(body, leader) <= 2.6
            && followers.filter { $0 != member }.allSatisfy { other in
              guard let otherBody = snapshot.positions[other],
                let otherTarget = snapshot.companionTargets[other]
              else { return false }
              return simd_distance(body, otherBody) >= 1.2
                && simd_distance(target, otherTarget) >= 1.2
            }
        }
      if settled {
        let moved = followers.contains { member in
          guard let first = coverStablePositions[member], let body = snapshot.positions[member]
          else { return true }
          return simd_distance(first, body) > 0.25
        }
        if coverStableSince == nil || moved {
          coverStableSince = stepTime
          coverStablePositions = snapshot.positions
        }
        let held = stepTime - (coverStableSince ?? stepTime)
        longestCoverHold = max(longestCoverHold, held)
        if held >= hold {
          recordGuardMark(
            "Defend settled in separate cover", snapshot: snapshot,
            longestCoverHoldSeconds: longestCoverHold)
          advance()
          return nil
        }
      } else {
        coverStableSince = nil
        coverStablePositions = [:]
      }
      if stepTime > seconds {
        recordGuardMark(
          "Defend cover settlement failed", snapshot: snapshot,
          longestCoverHoldSeconds: longestCoverHold)
        failures.append("both companions did not settle in separate covered positions")
        advance()
        return nil
      }
      // The player's ordinary roll is still available during recall. No planner or damage
      // state is changed to protect the leader while observing the real companions.
      if guardRelease {
        guardRelease = false
        return InputRules.Raw()
      }
      if phase != .committed && phase != .burst, !atStaging {
        return InputRules.Raw(
          stick: Movement.stick(
            towards: staging - leader, cameraOffset: snapshot.level.cameraOffset))
      }
      if phase == .committed, elapsed - lastGuardDodge > 1,
        let centre = snapshot.robotPosition, simd_distance(leader, centre) > 0.1
      {
        let radial = leader - centre
        let tangent = simd_normalize(SIMD2(-radial.y, radial.x))
        let movement = PartyMotion(radius: PartyBody.radius, obstacles: snapshot.level.obstacles)
        let escape =
          movement.canTraverse(from: leader, to: leader + tangent * 3) ? tangent : -tangent
        lastGuardDodge = elapsed
        guardRelease = true
        return InputRules.Raw(
          stick: Movement.stick(towards: escape, cameraOffset: snapshot.level.cameraOffset),
          controllerDodge: true)
      }
      return InputRules.Raw()
    }

    /// A bounded player script, not a simulation shortcut: no teleports, state writes or
    /// damage immunity. It observes the same component markers that the player sees.
    private mutating func downCrawlers(_ snapshot: Snapshot) -> InputRules.Raw? {
      let standing = snapshot.crawlers.filter { $0.phase != .down }
      if standing.isEmpty {
        // Under Attack the companions shoot the crawlers closing in, as well as Miki.
        let companionDamage = snapshot.crawlers.reduce(0) { total, crawler in
          total
            + [PartyMember.tom, .laura].reduce(0) {
              $0 + (snapshot.damage.byTarget[crawler.id]?[$1.rawValue] ?? 0)
            }
        }
        if snapshot.combatStance == .attack, companionDamage == 0 {
          failures.append("no crawler took a companion's fire under Attack")
        }
        advance()
        return nil
      }
      if snapshot.isRetrying || snapshot.beat != .stranger || stepTime > 60 {
        failures.append(
          "\(standing.count) crawler(s) still stood or the fight retried at \(Self.seconds(elapsed))"
        )
        advance()
        return nil
      }
      if guardRelease {
        guardRelease = false
        return InputRules.Raw()
      }
      if snapshot.leader != .miki {
        guardRelease = true
        return InputRules.Raw(controllerSwitch: true)
      }
      guard let at = snapshot.positions[.miki],
        let target = standing.min(by: {
          simd_distance($0.position, at) < simd_distance($1.position, at)
        })
      else { return InputRules.Raw() }
      var raw = InputRules.Raw()
      let movement = PartyMotion(radius: PartyBody.radius, obstacles: snapshot.level.obstacles)
      func roll(across line: SIMD2<Float>) -> InputRules.Raw {
        let across =
          simd_length(line) > 0.01 ? simd_normalize(SIMD2(-line.y, line.x)) : SIMD2<Float>(1, 0)
        let side = movement.canTraverse(from: at, to: at + across * 3) ? across : -across
        var raw = InputRules.Raw()
        raw.stick = Movement.stick(towards: side, cameraOffset: snapshot.level.cameraOffset)
        raw.controllerDodge = true
        lastGuardDodge = elapsed
        guardRelease = true
        return raw
      }
      // A committed volley does not home in: roll across the guard's line, as dismantleGuard.
      if snapshot.robotPhase == .committed, elapsed - lastGuardDodge > 1,
        let centre = snapshot.robotPosition, simd_distance(at, centre) > 0.1
      {
        return roll(across: at - centre)
      }
      // Nor does a ram: once a crawler's line covers her, roll out of it.
      if elapsed - lastGuardDodge > 0.8,
        let ram = standing.first(where: { crawler in
          guard crawler.phase == .windingUp || crawler.phase == .ramming,
            let start = crawler.ramStart, let end = crawler.ramEnd
          else { return false }
          return Crawler.distance(from: at, toSegment: start, end) < Crawler.reach + 0.4
        }), let start = ram.ramStart, let end = ram.ramEnd
      {
        return roll(across: end - start)
      }
      // The aim help lowers the round to the nearest crawler; the route sets no lock.
      let delta = target.position - at
      if simd_length(delta) > 0.001 {
        raw.aimStick = Movement.stick(towards: delta, cameraOffset: snapshot.level.cameraOffset)
      }
      raw.controllerFire = true
      return raw
    }

    private mutating func downDrones(_ snapshot: Snapshot) -> InputRules.Raw? {
      let flying = snapshot.drones.filter { $0.phase != .down }
      if flying.isEmpty {
        advance()
        return nil
      }
      if snapshot.isRetrying || snapshot.beat != .stranger || stepTime > 60 {
        failures.append(
          "\(flying.count) drone(s) still flew or the fight retried at \(Self.seconds(elapsed))")
        advance()
        return nil
      }
      if guardRelease {
        guardRelease = false
        return InputRules.Raw()
      }
      if snapshot.leader != .miki {
        guardRelease = true
        return InputRules.Raw(controllerSwitch: true)
      }
      guard let at = snapshot.positions[.miki],
        let target = flying.min(by: {
          simd_distance($0.position, at) < simd_distance($1.position, at)
        })
      else { return InputRules.Raw() }
      var raw = InputRules.Raw()
      let movement = PartyMotion(radius: PartyBody.radius, obstacles: snapshot.level.obstacles)
      // A committed volley does not home in: roll across the guard's line, as dismantleGuard.
      if snapshot.robotPhase == .committed, elapsed - lastGuardDodge > 1,
        let centre = snapshot.robotPosition, simd_distance(at, centre) > 0.1
      {
        let radial = at - centre
        let tangent = simd_normalize(SIMD2(-radial.y, radial.x))
        let side = movement.canTraverse(from: at, to: at + tangent * 3) ? tangent : -tangent
        raw.stick = Movement.stick(towards: side, cameraOffset: snapshot.level.cameraOffset)
        raw.controllerDodge = true
        lastGuardDodge = elapsed
        guardRelease = true
        return raw
      }
      // Neither does a dive: once one commits near her, step across its line before it fires.
      if let dive = flying.first(where: {
        $0.phase == .diving
          && ($0.committedPoint.map { simd_distance($0, at) < ScoutDrone.danger }
            ?? false)
      }) {
        let line = at - dive.position
        let across =
          simd_length(line) > 0.01 ? simd_normalize(SIMD2(-line.y, line.x)) : SIMD2<Float>(1, 0)
        let side = movement.canTraverse(from: at, to: at + across * 1.5) ? across : -across
        raw.stick = Movement.stick(towards: side, cameraOffset: snapshot.level.cameraOffset)
      }
      // The aim help raises the round to the nearest drone; the route sets no lock.
      let delta = target.position - at
      if simd_length(delta) > 0.001 {
        raw.aimStick = Movement.stick(towards: delta, cameraOffset: snapshot.level.cameraOffset)
      }
      raw.controllerFire = true
      return raw
    }

    /// The leader supplies only movement, aim/lock and dodge input. Damage evidence must
    /// name a drone and a follower; a guard death that drops its drones cannot pass this.
    private mutating func companionDrones(_ snapshot: Snapshot) -> InputRules.Raw? {
      guard !snapshot.isRetrying, snapshot.beat == .stranger,
        (snapshot.guardStrategy?.health ?? 0) > 0, stepTime <= 60
      else {
        failures.append(
          "companions did not down a drone before the guard died or the fight retried")
        advance()
        return nil
      }
      if snapshot.damage.byMember[PartyMember.miki.rawValue, default: 0] != 0 {
        failures.append("the companion-drone route allowed player damage")
        advance()
        return nil
      }
      if snapshot.dronesDown > 0 {
        let down = snapshot.drones.filter { $0.phase == .down }
        let followerDamage = down.reduce(0) { total, drone in
          total
            + [PartyMember.tom, .laura].reduce(0) {
              $0 + (snapshot.damage.byTarget[drone.id]?[$1.rawValue] ?? 0)
            }
        }
        if followerDamage < ScoutDrone.health {
          failures.append("no defeated drone had native follower-attributed damage")
        }
        recordGuardMark("companion drone down", snapshot: snapshot)
        advance()
        return nil
      }
      guard var raw = companionFight(snapshot, allowLeaderFire: false),
        let at = snapshot.positions[.miki]
      else { return nil }
      if !raw.controllerDodge,
        let dive = snapshot.drones.first(where: {
          $0.phase == .diving
            && ($0.committedPoint.map { simd_distance($0, at) < ScoutDrone.danger } ?? false)
        })
      {
        let line = at - dive.position
        let across =
          simd_length(line) > 0.01 ? simd_normalize(SIMD2(-line.y, line.x)) : SIMD2<Float>(1, 0)
        let movement = PartyMotion(radius: PartyBody.radius, obstacles: snapshot.level.obstacles)
        let side = movement.canTraverse(from: at, to: at + across * 1.5) ? across : -across
        raw.stick = Movement.stick(towards: side, cameraOffset: snapshot.level.cameraOffset)
      }
      return raw
    }

    private mutating func dismantleGuard(_ snapshot: Snapshot) -> InputRules.Raw? {
      if snapshot.defeated > 0 {
        // The crossing/order scenarios begin as Miki. Return through the real cycle so later
        // checks retain their intended squad roles, rather than inheriting Tom by accident.
        if guardRelease {
          guardRelease = false
          return InputRules.Raw()
        }
        if snapshot.leader != .miki {
          guardRelease = true
          return InputRules.Raw(controllerSwitch: true)
        }
        advance()
        return nil
      }
      if snapshot.isRetrying || snapshot.beat != .stranger || stepTime > 60 {
        failures.append(
          "guard combination failed or retried at \(Self.seconds(elapsed)); "
            + "\(snapshot.leader.displayName) at "
            + Self.describe(snapshot.positions[snapshot.leader] ?? [.nan, .nan])
            + "; stage \(String(describing: snapshot.guardStrategy?.phase)), "
            + "legs lost \(snapshot.guardStrategy?.detachedLegs.count ?? 0), "
            + "robot \(String(describing: snapshot.robotPhase))")
        advance()
        return nil
      }
      if guardRelease {
        guardRelease = false
        return InputRules.Raw()
      }
      guard let strategy = snapshot.guardStrategy, let centre = snapshot.robotPosition,
        let at = snapshot.positions[snapshot.leader]
      else { return InputRules.Raw() }
      // This player script explicitly commits the squad. Normal companion support is useful
      // throughout the longer health-based fight; no automatic permission bypass supplies it.
      if !strategy.detachedLegs.isEmpty && snapshot.combatStance != .attack {
        guardRelease = true
        return InputRules.Raw(dpadUp: true)
      }
      if guardStageSeen != strategy.phase {
        guardStageSeen = strategy.phase
        recordGuardMark("eye and legs", snapshot: snapshot)
      }
      let member: PartyMember
      let kind: Weapon.Kind
      if strategy.detachedLegs.isEmpty {
        member = .laura
        kind = .energySword
      } else if snapshot.damage.weakpoint == 0 {
        member = .miki
        kind = .longRifle
      } else {
        member = .tom
        kind = .minigun
      }
      if snapshot.leader != member {
        guardRelease = true
        return InputRules.Raw(controllerSwitch: true)
      }
      if snapshot.weapon.kind != kind {
        guardRelease = true
        return InputRules.Raw(controllerSwap: true)
      }
      let candidates = snapshot.guardPoints.filter {
        if member == .laura {
          if case .leg = $0.part { return true }
          return false
        }
        return $0.part == .eye
      }
      guard
        let point = candidates.min(by: {
          simd_distance_squared($0.ground, at) < simd_distance_squared($1.ground, at)
        })
      else { return InputRules.Raw() }
      let delta = point.ground - at
      var raw = InputRules.Raw()
      let radial = at - centre
      let distance = simd_length(radial)
      var needsPeek = false
      if member == .laura {
        // Repeated native swings on the nearest intact leg; movement remains outside hull.
        let side = simd_normalize(point.ground - centre)
        let radius: Float = 2.4
        var destination = centre + side * radius
        if distance > 0.1 {
          let direction = radial / distance
          let cross = direction.x * side.y - direction.y * side.x
          if simd_dot(direction, side) < 0.9 {
            let angle: Float = cross >= 0 ? 0.35 : -0.35
            let rotated = SIMD2(
              direction.x * cos(angle) - direction.y * sin(angle),
              direction.x * sin(angle) + direction.y * cos(angle))
            destination = centre + rotated * max(radius, distance)
          }
        }
        let approach = destination - at
        if simd_length(approach) > 0.18 {
          raw.stick = Movement.stick(
            towards: approach, cameraOffset: snapshot.level.cameraOffset)
        }
      } else {
        let ballistics = Ballistics(level: snapshot.level)
        let clearShot = ballistics.isClear(from: ballistics.point(at), to: point.centre)
        let visibleBody = ballistics.isClear(
          from: ballistics.point(centre, above: 1.52), to: ballistics.point(at))
        needsPeek = !clearShot || !visibleBody
        if needsPeek {
          // The new rear cover can hide a rolled leader at a perfectly valid rifle range.
          // Peek through the authored central lane using ordinary input, rather than keep
          // firing into a barrier or waiting forever for an unseen guard to recover.
          let movement = PartyMotion(radius: PartyBody.radius, obstacles: snapshot.level.obstacles)
          let front = SIMD2<Float>(6.5, 8)
          let rear = SIMD2<Float>(6.5, 10.6)
          let destination = movement.canTraverse(from: at, to: front) ? front : rear
          if movement.canTraverse(from: at, to: destination), simd_distance(at, destination) > 0.15
          {
            raw.stick = Movement.stick(
              towards: destination - at, cameraOffset: snapshot.level.cameraOffset)
          }
        } else if distance > 11 || distance < 5 {
          let away = distance > 0.1 ? radial / distance : snapshot.robotFacing ?? [0, 1]
          raw.stick = Movement.stick(
            towards: centre + away * 8 - at, cameraOffset: snapshot.level.cameraOffset)
        }
      }
      // A committed volley does not home in. A real roll crosses its old line; its ordinary
      // cooldown and vulnerability rules still apply; eye criticals have no exposure timer.
      if snapshot.robotPhase == .committed, elapsed - lastGuardDodge > 1,
        member != .laura, distance > 0.1
      {
        let tangent = SIMD2(-radial.y, radial.x)
        raw.stick = Movement.stick(
          towards: tangent, cameraOffset: snapshot.level.cameraOffset)
        raw.controllerDodge = true
        lastGuardDodge = elapsed
        guardRelease = true
        return raw
      }
      if needsPeek { return raw }
      if !snapshot.locked {
        guardRelease = true
        return InputRules.Raw(controllerLock: true)
      }
      if simd_length(delta) > 0.001 {
        raw.aimStick = Movement.stick(
          towards: delta, cameraOffset: snapshot.level.cameraOffset)
      }
      // Every real contact counts. Sword hits must actually reach a surviving leg.
      raw.controllerFire =
        member != .laura
        || simd_length(delta) < Weapon.energySword.range + point.radius
      return raw
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
      defendBaseline = nil
      defendLoaded = [:]
      defendDistances = [:]
      defendClosestDistances = [:]
      defendApproach = [:]
      defendPreviousPositions = [:]
      coverStableSince = nil
      coverStablePositions = [:]
      longestCoverHold = 0
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
      if name == "robot-parts",
        legStagger?.completed != true || (legStagger?.staggeredSamples ?? 0) < 2
      {
        failures.append("robot-parts did not observe a complete nonlethal leg-break stagger")
      }
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
        worstLeaderGap: Double(worstGap),
        peakPartyHits: Dictionary(
          uniqueKeysWithValues: peakPartyHits.map { ($0.key.rawValue, $0.value) }),
        retryCount: retryCount, damage: observedDamage, maximumDamageLabels: maximumDamageLabels,
        nonTouchInputFrames: usesTouch ? nonTouchInputFrames : nil,
        legStagger: legStagger)
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
        .dismantleGuard, .expectDefeated(1), .mark("guard disabled"), .walk([6.5, -12]),
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
        .waitForRobotPhase(.committed, seconds: 3), .mark("guard committed"), .dodgeGuard,
        .waitForRobotPhase(.burst, seconds: 2), .mark("guard burst"),
        .waitForRobotPhase(.recovering, seconds: 2), .expectRobotShots(atLeast: 3),
        .mark("guard recovery"),
        .dismantleGuard, .expectDefeated(1), .mark("guard disabled"), .expectHits(0),
        .wait(seconds: 1),
      ] + restartRun

    /// Standing in the open takes at most one hit per burst. The third starts the encounter
    /// again at its checkpoint with inventory restored; the second attempt returns fire.
    private static let fightRetry: [Step] =
      toTheStranger + [
        .waitForRetry(seconds: 90), .expectBeat(.crossing), .expectHits(0), .expectDefeated(0),
        .mark("retry"),
        .walk([6.5, 10]), .expectBeat(.stranger), .dismantleGuard,
        .expectDefeated(1), .mark("won after the retry"),
      ]

    /// The lock (ADR 0020) in the first fight: a press of the right stick locks on the guard and
    /// rings it in red, Fire takes it with the stick at rest, and once it is down the lock lets
    /// go.
    private static let lockOn: [Step] =
      toTheStranger + [
        .wait(seconds: 0.5), .lock, .expectLock(true), .wait(seconds: 0.6),
        .mark("locked on the guard"), .dismantleGuard, .expectDefeated(1), .expectLock(false),
        .mark("guard down, lock let go"), .wait(seconds: 1),
      ] + restartRun

    /// Tom's two weapons in the first fight (ADR 0021): he raises his dome against the guard's
    /// bursts and nobody is hurt. A short ordinary minigun burst damages the guard, then the
    /// optional weak-point route demonstrates the party's larger bonuses.
    private static let weapons: [Step] =
      toTheStranger + [
        .order(.hold),
        .switchLeader, .swap, .wait(seconds: 0.3), .fire(seconds: 2.5), .mark("Tom's dome"),
        .fire(seconds: 2), .expectHits(0), .swap, .wait(seconds: 0.3), .fire(seconds: 1),
        .expectDefeated(0), .mark("ordinary minigun damage"), .formation, .dismantleGuard,
        .expectDefeated(1), .mark("guard dismantled by the party"), .wait(seconds: 1),
      ] + restartRun

    /// Miki supplies only the sensor shot; her two companions move and fight for themselves.
    private static let companions: [Step] =
      toTheStranger + [
        .order(.attack), .expectCombatStance(.attack), .mark("Attack permits companions"),
        .companionPrerequisites, .order(.hold), .order(.defend), .expectCombatStance(.defend),
        .mark("Defend recalls the squad"), .defendGuard(seconds: 3),
        .order(.attack), .expectCombatStance(.attack), .mark("Attack resumes companions"),
        .companionFight, .expectDefeated(1), .expectParty([.miki, .tom, .laura]),
        .mark("guard dismantled without switching"), .wait(seconds: 1),
      ] + restartRun

    /// A real attacking follower earns the next warning. Switching to another member and
    /// ordering Defend retains the named/committed target; Attack later resumes cooperation.
    private static let retaliation: [Step] =
      [
        .mark("start"), .switchLeader, .walk([6.5, 66]), .walk([6.5, 10]),
        .expectBeat(.stranger), .order(.attack), .mark("Attack permits native companion fire"),
        .provokeRetaliation, .leadWarnedMember, .order(.defend), .expectCombatStance(.defend),
        .mark("Defend after the named warning"), .finishRetaliationCycle,
        .order(.attack), .expectCombatStance(.attack), .mark("Attack after retaliation"),
        .dismantleGuard, .expectDefeated(1), .mark("retaliating guard dismantled"),
      ] + restartRun

    /// Native Attack contributions precede a real withdrawal. The distinct cover must hold
    /// at the actual bodies, survive Pause/Resume, then allow Attack to finish the guard.
    private static let coverSpacing: [Step] =
      toTheStranger + [
        .order(.attack), .expectCombatStance(.attack), .companionPrerequisites,
        .order(.hold), .order(.defend), .expectCombatStance(.defend),
        .walk([6.5, 10]), .mark("Defend returns to rear cover"),
        .settleDefendCover(seconds: 14, hold: 1),
        .pause, .wait(seconds: 0.5), .mark("Paused in separate cover"), .pause,
        .settleDefendCover(seconds: 6, hold: 0.5), .mark("Separate cover after Resume"),
        .order(.attack), .expectCombatStance(.attack), .companionFight,
        .expectDefeated(1), .mark("Guard dismantled after covered withdrawal"),
      ] + restartRun

    /// Show ordinary white damage before attempting the optional bonus route. Both damage
    /// categories and bounded visible numbers must be observed through real input.
    private static let damageFeedback: [Step] =
      toTheStranger + [
        .walk([6.5, 8]), .swap, .fire(seconds: 0.9), .mark("Ordinary damage numbers"),
        .swap, .dismantleGuard, .expectDefeated(1), .expectDamageFeedback,
        .mark("Guard defeated with normal and weak-point damage"),
      ] + restartRun

    /// The phone's controls throughout: no controller buttons, keyboard or manual right stick.
    private static let touchFightRoute: [Step] =
      toTheStranger + [
        .mark("Touch controls and order hint"), .wait(seconds: 1.5),
        .touchTarget, .expectLock(true), .mark("Guard selected by touch"), .wait(seconds: 1.5),
        .touchTarget, .expectLock(false), .touchTarget, .expectLock(true),
        .touchPress(InputRules.Raw(touchSwap: true)),
        .touchPress(InputRules.Raw(touchSwap: true)),
        .touchPress(InputRules.Raw(touchSwitch: true)),
        .touchPress(InputRules.Raw(touchSwitch: true)),
        .touchPress(InputRules.Raw(touchSwitch: true)),
        .touchOrder(.bothGo, at: [6.5, 13]),
        .expectOrder(.tom, "going"), .expectOrder(.laura, "going"), .expectRefused(0),
        .touchPress(InputRules.Raw(touchOrder: InputRules.TouchOrder(command: .hold, point: nil))),
        .expectOrder(.tom, "holding"),
        .touchPress(InputRules.Raw(touchFormation: true)),
        .touchPress(
          InputRules.Raw(touchOrder: InputRules.TouchOrder(command: .attack, point: nil))),
        .expectCombatStance(.attack), .touchFight, .expectDefeated(1), .expectLock(false),
        .expectTouchDamage,
        .mark("Touch-only guard victory"),
        .touchPress(
          InputRules.Raw(touchOrder: InputRules.TouchOrder(command: .defend, point: nil))),
        .expectCombatStance(.defend),
        .touchPress(InputRules.Raw(touchPause: true)), .wait(seconds: 0.5),
        .touchPress(InputRules.Raw(touchPanel: true)), .expectPanel(false),
        .mark("Touch Pause with status hidden"), .wait(seconds: 1.5),
        .touchPress(InputRules.Raw(touchPanel: true)), .expectPanel(true),
        .touchPress(InputRules.Raw(touchPause: true)), .wait(seconds: 0.3),
        .touchPress(InputRules.Raw(touchPause: true)), .wait(seconds: 0.3),
        .touchPress(InputRules.Raw(touchRestart: true)), .expectRestarted,
        .mark("Touch Restart restores the party"), .wait(seconds: 1),
      ]

    /// From the start through the first-tower guard's fight, then on beyond mid-span towards
    /// the second tower.
    private static let pastTheGuard: [Step] =
      toTheStranger + [
        .dismantleGuard, .expectDefeated(1), .mark("guard disabled"), .walk([6.5, -12]),
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

    /// The new mechanics are accepted through ordinary input, not injected damage/parts:
    /// Tom throws, Pause freezes the flight, Laura breaks a leg, then the squad finishes.
    private static let robotParts: [Step] =
      toTheStranger + [
        .order(.hold), .switchLeader, .walk([6.5, 5]), .lock, .grenade,
        .wait(seconds: 0.2), .mark("Tom's grenade in flight"),
        .pause, .wait(seconds: 0.5), .pause, .wait(seconds: 1.5),
        .expectGrenadeDamage, .mark("grenade detonated"), .formation,
        .dismantleGuard, .expectDefeated(1), .expectLegLoss, .expectDamageFeedback,
        .mark("leg detached and guard down"), .wait(seconds: 1),
      ] + restartRun

    /// The shipped first-tower fight, the guard with both scout drones (issue #201): Miki
    /// shoots the drones down through the aim help, stepping out of their dives, and then the
    /// squad dismantles the guard. The other routes play the guard alone (`level(for:)`).
    private static let droneFight: [Step] =
      toTheStranger + [
        .downDrones, .expectDronesDown(BrooklynBridge.drones.count), .mark("both drones down"),
        .dismantleGuard, .expectDefeated(1), .expectDronesDown(BrooklynBridge.drones.count),
        .mark("guard down after its drones"), .wait(seconds: 1),
      ] + restartRun

    /// Companions execute real anti-drone fire before the player attacks; Defend and Pause
    /// then interrupt the live combined encounter before the ordinary squad finish.
    private static let companionDroneFight: [Step] =
      toTheStranger + [
        .order(.attack), .expectCombatStance(.attack), .companionDrones,
        .order(.defend), .expectCombatStance(.defend), .mark("Defend with drones present"),
        .pause, .wait(seconds: 0.5), .pause, .order(.attack),
        .dismantleGuard, .expectDefeated(1), .expectDronesDown(BrooklynBridge.drones.count),
        .mark("combined squad victory"), .wait(seconds: 1),
      ] + restartRun

    /// The shipped first-tower fight with the whole pack (issue #208), the squad on Attack: Miki
    /// and the companions down the crawlers as they close in, Miki rolling out of their rams,
    /// then Miki downs the drones and the squad dismantles the guard.
    private static let crawlerFight: [Step] =
      toTheStranger + [
        .order(.attack), .expectCombatStance(.attack),
        .downCrawlers, .expectCrawlersDown(BrooklynBridge.crawlers.count),
        .mark("all crawlers down"), .downDrones, .expectDronesDown(BrooklynBridge.drones.count),
        .mark("both drones down"), .dismantleGuard, .expectDefeated(1),
        .mark("guard down after its pack"), .wait(seconds: 1),
      ] + restartRun

    /// The routes written for the guard with its drones, before the crawlers joined; they play
    /// `BrooklynBridge.guardAndDrones`.
    static let droneScenarios: Set<String> = ["drone-fight", "companion-drones"]
    /// The routes that play the shipped fight with the whole pack.
    static let packScenarios: Set<String> = ["crawler-fight"]

    /// The level a scenario runs on; with no scenario, the shipped bridge. The others were
    /// written for the guard's own contract and play it alone, on `BrooklynBridge.guardOnly`.
    static func level(for scenario: String?) -> Level {
      guard let scenario, !packScenarios.contains(scenario) else { return BrooklynBridge.level }
      return droneScenarios.contains(scenario)
        ? BrooklynBridge.guardAndDrones : BrooklynBridge.guardOnly
    }

    /// Every bridge scenario, by the name `apple/scripts/playtest` gives it.
    private static let scenarios: [(name: String, steps: [Step])] = [
      ("bridge-walk", bridgeWalk), ("first-fight", firstFight), ("fight-retry", fightRetry),
      ("opening", opening), ("formations", formations), ("orders", orders), ("lock-on", lockOn),
      ("weapons", weapons), ("companions", companions), ("retaliation", retaliation),
      ("cover-spacing", coverSpacing),
      ("damage-feedback", damageFeedback),
      ("touch-fight", touchFightRoute), ("robot-parts", robotParts),
      ("drone-fight", droneFight),
      ("companion-drones", companionDroneFight),
      ("crawler-fight", crawlerFight),
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
