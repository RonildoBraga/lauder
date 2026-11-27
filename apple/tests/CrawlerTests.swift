import Testing
import simd

@testable import Lauder

/// A pack crawler's own movement (issue #208): folded, getting up in turn, the approach, a
/// wind-up whose line is fixed from its start, the ram, recovery, the leash, walls, the fall
/// and the quiet exit.
struct CrawlerTests {
  private static let dt: Float = 1 / 120
  private static let open = PartyMotion(radius: Crawler.radius, obstacles: [])

  private func run(
    _ crawler: inout Crawler, seconds: Float, target: SIMD2<Float>?, engaged: Bool = true,
    mayWindUp: Bool = true, motion: PartyMotion = CrawlerTests.open,
    guardian: (centre: SIMD2<Float>, radius: Float)? = nil,
    until: (Crawler) -> Bool = { _ in false }
  ) -> [Crawler.Ram] {
    var rams: [Crawler.Ram] = []
    for _ in 0..<Int(seconds / Self.dt) {
      if let ram = crawler.step(
        dt: Self.dt, target: target, engaged: engaged, mayWindUp: mayWindUp, motion: motion,
        guardian: guardian, others: [])
      {
        rams.append(ram)
      }
      if until(crawler) { break }
    }
    return rams
  }

  @Test
  func itWaitsFoldedUntilItsFightIsEngagedThenGetsUpInTurn() throws {
    var first = Crawler(home: .zero, slot: 0)
    var third = Crawler(home: .zero, slot: 2)
    first.reveal()
    third.reveal()
    _ = run(&first, seconds: 5, target: [0, 8], engaged: false)
    #expect(first.phase == .folded && first.position == .zero && first.isTargetable)
    func timeToGetUp(_ crawler: inout Crawler) -> Float? {
      for step in 1...Int(4 / Self.dt) {
        _ = crawler.step(
          dt: Self.dt, target: [0, 8], engaged: true, mayWindUp: false, motion: Self.open,
          guardian: nil, others: [])
        if crawler.phase == .approaching { return Float(step) * Self.dt }
      }
      return nil
    }
    let one = try #require(timeToGetUp(&first))
    let three = try #require(timeToGetUp(&third))
    #expect(abs(one - Crawler.unfoldTime) < 0.02)
    #expect(abs(three - (Crawler.unfoldTime + 2 * Crawler.slotDelay)) < 0.02)
  }

  @Test
  func itWalksUpToItsTargetAndStopsJustInsideRamRangeWhenItMayNotWindUp() {
    var crawler = Crawler(home: .zero)
    crawler.reveal()
    _ = run(&crawler, seconds: 8, target: [0, 10], mayWindUp: false)
    #expect(crawler.phase == .approaching)
    let distance = simd_distance(crawler.position, [0, 10])
    #expect(distance <= Crawler.ramRange && distance > Crawler.ramRange - 0.5)
  }

  @Test
  func itsRamLineIsFixedWhenTheWindUpStartsAndTheRamSweepsIt() throws {
    var crawler = Crawler(home: .zero)
    crawler.reveal()
    _ = run(&crawler, seconds: 6, target: [0, 6]) { $0.phase == .windingUp }
    try #require(crawler.phase == .windingUp)
    let start = try #require(crawler.ramStart)
    let end = try #require(crawler.ramEnd)
    #expect(abs(simd_distance(start, end) - Crawler.ramDistance) < 0.001)
    // The member steps aside during the wind-up; the line does not follow them.
    var windUp: Float = 0
    var rams: [Crawler.Ram] = []
    for _ in 0..<Int(3 / Self.dt) {
      if crawler.phase == .windingUp { windUp += Self.dt }
      if let ram = crawler.step(
        dt: Self.dt, target: [3, 6], engaged: true, mayWindUp: true, motion: Self.open,
        guardian: nil, others: [])
      {
        rams.append(ram)
      }
      if crawler.phase == .recovering { break }
      if crawler.isAttacking {
        #expect(crawler.ramStart == start && crawler.ramEnd == end)
      }
    }
    #expect(windUp >= Crawler.windUpTime - Self.dt)
    try #require(crawler.phase == .recovering)
    #expect(simd_distance(crawler.position, end) < 0.01)
    #expect(!rams.isEmpty && simd_distance(rams[0].from, start) < 0.01)
    #expect(rams.allSatisfy { Crawler.distance(from: $0.to, toSegment: start, end) < 0.001 })
  }

  @Test
  func aRamCanHurtAtMostOnceAndOnlyWhileItRamsOrRecovers() throws {
    var crawler = Crawler(home: .zero)
    let early = crawler.acceptRamHit()
    #expect(!early)
    crawler.reveal()
    _ = run(&crawler, seconds: 6, target: [0, 6]) { $0.phase == .ramming }
    try #require(crawler.phase == .ramming)
    let first = crawler.acceptRamHit()
    let second = crawler.acceptRamHit()
    #expect(first && !second)
  }

  @Test
  func afterARamItRecoversExposedAndWaitsBeforeTheNextWindUp() throws {
    var crawler = Crawler(home: .zero)
    crawler.reveal()
    _ = run(&crawler, seconds: 6, target: [0, 6]) { $0.phase == .recovering }
    try #require(crawler.phase == .recovering)
    var recovering: Float = 0
    var untilNext: Float = 0
    for _ in 0..<Int(6 / Self.dt) {
      _ = crawler.step(
        dt: Self.dt, target: crawler.position + [0, 2], engaged: true, mayWindUp: true,
        motion: Self.open, guardian: nil, others: [])
      if crawler.phase == .recovering { recovering += Self.dt } else { untilNext += Self.dt }
      if crawler.phase == .windingUp { break }
    }
    #expect(abs(recovering - Crawler.recoverTime) < 0.02)
    #expect(recovering + untilNext >= Crawler.attackInterval - 0.02)
  }

  @Test
  func beyondItsLeashItTurnsBackHome() {
    var crawler = Crawler(home: .zero)
    crawler.reveal()
    _ = run(&crawler, seconds: 6, target: [0, 6], mayWindUp: false)
    _ = run(&crawler, seconds: 10, target: [0, Crawler.leash + 5], mayWindUp: false)
    #expect(simd_distance(crawler.position, .zero) < 0.1)
  }

  @Test
  func itSlidesRoundAWallAndNeverWalksThroughTheGuard() {
    let wall = PartyMotion.Box(minimum: [-1, 3], maximum: [1, 4])
    let motion = PartyMotion(radius: Crawler.radius, obstacles: [wall])
    var crawler = Crawler(home: .zero)
    crawler.reveal()
    var closest: Float = .infinity
    for _ in 0..<Int(12 / Self.dt) {
      _ = crawler.step(
        dt: Self.dt, target: [0, 9], engaged: true, mayWindUp: false, motion: motion,
        guardian: (centre: [3, 5], radius: 1.2), others: [])
      let insideWall =
        crawler.position.x > -1 && crawler.position.x < 1 && crawler.position.y > 3
        && crawler.position.y < 4
      #expect(!insideWall)
      closest = min(closest, simd_distance(crawler.position, [3, 5]))
    }
    #expect(closest >= 1.2 + Crawler.radius - 0.01)
    #expect(simd_distance(crawler.position, [0, 9]) < Crawler.ramRange + 0.5)
  }

  @Test
  func knockedDownItCollapsesAndCannotBeTargeted() {
    var crawler = Crawler(home: .zero)
    crawler.reveal()
    crawler.knockDown()
    #expect(crawler.isDown && !crawler.isTargetable)
    let rams = run(&crawler, seconds: 2, target: [0, 2])
    #expect(rams.isEmpty && crawler.fallen == 1 && crawler.position == .zero)
    let accepted = crawler.acceptRamHit()
    #expect(!accepted)
  }

  @Test
  func afterTheQuietExitItWalksHomeFoldsAndNeverRams() {
    var crawler = Crawler(home: .zero)
    crawler.reveal()
    _ = run(&crawler, seconds: 4, target: [0, 8], mayWindUp: false)
    crawler.clear()
    let rams = run(&crawler, seconds: 6, target: [0, 8])
    #expect(rams.isEmpty && crawler.phase == .cleared && !crawler.isTargetable)
    #expect(simd_distance(crawler.position, .zero) < 0.1)
  }

  @Test
  func itsWayCoversOnlyTheFixedLineWhileItWindsUpOrRams() throws {
    var crawler = Crawler(home: .zero)
    crawler.reveal()
    #expect(!crawler.threatens(.zero))
    _ = run(&crawler, seconds: 6, target: [0, 6]) { $0.phase == .windingUp }
    let start = try #require(crawler.ramStart)
    let end = try #require(crawler.ramEnd)
    #expect(crawler.threatens((start + end) / 2))
    #expect(crawler.threatens((start + end) / 2 + [Crawler.reach, 0]))
    #expect(!crawler.threatens((start + end) / 2 + [Crawler.reach + 1, 0]))
  }

  @Test
  func aRamStopsAtTheFirstBlockerOnItsLineRatherThanSlidingAlongIt() throws {
    // The line meets a wall's face at a slant; sliding along it would leave the line.
    let wall = PartyMotion.Box(minimum: [-6, 2], maximum: [6, 3])
    let motion = PartyMotion(radius: Crawler.radius, obstacles: [wall])
    var crawler = Crawler(home: .zero)
    crawler.reveal()
    _ = run(&crawler, seconds: 4, target: [1.5, 1.8], motion: motion) { $0.phase == .windingUp }
    let start = try #require(crawler.ramStart)
    let end = try #require(crawler.ramEnd)
    _ = run(&crawler, seconds: 2, target: [1.5, 1.8], motion: motion) { $0.phase == .recovering }
    #expect(crawler.phase == .recovering)
    #expect(Crawler.distance(from: crawler.position, toSegment: start, end) < 0.01)
    #expect(crawler.position.y <= 2 - Crawler.radius + 0.01)
    #expect(simd_distance(crawler.position, end) > 0.3, "the wall stopped it short of its end")
  }

  @Test
  func unusableStepsChangeNothing() {
    var crawler = Crawler(home: .zero)
    crawler.reveal()
    _ = run(&crawler, seconds: 2, target: [0, 8], mayWindUp: false)
    let before = (crawler.position, crawler.phase)
    for dt in [Float.nan, 0, -1, .infinity] {
      _ = crawler.step(
        dt: dt, target: [0, 8], engaged: true, mayWindUp: true, motion: Self.open,
        guardian: nil, others: [])
    }
    #expect(crawler.position == before.0 && crawler.phase == before.1)
  }
}

/// Crawlers in a guard's fight (issue #208): they wait for it, wind up only between its
/// attacks and never two on one member, rams hurt once, a rifle round downs one, they go down
/// with the guard, the quiet exit clears them and the lock takes them.
@MainActor
struct CrawlerFightTests {
  @Test
  func theyStayFoldedUntilTheGuardNoticesTheParty() throws {
    let range = try Range(party: [0, 30])
    for _ in 0..<(10 * 120) {
      range.step()
      for id in Range.crawlers {
        #expect(range.fight.hostiles[id]?.crawler?.phase == .folded)
      }
    }
    #expect(!range.events.contains { if case .crawlerWarning = $0 { true } else { false } })
  }

  @Test
  func onceEngagedTheyRamBetweenTheGuardsAttacksAndNeverTwoOnOneMember() throws {
    let range = try Range(party: [0, 8])
    var windUps = 0
    var previous: [String: Crawler.Phase] = [:]
    for _ in 0..<(30 * 120) {
      range.step()
      let guardPhase = try #require(range.fight.hostiles[Range.guardID]?.robot?.phase)
      var attacking: [PartyMember] = []
      for id in Range.crawlers {
        guard let crawler = range.fight.hostiles[id]?.crawler else { continue }
        if crawler.phase == .windingUp, previous[id] != .windingUp {
          windUps += 1
          // A wind-up starts only while the guard patrols, recovers or searches.
          #expect([.patrol, .recovering, .searching].contains(guardPhase))
        }
        if crawler.isAttacking, let member = range.fight.crawlerTarget(for: id) {
          attacking.append(member)
        }
        previous[id] = crawler.phase
      }
      #expect(Set(attacking).count == attacking.count)
    }
    #expect(windUps >= 3)
  }

  @Test
  func aRamHurtsAtMostOneMemberOnce() throws {
    // Without a guard the pack engages at once, and every injury comes from a ram.
    let range = try Range(party: [0, 8], touchable: true, withGuard: false)
    var rams = 0
    var previous: [String: Crawler.Phase] = [:]
    for _ in 0..<(40 * 120) where !range.isRetrying {
      range.step()
      for id in Range.crawlers {
        guard let crawler = range.fight.hostiles[id]?.crawler else { continue }
        if crawler.phase == .ramming, previous[id] != .ramming { rams += 1 }
        previous[id] = crawler.phase
      }
      #expect(range.totalHits <= rams)
    }
    #expect(rams >= 1 && range.totalHits >= 1)
  }

  @Test
  func oneAssistedRifleRoundDownsACrawlerOnTheSnow() throws {
    // From the side, so the guard's body is not in the way.
    let range = try Range(party: [-6, 6])
    var downed: DamageHit?
    for _ in 0..<(20 * 120) where downed == nil {
      range.step(fireAt: Range.crawlers[0])
      downed = range.hits.first { $0.target == Range.crawlers[0] }
    }
    let hit = try #require(downed)
    #expect(hit.amount == Crawler.health && hit.position.y < 0.6)
    #expect(range.fight.hostiles[Range.crawlers[0]]?.isDown == true)
    #expect(range.session.defeated.contains(Range.crawlers[0]))
  }

  @Test
  func downingTheGuardTakesItsCrawlersDownAndEndsTheFight() throws {
    let range = try Range(party: [0, 6])
    for _ in 0..<(120 * 120) where range.session.inEncounter {
      range.step(fireAt: Range.guardID)
    }
    #expect(!range.session.inEncounter)
    #expect(range.session.defeated == Set([Range.guardID] + Range.crawlers))
    for _ in 0..<120 { range.step() }
    for id in Range.crawlers {
      let crawler = try #require(range.fight.hostiles[id]?.crawler)
      #expect(crawler.isDown && crawler.fallen == 1)
    }
  }

  @Test
  func theQuietExitSendsTheCrawlersHomeHarmlessly() throws {
    let range = try Range(party: [0, 30])
    range.step()
    #expect(range.fight.resolveRobotBypass(id: Range.guardID, session: range.session))
    for _ in 0..<(3 * 120) { range.step() }
    for id in Range.crawlers {
      let state = try #require(range.fight.hostiles[id])
      #expect(state.crawler?.phase == .cleared && !state.isTargetable)
    }
  }

  @Test
  func theLockCanTakeEachCrawler() throws {
    let range = try Range(party: [0, 8])
    range.step()
    var locked: Set<String> = []
    for _ in 0..<8 {
      range.fight.selectLock(
        from: [0, 8], facing: [0, -1], up: [0, -1], right: [1, 0], advancing: true)
      if let lock = range.fight.lock { locked.insert(lock) }
    }
    #expect(locked == Set([Range.guardID] + Range.crawlers))
  }

  @Test
  func tomsDomeSheltersAMemberDeepInsideItFromARamThatSetOffOutside() throws {
    // Tom leads with his dome up. The crawler goes for Laura, nearer it and inside the dome,
    // setting off from outside the dome; it meets her well inside, where the step's own
    // start is inside too.
    let figures: [PartyMember: SIMD2<Float>] = [.tom: [0, 6], .laura: [0, 5], .miki: [9, 13]]
    let pack = Level.Hostile(
      id: "crawler", name: "Crawler", hiddenAt: .zero, standAt: .zero, hits: Crawler.health,
      attack: .crawler(slot: 0))
    let encounter = Level.Encounter(
      beat: .stranger, start: .area(.init(minimum: [-40, -40], maximum: [40, 40])),
      retryAt: [0, 6], hostiles: [pack], cues: [(0, .reveal("crawler")), (0, .engage("crawler"))])
    let level = Level(
      id: "crawler-dome", ground: .box("floor", at: [0, -0.15, 0], size: [100, 0.3, 100]),
      boxes: [], triggers: [], encounters: [encounter], party: [.miki, .tom, .laura],
      spawns: figures, heading: [0, -1], cameraOffset: BrooklynBridge.cameraOffset,
      fieldOfView: 22, opening: "Range", objective: "Test", lookAround: "Range",
      restartNote: "Restart")
    let session = GameSession(level: level)
    session.cycleLeader()
    try #require(session.leader == .tom)
    let fight = EncounterSimulation(level: level)
    try #require(session.beginEncounter(encounter.beat))
    fight.begin(encounter)
    fight.swapWeapon(for: .tom)
    var origins: [SIMD2<Float>] = []
    var blocked = 0
    var previous = Crawler.Phase.hidden
    for _ in 0..<(120 * 4) {
      _ = fight.step(
        dt: 1 / 120, leader: [0, 6], facing: [0, -1], aiming: true, fireHeld: true,
        firePressed: false, figures: figures, session: session)
      blocked +=
        fight.takeEvents().filter { if case .struckBlock = $0 { true } else { false } }
        .count
      let crawler = try #require(fight.hostiles["crawler"]?.crawler)
      if crawler.phase == .windingUp, previous != .windingUp, let start = crawler.ramStart {
        origins.append(start)
      }
      previous = crawler.phase
      if !origins.isEmpty, crawler.phase == .recovering { break }
    }
    let origin = try #require(origins.first, "the crawler never wound up")
    #expect(fight.shieldIsUp)
    #expect(simd_distance(origin, [0, 6]) > ShieldDome.radius, "it set off outside the dome")
    #expect(blocked == 1)
    #expect(session.hits(of: .laura) == 0 && session.hits(of: .tom) == 0)
  }

  @Test
  func aWindUpOutranksTheGuardsRecoveryOnTheHUDButNotItsWarnedAttack() throws {
    let range = try Range(party: [0, 8])
    var seenDuringRecovery = false
    for _ in 0..<(30 * 120) {
      range.step()
      let robot = try #require(range.fight.hostiles[Range.guardID]?.robot)
      let crawling = Range.crawlers.contains {
        range.fight.hostiles[$0]?.crawler.map { $0.phase == .windingUp || $0.phase == .ramming }
          ?? false
      }
      let text = range.fight.threat ?? ""
      if [.notice, .tracking, .committed, .burst].contains(robot.phase) {
        #expect(!text.contains("winding up") && !text.contains("ramming"))
      } else if robot.phase == .recovering, crawling {
        seenDuringRecovery = true
        #expect(text.contains("winding up") || text.contains("ramming"), "HUD said: \(text)")
      }
    }
    #expect(seenDuringRecovery, "no crawler attacked during the guard's recovery")
  }

  /// A guard and three crawlers on an open range, with the party together at one point.
  /// Members are untouchable unless a test needs real hits.
  @MainActor
  private final class Range {
    static let guardID = "guard"
    static let crawlers = ["crawler.1", "crawler.2", "crawler.3"]
    let fight: EncounterSimulation
    let session: GameSession
    private(set) var hits: [DamageHit] = []
    private(set) var events: [CombatEvent] = []
    private(set) var isRetrying = false
    private let figures: [PartyMember: SIMD2<Float>]
    private let touchable: Bool

    var totalHits: Int { PartyMember.allCases.reduce(0) { $0 + session.hits(of: $1) } }

    init(party point: SIMD2<Float>, touchable: Bool = false, withGuard: Bool = true) throws {
      self.touchable = touchable
      figures = [.miki: point, .tom: point + [-1.5, 0.5], .laura: point + [1.5, 0.5]]
      let guardian = Level.Hostile(
        id: Self.guardID, name: "Guard", hiddenAt: .zero, standAt: .zero, hits: 6,
        attack: .robot, strategicGuard: true, range: 12)
      let offsets: [SIMD2<Float>] = [[-2.6, -1.4], [2.6, -1.4], [0, -3]]
      let pack = Self.crawlers.enumerated().map { index, id in
        Level.Hostile(
          id: id, name: "Crawler", hiddenAt: offsets[index], standAt: offsets[index],
          hits: Crawler.health, attack: .crawler(slot: index))
      }
      let hostiles = (withGuard ? [guardian] : []) + pack
      var cues: [(at: Float, cue: Level.Cue)] = []
      for hostile in hostiles {
        cues += [(0, .reveal(hostile.id)), (0, .engage(hostile.id))]
      }
      let encounter = Level.Encounter(
        beat: .stranger, start: .area(.init(minimum: [-40, -40], maximum: [40, 40])),
        retryAt: point, hostiles: hostiles, cues: cues,
        safeExit: .init(minimum: [30, 30], maximum: [35, 35]))
      let level = Level(
        id: "crawler-range", ground: .box("floor", at: [0, -0.15, 0], size: [100, 0.3, 100]),
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
      let outcome = fight.step(
        dt: 1 / 120, leader: leader, facing: facing, aiming: fire, fireHeld: fire,
        firePressed: fire, figures: figures, session: session,
        untouchable: touchable ? [] : Set(PartyMember.allCases))
      if outcome.retry { isRetrying = true }
      for event in fight.takeEvents() {
        events.append(event)
        if case .damaged(let hit) = event { hits.append(hit) }
      }
    }
  }
}
