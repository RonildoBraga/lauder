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
    /// Launch a marked grenade. The fight resolves its fuse and blast later, never as an
    /// immediate hit on the member being aimed at.
    case grenade
  }

  /// Seconds to step out from where it waited.
  static let stepOutTime: Float = 0.8
  /// How close a charger comes to the leader before it stops.
  static let reach: Float = 0.9
  /// Seconds each hit during a wind-up delays its shot, and the most that hits can delay one
  /// wind-up in all (ADR 0008). Starting values for playtests.
  static let flinchDelay: Float = 0.2
  static let flinchLimit: Float = 0.5

  let spec: Level.Hostile
  private(set) var phase = Phase.hidden {
    didSet {
      guard case .aiming = phase else { return }
      hasAimed = true
      if case .aiming = oldValue {} else { flinched = 0 }
    }
  }
  private(set) var position: SIMD2<Float>
  private var hasFired = false
  /// Whether it has begun a wind-up: what it remembers of the fight after a fall back.
  private var hasAimed = false
  private var engaged = false
  /// How long hits have delayed the current wind-up so far.
  private var flinched: Float = 0

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
    if phase == .waiting { phase = openingAttack }
  }

  /// The phase an engaged hostile attacks in.
  private var attacking: Phase {
    switch spec.attack {
    case .shoot, .throwGrenade: .aiming(remaining: spec.windUp)
    case .charge: .charging
    }
  }

  /// Reaction is paid once per engagement, rather than before every shot. Chargers retain
  /// the opening's direct charge and never wait in a shooting phase.
  private var openingAttack: Phase {
    if case .charge = spec.attack { return attacking }
    return spec.reactionDelay.isFinite && spec.reactionDelay > 0
      ? .recovering(remaining: spec.reactionDelay) : attacking
  }

  /// The fight has checked this destination against movement blockers and floor bounds.
  /// Revealing and falling bodies keep their authored movement; hidden or downed actors
  /// cannot be repositioned by a stale tactical destination.
  mutating func reposition(to point: SIMD2<Float>) {
    guard point.x.isFinite, point.y.isFinite else { return }
    switch phase {
    case .waiting, .aiming, .recovering, .charging: position = point
    case .hidden, .steppingOut, .down: break
    }
  }

  mutating func knockDown() {
    phase = .down
  }

  /// A hit that does not down it (ADR 0008): during a wind-up, its shot comes a little later,
  /// up to a limit for each wind-up. Only Disrupt cancels a wind-up.
  mutating func flinch() {
    guard case .aiming(let remaining) = phase else { return }
    let delay = min(Self.flinchDelay, Self.flinchLimit - flinched)
    guard delay > 0 else { return }
    flinched += delay
    phase = .aiming(remaining: remaining + delay)
  }

  /// Disrupt (ADR 0005): a wind-up is cancelled before its shot, and the hostile recovers
  /// before it can aim again.
  mutating func disrupt() {
    guard case .aiming = phase else { return }
    phase = .recovering(remaining: spec.recovery)
  }

  /// A new angle or lost target requires a fresh readable wind-up. In particular a marksman
  /// cannot carry an almost-finished shot through a retreat and fire the instant it stops.
  /// Reaction and post-shot recovery still have to finish before that next wind-up begins.
  mutating func restartWindUp() {
    guard engaged, spec.attack == .shoot, isVisible, !isDown, case .aiming = phase else { return }
    flinched = 0
    phase = .aiming(remaining: spec.windUp)
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
  /// whether the line to the leader is clear and within range at that moment. `canFire` gates
  /// aiming without freezing arrival/recovery readiness. A charger runs towards `target`.
  mutating func step(
    dt: Float, canHit: Bool, toward target: SIMD2<Float>, canAttack: Bool = true,
    canFire: Bool = true
  ) -> Shot? {
    switch phase {
    case .hidden, .down:
      return nil
    case .steppingOut(let elapsed):
      let progress = min(1, (elapsed + dt) / Self.stepOutTime)
      position = spec.hiddenAt + (spec.standAt - spec.hiddenAt) * progress
      if progress < 1 {
        phase = .steppingOut(elapsed: elapsed + dt)
      } else {
        phase = engaged ? openingAttack : .waiting
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
      guard canAttack else { return nil }
      guard canFire else {
        phase = .aiming(remaining: spec.windUp)
        return nil
      }
      guard remaining - dt <= 0 else {
        phase = .aiming(remaining: remaining - dt)
        return nil
      }
      let shot: Shot
      if spec.attack == .throwGrenade {
        shot = canHit ? .grenade : .blocked
      } else {
        shot = spec.firstShotMisses && !hasFired ? .miss : canHit ? .hit : .blocked
      }
      hasFired = true
      phase = .recovering(remaining: spec.recovery)
      return shot
    case .recovering(let remaining):
      guard canAttack else { return nil }
      phase =
        remaining - dt <= 0
        ? .aiming(remaining: spec.windUp) : .recovering(remaining: remaining - dt)
      return nil
    }
  }
}
