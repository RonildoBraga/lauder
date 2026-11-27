import simd

/// Continuous exclusion from a living guard's hull. The world still resolves stone and other
/// movement blockers; this query never pushes an overlapping traveller to an unrequested spot.
enum GuardCollision {
  static func resolve(
    start: SIMD2<Float>, delta: SIMD2<Float>, centre: SIMD2<Float>, radius: Float
  ) -> SIMD2<Float> {
    guard start.x.isFinite, start.y.isFinite, delta.x.isFinite, delta.y.isFinite,
      centre.x.isFinite, centre.y.isFinite, radius.isFinite, radius > 0
    else { return start }
    typealias Vector = SIMD2<Double>
    let origin = Vector(Double(start.x), Double(start.y))
    let movement = Vector(Double(delta.x), Double(delta.y))
    let offset = origin - Vector(Double(centre.x), Double(centre.y))
    let clearance = Double(radius) + Double(PartyMotion.skin)
    func point(_ value: Vector) -> SIMD2<Float> {
      let result = SIMD2(Float(value.x), Float(value.y))
      return result.x.isFinite && result.y.isFinite ? result : start
    }
    let distanceSquared = simd_length_squared(offset)
    if distanceSquared < clearance * clearance {
      // An existing overlap may escape but cannot move farther through the hull. Tangential
      // movement also increases clearance, without an automatic push that could cross stone.
      guard distanceSquared > 0.000000000001 else { return point(origin + movement) }
      let normal = offset / sqrt(distanceSquared)
      return point(origin + movement - normal * min(0, simd_dot(movement, normal)))
    }
    let a = simd_length_squared(movement)
    guard a > 0 else { return start }
    let b = simd_dot(offset, movement)
    let c = distanceSquared - clearance * clearance
    let discriminant = b * b - a * c
    guard b < 0, discriminant >= 0 else { return point(origin + movement) }
    let time = (-b - sqrt(discriminant)) / a
    guard time >= 0, time <= 1 else { return point(origin + movement) }
    let contact = origin + movement * time
    let normal = (offset + movement * time) / clearance
    let remaining = movement * (1 - time)
    let tangent = remaining - normal * min(0, simd_dot(remaining, normal))
    return point(contact + tangent)
  }
}
