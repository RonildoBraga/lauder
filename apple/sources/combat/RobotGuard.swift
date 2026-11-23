import simd

/// One bounded machine, independent of entities and animation playback. Fixed-step authority
/// chooses movement, an honest committed aim point and one discharge at a time.
struct RobotGuard {
  enum Phase: Equatable, Sendable {
    case hidden, patrol, notice, tracking, committed, burst, recovering, searching, down, cleared
    case pursuing, takingCover, covered, peeking
  }

  struct Discharge: Equatable, Sendable {
    let gun: Int
    let origin: SIMD3<Float>
    let direction: SIMD3<Float>
    let burst: Int
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
  static let searchTime: Float = 8
  static let pursuitDistance: Float = 9
  static let coverHoldTime: Float = 1.25
  static let gunYawLimit: Float = 15 * .pi / 180
  /// The final leg faces the bridge entrance again instead of patrolling only north/east/west.
  private static let patrolOffsets: [SIMD2<Float>] = [[0, -1.5], [3, -1.5], [1.5, 0]]

  let home: SIMD2<Float>
  private(set) var phase = Phase.hidden
  private(set) var position: SIMD2<Float>
  private(set) var facing: SIMD2<Float> = [0, 1]
  private(set) var shotSerial = 0
  private(set) var lastGun = 0
  private(set) var burstSerial = 0
  private(set) var gunRecoil = SIMD2<Float>.zero
  private(set) var gunDirections: [SIMD3<Float>] = [[0, 0, 1], [0, 0, 1]]
  private(set) var brace: Float = 0
  private(set) var motion = RobotMotion()
  private(set) var committedPoint: SIMD2<Float>?
  private(set) var elapsed: Float = 0
  private(set) var coverGoal: SIMD2<Float>?
  private(set) var coverRequested = false
  private var recoilElapsed = SIMD2<Float>(repeating: 10)
  private var armed = false
  private var lastSeen: SIMD2<Float>?
  private var patrolIndex = 0
  private var roundsFired = 0
  private var burstHitAccepted = false
  private var aimingPoint: SIMD2<Float>?
  private var repositionRemaining: Float = 0
  private var repositionGoal: SIMD2<Float>?
  private var peekGoal: SIMD2<Float>?
  private var coverCooldown: Float = 0
  private var route: [SIMD2<Float>] = []
  private var routeGoal: SIMD2<Float>?
  private var routeRefresh: Float = 0

  init(home: SIMD2<Float>) {
    self.home = home
    position = home
    motion.reset(position: home, facing: facing)
  }

  var isVisible: Bool { phase != .hidden }
  var isTargetable: Bool { armed && phase != .hidden && phase != .down && phase != .cleared }
  var isDown: Bool { phase == .down }
  var isCleared: Bool { phase == .cleared }
  var lastKnownPosition: SIMD2<Float>? { lastSeen }
  var guardArea: PartyMotion.Box {
    // The east aisle and south face of the first pier, never the west bypass or whole bridge.
    PartyMotion.Box(minimum: home + [-7, -5], maximum: home + [6, 8])
  }

  mutating func reveal() {
    guard phase == .hidden else { return }
    transition(.patrol)
  }

  mutating func engage() { armed = true }

  /// Damage is evidence of danger, not permission to track a shooter through a wall.
  /// One retreat may interrupt tracking; committed rounds finish honestly before a retreat.
  mutating func notifyHit() {
    guard isTargetable, coverCooldown <= 0,
      ![.takingCover, .covered, .peeking].contains(phase)
    else { return }
    coverRequested = true
  }

  mutating func knockDown() {
    transition(.down)
    committedPoint = nil
    gunRecoil = .zero
    recoilElapsed = SIMD2(repeating: 10)
    clearTactics()
  }

  mutating func clear() {
    transition(.cleared)
    committedPoint = nil
    aimingPoint = nil
    gunRecoil = .zero
    recoilElapsed = SIMD2(repeating: 10)
    brace = 0
    updateGunDirections()
    clearTactics()
  }

  /// One player injury at most per committed three-round burst, including crossfire.
  mutating func acceptBurstHit() -> Bool {
    guard !burstHitAccepted, phase == .burst || phase == .recovering else { return false }
    burstHitAccepted = true
    return true
  }

  mutating func step(
    dt: Float, target: SIMD2<Float>, hasSight: Bool, obstacles: [PartyMotion.Box],
    party: [SIMD2<Float>], coverBoxes: [Level.Box] = []
  ) -> Discharge? {
    guard dt.isFinite, dt > 0, target.x.isFinite, target.y.isFinite else { return nil }
    guard phase != .hidden, phase != .down, phase != .cleared else { return nil }
    recoilElapsed += SIMD2(repeating: dt)
    for gun in 0..<2 { gunRecoil[gun] = Self.recoil(at: recoilElapsed[gun]) }
    elapsed += dt
    coverCooldown = max(0, coverCooldown - dt)
    routeRefresh = max(0, routeRefresh - dt)
    let offset = target - position
    let distance = simd_length(offset)
    let inCone = distance < 0.001 || simd_dot(offset / distance, facing) >= cos(50 * .pi / 180)
    // Acquisition uses the front cone. A known, unobstructed opponent stays known while the
    // heavy body faces a route waypoint; otherwise search and pursuit can reverse each turn.
    let retainsSight = lastSeen != nil && phase != .patrol
    let sees = armed && hasSight && distance <= Self.detectionRange && (inCone || retainsSight)
    if sees { lastSeen = target }
    let tactics = RobotTactics(area: guardArea, obstacles: obstacles, boxes: coverBoxes)
    if coverRequested, phase != .committed, phase != .burst {
      coverRequested = false
      coverCooldown = 6
      if let lastSeen, let cover = tactics.cover(from: position, against: lastSeen) {
        coverGoal = cover.position
        peekGoal = cover.peek
        route = cover.route
        routeGoal = cover.position
        routeRefresh = 0.75
        committedPoint = nil
        aimingPoint = nil
        repositionRemaining = 0
        transition(.takingCover)
      }
    }
    let wantsBrace = [.notice, .tracking, .committed, .burst].contains(phase)
    brace = min(1, max(0, brace + (wantsBrace ? 2 : -2) * dt))

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
        transition(distance > Self.attackRange ? .pursuing : .notice)
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
        updateMotion(dt: dt)
        return nil
      }
      aimingPoint = target
      turn(towards: target, dt: dt)
      if distance > Self.attackRange {
        transition(.pursuing)
        break
      }
      if phase == .notice, elapsed >= Self.noticeTime { transition(.tracking) }
      if phase == .tracking, elapsed >= Self.trackingTime, distance <= Self.attackRange,
        distance < 0.001 || simd_dot(offset / distance, facing) >= cos(5 * .pi / 180)
      {
        committedPoint = target
        aimingPoint = target
        transition(.committed)
      }
    case .committed:
      // Target is now a fixed point. Losing sight after commitment cannot make it home in.
      aimingPoint = committedPoint
      if elapsed >= Self.commitTime {
        roundsFired = 0
        burstHitAccepted = false
        burstSerial += 1
        transition(.burst)
      }
    case .burst:
      break
    case .recovering:
      aimingPoint = committedPoint
      if elapsed >= Self.recoveryTime {
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
        transition(distance > Self.attackRange ? .pursuing : .notice)
      } else if elapsed >= Self.searchTime {
        aimingPoint = nil
        lastSeen = nil
        transition(.patrol)
      } else if let lastSeen {
        _ = followRoute(towards: lastSeen, dt: dt, tactics: tactics, party: party)
      }
    case .pursuing:
      guard sees else {
        aimingPoint = lastSeen
        transition(.searching)
        break
      }
      aimingPoint = target
      if distance <= Self.pursuitDistance {
        transition(.notice)
      } else {
        let direction = distance > 0.001 ? offset / distance : facing
        _ = followRoute(
          towards: target - direction * (Self.pursuitDistance - 0.5), dt: dt,
          tactics: tactics, party: party)
      }
    case .takingCover:
      aimingPoint = nil
      if let coverGoal {
        let arrived = followRoute(
          towards: coverGoal, dt: dt, tactics: tactics, party: party)
        if arrived {
          if let lastSeen, tactics.isCovered(position, against: lastSeen) {
            transition(.covered)
          } else {
            transition(sees ? .notice : .searching)
          }
        } else if elapsed >= 30 {
          transition(sees ? .notice : .searching)
        }
      } else {
        transition(.searching)
      }
    case .covered:
      aimingPoint = lastSeen
      if let lastSeen { turn(towards: lastSeen, dt: dt) }
      if sees, !tactics.isCovered(position, against: target) {
        coverCooldown = 6
        transition(.notice)
      } else if elapsed >= Self.coverHoldTime {
        coverCooldown = 6
        transition(.peeking)
      }
    case .peeking:
      aimingPoint = lastSeen
      let arrived =
        peekGoal.map {
          followRoute(towards: $0, dt: dt, tactics: tactics, party: party)
        } ?? true
      if arrived, let lastSeen { turn(towards: lastSeen, dt: dt) }
      // Arriving while facing the travel direction is not a failed search. Turn towards the
      // remembered threat and require real sight before a fresh warned attack.
      if (arrived && sees) || elapsed >= 15 {
        coverGoal = nil
        peekGoal = nil
        coverCooldown = 6
        transition(sees ? (distance > Self.attackRange ? .pursuing : .notice) : .searching)
      }
    }
    updateMotion(dt: dt)
    if phase == .burst, elapsed + 0.000001 >= Float(roundsFired) * Self.shotInterval {
      let gun = roundsFired % 2
      let shot = Discharge(
        gun: gun, origin: muzzle(gun: gun), direction: gunDirections[gun], burst: burstSerial)
      roundsFired += 1
      lastGun = gun
      shotSerial += 1
      recoilElapsed[gun] = 0
      gunRecoil[gun] = 0
      if roundsFired == 3 { transition(.recovering) }
      return shot
    }
    return nil
  }

  /// Exactly the same mount/yaw/recoil transform used by the visual gun hierarchy.
  func muzzle(gun: Int) -> SIMD3<Float> {
    let yaw = Movement.yaw(towards: facing)
    let turn = simd_quatf(angle: yaw, axis: [0, 1, 0])
    let body = turn * motion.bodyPose.rotation
    let direction = body.inverse.act(gunDirections[gun])
    let gunYaw = Movement.yaw(towards: [direction.x, direction.z])
    let pitch = asin(min(1, max(-1, direction.y)))
    let mount = RobotModelGeometry.gunMounts[gun]
    let tip = RobotModelGeometry.muzzles[gun] - mount + [0, 0, gunRecoil[gun]]
    let gunRotation =
      simd_quatf(angle: gunYaw, axis: [0, 1, 0])
      * simd_quatf(angle: pitch, axis: [1, 0, 0])
    return SIMD3(position.x, 0, position.y) + turn.act(motion.bodyPose.offset)
      + body.act(mount + gunRotation.act(tip))
  }

  private mutating func transition(_ next: Phase) {
    phase = next
    elapsed = 0
    // A phase change never carries a partly completed route into another tactical decision.
    if next != .takingCover {
      route = []
      routeGoal = nil
      routeRefresh = 0
    }
    if ![.takingCover, .covered, .peeking].contains(next) {
      coverGoal = nil
      peekGoal = nil
    }
  }

  private mutating func clearTactics() {
    coverGoal = nil
    peekGoal = nil
    coverRequested = false
    route = []
    routeGoal = nil
    routeRefresh = 0
    repositionRemaining = 0
  }

  @discardableResult
  private mutating func followRoute(
    towards goal: SIMD2<Float>, dt: Float, tactics: RobotTactics, party: [SIMD2<Float>]
  ) -> Bool {
    if routeRefresh <= 0, routeGoal == nil || simd_distance(routeGoal!, goal) > 0.5 || route.isEmpty
    {
      route = tactics.approach(from: position, towards: goal) ?? []
      routeGoal = route.last
      routeRefresh = 0.75
    }
    while let first = route.first, simd_distance(position, first) < 0.08 {
      route.removeFirst()
    }
    if let next = route.first {
      move(towards: next, dt: dt, obstacles: tactics.obstacles, party: party)
    }
    return routeGoal.map { simd_distance(position, $0) < 0.1 } ?? false
  }

  private mutating func updateMotion(dt: Float) {
    motion.advance(position: position, facing: facing, brace: brace, dt: dt)
    updateGunDirections()
  }

  private mutating func updateGunDirections() {
    let yaw = Movement.yaw(towards: facing)
    let turn = simd_quatf(angle: yaw, axis: [0, 1, 0])
    let body = turn * motion.bodyPose.rotation
    let origin = SIMD3(position.x, 0, position.y) + turn.act(motion.bodyPose.offset)
    for gun in 0..<2 {
      guard let aimingPoint else {
        gunDirections[gun] = [facing.x, 0, facing.y]
        continue
      }
      let mount = origin + body.act(RobotModelGeometry.gunMounts[gun])
      let delta = body.inverse.act(SIMD3(aimingPoint.x, 1.25, aimingPoint.y) - mount)
      let desired = Movement.yaw(towards: [delta.x, delta.z])
      let ground = Movement.facing(yaw: min(Self.gunYawLimit, max(-Self.gunYawLimit, desired)))
      let pitch = min(
        Self.gunYawLimit,
        max(
          -Self.gunYawLimit,
          atan2(delta.y, simd_length(SIMD2(delta.x, delta.z)))))
      gunDirections[gun] = body.act([ground.x * cos(pitch), sin(pitch), ground.y * cos(pitch)])
    }
  }

  private mutating func turn(towards target: SIMD2<Float>, dt: Float) {
    let offset = target - position
    guard simd_length_squared(offset) > 0.000001 else { return }
    let yaw = Movement.turn(
      from: Movement.yaw(towards: facing), towards: Movement.yaw(towards: offset),
      limit: Self.turnRate * dt)
    let proposed = Movement.facing(yaw: yaw)
    if motion.canPlaceBody(position: position, facing: proposed, brace: brace) { facing = proposed }
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
    let candidate = bounded(proposed)
    if motion.canPlaceBody(position: candidate, facing: facing, brace: brace) {
      position = candidate
    }
  }

  private func bounded(_ point: SIMD2<Float>) -> SIMD2<Float> {
    let area = guardArea
    return simd_min(area.maximum, simd_max(area.minimum, point))
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
