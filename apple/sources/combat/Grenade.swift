import simd

/// One warned blast at a fixed landing point. The fuse starts at launch, includes the flight,
/// and expires once; the fight applies damage then, using its own cover and hit rules.
struct Grenade: Sendable {
  static let radius: Float = 2.2
  static let fuse: Float = 2.5
  static let flightTime: Float = 0.6
  static let launchHeight: Float = 1.25
  static let landingHeight: Float = 0.12
  static let arcHeight: Float = 2

  let id: Int
  let owner: String
  let start: SIMD2<Float>
  let position: SIMD2<Float>
  let startHeight: Float
  let landingHeight: Float
  private(set) var remaining: Float = Grenade.fuse

  init(
    id: Int, owner: String, from start: SIMD2<Float>, at position: SIMD2<Float>,
    startHeight: Float = 0, landingHeight: Float = 0
  ) {
    precondition(start.x.isFinite && start.y.isFinite && position.x.isFinite && position.y.isFinite)
    self.id = id
    self.owner = owner
    self.start = start
    self.position = position
    self.startHeight = startHeight
    self.landingHeight = landingHeight
  }

  /// Only positive finite simulation time advances a fuse. Pause does not call this. The
  /// single true result is the detonation event, even when a long step passes its deadline.
  mutating func advance(dt: Float) -> Bool {
    guard dt.isFinite, dt > 0, remaining > 0 else { return false }
    remaining = max(0, remaining - dt)
    return remaining == 0
  }

  /// A simple ballistic-looking arc to the frozen marker, then the grenade rests there for
  /// the rest of its fuse. This presentation query does not change the simulation.
  var projectilePosition: SIMD3<Float> {
    let progress = min(1, max(0, (Self.fuse - remaining) / Self.flightTime))
    return projectilePosition(at: progress)
  }

  func projectilePosition(at progress: Float) -> SIMD3<Float> {
    let point = start + (position - start) * progress
    let height =
      (startHeight + Self.launchHeight) * (1 - progress)
      + (landingHeight + Self.landingHeight) * progress
      + 4 * Self.arcHeight * progress * (1 - progress)
    return [point.x, height, point.y]
  }

  /// A throw cannot pass through a ramp, retaining wall or cover. Twelve short segments
  /// follow the same visible arc, evaluated once at launch rather than each rendered frame.
  func canReach(isClear: (SIMD3<Float>, SIMD3<Float>) -> Bool) -> Bool {
    var previous = projectilePosition(at: 0)
    for step in 1...12 {
      let next = projectilePosition(at: Float(step) / 12)
      guard isClear(previous, next) else { return false }
      previous = next
    }
    return true
  }

  /// The marker's world-space radius is also the blast's inclusive radius. Walls and whether
  /// the grenade has detonated are checked by the fight, not by this geometry query.
  func contains(_ point: SIMD2<Float>) -> Bool {
    guard point.x.isFinite, point.y.isFinite else { return false }
    return simd_distance_squared(point, position) <= Self.radius * Self.radius
  }
}
