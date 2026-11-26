import simd

/// Small, local intentions for a companion in the active guard fight. Orders and the player
/// remain authoritative; motors, collision, turning, weapon timing and real hits execute them.
struct CompanionTactics {
  enum Activity: String, Sendable {
    case following, ordered, holding, approaching, waiting, attacking, avoiding
  }

  struct Input {
    let member: PartyMember
    let leader: PartyMember
    let position: SIMD2<Float>
    let leaderPosition: SIMD2<Float>
    let baseTarget: SIMD2<Float>
    let order: GameSession.Order
    let active: Bool
    let guardPosition: SIMD2<Float>
    let guardFacing: SIMD2<Float>
    let phase: RobotGuard.Phase
    let stage: GuardStrategy.Phase
    let weakpoints: [GuardWeakpoint]
    let dt: Float
  }

  struct Intent: Equatable, Sendable {
    var position: SIMD2<Float>? = nil
    var lookAt: SIMD2<Float>? = nil
    var weapon: Weapon.Kind? = nil
    var fire = false
    var activity: Activity
  }

  static let leaderLeash: Float = 8
  static let localRadius: Float = 3
  static let replanInterval: Float = 0.3

  private struct Context: Equatable {
    let member: PartyMember
    let leader: PartyMember
    let order: GameSession.Order
    let phase: RobotGuard.Phase
    let stage: GuardStrategy.Phase
    let threatened: Bool
  }

  private var context: Context?
  private var goal: SIMD2<Float>?
  private var goalActivity = Activity.following
  private var sincePlan = Float.infinity

  mutating func plan(
    input: Input, canStand: (SIMD2<Float>) -> Bool,
    canTraverse: (SIMD2<Float>, SIMD2<Float>) -> Bool,
    canFire: (SIMD2<Float>, GuardWeakpoint, Weapon.Kind) -> Bool,
    isCovered: (SIMD2<Float>) -> Bool, isThreatened: (SIMD2<Float>) -> Bool
  ) -> Intent {
    let fallback: Activity
    switch input.order {
    case .following: fallback = .following
    case .going: fallback = .ordered
    case .holding: fallback = .holding
    }
    guard input.member != input.leader, input.active, input.dt.isFinite, input.dt > 0,
      input.stage != .complete, ![.hidden, .down, .cleared].contains(input.phase),
      [
        input.position, input.leaderPosition, input.baseTarget, input.guardPosition,
        input.guardFacing,
      ]
      .allSatisfy({ $0.x.isFinite && $0.y.isFinite }),
      simd_distance(input.position, input.leaderPosition) <= Self.leaderLeash,
      simd_distance(input.guardPosition, input.leaderPosition) <= RobotGuard.detectionRange
    else {
      self = CompanionTactics()
      return Intent(activity: fallback)
    }
    if case .going = input.order {
      self = CompanionTactics()
      return Intent(activity: .ordered)
    }
    let threatened = isThreatened(input.position) && !isCovered(input.position)
    let next = Context(
      member: input.member, leader: input.leader, order: input.order, phase: input.phase,
      stage: input.stage, threatened: threatened)
    if context != next {
      goal = nil
      sincePlan = .infinity
    }
    context = next
    sincePlan += input.dt

    let assignment = Self.assignment(member: input.member, stage: input.stage)
    let points = input.weakpoints.filter { $0.part == assignment?.part }
    let point = points.min {
      simd_distance_squared($0.ground, input.position)
        < simd_distance_squared($1.ground, input.position)
    }
    var intent = Intent(
      lookAt: point?.ground ?? input.guardPosition, weapon: assignment?.weapon,
      activity: fallback)
    func legal(_ position: SIMD2<Float>) -> Bool {
      simd_distance(position, input.leaderPosition) <= Self.leaderLeash
        && canStand(position) && canTraverse(input.position, position)
    }
    func safe(_ position: SIMD2<Float>) -> Bool {
      !isThreatened(position) || isCovered(position)
    }
    if case .holding = input.order {
      goal = nil
      if let assignment, canStand(input.position),
        let point = points.first(where: {
          $0.exposed && canFire(input.position, $0, assignment.weapon)
        })
      {
        intent.lookAt = point.ground
        intent.fire = true
        intent.activity = .attacking
      }
      return intent
    }
    if threatened {
      if goalActivity != .avoiding || sincePlan >= Self.replanInterval
        || goal.map({ !legal($0) || !safe($0) }) != false
      {
        goal = Self.near(input.position).filter { legal($0) && safe($0) }.min {
          let a = simd_distance($0, input.position) - (isCovered($0) ? 4 : 0)
          let b = simd_distance($1, input.position) - (isCovered($1) ? 4 : 0)
          return a < b
        }
        goalActivity = .avoiding
        sincePlan = 0
      }
      intent.position = goal ?? input.position
      intent.activity = .avoiding
      return intent
    }
    if let assignment, canStand(input.position),
      let point = points.first(where: {
        canFire(input.position, $0, assignment.weapon)
      })
    {
      // Already in a real firing stance: do not keep orbiting just to reach an ideal radius.
      goal = input.position
      intent.position = input.position
      intent.lookAt = point.ground
      intent.fire = point.exposed
      intent.activity = point.exposed ? .attacking : .waiting
      return intent
    }
    if sincePlan < Self.replanInterval, let goal, legal(goal), safe(goal) {
      intent.position = goal
      intent.activity = goalActivity
      return intent
    }
    sincePlan = 0
    goal = nil
    if let assignment, !points.isEmpty {
      var stances: [SIMD2<Float>] = []
      for point in points {
        let outward = Self.direction(
          point.ground - input.guardPosition, fallback: input.guardFacing)
        for radius in assignment.radii {
          for angle: Float in [0, 0.35, -0.35, 0.7, -0.7] {
            let candidate = input.guardPosition + Self.rotated(outward, by: angle) * radius
            if legal(candidate), safe(candidate), canFire(candidate, point, assignment.weapon) {
              stances.append(candidate)
            }
          }
        }
      }
      goal = stances.min {
        simd_distance($0, input.position) - (isCovered($0) ? 1 : 0)
          < simd_distance($1, input.position) - (isCovered($1) ? 1 : 0)
      }
      if goal == nil {
        // Static navigation alone does not know the living hull. A short legal orbit leg
        // approaches the useful side without repeatedly walking straight into its centre.
        let outward = Self.direction(
          input.position - input.guardPosition, fallback: input.guardFacing)
        let radius = max(simd_distance(input.position, input.guardPosition), assignment.radii[0])
        let ideals = points.map {
          input.guardPosition
            + Self.direction($0.ground - input.guardPosition, fallback: input.guardFacing)
            * assignment.radii[0]
        }
        goal = [Float(0.35), -0.35].map {
          input.guardPosition + Self.rotated(outward, by: $0) * radius
        }.filter {
          simd_distance($0, input.position) <= Self.localRadius && legal($0) && safe($0)
        }.min { first, second in
          (ideals.map { simd_distance($0, first) }.min() ?? .infinity)
            < (ideals.map { simd_distance($0, second) }.min() ?? .infinity)
        }
      }
      goalActivity = goal == nil ? .following : .approaching
    } else {
      // Non-specialists offer local support instead of firing pointlessly into closed armour.
      goal = ([input.position] + Self.near(input.baseTarget)).filter {
        simd_distance($0, input.position) <= Self.localRadius
          && simd_distance($0, input.baseTarget) <= Self.localRadius
          && legal($0) && isCovered($0)
      }.min { simd_distance($0, input.baseTarget) < simd_distance($1, input.baseTarget) }
      goalActivity = .waiting
    }
    intent.position = goal
    intent.activity = goal == nil ? .following : goalActivity
    return intent
  }

  private static func assignment(
    member: PartyMember, stage: GuardStrategy.Phase
  ) -> (part: GuardStrategy.Part, weapon: Weapon.Kind, radii: [Float])? {
    switch (member, stage) {
    case (.miki, .sensor): (.sensor, .longRifle, [6, 7])
    case (.laura, .coupling): (.coupling, .energySword, [2.65])
    case (.tom, .reactor): (.reactor, .minigun, [3.5, 4])
    default: nil
    }
  }

  private static func near(_ centre: SIMD2<Float>) -> [SIMD2<Float>] {
    [Float(1.25), 2.5, 3].flatMap { radius in
      (0..<8).map { centre + rotated([1, 0], by: Float($0) * .pi / 4) * radius }
    }
  }

  private static func direction(_ vector: SIMD2<Float>, fallback: SIMD2<Float>) -> SIMD2<Float> {
    if simd_length_squared(vector) > 0.0001 { return simd_normalize(vector) }
    return simd_length_squared(fallback) > 0.0001 ? simd_normalize(fallback) : [0, 1]
  }

  private static func rotated(_ vector: SIMD2<Float>, by angle: Float) -> SIMD2<Float> {
    [vector.x * cos(angle) - vector.y * sin(angle), vector.x * sin(angle) + vector.y * cos(angle)]
  }
}
