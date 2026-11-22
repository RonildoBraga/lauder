import simd

/// Shared straight shots through the actual world heights. Target assistance still chooses
/// a direction in the ground plane; this query decides what that direction really strikes.
struct Ballistics {
  struct Target {
    let id: String
    let centre: SIMD3<Float>
    var halfHeight: Float = 0.6
    var radius: Float = Aim.bodyRadius
  }

  struct Trace {
    let start: SIMD3<Float>
    let end: SIMD3<Float>
    let strike: ShotPath.Strike

    var path: ShotPath {
      ShotPath(start: [start.x, start.z], end: [end.x, end.z], strike: strike)
    }
  }

  private let boxes: [Level.Box]
  let terrain: Terrain
  private let bounds: PartyMotion.Box
  var gate: PartyMotion.Box?

  init(level: Level) {
    boxes = level.boxes
    terrain = level.terrain
    bounds = level.bounds
  }

  func point(_ point: SIMD2<Float>, above height: Float = 1.25)
    -> SIMD3<Float>
  {
    [point.x, terrain.height(at: point) + height, point.y]
  }

  func isClear(from start: SIMD3<Float>, to end: SIMD3<Float>, ignoringLowCover: Bool = false)
    -> Bool
  {
    firstBlock(from: start, to: end, ignoringLowCover: ignoringLowCover).map { $0 >= 0.9999 }
      ?? true
  }

  /// Fired rounds cross this level until they meet a real solid/body or leave its ground
  /// bounds. Target assistance and an actor's decision to fire keep their own shorter reach.
  /// The nonphysical map edge produces no impact, and no fixed distance truncates a long map.
  func traceAcrossLevel(
    from start: SIMD3<Float>, direction: SIMD3<Float>, targets: [Target]
  ) -> Trace {
    guard start.indices.allSatisfy({ start[$0].isFinite }),
      direction.indices.allSatisfy({ direction[$0].isFinite }),
      simd_length_squared(direction).isFinite, simd_length_squared(direction) > 0.000001,
      bounds.contains([start.x, start.z])
    else { return trace(from: start, direction: direction, range: 0, targets: []) }
    let unit = simd_normalize(direction)
    var reach = Float.infinity
    for (axis, floorAxis) in [(0, 0), (2, 1)] where abs(unit[axis]) > 0.000001 {
      let edge = unit[axis] > 0 ? bounds.maximum[floorAxis] : bounds.minimum[floorAxis]
      reach = min(reach, (edge - start[axis]) / unit[axis])
    }
    // Every supported weapon has a ground-plane heading. A purely vertical ray has no
    // finite x/z exit; explicit vertical geometry queries use trace(range:) instead.
    guard reach.isFinite else {
      return trace(from: start, direction: direction, range: 0, targets: [])
    }
    return trace(from: start, direction: unit, range: reach, targets: targets)
  }

  func trace(
    from start: SIMD3<Float>, direction: SIMD3<Float>, range: Float, targets: [Target]
  ) -> Trace {
    guard range.isFinite, range > 0, start.indices.allSatisfy({ start[$0].isFinite }),
      direction.indices.allSatisfy({ direction[$0].isFinite }),
      simd_length_squared(direction).isFinite, simd_length_squared(direction) > 0.000001
    else {
      let safe = start.indices.allSatisfy({ start[$0].isFinite }) ? start : .zero
      return Trace(start: safe, end: safe, strike: .nothing)
    }
    let end = start + simd_normalize(direction) * range
    let block = firstBlock(from: start, to: end)
    var distance = block ?? 1
    var strike: ShotPath.Strike = block != nil ? .scenery : .nothing
    for target in targets.sorted(by: { $0.id < $1.id }) {
      if let entry = Self.entry(from: start, to: end, target: target),
        entry < distance || (entry == distance && strike == .nothing)
      {
        distance = entry
        strike = .body(target.id)
      }
    }
    return Trace(start: start, end: start + (end - start) * distance, strike: strike)
  }

  private func firstBlock(
    from start: SIMD3<Float>, to end: SIMD3<Float>, ignoringLowCover: Bool = false
  ) -> Float? {
    var first = terrain.firstIntersection(from: start, to: end, within: bounds)
    for box in boxes {
      if ignoringLowCover,
        box.position.y + box.size.y / 2 - terrain.height(at: [box.position.x, box.position.z])
          < LeaderCover.lowHeight
      {
        continue
      }
      if let entry = LineOfSight.entry(
        from: start, along: end - start, minimum: box.position - box.size / 2,
        maximum: box.position + box.size / 2, limit: 1)
      {
        first = min(first ?? 1, entry)
      }
    }
    if let gate {
      let centre = (gate.minimum + gate.maximum) / 2
      let base = terrain.height(at: centre)
      if let entry = LineOfSight.entry(
        from: start, along: end - start,
        minimum: [gate.minimum.x, base, gate.minimum.y],
        maximum: [gate.maximum.x, base + 3, gate.maximum.y], limit: 1)
      {
        first = min(first ?? 1, entry)
      }
    }
    return first
  }

  /// Cylinder intersection preserves the existing circular ground-plane hit radius, while
  /// rejecting a shot that passes above or below a body on another tier or behind low cover.
  private static func entry(from start: SIMD3<Float>, to end: SIMD3<Float>, target: Target)
    -> Float?
  {
    let delta = end - start
    let offset = SIMD2(start.x - target.centre.x, start.z - target.centre.z)
    let across = SIMD2(delta.x, delta.z)
    let a = simd_dot(across, across)
    let b = simd_dot(offset, across)
    let c = simd_dot(offset, offset) - target.radius * target.radius
    var near: Float = 0
    var far: Float = 1
    if a < 0.000001 {
      guard c <= 0 else { return nil }
    } else {
      let determinant = b * b - a * c
      guard determinant >= 0 else { return nil }
      near = max(near, (-b - sqrt(determinant)) / a)
      far = min(far, (-b + sqrt(determinant)) / a)
    }
    let bottom = target.centre.y - target.halfHeight
    let top = target.centre.y + target.halfHeight
    if abs(delta.y) < 0.000001 {
      guard start.y >= bottom, start.y <= top else { return nil }
    } else {
      let first = (bottom - start.y) / delta.y
      let second = (top - start.y) / delta.y
      near = max(near, min(first, second))
      far = min(far, max(first, second))
    }
    return near <= far ? near : nil
  }
}
