import simd

/// Horizontal sphere-footprint sweep motion for the prototype's flat floor.
enum PartyMotion {
  struct Hit: Sendable {
    let distance: Float
    let normal: SIMD2<Float>
  }

  private static let skin: Float = 0.002

  /// Recover sphere-centre travel from the contact point and full surface normal.
  static func footprintHit(
    from: SIMD2<Float>, to: SIMD2<Float>, point: SIMD3<Float>, normal: SIMD3<Float>,
    radius: Float
  ) -> Hit {
    let invalid = Hit(distance: 0, normal: .zero)
    let delta = to - from
    let length = simd_length(delta)
    let normalLength = simd_length(normal)
    let horizontalNormal = SIMD2(normal.x, normal.z)
    guard finite(from), finite(to), length.isFinite, length > 0,
      point.x.isFinite, point.y.isFinite, point.z.isFinite, point != .zero,
      normalLength.isFinite, abs(normalLength - 1) <= 0.0001,
      radius.isFinite, radius > 0, simd_length_squared(horizontalNormal) > 0
    else { return invalid }
    // Keep the horizontal magnitude of the 3D normal; normalising it first changes the centre.
    let centre = SIMD2(point.x, point.z) + radius * horizontalNormal
    let direction = delta / length
    let travel = simd_dot(centre - from, direction)
    guard finite(centre), travel.isFinite, travel >= -0.00001, travel <= length + 0.00001
    else { return invalid }
    let clamped = min(max(travel, 0), length)
    guard simd_distance(centre, from + direction * clamped) <= 0.0001 else { return invalid }
    return Hit(distance: clamped, normal: horizontalNormal)
  }

  static func resolve(
    start: SIMD2<Float>, delta: SIMD2<Float>,
    cast: (SIMD2<Float>, SIMD2<Float>) -> Hit?
  ) -> SIMD2<Float> {
    let distance = simd_length(delta)
    let end = start + delta
    guard finite(start), finite(delta), finite(end), distance.isFinite, distance > 0 else {
      return start
    }
    guard let hit = cast(start, end) else { return end }
    guard let normal = validatedNormal(hit, maximumDistance: distance) else { return start }
    let contact = start + delta * (max(0, hit.distance - skin) / distance)
    let remaining = end - contact
    let slide = remaining - normal * simd_dot(remaining, normal)
    let slideDistance = simd_length(slide)
    let slideEnd = contact + slide
    guard finite(contact), finite(slideEnd), slideDistance.isFinite, slideDistance > 0.000001
    else { return contact }
    guard let second = cast(contact, slideEnd) else { return slideEnd }
    guard validatedNormal(second, maximumDistance: slideDistance) != nil else { return contact }
    return contact + slide * (max(0, second.distance - skin) / slideDistance)
  }

  private static func validatedNormal(_ hit: Hit, maximumDistance: Float) -> SIMD2<Float>? {
    let length = simd_length(hit.normal)
    guard hit.distance.isFinite, hit.distance > 0, hit.distance <= maximumDistance,
      finite(hit.normal), length.isFinite, length > 0
    else { return nil }
    return hit.normal / length
  }

  private static func finite(_ point: SIMD2<Float>) -> Bool {
    point.x.isFinite && point.y.isFinite
  }
}
