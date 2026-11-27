import Testing
import simd

@testable import Lauder

/// Native contact tests isolate incoming damage, not outgoing hits. The world/playtest suites
/// separately exercise real movement, injuries and ordinary input authority without immunity.
@MainActor
struct StrategicGuardIntegrationTests {
  @Test(arguments: ["assist", "manual", "lock"])
  func allThreeDismantleRealComponentsWithoutAnAuthoredTakedown(style: String) throws {
    let trial = try Trial(style: style)
    #expect(trial.reach(.coupling))
    #expect(trial.strategy.sensorDisabled && !trial.strategy.couplingBreached)
    #expect(trial.reach(.reactor))
    #expect(trial.strategy.couplingBreached && trial.strategy.reactorDamage == 0)
    #expect(trial.reach(.complete))
    #expect(trial.strategy.reactorDamage == GuardStrategy.reactorDamageRequired)
    #expect(trial.session.defeated == [Trial.id])
    #expect(trial.fight.hostiles[Trial.id]?.isDown == true)
    #expect(trial.fight.weakpoints(for: Trial.id).isEmpty)
  }

  @Test(arguments: ["assist", "manual", "lock"])
  func noSingleCharacterOrPairCanBypassTheMissingRole(style: String) throws {
    let subsets: [[PartyMember]] = [
      [.miki], [.laura], [.tom], [.miki, .laura], [.miki, .tom], [.laura, .tom],
    ]
    for allowed in subsets {
      let trial = try Trial(style: style)
      #expect(!trial.reach(.complete, allowed: allowed, seconds: 20))
      #expect(trial.session.defeated.isEmpty, "\(style), \(allowed)")
      #expect(trial.fight.hostiles[Trial.id]?.isDown == false)
    }
  }

  @Test
  func alternateWeaponsDoNotOpenTheCorrectCharactersComponent() throws {
    let trial = try Trial()
    trial.fire(as: .miki, alternate: true, seconds: 8)
    #expect(trial.strategy.phase == .sensor && trial.session.defeated.isEmpty)
    #expect(trial.reach(.coupling))
    trial.fire(as: .laura, alternate: false, seconds: 3)
    #expect(trial.strategy.phase == .coupling && trial.session.defeated.isEmpty)
    #expect(trial.reach(.reactor))
    trial.fire(as: .tom, alternate: true, seconds: 2)
    #expect(trial.strategy.reactorDamage == 0 && trial.session.defeated.isEmpty)
    #expect(trial.reach(.complete))
  }

  @Test
  func pauseRetreatAndMissedWindowsPreserveProgressButRetryResetsIt() throws {
    let trial = try Trial()
    #expect(trial.reach(.reactor))
    let before = trial.strategy
    let robot = try #require(trial.fight.hostiles[Trial.id]?.robot)
    trial.session.togglePause()
    trial.fire(as: .tom, seconds: 2)
    #expect(trial.strategy == before)
    #expect(trial.fight.hostiles[Trial.id]?.robot?.elapsed == robot.elapsed)
    trial.session.togglePause()
    for _ in 0..<120 * 8 { trial.step(as: .tom, fire: false, at: [0, 29]) }
    #expect(trial.strategy.sensorDisabled && trial.strategy.couplingBreached)
    #expect(trial.strategy.windowRemaining == 0 && trial.strategy.reactorDamage == 0)
    #expect(trial.session.inEncounter)
    #expect(trial.reach(.complete))

    let retry = try Trial()
    #expect(retry.reach(.reactor))
    retry.session.retryEncounter()
    retry.fight.reset()
    #expect(retry.strategy == GuardStrategy())
    #expect(retry.fight.weakpoints(for: Trial.id).isEmpty)
    #expect(retry.session.defeated.isEmpty && retry.session.beat == .crossing)
  }

  @Test
  func realCoverStopsLockedCoreRoundsAndArmourHitsDoNotCountAsProgress() throws {
    let wall = Level.Box.box("screen", at: [6, 2, 0], size: [0.5, 4, 40])
    let trial = try Trial(style: "lock", boxes: [wall])
    #expect(trial.reach(.reactor))
    #expect(trial.strategy.windowRemaining > 0)
    var impacts = 0
    for _ in 0..<120 * 2 {
      trial.step(as: .tom, at: [9, 0])
      for shot in trial.fight.shots {
        if case .party = shot.side {
          impacts += 1
          #expect(shot.path.strike == .scenery)
        }
      }
    }
    #expect(impacts > 0 && trial.strategy.reactorDamage == 0)
    #expect(trial.session.defeated.isEmpty)

    let armour = try Trial(style: "manual")
    var bodyHits = 0
    for _ in 0..<120 * 8 {
      // Approach from behind: the hull is encountered before the front sensor. An ordinary
      // manual ray must not turn a body hit into the role's component hit.
      armour.step(as: .miki, behind: true)
      bodyHits += armour.fight.shots.filter { $0.path.strike == .body(Trial.id) }.count
    }
    #expect(bodyHits > 0)
    #expect(armour.strategy.phase == .sensor && armour.session.defeated.isEmpty)
  }

  @Test
  func aSwordCannotBreachFromInsideTheHullOrAcrossTheWrongSide() throws {
    let trial = try Trial()
    #expect(trial.reach(.coupling))
    for _ in 0..<120 {
      trial.step(as: .laura, alternate: true, radialDistance: 0.5)
    }
    #expect(!trial.strategy.couplingBreached, "being inside the hull is not a flank")
    for _ in 0..<120 {
      // Outside the solid hull and within sword reach, but 70 degrees round from the
      // component's outward face. A proximity-only check would incorrectly accept it.
      trial.step(as: .laura, alternate: true, radialDistance: 1.65, radialAngle: 70 * .pi / 180)
    }
    #expect(!trial.strategy.couplingBreached, "reach alone does not breach the side component")
    #expect(trial.reach(.reactor), "the ordinary outward-side contact still works")
  }

  @Test(arguments: ["assist", "lock"])
  func anElevatedSensorCanBeHitOverCoverThatBlocksGroundHeightAssistance(style: String) throws {
    let lowWall = Level.Box.box("low-screen", at: [0, 0.65, 4], size: [40, 1.3, 0.3])
    #expect(lowWall.position.y + lowWall.size.y / 2 > EncounterSimulation.aimHeight)
    let trial = try Trial(style: style, boxes: [lowWall])
    #expect(trial.reach(.coupling), "actual 3D sensor sight clears the low wall")
    #expect(trial.strategy.sensorDisabled && trial.session.defeated.isEmpty)
  }

  @MainActor
  private final class Trial {
    static let id = "guard"
    let session: GameSession
    let fight: EncounterSimulation
    private let level: Level
    private let style: String
    private let dt: Float = 1 / 120

    var strategy: GuardStrategy { fight.guardStrategies[Self.id] ?? GuardStrategy() }

    init(style: String = "assist", boxes: [Level.Box] = []) throws {
      self.style = style
      let robot = Level.Hostile(
        id: Self.id, name: "Guard", hiddenAt: .zero, standAt: .zero, hits: 6,
        attack: .robot, strategicGuard: true, range: 12)
      let encounter = Level.Encounter(
        beat: .stranger, start: .area(.init(minimum: [-20, -20], maximum: [20, 20])),
        retryAt: [0, 12], hostiles: [robot],
        cues: [(0, .reveal(Self.id)), (0, .engage(Self.id))])
      level = Level(
        id: "component-range", ground: .box("floor", at: [0, -0.15, 0], size: [70, 0.3, 70]),
        boxes: boxes, triggers: [], encounters: [encounter], party: [.miki, .tom, .laura],
        spawns: [.miki: [0, 8], .tom: [-12, 15], .laura: [12, 15]], heading: [0, -1],
        cameraOffset: BrooklynBridge.cameraOffset, fieldOfView: 22,
        opening: "Range", objective: "Test", lookAround: "Range", restartNote: "Restart")
      session = GameSession(level: level)
      fight = EncounterSimulation(level: level)
      #expect(session.beginEncounter(.stranger))
      fight.begin(encounter)
      step(as: .miki, fire: false)
    }

    @discardableResult
    func reach(
      _ phase: GuardStrategy.Phase, allowed: [PartyMember] = [.miki, .tom, .laura],
      seconds: Float = 30
    ) -> Bool {
      for _ in 0..<Int(seconds * 120) {
        if strategy.phase == phase { return true }
        let wanted: PartyMember =
          switch strategy.phase {
          case .sensor: .miki
          case .coupling: .laura
          case .reactor, .complete: .tom
          }
        let member = allowed.contains(wanted) ? wanted : allowed[0]
        step(as: member, alternate: member == .laura)
      }
      return strategy.phase == phase
    }

    func fire(as member: PartyMember, alternate: Bool = false, seconds: Float) {
      for _ in 0..<Int(seconds * 120) { step(as: member, alternate: alternate) }
    }

    func step(
      as member: PartyMember, alternate: Bool = false, fire: Bool = true,
      at position: SIMD2<Float>? = nil, behind: Bool = false,
      radialDistance: Float? = nil, radialAngle: Float = 0
    ) {
      for _ in 0..<3 where session.leader != member { session.cycleLeader() }
      let kind = Weapon.pair(for: member)[alternate ? 1 : 0].kind
      if fight.weapon(of: member).kind != kind { fight.swapWeapon(for: member) }
      let robot = fight.hostiles[Self.id]?.robot
      let centre = robot?.position ?? .zero
      let point = fight.weakpoints(for: Self.id).last
      let needsAttack =
        strategy.phase == .reactor && strategy.windowRemaining == 0
        && robot?.phase != .committed && robot?.phase != .burst && robot?.phase != .recovering
      let outward =
        needsAttack
        ? robot?.facing ?? [0, 1] : point.map { $0.ground - centre } ?? SIMD2<Float>(0, 1)
      let direction = simd_length(outward) > 0.001 ? simd_normalize(outward) : [0, 1]
      let distance: Float = member == .laura ? 2.65 : member == .tom ? 3.5 : 8
      let rotated = SIMD2(
        direction.x * cos(radialAngle) - direction.y * sin(radialAngle),
        direction.x * sin(radialAngle) + direction.y * cos(radialAngle))
      let from = position ?? centre + rotated * (radialDistance ?? distance) * (behind ? -1 : 1)
      let offset = (point?.ground ?? centre) - from
      let facing = simd_length(offset) > 0.001 ? simd_normalize(offset) : [0, -1]
      if style == "lock", fight.lock == nil {
        fight.pressLock(from: from, facing: facing, up: [0, -1], right: [1, 0])
      }
      var figures = level.spawns
      figures[member] = from
      _ = fight.step(
        dt: dt, leader: from, facing: facing, aiming: style == "manual",
        fireHeld: fire, firePressed: fire, figures: figures, session: session,
        untouchable: Set(session.party))
    }
  }
}
