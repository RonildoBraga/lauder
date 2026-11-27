import Testing
import simd

@testable import Lauder

/// Real discharges and swings, with native draw, scatter, geometry and health. These are
/// contact fixtures, not party-motor or survival tests; no health, timers or parts are edited.
@MainActor
struct GuardDamageRegressionTests {
  @Test(
    arguments: [Weapon.Kind.longRifle, .assaultRifle, .shotgun, .minigun], [false, true])
  func actualBodyHitsRetainPositiveRangeFalloffDrawCadenceAndMagazine(
    kind: Weapon.Kind, beyondRange: Bool
  ) throws {
    let member: PartyMember =
      switch kind {
      case .longRifle, .assaultRifle: .miki
      case .shotgun: .laura
      default: .tom
      }
    let weapon = try #require(Weapon.pair(for: member).first { $0.kind == kind })
    let distance = weapon.range + (beyondRange ? 4 : -4)
    // Rear-hull contacts isolate range from the eye's separate multiplier. Manual shots
    // still travel beyond assistance and effective range through the native ballistic path.
    let origin = SIMD2<Float>(0, -distance)
    let trial = try Trial(member: member, origin: origin)
    if trial.fight.weapon(of: member).kind != kind { trial.fight.swapWeapon(for: member) }
    var times: [Float] = []
    var hits: [DamageHit] = []
    for frame in 0..<360 where times.count < 2 {
      let result = trial.step(origin: origin, facing: [0, 1], fire: true)
      try account(result, member: member, weapon: kind)
      for shot in result.shots {
        let trace = try #require(shot.trace)
        #expect(shot.path.strike == .body("guard"))
        #expect((simd_distance(trace.start, trace.end) > weapon.range) == beyondRange)
        times.append(Float(frame + 1) / 120)
      }
      hits += result.hits
    }
    try #require(times.count == 2 && hits.count == 2)
    #expect(times[0] >= max(weapon.drawTime, weapon.spinUp) - Trial.dt)
    #expect(times[1] - times[0] >= weapon.interval - Trial.dt)
    #expect(trial.fight.status(for: member).loaded == weapon.capacity - 2)
    #expect(hits.allSatisfy { $0.effectiveness == .normal })
    #expect(hits.allSatisfy { $0.amount == (beyondRange ? 1 : weapon.damage) })
    #expect(
      trial.strategy.health == GuardStrategy.maximumHealth - hits.reduce(0) { $0 + $1.amount })
    #expect(trial.strategy.swordHits.isEmpty && trial.strategy.detachedLegs.isEmpty)
  }

  @Test
  func aRefinedEyeContactHasOneDamageEventAndOneAppliedHealthChangeInItsFixedStep() throws {
    let trial = try Trial(member: .miki, origin: [0, 6])
    var contacts = 0
    for _ in 0..<360 where contacts < 2 {
      let result = trial.step(origin: [0, 6], facing: [0, -1], fire: true)
      try account(result, member: .miki, weapon: .longRifle)
      for shot in result.shots {
        #expect(shot.path.strike == .body("guard.eye"))
        #expect(result.hits.count == 1)
        #expect(result.hits.first?.effectiveness == .weakpoint)
        #expect(result.hits.first?.amount == Weapon.longRifle.damage * 3)
        contacts += 1
      }
    }
    #expect(contacts == 2)
    #expect(trial.strategy.health == GuardStrategy.maximumHealth - 2 * 144)
  }

  enum SwordProbe: CaseIterable {
    case reached, beyondReach, facingAway, wrongSide, solidCover
  }

  @Test(arguments: SwordProbe.allCases)
  func aRealSwordSwingNeedsLegReachFacingAnOutwardSideAndClearCover(probe: SwordProbe) throws {
    let boxes: [Level.Box] =
      probe == .solidCover
      ? [.box("leg-screen", at: [0, 2, 1.2], size: [8, 4, 0.2])] : []
    let trial = try Trial(member: .laura, origin: [-2, 2], boxes: boxes)
    trial.fight.swapWeapon(for: .laura)
    var swing: Frame?
    for _ in 0..<180 where swing == nil {
      let robot = try #require(trial.fight.hostiles["guard"]?.robot)
      let leg = try #require(trial.fight.weakpoints(for: "guard").first { $0.part == .leg(0) })
      let outward = simd_normalize(leg.ground - robot.position)
      let origin: SIMD2<Float>
      if probe == .wrongSide {
        // This leg remains within reach, but across the hull from Laura's outward stance.
        // The nearer leg is outside this swing's arc; a body hit remains legitimate.
        let angle: Float = -80 * .pi / 180
        let radial = SIMD2(
          outward.x * cos(angle) - outward.y * sin(angle),
          outward.x * sin(angle) + outward.y * cos(angle))
        origin = robot.position + radial * (RobotModelGeometry.bodyRadius + PartyBody.radius + 0.05)
        #expect(simd_dot(radial, outward) < 0.55)
        #expect(simd_distance(origin, leg.ground) < Weapon.energySword.range + leg.radius)
      } else {
        let gap: Float =
          probe == .beyondReach ? Weapon.energySword.range + leg.radius + 0.12 : 1.1
        origin = leg.ground + outward * gap
      }
      var facing = simd_normalize(leg.ground - origin)
      if probe == .facingAway { facing = -facing }
      // Tracking the measured part isolates the swing gate from this fixture's native turn;
      // it never changes the robot, its part positions or the collision boxes.
      let result = trial.step(origin: origin, facing: facing, fire: true)
      try account(result, member: .laura, weapon: .energySword)
      if result.swings > 0 { swing = result }
    }
    let result = try #require(swing)
    #expect(result.swings == 1)
    if probe == .reached {
      #expect(trial.strategy.swordHits == [0: 1])
      #expect(result.hits.count == 1 && result.hits.first?.amount == Weapon.energySword.damage)
    } else {
      #expect(trial.strategy.swordHits.isEmpty)
      if probe == .wrongSide {
        #expect(result.hits.count == 1 && result.hits.first?.amount == Weapon.energySword.damage)
      } else {
        #expect(result.hits.isEmpty && trial.strategy.health == GuardStrategy.maximumHealth)
      }
    }
    #expect(result.hits.allSatisfy { $0.effectiveness == .normal && !$0.brokeComponent })
    #expect(trial.strategy.detachedLegs.isEmpty)
  }

  private func account(_ frame: Frame, member: PartyMember, weapon: Weapon.Kind) throws {
    #expect(frame.before - frame.after == frame.hits.reduce(0) { $0 + $1.amount })
    #expect(frame.hits.count <= 1, "One contact cannot count both the hull and a component")
    #expect(
      frame.hits.allSatisfy {
        $0.target == "guard" && $0.attacker == member && $0.weapon == weapon && $0.amount > 0
      })
    if weapon.shoots {
      #expect(frame.shots.count <= 1)
      let contacts = frame.shots.filter {
        if case .body(let id) = $0.path.strike {
          id == "guard" || id.hasPrefix("guard.")
        } else {
          false
        }
      }
      #expect(frame.hits.count == contacts.count)
    }
  }

  private struct Frame {
    let before: Int
    let after: Int
    let hits: [DamageHit]
    let shots: [EncounterSimulation.Shot]
    let swings: Int
  }

  @MainActor
  private final class Trial {
    static let dt: Float = 1 / 120
    let member: PartyMember
    let session: GameSession
    let fight: EncounterSimulation
    var strategy: GuardStrategy { fight.guardStrategies["guard"] ?? GuardStrategy() }

    init(member: PartyMember, origin: SIMD2<Float>, boxes: [Level.Box] = []) throws {
      self.member = member
      let hostile = Level.Hostile(
        id: "guard", name: "Guard", hiddenAt: .zero, standAt: .zero, hits: 6,
        attack: .robot, strategicGuard: true)
      let encounter = Level.Encounter(
        beat: .stranger, start: .area(.init(minimum: [-40, -40], maximum: [40, 40])),
        retryAt: nil, hostiles: [hostile], cues: [(0, .reveal("guard")), (0, .engage("guard"))])
      let level = Level(
        id: "guard-damage-regression",
        ground: .box("floor", at: [0, -0.15, 0], size: [100, 0.3, 100]),
        boxes: boxes, triggers: [], encounters: [encounter], party: [member],
        spawns: [member: origin], heading: [0, -1], cameraOffset: BrooklynBridge.cameraOffset,
        fieldOfView: 22, opening: "Test", objective: "Test", lookAround: "Test", restartNote: "Test"
      )
      session = GameSession(level: level)
      fight = EncounterSimulation(level: level)
      let began = session.beginEncounter(encounter.beat)
      try #require(began)
      fight.begin(encounter)
      _ = step(origin: origin, facing: [0, -1], fire: false)
    }

    func step(origin: SIMD2<Float>, facing: SIMD2<Float>, fire: Bool) -> Frame {
      let before = strategy.health
      _ = fight.step(
        dt: Self.dt, leader: origin, facing: facing, aiming: true, fireHeld: fire,
        firePressed: fire, figures: [member: origin], session: session)
      let events = fight.takeEvents()
      return Frame(
        before: before, after: strategy.health,
        hits: events.compactMap { if case .damaged(let hit) = $0 { hit } else { nil } },
        shots: fight.shots.filter { $0.actor == member },
        swings: events.filter { if case .fired(.energySword, _, _) = $0 { true } else { false } }
          .count)
    }
  }
}
