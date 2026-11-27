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
    let stance: GameSession.CombatStance
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
    /// Whether the plan takes part in the guard fight: the companion draws, aims at `lookAt`
    /// and may fire. Only an engaged plan lets the pack's targets come first.
    var engaged = false
    var weapon: Weapon.Kind? = nil
    var targetsBody = false
    /// A scout drone to shoot instead of the guard, chosen after planning (issue #201).
    var drone: String? = nil
    /// A pack crawler to shoot instead of the guard, chosen after planning (issue #208).
    var crawler: String? = nil
    var fire = false
    var activity: Activity
  }

  /// A member of the guard's pack a companion could shoot ahead of the guard: a diving drone or
  /// a crawler closing in, as EncounterSimulation finds them (issues #201, #208).
  struct PackTarget: Equatable, Sendable {
    enum Kind: Equatable, Sendable { case drone, crawler }

    let kind: Kind
    let id: String
    let position: SIMD2<Float>
    let weapon: Weapon.Kind
  }

  /// Under Attack, a companion whose plan engages the guard, and who is not seeking safety,
  /// shoots the pack first: `target` gives a diving drone, or else a crawler closing in.
  /// Movement and orders keep the plan's own, and `target` is only asked when it can matter.
  static func preferringPack(
    _ intent: Intent, stance: GameSession.CombatStance, target: () -> PackTarget?
  ) -> Intent {
    guard stance == .attack, intent.engaged, intent.activity != .avoiding, let target = target()
    else { return intent }
    var intent = intent
    intent.lookAt = target.position
    intent.weapon = target.weapon
    switch target.kind {
    case .drone: intent.drone = target.id
    case .crawler: intent.crawler = target.id
    }
    intent.fire = true
    intent.activity = .attacking
    return intent
  }

  static let leaderLeash: Float = 8
  static let localRadius: Float = 3
  static let replanInterval: Float = 0.3
  static let minimumSpacing: Float = 1.2

  private struct Context: Equatable {
    let member: PartyMember
    let leader: PartyMember
    let order: GameSession.Order
    let stance: GameSession.CombatStance
    let phase: RobotGuard.Phase
    let stage: GuardStrategy.Phase
    let part: GuardStrategy.Part?
    let threatened: Bool
  }

  private var context: Context?
  private var goal: SIMD2<Float>?
  private var goalActivity = Activity.following
  private var goalTargetsBody = false
  private var sincePlan = Float.infinity

  mutating func plan(
    input: Input, canStand: (SIMD2<Float>) -> Bool,
    canTraverse: (SIMD2<Float>, SIMD2<Float>) -> Bool,
    canFire: (SIMD2<Float>, GuardWeakpoint, Weapon.Kind) -> Bool,
    canFireAtBody: (SIMD2<Float>, Weapon.Kind) -> Bool,
    isCovered: (SIMD2<Float>) -> Bool, isThreatened: (SIMD2<Float>) -> Bool,
    isSpaced: (SIMD2<Float>) -> Bool
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
    let assignment = Self.assignment(
      member: input.member, position: input.position, points: input.weakpoints)
    let next = Context(
      member: input.member, leader: input.leader, order: input.order, stance: input.stance,
      phase: input.phase, stage: input.stage, part: assignment?.part, threatened: threatened)
    if context != next {
      goal = nil
      goalTargetsBody = false
      sincePlan = .infinity
    }
    context = next
    sincePlan += input.dt

    func legal(_ position: SIMD2<Float>) -> Bool {
      simd_distance(position, input.leaderPosition) <= Self.leaderLeash
        && canStand(position) && canTraverse(input.position, position)
    }
    func available(_ position: SIMD2<Float>) -> Bool {
      legal(position) && isSpaced(position)
    }
    func safe(_ position: SIMD2<Float>) -> Bool {
      !isThreatened(position) || isCovered(position)
    }
    if input.stance == .defend {
      // Defend recalls the squad; cover must not turn into a remote, implicit Hold order.
      // A subsequently issued Go/Hold still owns movement, with no combat authority.
      if case .holding = input.order {
        goal = nil
        return Intent(activity: .holding)
      }
      let fromLeader = simd_distance(input.position, input.leaderPosition)
      let fromBase = simd_distance(input.position, input.baseTarget)
      func returning(_ point: SIMD2<Float>) -> Bool {
        let toLeader = simd_distance(point, input.leaderPosition)
        let toBase = simd_distance(point, input.baseTarget)
        // Nearby real shelter can sit behind a formation slot that faces the guard.
        let nearFormation = toLeader <= 2.6 && (toBase <= 1.5 || isCovered(point))
        return simd_distance(point, input.position) <= Self.localRadius
          && available(point)
          && (nearFormation || toBase < fromBase - 0.25)
          && (fromLeader <= 2.6 ? toLeader <= 2.6 : toLeader < fromLeader - 0.25)
      }
      if sincePlan >= Self.replanInterval
        || goal.map({
          !returning($0) || !safe($0) || (goalActivity == .avoiding && !isCovered($0))
        }) != false
      {
        let candidates =
          ([input.position, input.baseTarget] + Self.near(input.position)
          + Self.near(input.baseTarget)).filter(returning)
        goal =
          candidates.filter(isCovered).min {
            simd_distance($0, input.baseTarget) < simd_distance($1, input.baseTarget)
          }
        goalActivity = .avoiding
        if goal == nil, !isSpaced(input.position) || !isSpaced(input.baseTarget) {
          // An occupied close-formation slot must not collapse the recall onto its owner.
          // Without cover, settle at a nearby clear return point rather than orbiting.
          goal =
            returning(input.position) && safe(input.position)
            ? input.position
            : candidates.filter(safe).min {
              simd_distance($0, input.baseTarget) < simd_distance($1, input.baseTarget)
            }
          goalActivity = .following
        }
        sincePlan = 0
      }
      return Intent(position: goal, activity: goal == nil ? .following : goalActivity)
    }
    let points = input.weakpoints.filter { $0.part == assignment?.part }
    let point = points.min {
      simd_distance_squared($0.ground, input.position)
        < simd_distance_squared($1.ground, input.position)
    }
    var intent = Intent(
      lookAt: point?.ground ?? input.guardPosition, engaged: true, weapon: assignment?.weapon,
      activity: fallback)
    if case .holding = input.order {
      goal = nil
      if let assignment, canStand(input.position),
        let point = points.first(where: { canFire(input.position, $0, assignment.weapon) })
      {
        intent.lookAt = point.ground
        intent.fire = true
        intent.activity = .attacking
      } else {
        let weapon = Self.ordinaryWeapon(for: input.member)
        if canStand(input.position), canFireAtBody(input.position, weapon) {
          intent.lookAt = input.guardPosition
          intent.weapon = weapon
          intent.targetsBody = true
          intent.fire = true
          intent.activity = .attacking
        }
      }
      return intent
    }
    if threatened {
      if goalActivity != .avoiding || sincePlan >= Self.replanInterval
        || goal.map({ !available($0) || !safe($0) }) != false
      {
        goal = Self.near(input.position).filter { available($0) && safe($0) }.min {
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
    if points.isEmpty {
      return ordinaryAttack(
        input: input, available: available, safe: safe, canStand: canStand,
        canFireAtBody: canFireAtBody, isCovered: isCovered, isSpaced: isSpaced)
    }
    if let assignment, canStand(input.position), isSpaced(input.position),
      let point = points.first(where: {
        canFire(input.position, $0, assignment.weapon)
      })
    {
      // Already in a real firing stance: do not keep orbiting just to reach an ideal radius.
      goal = input.position
      goalTargetsBody = false
      intent.position = input.position
      intent.lookAt = point.ground
      intent.fire = true
      intent.activity = .attacking
      return intent
    }
    if input.member == .miki || input.member == .tom,
      canStand(input.position), isSpaced(input.position),
      canFireAtBody(input.position, Self.ordinaryWeapon(for: input.member))
    {
      // Take a useful shot from this safe stance before retaining an old eye orbit.
      // Laura keeps approaching her assigned leg.
      return ordinaryAttack(
        input: input, available: available, safe: safe, canStand: canStand,
        canFireAtBody: canFireAtBody, isCovered: isCovered, isSpaced: isSpaced)
    }
    if sincePlan < Self.replanInterval, let goal, available(goal), safe(goal) {
      if goalTargetsBody {
        return ordinaryAttack(
          input: input, available: available, safe: safe, canStand: canStand,
          canFireAtBody: canFireAtBody, isCovered: isCovered, isSpaced: isSpaced)
      }
      intent.position = goal
      intent.activity = goalActivity
      return intent
    }
    sincePlan = 0
    goal = nil
    goalTargetsBody = false
    if let assignment, !points.isEmpty {
      var stances: [SIMD2<Float>] = []
      for point in points {
        if !isSpaced(input.position) {
          stances += Self.near(input.position).filter {
            available($0) && safe($0) && canFire($0, point, assignment.weapon)
          }
        }
        let outward = Self.direction(
          point.ground - input.guardPosition, fallback: input.guardFacing)
        for radius in assignment.radii {
          for angle: Float in [0, 0.35, -0.35, 0.7, -0.7] {
            let candidate = input.guardPosition + Self.rotated(outward, by: angle) * radius
            if available(candidate), safe(candidate), canFire(candidate, point, assignment.weapon) {
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
          simd_distance($0, input.position) <= Self.localRadius && available($0) && safe($0)
        }.min { first, second in
          (ideals.map { simd_distance($0, first) }.min() ?? .infinity)
            < (ideals.map { simd_distance($0, second) }.min() ?? .infinity)
        }
      }
      goalActivity = goal == nil ? .following : .approaching
    }
    if goal == nil {
      return ordinaryAttack(
        input: input, available: available, safe: safe, canStand: canStand,
        canFireAtBody: canFireAtBody, isCovered: isCovered, isSpaced: isSpaced)
    }
    intent.position = goal
    intent.activity = goal == nil ? .following : goalActivity
    return intent
  }

  /// A specialist opportunity is preferred, but it never makes safe ordinary fire useless.
  /// The native execution query retains responsibility for weapon range, cover and allies.
  private mutating func ordinaryAttack(
    input: Input, available: (SIMD2<Float>) -> Bool, safe: (SIMD2<Float>) -> Bool,
    canStand: (SIMD2<Float>) -> Bool,
    canFireAtBody: (SIMD2<Float>, Weapon.Kind) -> Bool,
    isCovered: (SIMD2<Float>) -> Bool, isSpaced: (SIMD2<Float>) -> Bool
  ) -> Intent {
    goalTargetsBody = true
    let weapon = Self.ordinaryWeapon(for: input.member)
    if canStand(input.position), isSpaced(input.position),
      canFireAtBody(input.position, weapon)
    {
      goal = input.position
      goalActivity = .attacking
      return Intent(
        position: goal, lookAt: input.guardPosition, engaged: true, weapon: weapon,
        targetsBody: true, fire: true, activity: .attacking)
    }
    if sincePlan < Self.replanInterval {
      if let goal, available(goal), safe(goal) {
        if canFireAtBody(goal, weapon) {
          goalActivity = .approaching
          return Intent(
            position: goal, lookAt: input.guardPosition, engaged: true, weapon: weapon,
            targetsBody: true, activity: .approaching)
        }
        if goalActivity == .waiting { return Intent(position: goal, activity: .waiting) }
      } else if goal == nil, goalActivity == .waiting {
        return Intent(activity: .following)
      }
    }
    sincePlan = 0
    let candidates =
      ([input.position, input.baseTarget] + Self.near(input.position) + Self.near(input.baseTarget))
      .filter {
        simd_distance($0, input.position) <= Self.localRadius && available($0) && safe($0)
      }
    goal = candidates.filter { canFireAtBody($0, weapon) }.min {
      simd_distance($0, input.position) - (isCovered($0) ? 1 : 0)
        < simd_distance($1, input.position) - (isCovered($1) ? 1 : 0)
    }
    if let goal {
      goalActivity = .approaching
      return Intent(
        position: goal, lookAt: input.guardPosition, engaged: true, weapon: weapon,
        targetsBody: true, activity: .approaching)
    }
    // When no real firing lane is available, retain the existing nearby support behaviour.
    let support = ([input.position, input.baseTarget] + Self.near(input.baseTarget)).filter {
      simd_distance($0, input.position) <= Self.localRadius
        && simd_distance($0, input.baseTarget) <= Self.localRadius
        && available($0) && safe($0)
    }
    goal = support.filter(isCovered).min {
      simd_distance($0, input.baseTarget) < simd_distance($1, input.baseTarget)
    }
    if goal == nil, !isSpaced(input.position) || !isSpaced(input.baseTarget) {
      goal =
        support.contains(input.position)
        ? input.position
        : support.min {
          simd_distance($0, input.baseTarget) < simd_distance($1, input.baseTarget)
        }
    }
    goalActivity = .waiting
    return Intent(position: goal, activity: goal == nil ? .following : .waiting)
  }

  private static func ordinaryWeapon(for member: PartyMember) -> Weapon.Kind {
    switch member {
    case .miki: .longRifle
    case .laura: .shotgun
    case .tom: .minigun
    }
  }

  private static func assignment(
    member: PartyMember, position: SIMD2<Float>, points: [GuardWeakpoint]
  ) -> (part: GuardStrategy.Part, weapon: Weapon.Kind, radii: [Float])? {
    switch member {
    case .miki: return (.eye, .longRifle, [6, 7])
    case .tom: return (.eye, .minigun, [3.5, 4])
    case .laura:
      let legs = points.filter {
        if case .leg(let index) = $0.part { return (0..<GuardStrategy.legCount).contains(index) }
        return false
      }
      guard
        let leg = legs.min(by: {
          let a = simd_distance_squared($0.ground, position)
          let b = simd_distance_squared($1.ground, position)
          return a == b ? $0.id < $1.id : a < b
        })
      else { return nil }
      return (leg.part, .energySword, [2.65])
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
