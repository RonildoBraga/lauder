#if DEBUG
  import simd

  /// A deterministic test pilot. It can only request the player's ordinary controls; it
  /// cannot place actors, grant ammunition, deal damage or advance a wave itself.
  enum ArenaPlaytest {
    struct Pilot {
      private var levelID: String?
      private var grid: NavigationGrid?
      private var motion: PartyMotion?
      private var route: [SIMD2<Float>] = []
      private var goal: SIMD2<Float>?
      private var enemy: String?
      private var reconsiderAt: Float = 0
      private var lastSignature: Float = -.infinity
      private var observedFallBacks = 0
      private var releaseUntil: Float = 0

      mutating func navigate(
        to destination: SIMD2<Float>, snapshot: PlaytestRunner.Snapshot, seconds: Float
      ) -> InputRules.Raw {
        prepare(snapshot.level)
        if observedFallBacks != snapshot.fallBacks {
          observedFallBacks = snapshot.fallBacks
          route = []
          goal = nil
          enemy = nil
          // A real fallback closes InputRules' release gate. Let it observe a neutral
          // sample after the return fade, just as a human releases the controls and waits.
          releaseUntil = seconds + 1
        }
        if seconds < releaseUntil { return InputRules.Raw() }
        guard let leader = snapshot.positions[snapshot.leader], let motion, let grid else {
          return InputRules.Raw()
        }
        if goal.map({ simd_distance($0, destination) > 0.4 }) ?? true
          || route.isEmpty || seconds >= reconsiderAt
        {
          goal = destination
          reconsiderAt = seconds + 2
          if motion.canTraverse(from: leader, to: destination) {
            route = [destination]
          } else if let cells = grid.route(from: leader, to: destination) {
            route = NavigationGrid.straightened([leader] + cells + [destination]) {
              motion.canTraverse(from: $0, to: $1)
            }
          } else {
            route = []
          }
        }
        while let next = route.first, simd_distance(leader, next) < 0.2 {
          route.removeFirst()
        }
        guard let next = route.first else { return InputRules.Raw() }
        return InputRules.Raw(
          stick: Movement.stick(towards: next - leader, cameraOffset: snapshot.level.cameraOffset))
      }

      mutating func fight(snapshot: PlaytestRunner.Snapshot, seconds: Float) -> InputRules.Raw {
        prepare(snapshot.level)
        guard snapshot.mode == .exploring,
          let leader = snapshot.positions[snapshot.leader], let grid
        else { return InputRules.Raw() }
        if !snapshot.isFighting {
          return navigate(to: [6.5, -2], snapshot: snapshot, seconds: seconds)
        }
        let candidates = snapshot.hostiles.values.filter { $0.isTargetable && !$0.isDown }
          .sorted { $0.spec.id < $1.spec.id }
        guard
          let target = candidates.min(by: {
            simd_distance_squared($0.position, leader) < simd_distance_squared($1.position, leader)
          })
        else { return InputRules.Raw() }
        let level = snapshot.level
        let ballistics = Ballistics(level: level)
        let cover = LeaderCover(boxes: level.boxes, ground: level.bounds, terrain: level.terrain)
        let sheltered = cover.shelter(at: target.position, facing: leader - target.position)
        let targetPoint = ballistics.point(
          target.position, above: sheltered?.isLow == true ? 0.85 : 1.25)
        var destination = goal ?? leader
        let danger = snapshot.grenades.contains {
          simd_distance($0.position, leader) <= Grenade.radius + 0.4
        }
        let canShoot =
          simd_distance(ballistics.point(leader), targetPoint) <= 11
          && ballistics.isClear(from: ballistics.point(leader), to: targetPoint)
        let needsEscape =
          danger
          && (goal.map { destination in
            snapshot.grenades.contains {
              simd_distance($0.position, destination) <= Grenade.radius + 0.6
            }
          } ?? true)
        if canShoot && !danger {
          destination = leader
          goal = leader
          route = []
        } else if enemy != target.spec.id || seconds >= reconsiderAt || needsEscape {
          enemy = target.spec.id
          let region = grid.region(at: leader)
          let spots = grid.roomySpots(
            within: danger ? 6 : 11, of: danger ? leader : target.position, stride: 5)
          let choices = spots.filter { point in
            let gap = simd_distance(point, target.position)
            return gap >= 3 && gap <= 11
              && (region == nil || grid.region(at: point) == region)
              && snapshot.grenades.allSatisfy {
                simd_distance($0.position, point) > Grenade.radius + 0.6
              }
              && ballistics.isClear(from: ballistics.point(point), to: targetPoint)
          }
          if let closest = choices.min(by: {
            simd_distance_squared($0, leader) < simd_distance_squared($1, leader)
          }) {
            destination = closest
          } else {
            destination = target.position
          }
          if goal.map({ simd_distance($0, destination) > 0.4 }) ?? true { route = [] }
          goal = destination
          reconsiderAt = seconds + 2
        }
        var raw = navigate(to: destination, snapshot: snapshot, seconds: seconds)
        raw.aimStick = Movement.stick(
          towards: target.position - leader, cameraOffset: level.cameraOffset)
        raw.controllerFire = true
        // Disrupt only where the shot can actually reach the low body too; repeatedly
        // cancelling a sheltered shooter's peek must not stall the encounter test.
        if canShoot, snapshot.canDisrupt, seconds - lastSignature > 1 {
          raw.controllerSignature = true
          lastSignature = seconds
        }
        return raw
      }

      /// Continue a prescribed route while using only a clear, reachable shot for defence.
      /// This exercises shooting across the ramps without granting immunity to the route.
      mutating func defend(
        _ movement: InputRules.Raw, snapshot: PlaytestRunner.Snapshot, seconds: Float
      ) -> InputRules.Raw {
        guard let leader = snapshot.positions[snapshot.leader] else { return movement }
        let level = snapshot.level
        let ballistics = Ballistics(level: level)
        let cover = LeaderCover(boxes: level.boxes, ground: level.bounds, terrain: level.terrain)
        let targets = snapshot.hostiles.values.sorted { $0.spec.id < $1.spec.id }.filter { state in
          guard state.isTargetable, !state.isDown else { return false }
          let low =
            cover.shelter(at: state.position, facing: leader - state.position)?.isLow == true
          let target = ballistics.point(state.position, above: low ? 0.85 : 1.25)
          return simd_distance(ballistics.point(leader), target) < Weapon.carbine.range
            && ballistics.isClear(from: ballistics.point(leader), to: target)
        }
        guard
          let target = targets.min(by: {
            simd_distance_squared($0.position, leader) < simd_distance_squared($1.position, leader)
          })
        else { return movement }
        var raw = movement
        raw.aimStick = Movement.stick(
          towards: target.position - leader, cameraOffset: level.cameraOffset)
        raw.controllerFire = true
        if snapshot.canDisrupt, seconds - lastSignature > 1 {
          raw.controllerSignature = true
          lastSignature = seconds
        }
        return raw
      }

      private mutating func prepare(_ level: Level) {
        guard levelID != level.id else { return }
        self = Pilot()
        levelID = level.id
        grid = NavigationGrid(level: level)
        motion = PartyMotion(radius: PartyBody.radius, obstacles: level.obstacles)
      }
    }
  }
#endif
