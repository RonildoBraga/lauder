import simd

/// A few local routes around existing solids, always checked at the whole machine's radius.
/// This does not use the companion grid's much smaller clearance or invent cover geometry.
struct RobotTactics {
  struct Cover {
    let position: SIMD2<Float>
    let peek: SIMD2<Float>
    let route: [SIMD2<Float>]
  }

  let area: PartyMotion.Box
  let obstacles: [PartyMotion.Box]
  let boxes: [Level.Box]
  private var clearance: Float { RobotModelGeometry.navigationRadius + 0.08 }
  private var mover: PartyMotion {
    PartyMotion(radius: RobotModelGeometry.navigationRadius, obstacles: obstacles)
  }

  func bounded(_ point: SIMD2<Float>) -> SIMD2<Float> {
    simd_min(area.maximum, simd_max(area.minimum, point))
  }

  func legal(_ point: SIMD2<Float>) -> Bool {
    area.contains(point) && mover.canTraverse(from: point, to: point)
  }

  /// The bridge has only a few piers. A tiny visibility graph is enough to get around their
  /// corners without a second grid or allowing a large robot through a person-sized gap.
  func route(from start: SIMD2<Float>, to goal: SIMD2<Float>) -> [SIMD2<Float>]? {
    guard legal(start), legal(goal) else { return nil }
    if mover.canTraverse(from: start, to: goal) { return [goal] }
    var nodes = [start, goal]
    for box in obstacles {
      for x in [box.minimum.x - clearance, box.maximum.x + clearance] {
        for y in [box.minimum.y - clearance, box.maximum.y + clearance] {
          let point = SIMD2(x, y)
          if legal(point) { nodes.append(point) }
        }
      }
    }
    var costs = [Float](repeating: .infinity, count: nodes.count)
    var previous = [Int](repeating: -1, count: nodes.count)
    var visited = [Bool](repeating: false, count: nodes.count)
    costs[0] = 0
    for _ in nodes.indices {
      guard
        let current = nodes.indices.filter({ !visited[$0] }).min(by: {
          costs[$0] < costs[$1]
        }), costs[current].isFinite
      else { break }
      if current == 1 { break }
      visited[current] = true
      for next in nodes.indices where !visited[next] && next != current {
        let cost = costs[current] + simd_distance(nodes[current], nodes[next])
        if cost < costs[next], mover.canTraverse(from: nodes[current], to: nodes[next]) {
          costs[next] = cost
          previous[next] = current
        }
      }
    }
    guard costs[1].isFinite else { return nil }
    var path = [goal]
    var current = 1
    while previous[current] != 0 {
      current = previous[current]
      guard current >= 0 else { return nil }
      path.append(nodes[current])
    }
    return path.reversed()
  }

  /// A remembered actor may stand where this much larger machine cannot. Approach a legal
  /// nearby place; never teleport to a projected point or route through a blocked segment.
  func approach(from start: SIMD2<Float>, towards requested: SIMD2<Float>)
    -> [SIMD2<Float>]?
  {
    let goal = bounded(requested)
    if let path = route(from: start, to: goal) { return path }
    var candidates: [SIMD2<Float>] = []
    for radius: Float in [0.5, 1.5, 3, 4.5] {
      for index in 0..<12 {
        let angle = Float(index) * 2 * .pi / 12
        candidates.append(bounded(goal + SIMD2(cos(angle), sin(angle)) * radius))
      }
    }
    for point in candidates.sorted(by: {
      simd_distance_squared($0, goal) < simd_distance_squared($1, goal)
    }) {
      if let path = route(from: start, to: point) { return path }
    }
    return nil
  }

  func cover(from start: SIMD2<Float>, against threat: SIMD2<Float>) -> Cover? {
    var best: (cost: Float, cover: Cover)?
    for box in boxes
    where box.position.y + box.size.y / 2 >= 2 * RobotModelGeometry.halfHeight + 0.1 {
      let footprint = box.footprint
      for fraction: Float in [0.05, 0.25, 0.5, 0.75, 0.95] {
        let along = footprint.minimum + (footprint.maximum - footprint.minimum) * fraction
        let candidates: [SIMD2<Float>] = [
          [along.x, footprint.minimum.y - clearance],
          [along.x, footprint.maximum.y + clearance],
          [footprint.minimum.x - clearance, along.y],
          [footprint.maximum.x + clearance, along.y],
        ]
        for point in candidates where simd_distance(point, start) > 0.5 {
          guard legal(point), isCovered(point, against: threat),
            let path = route(from: start, to: point),
            let peek = peek(from: point, towards: threat)
          else { continue }
          let cost = pathLength(path, from: start) + simd_distance(point, peek) * 0.2
          if best == nil || cost < best!.cost {
            best = (cost, Cover(position: point, peek: peek, route: path))
          }
        }
      }
    }
    return best?.cover
  }

  /// Both the tall body silhouette and the guns must actually be hidden by real 3D solids.
  /// A low obstacle or a blocked centre ray alone does not protect this large machine.
  func isCovered(_ point: SIMD2<Float>, against threat: SIMD2<Float>) -> Bool {
    let delta = threat - point
    guard simd_length_squared(delta) > 0.01 else { return false }
    let side = simd_normalize(SIMD2(-delta.y, delta.x)) * RobotModelGeometry.bodyRadius
    let top = 2 * RobotModelGeometry.halfHeight + 0.1
    let samples: [SIMD3<Float>] =
      [
        [point.x, RobotModelGeometry.halfHeight, point.y],
        [point.x, top, point.y],
        [point.x + side.x, top, point.y + side.y],
        [point.x - side.x, top, point.y - side.y],
      ] + gunPoints(at: point, towards: threat)
    return samples.allSatisfy { !clear(from: [threat.x, 1.25, threat.y], to: $0) }
  }

  private func peek(from point: SIMD2<Float>, towards threat: SIMD2<Float>) -> SIMD2<Float>? {
    var candidates: [SIMD2<Float>] = []
    for radius: Float in [1, 2, 3, 4, 5] {
      for index in 0..<16 {
        let angle = Float(index) * 2 * .pi / 16
        candidates.append(point + SIMD2(cos(angle), sin(angle)) * radius)
      }
    }
    return candidates.first {
      legal($0)
        && simd_distance($0, threat) <= RobotGuard.detectionRange
        && gunPoints(at: $0, towards: threat).allSatisfy {
          clear(from: $0, to: [threat.x, 1.25, threat.y])
        }
        && route(from: point, to: $0) != nil
    }
  }

  private func gunPoints(at point: SIMD2<Float>, towards threat: SIMD2<Float>) -> [SIMD3<Float>] {
    let yaw = Movement.yaw(towards: threat - point)
    return RobotModelGeometry.muzzles.map {
      SIMD3(
        point.x + cos(yaw) * $0.x + sin(yaw) * $0.z, $0.y,
        point.y - sin(yaw) * $0.x + cos(yaw) * $0.z)
    }
  }

  private func clear(from start: SIMD3<Float>, to end: SIMD3<Float>) -> Bool {
    !boxes.contains {
      if let entry = LineOfSight.entry(
        from: start, along: end - start, minimum: $0.position - $0.size / 2,
        maximum: $0.position + $0.size / 2, limit: 1)
      {
        return entry < 0.9999
      }
      return false
    }
  }

  private func pathLength(_ points: [SIMD2<Float>], from start: SIMD2<Float>) -> Float {
    zip([start] + points, points).reduce(0) { $0 + simd_distance($1.0, $1.1) }
  }
}
