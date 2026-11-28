import simd

@testable import Lauder

/// Historical collision-regression geometry only, independent of retired level/party policy.
enum TestYard {
  static let cameraOffset: SIMD3<Float> = [5.25, 10, 8.4]
  static let obstacles: [PartyMotion.Box] = [
    box([0, 9.7], [28, 0.6]), box([0, -9.7], [28, 0.6]),
    box([-13.7, 0], [0.6, 20]), box([13.7, 0], [0.6, 20]),
    box([-9, 0], [7, 0.35]), box([-12.3, 2.5], [0.35, 5]),
    box([-1.5, 1], [2.5, 1.2]), box([1, -2], [1.2, 2.5]),
    box([7, -7], [6.4, 0.35]), box([10, -4], [0.35, 6]),
    box([4, -6.2], [0.35, 1.6]), box([4, -2.3], [0.35, 2.6]),
    box([5, -1], [2, 0.35]), box([9, -1], [2, 0.35]),
    box([7, -0.7], [2.2, 1]), box([-10, 1.5], [0.8, 0.6]),
    box([7, -4.5], [0.5, 0.5]),
  ]

  private static func box(_ centre: SIMD2<Float>, _ size: SIMD2<Float>) -> PartyMotion.Box {
    .init(minimum: centre - size / 2, maximum: centre + size / 2)
  }
}
