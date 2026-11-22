import simd

/// Cover at the leader's actual position (ADR 0009), rather than a place for the companion
/// planner to walk to. The fight owns exposure time; these queries use the same footprint for
/// an incoming shot, a shield's state and a valid outgoing peek.
struct LeaderCover {
  /// Maximum gap between the body's edge and a wall face.
  static let proximity: Float = 0.5
  /// How close along a tall face the body must be to an end before it can peek around it.
  static let edgeReach: Float = 0.6
  static let exposureSeconds: Float = 0.3
  static let lowHeight: Float = 1.25

  struct Shelter: Sendable {
    let boxID: String
    /// Out from the wall towards the body. A shield faces the opposite way, towards the wall.
    let normal: SIMD2<Float>
    let isLow: Bool
    fileprivate let index: Int
    fileprivate let axis: Int
    fileprivate let face: Float
    fileprivate let minimum: Float
    fileprivate let maximum: Float
  }

  private struct Block {
    let name: String
    let footprint: PartyMotion.Box
    let isLow: Bool
    let bottom: Float
    let top: Float
  }

  private let blocks: [Block]
  private let motion: PartyMotion
  private let ground: PartyMotion.Box?
  private let terrain: Terrain
  private static let tolerance: Float = 0.00001
  /// A little room outside a tall corner for the shoulder and the shot, beyond body clearance.
  private static let peekRoom: Float = 0.05

  init(boxes: [Level.Box], ground: PartyMotion.Box? = nil, terrain: Terrain = Terrain()) {
    blocks = boxes.map {
      Block(
        name: $0.name, footprint: $0.footprint,
        isLow: $0.position.y + $0.size.y / 2
          - terrain.height(at: [$0.position.x, $0.position.z]) < Self.lowHeight,
        bottom: $0.position.y - $0.size.y / 2, top: $0.position.y + $0.size.y / 2)
    }
    motion = PartyMotion(
      radius: PartyBody.radius, obstacles: boxes.map(\.footprint) + terrain.cliffs)
    self.ground = ground
    self.terrain = terrain
  }

  /// The nearest external face within reach. Ties prefer the face the leader faces into,
  /// then authored order, so standing still never alternates between equal candidates.
  func shelter(at point: SIMD2<Float>, facing: SIMD2<Float>) -> Shelter? {
    guard fits(point), finite(facing) else { return nil }
    var nearest: (shelter: Shelter, gap: Float, alignment: Float)?
    let floor = terrain.height(at: point)
    for (index, block) in blocks.enumerated() {
      // A low box on a different tier cannot become this body's shelter through the cliff.
      guard block.bottom <= floor + 0.15, block.top > floor + 0.1 else { continue }
      for axis in 0..<2 {
        let across = 1 - axis
        for sign: Float in [-1, 1] {
          var normal = SIMD2<Float>.zero
          normal[axis] = sign
          let candidate = Shelter(
            boxID: block.name, normal: normal, isLow: block.top - floor < Self.lowHeight,
            index: index, axis: axis,
            face: sign < 0 ? block.footprint.minimum[axis] : block.footprint.maximum[axis],
            minimum: block.footprint.minimum[across], maximum: block.footprint.maximum[across])
          guard isBeside(point, candidate) else { continue }
          let gap = (point[axis] - candidate.face) * sign - PartyBody.radius
          let alignment = simd_dot(facing, -normal)
          if nearest == nil || gap < nearest!.gap - Self.tolerance
            || (abs(gap - nearest!.gap) <= Self.tolerance && alignment > nearest!.alignment)
          {
            nearest = (candidate, gap, alignment)
          }
        }
      }
    }
    return nearest?.shelter
  }

  /// A shared origin for the exposed body and its weapon. Low cover raises in place. A tall
  /// wall needs no lean when the shot already clears it; otherwise only an end can provide a
  /// firing angle, with a whole-body route clear of every box and the floor's edge.
  func firingPoint(
    from point: SIMD2<Float>, in shelter: Shelter, facing: SIMD2<Float>
  ) -> SIMD2<Float>? {
    guard fits(point), isBeside(point, shelter), finite(facing),
      simd_length_squared(facing) > 0.000001,
      blocks.indices.contains(shelter.index), blocks[shelter.index].name == shelter.boxID
    else { return nil }
    if shelter.isLow { return point }
    let wall = blocks[shelter.index].footprint
    let direction = simd_normalize(facing)
    func clearsWall(_ origin: SIMD2<Float>) -> Bool {
      LineOfSight.entry(
        from: origin, along: direction, minimum: wall.minimum, maximum: wall.maximum,
        limit: .infinity) == nil
    }
    if clearsWall(point) { return point }
    let across = 1 - shelter.axis
    let ends: [(point: Float, sign: Float)] = [(shelter.minimum, -1), (shelter.maximum, 1)]
    let candidates = ends.sorted { abs(point[across] - $0.point) < abs(point[across] - $1.point) }
    for end in candidates where abs(point[across] - end.point) <= Self.edgeReach {
      var peek = point
      peek[across] =
        end.point + end.sign * (PartyBody.radius + PartyMotion.skin + Self.peekRoom)
      if fits(peek), motion.canTraverse(from: point, to: peek), clearsWall(peek) { return peek }
    }
    return nil
  }

  /// Tall scenery always stops incoming shots. A low block conceals the crouched leader only
  /// while it is the selected shelter; standing elsewhere or firing raises the body above it.
  /// A tall peek instead uses its exposed point and keeps every tall blocker.
  func incomingBlockers(in shelter: Shelter?, exposed: Bool) -> [PartyMotion.Box] {
    blocks.enumerated().compactMap { index, block in
      if !block.isLow { return block.footprint }
      guard !exposed, let shelter, shelter.isLow, shelter.index == index,
        shelter.boxID == block.name
      else { return nil }
      return block.footprint
    }
  }

  private func isBeside(_ point: SIMD2<Float>, _ shelter: Shelter) -> Bool {
    let across = 1 - shelter.axis
    let gap =
      (point[shelter.axis] - shelter.face) * shelter.normal[shelter.axis] - PartyBody.radius
    return gap >= -Self.tolerance && gap <= Self.proximity + Self.tolerance
      && point[across] >= shelter.minimum && point[across] <= shelter.maximum
  }

  private func fits(_ point: SIMD2<Float>) -> Bool {
    guard finite(point), motion.canTraverse(from: point, to: point) else { return false }
    guard let ground else { return true }
    let radius = PartyBody.radius + PartyMotion.skin
    return point.x - radius >= ground.minimum.x && point.x + radius <= ground.maximum.x
      && point.y - radius >= ground.minimum.y && point.y + radius <= ground.maximum.y
  }

  private func finite(_ point: SIMD2<Float>) -> Bool { point.x.isFinite && point.y.isFinite }
}
