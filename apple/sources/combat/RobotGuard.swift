import simd

/// One bounded machine, independent of entities and animation playback. Fixed-step authority
/// chooses movement, an honest committed aim point and one discharge at a time.
struct RobotGuard {
  enum Pattern: Hashable, Sendable {
    case precision, fan

    var name: String { self == .precision ? "Precision burst" : "Fan sweep" }
    var roundCount: Int { self == .precision ? 3 : 5 }
    var trackingTime: Float { self == .precision ? RobotGuard.trackingTime : 1.4 }
    var commitTime: Float { self == .precision ? RobotGuard.commitTime : 0.6 }
    var shotInterval: Float { self == .precision ? RobotGuard.shotInterval : 0.16 }

    func yawOffset(round: Int) -> Float {
      self == .precision ? 0 : Float(round - 2) * 7 * .pi / 180
    }
  }

  enum Phase: Equatable, Sendable {
    case hidden, patrol, notice, tracking, committed, burst, recovering, searching, down, cleared
  }

  struct Discharge: Equatable, Sendable {
    let gun: Int
    let origin: SIMD3<Float>
    let direction: SIMD3<Float>
    let burst: Int
    let pattern: Pattern

    init(
      gun: Int, origin: SIMD3<Float>, direction: SIMD3<Float>, burst: Int,
      pattern: Pattern = .precision
    ) {
      self.gun = gun
      self.origin = origin
      self.direction = direction
      self.burst = burst
      self.pattern = pattern
    }
  }

  static let speed: Float = 0.55
  static let turnRate: Float = 0.8
  static let detectionRange: Float = 14
  static let attackRange: Float = 12
  static let noticeTime: Float = 0.5
  static let trackingTime: Float = 1
  static let commitTime: Float = 0.35
  static let shotInterval: Float = 0.2
  static let recoveryTime: Float = 1.8
  static let searchTime: Float = 3
  static let gunYawLimit: Float = 15 * .pi / 180
  /// The final leg faces the bridge entrance again instead of patrolling only north/east/west.
  private static let patrolOffsets: [SIMD2<Float>] = [[0, -1.5], [3, -1.5], [1.5, 0]]

  let home: SIMD2<Float>
  private let strategicPatterns: Bool
  private(set) var pattern = Pattern.precision
  private(set) var phase = Phase.hidden
  private(set) var position: SIMD2<Float>
  private(set) var facing: SIMD2<Float> = [0, 1]
  private(set) var shotSerial = 0
  private(set) var lastGun = 0
  private(set) var burstSerial = 0
  private(set) var gunRecoil = SIMD2<Float>.zero
  private(set) var gunDirections: [SIMD3<Float>] = [[0, 0, 1], [0, 0, 1]]
  private(set) var brace: Float = 0
  private(set) var committedPoint: SIMD2<Float>?
  private(set) var elapsed: Float = 0
  private var recoilElapsed = SIMD2<Float>(repeating: 10)
  private var armed = false
  private var lastSeen: SIMD2<Float>?
  private var patrolIndex = 0
  private var roundsFired = 0
  private var burstHitAccepted = false
  private var aimingPoint: SIMD2<Float>?
  private var repositionRemaining: Float = 0
  private var repositionGoal: SIMD2<Float>?
  private var gunOffsets = SIMD2<Float>.zero

  init(home: SIMD2<Float>, strategicPatterns: Bool = false) {
    self.home = home
    self.strategicPatterns = strategicPatterns
    position = home
  }

  var nextPattern: Pattern {
    strategicPatterns && pattern == .precision ? .fan : .precision
  }

  var recoveryDuration: Float {
    strategicPatterns ? GuardStrategy.windowDuration : Self.recoveryTime
  }

  var isVisible: Bool { phase != .hidden }
  var isTargetable: Bool { armed && phase != .hidden && phase != .down && phase != .cleared }
  var isDown: Bool { phase == .down }
  var isCleared: Bool { phase == .cleared }
  var guardArea: PartyMotion.Box {
    PartyMotion.Box(minimum: home + [0, -3], maximum: home + [3.5, 1])
  }

  mutating func reveal() {
    guard phase == .hidden else { return }
    transition(.patrol)
  }

  mutating func engage() { armed = true }

  mutating func knockDown() {
    transition(.down)
    committedPoint = nil
    gunRecoil = .zero
    recoilElapsed = SIMD2(repeating: 10)
  }

  mutating func clear() {
    transition(.cleared)
    committedPoint = nil
    aimingPoint = nil
    gunRecoil = .zero
    recoilElapsed = SIMD2(repeating: 10)
    brace = 0
    updateGunDirections()
  }

  /// One party injury at most per committed burst of either pattern, including crossfire.
  mutating func acceptBurstHit() -> Bool {
    guard !burstHitAccepted, phase == .burst || phase == .recovering else { return false }
    burstHitAccepted = true
    return true
  }

  mutating func step(
    dt: Float, target: SIMD2<Float>, hasSight: Bool, obstacles: [PartyMotion.Box],
    party: [SIMD2<Float>], awareOfTarget: Bool = false
  ) -> Discharge? {
    guard dt.isFinite, dt > 0, target.x.isFinite, target.y.isFinite else { return nil }
    guard phase != .hidden, phase != .down, phase != .cleared else { return nil }
    recoilElapsed += SIMD2(repeating: dt)
    for gun in 0..<2 { gunRecoil[gun] = Self.recoil(at: recoilElapsed[gun]) }
    elapsed += dt
    let offset = target - position
    let distance = simd_length(offset)
    let inCone = distance < 0.001 || simd_dot(offset / distance, facing) >= cos(50 * .pi / 180)
    // An engaged guard can acknowledge a visible attacker on its flank. Actual line of
    // sight, range, finite body turning and the complete warning still apply.
    let sees = armed && hasSight && distance <= Self.detectionRange && (inCone || awareOfTarget)
    if sees { lastSeen = target }
    let wantsBrace = [.notice, .tracking, .committed, .burst].contains(phase)
    let braceTarget: Float = wantsBrace ? (strategicPatterns && pattern == .precision ? 0.6 : 1) : 0
    brace += max(-2 * dt, min(2 * dt, braceTarget - brace))

    switch phase {
    case .hidden, .down, .cleared:
      break
    case .patrol:
      aimingPoint = nil
      if repositionRemaining > 0 {
        repositionRemaining = max(0, repositionRemaining - dt)
        let goal = repositionGoal ?? home
        move(towards: goal, dt: dt, obstacles: obstacles, party: party)
        if simd_distance(position, goal) < 0.1 { repositionRemaining = 0 }
      } else if sees {
        aimingPoint = target
        transition(.notice)
      } else {
        let goal = home + Self.patrolOffsets[patrolIndex]
        move(towards: goal, dt: dt, obstacles: obstacles, party: party)
        if simd_distance(position, goal) < 0.15 {
          patrolIndex = (patrolIndex + 1) % Self.patrolOffsets.count
        }
      }
    case .notice, .tracking:
      guard sees else {
        aimingPoint = lastSeen
        transition(.searching)
        updateGunDirections()
        return nil
      }
      aimingPoint = target
      turn(towards: target, dt: dt)
      if phase == .notice, elapsed >= Self.noticeTime { transition(.tracking) }
      if phase == .tracking, elapsed >= pattern.trackingTime {
        if distance > Self.attackRange {
          // A visible target can remain between detection and attack range indefinitely.
          // End this completed warning so the encounter can acquire a reachable target.
          transition(.searching)
        } else if distance < 0.001
          || simd_dot(offset / distance, facing) >= cos(5 * .pi / 180)
        {
          committedPoint = target
          aimingPoint = target
          transition(.committed)
        }
      }
    case .committed:
      // Target is now a fixed point. Losing sight after commitment cannot make it home in.
      aimingPoint = committedPoint
      if elapsed >= pattern.commitTime {
        roundsFired = 0
        burstHitAccepted = false
        burstSerial += 1
        transition(.burst)
      }
    case .burst:
      break
    case .recovering:
      aimingPoint = committedPoint
      if elapsed >= recoveryDuration {
        pattern = nextPattern
        committedPoint = nil
        aimingPoint = nil
        // One short bounded reposition precedes the next warned cycle.
        patrolIndex = (patrolIndex + 1) % Self.patrolOffsets.count
        let side = SIMD2(-facing.y, facing.x)
        let mover = PartyMotion(radius: RobotModelGeometry.navigationRadius, obstacles: obstacles)
        repositionGoal = [facing, side, -side, -facing].map { bounded(position + $0 * 0.9) }
          .first { simd_distance(position, $0) > 0.25 && mover.canTraverse(from: position, to: $0) }
        repositionRemaining = repositionGoal == nil ? 0 : 4
        transition(sees ? .patrol : .searching)
      }
    case .searching:
      aimingPoint = lastSeen
      if sees {
        aimingPoint = target
        transition(.notice)
      } else if elapsed >= Self.searchTime {
        aimingPoint = nil
        lastSeen = nil
        transition(.patrol)
      } else if let lastSeen {
        move(towards: bounded(lastSeen), dt: dt, obstacles: obstacles, party: party)
      }
    }
    updateGunDirections()
    if phase == .burst, elapsed + 0.000001 >= Float(roundsFired) * pattern.shotInterval {
      let gun = roundsFired % 2
      gunOffsets[gun] = pattern.yawOffset(round: roundsFired)
      updateGunDirections()
      // A fan can revisit a barrel before its previous recoil has finished. Reset before
      // measuring this discharge, so the rendered muzzle and the actual ray stay identical.
      recoilElapsed[gun] = 0
      gunRecoil[gun] = 0
      let shot = Discharge(
        gun: gun, origin: muzzle(gun: gun), direction: gunDirections[gun], burst: burstSerial,
        pattern: pattern)
      roundsFired += 1
      lastGun = gun
      shotSerial += 1
      if roundsFired == pattern.roundCount { transition(.recovering) }
      return shot
    }
    return nil
  }

  /// Exactly the same mount/yaw/recoil transform used by the visual gun hierarchy.
  func muzzle(gun: Int) -> SIMD3<Float> {
    let yaw = Movement.yaw(towards: facing)
    let direction = gunDirections[gun]
    let gunYaw = Movement.yaw(towards: [direction.x, direction.z])
    let pitch = asin(min(1, max(-1, direction.y)))
    let mount = RobotModelGeometry.gunMounts[gun]
    let tip = RobotModelGeometry.muzzles[gun] - mount + [0, 0, gunRecoil[gun]]
    return SIMD3(position.x, -RobotModelGeometry.braceDepth * brace, position.y)
      + Self.rotate(mount, yaw: yaw)
      + (simd_quatf(angle: gunYaw, axis: [0, 1, 0])
      * simd_quatf(angle: pitch, axis: [1, 0, 0])).act(tip)
  }

  private mutating func transition(_ next: Phase) {
    phase = next
    elapsed = 0
    if next == .notice || next == .tracking || next == .patrol || next == .searching {
      gunOffsets = .zero
    }
  }

  private mutating func updateGunDirections() {
    let yaw = Movement.yaw(towards: facing)
    for gun in 0..<2 {
      guard let aimingPoint else {
        gunDirections[gun] = [facing.x, 0, facing.y]
        continue
      }
      let mount = Self.rotate(RobotModelGeometry.gunMounts[gun], yaw: yaw)
      let delta = aimingPoint - position - SIMD2(mount.x, mount.z)
      let desired = Movement.yaw(towards: delta)
      let relative = (desired - yaw).remainder(dividingBy: 2 * .pi) + gunOffsets[gun]
      let ground = Movement.facing(
        yaw: yaw + min(Self.gunYawLimit, max(-Self.gunYawLimit, relative)))
      let vertical =
        Float(1.25)
        - (RobotModelGeometry.gunMounts[gun].y - RobotModelGeometry.braceDepth * brace)
      let pitch = min(Self.gunYawLimit, max(-Self.gunYawLimit, atan2(vertical, simd_length(delta))))
      gunDirections[gun] = [ground.x * cos(pitch), sin(pitch), ground.y * cos(pitch)]
    }
  }

  private mutating func turn(towards target: SIMD2<Float>, dt: Float) {
    let offset = target - position
    guard simd_length_squared(offset) > 0.000001 else { return }
    let yaw = Movement.turn(
      from: Movement.yaw(towards: facing), towards: Movement.yaw(towards: offset),
      limit: Self.turnRate * dt)
    facing = Movement.facing(yaw: yaw)
  }

  private mutating func move(
    towards goal: SIMD2<Float>, dt: Float, obstacles: [PartyMotion.Box],
    party: [SIMD2<Float>]
  ) {
    let target = bounded(goal)
    let delta = target - position
    let distance = simd_length(delta)
    guard distance > 0.05 else { return }
    turn(towards: target, dt: dt)
    // Heavy articulated legs stop, turn and then advance. Translating through a broad turn
    // stretches a planted foot beyond the actual two-link reach during the corner.
    guard simd_dot(delta / distance, facing) >= cos(1 * .pi / 180) else { return }
    let movement = delta / distance * min(Self.speed * dt, distance)
    let proposed = PartyMotion(radius: RobotModelGeometry.navigationRadius, obstacles: obstacles)
      .resolve(start: position, delta: movement)
    guard
      party.allSatisfy({
        simd_distance($0, proposed) >= RobotModelGeometry.navigationRadius + PartyBody.radius
      })
    else {
      return
    }
    position = bounded(proposed)
  }

  private func bounded(_ point: SIMD2<Float>) -> SIMD2<Float> {
    let area = guardArea
    return simd_min(area.maximum, simd_max(area.minimum, point))
  }

  private static func rotate(_ point: SIMD3<Float>, yaw: Float) -> SIMD3<Float> {
    [
      cos(yaw) * point.x + sin(yaw) * point.z, point.y,
      -sin(yaw) * point.x + cos(yaw) * point.z,
    ]
  }

  private static func recoil(at time: Float) -> Float {
    func smooth(_ t: Float) -> Float {
      let t = min(1, max(0, t))
      return t * t * t * (t * (t * 6 - 15) + 10)
    }
    if time < 0.07 { return 0.075 * smooth(time / 0.07) }
    if time < 0.36 { return 0.075 * (1 - smooth((time - 0.07) / 0.29)) }
    return 0
  }
}
