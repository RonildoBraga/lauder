import simd

/// One hostile's behaviour in an encounter. It waits unseen and steps out. Once engaged, a
/// shooter aims with a visible wind-up, shoots, recovers and aims again until it is down; a
/// charger runs at the leader. Plain values: the world moves its body and resolves the shot
/// against the leader.
struct HostileState {
  enum Phase: Equatable {
    case hidden
    /// Moving from where it waited to where it fights.
    case steppingOut(elapsed: Float)
    /// In the open, not yet fighting: the moment Miki hesitates.
    case waiting
    case aiming(remaining: Float)
    case recovering(remaining: Float)
    /// Running at the leader.
    case charging
    case down
  }

  enum Shot: Equatable {
    /// Deliberately wide, as the opening's first shot.
    case miss
    /// Clear line, within range: the leader is hit.
    case hit
    /// Cover was in the way, or the leader was out of range.
    case blocked
  }

  /// Seconds to step out from where it waited.
  static let stepOutTime: Float = 0.8
  /// How close a charger comes to the leader before it stops.
  static let reach: Float = 0.9

  let spec: Level.Hostile
  private(set) var phase = Phase.hidden {
    didSet {
      if case .aiming = phase { hasAimed = true }
    }
  }
  private(set) var position: SIMD2<Float>
  private var hasFired = false
  /// Whether it has begun a wind-up: what it remembers of the fight after a fall back.
  private var hasAimed = false
  private var engaged = false

  init(spec: Level.Hostile) {
    self.spec = spec
    position = spec.inView ? spec.standAt : spec.hiddenAt
    if spec.inView { phase = .waiting }
  }

  var isVisible: Bool { phase != .hidden }
  var isDown: Bool { phase == .down }
  /// A target for assisted aim only once it has opened fire, or, for one that is a target from
  /// its first wind-up, once it has begun to aim: before that, nobody knows it is hostile.
  var isTargetable: Bool { !isDown && (hasFired || spec.targetFromWindUp && hasAimed) }

  mutating func reveal() {
    guard phase == .hidden else { return }
    phase = .steppingOut(elapsed: 0)
  }

  mutating func engage() {
    guard !isDown else { return }
    engaged = true
    if phase == .waiting { phase = attacking }
  }

  /// The phase an engaged hostile attacks in.
  private var attacking: Phase {
    spec.attack == .shoot ? .aiming(remaining: spec.windUp) : .charging
  }

  mutating func knockDown() {
    phase = .down
  }

  /// The party fell back (ADR 0005): a hostile still standing stops fighting and waits where it
  /// stands until it is engaged again. It remembers having aimed, so it stays a target; the
  /// session keeps the damage dealt to it.
  mutating func standDown() {
    guard isVisible, !isDown else { return }
    position = spec.standAt
    phase = .waiting
    engaged = false
  }

  /// Advance by one simulation step. A shot returns when a wind-up completes; `canHit` says
  /// whether the line to the leader is clear and within range at that moment. A charger runs
  /// towards `target`, the leader.
  mutating func step(dt: Float, canHit: Bool, toward target: SIMD2<Float>) -> Shot? {
    switch phase {
    case .hidden, .down:
      return nil
    case .steppingOut(let elapsed):
      let progress = min(1, (elapsed + dt) / Self.stepOutTime)
      position = spec.hiddenAt + (spec.standAt - spec.hiddenAt) * progress
      if progress < 1 {
        phase = .steppingOut(elapsed: elapsed + dt)
      } else {
        phase = engaged ? attacking : .waiting
      }
      return nil
    case .waiting:
      return nil
    case .charging:
      guard case .charge(let speed) = spec.attack else { return nil }
      let offset = target - position
      let distance = simd_length(offset)
      if distance > Self.reach {
        position += offset / distance * min(speed * dt, distance - Self.reach)
      }
      return nil
    case .aiming(let remaining):
      guard remaining - dt <= 0 else {
        phase = .aiming(remaining: remaining - dt)
        return nil
      }
      let shot: Shot = spec.firstShotMisses && !hasFired ? .miss : canHit ? .hit : .blocked
      hasFired = true
      phase = .recovering(remaining: spec.recovery)
      return shot
    case .recovering(let remaining):
      phase =
        remaining - dt <= 0
        ? .aiming(remaining: spec.windUp) : .recovering(remaining: remaining - dt)
      return nil
    }
  }
}
