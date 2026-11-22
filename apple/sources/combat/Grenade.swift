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
  private(set) var remaining: Float = Grenade.fuse

  init(id: Int, owner: String, from start: SIMD2<Float>, at position: SIMD2<Float>) {
    precondition(start.x.isFinite && start.y.isFinite && position.x.isFinite && position.y.isFinite)
    self.id = id
    self.owner = owner
    self.start = start
    self.position = position
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
    let point = start + (position - start) * progress
    let height =
      Self.launchHeight * (1 - progress) + Self.landingHeight * progress
      + 4 * Self.arcHeight * progress * (1 - progress)
    return [point.x, height, point.y]
  }

  /// The marker's world-space radius is also the blast's inclusive radius. Walls and whether
  /// the grenade has detonated are checked by the fight, not by this geometry query.
  func contains(_ point: SIMD2<Float>) -> Bool {
    guard point.x.isFinite, point.y.isFinite else { return false }
    return simd_distance_squared(point, position) <= Self.radius * Self.radius
  }
}
