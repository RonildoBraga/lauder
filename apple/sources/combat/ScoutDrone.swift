import simd

/// A small flying scout that keeps watch with the first-tower guard (issue #201). It circles
/// above sword reach and the low cover, warns before it dives, commits to a straight line,
/// fires a short burst along it, passes low and climbs back. EncounterSimulation chooses its
/// target and resolves every round and every hit; this value only flies (docs/scout-drones.md).
struct ScoutDrone {
  enum Phase: Equatable, Sendable {
    /// Unseen until its encounter begins.
    case hidden
    /// Circling its centre. It attacks only once its fight is engaged.
    case patrolling
    /// Hovering with its light on, watching its target before it commits.
    case warning
    /// On a committed straight line past the point its target held, firing as it comes.
    case diving
    /// Rising back to cruise height after the low pass.
    case climbing
    case down
    /// After the quiet exit it keeps circling and never attacks again in that run.
    case cleared
  }

  /// One round of a dive's burst, from the drone towards its committed point.
  struct Discharge: Equatable, Sendable {
    let origin: SIMD3<Float>
    let direction: SIMD3<Float>
  }

  /// Where a drone may fly: round the tall blockers, over the low ones, inside the bounds.
  struct Airspace: Sendable {
    struct Roof: Sendable {
      let footprint: PartyMotion.Box
      let top: Float
    }

    var walls: [PartyMotion.Box] = []
    var roofs: [Roof] = []
    var bounds: PartyMotion.Box

    init(walls: [PartyMotion.Box] = [], roofs: [Roof] = [], bounds: PartyMotion.Box) {
      self.walls = walls
      self.roofs = roofs
      self.bounds = bounds
    }

    /// A level's boxes that reach cruise height are walls; the rest are roofs to rise over.
    init(level: Level) {
      for box in level.boxes {
        let top = box.position.y + box.size.y / 2
        if top > ScoutDrone.cruiseHeight - ScoutDrone.clearance {
          walls.append(box.footprint)
        } else {
          roofs.append(Roof(footprint: box.footprint, top: top))
        }
      }
      let inset = SIMD2<Float>(repeating: ScoutDrone.radius)
      bounds = PartyMotion.Box(
        minimum: level.bounds.minimum + inset, maximum: level.bounds.maximum - inset)
    }
  }

  /// The height it circles at, above a sword's reach and the bridge's low cover.
  static let cruiseHeight: Float = 3
  /// The height of the low pass, where a level shot, the shotgun and the sword reach it.
  static let lowHeight: Float = 1.3
  /// The highest body centre a sword swing reaches.
  static let swordHeight: Float = 2
  /// Where its rounds aim on a member's body, as the party's own shots fly
  /// (EncounterSimulation.aimHeight).
  static let aimHeight: Float = 1.25
  /// How far above a low blocker it stays.
  static let clearance: Float = 0.45
  /// Its body, as rounds and swings meet it.
  static let radius: Float = 0.45
  static let halfHeight: Float = 0.22
  static let health = 60
  static let orbitRadius: Float = 5
  static let cruiseSpeed: Float = 3.2
  static let diveSpeed: Float = 6
  static let verticalSpeed: Float = 2.5
  /// The warning before each dive: the light, the sound and the HUD line.
  static let warningTime: Float = 1
  /// How far away a target can be for a dive to start.
  static let attackRange: Float = 12
  /// The shortest dive: enough run-up for the whole burst before it reaches its point. A
  /// warning drone backs off to keep it.
  static let minimumRunUp: Float = 4
  /// After the fight is engaged, before the first dive; a second drone waits longer.
  static let firstAttack: Float = 3
  static let slotDelay: Float = 4.5
  /// Between one drone's dives, so with two a dive comes about every 4.5 s.
  static let attackInterval: Float = 9
  /// After a warning whose line was blocked before it could commit.
  static let retryDelay: Float = 1.5
  static let burstRounds = 3
  static let burstInterval: Float = 0.12
  /// From the commit to the first round: the moment to step out of the line, as the guard's
  /// committed aim gives one before its burst.
  static let fireDelay: Float = 0.35
  /// How far round the point a dive aims at someone counts as in its way.
  static let danger: Float = 1.3
  /// The dive levels off this far short of the committed point.
  static let levelOff: Float = 1.5
  /// The low pass carries on this far beyond the committed point.
  static let overshoot: Float = 2.5
  static let fallTime: Float = 0.7
  /// Where a downed drone rests, above the snow or the low cover it falls on.
  static let wreckHeight: Float = 0.12

  /// The centre it circles before its guard moves, from its authored place.
  let home: SIMD2<Float>
  private(set) var phase = Phase.hidden
  private(set) var position: SIMD2<Float>
  private(set) var height = ScoutDrone.cruiseHeight
  private(set) var facing = SIMD2<Float>(0, 1)
  /// The point the current dive is aimed at; fixed when the warning ends.
  private(set) var committedPoint: SIMD2<Float>?
  /// How far through its warning it is, from 0 to 1, for the light.
  private(set) var warning: Float = 0
  private var angle: Float
  private var armed = false
  private var attackTimer: Float
  private var elapsed: Float = 0
  private var lastSeen: SIMD2<Float>?
  private var diveDirection = SIMD2<Float>(0, 1)
  private var diveHeight = ScoutDrone.cruiseHeight
  private var diveLength: Float = 0
  private var travelled: Float = 0
  private var rounds = 0
  private var sinceCommit: Float = 0
  private var hitAccepted = false
  private var fallStart = ScoutDrone.cruiseHeight
  private var fallen: Float = 0

  /// `orbit` is where round its centre it starts, in radians; `slot` delays its first dive.
  init(home: SIMD2<Float>, orbit: Float, slot: Int = 0) {
    self.home = home
    angle = orbit
    position = home + Self.orbitRadius * SIMD2(cos(orbit), sin(orbit))
    attackTimer = Self.firstAttack + Float(max(0, slot)) * Self.slotDelay
  }

  var isTargetable: Bool { phase != .hidden && phase != .down && phase != .cleared }
  var isDown: Bool { phase == .down }
  /// Warning or diving: while one drone does either, the other waits its turn.
  var isAttacking: Bool { phase == .warning || phase == .diving }
  /// Low enough for a sword swing.
  var isLow: Bool { height <= Self.swordHeight }
  /// Where its rounds would go: the warned member's last-seen point, or the committed point.
  var aimPoint: SIMD2<Float>? {
    switch phase {
    case .warning: lastSeen
    case .diving: committedPoint
    default: nil
    }
  }
  /// The middle of its body, where shots and swings meet it.
  var centre: SIMD3<Float> { [position.x, height, position.y] }

  mutating func reveal() {
    guard phase == .hidden else { return }
    phase = .patrolling
  }

  /// Its fight can start; the encounter still decides when it is engaged.
  mutating func engage() { armed = true }

  mutating func knockDown() {
    guard phase != .down else { return }
    phase = .down
    fallStart = height
    fallen = 0
    committedPoint = nil
    warning = 0
  }

  /// The quiet exit: it keeps circling, harmless, for the rest of the run.
  mutating func clear() {
    guard phase != .down, phase != .hidden else { return }
    phase = .cleared
    committedPoint = nil
    warning = 0
    armed = false
  }

  /// A dive's burst can hurt at most one member, once.
  mutating func acceptBurstHit() -> Bool {
    guard !hitAccepted, phase == .diving || phase == .climbing else { return false }
    hitAccepted = true
    return true
  }

  /// One fixed step. `centre` is what it circles, normally its guard; `target` is where the
  /// member it watches stands, if it can see one; `mayAttack` is false until its fight is
  /// engaged and while another drone attacks.
  mutating func step(
    dt: Float, centre: SIMD2<Float>, target: SIMD2<Float>?, mayAttack: Bool,
    airspace: Airspace
  ) -> Discharge? {
    guard dt.isFinite, dt > 0, centre.x.isFinite, centre.y.isFinite else { return nil }
    let target = target.flatMap { $0.x.isFinite && $0.y.isFinite ? $0 : nil }
    switch phase {
    case .hidden:
      return nil
    case .down:
      fallen = min(Self.fallTime, fallen + dt)
      let progress = fallen / Self.fallTime
      // A wreck rests on any low cover beneath it, not inside it.
      let rest = roof(at: position, in: airspace) + Self.wreckHeight
      height = fallStart + (rest - fallStart) * progress * progress
      return nil
    case .patrolling, .cleared:
      circle(dt: dt, centre: centre, airspace: airspace)
      guard phase == .patrolling, armed else { return nil }
      attackTimer = max(0, attackTimer - dt)
      if mayAttack, attackTimer == 0, let target,
        (Self.minimumRunUp...Self.attackRange).contains(simd_distance(target, position)),
        !Self.crosses(airspace.walls, from: position, to: target)
      {
        phase = .warning
        elapsed = 0
        warning = 0
        lastSeen = target
      }
      return nil
    case .warning:
      elapsed += dt
      warning = min(1, elapsed / Self.warningTime)
      if let target {
        lastSeen = target
        let offset = position - target
        let distance = simd_length(offset)
        if distance < Self.minimumRunUp + 0.5, distance > 0.001 {
          fly(
            towards: target + offset / distance * (Self.minimumRunUp + 1),
            speed: Self.cruiseSpeed, dt: dt, airspace: airspace)
        }
        turn(towards: target)
      }
      rise(towards: Self.cruiseHeight, dt: dt, airspace: airspace)
      guard elapsed >= Self.warningTime else { return nil }
      warning = 0
      guard let point = lastSeen, simd_distance(point, position) >= Self.minimumRunUp - 0.5,
        !Self.crosses(airspace.walls, from: position, to: point)
      else {
        phase = .patrolling
        attackTimer = Self.retryDelay
        return nil
      }
      commit(to: point)
      return nil
    case .diving:
      return dive(dt: dt, airspace: airspace)
    case .climbing:
      fly(towards: orbitPoint(centre), speed: Self.cruiseSpeed, dt: dt, airspace: airspace)
      rise(towards: Self.cruiseHeight, dt: dt, airspace: airspace)
      if height >= Self.cruiseHeight - 0.001 {
        phase = .patrolling
        attackTimer = Self.attackInterval
      }
      return nil
    }
  }

  /// Whether a straight path between two points, widened by a drone's body, meets a wall.
  static func crosses(
    _ walls: [PartyMotion.Box], from start: SIMD2<Float>, to end: SIMD2<Float>
  ) -> Bool {
    let delta = end - start
    return walls.contains { box in
      LineOfSight.entry(
        from: start, along: delta,
        minimum: box.minimum - radius, maximum: box.maximum + radius, limit: 1) != nil
    }
  }

  private mutating func commit(to point: SIMD2<Float>) {
    let offset = point - position
    let length = simd_length(offset)
    committedPoint = point
    diveDirection = offset / length
    diveLength = length
    diveHeight = height
    travelled = 0
    rounds = 0
    sinceCommit = 0
    hitAccepted = false
    facing = diveDirection
    phase = .diving
  }

  private mutating func dive(dt: Float, airspace: Airspace) -> Discharge? {
    guard let point = committedPoint else {
      phase = .climbing
      return nil
    }
    let step = Self.diveSpeed * dt
    let next = position + diveDirection * step
    if Self.inside(airspace.walls, next) || !airspace.bounds.contains(next) {
      committedPoint = nil
      phase = .climbing
      return nil
    }
    position = next
    travelled += step
    let descent = max(0.001, diveLength - Self.levelOff)
    let progress = min(1, travelled / descent)
    height = max(
      diveHeight + (Self.lowHeight - diveHeight) * progress,
      roof(at: position, in: airspace) + Self.clearance)
    sinceCommit += dt
    var discharge: Discharge?
    let ahead = simd_dot(point - position, diveDirection)
    if rounds < Self.burstRounds, ahead > 0.3,
      sinceCommit >= Self.fireDelay + Float(rounds) * Self.burstInterval
    {
      rounds += 1
      let origin = centre
      let aim = SIMD3(point.x, Self.aimHeight, point.y)
      discharge = Discharge(origin: origin, direction: simd_normalize(aim - origin))
    }
    if travelled >= diveLength + Self.overshoot {
      committedPoint = nil
      phase = .climbing
    }
    return discharge
  }

  private func orbitPoint(_ centre: SIMD2<Float>) -> SIMD2<Float> {
    centre + Self.orbitRadius * SIMD2(cos(angle), sin(angle))
  }

  private mutating func circle(dt: Float, centre: SIMD2<Float>, airspace: Airspace) {
    angle = (angle + Self.cruiseSpeed / Self.orbitRadius * dt)
      .truncatingRemainder(dividingBy: 2 * .pi)
    fly(towards: orbitPoint(centre), speed: Self.cruiseSpeed * 1.5, dt: dt, airspace: airspace)
    rise(towards: Self.cruiseHeight, dt: dt, airspace: airspace)
  }

  private mutating func fly(
    towards goal: SIMD2<Float>, speed: Float, dt: Float, airspace: Airspace
  ) {
    let offset = goal - position
    let distance = simd_length(offset)
    guard distance > 0.001 else { return }
    let moved = position + offset / distance * min(distance, speed * dt)
    let bounded = simd_clamp(moved, airspace.bounds.minimum, airspace.bounds.maximum)
    let clear = Self.pushedOut(bounded, from: airspace.walls)
    if simd_distance(clear, position) > 0.0001 { turn(towards: clear) }
    position = clear
  }

  private mutating func rise(towards wanted: Float, dt: Float, airspace: Airspace) {
    let limit = Self.verticalSpeed * dt
    height += max(-limit, min(limit, wanted - height))
    height = max(height, roof(at: position, in: airspace) + Self.clearance)
  }

  private mutating func turn(towards point: SIMD2<Float>) {
    let offset = point - position
    guard simd_length_squared(offset) > 0.000001 else { return }
    facing = simd_normalize(offset)
  }

  private func roof(at point: SIMD2<Float>, in airspace: Airspace) -> Float {
    airspace.roofs.filter {
      point.x >= $0.footprint.minimum.x - Self.radius
        && point.x <= $0.footprint.maximum.x + Self.radius
        && point.y >= $0.footprint.minimum.y - Self.radius
        && point.y <= $0.footprint.maximum.y + Self.radius
    }.map(\.top).max() ?? 0
  }

  private static func inside(_ walls: [PartyMotion.Box], _ point: SIMD2<Float>) -> Bool {
    walls.contains {
      point.x > $0.minimum.x - radius && point.x < $0.maximum.x + radius
        && point.y > $0.minimum.y - radius && point.y < $0.maximum.y + radius
    }
  }

  /// The nearest point outside every wall, widened by a drone's body, moving across the
  /// shallowest side of each wall it is inside.
  private static func pushedOut(_ point: SIMD2<Float>, from walls: [PartyMotion.Box])
    -> SIMD2<Float>
  {
    var point = point
    for wall in walls {
      let minimum = wall.minimum - radius
      let maximum = wall.maximum + radius
      guard point.x > minimum.x, point.x < maximum.x, point.y > minimum.y, point.y < maximum.y
      else { continue }
      let exits: [(distance: Float, point: SIMD2<Float>)] = [
        (point.x - minimum.x, [minimum.x, point.y]),
        (maximum.x - point.x, [maximum.x, point.y]),
        (point.y - minimum.y, [point.x, minimum.y]),
        (maximum.y - point.y, [point.x, maximum.y]),
      ]
      point = exits.min { $0.distance < $1.distance }?.point ?? point
    }
    return point
  }
}
