import simd

/// One walkable height at each ground point. Terraces join through authored ramps; there are
/// no stacked floors, jumping or falling. An empty terrain keeps the existing flat levels.
struct Terrain: Equatable, Sendable {
  struct Patch: Equatable, Sendable {
    enum Axis: Equatable, Sendable { case x, z }

    let minimum: SIMD2<Float>
    let maximum: SIMD2<Float>
    let axis: Axis
    let from: Float
    let to: Float

    static func flat(minimum: SIMD2<Float>, maximum: SIMD2<Float>, height: Float) -> Self {
      ramp(minimum: minimum, maximum: maximum, axis: .x, from: height, to: height)
    }

    /// `from` lies on the minimum-axis edge and `to` on the maximum-axis edge.
    static func ramp(
      minimum: SIMD2<Float>, maximum: SIMD2<Float>, axis: Axis, from: Float, to: Float
    ) -> Self {
      precondition(
        minimum.x.isFinite && minimum.y.isFinite && maximum.x.isFinite && maximum.y.isFinite
          && minimum.x < maximum.x && minimum.y < maximum.y && from.isFinite && to.isFinite)
      return Self(minimum: minimum, maximum: maximum, axis: axis, from: from, to: to)
    }

    fileprivate func contains(_ point: SIMD2<Float>) -> Bool {
      point.x >= minimum.x && point.x <= maximum.x && point.y >= minimum.y
        && point.y <= maximum.y
    }

    fileprivate func height(at point: SIMD2<Float>) -> Float {
      let distance = axis == .x ? maximum.x - minimum.x : maximum.y - minimum.y
      let offset = axis == .x ? point.x - minimum.x : point.y - minimum.y
      return from + (to - from) * min(1, max(0, offset / distance))
    }
  }

  let patches: [Patch]
  private let xEdges: [Float]
  private let zEdges: [Float]

  init(patches: [Patch] = []) {
    self.patches = patches
    xEdges = Array(Set(patches.flatMap { [$0.minimum.x, $0.maximum.x] })).sorted()
    zEdges = Array(Set(patches.flatMap { [$0.minimum.y, $0.maximum.y] })).sorted()
  }

  /// Later patches take precedence where authored rectangles overlap. Outside them is y = 0.
  func height(at point: SIMD2<Float>) -> Float {
    patch(at: point)?.height(at: point) ?? 0
  }

  /// Thin, solid cliff edges join the ordinary collision footprints. The existing swept-body
  /// resolver and navigation grid then agree about the only traversable entrances: ramp ends.
  var cliffs: [PartyMotion.Box] {
    guard !patches.isEmpty else { return [] }
    let xs = xEdges
    let zs = zEdges
    let halfWidth: Float = 0.001
    let sample: Float = 0.0001
    var result: [PartyMotion.Box] = []
    for x in xs {
      for (low, high) in zip(zs, zs.dropFirst()) {
        let middle = (low + high) / 2
        let left = patch(at: [x - sample, middle])
        let right = patch(at: [x + sample, middle])
        if differs(left, right, at: [x, low], and: [x, high]) {
          result.append(.init(minimum: [x - halfWidth, low], maximum: [x + halfWidth, high]))
        }
      }
    }
    for z in zs {
      for (low, high) in zip(xs, xs.dropFirst()) {
        let middle = (low + high) / 2
        let near = patch(at: [middle, z - sample])
        let far = patch(at: [middle, z + sample])
        if differs(near, far, at: [low, z], and: [high, z]) {
          result.append(.init(minimum: [low, z - halfWidth], maximum: [high, z + halfWidth]))
        }
      }
    }
    return result
  }

  /// The first point where a finite segment meets the bounded solid ground, as a fraction of
  /// its length. Splitting at patch boundaries handles ramp planes and vertical risers exactly.
  /// Nothing outside the playable floor counts as terrain.
  func firstIntersection(
    from start: SIMD3<Float>, to end: SIMD3<Float>, within bounds: PartyMotion.Box
  ) -> Float? {
    let delta = end - start
    guard start.x.isFinite, start.y.isFinite, start.z.isFinite,
      end.x.isFinite, end.y.isFinite, end.z.isFinite
    else { return nil }
    var low: Float = 0
    var high: Float = 1
    for (origin, travel, minimum, maximum) in [
      (start.x, delta.x, bounds.minimum.x, bounds.maximum.x),
      (start.z, delta.z, bounds.minimum.y, bounds.maximum.y),
    ] {
      if abs(travel) < 0.000001 {
        if origin < minimum || origin > maximum { return nil }
      } else {
        let first = (minimum - origin) / travel
        let last = (maximum - origin) / travel
        low = max(low, min(first, last))
        high = min(high, max(first, last))
      }
    }
    guard low <= high else { return nil }
    var cuts = [low, high]
    if abs(delta.x) > 0.000001 {
      for x in xEdges {
        let cut = (x - start.x) / delta.x
        if cut > low && cut < high { cuts.append(cut) }
      }
    }
    if abs(delta.z) > 0.000001 {
      for z in zEdges {
        let cut = (z - start.z) / delta.z
        if cut > low && cut < high { cuts.append(cut) }
      }
    }
    cuts = Array(Set(cuts)).sorted()
    // A vertical segment, or a segment touching only a floor-boundary point, has no interval.
    if cuts.count == 1 {
      let point = start + delta * low
      return point.y <= height(at: [point.x, point.z]) ? low : nil
    }
    for (first, last) in zip(cuts, cuts.dropFirst()) {
      let middle = start + delta * ((first + last) / 2)
      let surface = patch(at: [middle.x, middle.z])
      func clearance(_ time: Float) -> Float {
        let point = start + delta * time
        return point.y - (surface?.height(at: [point.x, point.z]) ?? 0)
      }
      let before = clearance(first)
      let after = clearance(last)
      if before <= 0 { return first }
      if after <= 0 { return first + (last - first) * before / (before - after) }
    }
    let final = start + delta * high
    if final.y <= height(at: [final.x, final.z]) { return high }
    return nil
  }

  /// Break lines for the bounded render mesh; cells never cross a patch edge.
  func divisions(in bounds: PartyMotion.Box) -> (x: [Float], z: [Float]) {
    let xs = xEdges
    let zs = zEdges
    return (
      Array(
        Set(
          [bounds.minimum.x, bounds.maximum.x]
            + xs.filter {
              $0 > bounds.minimum.x && $0 < bounds.maximum.x
            })
      ).sorted(),
      Array(
        Set(
          [bounds.minimum.y, bounds.maximum.y]
            + zs.filter {
              $0 > bounds.minimum.y && $0 < bounds.maximum.y
            })
      ).sorted()
    )
  }

  /// Use the patch chosen inside a tile when evaluating its edge: adjacent sides of a cliff
  /// need separate vertices even when their x/z coordinates coincide.
  func height(at point: SIMD2<Float>, inTileContaining middle: SIMD2<Float>) -> Float {
    patch(at: middle)?.height(at: point) ?? 0
  }

  private func patch(at point: SIMD2<Float>) -> Patch? {
    patches.last { $0.contains(point) }
  }

  private func differs(
    _ first: Patch?, _ second: Patch?, at start: SIMD2<Float>, and end: SIMD2<Float>
  ) -> Bool {
    [start, end].contains {
      abs((first?.height(at: $0) ?? 0) - (second?.height(at: $0) ?? 0)) > 0.0001
    }
  }
}
