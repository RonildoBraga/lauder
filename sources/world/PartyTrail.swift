import simd

/// A small, connected record of movement the world has actually resolved.
/// The caller owns leadership and collision checking; this value never adds an unchecked connector.
struct PartyTrail {
  struct Limits {
    var maximumNodeCount = 512
    var maximumRetainedLength: Float = 64
    var followerStallDuration: Float = 1
  }

  enum Diagnostic: Equatable, CustomStringConvertible {
    case capacity
    case disconnected(PartyMember)
    case followerBlocked(PartyMember)
    case unresolvedStep

    var description: String {
      switch self {
      case .capacity: "Party trail capacity reached. Relaunch Lauder to repeat the route check."
      case .disconnected(let member): "\(member.displayName)'s recorded route disconnected."
      case .followerBlocked(let member): "\(member.displayName) is blocked on the recorded route."
      case .unresolvedStep: "Party movement was not observed before the next step."
      }
    }
  }

  private struct Node {
    let position: SIMD2<Float>
    var neighbours: Set<Int> = []
  }

  private struct Request {
    let start: Int
    let target: Int?
    let delta: SIMD2<Float>
    let isFollower: Bool
    let actualStart: SIMD2<Float>
    var isCorrection = false
  }

  private static let positionTolerance: Float = 0.00001
  private static let resolvedMovementAllowance: Float = 0.003
  private static let maximumStepDistance: Float = 0.12
  private static let maximumSampleSpan: Float = 0.08
  private static let minimumSampleTurnCosine = cos(Float(0.1))
  private static let maximumClearanceChecks = 3
  private let limits: Limits
  private var nodes: [Int: Node] = [:]
  private var cursors: [PartyMember: Int] = [:]
  private var actualPositions: [PartyMember: SIMD2<Float>] = [:]
  private var needsEndpointCorrection: Set<PartyMember> = []
  private var pending: [PartyMember: Request] = [:]
  private var stalledTime: [PartyMember: Float] = [:]
  private var nextID = 0
  private var nextCoalescingID = 0

  private(set) var diagnostic: Diagnostic?
  var holdsAllMovement: Bool { diagnostic != nil }
  var nodeCount: Int { nodes.count }
  var retainedLength: Float {
    nodes.reduce(0) { length, entry in
      length
        + entry.value.neighbours.reduce(0) { subtotal, neighbour in
          guard neighbour > entry.key, let other = nodes[neighbour] else { return subtotal }
          return subtotal + simd_distance(entry.value.position, other.position)
        }
    }
  }

  /// Spawn order describes an authored, walkable line, not a nearest-point search.
  init(
    spawns: [(member: PartyMember, position: SIMD2<Float>)], limits: Limits = .init()
  ) {
    precondition(Set(spawns.map(\.member)) == Set(PartyMember.allCases))
    precondition(spawns.count == PartyMember.allCases.count)
    precondition(limits.maximumNodeCount >= spawns.count)
    precondition(limits.maximumRetainedLength > 0 && limits.followerStallDuration > 0)
    precondition(spawns.allSatisfy { Self.isFinite($0.position) })
    self.limits = limits
    for spawn in spawns {
      let previous = nextID - 1
      let id = appendNode(at: spawn.position)
      cursors[spawn.member] = id
      actualPositions[spawn.member] = spawn.position
      if previous >= 0 {
        precondition(simd_distance(nodes[previous]!.position, spawn.position) > 0)
        connect(previous, id)
      }
    }
    precondition(retainedLength <= limits.maximumRetainedLength)
  }

  /// Reconcile the previous engine tick. Only requested follower movement accrues stall time.
  /// Call only during active simulation; a long interruption contributes no stall time.
  mutating func observe(positions: [PartyMember: SIMD2<Float>], deltaTime: Float) {
    guard !holdsAllMovement else { return }
    let requests = pending
    pending.removeAll(keepingCapacity: true)
    let activeTime = deltaTime.isFinite && deltaTime > 0 && deltaTime <= 0.1 ? deltaTime : 0

    for member in PartyMember.allCases {
      guard let actual = positions[member], Self.isFinite(actual),
        let cursor = cursors[member], let start = nodes[cursor]?.position
      else {
        diagnostic = .disconnected(member)
        return
      }
      guard let request = requests[member] else {
        // Keep any numerical XZ residue separate from topology, bounded against the
        // same exact cursor. A quiet body is otherwise unchanged by the flat-floor resolver.
        let residue = simd_distance(start, actual)
        if residue > Self.resolvedMovementAllowance {
          diagnostic = .disconnected(member)
          return
        }
        actualPositions[member] = actual
        if residue > Self.positionTolerance {
          needsEndpointCorrection.insert(member)
        } else {
          needsEndpointCorrection.remove(member)
        }
        stalledTime[member] = 0
        continue
      }
      let travelled = simd_distance(request.actualStart, actual)
      guard travelled <= simd_length(request.delta) + Self.resolvedMovementAllowance else {
        diagnostic = .disconnected(member)
        return
      }
      actualPositions[member] = actual

      if request.isCorrection {
        let residue = simd_distance(start, actual)
        guard residue <= Self.resolvedMovementAllowance else {
          diagnostic = .disconnected(member)
          return
        }
        let progress = simd_distance(request.actualStart, start) - residue
        recordProgress(progress, for: member, request: request, activeTime: activeTime)
        guard !holdsAllMovement else { return }
        if residue <= Self.positionTolerance { needsEndpointCorrection.remove(member) }
        continue
      }

      if request.isFollower {
        guard let target = request.target, let end = nodes[target]?.position else {
          diagnostic = .disconnected(member)
          return
        }
        // Project only onto the edge selected before this tick. The exact graph records
        // progress; the separately retained actual offset is corrected by world movement.
        let projection = Self.projection(of: actual, from: start, to: end)
        guard simd_distance(actual, projection) <= Self.resolvedMovementAllowance,
          let id = insert(projection, from: request.start, toward: target)
        else {
          diagnostic = .disconnected(member)
          return
        }
        cursors[member] = id
        let progress = simd_distance(start, projection)
        recordProgress(progress, for: member, request: request, activeTime: activeTime)
        guard !holdsAllMovement else { return }
        if id == target && simd_distance(actual, end) > Self.positionTolerance {
          needsEndpointCorrection.insert(member)
        }
      } else {
        stalledTime[member] = 0
        guard travelled > Self.positionTolerance else { continue }
        if let target = request.target,
          let id = insert(actual, from: request.start, toward: target)
        {
          cursors[member] = id
        } else {
          let length = simd_distance(start, actual)
          guard canAddNode(extraLength: length) else {
            diagnostic = .capacity
            return
          }
          let id = appendNode(at: actual)
          connect(request.start, id)
          cursors[member] = id
        }
      }
    }
  }

  /// Reserve the complete party step before the world moves any body. A capacity hold returns
  /// no movement, including for the leader. Targets always lie on the next connected edge.
  mutating func prepareStep(
    leader: PartyMember, leaderDelta: SIMD2<Float>, maximumFollowerDistance: Float,
    canTraverse: ((SIMD2<Float>, SIMD2<Float>) -> Bool)? = nil
  ) -> [PartyMember: SIMD2<Float>] {
    guard !holdsAllMovement else { return [:] }
    guard pending.isEmpty else {
      diagnostic = .unresolvedStep
      return [:]
    }
    pruneUnusedRoute()
    coalesceShortSamples(canTraverse: canTraverse)
    guard let head = cursors[leader], Self.isFinite(leaderDelta),
      maximumFollowerDistance.isFinite, maximumFollowerDistance >= 0
    else {
      diagnostic = .disconnected(leader)
      return [:]
    }

    var requests: [PartyMember: Request] = [:]
    let delta = Self.limited(leaderDelta, to: Self.maximumStepDistance)
    let leaderActual = actualPositions[leader]!
    if simd_distance(leaderActual, nodes[head]!.position) > Self.positionTolerance {
      // A newly selected body reconciles its physical residue before authoring a new branch.
      requests[leader] = correction(for: leader, isFollower: false)
    } else if simd_length(delta) > Self.positionTolerance {
      requests[leader] = Request(
        start: head, target: existingEdge(from: head, for: delta), delta: delta, isFollower: false,
        actualStart: leaderActual
      )
    }

    var followers: [(member: PartyMember, route: [Int], distance: Float)] = []
    for member in PartyMember.allCases where member != leader {
      guard let start = cursors[member], let route = route(from: start, to: head) else {
        diagnostic = .disconnected(member)
        return [:]
      }
      followers.append((member, route, routeLength(route)))
    }
    // Route order reverses naturally when the rearmost member becomes leader.
    followers.sort {
      if abs($0.distance - $1.distance) > Self.positionTolerance {
        return $0.distance < $1.distance
      }
      return $0.member.rawValue < $1.member.rawValue
    }
    let followerLimit = min(maximumFollowerDistance, Self.maximumStepDistance)
    for (index, follower) in followers.enumerated() {
      let excess = follower.distance - Float(index + 1) * 0.8
      let start = follower.route[0]
      let actual = actualPositions[follower.member]!
      let residue = simd_distance(actual, nodes[start]!.position)
      if residue > Self.positionTolerance
        && (needsEndpointCorrection.contains(follower.member)
          || excess <= Self.positionTolerance || follower.route.count < 2)
      {
        if followerLimit > Self.positionTolerance {
          requests[follower.member] = correction(
            for: follower.member, isFollower: true, maximumDistance: followerLimit)
        }
        continue
      }
      guard excess > Self.positionTolerance, follower.route.count >= 2 else { continue }
      let target = follower.route[1]
      let edge = nodes[target]!.position - nodes[start]!.position
      let distance = simd_length(edge)
      let amount = min(followerLimit, excess, distance)
      guard amount > Self.positionTolerance else { continue }
      let aim = nodes[start]!.position + edge / distance * amount
      requests[follower.member] = Request(
        start: start, target: target, delta: Self.limited(aim - actual, to: followerLimit),
        isFollower: true, actualStart: actual
      )
    }

    // Every moving member may add one node. Edge splits normally preserve length; reserving
    // twice follower travel also bounds a small collision-resolved numerical deviation.
    let routeRequests = requests.values.filter { !$0.isCorrection }
    let extraLength = routeRequests.reduce(Float.zero) {
      $0 + (simd_length($1.delta) + Self.resolvedMovementAllowance) * ($1.isFollower ? 2 : 1)
    }
    guard nodes.count + routeRequests.count <= limits.maximumNodeCount,
      retainedLength + extraLength <= limits.maximumRetainedLength
    else {
      diagnostic = .capacity
      return [:]
    }
    pending = requests
    return Dictionary(
      uniqueKeysWithValues: PartyMember.allCases.map { ($0, requests[$0]?.delta ?? .zero) }
    )
  }

  private mutating func appendNode(at position: SIMD2<Float>) -> Int {
    let id = nextID
    nextID += 1
    nodes[id] = Node(position: position)
    return id
  }

  private func correction(
    for member: PartyMember, isFollower: Bool,
    maximumDistance: Float = Self.maximumStepDistance
  ) -> Request {
    let cursor = cursors[member]!
    let actual = actualPositions[member]!
    return Request(
      start: cursor, target: cursor,
      delta: Self.limited(nodes[cursor]!.position - actual, to: maximumDistance),
      isFollower: isFollower, actualStart: actual, isCorrection: true)
  }

  private mutating func recordProgress(
    _ progress: Float, for member: PartyMember, request: Request, activeTime: Float
  ) {
    let littleProgress = progress < min(0.002, simd_length(request.delta) * 0.1)
    stalledTime[member] = littleProgress ? (stalledTime[member] ?? 0) + activeTime : 0
    if stalledTime[member, default: 0] >= limits.followerStallDuration {
      diagnostic = .followerBlocked(member)
    }
  }

  private mutating func connect(_ first: Int, _ second: Int) {
    nodes[first]!.neighbours.insert(second)
    nodes[second]!.neighbours.insert(first)
  }

  private func canAddNode(extraLength: Float) -> Bool {
    nodes.count < limits.maximumNodeCount
      && retainedLength + extraLength <= limits.maximumRetainedLength
  }

  /// Search only a connection selected before the tick. Concurrent followers may have split
  /// that connection already, so its remaining chain is traversed without a geometric rebase.
  private mutating func insert(_ point: SIMD2<Float>, from start: Int, toward end: Int) -> Int? {
    guard let first = nodes[start]?.position, let last = nodes[end]?.position,
      Self.isOnEdge(point, from: first, to: last), let chain = route(from: start, to: end)
    else { return nil }
    for id in chain where simd_distance(nodes[id]!.position, point) <= Self.positionTolerance {
      return id
    }
    for (firstID, secondID) in zip(chain, chain.dropFirst()) {
      let firstPosition = nodes[firstID]!.position
      let secondPosition = nodes[secondID]!.position
      guard Self.isOnEdge(point, from: firstPosition, to: secondPosition) else { continue }
      let increase =
        simd_distance(firstPosition, point) + simd_distance(point, secondPosition)
        - simd_distance(firstPosition, secondPosition)
      guard canAddNode(extraLength: max(0, increase)) else { return nil }
      nodes[firstID]!.neighbours.remove(secondID)
      nodes[secondID]!.neighbours.remove(firstID)
      let id = appendNode(at: point)
      connect(firstID, id)
      connect(id, secondID)
      return id
    }
    return nil
  }

  private func existingEdge(from start: Int, for delta: SIMD2<Float>) -> Int? {
    let point = nodes[start]!.position + delta
    return nodes[start]!.neighbours.sorted().first {
      Self.isOnEdge(point, from: nodes[start]!.position, to: nodes[$0]!.position)
    }
  }

  private func route(from start: Int, to end: Int) -> [Int]? {
    guard nodes[start] != nil, nodes[end] != nil else { return nil }
    var queue = [start]
    var previous = [start: start]
    var index = 0
    while index < queue.count {
      let current = queue[index]
      if current == end {
        var path = [end]
        while path.last! != start { path.append(previous[path.last!]!) }
        return path.reversed()
      }
      for neighbour in nodes[current]!.neighbours.sorted() where previous[neighbour] == nil {
        previous[neighbour] = current
        queue.append(neighbour)
      }
      index += 1
    }
    return nil
  }

  private func routeLength(_ route: [Int]) -> Float {
    zip(route, route.dropFirst()).reduce(0) {
      $0 + simd_distance(nodes[$1.0]!.position, nodes[$1.1]!.position)
    }
  }

  private mutating func pruneUnusedRoute() {
    let occupied = Set(cursors.values)
    var changed = true
    while changed {
      changed = false
      for id in nodes.keys.sorted() where !occupied.contains(id) {
        guard let node = nodes[id] else { continue }
        if node.neighbours.count <= 1 {
          for neighbour in node.neighbours { nodes[neighbour]!.neighbours.remove(id) }
          nodes.removeValue(forKey: id)
          changed = true
        } else if node.neighbours.count == 2 {
          let neighbours = node.neighbours.sorted()
          let first = nodes[neighbours[0]]!.position - node.position
          let second = nodes[neighbours[1]]!.position - node.position
          // Remove straight-line density only. Corners and branch connections survive.
          let cross = first.x * second.y - first.y * second.x
          let scale = simd_length(first) * simd_length(second)
          if abs(cross) <= scale * 0.00001 && simd_dot(first, second) < 0 {
            nodes[neighbours[0]]!.neighbours.remove(id)
            nodes[neighbours[1]]!.neighbours.remove(id)
            nodes.removeValue(forKey: id)
            connect(neighbours[0], neighbours[1])
            changed = true
          }
        }
      }
    }
  }

  /// Reduce short, gentle samples only after a world sweep clears their entire replacement
  /// chord. Never remove an occupied cursor or alter an outstanding movement promise.
  private mutating func coalesceShortSamples(
    canTraverse: ((SIMD2<Float>, SIMD2<Float>) -> Bool)?
  ) {
    guard let canTraverse else { return }
    let occupied = Set(cursors.values)
    let ids = nodes.keys.sorted()
    guard !ids.isEmpty else { return }
    let first = ids.firstIndex { $0 >= nextCoalescingID } ?? 0
    var checks = 0
    for offset in 0..<ids.count {
      let id = ids[(first + offset) % ids.count]
      guard !occupied.contains(id), let node = nodes[id], node.neighbours.count == 2 else {
        continue
      }
      let neighbours = node.neighbours.sorted()
      let start = nodes[neighbours[0]]!.position
      let end = nodes[neighbours[1]]!.position
      let incoming = start - node.position
      let outgoing = end - node.position
      let span = simd_length(incoming) + simd_length(outgoing)
      let scale = simd_length(incoming) * simd_length(outgoing)
      guard span <= Self.maximumSampleSpan, scale > 0,
        simd_distance(start, end) > Self.positionTolerance,
        -simd_dot(incoming, outgoing) >= scale * Self.minimumSampleTurnCosine
      else { continue }

      // Advance after rejected queries too, so blocked old corners cannot starve new samples.
      nextCoalescingID = id + 1
      checks += 1
      if canTraverse(start, end) {
        nodes[neighbours[0]]!.neighbours.remove(id)
        nodes[neighbours[1]]!.neighbours.remove(id)
        nodes.removeValue(forKey: id)
        connect(neighbours[0], neighbours[1])
      }
      if checks == Self.maximumClearanceChecks { break }
    }
  }

  private static func isOnEdge(
    _ point: SIMD2<Float>, from start: SIMD2<Float>, to end: SIMD2<Float>
  ) -> Bool {
    // Only floating-point endpoint/collinearity error is tolerated. The larger allowance
    // for collision-resolved travel must never turn an intentional corner into a connector.
    return simd_distance(point, projection(of: point, from: start, to: end)) <= positionTolerance
  }

  private static func projection(
    of point: SIMD2<Float>, from start: SIMD2<Float>, to end: SIMD2<Float>
  ) -> SIMD2<Float> {
    let edge = end - start
    let squaredLength = simd_length_squared(edge)
    guard squaredLength > 0 else { return start }
    let fraction = simd_dot(point - start, edge) / squaredLength
    return start + edge * min(max(fraction, 0), 1)
  }

  private static func limited(_ delta: SIMD2<Float>, to maximum: Float) -> SIMD2<Float> {
    let distance = simd_length(delta)
    return distance > maximum ? delta / distance * maximum : delta
  }

  private static func isFinite(_ point: SIMD2<Float>) -> Bool {
    point.x.isFinite && point.y.isFinite
  }

}
