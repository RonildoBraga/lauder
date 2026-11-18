import simd

/// The leader's last few metres of travel, newest last. Column slots and the narrow-place
/// fallback are placed on it (ADR 0003); companions still steer to those points themselves.
struct RouteMemory {
  static let spacing: Float = 0.05
  static let maximumLength: Float = 6

  private(set) var points: [SIMD2<Float>]

  init(start: SIMD2<Float>) {
    points = [start]
  }

  mutating func reset(to position: SIMD2<Float>) {
    points = [position]
  }

  mutating func record(_ position: SIMD2<Float>) {
    guard position.x.isFinite, position.y.isFinite else { return }
    guard let last = points.last, simd_distance(last, position) >= Self.spacing else { return }
    // After a reversal the old route lies ahead of the leader, so it would put companions in
    // the leader's way. Start again from the turning point.
    if points.count >= 2 {
      let before = last - points[points.count - 2]
      let after = position - last
      if simd_dot(before, after) < -0.5 * simd_length(before) * simd_length(after) {
        points = [last]
      }
    }
    points.append(position)
    var length: Float = 0
    var keep = points.count - 1
    while keep > 0 && length < Self.maximumLength {
      length += simd_distance(points[keep], points[keep - 1])
      keep -= 1
    }
    if keep > 0 { points.removeFirst(keep) }
  }

  /// The point `distance` back along the route from `current`, or nil if the route is shorter.
  func point(back distance: Float, from current: SIMD2<Float>) -> SIMD2<Float>? {
    var remaining = distance
    var ahead = current
    for point in points.reversed() {
      let segment = simd_distance(ahead, point)
      if segment >= remaining, segment > 0 {
        return ahead + (point - ahead) * (remaining / segment)
      }
      remaining -= segment
      ahead = point
    }
    return nil
  }
}
