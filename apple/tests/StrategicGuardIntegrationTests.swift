import Testing
import simd

@testable import Lauder

/// Native contact tests isolate incoming damage, not outgoing hits. The world/playtest suites
/// separately exercise real movement, injuries and ordinary input authority without immunity.
@MainActor
struct StrategicGuardIntegrationTests {
  @Test(arguments: ["assist", "manual", "lock"])
  func allThreeExploitRealComponentsWhileOnlyHealthDefeatsTheGuard(style: String) throws {
    let trial = try Trial(style: style)
    try #require(trial.reach(.coupling))
    #expect(trial.strategy.sensorDisabled && !trial.strategy.couplingBreached)
    try #require(trial.reach(.reactor))
    #expect(trial.strategy.couplingBreached && trial.strategy.reactorDamage == 0)
    try #require(trial.reach(.complete))
    #expect(trial.strategy.health == 0 && trial.strategy.reactorDamage > 0)
    #expect(trial.session.defeated == [Trial.id])
    #expect(trial.fight.hostiles[Trial.id]?.isDown == true)
    #expect(trial.fight.weakpoints(for: Trial.id).isEmpty)
    #expect(trial.damageHits.reduce(0) { $0 + $1.amount } == GuardStrategy.maximumHealth)
    for kind in [Weapon.Kind.longRifle, .energySword, .minigun] {
      #expect(trial.damageHits.contains { $0.weapon == kind && $0.effectiveness == .weakpoint })
    }
    let sensor = try #require(trial.damageHits.first { $0.brokeComponent })
    #expect(sensor.weapon == .longRifle && sensor.amount == Weapon.longRifle.damage * 3)
    let coupling = try #require(
      trial.damageHits.first { $0.weapon == .energySword && $0.brokeComponent })
    #expect(coupling.amount == Weapon.energySword.damage * 3)
    #expect(trial.damageHits.allSatisfy { $0.target == Trial.id && $0.amount > 0 })
  }

  @Test(arguments: [Weapon.Kind.longRifle, .assaultRifle, .shotgun, .energySword, .minigun])
  func everyDamagingWeaponCanWinWithRealOrdinaryBodyHits(kind: Weapon.Kind) throws {
    let (member, alternate): (PartyMember, Bool) =
      switch kind {
      case .longRifle: (.miki, false)
      case .assaultRifle: (.miki, true)
      case .shotgun: (.laura, false)
      case .energySword: (.laura, true)
      case .minigun: (.tom, false)
      default: (.miki, false)
      }
    let trial = try Trial(style: "manual")
    for _ in 0..<120 * 90 where trial.strategy.health > 0 {
      // The body is encountered before the front sensor. No specialist opening or companion
      // attack supplies this weapon's win; native draw, spread, cadence and reload still apply.
      trial.step(as: member, alternate: alternate, behind: true)
      #expect(trial.session.leader == member)
    }
    #expect(trial.strategy.health == 0 && trial.session.defeated == [Trial.id])
    #expect(!trial.strategy.sensorDisabled && !trial.strategy.couplingBreached)
    #expect(trial.strategy.reactorDamage == 0)
    #expect(trial.damageHits.reduce(0) { $0 + $1.amount } == GuardStrategy.maximumHealth)
    #expect(
      trial.damageHits.allSatisfy {
        $0.attacker == member && $0.weapon == kind && $0.effectiveness == .normal
          && !$0.brokeComponent
      })
    #expect(trial.partyShots.allSatisfy { $0.actor == member })
    #expect(
      trial.events.contains {
        if case .fired(let fired, _, true) = $0 { fired == kind } else { false }
      })
  }

  @Test
  func closedAndUnmatchedPartContactsApplyNormalHealthDamage() throws {
    let closed = try Trial(style: "manual")
    let first = try #require(closed.firstHit(as: .miki))
    #expect(first.amount == Weapon.longRifle.damage && first.effectiveness == .normal)
    #expect(!closed.strategy.sensorDisabled)
    #expect(closed.partyShots.contains { $0.path.strike == .body("guard.sensor.0") })
    #expect(closed.strategy.health == GuardStrategy.maximumHealth - first.amount)

    let wrong = try Trial()
    let rifle = try #require(wrong.firstHit(as: .miki, alternate: true))
    #expect(rifle.amount == Weapon.assaultRifle.damage && rifle.effectiveness == .normal)
    #expect(!wrong.strategy.sensorDisabled)
    try #require(wrong.reach(.coupling))
    let health = wrong.strategy.health
    let shotgun = try #require(wrong.firstHit(as: .laura))
    #expect(shotgun.amount == Weapon.shotgun.damage && shotgun.effectiveness == .normal)
    #expect(!wrong.strategy.couplingBreached && wrong.strategy.health == health - shotgun.amount)
    try #require(wrong.reach(.reactor))
    let beforeShield = wrong.strategy
    let beforeShieldEvents = wrong.damageHits.count
    wrong.fire(as: .tom, alternate: true, seconds: 1)
    #expect(
      wrong.strategy.health == beforeShield.health
        && wrong.strategy.sensorDisabled == beforeShield.sensorDisabled
        && wrong.strategy.couplingBreached == beforeShield.couplingBreached
        && wrong.strategy.reactorDamage == beforeShield.reactorDamage,
      "the dome is protection, not a damaging weapon")
    #expect(wrong.damageHits.count == beforeShieldEvents)
  }

  @Test
  func pauseRetreatAndMissedWindowsPreserveHealthButRetryResetsIt() throws {
    let trial = try Trial()
    try #require(trial.reach(.reactor))
    let firstCore = try #require(trial.firstHit(as: .tom))
    #expect(firstCore.amount > 0)
    let before = trial.strategy
    let robot = try #require(trial.fight.hostiles[Trial.id]?.robot)
    let eventCount = trial.damageHits.count
    trial.session.togglePause()
    trial.fire(as: .tom, seconds: 2)
    #expect(trial.strategy == before && trial.damageHits.count == eventCount)
    #expect(trial.fight.hostiles[Trial.id]?.robot?.elapsed == robot.elapsed)
    trial.session.togglePause()
    // Native recovery entries can reopen the window while the guard still sees a companion.
    // Observe an actual opening expiring during withdrawal, rather than assume a fixed delay
    // lands between cycles. No fire or direct timer/health write supplies that observation.
    var sawOpen = before.windowRemaining > 0
    var sawClosed = false
    for _ in 0..<120 * 20 {
      trial.step(as: .tom, fire: false, at: [0, 29])
      if trial.strategy.windowRemaining > 0 { sawOpen = true }
      if sawOpen && trial.strategy.windowRemaining == 0 {
        sawClosed = true
        break
      }
    }
    try #require(sawClosed, "a real bonus window must expire during the bounded withdrawal")
    #expect(trial.strategy.sensorDisabled && trial.strategy.couplingBreached)
    #expect(trial.strategy.windowRemaining == 0)
    #expect(
      trial.strategy.health == before.health && trial.strategy.reactorDamage == before.reactorDamage
    )
    #expect(trial.session.inEncounter)
    #expect(trial.reach(.complete))

    let retry = try Trial()
    try #require(retry.reach(.reactor))
    #expect(retry.strategy.health < GuardStrategy.maximumHealth)
    retry.session.retryEncounter()
    retry.fight.reset()
    #expect(retry.strategy == GuardStrategy())
    #expect(retry.fight.weakpoints(for: Trial.id).isEmpty)
    #expect(retry.session.defeated.isEmpty && retry.session.beat == .crossing)
    #expect(!retry.fight.takeEvents().contains { if case .damaged = $0 { true } else { false } })
  }

  @Test
  func realCoverStopsLockedCoreRoundsAndProducesNoDamageEvents() throws {
    let wall = Level.Box.box("screen", at: [6, 2, 0], size: [0.5, 4, 40])
    let trial = try Trial(style: "lock", boxes: [wall])
    try #require(trial.reach(.reactor))
    let before = trial.strategy
    let eventCount = trial.damageHits.count
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
    #expect(impacts > 0)
    #expect(trial.strategy.health == before.health)
    #expect(trial.strategy.reactorDamage == before.reactorDamage)
    #expect(trial.damageHits.count == eventCount && trial.session.defeated.isEmpty)
  }

  @Test
  func aSwordBodyContactHasFeedbackAndOneHealthChangePerSwing() throws {
    let trial = try Trial(style: "manual")
    var contacts = 0
    for _ in 0..<120 * 2 {
      let health = trial.strategy.health
      trial.step(as: .laura, alternate: true, behind: true)
      let damage = trial.lastEvents.compactMap { event -> DamageHit? in
        if case .damaged(let hit) = event { hit } else { nil }
      }
      let struck = trial.lastEvents.filter {
        if case .struckBody = $0 { true } else { false }
      }
      #expect(damage.count <= 1)
      #expect(health - trial.strategy.health == damage.reduce(0) { $0 + $1.amount })
      if let hit = damage.first {
        contacts += 1
        #expect(hit.amount == Weapon.energySword.damage && hit.effectiveness == .normal)
        #expect(hit.attacker == .laura && hit.weapon == .energySword)
        #expect(struck.count == 1)
        #expect(
          trial.lastEvents.contains {
            if case .fired(.energySword, _, true) = $0 { true } else { false }
          })
      }
    }
    #expect(contacts >= 2 && !trial.strategy.sensorDisabled)
    #expect(
      trial.strategy.health == GuardStrategy.maximumHealth - contacts * Weapon.energySword.damage)
  }

  @Test
  func aSwordStillNeedsReachAndAnOutwardSideForItsComponentBonus() throws {
    let outOfReach = try Trial(style: "manual")
    for _ in 0..<120 {
      outOfReach.step(
        as: .laura, alternate: true, behind: true,
        radialDistance: Weapon.energySword.range + RobotModelGeometry.bodyRadius + 0.3)
    }
    #expect(
      outOfReach.events.contains {
        if case .fired(.energySword, _, true) = $0 { true } else { false }
      })
    #expect(
      outOfReach.damageHits.isEmpty && outOfReach.strategy.health == GuardStrategy.maximumHealth)

    let trial = try Trial()
    try #require(trial.reach(.coupling))
    let before = trial.damageHits.count
    for _ in 0..<120 { trial.step(as: .laura, alternate: true, radialDistance: 0.5) }
    #expect(!trial.strategy.couplingBreached, "being inside the hull is not a flank")
    for _ in 0..<120 {
      trial.step(as: .laura, alternate: true, radialDistance: 1.65, radialAngle: 70 * .pi / 180)
    }
    #expect(!trial.strategy.couplingBreached, "reach alone does not breach the side component")
    #expect(trial.damageHits.dropFirst(before).allSatisfy { $0.effectiveness == .normal })
    #expect(trial.reach(.reactor), "an actual outward-side contact still earns the bonus")
  }

  @Test
  func startingInsideTheProtrudingCoreCannotAwardDamageWhenFiringAway() throws {
    let trial = try Trial(style: "manual")
    try #require(trial.reach(.reactor))
    let health = trial.strategy.health
    let events = trial.damageHits.count
    let shots = trial.partyShots.count
    for _ in 0..<120 * 3 {
      guard let robot = trial.fight.hostiles[Trial.id]?.robot,
        let point = trial.fight.weakpoints(for: Trial.id).last
      else {
        Issue.record("the core must remain present during the native away-fire check")
        break
      }
      let radial = simd_normalize(point.ground - robot.position)
      // The player is outside the physical hull but within the generous component cylinder.
      let origin = robot.position + radial * 1.65
      #expect(simd_distance(origin, point.ground) < point.radius)
      trial.step(as: .tom, at: origin, facingOverride: radial)
    }
    #expect(trial.partyShots.count > shots, "the minigun actually discharged")
    #expect(trial.damageHits.count == events && trial.strategy.health == health)
  }

  @Test
  func ordinaryHitsKeepNativeDrawCadenceMagazineAndPositiveRangeFalloff() throws {
    let trial = try Trial(style: "manual")
    trial.fire(as: .miki, seconds: 0.2, behind: true)
    #expect(
      trial.damageHits.isEmpty && trial.fight.status(for: .miki).loaded == Weapon.longRifle.capacity
    )
    for _ in 0..<120 * 8 where trial.fight.status(for: .miki).loaded > 0 {
      trial.step(as: .miki, behind: true)
    }
    #expect(trial.fight.status(for: .miki).loaded == 0)
    #expect(trial.fight.status(for: .miki).reloadRemaining > 0)
    let fired = trial.partyShots.count
    #expect(fired == Weapon.longRifle.capacity)
    trial.fire(as: .miki, seconds: 0.5, behind: true)
    #expect(trial.partyShots.count == fired, "damage cannot bypass the magazine's reload")
    for _ in 0..<120 * 3 where trial.partyShots.count == fired {
      trial.step(as: .miki, behind: true)
    }
    #expect(trial.partyShots.count == fired + 1)
    #expect(trial.fight.status(for: .miki).loaded == Weapon.longRifle.capacity - 1)
    #expect(
      trial.damageHits.allSatisfy {
        $0.amount == Weapon.longRifle.damage && $0.effectiveness == .normal
      })

    let distant = try Trial(style: "manual")
    let hit = try #require(distant.firstHit(as: .miki, at: [0, 33]))
    #expect(hit.amount == 1 && hit.effectiveness == .normal)
    #expect(
      distant.partyShots.contains {
        guard let trace = $0.trace else { return false }
        return simd_distance(trace.start, trace.end) > Weapon.longRifle.range
      })
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
    private(set) var events: [CombatEvent] = []
    private(set) var lastEvents: [CombatEvent] = []
    private(set) var damageHits: [DamageHit] = []
    private(set) var partyShots: [EncounterSimulation.Shot] = []

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
    func reach(_ phase: GuardStrategy.Phase, seconds: Float = 45) -> Bool {
      for _ in 0..<Int(seconds * 120) {
        if strategy.phase == phase { return true }
        let member: PartyMember =
          switch strategy.phase {
          case .sensor: .miki
          case .coupling: .laura
          case .reactor, .complete: .tom
          }
        step(as: member, alternate: member == .laura)
      }
      return strategy.phase == phase
    }

    func fire(
      as member: PartyMember, alternate: Bool = false, seconds: Float, behind: Bool = false
    ) {
      for _ in 0..<Int(seconds * 120) { step(as: member, alternate: alternate, behind: behind) }
    }

    func firstHit(
      as member: PartyMember, alternate: Bool = false, at position: SIMD2<Float>? = nil
    ) -> DamageHit? {
      let previous = damageHits.count
      for _ in 0..<120 * 5 {
        step(as: member, alternate: alternate, at: position)
        if damageHits.count > previous { return damageHits.last }
      }
      return nil
    }

    func step(
      as member: PartyMember, alternate: Bool = false, fire: Bool = true,
      at position: SIMD2<Float>? = nil, behind: Bool = false,
      radialDistance: Float? = nil, radialAngle: Float = 0,
      facingOverride: SIMD2<Float>? = nil
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
      let facing =
        facingOverride ?? (simd_length(offset) > 0.001 ? simd_normalize(offset) : [0, -1])
      if style == "lock", fight.lock == nil {
        fight.pressLock(from: from, facing: facing, up: [0, -1], right: [1, 0])
      }
      var figures = level.spawns
      figures[member] = from
      let health = strategy.health
      _ = fight.step(
        dt: dt, leader: from, facing: facing, aiming: style == "manual",
        fireHeld: fire, firePressed: fire, figures: figures, session: session,
        untouchable: Set(session.party))
      lastEvents = fight.takeEvents()
      events += lastEvents
      let hits = lastEvents.compactMap { event -> DamageHit? in
        if case .damaged(let hit) = event { hit } else { nil }
      }
      damageHits += hits
      let fired = fight.shots.filter { if case .party = $0.side { true } else { false } }
      partyShots += fired
      #expect(health - strategy.health == hits.reduce(0) { $0 + $1.amount })
      #expect(hits.allSatisfy { $0.amount > 0 && $0.target == Self.id && $0.attacker == member })
      if fight.weapon(of: member).kind.shoots {
        let contacts = fired.filter {
          if case .body(let id) = $0.path.strike {
            id == Self.id || id.hasPrefix(Self.id + ".")
          } else {
            false
          }
        }
        #expect(contacts.count == hits.count, "each native gun contact supplies one damage event")
      }
    }
  }
}
