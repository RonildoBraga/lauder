import simd

/// Temporary cover at an actor's movement anchor. The same geometry and exposure interval
/// serve the leader, companions and tactical enemies; no entity or navigation state lives here.
struct CoverStance {
  private(set) var shelter: LeaderCover.Shelter?
  private(set) var position = SIMD2<Float>.zero
  private(set) var exposureRemaining: Float = 0
  private var peekFacing: SIMD2<Float>?

  var firing: Bool { exposureRemaining > 0 }

  mutating func advance(
    at point: SIMD2<Float>, facing: SIMD2<Float>, dt: Float, using rules: LeaderCover
  ) {
    let next = rules.shelter(at: point, facing: facing)
    if next?.boxID != shelter?.boxID || next?.normal != shelter?.normal {
      exposureRemaining = 0
      peekFacing = nil
    }
    position = point
    shelter = next
    exposureRemaining = max(0, exposureRemaining - dt)
    if exposureRemaining == 0 { peekFacing = nil }
    if let shelter, let peekFacing,
      rules.firingPoint(from: point, in: shelter, facing: peekFacing) == nil
    {
      self.peekFacing = nil
    }
  }

  func firingPoint(facing: SIMD2<Float>, using rules: LeaderCover) -> SIMD2<Float> {
    guard let shelter else { return position }
    return rules.firingPoint(from: position, in: shelter, facing: peekFacing ?? facing) ?? position
  }

  /// A committed peek stays exposed while its timer lasts, even if the shooter turns.
  mutating func fired(facing: SIMD2<Float>, using rules: LeaderCover) {
    guard let shelter else { return }
    if peekFacing == nil,
      let peek = rules.firingPoint(from: position, in: shelter, facing: facing),
      simd_distance_squared(peek, position) > 0.000001
    {
      peekFacing = facing
    }
    exposureRemaining = LeaderCover.exposureSeconds
  }

  func incomingPoint(using rules: LeaderCover) -> SIMD2<Float> {
    guard firing, let peekFacing else { return position }
    return firingPoint(facing: peekFacing, using: rules)
  }

  func incomingBlockers(using rules: LeaderCover) -> [PartyMotion.Box] {
    rules.incomingBlockers(in: shelter, exposed: firing)
  }
}
