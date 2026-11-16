import Testing
import simd

@testable import Lauder

struct PartyMotionTests {
  @Test
  func anUnobstructedSweepMovesTheWholeRequestedDistance() {
    var calls = 0
    let position = PartyMotion.resolve(start: [2, 3], delta: [0.2, -0.1]) { start, end in
      calls += 1
      #expect(start == [2, 3])
      #expect(end == [2.2, 2.9])
      return nil
    }
    #expect(position == [2.2, 2.9])
    #expect(calls == 1)
  }

  @Test
  func headOnMotionStopsBeforeTheWallWithoutSliding() {
    var calls = 0
    let position = PartyMotion.resolve(start: .zero, delta: [1, 0]) { _, _ in
      calls += 1
      return .init(distance: 0.4, normal: [-1, 0])
    }
    #expect(simd_distance(position, [0.398, 0]) < 0.00001)
    #expect(calls == 1)
  }

  @Test
  func anObliqueHitSlidesOnlyAfterSweepingTheRemainingPath() {
    var calls = 0
    let position = PartyMotion.resolve(start: .zero, delta: [1, 1]) { start, end in
      calls += 1
      if calls == 1 { return .init(distance: sqrt(2) / 2, normal: [-2, 0]) }
      #expect(abs(end.x - start.x) < 0.00001)
      #expect(end.y == 1)
      return nil
    }
    #expect(abs(position.x - (0.5 - 0.002 / sqrt(2))) < 0.00001)
    #expect(position.y == 1)
    #expect(calls == 2)
  }

  @Test
  func aSecondWallStopsTheSlideWithoutAThirdSweep() {
    var calls = 0
    var contact = SIMD2<Float>.zero
    let position = PartyMotion.resolve(start: .zero, delta: [1, 1]) { start, _ in
      calls += 1
      if calls == 1 { return .init(distance: sqrt(2) / 2, normal: [-1, 0]) }
      contact = start
      return .init(distance: 0.2, normal: [0, -1])
    }
    #expect(simd_distance(position, contact + [0, 0.198]) < 0.00001)
    #expect(calls == 2)
  }

  @Test(arguments: [
    PartyMotion.Hit(distance: 0, normal: [-1, 0]),
    PartyMotion.Hit(distance: -0.1, normal: [-1, 0]),
    PartyMotion.Hit(distance: .nan, normal: [-1, 0]),
    PartyMotion.Hit(distance: .infinity, normal: [-1, 0]),
    PartyMotion.Hit(distance: 2, normal: [-1, 0]),
    PartyMotion.Hit(distance: 0.1, normal: .zero),
    PartyMotion.Hit(distance: 0.1, normal: [.nan, 0]),
  ])
  func overlapOrInvalidHitsCannotAuthorizeMotion(hit: PartyMotion.Hit) {
    var calls = 0
    let start = SIMD2<Float>([2, 3])
    let position = PartyMotion.resolve(start: start, delta: [1, 0]) { _, _ in
      calls += 1
      return hit
    }
    #expect(position == start)
    #expect(calls == 1)
  }

  @Test
  func overlapOnTheSlideKeepsTheFirstSafePosition() {
    var calls = 0
    var contact = SIMD2<Float>.zero
    let position = PartyMotion.resolve(start: .zero, delta: [1, 1]) { start, _ in
      calls += 1
      if calls == 1 { return .init(distance: sqrt(2) / 2, normal: [-1, 0]) }
      contact = start
      return .init(distance: 0, normal: [0, -1])
    }
    #expect(position == contact)
    #expect(calls == 2)
  }

  @Test(arguments: [SIMD2<Float>.zero, [.nan, 0], [0, .infinity]])
  func zeroOrInvalidInputDoesNotCast(delta: SIMD2<Float>) {
    var calls = 0
    let start = SIMD2<Float>([2, 3])
    let position = PartyMotion.resolve(start: start, delta: delta) { _, _ in
      calls += 1
      return nil
    }
    #expect(position == start)
    #expect(calls == 0)
  }

  @Test
  func footprintTravelUsesTheSphereCentreRatherThanItsContactPoint() {
    let hit = PartyMotion.footprintHit(
      from: .zero, to: [1, 0], point: [0.76, 0.1, 0], normal: [-1, 0, 0], radius: 0.26)
    #expect(abs(hit.distance - 0.5) < 0.00001)
    #expect(hit.normal == [-1, 0])
  }

  @Test
  func anOffCentreVerticalContactKeepsTheFullNormalMagnitude() {
    let normal = SIMD3<Float>([-sqrt(3) / 2, 0.5, 0])
    let point = SIMD3<Float>([0.5, 0.85, 0]) - 0.26 * normal
    let hit = PartyMotion.footprintHit(
      from: .zero, to: [1, 0], point: point, normal: normal, radius: 0.26)
    #expect(abs(hit.distance - 0.5) < 0.00001)
    #expect(abs(hit.normal.x - normal.x) < 0.00001)
  }

  @Test
  func anObliqueSweepProjectsCentreTravelAlongItsOwnDirection() {
    let hit = PartyMotion.footprintHit(
      from: [2, 3], to: [3, 4], point: [2.66, 0.1, 3.4], normal: [-1, 0, 0], radius: 0.26)
    #expect(abs(hit.distance - 0.4 * sqrt(2)) < 0.00001)
  }

  @Test
  func anOffLineContactCannotInventTravelAlongTheSweep() {
    let hit = PartyMotion.footprintHit(
      from: .zero, to: [1, 0], point: [0.76, 0.1, 0.01], normal: [-1, 0, 0], radius: 0.26)
    #expect(hit.distance == 0)
    #expect(hit.normal == .zero)
  }

  @Test(arguments: [Float(-0.01), 1.01])
  func aContactOutsideTheFiniteSweepIsRejected(centre: Float) {
    let hit = PartyMotion.footprintHit(
      from: .zero, to: [1, 0], point: [centre + 0.26, 0.1, 0],
      normal: [-1, 0, 0], radius: 0.26)
    #expect(hit.distance == 0)
    #expect(hit.normal == .zero)
  }

  @Test
  func tinyEndpointRoundingIsClampedToTheFiniteSweep() {
    let hit = PartyMotion.footprintHit(
      from: .zero, to: [1, 0], point: [1.260005, 0.1, 0], normal: [-1, 0, 0], radius: 0.26)
    #expect(hit.distance == 1)
  }

  @Test(arguments: [
    SIMD3<Float>.zero, [0, 0.5, 0], [.nan, 0, 0], [.infinity, 0, 0],
  ])
  func invalidFullNormalsAreRejected(normal: SIMD3<Float>) {
    let hit = PartyMotion.footprintHit(
      from: .zero, to: [1, 0], point: [0.76, 0.1, 0], normal: normal, radius: 0.26)
    #expect(hit.distance == 0)
    #expect(hit.normal == .zero)
  }

  @Test
  func theStartingOverlapSentinelIsNotAContactPoint() {
    let hit = PartyMotion.footprintHit(
      from: [-1, 0], to: [1, 0], point: .zero, normal: [-1, 0, 0], radius: 0.26)
    #expect(hit.distance == 0)
    #expect(hit.normal == .zero)
  }
}
