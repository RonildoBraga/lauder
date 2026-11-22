import simd

/// Camera motion as values: follow, encounter lean, leader-switch easing and the aiming lens.
/// WorldCamera applies the result to RealityKit; projection and motion need no scene entities.
struct CameraRig {
  static let leanRate: Float = 3
  static let fightLens: Float = 0.7
  static let lensTime: Float = 0.3
  static let switchTime: Float = 0.25

  let offset: SIMD3<Float>
  let fieldOfView: Float
  private(set) var target: SIMD3<Float>
  private(set) var lens: Float
  private var lean: SIMD2<Float> = .zero
  private var switchStart: SIMD3<Float>?
  private var switchElapsed: Float = 0

  init(offset: SIMD3<Float>, fieldOfView: Float, over point: SIMD2<Float>) {
    self.offset = offset
    self.fieldOfView = fieldOfView
    target = Self.target(over: point)
    lens = fieldOfView
  }

  var eye: SIMD3<Float> { target + offset }

  mutating func switchLeader() {
    switchStart = target
    switchElapsed = 0
  }

  mutating func reset(over point: SIMD2<Float>) {
    switchStart = nil
    switchElapsed = 0
    lean = .zero
    target = Self.target(over: point)
    lens = fieldOfView
  }

  mutating func update(
    over leader: SIMD2<Float>, lean wanted: SIMD2<Float>, close: Bool, deltaTime: Float
  ) {
    lean += (wanted - lean) * min(1, deltaTime * Self.leanRate)
    let following = Self.target(over: leader + lean)
    if let start = switchStart {
      switchElapsed = min(Self.switchTime, switchElapsed + deltaTime)
      let amount = switchElapsed / Self.switchTime
      let eased = amount * amount * (3 - 2 * amount)
      target = start + (following - start) * eased
      if switchElapsed >= Self.switchTime { switchStart = nil }
    } else {
      target = following
    }
    let goal = fieldOfView * (close ? Self.fightLens : 1)
    lens += (goal - lens) * min(1, deltaTime / Self.lensTime)
  }

  func projection(aspect: Float) -> CameraProjection {
    CameraProjection(eye: eye, target: target, fieldOfView: lens, aspect: aspect)
  }

  private static func target(over point: SIMD2<Float>) -> SIMD3<Float> {
    [point.x, PartyBody.height / 2 + 0.1, point.y]
  }
}
