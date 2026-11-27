import Testing
import simd

@testable import Lauder

/// The scout drone's own flight (issue #201): circling, the warning, the committed dive and
/// its burst, the low pass, walls and low cover, the fall and the quiet exit.
struct ScoutDroneTests {
  private static let open = ScoutDrone.Airspace(
    bounds: PartyMotion.Box(minimum: [-40, -40], maximum: [40, 40]))
  private static let dt: Float = 1 / 120

  @Test
  func itCirclesAtCruiseHeightAndNeverWarnsBeforeItsFightIsEngaged() {
    var drone = ScoutDrone(home: .zero, orbit: 0)
    drone.reveal()
    for _ in 0..<Int(12 / Self.dt) {
      _ = drone.step(
        dt: Self.dt, centre: .zero, target: [0, 4], mayAttack: true, airspace: Self.open)
      #expect(drone.phase == .patrolling)
      #expect(abs(drone.height - ScoutDrone.cruiseHeight) < 0.001)
      #expect(abs(simd_length(drone.position) - ScoutDrone.orbitRadius) < 0.6)
    }
    #expect(drone.isTargetable && !drone.isLow)
  }

  @Test
  func itWarnsForAFullSecondThenCommitsToWhereItsTargetLastStood() throws {
    var drone = ScoutDrone(home: .zero, orbit: 0)
    drone.reveal()
    drone.engage()
    var warned: Float = 0
    var target = SIMD2<Float>(0, 6)
    for _ in 0..<Int(10 / Self.dt) {
      _ = drone.step(
        dt: Self.dt, centre: .zero, target: target, mayAttack: true, airspace: Self.open)
      if drone.phase == .warning {
        warned += Self.dt
        // The member keeps moving through the warning; the dive takes the last place seen.
        target += [Self.dt, 0]
      }
      if drone.phase == .diving { break }
    }
    try #require(drone.phase == .diving)
    #expect(warned >= ScoutDrone.warningTime - Self.dt)
    let committed = try #require(drone.committedPoint)
    #expect(simd_distance(committed, target) < 0.02)
    _ = drone.step(
      dt: Self.dt, centre: .zero, target: [20, 20], mayAttack: true, airspace: Self.open)
    #expect(drone.committedPoint == committed)
  }

  @Test
  func aDiveFiresThreeRoundsAtItsPointComesLowAndClimbsBack() throws {
    var drone = ScoutDrone(home: .zero, orbit: 0)
    drone.reveal()
    drone.engage()
    var rounds: [ScoutDrone.Discharge] = []
    var committed: SIMD2<Float>?
    var lowest = Float.infinity
    var climbed = false
    for _ in 0..<Int(16 / Self.dt) {
      if let round = drone.step(
        dt: Self.dt, centre: .zero, target: [0, 6], mayAttack: rounds.isEmpty,
        airspace: Self.open)
      {
        rounds.append(round)
      }
      if drone.phase == .diving { committed = committed ?? drone.committedPoint }
      if drone.phase == .diving || drone.phase == .climbing { lowest = min(lowest, drone.height) }
      if !rounds.isEmpty, drone.phase == .patrolling {
        climbed = true
        break
      }
    }
    let point = try #require(committed)
    #expect(rounds.count == ScoutDrone.burstRounds)
    for round in rounds {
      let aim = SIMD3(point.x, ScoutDrone.aimHeight, point.y)
      #expect(simd_dot(round.direction, simd_normalize(aim - round.origin)) > 0.9999)
    }
    #expect(lowest <= ScoutDrone.lowHeight + 0.001)
    #expect(lowest <= ScoutDrone.swordHeight)
    #expect(climbed && abs(drone.height - ScoutDrone.cruiseHeight) < 0.001)
  }

  @Test
  func aBurstCanHurtAtMostOnceAndOnlyWhileItDivesOrClimbs() throws {
    var drone = ScoutDrone(home: .zero, orbit: 0)
    let early = drone.acceptBurstHit()
    #expect(!early)
    drone.reveal()
    drone.engage()
    for _ in 0..<Int(10 / Self.dt) where drone.phase != .diving {
      _ = drone.step(
        dt: Self.dt, centre: .zero, target: [0, 6], mayAttack: true, airspace: Self.open)
    }
    try #require(drone.phase == .diving)
    let first = drone.acceptBurstHit()
    let second = drone.acceptBurstHit()
    #expect(first && !second)
  }

  @Test
  func itWaitsItsTurnWhileAnotherDroneAttacks() {
    var drone = ScoutDrone(home: .zero, orbit: 0)
    drone.reveal()
    drone.engage()
    for _ in 0..<Int(12 / Self.dt) {
      _ = drone.step(
        dt: Self.dt, centre: .zero, target: [0, 6], mayAttack: false, airspace: Self.open)
      #expect(drone.phase == .patrolling)
    }
  }

  @Test
  func aWallBetweenItAndItsTargetStopsTheDiveAndItNeverFliesInsideOne() {
    // A tall pier between the circle and the member, as the first tower's stands.
    let wall = PartyMotion.Box(minimum: [-6, 2], maximum: [6, 4])
    let airspace = ScoutDrone.Airspace(
      walls: [wall], bounds: PartyMotion.Box(minimum: [-40, -40], maximum: [40, 40]))
    var drone = ScoutDrone(home: [0, -3], orbit: 0)
    drone.reveal()
    drone.engage()
    for _ in 0..<Int(14 / Self.dt) {
      _ = drone.step(
        dt: Self.dt, centre: [0, -3], target: [0, 9], mayAttack: true, airspace: airspace)
      #expect(drone.phase != .diving)
      let inside =
        drone.position.x > wall.minimum.x - ScoutDrone.radius + 0.001
        && drone.position.x < wall.maximum.x + ScoutDrone.radius - 0.001
        && drone.position.y > wall.minimum.y - ScoutDrone.radius + 0.001
        && drone.position.y < wall.maximum.y + ScoutDrone.radius - 0.001
      #expect(!inside)
    }
  }

  @Test
  func itRisesOverLowCoverOnItsLowPass() throws {
    // Low cover all round the member it dives at, so every low pass crosses it.
    let cover = PartyMotion.Box(minimum: [-2.5, 3.5], maximum: [2.5, 8.5])
    let airspace = ScoutDrone.Airspace(
      roofs: [.init(footprint: cover, top: 1.65)],
      bounds: PartyMotion.Box(minimum: [-40, -40], maximum: [40, 40]))
    var drone = ScoutDrone(home: .zero, orbit: -.pi / 2)
    drone.reveal()
    drone.engage()
    var overCover: [(phase: ScoutDrone.Phase, height: Float)] = []
    for _ in 0..<Int(16 / Self.dt) {
      _ = drone.step(
        dt: Self.dt, centre: .zero, target: [0, 6], mayAttack: true, airspace: airspace)
      let near = ScoutDrone.radius
      if drone.position.x >= cover.minimum.x - near, drone.position.x <= cover.maximum.x + near,
        drone.position.y >= cover.minimum.y - near, drone.position.y <= cover.maximum.y + near
      {
        overCover.append((drone.phase, drone.height))
      }
    }
    try #require(overCover.contains { $0.phase == .diving })
    #expect(overCover.allSatisfy { $0.height >= 1.65 + ScoutDrone.clearance - 0.001 })
  }

  @Test
  func knockedDownItFallsToTheSnowStopsAndCannotBeTargeted() {
    var drone = ScoutDrone(home: .zero, orbit: 0)
    drone.reveal()
    drone.knockDown()
    #expect(drone.isDown && !drone.isTargetable)
    for _ in 0..<Int(2 / Self.dt) {
      let shot = drone.step(
        dt: Self.dt, centre: .zero, target: [0, 6], mayAttack: true, airspace: Self.open)
      #expect(shot == nil)
    }
    #expect(abs(drone.height - ScoutDrone.wreckHeight) < 0.001)
    let accepted = drone.acceptBurstHit()
    #expect(!accepted)
  }

  @Test
  func aWreckRestsOnTheLowCoverItFallsOnto() {
    let cover = PartyMotion.Box(minimum: [-1, -1], maximum: [1, 1])
    let airspace = ScoutDrone.Airspace(
      roofs: [.init(footprint: cover, top: 1.65)],
      bounds: PartyMotion.Box(minimum: [-40, -40], maximum: [40, 40]))
    // It starts a quarter of the way round its circle, right above the cover.
    var drone = ScoutDrone(home: [0, -ScoutDrone.orbitRadius], orbit: .pi / 2)
    drone.reveal()
    drone.knockDown()
    for _ in 0..<Int(2 / Self.dt) {
      _ = drone.step(
        dt: Self.dt, centre: [0, -ScoutDrone.orbitRadius], target: nil, mayAttack: false,
        airspace: airspace)
    }
    #expect(abs(drone.height - (1.65 + ScoutDrone.wreckHeight)) < 0.001)
  }

  @Test
  func afterTheQuietExitItCirclesButNeverAttacksAgain() {
    var drone = ScoutDrone(home: .zero, orbit: 0)
    drone.reveal()
    drone.engage()
    drone.clear()
    drone.engage()
    for _ in 0..<Int(12 / Self.dt) {
      let shot = drone.step(
        dt: Self.dt, centre: .zero, target: [0, 6], mayAttack: true, airspace: Self.open)
      #expect(shot == nil)
      #expect(drone.phase == .cleared && !drone.isTargetable)
    }
  }

  @Test
  func unusableStepsChangeNothing() {
    var drone = ScoutDrone(home: .zero, orbit: 0)
    drone.reveal()
    drone.engage()
    let before = (drone.position, drone.height, drone.phase)
    for dt in [Float.nan, 0, -1, .infinity] {
      _ = drone.step(dt: dt, centre: .zero, target: [0, 6], mayAttack: true, airspace: Self.open)
    }
    _ = drone.step(
      dt: Self.dt, centre: [.nan, 0], target: [0, 6], mayAttack: true, airspace: Self.open)
    #expect(drone.position == before.0 && drone.height == before.1 && drone.phase == before.2)
  }

}

/// Drones in a guard's fight (issue #201): they wait for it, take turns, wake it when hit,
/// rise to assisted fire, fall with it, and the quiet exit clears them.
@MainActor
struct ScoutDroneFightTests {
  @Test
  func itsRoundsAimWhereThePartysOwnShotsFly() {
    #expect(ScoutDrone.aimHeight == EncounterSimulation.aimHeight)
  }

  @Test
  func theyCircleWithoutDivingUntilTheGuardNoticesTheParty() throws {
    let range = try Range(party: [0, 30])
    for _ in 0..<Int(15 * 120) {
      range.step()
      for id in Range.drones {
        let drone = try #require(range.fight.hostiles[id]?.drone)
        #expect(drone.phase == .patrolling)
      }
    }
    #expect(!range.events.contains { if case .droneWarning = $0 { true } else { false } })
  }

  @Test
  func onceTheFightIsEngagedTheyDiveOneAtATimeAfterAWarning() throws {
    let range = try Range(party: [0, 8])
    var warned: [String: Float] = [:]
    var dives = 0
    var previous: [String: ScoutDrone.Phase] = [:]
    for _ in 0..<Int(45 * 120) {
      let before = Range.drones.map { range.fight.hostiles[$0]?.drone?.phase }
      range.step()
      // A warning starts only while the guard itself patrols, recovers or searches. The guard
      // moves first in each step, so its phase now is the one the drone saw.
      let guardPhase = range.fight.hostiles[Range.guardID]?.robot?.phase
      for (index, id) in Range.drones.enumerated()
      where before[index] == .patrolling && range.fight.hostiles[id]?.drone?.phase == .warning {
        #expect(guardPhase.map { [.patrol, .recovering, .searching].contains($0) } == true)
      }
      let phases = Range.drones.compactMap { id in
        range.fight.hostiles[id]?.drone.map { (id, $0.phase) }
      }
      #expect(phases.filter { $0.1 == .warning || $0.1 == .diving }.count <= 1)
      for (id, phase) in phases {
        if phase == .warning { warned[id, default: 0] += 1 / 120 }
        if phase == .diving, previous[id] == .warning {
          #expect((warned[id] ?? 0) >= ScoutDrone.warningTime - 1 / 120)
          warned[id] = 0
          dives += 1
        }
        previous[id] = phase
      }
    }
    #expect(dives >= 3)
    #expect(range.events.contains { if case .droneWarning = $0 { true } else { false } })
  }

  @Test
  func hittingADroneWakesItAndItsGuard() throws {
    // Beyond the guard's sight, so only the hit can start the fight.
    let range = try Range(party: [0, 18])
    #expect(range.fight.companionGuard(near: .zero) == nil)
    var hit = false
    for _ in 0..<Int(20 * 120) where !hit {
      range.step(fireAt: Range.drones[0])
      hit = range.hits.contains { $0.target == Range.drones[0] }
    }
    try #require(hit)
    #expect(range.fight.companionGuard(near: .zero) != nil)
  }

  @Test
  func assistedFireRisesToADroneAtCruiseHeight() throws {
    let range = try Range(party: [0, 8])
    var heights: [Float] = []
    for _ in 0..<Int(20 * 120) where heights.isEmpty {
      let before = range.hits.count
      let height = range.fight.hostiles[Range.drones[1]]?.drone?.height ?? 0
      range.step(fireAt: Range.drones[1])
      if range.hits[before...].contains(where: { $0.target == Range.drones[1] }) {
        heights.append(height)
      }
    }
    let height = try #require(heights.first)
    #expect(height > ScoutDrone.swordHeight)
    let hit = try #require(range.hits.first { $0.target == Range.drones[1] })
    #expect(hit.position.y > ScoutDrone.swordHeight)
    #expect(hit.amount == Weapon.longRifle.damage)
  }

  @Test
  func downingTheGuardDropsItsDronesAndEndsTheFight() throws {
    let range = try Range(party: [0, 6])
    var flyingAtTheEnd = 0
    for _ in 0..<Int(120 * 120) where range.session.inEncounter {
      if range.fight.hostiles[Range.guardID]?.isDown == false {
        flyingAtTheEnd = Range.drones.filter { range.fight.hostiles[$0]?.isDown == false }.count
      }
      range.step(fireAt: Range.guardID)
    }
    #expect(!range.session.inEncounter)
    #expect(range.session.defeated == Set([Range.guardID] + Range.drones))
    // At least one drone was still flying when the guard went down, and fell with it.
    #expect(flyingAtTheEnd > 0)
    for id in Range.drones {
      #expect(range.fight.hostiles[id]?.isDown == true)
      #expect(range.fight.hostiles[id]?.drone?.isTargetable == false)
    }
    // The fight is over, but each fall still finishes on the snow.
    for _ in 0..<120 { range.step() }
    for id in Range.drones {
      let height = try #require(range.fight.hostiles[id]?.drone?.height)
      #expect(abs(height - ScoutDrone.wreckHeight) < 0.001)
    }
  }

  @Test
  func theQuietExitLeavesTheDronesCirclingHarmlessly() throws {
    let range = try Range(party: [0, 30])
    range.step()
    #expect(range.fight.resolveRobotBypass(id: Range.guardID, session: range.session))
    for id in Range.drones {
      #expect(range.fight.hostiles[id]?.drone?.phase == .cleared)
      #expect(range.fight.hostiles[id]?.isTargetable == false)
    }
    // With the encounter over, they keep circling and never fire again.
    let before = Range.drones.map { range.fight.hostiles[$0]?.position ?? .zero }
    for _ in 0..<(2 * 120) { range.step() }
    for (index, id) in Range.drones.enumerated() {
      let drone = try #require(range.fight.hostiles[id]?.drone)
      #expect(drone.phase == .cleared && drone.height == ScoutDrone.cruiseHeight)
      #expect(simd_distance(drone.position, before[index]) > 1)
    }
    #expect(
      !range.events.contains {
        if case .fired(_, _, false) = $0 { return true }
        return false
      })
  }

  @Test
  func theLockCanTakeEachDrone() throws {
    let range = try Range(party: [0, 8])
    range.step()
    var locked: Set<String> = []
    for _ in 0..<6 {
      range.fight.selectLock(
        from: [0, 8], facing: [0, -1], up: [0, -1], right: [1, 0], advancing: true)
      if let lock = range.fight.lock { locked.insert(lock) }
    }
    #expect(locked == Set([Range.guardID] + Range.drones))
  }

  /// A guard and its two drones on an open range, with the party together at one point.
  /// Members are untouchable, so incoming injuries never end a test early.
  @MainActor
  private final class Range {
    static let guardID = "guard"
    static let drones = ["drone.1", "drone.2"]
    let fight: EncounterSimulation
    let session: GameSession
    private(set) var hits: [DamageHit] = []
    private(set) var events: [CombatEvent] = []
    private let figures: [PartyMember: SIMD2<Float>]

    init(party point: SIMD2<Float>) throws {
      figures = [.miki: point, .tom: point + [-1.5, 0.5], .laura: point + [1.5, 0.5]]
      let guardian = Level.Hostile(
        id: Self.guardID, name: "Guard", hiddenAt: .zero, standAt: .zero, hits: 6,
        attack: .robot, strategicGuard: true, range: 12)
      let drones = Self.drones.enumerated().map { index, id in
        Level.Hostile(
          id: id, name: "Scout drone", hiddenAt: .zero, standAt: .zero, hits: ScoutDrone.health,
          attack: .drone(orbit: Float(index) * .pi, slot: index))
      }
      var cues: [(at: Float, cue: Level.Cue)] = []
      for hostile in [guardian] + drones {
        cues += [(0, .reveal(hostile.id)), (0, .engage(hostile.id))]
      }
      let encounter = Level.Encounter(
        beat: .stranger, start: .area(.init(minimum: [-40, -40], maximum: [40, 40])),
        retryAt: point, hostiles: [guardian] + drones, cues: cues,
        safeExit: .init(minimum: [30, 30], maximum: [35, 35]))
      let level = Level(
        id: "drone-range", ground: .box("floor", at: [0, -0.15, 0], size: [100, 0.3, 100]),
        boxes: [], triggers: [], encounters: [encounter], party: [.miki, .tom, .laura],
        spawns: figures, heading: [0, -1], cameraOffset: BrooklynBridge.cameraOffset,
        fieldOfView: 22, opening: "Range", objective: "Test", lookAround: "Range",
        restartNote: "Restart")
      fight = EncounterSimulation(level: level)
      session = GameSession(level: level)
      try #require(session.beginEncounter(encounter.beat))
      fight.begin(encounter)
    }

    /// One fixed step; with `fireAt`, Miki leads with her long rifle aimed at that hostile.
    func step(fireAt id: String? = nil) {
      let leader = figures[.miki] ?? .zero
      var facing = SIMD2<Float>(0, -1)
      if let id, let target = fight.hostiles[id]?.position,
        simd_distance(target, leader) > 0.001
      {
        facing = simd_normalize(target - leader)
      }
      let fire = id != nil
      _ = fight.step(
        dt: 1 / 120, leader: leader, facing: facing, aiming: fire, fireHeld: fire,
        firePressed: fire, figures: figures, session: session,
        untouchable: Set(PartyMember.allCases))
      for event in fight.takeEvents() {
        events.append(event)
        if case .damaged(let hit) = event { hits.append(hit) }
      }
    }
  }
}
