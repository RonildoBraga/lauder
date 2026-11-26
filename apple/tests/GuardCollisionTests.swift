import Testing
import simd

@testable import Lauder

struct GuardCollisionTests {
  @Test
  func aFastRollCannotTunnelThroughTheHull() {
    let start = SIMD2<Float>(-4, 0)
    let end = GuardCollision.resolve(start: start, delta: [8, 0], centre: .zero, radius: 1)
    #expect(end.x < -1 && end.x > -1.003 && end.y == 0)
    #expect(distance(from: .zero, to: start, end) >= 1)
  }

  @Test
  func movementAwayOrAlongATangentIsUnchanged() {
    for (start, delta) in [
      (SIMD2<Float>(-4, 3), SIMD2<Float>(8, 0)),
      ([1.002, 0], [0, 3]),
      ([1.002, 0], [2, 0]),
    ] {
      #expect(
        GuardCollision.resolve(start: start, delta: delta, centre: .zero, radius: 1) == start
          + delta)
    }
  }

  @Test
  func anObliqueApproachSlidesWithoutItsResolvedPathCrossingTheHull() {
    let start = SIMD2<Float>(-3, 0.2)
    let movement = SIMD2<Float>(5, 1)
    let end = GuardCollision.resolve(start: start, delta: movement, centre: .zero, radius: 1)
    #expect(end.y > start.y && end.x < (start + movement).x)
    #expect(distance(from: .zero, to: start, end) >= 1)
    #expect(simd_length(end) >= 1)
    #expect(GuardCollision.resolve(start: start, delta: movement, centre: .zero, radius: 1) == end)
    let shift = SIMD2<Float>(5, -7)
    let shifted = GuardCollision.resolve(
      start: start + shift, delta: movement, centre: shift, radius: 1)
    #expect(simd_distance(shifted, end + shift) < 0.00001)
  }

  @Test
  func anExistingOverlapCanEscapeWithoutBeingPushedThroughOtherScenery() {
    let start = SIMD2<Float>(0.8, 0)
    #expect(GuardCollision.resolve(start: start, delta: .zero, centre: .zero, radius: 1) == start)
    #expect(
      GuardCollision.resolve(start: start, delta: [-1, 0], centre: .zero, radius: 1) == start)
    #expect(
      GuardCollision.resolve(start: start, delta: [1, 0], centre: .zero, radius: 1) == [1.8, 0])
    let escaping = GuardCollision.resolve(
      start: start, delta: [-0.2, 0.5], centre: .zero, radius: 1)
    #expect(escaping == [0.8, 0.5] && simd_length(escaping) > simd_length(start))
    #expect(
      GuardCollision.resolve(start: .zero, delta: [0.1, 0], centre: .zero, radius: 1) == [0.1, 0])
  }

  @Test
  func invalidInputsCannotMoveTheBody() {
    let start = SIMD2<Float>(3, 0)
    for delta: SIMD2<Float> in [[.infinity, 0], [0, .nan]] {
      #expect(GuardCollision.resolve(start: start, delta: delta, centre: .zero, radius: 1) == start)
    }
    for radius: Float in [0, -1, .nan, .infinity] {
      #expect(
        GuardCollision.resolve(start: start, delta: [-5, 0], centre: .zero, radius: radius) == start
      )
    }
  }

  private func distance(from point: SIMD2<Float>, to start: SIMD2<Float>, _ end: SIMD2<Float>)
    -> Float
  {
    let delta = end - start
    let time =
      simd_length_squared(delta) > 0
      ? max(0, min(1, simd_dot(point - start, delta) / simd_length_squared(delta))) : 0
    return simd_distance(point, start + delta * time)
  }
}
