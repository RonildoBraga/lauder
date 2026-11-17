import simd

/// Chooses where each companion should be: a Close formation slot around the leader, pulled
/// in or moved onto the leader's route where the slot does not fit (ADR 0003, phase S1).
struct SquadPlanner {
  /// Close formation: (to the side, behind the leader), in metres.
  static let closeSlots: [SIMD2<Float>] = [[0.9, 0.9], [-0.9, 0.9]]
  static let turnRate: Float = .pi
  /// A sharper change of direction flips the formation at once instead of swinging it round
  /// through the leader's new path; companions keep their sides and let the leader pass.
  static let flipAngle: Float = 110 * .pi / 180
  static let turningSpeed: Float = 0.5
  static let swapSaving: Float = 0.5
  static let swapInterval: Float = 1
  static let restoreDelay: Float = 0.3
  static let columnSpacing: Float = 1
  static let columnSwapSaving: Float = 0.2
  static let columnSwapInterval: Float = 0.5

  private enum Placement: Int {
    case slot, pulledIn, column
  }

  private(set) var heading: SIMD2<Float>
  /// Companions in slot order.
  private var order: [PartyMember] = []
  private var sinceSwap: Float = 0
  private var placement: [PartyMember: Placement] = [:]
  private var fitTime: [PartyMember: Float] = [:]
  /// Companions in their order along the leader's route, nearest first.
  private var columnOrder: [PartyMember] = []
  private var sinceColumnSwap: Float = 0

  init(heading: SIMD2<Float>) {
    self.heading = simd_normalize(heading)
  }

  struct Input {
    let leader: PartyMember
    let leaderPosition: SIMD2<Float>
    let leaderVelocity: SIMD2<Float>
    let positions: [PartyMember: SIMD2<Float>]
    let route: RouteMemory
    let dt: Float
  }

  mutating func targets(
    for input: Input, grid: NavigationGrid, isClear: (SIMD2<Float>, SIMD2<Float>) -> Bool
  ) -> [PartyMember: SIMD2<Float>] {
    let flipped = turn(towards: input.leaderVelocity, dt: input.dt)
    let companions = PartyMember.allCases.filter { $0 != input.leader }
    if flipped { order = [] }
    assign(companions, input: input)

    let leader = input.leaderPosition
    let side = SIMD2(-heading.y, heading.x)
    let isStill = simd_length(input.leaderVelocity) < 0.1
    orderColumn(companions, input: input)
    var result: [PartyMember: SIMD2<Float>] = [:]
    for (index, member) in order.enumerated() {
      let offset = Self.closeSlots[index]
      let slot = leader + side * offset.x - heading * offset.y
      let pulledIn = leader + (slot - leader) / 2
      func fits(_ point: SIMD2<Float>) -> Bool {
        grid.isRoomy(point) && isClear(leader, point)
      }
      let slotFits = fits(slot)
      fitTime[member] = slotFits ? (fitTime[member] ?? 0) + input.dt : 0
      // Compress at once; spread out again only after the slot has fitted for a moment, so a
      // slot brushing a wall edge does not flicker between places.
      let current = placement[member] ?? .slot
      let restored = (fitTime[member] ?? 0) >= Self.restoreDelay
      var next: Placement
      if slotFits && (current == .slot || restored) {
        next = .slot
      } else if fits(pulledIn) && (current != .column || restored) {
        next = .pulledIn
      } else {
        next = .column
      }
      placement[member] = next

      var target: SIMD2<Float>
      switch next {
      case .slot: target = slot
      case .pulledIn: target = pulledIn
      case .column:
        let distance = Self.columnSpacing * Float((columnOrder.firstIndex(of: member) ?? 0) + 1)
        if let onRoute = input.route.point(back: distance, from: leader) {
          target = onRoute
        } else {
          // Just after a switch or a reversal the route is still short: stand behind the
          // leader's actual movement, not the formation's still-turning heading.
          let speed = simd_length(input.leaderVelocity)
          let backwards = speed > Self.turningSpeed ? input.leaderVelocity / speed : heading
          let behind = leader - backwards * distance
          target =
            grid.isWalkable(behind) && isClear(leader, behind)
            ? behind : (input.positions[member] ?? leader)
        }
      }
      // A waiting companion stands clear of doorways, close to their place, on their own side
      // of it and on the leader's side of any wall.
      let own = input.positions[member] ?? target
      if isStill && !grid.isRoomy(target),
        let roomy = grid.nearestWalkable(
          to: target, within: 1.5,
          where: { candidate in
            grid.isRoomy(candidate) && isClear(leader, candidate)
              && simd_distance(candidate, own) <= simd_distance(target, own) + 0.5
              // Two waiting companions never share a spot, or neither could settle.
              && result.values.allSatisfy { simd_distance($0, candidate) >= 0.8 }
          })
      {
        target = roomy
      }
      result[member] = target
    }
    return result
  }

  /// The previous assignment is discarded, for example after a leader change.
  mutating func reset() {
    order = []
    placement = [:]
    fitTime = [:]
    columnOrder = []
  }

  /// Places on the leader's route go to whichever order needs less walking in total, so the
  /// two companions do not cross. A small margin keeps near-ties from trading places.
  private mutating func orderColumn(_ companions: [PartyMember], input: Input) {
    sinceColumnSwap += input.dt
    let leader = input.leaderPosition
    func cost(_ candidate: [PartyMember]) -> Float {
      candidate.enumerated().reduce(0) { total, entry in
        let distance = Self.columnSpacing * Float(entry.offset + 1)
        let place = input.route.point(back: distance, from: leader) ?? leader
        return total + simd_distance(input.positions[entry.element] ?? leader, place)
      }
    }
    let reversed = Array(companions.reversed())
    guard Set(columnOrder) == Set(companions), columnOrder.count == companions.count else {
      columnOrder = cost(companions) <= cost(reversed) ? companions : reversed
      sinceColumnSwap = 0
      return
    }
    let alternative = Array(columnOrder.reversed())
    if sinceColumnSwap >= Self.columnSwapInterval
      && cost(alternative) + Self.columnSwapSaving < cost(columnOrder)
    {
      columnOrder = alternative
      sinceColumnSwap = 0
    }
  }

  /// Returns true when the formation flipped rather than turned.
  private mutating func turn(towards velocity: SIMD2<Float>, dt: Float) -> Bool {
    let speed = simd_length(velocity)
    guard speed > Self.turningSpeed else { return false }
    let wanted = velocity / speed
    let angle = atan2(
      heading.x * wanted.y - heading.y * wanted.x, simd_dot(heading, wanted))
    if abs(angle) > Self.flipAngle {
      heading = wanted
      return true
    }
    let step = max(-Self.turnRate * dt, min(Self.turnRate * dt, angle))
    let cosine = cos(step)
    let sine = sin(step)
    heading = simd_normalize(
      SIMD2(heading.x * cosine - heading.y * sine, heading.x * sine + heading.y * cosine))
    return false
  }

  private mutating func assign(_ companions: [PartyMember], input: Input) {
    sinceSwap += input.dt
    let leader = input.leaderPosition
    let side = SIMD2(-heading.y, heading.x)
    func cost(_ candidate: [PartyMember]) -> Float {
      zip(candidate, Self.closeSlots).reduce(0) { total, pair in
        let slot = leader + side * pair.1.x - heading * pair.1.y
        return total + simd_distance(input.positions[pair.0] ?? leader, slot)
      }
    }
    let swapped = Array(companions.reversed())
    guard Set(order) == Set(companions), order.count == companions.count else {
      order = cost(companions) <= cost(swapped) ? companions : swapped
      sinceSwap = 0
      return
    }
    let alternative = Array(order.reversed())
    if sinceSwap >= Self.swapInterval && cost(alternative) + Self.swapSaving < cost(order) {
      order = alternative
      sinceSwap = 0
    }
  }
}
