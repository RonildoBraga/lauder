import RealityKit
import Testing
import simd

@testable import Lauder

/// Small encounters drive the production fight, independent of the combat yard's timeline.
@MainActor
struct TacticalCombatTests {
  @Test
  func aWarnedThrowLaunchesWithoutDamageAndItsLandingDoesNotFollowTheParty() throws {
    let level = range(hostiles: [thrower()])
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    try begin(fight, session: session, level: level)
    for _ in 0..<12 { step(fight, session: session, figures: level.spawns) }
    #expect(fight.grenades.isEmpty && fight.grenadesThrown == 0)
    #expect(fight.threat == "Thrower is preparing a grenade.")

    let grenade = try launch(fight, session: session, figures: level.spawns)
    #expect(grenade.start == [0, -5] && grenade.position == .zero)
    #expect(grenade.remaining == Grenade.fuse)
    #expect(fight.grenadesThrown == 1 && fight.grenadesExploded == 0)
    #expect(fight.shots.isEmpty && session.hitsTaken == 0)
    let escaped: [PartyMember: SIMD2<Float>] = [.miki: [4, 0]]
    for _ in 0..<60 {
      step(fight, session: session, figures: escaped)
      #expect(fight.grenades.first?.position == grenade.position)
    }
    try detonate(fight, session: session, figures: escaped)
    #expect(fight.explosions == [grenade.position])
    #expect(fight.grenades.isEmpty && session.hitsTaken == 0)
    for _ in 0..<120 { step(fight, session: session, figures: escaped) }
    #expect(fight.grenadesExploded == 1 && fight.grenadesThrown == 1)
    #expect(fight.explosions.isEmpty && session.hitsTaken == 0)
  }

  @Test(arguments: [Float(1), LeaderCover.lowHeight, Float(3)])
  func aBlastHitsEachNearbyMemberOnceAndOnlyTallWallsShieldIt(height: Float) throws {
    let figures: [PartyMember: SIMD2<Float>] = [
      .miki: .zero, .tom: [-1, 0], .laura: [5, 5],
    ]
    let level = range(
      hostiles: [thrower()],
      boxes: [.box("blast-wall", at: [0, height / 2, 0.9], size: [4, height, 0.3])],
      figures: figures)
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    try begin(fight, session: session, level: level)
    _ = try launch(fight, session: session, figures: figures)
    // Miki is inside the marked radius, across the wall from the landing point. Tom stays
    // on its open side; Laura is outside the blast. No companion weapon changes this fight.
    var afterLaunch = figures
    afterLaunch[.miki] = [0, 1.8]
    _ = fight.takeEvents()
    try detonate(fight, session: session, figures: afterLaunch)
    #expect(session.hits(of: .miki) == (height < LeaderCover.lowHeight ? 1 : 0))
    #expect(session.hits(of: .tom) == 1 && session.hits(of: .laura) == 0)
    #expect(fight.grenadesExploded == 1)
    #expect(fight.takeEvents().filter { $0 == .struckBlock(at: .zero) }.count == 1)
    #expect(fight.takeEvents().isEmpty)
    for _ in 0..<120 { step(fight, session: session, figures: afterLaunch) }
    #expect(session.hits(of: .tom) == 1 && fight.grenadesExploded == 1)
  }

  @Test
  func aReleasedGrenadeOutlivesItsThrowerAndKeepsTheEncounterOpenUntilDetonation() throws {
    let level = range(
      hostiles: [thrower()], extraCues: [(0.5, .shot(by: .miki, at: "thrower"))])
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    try begin(fight, session: session, level: level)
    let grenade = try launch(fight, session: session, figures: level.spawns)
    for _ in 0..<60 { step(fight, session: session, figures: level.spawns) }
    #expect(fight.hostiles["thrower"]?.isDown == true)
    #expect(session.defeated == ["thrower"] && session.inEncounter)
    #expect(fight.grenades.first?.id == grenade.id && fight.grenadesExploded == 0)
    _ = fight.takeEvents()
    try detonate(fight, session: session, figures: level.spawns)
    #expect(fight.takeEvents().contains(.leaderHit(at: .zero)))
    #expect(fight.grenadesExploded == 1)
    // Winning the encounter heals the party, after the pending blast has resolved.
    #expect(!session.inEncounter && !fight.fightUnderWay && fight.grenades.isEmpty)
    for _ in 0..<120 { step(fight, session: session, figures: level.spawns) }
    #expect(session.hitsTaken == 0 && fight.grenadesExploded == 1)
  }

  @Test
  func fallbackClearsFlightsAndMovementWhileDamageSurvivesUntilRestart() throws {
    let flank = shooter("flank", at: [7, -7], behavior: .flank, windUp: 60)
    let level = range(hostiles: [thrower(hits: 2), flank])
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    try begin(fight, session: session, level: level)
    _ = try launch(fight, session: session, figures: level.spawns)
    let first = try fireOnce(fight, session: session, figures: level.spawns, at: [0, -5])
    #expect(first.path.strike == .body("thrower") && session.defeated.isEmpty)
    #expect(fight.movedEnemies.contains(flank.id) && !fight.grenades.isEmpty)

    session.fallBack()
    fight.fallBack()
    #expect(fight.grenades.isEmpty && fight.explosions.isEmpty)
    #expect(fight.enemyCoverStates.isEmpty && !fight.fightUnderWay)
    #expect(fight.hostiles[flank.id]?.position == flank.standAt)
    for _ in 0..<60 { step(fight, session: session, figures: level.spawns) }
    #expect(fight.hostiles[flank.id]?.position == flank.standAt)
    #expect(fight.grenades.isEmpty && session.hitsTaken == 0)

    try begin(fight, session: session, level: level)
    _ = try launch(fight, session: session, figures: level.spawns)
    let second = try fireOnce(fight, session: session, figures: level.spawns, at: [0, -5])
    #expect(second.path.strike == .body("thrower"))
    #expect(session.defeated == ["thrower"] && fight.hostiles["thrower"]?.isDown == true)
    #expect(!fight.grenades.isEmpty)
    session.restart()
    fight.reset()
    #expect(session.defeated.isEmpty && session.ammo == level.startingAmmo)
    #expect(fight.grenades.isEmpty && fight.explosions.isEmpty && fight.enemyCoverStates.isEmpty)
    #expect(fight.grenadesThrown == 0 && fight.grenadesExploded == 0 && fight.movedEnemies.isEmpty)
    #expect(fight.hostiles["thrower"]?.isDown == false)
    #expect(fight.hostiles[flank.id]?.position == flank.standAt)
  }

  @Test
  func tacticalMovementReachesTheFightWithoutCrossingWallsOrFiringWhileMoving() throws {
    let spec = shooter("flank", at: [0, -6], behavior: .flank)
    let level = range(
      hostiles: [spec], boxes: [.box("wall", at: [0, 1.5, -4], size: [4, 3, 1])],
      figures: [.miki: [0, 5]])
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    let motion = PartyMotion(radius: PartyBody.radius, obstacles: level.obstacles)
    try begin(fight, session: session, level: level)
    for _ in 0..<300 {
      let before = try #require(fight.hostiles[spec.id]?.position)
      step(fight, session: session, figures: level.spawns, dt: 1 / 60)
      let after = try #require(fight.hostiles[spec.id]?.position)
      #expect(motion.canTraverse(from: before, to: after))
      #expect(simd_distance(after, before) <= EnemyTactics.speed / 60 + 0.0001)
      #expect(simd_distance(after, spec.standAt) <= EnemyTactics.homeReach + 0.0001)
      #expect(level.bounds.contains(after))
      if simd_distance_squared(before, after) > 0.0000001 {
        #expect(fight.shots.isEmpty)
      }
    }
    let final = try #require(fight.hostiles[spec.id]?.position)
    #expect(fight.movedEnemies == [spec.id] && abs(final.x) > 2.3)
  }

  @Test
  func aTacticalShooterCanOnlyBeShotOverLowCoverDuringItsCommittedExposure() throws {
    let spec = shooter("cover", at: [0, -2], behavior: .takeCover, hits: 1, windUp: 2)
    let level = range(
      hostiles: [spec], boxes: [.box("low", at: [0, 0.5, 0], size: [4, 1, 1])],
      figures: [.miki: [0, 5]])
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    try begin(fight, session: session, level: level)
    var crouched = false
    for _ in 0..<240 {
      step(fight, session: session, figures: level.spawns)
      if let cover = fight.enemyCoverStates[spec.id], cover.isLow && !cover.exposed {
        crouched = true
        break
      }
    }
    try #require(crouched)
    let hiddenPoint = try #require(fight.hostiles[spec.id]?.position)
    let blocked = try fireOnce(fight, session: session, figures: level.spawns, at: hiddenPoint)
    #expect(blocked.path.strike != .body(spec.id) && session.defeated.isEmpty)

    var exposed = false
    for _ in 0..<600 {
      step(fight, session: session, figures: level.spawns)
      if fight.enemyCoverStates[spec.id]?.firing == true {
        exposed = true
        break
      }
    }
    try #require(exposed)
    #expect(fight.enemyCoverStates[spec.id]?.exposed == true)
    let exposedPoint = try #require(fight.hostiles[spec.id]?.position)
    let hit = try fireOnce(fight, session: session, figures: level.spawns, at: exposedPoint)
    #expect(hit.path.strike == .body(spec.id) && session.defeated == [spec.id])
  }

  @Test
  func aTallEdgeThreatAndThePartyShieldAgreeWithTheActualIncomingShot() throws {
    let spec = shooter(
      "peek", at: [0.75, -0.9], behavior: .takeCover, windUp: 0.3, reaction: 0.1)
    let level = range(
      hostiles: [spec], boxes: mirroredCover, figures: [.miki: [1.5, 4]])
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    let coverRules = LeaderCover(boxes: level.boxes, ground: level.bounds)
    try begin(fight, session: session, level: level)
    var incoming: FightSimulation.Shot?
    var threatenedFromPeek = false
    for _ in 0..<360 {
      step(fight, session: session, figures: level.spawns)
      if let shield = fight.coverState, let threat = fight.threats.first {
        let anchor = try #require(fight.hostiles[spec.id]?.position)
        let point = shield.position + shield.offset
        let shelter = coverRules.shelter(at: shield.position, facing: [0, -1])
        let blockers = coverRules.incomingBlockers(in: shelter, exposed: shield.firing)
        let clear =
          simd_distance(threat.position, point) <= threat.range
          && LineOfSight.isClear(from: threat.position, to: point, obstacles: blockers)
        #expect(shield.exposed == clear)
        if clear, !LineOfSight.isClear(from: anchor, to: point, obstacles: blockers) {
          threatenedFromPeek = true
        }
      }
      if let shot = fight.shots.first(where: { if case .hostile = $0.side { true } else { false } })
      {
        incoming = shot
        break
      }
    }
    let shot = try #require(incoming)
    let shield = try #require(fight.coverState)
    let enemy = try #require(fight.enemyCoverStates[spec.id])
    let threat = try #require(fight.threats.first)
    #expect(threatenedFromPeek && !enemy.isLow && enemy.firing)
    #expect(simd_length(enemy.offset) > 0.1)
    #expect(simd_distance(shot.path.start, enemy.position + enemy.offset) < 0.001)
    #expect(simd_distance(threat.position, shot.path.start) < 0.001)
    #expect(shield.exposed && shot.path.strike == .body(PartyMember.miki.rawValue))
    #expect(
      abs(simd_distance(shot.path.end, shield.position + shield.offset) - Aim.bodyRadius) < 0.001)
    let trace = try #require(shot.trace)
    let crouched = shield.isLow && !shield.firing
    let centreHeight = FightSimulation.aimHeight * (crouched ? 0.68 : 1)
    #expect(trace.path == shot.path)
    #expect(abs(trace.end.y - centreHeight) <= (crouched ? 0.3 : 0.6) + 0.001)
    #expect(session.hitsTaken == 1)
  }

  @Test
  func anEnemyShieldAccountsForTheLeadersPotentialTallEdgeShot() throws {
    let spec = shooter("cover", at: [1.5, 4], behavior: .takeCover, windUp: 60, reaction: 0.1)
    let level = range(
      hostiles: [spec], boxes: mirroredCover, figures: [.miki: [0.75, -0.9]])
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    let rules = LeaderCover(boxes: level.boxes, ground: level.bounds)
    let leader = level.spawn(.miki)
    let facing = simd_normalize(spec.standAt - leader)
    try begin(fight, session: session, level: level)
    for _ in 0..<4 { step(fight, session: session, figures: level.spawns, facing: facing) }

    let shield = try #require(fight.enemyCoverStates[spec.id])
    let leaderCover = try #require(rules.shelter(at: leader, facing: facing))
    let origin = try #require(rules.firingPoint(from: leader, in: leaderCover, facing: facing))
    let enemyCover = rules.shelter(at: shield.position, facing: leader - shield.position)
    let blockers = rules.incomingBlockers(in: enemyCover, exposed: shield.firing)
    #expect(!LineOfSight.isClear(from: leader, to: shield.position, obstacles: blockers))
    #expect(LineOfSight.isClear(from: origin, to: shield.position, obstacles: blockers))
    #expect(shield.isLow && shield.exposed && !shield.firing)
    #expect(fight.coverState?.firing == false && fight.shots.isEmpty)

    let shot = try fireOnce(fight, session: session, figures: level.spawns, at: spec.standAt)
    let peeking = try #require(fight.coverState)
    #expect(shot.path.strike == .body(spec.id) && fight.enemyCoverStates[spec.id]?.exposed == true)
    #expect(peeking.firing && simd_length(peeking.offset) > 0.1)
    #expect(simd_distance(shot.path.start, peeking.position + peeking.offset) < 0.001)
  }

  @Test(arguments: [Float(1), Float(3)])
  func disruptCannotReachACrouchedEnemyButCanAnswerItsRetainedFiringExposure(height: Float) throws {
    let spec = shooter(
      "cover", at: [0.75, -0.9], behavior: .takeCover, windUp: 0.6, reaction: 0.1,
      recovery: 0.05)
    let level = range(
      hostiles: [spec], boxes: [.box("cover", at: [0, height / 2, 0], size: [2, height, 0.5])],
      figures: [.miki: [1.5, 4]], disrupt: true)
    let session = GameSession(level: level)
    let fight = FightSimulation(level: level)
    try begin(fight, session: session, level: level)
    var windingUp = false
    for _ in 0..<60 {
      step(fight, session: session, figures: level.spawns, mayDisrupt: true)
      if case .aiming = fight.hostiles[spec.id]?.phase {
        windingUp = true
        break
      }
    }
    try #require(windingUp)
    #expect(fight.enemyCoverStates[spec.id]?.firing == false && !fight.canDisrupt)
    let rounds = session.ammo
    step(fight, session: session, figures: level.spawns, mayDisrupt: true, signature: true)
    #expect(fight.disrupts == 0 && fight.shots.isEmpty)
    #expect(fight.enemyCoverStates[spec.id]?.firing == false)

    // A real shot, then a brief recovery, leaves an exposed body during the next wind-up.
    // Cancelling that next wind-up must neither invent a peek nor hide the prior one.
    var retainedExposure = false
    for _ in 0..<600 {
      step(fight, session: session, figures: level.spawns, mayDisrupt: true)
      if fight.enemyCoverStates[spec.id]?.firing == true,
        case .aiming = fight.hostiles[spec.id]?.phase
      {
        retainedExposure = true
        break
      }
    }
    try #require(retainedExposure && fight.canDisrupt)
    step(fight, session: session, figures: level.spawns, mayDisrupt: true, signature: true)
    let exposed = try #require(fight.enemyCoverStates[spec.id])
    let shot = try #require(fight.shots.first)
    #expect(fight.disrupts == 1 && fight.shots.count == 1 && session.ammo == rounds)
    #expect(shot.path.strike == .body(spec.id) && exposed.firing)
    #expect(simd_distance(shot.path.end, exposed.position + exposed.offset) < 0.001)
    if height >= LeaderCover.lowHeight { #expect(simd_length(exposed.offset) > 0.1) }
    if case .recovering = fight.hostiles[spec.id]?.phase {
    } else {
      Issue.record("Disrupt must cancel the current wind-up")
    }
  }

  @Test
  func pauseFreezesTheWorldsLiveGrenadeAndResumingFinishesTheSameFuse() throws {
    let world = GameWorld(
      level: range(
        hostiles: [thrower()], figures: [.miki: .zero, .tom: [4, 5], .laura: [-4, 5]]))
    let marker = try #require(world.root.findEntity(named: "grenade.marker.thrower"))
    try #require(run(world, upTo: 1) { marker.isEnabled })
    let countdown = try #require(marker.findEntity(named: "grenade.countdown"))
    let projectile = try #require(marker.findEntity(named: "grenade.projectile"))
    pressPause(world)
    try #require(world.isPaused)
    let scale = countdown.scale
    let point = projectile.position
    for _ in 0..<300 {
      world.update(with: .neutral, sampledIn: .paused, deltaTime: 1 / 60)
    }
    #expect(marker.isEnabled && countdown.scale == scale && projectile.position == point)
    #expect(world.session.hitsTaken == 0)
    pressPause(world)
    #expect(!world.isPaused)
    for _ in 0..<30 { world.advanceParty(movement: .zero, deltaTime: 1 / 60) }
    #expect(marker.isEnabled && countdown.scale.x < scale.x && world.session.hitsTaken == 0)
    #expect(run(world, upTo: Grenade.fuse) { world.session.hitsTaken == 1 })
    #expect(!marker.isEnabled && world.fallBacks == 0)
  }

  private func thrower(hits: Int = 50) -> Level.Hostile {
    Level.Hostile(
      id: "thrower", name: "Thrower", hiddenAt: [0, -5], standAt: [0, -5], hits: hits,
      attack: .throwGrenade, windUp: 0.2, recovery: 60, range: 14, inView: true,
      targetFromWindUp: true)
  }

  private func shooter(
    _ id: String, at point: SIMD2<Float>, behavior: Level.Hostile.Behavior,
    hits: Int = 50, windUp: Float = 2, reaction: Float = 0, recovery: Float = 60
  ) -> Level.Hostile {
    Level.Hostile(
      id: id, name: id, hiddenAt: point, standAt: point, hits: hits, behavior: behavior,
      reactionDelay: reaction, windUp: windUp, recovery: recovery, range: 14, inView: true,
      targetFromWindUp: true)
  }

  /// One tall corner, with a side-facing low block on the other end of its clear peek line.
  private var mirroredCover: [Level.Box] {
    [
      .box("tall", at: [0, 1.5, 0], size: [2, 3, 0.5]),
      .box("side", at: [0.3, 0.5, 4], size: [1, 1, 2]),
    ]
  }

  private func range(
    hostiles: [Level.Hostile], boxes: [Level.Box] = [],
    figures: [PartyMember: SIMD2<Float>] = [.miki: .zero],
    extraCues: [(at: Float, cue: Level.Cue)] = [], disrupt: Bool = false
  ) -> Level {
    let encounter = Level.Encounter(
      beat: .stranger, start: .area(PartyMotion.Box(minimum: [-12, -12], maximum: [12, 12])),
      retryAt: figures[.miki], hostiles: hostiles,
      cues: hostiles.map { (0, .engage($0.id)) } + extraCues)
    return Level(
      id: "tactical-combat-range",
      ground: .box("ground", at: [0, -0.15, 0], size: [24, 0.3, 24]), boxes: boxes,
      interactions: [], triggers: [], encounters: [encounter], startingAmmo: 60,
      party: [.miki, .tom, .laura].filter { figures[$0] != nil }, spawns: figures,
      heading: [0, -1], cameraOffset: TestYard.cameraOffset, fieldOfView: 42,
      opening: "Snow.", objective: "Test.", lookAround: "A range.", restartNote: "Restart.",
      combat: Level.Combat(fallsBack: true, disrupt: disrupt, leaderCover: true))
  }

  private func begin(_ fight: FightSimulation, session: GameSession, level: Level) throws {
    let encounter = try #require(level.encounters.first)
    try #require(session.beginEncounter(encounter.beat))
    fight.begin(encounter)
  }

  @discardableResult
  private func step(
    _ fight: FightSimulation, session: GameSession, figures: [PartyMember: SIMD2<Float>],
    dt: Float = 1 / 120, facing: SIMD2<Float> = [0, -1], fire: Bool = false,
    pressed: Bool = false, mayDisrupt: Bool = false, signature: Bool = false
  ) -> FightSimulation.Outcome {
    fight.step(
      dt: dt, leader: figures[session.leader]!, facing: facing, aiming: true,
      fireHeld: fire, firePressed: pressed, mayDisrupt: mayDisrupt, signaturePressed: signature,
      figures: figures, session: session)
  }

  private func launch(
    _ fight: FightSimulation, session: GameSession, figures: [PartyMember: SIMD2<Float>]
  ) throws -> Grenade {
    for _ in 0..<120 {
      step(fight, session: session, figures: figures)
      if let grenade = fight.grenades.first { return grenade }
    }
    return try #require(fight.grenades.first, "The thrower's wind-up did not launch a grenade")
  }

  private func detonate(
    _ fight: FightSimulation, session: GameSession, figures: [PartyMember: SIMD2<Float>]
  ) throws {
    for _ in 0..<360 {
      step(fight, session: session, figures: figures)
      if !fight.explosions.isEmpty { return }
    }
    try #require(!fight.explosions.isEmpty, "The released grenade did not detonate")
  }

  private func fireOnce(
    _ fight: FightSimulation, session: GameSession, figures: [PartyMember: SIMD2<Float>],
    at target: SIMD2<Float>
  ) throws -> FightSimulation.Shot {
    let facing = simd_normalize(target - figures[session.leader]!)
    for frame in 0..<120 {
      step(
        fight, session: session, figures: figures, facing: facing, fire: true,
        pressed: frame == 0)
      if let shot = fight.shots.first(where: { if case .party = $0.side { true } else { false } }) {
        return shot
      }
    }
    return try #require(
      fight.shots.first(where: { if case .party = $0.side { true } else { false } }),
      "The leader did not fire a shot")
  }
}
