import Testing
import simd

@testable import Lauder

struct PartyMotionTests {
  private let wall = PartyMotion.Box(minimum: [0, -100], maximum: [1, 100])
  private let radius: Float = 0.26

  @Test
  func unobstructedMotionAndInvalidInputStayPredictable() {
    let motion = PartyMotion(radius: radius, obstacles: [])
    #expect(motion.resolve(start: [2, 3], delta: [0.2, -0.1]) == [2.2, 2.9])
    for delta: SIMD2<Float> in [.zero, [.nan, 0], [0, .infinity]] {
      #expect(motion.resolve(start: [2, 3], delta: delta) == [2, 3])
    }
    #expect(!motion.canTraverse(from: [.nan, 0], to: .zero))
  }

  @Test
  func headOnAndNoPhysicalHitEndpointsKeepNormalSkinClearance() {
    let motion = PartyMotion(radius: radius, obstacles: [wall])
    let headOn = motion.resolve(start: [-1, 0], delta: [2, 0])
    #expect(abs(headOn.x + radius + 0.002) < 0.000001)
    #expect(headOn.y == 0)
    // This destination is outside the physical circle but inside the clearance skin.
    let near = motion.resolve(start: [-0.27, 0], delta: [0.009, 0])
    #expect(abs(near.x + radius + 0.002) < 0.000001)
  }

  /// Far from the origin, a Float position rounds by up to half the Float spacing, about 15 µm
  /// 489 m out, so a contact there can sit a few micrometres inside the clearance. Moving away
  /// from it stays allowed, as it is near the origin.
  @Test
  func aContactFarFromTheOriginCanStillMoveAway() {
    // A car near the bridge's Manhattan end.
    let car = PartyMotion.Box(minimum: [-10.8, -491.6], maximum: [-8.8, -487])
    let motion = PartyMotion(radius: radius, obstacles: [car])
    for x in stride(from: Float(-10.5), through: -9.1, by: 0.1) {
      let contact = motion.resolve(start: [x, -480], delta: [0, -10])
      #expect(abs(contact.y + 487 - radius - 0.002) < 0.0001, "stopped at the car, x = \(x)")
      #expect(motion.canTraverse(from: contact, to: contact + [0, 1]), "moving away, x = \(x)")
    }
  }

  @Test(arguments: [Float(0.5), 2.5, 13, 30])
  func grazingAlongAWallRetainsNormalClearanceAndNeverFreezes(degrees: Float) {
    let motion = PartyMotion(radius: radius, obstacles: [wall])
    let angle = degrees * .pi / 180
    let delta = SIMD2(sin(angle), cos(angle)) * (2.6 / 60)
    var position = SIMD2<Float>(-0.35, -10)
    for _ in 0..<800 {
      let previous = position
      position = motion.resolve(start: position, delta: delta)
      #expect(-position.x >= radius + 0.002 - 0.000001)
      #expect(motion.canTraverse(from: previous, to: position))
    }
    #expect(position.y > 15)
    #expect(motion.resolve(start: position, delta: [-0.04, 0]).x < position.x)
  }

  @Test
  func touchingAndOverlappingStartsCanEscapeWithoutAnIdleSnap() {
    let motion = PartyMotion(radius: radius, obstacles: [wall])
    for start: SIMD2<Float> in [[-0.262, 0], [-0.2601, 0], [-0.25, 0]] {
      #expect(motion.resolve(start: start, delta: .zero) == start)
      let outward = motion.resolve(start: start, delta: [-0.05, 0])
      #expect(abs(outward.x - (start.x - 0.05)) < 0.000001)
      #expect(outward.y == 0)
      #expect(motion.resolve(start: start, delta: [0.05, 0]) == start)
      let tangent = motion.resolve(start: start, delta: [0, 0.05])
      #expect(simd_distance(tangent, start + [0, 0.05]) < 0.000001)
    }
    #expect(!motion.canTraverse(from: [-0.25, 0], to: [-1, 0]))
  }

  @Test
  func recoveryStillChecksTheOtherObstacles() {
    let motion = PartyMotion(
      radius: radius,
      obstacles: [wall, .init(minimum: [-0.9, -1], maximum: [-0.7, 1])])
    let position = motion.resolve(start: [-0.2601, 0], delta: [-1, 0])
    #expect(position.x >= -0.7 + radius + 0.002 - 0.000001)
    #expect(position.x < -0.2601)
  }

  @Test
  func theRoundedCornerDoesNotBecomeAnExpandedSquare() {
    let motion = PartyMotion(
      radius: radius, obstacles: [.init(minimum: .zero, maximum: [1, 1])])
    let start = SIMD2<Float>(-0.25, -0.2)
    let end = SIMD2<Float>(-0.2, -0.25)
    #expect(motion.canTraverse(from: start, to: end))
    #expect(simd_distance(motion.resolve(start: start, delta: end - start), end) < 0.000001)

    let radial = motion.resolve(start: [-1, -1], delta: [2, 2])
    #expect(abs(simd_length(radial) - radius - 0.002) < 0.000001)
    #expect(abs(radial.x - radial.y) < 0.000001)
    #expect(radial.x < 0)
    #expect(!motion.canTraverse(from: start, to: [0.5, 0.5]))
  }

  @Test
  func continuousMotionCannotTunnelThroughAThinBox() {
    let motion = PartyMotion(
      radius: radius, obstacles: [.init(minimum: [0, -1], maximum: [0.001, 1])])
    let end = motion.resolve(start: [-2, 0], delta: [4, 0])
    #expect(abs(end.x + radius + 0.002) < 0.000001)
    #expect(!motion.canTraverse(from: [-2, 0], to: [2, 0]))
  }

  @Test
  func aSecondWallStopsTheSlide() {
    let motion = PartyMotion(
      radius: radius,
      obstacles: [wall, .init(minimum: [-100, 1], maximum: [100, 2])])
    let end = motion.resolve(start: [-1, 0], delta: [2, 2])
    #expect(abs(end.x + radius + 0.002) < 0.000001)
    #expect(abs(end.y - (1 - radius - 0.002)) < 0.000001)
    #expect(motion.canTraverse(from: [-1, 0], to: end))
  }

  @Test
  func aSlideCannotRecordAChordThroughAnotherBox() {
    let motion = PartyMotion(
      radius: radius,
      obstacles: [
        .init(minimum: [0, -1], maximum: [1, 3]),
        .init(minimum: [-1.1, 2.2], maximum: [-0.9, 2.4]),
      ])
    let start = SIMD2<Float>(-2, 0)
    let end = motion.resolve(start: start, delta: [4, 4])
    // The two-leg route could reach this slide endpoint, but its recorded chord is blocked.
    #expect(!motion.canTraverse(from: start, to: [-0.262, 4]))
    #expect(simd_distance(end, [-0.262, 1.738]) < 0.00001)
    #expect(motion.canTraverse(from: start, to: end))
  }

  @Test(arguments: [
    SIMD2<Float>(-10.888096, 9.139913), [-10.890598, -9.139953],
    [-10.886109, -9.139682], [13.139972, 7.777336], [-13.139841, 7.780174],
    [-2.4376667, 1.8600595], [7.8554177, 0.060019918], [9.618896, -7.4354496],
  ])
  func everyReportedFrozenPositionHasAnOutwardEscape(start: SIMD2<Float>) {
    let motion = PartyMotion(radius: PartyBody.radius, obstacles: TestYard.obstacles)
    var escapes = 0
    for index in 0..<16 {
      let angle = Float(index) * .pi / 8
      let delta = SIMD2(cos(angle), sin(angle)) * (2.6 / 60)
      let end = motion.resolve(start: start, delta: delta)
      #expect(simd_distance(start, end) <= simd_length(delta) + 0.000001)
      if simd_distance(start, end) > 0.00001 { escapes += 1 }
      for box in TestYard.obstacles {
        let closest = SIMD2(
          min(max(end.x, box.minimum.x), box.maximum.x),
          min(max(end.y, box.minimum.y), box.maximum.y))
        #expect(simd_distance(end, closest) >= radius - 0.00001)
      }
    }
    #expect(escapes > 0)
  }
}
