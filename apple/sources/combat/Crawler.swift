import simd

/// A crawler from the first-tower guard's pack (issue #208). It waits folded beside the guard
/// and, once that fight is engaged, walks round blockers towards a member it can see, winds up
/// with its ram line already fixed, rams along it and recovers, exposed. EncounterSimulation
/// chooses its target and resolves the ram's hit and every hit on it; this value only moves
/// (docs/crawler-pack.md).
struct Crawler {
  enum Phase: Equatable, Sendable {
    /// Unseen until its encounter begins.
    case hidden
    /// Waiting beside the guard, legs tucked in. It can be shot, which wakes it.
    case folded
    /// Getting up once its fight is engaged.
    case unfolding
    /// Walking towards the member it watches, or back towards its place.
    case approaching
    /// Crouched, light on, its ram line already fixed: the moment to step aside.
    case windingUp
    /// Along the fixed line, fast; a member in the way takes the hit.
    case ramming
    /// Stopped and exposed after a ram.
    case recovering
    case down
    /// After the quiet exit it walks back to its place and folds, harmless, for the run.
    case cleared
  }

  /// The stretch a ram swept in one step, for the hit test.
  struct Ram: Equatable, Sendable {
    let from: SIMD2<Float>
    let to: SIMD2<Float>
  }

  static let radius: Float = 0.38
  /// Its body as rounds meet it: low to the snow.
  static let centreHeight: Float = 0.28
  static let halfHeight: Float = 0.24
  static let health = 45
  /// A little quicker than the party, so the pack closes in and has to be fought.
  static let speed: Float = 3
  static let unfoldTime: Float = 0.6
  /// How close it comes before it winds up.
  static let ramRange: Float = 2.5
  static let windUpTime: Float = 0.6
  static let ramDistance: Float = 3
  static let ramSpeed: Float = 9
  static let recoverTime: Float = 1.2
  /// Between one crawler's wind-ups, recovery included.
  static let attackInterval: Float = 2.5
  /// A second crawler gets up a little after the first, and so on.
  static let slotDelay: Float = 0.5
  /// Farthest it chases from its place before it turns back.
  static let leash: Float = 16
  /// How near another crawler it walks.
  static let spacing: Float = 1
  /// How far round a ram's line a member counts as in its way.
  static let reach: Float = Crawler.radius + PartyBody.radius
  static let fallTime: Float = 0.5

  /// Its place beside the guard, where it waits folded.
  let home: SIMD2<Float>
  private(set) var phase = Phase.hidden
  private(set) var position: SIMD2<Float>
  private(set) var facing = SIMD2<Float>(0, 1)
  /// The fixed ram line while it winds up and rams.
  private(set) var ramStart: SIMD2<Float>?
  private(set) var ramEnd: SIMD2<Float>?
  /// How far through its wind-up it is, from 0 to 1, for its crouch and light.
  private(set) var windUp: Float = 0
  /// How far through its collapse it is, from 0 to 1, once down.
  private(set) var fallen: Float = 0
  /// Whether it moved in the latest step, for its legs.
  private(set) var isWalking = false
  private var timer: Float = 0
  private var cooldown: Float = 0
  private var hitAccepted = false
  /// Which way it last turned to get round a blocker, so it keeps going that way.
  private var detourSide: Float = 1
  private let slot: Int

  init(home: SIMD2<Float>, slot: Int = 0) {
    self.home = home
    self.slot = max(0, slot)
    position = home
  }

  var isTargetable: Bool { phase != .hidden && phase != .down && phase != .cleared }
  var isDown: Bool { phase == .down }
  /// Winding up or ramming: the ram line is fixed and dangerous.
  var isAttacking: Bool { phase == .windingUp || phase == .ramming }
  /// The middle of its body, where shots meet it.
  var centre: SIMD3<Float> { [position.x, Self.centreHeight, position.y] }

  mutating func reveal() {
    guard phase == .hidden else { return }
    phase = .folded
  }

  mutating func knockDown() {
    guard phase != .down else { return }
    phase = .down
    fallen = 0
    ramStart = nil
    ramEnd = nil
    windUp = 0
    isWalking = false
  }

  /// The quiet exit: it walks back to its place, folds and stays harmless for the run.
  mutating func clear() {
    guard phase != .down, phase != .hidden else { return }
    phase = .cleared
    ramStart = nil
    ramEnd = nil
    windUp = 0
  }

  /// A ram can hurt at most one member, once.
  mutating func acceptRamHit() -> Bool {
    guard !hitAccepted, phase == .ramming || phase == .recovering else { return false }
    hitAccepted = true
    return true
  }

  /// Whether `point` lies in the way of what is left of its fixed ram line, widened by a body
  /// each side. Behind it is safe: the ram moves away from there.
  func threatens(_ point: SIMD2<Float>, margin: Float = 0.25) -> Bool {
    guard isAttacking, let start = ramStart, let end = ramEnd else { return false }
    let from = phase == .ramming ? position : start
    let line = end - from
    let length = simd_length(line)
    guard length > 0.0001 else { return false }
    return simd_dot(point - from, line / length) > -margin
      && Self.distance(from: point, toSegment: from, end) < Self.reach + margin
  }

  /// Whether this step of a ram runs into a body standing at `point`: one ahead of the crawler,
  /// within a body's reach of the stretch it swept. A body beside or behind it as it sets off
  /// is left behind, not run into.
  static func runsInto(_ point: SIMD2<Float>, along ram: Ram) -> Bool {
    let stretch = ram.to - ram.from
    let length = simd_length(stretch)
    guard length > 0.0001 else { return false }
    return simd_dot(point - ram.from, stretch / length) > 0
      && distance(from: point, toSegment: ram.from, ram.to) <= reach
  }

  /// One fixed step. `target` is where the member it watches stands, if it can see one;
  /// `engaged` is whether its fight has started; `mayWindUp` is false while the guard warns,
  /// fires or staggers, and while another crawler winds up on the same member. `motion`
  /// holds the level's blockers at a crawler's radius, `guardian` the living guard's hull and
  /// `others` the other crawlers.
  mutating func step(
    dt: Float, target: SIMD2<Float>?, engaged: Bool, mayWindUp: Bool, motion: PartyMotion,
    guardian: (centre: SIMD2<Float>, radius: Float)?, others: [SIMD2<Float>]
  ) -> Ram? {
    guard dt.isFinite, dt > 0 else { return nil }
    let target = target.flatMap { $0.x.isFinite && $0.y.isFinite ? $0 : nil }
    isWalking = false
    cooldown = max(0, cooldown - dt)
    switch phase {
    case .hidden:
      return nil
    case .down:
      fallen = min(1, fallen + dt / Self.fallTime)
      return nil
    case .folded:
      guard engaged else { return nil }
      phase = .unfolding
      timer = Self.unfoldTime + Float(slot) * Self.slotDelay
      return nil
    case .unfolding:
      timer -= dt
      if timer <= 0 { phase = .approaching }
      return nil
    case .cleared:
      walk(towards: home, stopAt: 0.05, dt: dt, motion: motion, guardian: guardian, others: [])
      return nil
    case .approaching:
      guard let target, simd_distance(target, home) <= Self.leash else {
        walk(
          towards: home, stopAt: 0.05, dt: dt, motion: motion, guardian: guardian,
          others: others)
        return nil
      }
      let offset = target - position
      let distance = simd_length(offset)
      if distance > 0.001 { facing = offset / distance }
      if distance <= Self.ramRange, cooldown == 0, mayWindUp, distance > 0.001 {
        // The line is fixed now, so the whole wind-up is the moment to step aside.
        ramStart = position
        ramEnd = position + offset / distance * Self.ramDistance
        phase = .windingUp
        timer = Self.windUpTime
        windUp = 0
        hitAccepted = false
        return nil
      }
      walk(
        towards: target, stopAt: Self.ramRange - 0.3, dt: dt, motion: motion,
        guardian: guardian, others: others)
      return nil
    case .windingUp:
      timer -= dt
      windUp = min(1, 1 - timer / Self.windUpTime)
      guard timer <= 0 else { return nil }
      windUp = 0
      phase = .ramming
      return nil
    case .ramming:
      guard let end = ramEnd else {
        phase = .recovering
        timer = Self.recoverTime
        return nil
      }
      let offset = end - position
      let distance = simd_length(offset)
      let wanted = distance > 0.001 ? offset / distance * min(distance, Self.ramSpeed * dt) : .zero
      var moved = motion.resolve(start: position, delta: wanted)
      if let guardian {
        moved = GuardCollision.resolve(
          start: position, delta: moved - position, centre: guardian.centre,
          radius: guardian.radius + Self.radius)
      }
      let swept = Ram(from: position, to: moved)
      let progress = simd_length(moved - position)
      position = moved
      isWalking = progress > 0.0001
      // It stops at the end of its line, or at the first blocker in the way.
      if distance <= Self.ramSpeed * dt + 0.0001 || progress < simd_length(wanted) * 0.5 {
        phase = .recovering
        timer = Self.recoverTime
        ramStart = nil
        ramEnd = nil
      }
      return swept
    case .recovering:
      timer -= dt
      if timer <= 0 {
        phase = .approaching
        cooldown = max(0, Self.attackInterval - Self.recoverTime)
      }
      return nil
    }
  }

  private mutating func walk(
    towards goal: SIMD2<Float>, stopAt range: Float, dt: Float, motion: PartyMotion,
    guardian: (centre: SIMD2<Float>, radius: Float)?, others: [SIMD2<Float>]
  ) {
    var offset = goal - position
    let distance = simd_length(offset)
    guard distance > range else { return }
    offset /= distance
    // Keep a little apart from the rest of the pack.
    for other in others {
      let away = position - other
      let gap = simd_length(away)
      if gap > 0.001, gap < Self.spacing { offset += away / gap * (Self.spacing - gap) }
    }
    guard simd_length_squared(offset) > 0.000001 else { return }
    let wanted = simd_normalize(offset)
    let length = min(distance - range, Self.speed * dt)
    // Straight ahead first. Blocked head-on, it turns aside, keeping to the side that worked
    // last, so it follows a pier's face round its corner instead of dithering against it.
    let side = detourSide
    let turns: [Float] = [0, side, -side, 2 * side, -2 * side, 3 * side, -3 * side].map {
      $0 * .pi / 4
    }
    var moved = position
    for turn in turns {
      let direction = SIMD2(
        wanted.x * cos(turn) - wanted.y * sin(turn), wanted.x * sin(turn) + wanted.y * cos(turn))
      var attempt = motion.resolve(start: position, delta: direction * length)
      if let guardian {
        attempt = GuardCollision.resolve(
          start: position, delta: attempt - position, centre: guardian.centre,
          radius: guardian.radius + Self.radius)
      }
      if simd_distance(attempt, position) >= length * 0.5 {
        moved = attempt
        if turn != 0 { detourSide = turn > 0 ? 1 : -1 }
        break
      }
    }
    if simd_distance(moved, position) > 0.0001 {
      facing = simd_normalize(moved - position)
      isWalking = true
    }
    position = moved
    if phase == .cleared, simd_distance(position, home) <= 0.05 { isWalking = false }
  }

  static func distance(
    from point: SIMD2<Float>, toSegment start: SIMD2<Float>, _ end: SIMD2<Float>
  ) -> Float {
    let line = end - start
    let length = simd_length_squared(line)
    guard length > 0.000001 else { return simd_distance(point, start) }
    let along = max(0, min(1, simd_dot(point - start, line) / length))
    return simd_distance(point, start + line * along)
  }
}
