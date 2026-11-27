import Testing
import simd

@testable import Lauder

/// Decisions use the real component/body queries and execute through native weapons. Fixed
/// figure positions isolate a firing stance; this is not a world motor or phone-input test.
@MainActor
struct CompanionBodyFallbackTests {
  @Test(arguments: [PartyMember.miki, .tom])
  func anExposedButHullOccludedEyeAllowsNativeOrdinaryFireFromTheCurrentStance(
    member: PartyMember
  ) throws {
    let trial = try Trial(member: member)
    try trial.requireRearBodyLane()
    // A genuinely reachable eye stance exists, so the old late fallback was not sufficient.
    let eye = try #require(trial.eye)
    #expect(trial.canStand([0, 6]) && trial.canTraverse(trial.origin, [0, 6]))
    #expect(
      trial.fight.companionCanFire(
        member, from: [0, 6], at: eye, weapon: trial.weapon.kind, figures: trial.figures))
    var times: [Float] = []
    let loaded = trial.fight.status(for: member).loaded
    let health = trial.strategy.health
    var applied = 0
    for frame in 0..<300 {
      try trial.requireRearBodyLane()
      let before = trial.strategy.health
      let result = trial.step()
      #expect(result.position == trial.origin && result.targetsBody && result.fire)
      let shots = trial.fight.shots.filter { $0.actor == member }
      times += shots.map { _ in Float(frame + 1) / 120 }
      let hits = trial.fight.takeEvents().compactMap { event -> DamageHit? in
        if case .damaged(let hit) = event { return hit }
        return nil
      }
      #expect(hits.count == shots.count)
      #expect(
        hits.allSatisfy {
          $0.attacker == member && $0.weapon == trial.weapon.kind
            && $0.effectiveness == .normal && $0.amount > 0
        })
      let damage = hits.reduce(0) { $0 + $1.amount }
      #expect(before - trial.strategy.health == damage)
      applied += damage
    }
    try #require(times.count >= 2)
    #expect(times[0] >= max(trial.weapon.drawTime, trial.weapon.spinUp) - 1 / 120)
    for (first, second) in zip(times, times.dropFirst()) {
      #expect(second - first >= trial.weapon.interval - 0.0001)
    }
    #expect(loaded - trial.fight.status(for: member).loaded == times.count)
    #expect(health - trial.strategy.health == applied && applied > 0)
    #expect(trial.strategy.swordHits.isEmpty && trial.strategy.detachedLegs.isEmpty)
    #expect(trial.session.leader == .laura && trial.session.combatStance == .attack)
  }

  @Test(arguments: [PartyMember.miki, .tom], Blocker.allCases)
  func aRealWallOrAllyBlockingTheBodyCannotBecomeAnOrdinaryShot(
    member: PartyMember, blocker: Blocker
  ) throws {
    let trial = try Trial(member: member, blocker: blocker)
    _ = try #require(trial.eye)
    #expect(!trial.bodyIsClear)
    let loaded = trial.fight.status(for: member).loaded
    let health = trial.strategy.health
    for _ in 0..<240 {
      let result = trial.step()
      #expect(!result.fire)
      #expect(!trial.fight.shots.contains { $0.actor == member })
    }
    #expect(trial.fight.status(for: member).loaded == loaded)
    #expect(trial.strategy.health == health)
    #expect(!trial.fight.takeEvents().contains { if case .damaged = $0 { true } else { false } })
  }

  enum Blocker: CaseIterable, Sendable, Equatable { case wall, ally }

  @MainActor
  private final class Trial {
    let member: PartyMember
    let weapon: Weapon
    let session: GameSession
    let fight: EncounterSimulation
    let figures: [PartyMember: SIMD2<Float>]
    let origin = SIMD2<Float>(-4, 0)
    private let motion: PartyMotion
    private var planner = CompanionTactics()

    var strategy: GuardStrategy { fight.guardStrategies["guard"] ?? GuardStrategy() }
    var eye: GuardWeakpoint? { fight.weakpoints(for: "guard").first { $0.part == .eye } }
    var bodyIsClear: Bool {
      fight.companionCanFireAtBody(
        member, from: origin, at: "guard", weapon: weapon.kind, figures: figures)
    }

    init(member: PartyMember, blocker: Blocker? = nil) throws {
      self.member = member
      weapon = member == .miki ? .longRifle : .minigun
      let other: PartyMember = member == .miki ? .tom : .miki
      figures = [.laura: [2.5, 3], member: origin, other: blocker == .ally ? [-2.5, 0] : [8, 6]]
      let boxes: [Level.Box] =
        blocker == .wall
        ? [.box("wall", at: [-2.2, 1.5, 0], size: [0.2, 3, 2.5])] : []
      let hostile = Level.Hostile(
        id: "guard", name: "Guard", hiddenAt: .zero, standAt: .zero, hits: 6,
        attack: .robot, strategicGuard: true, range: 12)
      let encounter = Level.Encounter(
        beat: .stranger, start: .area(.init(minimum: [-20, -20], maximum: [20, 20])),
        retryAt: [2.5, 3], hostiles: [hostile],
        cues: [(0, .reveal("guard")), (0, .engage("guard"))])
      let level = Level(
        id: "companion-body-fallback",
        ground: .box("floor", at: [0, -0.15, 0], size: [60, 0.3, 60]),
        boxes: boxes, triggers: [], encounters: [encounter], party: [.laura, .miki, .tom],
        spawns: figures, heading: [0, -1], cameraOffset: BrooklynBridge.cameraOffset,
        fieldOfView: 22, opening: "Range", objective: "Test", lookAround: "Range",
        restartNote: "Restart")
      motion = PartyMotion(radius: PartyBody.radius, obstacles: level.obstacles)
      session = GameSession(level: level)
      session.setCombatStance(.attack)
      fight = EncounterSimulation(level: level)
      let began = session.beginEncounter(.stranger)
      try #require(began)
      fight.begin(encounter)
      nativeStep(intents: [:])
      try #require(fight.companionGuard(near: figures[.laura] ?? .zero) != nil)
      _ = fight.takeEvents()
    }

    func requireRearBodyLane() throws {
      let point = try #require(eye)
      try #require(
        !fight.companionCanFire(
          member, from: origin, at: point, weapon: weapon.kind, figures: figures))
      try #require(bodyIsClear)
      try #require(canStand(origin))
    }

    func canStand(_ point: SIMD2<Float>) -> Bool {
      motion.canTraverse(from: point, to: point)
        && simd_distance(point, fight.hostiles["guard"]?.position ?? .zero)
          >= RobotModelGeometry.navigationRadius + PartyBody.radius
    }

    func canTraverse(_ start: SIMD2<Float>, _ end: SIMD2<Float>) -> Bool {
      let resolved = GuardCollision.resolve(
        start: start, delta: end - start, centre: fight.hostiles["guard"]?.position ?? .zero,
        radius: RobotModelGeometry.navigationRadius + PartyBody.radius)
      return motion.canTraverse(from: start, to: end) && simd_distance(resolved, end) < 0.0001
    }

    @discardableResult
    func step() -> CompanionTactics.Intent {
      guard let guardState = fight.companionGuard(near: figures[.laura] ?? .zero) else {
        Issue.record("The native fixture lost its engaged guard")
        return .init(activity: .following)
      }
      let result = planner.plan(
        input: .init(
          member: member, leader: .laura, position: origin,
          leaderPosition: figures[.laura] ?? .zero,
          baseTarget: origin, order: .following, stance: session.combatStance, active: true,
          guardPosition: guardState.robot.position, guardFacing: guardState.robot.facing,
          phase: guardState.robot.phase, stage: guardState.strategy.phase,
          weakpoints: fight.weakpoints(for: "guard"), dt: 1 / 120),
        canStand: canStand, canTraverse: canTraverse,
        canFire: {
          self.fight.companionCanFire(
            self.member, from: $0, at: $1, weapon: $2, figures: self.figures)
        },
        canFireAtBody: {
          self.fight.companionCanFireAtBody(
            self.member, from: $0, at: "guard", weapon: $1, figures: self.figures)
        },
        isCovered: { self.fight.companionHasCover(at: $0, from: guardState.robot) },
        isThreatened: { self.fight.companionIsThreatened(at: $0, by: guardState.robot) },
        isSpaced: { point in
          self.figures.filter { $0.key != self.member }.values.allSatisfy {
            simd_distance($0, point) >= CompanionTactics.minimumSpacing
          }
        })
      nativeStep(intents: [member: result])
      return result
    }

    private func nativeStep(intents: [PartyMember: CompanionTactics.Intent]) {
      let leader = figures[.laura] ?? .zero
      let facings = Dictionary(
        uniqueKeysWithValues: figures.map { member, point in
          (member, simd_normalize((intents[member]?.lookAt ?? .zero) - point))
        })
      _ = fight.step(
        dt: 1 / 120, leader: leader, facing: facings[.laura] ?? [0, -1], aiming: false,
        fireHeld: false, firePressed: false, figures: figures, session: session,
        companionIntents: intents, facings: facings)
    }
  }
}
