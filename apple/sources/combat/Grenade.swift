import simd

/// One committed throw as values. EncounterSimulation owns the squad's shared recharge and
/// accepted blast damage; this value only flies, stops against real geometry and times its fuse.
struct Grenade: Sendable {
  static let cooldown: Float = 8
  static let maximumRange: Float = 10
  static let flightDuration: Float = 0.75
  static let fuseDuration: Float = 0.6
  static let blastRadius: Float = 3
  static let maximumDamage = 180
  static let minimumDamage = 60
  /// A small solid's centre stays outside the ground and any surface it struck.
  static let clearance: Float = 0.08
  static let arcHeight: Float = 2.5
  private static let segmentDuration: Float = 1 / 120

  let thrower: PartyMember
  let start: SIMD3<Float>
  let destination: SIMD3<Float>
  private(set) var position: SIMD3<Float>
  private(set) var hasLanded = false
  private(set) var isFinished = false
  private var flightAge: Float = 0
  private var fuseRemaining = Grenade.fuseDuration

  init?(from start: SIMD3<Float>, toward target: SIMD2<Float>, by thrower: PartyMember) {
    guard start.indices.allSatisfy({ start[$0].isFinite }), start.y >= Self.clearance,
      target.indices.allSatisfy({ target[$0].isFinite })
    else { return nil }
    let offset = target - SIMD2(start.x, start.z)
    let distance = simd_length(offset)
    guard distance.isFinite else { return nil }
    let capped = distance > Self.maximumRange ? offset / distance * Self.maximumRange : offset
    let destination = SIMD3(start.x + capped.x, Self.clearance, start.z + capped.y)
    guard destination.indices.allSatisfy({ destination[$0].isFinite }) else { return nil }
    self.thrower = thrower
    self.start = start
    self.destination = destination
    position = start
  }

  /// Advances accepted simulation time, returning the blast point exactly once. The caller
  /// traces each short segment against scenery (no bodies); tall cover can stop a throw while
  /// a low wall can be cleared. Pause/inactivity simply do not advance this value.
  mutating func step(
    dt: Float, trace: (SIMD3<Float>, SIMD3<Float>) -> Ballistics.Trace
  ) -> SIMD3<Float>? {
    guard dt.isFinite, dt > 0, !isFinished else { return nil }
    // Flight has a bounded number of short segments, then the fuse consumes the remainder;
    // even a huge finite time step cannot create an unbounded integration loop.
    var remaining = dt
    while remaining > 0 {
      if hasLanded {
        let elapsed = min(remaining, fuseRemaining)
        fuseRemaining = max(0, fuseRemaining - elapsed)
        remaining = max(0, remaining - elapsed)
        if fuseRemaining == 0 {
          isFinished = true
          return position
        }
      } else {
        let elapsed = min(remaining, min(Self.segmentDuration, Self.flightDuration - flightAge))
        flightAge = min(Self.flightDuration, flightAge + elapsed)
        remaining = max(0, remaining - elapsed)
        let fraction = flightAge / Self.flightDuration
        // Preserve the exact committed endpoint: interpolation can otherwise leave its y
        // a few Float ulps away from the ground clearance even when the fraction is one.
        let next =
          flightAge == Self.flightDuration
          ? destination
          : start + (destination - start) * fraction
            + SIMD3(0, 4 * Self.arcHeight * fraction * (1 - fraction), 0)
        let contact = trace(position, next)
        guard contact.end.indices.allSatisfy({ contact.end[$0].isFinite }) else {
          // Invalid geometry must not produce a blast or leave an immortal live projectile.
          isFinished = true
          return nil
        }
        if contact.strike != .nothing {
          let incoming = contact.end - position
          let contactDistance = simd_length(incoming)
          guard contactDistance.isFinite else {
            isFinished = true
            return nil
          }
          // Trace endpoints are exactly on the solid: pull back towards the free previous
          // point so the subsequent blast's cover ray does not begin inside that surface.
          // Reuse that point exactly for a very short contact, without roundoff overshooting it.
          position =
            contactDistance <= Self.clearance
            ? position : contact.end - incoming / contactDistance * Self.clearance
          position.y = max(Self.clearance, position.y)
          hasLanded = true
        } else {
          position = next
          if flightAge == Self.flightDuration { hasLanded = true }
        }
      }
    }
    return nil
  }

  /// Whole-body blast damage falls off linearly; component criticals are separate direct hits.
  static func damage(at distance: Float) -> Int {
    guard distance.isFinite, distance >= 0, distance <= blastRadius else { return 0 }
    let loss = Float(maximumDamage - minimumDamage) * (distance / blastRadius)
    return max(minimumDamage, min(maximumDamage, Int((Float(maximumDamage) - loss).rounded())))
  }
}
