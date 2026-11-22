import Foundation
import Testing
import simd

@testable import Lauder

/// Repeatable measurements of the production handling, spread and body traces. The body
/// remains present after six hits so the accuracy sample is not biased by stopping on a kill.
@MainActor
struct CombatBalanceTests {
  private let dt: Float = 1 / 120
  private let duration: Float = 20
  private let seeds = (1...16).map(UInt64.init)
  private let distances: [Float] = [5, 10, 20, 40]

  @Test
  func measureTheSixWeaponsWithoutAssistanceAndRecordActualPassiveSelection() throws {
    let geometry = Ballistics(level: range())
    var rows: [Row] = []
    for kind in Weapon.testKinds {
      let weapon = Weapon.forKind(kind)
      for distance in distances {
        let selected = try passiveSelection(kind: kind, distance: distance)
        for moving in [false, true] {
          let trials = seeds.map {
            trial(weapon: weapon, distance: distance, moving: moving, seed: $0, geometry: geometry)
          }
          #expect(trials.allSatisfy { $0.valid && $0.shots > 0 && $0.hits <= $0.shots })
          let reloads = trials.flatMap(\.reloads)
          #expect(reloads.allSatisfy { $0 >= weapon.reloadTime - 2 * dt })
          let gaps = trials.flatMap(\.reloadFiringGaps)
          #expect(gaps.allSatisfy { $0 >= max(weapon.reloadTime, weapon.interval) - 2 * dt })
          let shots = trials.reduce(0) { $0 + $1.shots }
          let hits = trials.reduce(0) { $0 + $1.hits }
          rows.append(
            Row(
              weapon: kind.name, distance: distance, motion: moving ? "moving spread" : "settled",
              trials: trials.count, secondsPerTrial: duration,
              shots: shots, hits: hits, hitFrequency: Float(hits) / Float(shots),
              sixHitDefeats: trials.compactMap(\.defeatedAt).count,
              medianTimeToSixHits: median(trials.compactMap(\.defeatedAt)),
              medianRoundsToSixHits: median(
                trials.compactMap(\.defeatedAfterRounds).map(Float.init)),
              reloadsCompleted: reloads.count, shortestReload: reloads.min(),
              longestReload: reloads.max(), shortestReloadFiringGap: gaps.min(),
              passiveSelection: selected,
              effectiveReach: weapon.range, assistanceReach: weapon.assistanceRange,
              magazine: weapon.capacity,
              configuredReload: weapon.reloadTime))
        }
      }
    }
    // Equal seeds and shot schedules make full-speed dispersion a subset of settled hits.
    for kind in Weapon.testKinds {
      let gun = rows.filter { $0.weapon == kind.name }
      for distance in distances {
        let pair = gun.filter { $0.distance == distance }
        #expect(pair.count == 2 && pair[1].hits <= pair[0].hits)
      }
      for motion in ["settled", "moving spread"] {
        let ordered = gun.filter { $0.motion == motion }.sorted { $0.distance < $1.distance }
        #expect(zip(ordered, ordered.dropFirst()).allSatisfy { $0.hits >= $1.hits })
      }
    }
    let repeated = trial(
      weapon: .submachineGun, distance: 10, moving: true, seed: 43, geometry: geometry)
    #expect(
      repeated
        == trial(weapon: .submachineGun, distance: 10, moving: true, seed: 43, geometry: geometry))
    // The close weapon should repay its short reach; its stopping bonus does not make it
    // the better ranged choice. These compare real traces/timing, not configured intervals.
    let close = try #require(
      rows.first {
        $0.weapon == Weapon.Kind.closeScatter.name && $0.distance == 5 && $0.motion == "settled"
      })
    let carbine = try #require(
      rows.first {
        $0.weapon == Weapon.Kind.carbine.name && $0.distance == 5 && $0.motion == "settled"
      })
    #expect(try #require(close.medianTimeToSixHits) < #require(carbine.medianTimeToSixHits))
    let distant = try #require(
      rows.first {
        $0.weapon == Weapon.Kind.closeScatter.name && $0.distance == 10 && $0.motion == "settled"
      })
    #expect(try #require(distant.medianTimeToSixHits) > #require(close.medianTimeToSixHits))
    let report = Report(
      method:
        "Unassisted fixed-direction rays through production WeaponHandling, Scatter and Ballistics. "
        + "Moving mode applies full-speed spread with no turning; it does not measure navigation or player aim. "
        + "Passive selection is a separate actual FightSimulation query with no aimed stick. "
        + "A six-hit dummy remains present for the full accuracy sample. "
        + "Time and round medians describe completed trials only; sixHitDefeats reports their count. "
        + "Uncompleted trials are censored at the trial limit, so these are not population medians for censored rows.",
      seeds: seeds, stepSeconds: dt, rows: rows)
    let folder = try #require(
      FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    )
    .appendingPathComponent("LauderPlaytest/combat-balance", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(report).write(
      to: folder.appendingPathComponent("report.json"), options: .atomic)
  }

  @Test
  func longPrecisionFireKeepsItsStoppingPowerWithoutAutomaticDistantSelection() throws {
    // Off axis so an unassisted ray cannot be mistaken for automatic target selection.
    let far = SIMD2<Float>(20, -40)
    let (session, fight) = try preparedFight(kind: .marksman, target: far)
    #expect(fight.isDrawn && fight.leaderWeapon.kind == .marksman)
    #expect(fight.target == nil, "A distant body must not become an automatic precision target.")
    let (_, nearby) = try preparedFight(kind: .marksman, target: [5, -10])
    #expect(nearby.target == [5, -10], "Local precision assistance remains useful.")
    #expect(session.ammo == 60)

    // An explicitly aimed round still travels almost the original 64 m effective reach.
    let (manualSession, manual) = try preparedFight(kind: .marksman, target: [0, -63], hits: 2)
    _ = step(manual, session: manualSession, facing: [0, -1], aiming: true, fire: true)
    let shot = try #require(manual.shots.first { $0.shooterID == PartyMember.miki.rawValue })
    #expect(shot.path.strike == .body("dummy"))
    #expect(simd_distance(shot.path.start, shot.path.end) > 62)
    #expect(
      manualSession.defeated.contains("dummy"), "The long precision round still deals two hits.")
  }

  @Test(arguments: [Float(2.4), Float(-1.8)])
  func explicitPrecisionAimCanReachAVisibleBodyOnAnotherTier(height: Float) throws {
    // The upper deck begins late enough that the rising ray clears its real front face.
    // The trench opens earlier, before the descending ray would meet the flat ground.
    let terrain = Terrain(patches: [
      .flat(
        minimum: [-12, -60], maximum: [12, height > 0 ? -30 : -10], height: height)
    ])
    let (session, fight) = try preparedFight(
      kind: .marksman, target: [0, -40], hits: 2, terrain: terrain)
    #expect(fight.target == nil, "Passive precision assistance remains local on either tier.")
    #expect(session.ammo == 60 && session.defeated.isEmpty)

    _ = step(fight, session: session, facing: [0, -1], aiming: true, fire: true)
    let shot = try #require(fight.shots.first { $0.shooterID == PartyMember.miki.rawValue })
    let trace = try #require(shot.trace)
    #expect(shot.path.strike == .body("dummy"))
    #expect(simd_distance(trace.start, trace.end) > 39)
    #expect((trace.end.y - trace.start.y) * height > 0)
    #expect(session.defeated.contains("dummy") && session.ammo == 59)
  }

  @Test
  func explicitPrecisionAimAwayFromADistantBodyDoesNotSnapToIt() throws {
    let (session, fight) = try preparedFight(kind: .marksman, target: [20, -40], hits: 2)
    #expect(fight.target == nil)
    _ = step(fight, session: session, facing: [-1, 0], aiming: true, fire: true)
    let shot = try #require(fight.shots.first { $0.shooterID == PartyMember.miki.rawValue })
    #expect(shot.path.strike == .nothing && fight.target == nil)
    #expect(shot.path.end.x < -40, "The dispersed round still travels in the requested direction.")
    #expect(session.defeated.isEmpty && session.ammo == 59)
  }

  @Test
  func aCompanionCannotUseLongBulletTravelAsMapWideAutomaticAwareness() throws {
    let (session, fight) = try preparedFight(
      kind: .marksman, target: [20, -40], marksmanCompanion: true)
    for _ in 0..<360 { _ = step(fight, session: session) }
    #expect(fight.equippedWeapon(for: .tom).kind == .marksman)
    #expect(fight.companionShots[.tom, default: 0] == 0)
  }

  private struct Report: Encodable {
    let method: String
    let seeds: [UInt64]
    let stepSeconds: Float
    let rows: [Row]
  }

  private struct Row: Encodable {
    let weapon: String
    let distance: Float
    let motion: String
    let trials: Int
    let secondsPerTrial: Float
    let shots: Int
    let hits: Int
    let hitFrequency: Float
    let sixHitDefeats: Int
    let medianTimeToSixHits: Float?
    let medianRoundsToSixHits: Float?
    let reloadsCompleted: Int
    let shortestReload: Float?
    let longestReload: Float?
    let shortestReloadFiringGap: Float?
    let passiveSelection: Bool
    let effectiveReach: Float
    let assistanceReach: Float
    let magazine: Int
    let configuredReload: Float
  }

  private struct Trial: Equatable {
    var shots = 0
    var hits = 0
    var defeatedAt: Float?
    var defeatedAfterRounds: Int?
    var reloads: [Float] = []
    var reloadFiringGaps: [Float] = []
    var valid = true
  }

  private func trial(
    weapon: Weapon, distance: Float, moving: Bool, seed: UInt64, geometry: Ballistics
  ) -> Trial {
    var handling = WeaponHandling(weapon: weapon)
    var scatter = Scatter()
    var random = SeededRandom(seed: seed)
    var result = Trial()
    var damage = 0
    var reloadStartedAt: Float?
    var reloadGapStartedAt: Float?
    let start = SIMD3<Float>(0, FightSimulation.aimHeight, 0)
    let target = Ballistics.Target(id: "dummy", centre: [0, FightSimulation.aimHeight, -distance])
    handling.draw()
    for frame in 1...Int(duration / dt) {
      let time = Float(frame) * dt
      let reloading = handling.reloadRemaining > 0
      handling.advance(dt: dt)
      scatter.settle(dt: dt, spread: weapon.spread)
      if reloading, handling.reloadRemaining == 0, let started = reloadStartedAt {
        result.reloads.append(time - started)
        reloadStartedAt = nil
      }
      result.valid = result.valid && (0...weapon.capacity).contains(handling.magazineRemaining)
      guard handling.isReady else { continue }
      result.valid = result.valid && handling.reloadRemaining == 0
      if let started = reloadGapStartedAt {
        result.reloadFiringGaps.append(time - started)
        reloadGapStartedAt = nil
      }
      let cone = scatter.angle(spread: weapon.spread, speed: moving ? 1 : 0, turning: 0)
      let angle = Scatter.deviation(within: cone, using: &random)
      let trace = geometry.traceAcrossLevel(
        from: start, direction: [sin(angle), 0, -cos(angle)], targets: [target])
      handling.fired()
      scatter.fired(spread: weapon.spread)
      result.shots += 1
      result.valid = result.valid && trace.end.indices.allSatisfy { trace.end[$0].isFinite }
      if trace.strike == .body("dummy") {
        result.hits += 1
        damage += weapon.damage(at: simd_distance(trace.start, trace.end))
        if damage >= 6, result.defeatedAt == nil {
          result.defeatedAt = time
          result.defeatedAfterRounds = result.shots
        }
      }
      if handling.reloadRemaining > 0 {
        reloadStartedAt = time
        reloadGapStartedAt = time
      }
    }
    return result
  }

  private func median(_ values: [Float]) -> Float? {
    guard !values.isEmpty else { return nil }
    let sorted = values.sorted()
    return (sorted[(sorted.count - 1) / 2] + sorted[sorted.count / 2]) / 2
  }

  private func passiveSelection(kind: Weapon.Kind, distance: Float) throws -> Bool {
    let point = SIMD2<Float>(distance * sin(.pi / 6), -distance * cos(.pi / 6))
    return try preparedFight(kind: kind, target: point).1.target != nil
  }

  private func preparedFight(
    kind: Weapon.Kind, target: SIMD2<Float>, hits: Int = 100, marksmanCompanion: Bool = false,
    terrain: Terrain = Terrain()
  ) throws -> (GameSession, FightSimulation) {
    let level = range(target: target, hits: hits, companion: marksmanCompanion, terrain: terrain)
    let session = GameSession(level: level)
    session.togglePause()
    for _ in Weapon.testKinds where session.weapon(for: session.leader).kind != kind {
      #expect(session.cycleTestWeapon())
    }
    #expect(session.weapon(for: session.leader).kind == kind)
    session.togglePause()
    if marksmanCompanion { session.cycleLeader() }
    let fight = FightSimulation(level: level)
    let encounter = try #require(level.encounters.first)
    #expect(session.beginEncounter(encounter.beat))
    fight.begin(encounter)
    for frame in 0..<180 {
      _ = step(fight, session: session, draw: frame == 0)
    }
    return (session, fight)
  }

  @discardableResult
  private func step(
    _ fight: FightSimulation, session: GameSession, facing: SIMD2<Float> = [0, -1],
    aiming: Bool = false, fire: Bool = false, draw: Bool = false
  ) -> FightSimulation.Outcome {
    fight.step(
      dt: dt, leader: session.leader == .miki ? [0, 0] : [-3, 0], facing: facing,
      aiming: aiming, fireHeld: fire, firePressed: draw,
      mayDisrupt: false, signaturePressed: false, figures: [.miki: [0, 0], .tom: [-3, 0]],
      session: session)
  }

  private func range(
    target: SIMD2<Float>? = nil, hits: Int = 100, companion: Bool = false,
    terrain: Terrain = Terrain()
  ) -> Level {
    let point = target ?? SIMD2<Float>(20, -40)
    let enemy = Level.Hostile(
      id: "dummy", name: "Dummy", hiddenAt: point, standAt: point, hits: hits,
      windUp: 60, recovery: 60, range: 1, inView: true,
      targetsAnyone: true, targetFromWindUp: true)
    return Level(
      id: "combat-balance-test",
      ground: .box("floor", at: [0, -0.15, -30], size: [100, 0.3, 100]),
      terrain: terrain, boxes: [], interactions: [], triggers: [],
      encounters: [
        .init(
          beat: .stranger, start: .area(.init(minimum: [-50, -80], maximum: [50, 20])),
          retryAt: nil, hostiles: [enemy], cues: [(0, .reveal(enemy.id)), (0, .engage(enemy.id))])
      ], startingAmmo: 60, party: companion ? [.tom, .miki] : [.miki],
      spawns: [.miki: .zero, .tom: [-3, 0], .laura: [3, 0]], heading: [0, -1],
      cameraOffset: [0, 12, 10], fieldOfView: 42,
      opening: "Test.", objective: "Test.", lookAround: "Test.", restartNote: "Restart.",
      combat: .init(companionWeapons: companion ? [.tom: .closeScatter] : [:]),
      arena: .init(slots: [.init(id: enemy.id, point: point)], warningDuration: 60))
  }
}
