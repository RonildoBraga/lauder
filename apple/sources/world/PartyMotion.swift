import simd

/// Continuous circular-footprint motion against the prototype's flat, axis-aligned scenery.
struct PartyMotion {
  struct Box: Sendable {
    let minimum: SIMD2<Float>
    let maximum: SIMD2<Float>

    func contains(_ point: SIMD2<Float>) -> Bool {
      point.x >= minimum.x && point.x <= maximum.x && point.y >= minimum.y
        && point.y <= maximum.y
    }
  }

  static let skin: Float = 0.002
  private typealias Vector = SIMD2<Double>

  private struct Bounds {
    let minimum: Vector
    let maximum: Vector
  }

  private struct Hit {
    let fraction: Double
    let normal: Vector
  }

  // Float body transforms can round a contact by a fraction of a micrometre. This margin
  // assumes the current layout, whose coordinates stay below 16 m; Float spacing doubles
  // beyond that, so a larger level should revisit both tolerances.
  private static let clearanceTolerance = 0.000001
  private static let arithmeticTolerance = 0.000000000001
  private let obstacles: [Bounds]
  private let radius: Double

  init(radius: Float, obstacles: [Box]) {
    precondition(radius.isFinite && radius > 0)
    precondition(
      obstacles.allSatisfy {
        Self.finite($0.minimum) && Self.finite($0.maximum)
          && $0.minimum.x < $0.maximum.x && $0.minimum.y < $0.maximum.y
      })
    self.radius = Double(radius) + Double(Self.skin)
    self.obstacles = obstacles.map {
      Bounds(minimum: Self.precise($0.minimum), maximum: Self.precise($0.maximum))
    }
  }

  func resolve(start: SIMD2<Float>, delta: SIMD2<Float>) -> SIMD2<Float> {
    guard Self.finite(start), Self.finite(delta), Self.finite(start + delta),
      simd_length_squared(delta) > 0
    else { return start }
    let origin = Self.precise(start)
    let movement = Self.precise(delta)
    let end = origin + movement
    guard let first = hit(from: origin, delta: movement, radius: radius) else {
      return start + delta
    }
    let contact = origin + movement * first.fraction
    let remaining = end - contact
    let slide = remaining - first.normal * min(0, simd_dot(remaining, first.normal))
    let second = hit(from: contact, delta: slide, radius: radius)
    let candidate = contact + slide * (second?.fraction ?? 1)

    // Positions are recorded as straight start→end steps (the leader's route memory), not as
    // the two movement legs. A slide around one box must not imply a cut through another.
    let connector = hit(from: origin, delta: candidate - origin, radius: radius)
    let result =
      connector.map { $0.fraction < 1 - Self.arithmeticTolerance } == true
      ? contact : candidate
    return [Float(result.x), Float(result.y)]
  }

  /// Full straight-segment clearance, with no sliding or start-overlap recovery.
  func canTraverse(from start: SIMD2<Float>, to end: SIMD2<Float>) -> Bool {
    guard Self.finite(start), Self.finite(end) else { return false }
    let origin = Self.precise(start)
    let destination = Self.precise(end)
    let clearance = radius - Self.clearanceTolerance
    guard
      obstacles.allSatisfy({
        separation(at: origin, from: $0).distance >= clearance
          && separation(at: destination, from: $0).distance >= clearance
      })
    else { return false }
    guard let collision = hit(from: origin, delta: destination - origin, radius: clearance) else {
      return true
    }
    return collision.fraction >= 1 - Self.arithmeticTolerance
  }

  private func hit(from start: Vector, delta: Vector, radius: Double) -> Hit? {
    let lengthSquared = simd_length_squared(delta)
    guard lengthSquared > 0 else { return nil }
    var nearest: Hit?
    func consider(_ fraction: Double, normal: Vector) {
      guard fraction >= -Self.arithmeticTolerance,
        fraction <= 1 + Self.arithmeticTolerance,
        simd_dot(delta, normal) < -Self.arithmeticTolerance
      else { return }
      let fraction = min(max(fraction, 0), 1)
      if nearest == nil || fraction < nearest!.fraction {
        nearest = Hit(fraction: fraction, normal: normal)
      }
    }

    for box in obstacles {
      let initial = separation(at: start, from: box)
      if initial.distance <= radius + Self.arithmeticTolerance {
        // The distance to this convex obstacle cannot decrease along an outward or
        // tangent ray. Allow that escape, but still check every other obstacle. No snap
        // or idle depenetration changes a member's recorded position.
        consider(0, normal: initial.normal)
        continue
      }

      // Offset faces cover their original spans. The remaining Minkowski boundary is
      // four quarter circles; an expanded square would incorrectly block corner gaps.
      for axis in 0..<2 {
        let other = 1 - axis
        guard delta[axis] != 0 else { continue }
        for sign: Double in [-1, 1] {
          let face = sign < 0 ? box.minimum[axis] - radius : box.maximum[axis] + radius
          let fraction = (face - start[axis]) / delta[axis]
          let across = start[other] + delta[other] * fraction
          if across >= box.minimum[other] && across <= box.maximum[other] {
            var normal = Vector.zero
            normal[axis] = sign
            consider(fraction, normal: normal)
          }
        }
      }
      for xSign: Double in [-1, 1] {
        for ySign: Double in [-1, 1] {
          let centre = Vector(
            xSign < 0 ? box.minimum.x : box.maximum.x,
            ySign < 0 ? box.minimum.y : box.maximum.y)
          let offset = start - centre
          let b = simd_dot(offset, delta)
          let c = simd_length_squared(offset) - radius * radius
          let discriminant = b * b - lengthSquared * c
          guard discriminant >= 0 else { continue }
          let fraction = (-b - sqrt(discriminant)) / lengthSquared
          let radial = start + delta * fraction - centre
          guard radial.x * xSign >= -Self.arithmeticTolerance,
            radial.y * ySign >= -Self.arithmeticTolerance
          else { continue }
          let length = simd_length(radial)
          guard length > 0 else { continue }
          consider(fraction, normal: radial / length)
        }
      }
    }
    return nearest
  }

  private func separation(at point: Vector, from box: Bounds)
    -> (distance: Double, normal: Vector)
  {
    let closest = Vector(
      min(max(point.x, box.minimum.x), box.maximum.x),
      min(max(point.y, box.minimum.y), box.maximum.y))
    let offset = point - closest
    let length = simd_length(offset)
    if length > 0 { return (length, offset / length) }

    // Inside a box, choose the nearest exit face. Moving toward it is possible even
    // from an externally supplied overlapping position; inward motion stays blocked.
    let faces: [(Double, Vector)] = [
      (point.x - box.minimum.x, [-1, 0]), (box.maximum.x - point.x, [1, 0]),
      (point.y - box.minimum.y, [0, -1]), (box.maximum.y - point.y, [0, 1]),
    ]
    let nearest = faces.min { $0.0 < $1.0 }!
    return (-nearest.0, nearest.1)
  }

  private static func precise(_ point: SIMD2<Float>) -> Vector {
    [Double(point.x), Double(point.y)]
  }

  private static func finite(_ point: SIMD2<Float>) -> Bool {
    point.x.isFinite && point.y.isFinite
  }
}
