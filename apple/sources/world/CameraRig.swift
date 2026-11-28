import simd

/// Fixed orientation with smooth translation: follow the hero or frame the focused duel.
struct CameraRig {
  static let followRate: Float = 8

  let offset: SIMD3<Float>
  let fieldOfView: Float
  private(set) var target: SIMD3<Float>

  init(offset: SIMD3<Float>, fieldOfView: Float, over point: SIMD2<Float>) {
    self.offset = offset
    self.fieldOfView = fieldOfView
    target = [point.x, 0.85, point.y]
  }

  var eye: SIMD3<Float> { target + offset }

  mutating func update(
    hero: SIMD2<Float>, enemy: SIMD2<Float>, isFocused: Bool, deltaTime: Float
  ) {
    guard deltaTime.isFinite, deltaTime > 0,
      let wanted = Self.composition(hero: hero, enemy: enemy, isFocused: isFocused)
    else { return }
    // Exponential damping has the same response at 30 Hz and 60 Hz; it never overshoots.
    let amount = 1 - exp(-Self.followRate * deltaTime)
    target += (wanted - target) * amount
  }

  mutating func reset(hero: SIMD2<Float>, enemy: SIMD2<Float>, isFocused: Bool) {
    guard let wanted = Self.composition(hero: hero, enemy: enemy, isFocused: isFocused) else {
      return
    }
    target = wanted
  }

  func projection(aspect: Float) -> CameraProjection {
    CameraProjection(eye: eye, target: target, fieldOfView: fieldOfView, aspect: aspect)
  }

  private static func composition(
    hero: SIMD2<Float>, enemy: SIMD2<Float>, isFocused: Bool
  ) -> SIMD3<Float>? {
    guard hero.x.isFinite, hero.y.isFinite else { return nil }
    var point = hero
    if isFocused {
      guard enemy.x.isFinite, enemy.y.isFinite else { return nil }
      point = hero / 2 + enemy / 2
    }
    return [point.x, 0.85, point.y]
  }
}
