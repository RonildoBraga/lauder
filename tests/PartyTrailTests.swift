import Testing
import simd

@testable import Lauder

struct PartyTrailTests {
  @Test
  func followersTraverseTheRecordedCornerRatherThanCuttingAcrossIt() {
    var party = RouteCheck()
    for _ in 0..<10 { party.step(leader: .miki, delta: [0, -0.1]) }
    for _ in 0..<24 {
      let deltas = party.step(leader: .miki, delta: [0.1, 0])
      for member in [PartyMember.lara, .tomas] {
        let delta = deltas[member]!
        #expect(abs(delta.x * delta.y) < 0.00001)
        if delta.x > 0.0001 { #expect(abs(party.positions[member]!.y + 1) < 0.0001) }
      }
    }
    #expect(party.trail.diagnostic == nil)
    #expect(party.positions[.lara]!.x > 0)
    #expect(party.positions[.tomas]!.x > 0)
  }

  @Test
  func switchingToTheBackPreservesRouteOrderAndRetracesCorners() {
    var party = RouteCheck()
    for _ in 0..<10 { party.step(leader: .miki, delta: [0, -0.1]) }
    for _ in 0..<20 { party.step(leader: .miki, delta: [0.1, 0]) }
    for _ in 0..<20 { party.step(leader: .miki, delta: .zero) }

    // Tomas is now the back of the line. Merely selecting him must not move spaced members.
    let before = party.positions
    for _ in 0..<5 { party.step(leader: .tomas, delta: .zero) }
    for member in PartyMember.allCases {
      #expect(simd_distance(party.positions[member]!, before[member]!) < 0.0001)
    }

    // Travel back along the horizontal leg, then down its original vertical leg.
    for _ in 0..<4 { party.step(leader: .tomas, delta: [-0.1, 0]) }
    for _ in 0..<14 {
      let deltas = party.step(leader: .tomas, delta: [0, 0.1])
      for member in [PartyMember.miki, .lara] {
        let delta = deltas[member]!
        #expect(abs(delta.x * delta.y) < 0.00001)
        if delta.y > 0.0001 { #expect(abs(party.positions[member]!.x) < 0.0002) }
      }
    }
    #expect(party.trail.diagnostic == nil)
  }

  @Test
  func shortCornersSurvivePruningRegardlessOfTheirWorldScale() {
    var party = RouteCheck()
    for delta: SIMD2<Float> in [[0, -0.001], [0.001, 0], [0, -0.001]] {
      party.step(leader: .miki, delta: delta, followerDistance: 0)
    }
    let reverse = party.step(leader: .tomas, delta: .zero)
    #expect(abs(reverse[.miki]!.x) < 0.00001)
    #expect(abs(reverse[.miki]!.y - 0.001) < 0.00001)
    let second = party.step(leader: .tomas, delta: .zero)
    #expect(abs(second[.miki]!.x + 0.001) < 0.00001)
    #expect(abs(second[.miki]!.y) < 0.00001)
    let third = party.step(leader: .tomas, delta: .zero)
    #expect(abs(third[.miki]!.x) < 0.00001)
    #expect(abs(third[.miki]!.y - 0.001) < 0.00001)
    #expect(party.trail.diagnostic == nil)
  }

  @Test
  func endpointResidueReturnsToTheSameCursorBeforeFollowingAnotherEdge() {
    for overshoot: Float in [0.000002, 0.0005, 0.004] {
      // Lara occupies the endpoint, so pruning cannot merge it into a longer edge.
      var positions: [PartyMember: SIMD2<Float>] = [
        .miki: [0, -0.001], .lara: [0, 0], .tomas: [0, 1.6],
      ]
      var trail = PartyTrail(spawns: PartyMember.allCases.map { ($0, positions[$0]!) })
      let deltas = trail.prepareStep(
        leader: .tomas, leaderDelta: .zero, maximumFollowerDistance: 0.1)
      #expect(abs(deltas[.miki]!.y - 0.001) < 0.00001)
      for (member, delta) in deltas { positions[member]! += delta }
      positions[.miki] = [0, overshoot]
      trail.observe(positions: positions, deltaTime: 1 / 30)
      if overshoot <= 0.003 {
        #expect(trail.diagnostic == nil)
        let correction = trail.prepareStep(
          leader: .tomas, leaderDelta: .zero, maximumFollowerDistance: 0.1)
        #expect(abs(correction[.miki]!.x) < 0.00001)
        #expect(abs(correction[.miki]!.y + (overshoot > 0.00001 ? overshoot : 0)) < 0.00001)
      } else {
        #expect(trail.diagnostic == .disconnected(.miki))
      }
    }
  }

  @Test
  func capturedCollisionResidueDoesNotDisconnectOrBendTheRecordedEdge() {
    var positions: [PartyMember: SIMD2<Float>] = [
      .miki: [-8, 2.5], .lara: [-8, 3.8], .tomas: [-8, 4.474639],
    ]
    var trail = PartyTrail(spawns: PartyMember.allCases.map { ($0, positions[$0]!) })
    let deltas = trail.prepareStep(
      leader: .miki, leaderDelta: .zero, maximumFollowerDistance: 0.043333173)
    for (member, delta) in deltas { positions[member]! += delta }
    positions[.tomas] = [-8.000571, 4.435579]
    trail.observe(positions: positions, deltaTime: 1 / 30)
    #expect(trail.diagnostic == nil)
    let next = trail.prepareStep(
      leader: .miki, leaderDelta: .zero, maximumFollowerDistance: 0.043333173)
    #expect(next[.tomas]!.x > 0)
    #expect(next[.tomas]!.y < 0)
    #expect(simd_length(next[.tomas]!) <= 0.043334)
  }

  @Test
  func idleResidueAndLeaderHandoffAreReconciledWithoutCreatingHistory() {
    var party = RouteCheck()
    party.positions[.lara]! += [0.000571, 0]
    party.trail.observe(positions: party.positions, deltaTime: 1 / 30)
    #expect(party.trail.diagnostic == nil)
    let correction = party.step(leader: .lara, delta: [0, -0.1])
    #expect(abs(correction[.lara]!.x + 0.000571) < 0.00001)
    #expect(abs(correction[.lara]!.y) < 0.00001)
    #expect(party.trail.nodeCount == 3)
    let movement = party.step(leader: .lara, delta: [0, -0.1])
    #expect(abs(movement[.lara]!.y + 0.1) < 0.00001)
    #expect(party.trail.diagnostic == nil)
  }

  @Test
  func repeatedLateralCollisionResidueCannotAccumulateIntoGraphCorners() {
    var party = RouteCheck(limits: .init(maximumNodeCount: 6, maximumRetainedLength: 3))
    for frame in 0..<400 {
      let deltas = party.trail.prepareStep(
        leader: .miki, leaderDelta: [0, -0.1], maximumFollowerDistance: 0.1)
      for (member, delta) in deltas {
        party.positions[member]! += delta
        if member != .miki && abs(delta.y) > 0.01 {
          party.positions[member]!.x += frame.isMultiple(of: 2) ? 0.000571 : -0.000571
        }
      }
      party.trail.observe(positions: party.positions, deltaTime: 1 / 30)
      #expect(party.trail.diagnostic == nil)
      #expect(party.trail.nodeCount <= 6)
      #expect(party.trail.retainedLength <= 3)
    }
    #expect(party.positions[.miki]!.y < -39)
  }

  @Test
  func physicalCornerResidueIsCorrectedBeforeTheNextLeg() {
    var positions: [PartyMember: SIMD2<Float>] = [
      .miki: [0, -0.001], .lara: [0, 0], .tomas: [1.6, 0],
    ]
    var trail = PartyTrail(spawns: PartyMember.allCases.map { ($0, positions[$0]!) })
    let first = trail.prepareStep(
      leader: .tomas, leaderDelta: .zero, maximumFollowerDistance: 0.1)
    for (member, delta) in first { positions[member]! += delta }
    positions[.miki] = [0.0005, 0.0005]
    trail.observe(positions: positions, deltaTime: 1 / 30)
    let correction = trail.prepareStep(
      leader: .tomas, leaderDelta: [0.1, 0], maximumFollowerDistance: 0.1)
    #expect(simd_distance(correction[.miki]!, [-0.0005, -0.0005]) < 0.00001)
    for (member, delta) in correction { positions[member]! += delta }
    trail.observe(positions: positions, deltaTime: 1 / 30)
    let nextLeg = trail.prepareStep(
      leader: .tomas, leaderDelta: .zero, maximumFollowerDistance: 0.1)
    #expect(nextLeg[.miki]!.x > 0)
    #expect(abs(nextLeg[.miki]!.y) < 0.00001)
    #expect(trail.diagnostic == nil)
  }

  @Test
  func idleCornerResidueIsCorrectedEvenWhenTheLeaderHasMovedOn() {
    var positions: [PartyMember: SIMD2<Float>] = [
      .miki: [0, 0], .lara: [0, 0.8], .tomas: [1.6, 0.8],
    ]
    var trail = PartyTrail(spawns: PartyMember.allCases.map { ($0, positions[$0]!) })
    // Settle Miki at the retained corner with the other two spaced along its next leg.
    for _ in 0..<12 {
      let deltas = trail.prepareStep(
        leader: .tomas, leaderDelta: .zero, maximumFollowerDistance: 0.1)
      for (member, delta) in deltas { positions[member]! += delta }
      trail.observe(positions: positions, deltaTime: 1 / 30)
    }
    #expect(simd_distance(positions[.miki]!, [0, 0.8]) < 0.00001)
    let advance = trail.prepareStep(
      leader: .tomas, leaderDelta: [0.1, 0], maximumFollowerDistance: 0.1)
    #expect(advance[.miki] == .zero)
    for (member, delta) in advance { positions[member]! += delta }
    positions[.miki]! += [-0.0005, 0.0005]
    trail.observe(positions: positions, deltaTime: 1 / 30)

    let correction = trail.prepareStep(
      leader: .tomas, leaderDelta: .zero, maximumFollowerDistance: 0.1)
    #expect(simd_distance(correction[.miki]!, [0.0005, -0.0005]) < 0.00001)
    for (member, delta) in correction { positions[member]! += delta }
    trail.observe(positions: positions, deltaTime: 1 / 30)
    let nextLeg = trail.prepareStep(
      leader: .tomas, leaderDelta: .zero, maximumFollowerDistance: 0.1)
    #expect(nextLeg[.miki]!.x > 0.05)
    #expect(abs(nextLeg[.miki]!.y) < 0.00001)
    #expect(trail.diagnostic == nil)
  }

  @Test
  func nearbyLoopPassesStayDistinctAndSwitchingDoesNotCreateAShortcut() {
    var party = RouteCheck()
    // Keep followers stationary while the leader records a U ending near the initial line.
    for delta: SIMD2<Float> in [[0, -0.1], [0.1, 0], [0, 0.1], [-0.1, 0]] {
      let count = delta == SIMD2<Float>([-0.1, 0]) ? 9 : 10
      for _ in 0..<count { party.step(leader: .miki, delta: delta, followerDistance: 0) }
    }
    #expect(simd_distance(party.positions[.miki]!, [0, 0]) < 0.11)
    let step = party.step(leader: .tomas, delta: .zero)
    // Miki is geometrically close to Lara, but must first go RIGHT along the recorded U.
    #expect(step[.miki]!.x > 0)
    #expect(abs(step[.miki]!.y) < 0.0001)
    #expect(party.trail.diagnostic == nil)
  }

  @Test
  func observationsUseActualMovementAndFollowersCanSettleWithoutLeaderInput() {
    var party = RouteCheck()
    let requested = party.trail.prepareStep(
      leader: .miki, leaderDelta: [0, -0.1], maximumFollowerDistance: 0.1
    )
    #expect(requested[.miki] == [0, -0.1])
    party.positions[.miki] = [0, -0.04]
    party.trail.observe(positions: party.positions, deltaTime: 1 / 30)
    let following = party.step(leader: .miki, delta: .zero)
    #expect(abs(following[.lara]!.y + 0.04) < 0.0001)
    #expect(abs(following[.tomas]!.y + 0.04) < 0.0001)
    #expect(party.trail.diagnostic == nil)
  }

  @Test
  func blockedFollowersHoldThePartyButPushingTheLeaderIntoAWallDoesNot() {
    var wall = RouteCheck()
    for _ in 0..<50 {
      _ = wall.trail.prepareStep(
        leader: .miki, leaderDelta: [0, -0.1], maximumFollowerDistance: 0.1
      )
      wall.trail.observe(positions: wall.positions, deltaTime: 1 / 30)
    }
    #expect(wall.trail.diagnostic == nil)
    #expect(wall.trail.nodeCount == 3)

    var blocked = RouteCheck(limits: .init(followerStallDuration: 0.1))
    for _ in 0..<10 {
      blocked.step(leader: .miki, delta: [0, -0.1], followerDistance: 0)
    }
    for _ in 0..<5 {
      _ = blocked.trail.prepareStep(
        leader: .miki, leaderDelta: .zero, maximumFollowerDistance: 0.1
      )
      blocked.trail.observe(positions: blocked.positions, deltaTime: 1 / 30)
    }
    #expect(blocked.trail.diagnostic == .followerBlocked(.lara))
    #expect(blocked.trail.holdsAllMovement)
    #expect(
      blocked.trail.prepareStep(
        leader: .miki, leaderDelta: [0.1, 0], maximumFollowerDistance: 0.1
      ).isEmpty)
  }

  @Test
  func interruptionTimeDoesNotCountAsAStallAndOffRouteMovementDoesNotInventAConnector() {
    var party = RouteCheck(limits: .init(followerStallDuration: 0.1))
    for _ in 0..<10 { party.step(leader: .miki, delta: [0, -0.1], followerDistance: 0) }
    _ = party.trail.prepareStep(
      leader: .miki, leaderDelta: .zero, maximumFollowerDistance: 0.1
    )
    party.trail.observe(positions: party.positions, deltaTime: 20)
    #expect(party.trail.diagnostic == nil)

    _ = party.trail.prepareStep(
      leader: .miki, leaderDelta: .zero, maximumFollowerDistance: 0.1
    )
    party.positions[.lara]! += [0.02, -0.04]
    party.trail.observe(positions: party.positions, deltaTime: 1 / 30)
    #expect(party.trail.diagnostic == .disconnected(.lara))
    #expect(party.trail.holdsAllMovement)
  }

  @Test
  func tinyNodeAndLengthBudgetsHoldBeforeAnyBodyMoves() {
    for limits in [
      PartyTrail.Limits(maximumNodeCount: 3),
      PartyTrail.Limits(maximumRetainedLength: 1.65),
    ] {
      var party = RouteCheck(limits: limits)
      let before = party.positions
      let deltas = party.step(leader: .miki, delta: [0, -0.1])
      #expect(deltas.isEmpty)
      #expect(party.positions == before)
      #expect(party.trail.diagnostic == .capacity)
      #expect(party.trail.nodeCount <= limits.maximumNodeCount)
      #expect(party.trail.retainedLength <= limits.maximumRetainedLength)
    }
  }

  @Test
  func unusedStraightHistoryIsPrunedWhileRequiredCornersRemainBounded() {
    let limits = PartyTrail.Limits(maximumNodeCount: 6, maximumRetainedLength: 3)
    var party = RouteCheck(limits: limits)
    for _ in 0..<200 {
      party.step(leader: .miki, delta: [0, -0.1])
      #expect(party.trail.nodeCount <= limits.maximumNodeCount)
      #expect(party.trail.retainedLength <= limits.maximumRetainedLength)
    }
    #expect(party.trail.diagnostic == nil)
    #expect(party.positions[.miki]!.y < -19)
    let count = party.trail.nodeCount
    for _ in 0..<200 { party.step(leader: .miki, delta: .zero) }
    #expect(party.trail.nodeCount <= count)
    #expect(party.trail.diagnostic == nil)
  }

  @Test
  func slowCurvedMovementUsesCheckedDistanceSamplesRatherThanOneNodePerFrame() {
    let spawns = Dictionary(
      uniqueKeysWithValues: PartyMember.allCases.map {
        let position = PrototypeLayout.spawn(for: $0)
        return ($0, SIMD2(position.x, position.z))
      })
    var party = RouteCheck(positions: spawns)
    for frame in 0..<2000 {
      var checks = 0
      let angle = Float(frame) * 0.001
      party.step(
        leader: .miki, delta: 0.001 * SIMD2(sin(angle), -cos(angle)),
        followerDistance: 2.6 / 60,
        canTraverse: { from, to in
          checks += 1
          #expect(simd_distance(from, to) > 0.00001)
          #expect(simd_distance(from, to) <= 0.080001)
          return true  // An empty world clears the whole proposed chord.
        })
      #expect(checks <= 3)
      #expect(party.trail.diagnostic == nil)
      #expect(party.trail.nodeCount <= 512)
      #expect(party.trail.retainedLength <= 64)
    }
    #expect(simd_distance(party.positions[.miki]!, spawns[.miki]!) > 1)

    // Selecting the rear member retains its position; the others retrace connected samples.
    let rear = party.positions[.tomas]!
    party.step(leader: .tomas, delta: .zero, canTraverse: { _, _ in true })
    #expect(simd_distance(party.positions[.tomas]!, rear) < 0.00001)
    for _ in 0..<600 {
      party.step(leader: .tomas, delta: [0, 0.001], canTraverse: { _, _ in true })
      #expect(party.trail.diagnostic == nil)
      #expect(party.trail.nodeCount <= 512)
    }
    #expect(party.positions[.tomas]!.y > rear.y + 0.5)
  }

  @Test
  func aBlockedCheckedChordPreservesTheRecordedBend() {
    let angle: Float = 0.03
    let first = SIMD2(cos(angle), -sin(angle))
    let bend = SIMD2<Float>(1 / cos(angle), 0)
    let last = SIMD2(cos(angle), sin(angle))
    var party = RouteCheck(positions: [
      .miki: first, .lara: first - [0, 0.8], .tomas: first - [0, 1.6],
    ])
    party.step(leader: .miki, delta: bend - first, followerDistance: 0)
    party.step(leader: .miki, delta: last - bend, followerDistance: 0)
    var checks = 0
    let reverse = party.step(
      leader: .tomas, delta: .zero,
      canTraverse: { from, to in
        checks += 1
        // The original legs are tangent to this expanded circular obstacle. Their chord
        // crosses its interior, so the world rejects coalescing even this gentle bend.
        let edge = to - from
        let amount = min(max(-simd_dot(from, edge) / simd_length_squared(edge), 0), 1)
        return simd_length(from + amount * edge) >= 0.99999
      })
    #expect(checks > 0)
    #expect(reverse[.miki]!.x > 0)
    #expect(reverse[.miki]!.y < 0)
    #expect(party.trail.diagnostic == nil)
  }

  @Test
  func clearanceAttemptsAreBoundedAndRotatePastRejectedSamples() {
    var party = RouteCheck()
    for frame in 0..<20 {
      let angle = Float(frame) * 0.01
      party.step(
        leader: .miki, delta: 0.01 * SIMD2(cos(angle), sin(angle)), followerDistance: 0)
    }
    let before = party.trail.nodeCount
    var starts: [SIMD2<Float>] = []
    let clearance: (SIMD2<Float>, SIMD2<Float>) -> Bool = { from, _ in
      starts.append(from)
      return from.x > 0.025
    }
    party.step(leader: .miki, delta: .zero, followerDistance: 0, canTraverse: clearance)
    #expect(starts.count == 3)
    #expect(starts.allSatisfy { $0.x <= 0.025 })
    #expect(party.trail.nodeCount == before)
    starts.removeAll()
    party.step(leader: .miki, delta: .zero, followerDistance: 0, canTraverse: clearance)
    #expect(!starts.isEmpty)
    #expect(starts.count <= 3)
    #expect(starts[0].x > 0.025)
    #expect(party.trail.nodeCount < before)
    #expect(party.trail.diagnostic == nil)
  }

  @Test
  func occupiedAndPendingCursorsAreNeverCoalesced() {
    var party = RouteCheck(positions: [
      .miki: [0, 0], .lara: [0.03, 0], .tomas: [0.06, 0.001],
    ])
    var checks = 0
    party.step(
      leader: .miki, delta: .zero,
      canTraverse: { _, _ in
        checks += 1
        return true
      })
    #expect(checks == 0)
    #expect(party.trail.nodeCount == 3)
    _ = party.trail.prepareStep(
      leader: .miki, leaderDelta: [0.001, 0], maximumFollowerDistance: 0.1)
    let unresolved = party.trail.prepareStep(
      leader: .miki, leaderDelta: .zero, maximumFollowerDistance: 0.1,
      canTraverse: { _, _ in
        checks += 1
        return true
      })
    #expect(checks == 0)
    #expect(unresolved.isEmpty)
    #expect(party.trail.diagnostic == .unresolvedStep)
  }

  @Test
  func anOutAndBackDoesNotOfferAZeroLengthReplacementChord() {
    var party = RouteCheck()
    party.step(leader: .miki, delta: [0.01, 0], followerDistance: 0)
    party.step(leader: .miki, delta: [-0.01, 0], followerDistance: 0)
    var checks = 0
    party.step(
      leader: .miki, delta: .zero, followerDistance: 0,
      canTraverse: { from, to in
        checks += 1
        #expect(simd_distance(from, to) > 0.00001)
        return true
      })
    #expect(checks == 0)
    #expect(party.trail.nodeCount == 3)
    #expect(party.trail.diagnostic == nil)
  }

  private struct RouteCheck {
    var positions: [PartyMember: SIMD2<Float>]
    var trail: PartyTrail

    init(
      limits: PartyTrail.Limits = .init(), positions supplied: [PartyMember: SIMD2<Float>]? = nil
    ) {
      let positions: [PartyMember: SIMD2<Float>] =
        supplied ?? [
          .miki: [0, 0], .lara: [0, 0.8], .tomas: [0, 1.6],
        ]
      self.positions = positions
      trail = PartyTrail(
        spawns: PartyMember.allCases.map { ($0, positions[$0]!) }, limits: limits)
    }

    @discardableResult
    mutating func step(
      leader: PartyMember, delta: SIMD2<Float>, followerDistance: Float = 0.1,
      canTraverse: ((SIMD2<Float>, SIMD2<Float>) -> Bool)? = nil
    ) -> [PartyMember: SIMD2<Float>] {
      let deltas = trail.prepareStep(
        leader: leader, leaderDelta: delta, maximumFollowerDistance: followerDistance,
        canTraverse: canTraverse)
      for (member, movement) in deltas { positions[member]! += movement }
      trail.observe(positions: positions, deltaTime: 1 / 30)
      return deltas
    }
  }
}
