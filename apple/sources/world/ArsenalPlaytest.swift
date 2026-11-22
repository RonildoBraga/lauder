#if DEBUG
  import simd

  /// Fixed-size observations of actual discharges, plus ordinary-control arsenal routes.
  /// This code never changes equipment, damage, resources or wave state directly.
  enum ArsenalPlaytest {
    typealias Step = PlaytestRunner.Step

    struct ShotMetrics: Equatable {
      var longestPartyTrace: Float = 0
      var longestPartySceneryTrace: Float = 0
      var partyWeapons: [Weapon.Kind: Int] = [:]
      var hostileWeapons: [Weapon.Kind: Int] = [:]
      var hostileActors: [String: Int] = [:]

      mutating func record(_ shot: FightSimulation.Shot) {
        switch shot.side {
        case .party:
          let distance =
            shot.trace.map { simd_distance($0.start, $0.end) }
            ?? simd_distance(shot.path.start, shot.path.end)
          if distance.isFinite {
            longestPartyTrace = max(longestPartyTrace, distance)
            if shot.path.strike == .scenery {
              longestPartySceneryTrace = max(longestPartySceneryTrace, distance)
            }
          }
          if let kind = shot.weaponKind { partyWeapons[kind, default: 0] += 1 }
        case .hostile:
          if let kind = shot.weaponKind { hostileWeapons[kind, default: 0] += 1 }
          if let actor = shot.shooterID { hostileActors[actor, default: 0] += 1 }
        }
      }
    }

    static let scenarios: [(name: String, steps: [Step])] = [
      ("arsenal-bench", bench),
      ("enemy-arsenal", enemyArsenal),
    ]

    private static let nextLevel: [Step] = [
      .pause, .wait(seconds: 0.3), .menu(1), .wait(seconds: 0.2), .menu(1),
      .wait(seconds: 0.2), .act, .wait(seconds: 0.6),
    ]
    private static let enter = nextLevel + [Step.expectLevel("combat-yard")]
    private static let restart: [Step] = [
      .pause, .wait(seconds: 0.3), .menu(1), .wait(seconds: 0.2), .act,
      .expectRestarted, .wait(seconds: 0.5),
    ]

    /// The test loadout is the fifth ordinary Pause choice, and selecting it stays paused.
    /// Options then resumes; each press includes its ordinary neutral release sample.
    private static let nextWeapon: [Step] = [
      .pause, .wait(seconds: 0.2),
      .menu(1), .wait(seconds: 0.1), .menu(1), .wait(seconds: 0.1),
      .menu(1), .wait(seconds: 0.1), .menu(1), .wait(seconds: 0.1),
      .act, .wait(seconds: 0.2), .pause, .wait(seconds: 0.3),
    ]

    private static func fireAndRemember(_ kind: Weapon.Kind) -> [Step] {
      [
        .expectWeapon(kind, loaded: nil, reloading: false),
        .fireAimed([0, -1], seconds: 1.3), .expectPartyWeaponFired(kind), .expectAmmo(60),
        .rememberWeapon, .switchLeader, .switchLeader, .switchLeader,
        .expectRememberedWeapon, .mark("\(kind.name) fires and survives switching"),
      ]
    }

    private static let bench: [Step] =
      enter + [
        .order(.hold), .walk([6.5, 6]),
        .fireAimed([-6.5, -45], seconds: 1.3),
        .expectShotTravel(atLeast: 40, scenery: true), .expectAmmo(60),
        .mark("native carbine reaches the distant wall"),
        .walk([0, 6]),
      ] + fireAndRemember(.carbine)
      + nextWeapon + fireAndRemember(.lightBurst)
      + nextWeapon + fireAndRemember(.closeScatter)
      + nextWeapon + fireAndRemember(.submachineGun)
      + nextWeapon + fireAndRemember(.marksman)
      + nextWeapon + fireAndRemember(.supportGun) + [
        .fireUntilReloading([0, -1], seconds: 10),
        .expectWeapon(.supportGun, loaded: 0...0, reloading: true),
        .pause, .rememberShotMetrics, .wait(seconds: 0.6), .expectShotMetricsHeld,
        .expectWeapon(.supportGun, loaded: 0...0, reloading: true),
        .mark("Pause freezes the support gun reload and discharges"),
        .pause, .awaitReloaded(seconds: 4),
        .expectWeapon(.supportGun, loaded: 36...36, reloading: false),
      ] + restart + [
        .expectWeapon(.carbine, loaded: 12...12, reloading: false),
        .expectNoShotMetrics, .mark("Restart restores native weapons"),
      ]

    private static let enemyArsenal: [Step] =
      enter + [
        .battleUntilWave(3, seconds: 300), .mark("new-role packs can arrive"),
        .observeEnemyWeapons([.marksman, .supportGun], seconds: 180),
        .expectEnemyWeaponFired(.marksman), .expectEnemyWeaponFired(.supportGun),
        .expectEnemyRecovery(.marksman), .expectEnemyRecovery(.supportGun),
        .expectMarksmanRetreated, .mark("marksman and support gun fire and recover"),
        .pause, .rememberArena, .rememberShotMetrics, .wait(seconds: 0.6),
        .expectArenaHeld, .expectShotMetricsHeld,
        .mark("Pause freezes the mixed fight"), .pause,
      ] + restart + [.expectNoShotMetrics, .expectArenaWave(1)]

    /// Get into a real enemy firing lane and let the new profiles complete their telegraphs.
    /// Ordinary fire handles other packs. The pause/HP/resource rules remain authoritative.
    struct Observer {
      private var navigator = ArenaPlaytest.Pilot()
      private var fighter = ArenaPlaytest.Pilot()
      private var levelID: String?
      private var grid: NavigationGrid?
      private var geometry: Ballistics?
      private var cover: LeaderCover?
      private var goal: SIMD2<Float>?
      private var enemy: String?
      private var reconsiderAt: Float = 0

      mutating func input(
        needing kinds: Set<Weapon.Kind>, marksmanRetreated: Bool,
        snapshot: PlaytestRunner.Snapshot, seconds: Float
      ) -> InputRules.Raw {
        prepare(snapshot.level)
        guard snapshot.mode == .exploring, let leader = snapshot.positions[snapshot.leader],
          let grid, let geometry, let cover
        else { return InputRules.Raw() }
        let candidates = snapshot.hostiles.values.filter {
          $0.isVisible && !$0.isDown && kinds.contains($0.spec.weapon)
            && (snapshot.shotMetrics.hostileWeapons[$0.spec.weapon, default: 0] == 0
              || $0.spec.weapon == .marksman && !marksmanRetreated)
        }.sorted { $0.spec.id < $1.spec.id }
        guard
          let target = candidates.min(by: {
            simd_distance_squared($0.position, leader) < simd_distance_squared($1.position, leader)
          })
        else {
          return fighter.fight(snapshot: snapshot, seconds: seconds)
        }
        let provokingRetreat =
          target.spec.weapon == .marksman
          && snapshot.shotMetrics.hostileWeapons[.marksman, default: 0] > 0
          && !marksmanRetreated
        let near: Float = provokingRetreat ? 10 : target.spec.weapon == .marksman ? 22 : 16
        let far: Float = provokingRetreat ? 14 : target.spec.weapon == .marksman ? 29 : 20
        let direction = leader - target.position
        let shelter = cover.shelter(at: target.position, facing: direction)
        let firing =
          shelter.flatMap {
            cover.firingPoint(from: target.position, in: $0, facing: direction)
          } ?? target.position
        let source = geometry.point(firing)
        let distance = simd_distance(geometry.point(leader), source)
        let hereIsOpen =
          cover.shelter(at: leader, facing: -direction) == nil
          && geometry.isClear(from: source, to: geometry.point(leader))
        if distance >= near, distance <= far, hereIsOpen {
          goal = leader
        } else if enemy != target.spec.id || seconds >= reconsiderAt || goal == nil {
          let region = grid.region(at: leader)
          let spots = grid.roomySpots(within: far, of: target.position, stride: 10)
          let choices = spots.filter { point in
            let gap = simd_distance(geometry.point(point), source)
            return gap >= near && gap <= far && (region == nil || grid.region(at: point) == region)
              && cover.shelter(at: point, facing: target.position - point) == nil
              && geometry.isClear(from: source, to: geometry.point(point))
              && snapshot.grenades.allSatisfy {
                simd_distance($0.position, point) > Grenade.radius + 0.5
              }
          }
          goal =
            choices.min { simd_distance_squared($0, leader) < simd_distance_squared($1, leader) }
            ?? target.position
          enemy = target.spec.id
          reconsiderAt = seconds + 2
        }
        return navigator.navigate(to: goal ?? leader, snapshot: snapshot, seconds: seconds)
      }

      private mutating func prepare(_ level: Level) {
        guard levelID != level.id else { return }
        levelID = level.id
        grid = NavigationGrid(level: level)
        geometry = Ballistics(level: level)
        cover = LeaderCover(boxes: level.boxes, ground: level.bounds, terrain: level.terrain)
        goal = nil
        enemy = nil
      }
    }
  }
#endif
