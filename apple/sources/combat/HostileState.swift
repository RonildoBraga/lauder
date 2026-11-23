import simd

/// A bridge hostile: it reveals itself, then fires from its authored place or charges the
/// leader. Its encounter supplies the timeline, and EncounterSimulation resolves the actual shot.
struct HostileState {
  enum Phase: Equatable {
    case hidden
    case steppingOut(elapsed: Float)
    case waiting
    case aiming(remaining: Float)
    case recovering(remaining: Float)
    case charging
    case down
  }

  enum Shot: Equatable {
    case miss
    case hit
    case blocked
  }

  static let stepOutTime: Float = 0.8
  static let reach: Float = 0.9
  static let flinchDelay: Float = 0.2
  static let flinchLimit: Float = 0.5

  let spec: Level.Hostile
  private(set) var phase = Phase.hidden {
    didSet {
      guard case .aiming = phase else { return }
      if case .aiming = oldValue {} else { flinched = 0 }
    }
  }
  private(set) var position: SIMD2<Float>
  private(set) var robot: RobotGuard?
  private var hasFired = false
  private var engaged = false
  private var flinched: Float = 0

  init(spec: Level.Hostile) {
    self.spec = spec
    position = spec.hiddenAt
    if spec.attack == .robot {
      robot = RobotGuard(home: spec.standAt)
      position = spec.standAt
    }
  }

  var isVisible: Bool { phase != .hidden }
  var isDown: Bool { phase == .down }
  /// Before the stranger opens fire, the party does not know that he is hostile.
  var isTargetable: Bool { robot.map(\.isTargetable) ?? (!isDown && hasFired) }

  mutating func reveal() {
    guard phase == .hidden else { return }
    if robot != nil {
      robot?.reveal()
      phase = .waiting
      return
    }
    phase = .steppingOut(elapsed: 0)
  }

  mutating func engage() {
    guard !isDown else { return }
    engaged = true
    if robot != nil {
      robot?.engage()
      return
    }
    if phase == .waiting { phase = attacking }
  }

  private var attacking: Phase {
    switch spec.attack {
    case .shoot: .aiming(remaining: spec.windUp)
    case .robot: .waiting
    case .charge: .charging
    }
  }

  mutating func knockDown() {
    phase = .down
    robot?.knockDown()
  }

  mutating func clearGuard() {
    robot?.clear()
    phase = .waiting
  }

  mutating func acceptRobotBurstHit() -> Bool { robot?.acceptBurstHit() ?? false }

  mutating func stepRobot(
    dt: Float, target: SIMD2<Float>, hasSight: Bool, obstacles: [PartyMotion.Box],
    party: [SIMD2<Float>]
  ) -> RobotGuard.Discharge? {
    let shot = robot?.step(
      dt: dt, target: target, hasSight: hasSight, obstacles: obstacles, party: party)
    if let robot { position = robot.position }
    return shot
  }

  /// A hit delays an unfinished wind-up, with a limit on the total delay from repeated hits.
  mutating func flinch() {
    guard robot == nil else { return }
    guard case .aiming(let remaining) = phase else { return }
    let delay = min(Self.flinchDelay, Self.flinchLimit - flinched)
    guard delay > 0 else { return }
    flinched += delay
    phase = .aiming(remaining: remaining + delay)
  }

  /// Returning within range requires a fresh warning rather than a banked almost-ready shot.
  mutating func restartWindUp() {
    guard engaged, spec.attack == .shoot, case .aiming = phase else { return }
    flinched = 0
    phase = .aiming(remaining: spec.windUp)
  }

  mutating func step(
    dt: Float, canHit: Bool, toward target: SIMD2<Float>, canFire: Bool = true
  ) -> Shot? {
    switch phase {
    case .hidden, .waiting, .down:
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
    case .charging:
      guard case .charge(let speed) = spec.attack else { return nil }
      let offset = target - position
      let distance = simd_length(offset)
      if distance > Self.reach {
        position += offset / distance * min(speed * dt, distance - Self.reach)
      }
      return nil
    case .aiming(let remaining):
      guard canFire else {
        phase = .aiming(remaining: spec.windUp)
        return nil
      }
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
