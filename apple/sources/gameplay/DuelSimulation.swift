import simd

enum DuelSide: Equatable, Sendable { case hero, enemy }
enum DuelOutcome: Equatable, Sendable { case fighting, won, lost }

struct DuelCommand: Equatable, Sendable {
  var movement: SIMD2<Float> = .zero
  var attackPressed = false
  var guardHeld = false
  var dodgePressed = false
  var focusPressed = false

  static let neutral = DuelCommand()
}

enum DuelEvent: Equatable, Sendable {
  case swung(DuelSide)
  case hit(DuelSide)
  case blocked, evaded, guardBroken
  case finished(DuelOutcome)
}

/// One clock controls both contact and the pose presented by the scene.
struct DuelAction: Equatable, Sendable {
  enum Kind: Equatable, Sendable { case slash, sweep, thrust, dodge }
  enum Phase: Equatable, Sendable { case windup, active, recovery }

  struct Profile: Equatable, Sendable {
    let windup: Float
    let active: Float
    let recovery: Float
    let reach: Float
    let halfAngle: Float
    let damage: Float
    let stamina: Float
  }

  let kind: Kind
  let direction: SIMD2<Float>
  var elapsed: Float = 0
  var previousElapsed: Float = 0
  var contacted = false

  var profile: Profile {
    switch kind {
    case .slash:
      Profile(
        windup: 0.19, active: 0.16, recovery: 0.32, reach: 1.8,
        halfAngle: .pi / 3, damage: 24, stamina: 24)
    case .sweep:
      Profile(
        windup: 0.65, active: 0.22, recovery: 0.9, reach: 2.05,
        halfAngle: .pi * 0.58, damage: 40, stamina: 22)
    case .thrust:
      Profile(
        windup: 0.95, active: 0.16, recovery: 1.1, reach: 2.75,
        halfAngle: .pi / 9, damage: 65, stamina: 34)
    case .dodge:
      Profile(
        windup: 0.03, active: 0.2, recovery: 0.24, reach: 0,
        halfAngle: 0, damage: 0, stamina: 30)
    }
  }

  var duration: Float { profile.windup + profile.active + profile.recovery }
  var phase: Phase {
    if elapsed < profile.windup { return .windup }
    return elapsed < profile.windup + profile.active ? .active : .recovery
  }
  var progress: Float { min(1, elapsed / duration) }
  var phaseProgress: Float {
    let p = profile
    switch phase {
    case .windup: return min(1, elapsed / p.windup)
    case .active: return min(1, (elapsed - p.windup) / p.active)
    case .recovery: return min(1, (elapsed - p.windup - p.active) / p.recovery)
    }
  }
  var isInvulnerable: Bool { kind == .dodge && phase == .active }

  /// The blade's local yaw and tip distance are shared with the primitive presenter.
  var bladeAngle: Float {
    guard kind == .slash || kind == .sweep else { return 0 }
    switch phase {
    case .windup: return 0.15 + (-profile.halfAngle - 0.15) * phaseProgress
    case .active: return -profile.halfAngle + 2 * profile.halfAngle * phaseProgress
    case .recovery: return profile.halfAngle * (1 - phaseProgress) + 0.15 * phaseProgress
    }
  }

  var bladeReach: Float {
    guard kind == .thrust else { return profile.reach }
    switch phase {
    case .windup: return 2.05 - 0.5 * phaseProgress
    case .active: return 1.55 + 1.2 * phaseProgress
    case .recovery: return profile.reach - 0.7 * phaseProgress
    }
  }
}

struct DuelFighter: Equatable, Sendable {
  var position: SIMD2<Float>
  var yaw: Float
  var health: Float
  var stamina: Float = DuelSimulation.maxStamina
  var guarding = false
  var action: DuelAction?
  var hitFlash: Float = 0
  var stagger: Float = 0
}

/// Flat navigation intentionally keeps real 3D presentation separate from terrain complexity.
enum DuelArena {
  static let halfWidth: Float = 7
  static let halfDepth: Float = 5
  static let radius: Float = 0.38
  /// The agreed 45-degree camera yaw projects this ground direction horizontally.
  static let screenRight = simd_normalize(SIMD2<Float>(1, -1))
  static let heroSpawn = SIMD2<Float>(0, 2.5)
  static let enemySpawn = SIMD2<Float>(0, -1.5)
  static let obstacles: [PartyMotion.Box] = [
    .init(minimum: [-8, -6], maximum: [-7, 6]),
    .init(minimum: [7, -6], maximum: [8, 6]),
    .init(minimum: [-8, -6], maximum: [8, -5]),
    .init(minimum: [-8, 5], maximum: [8, 6]),
    .init(minimum: [-5, -1.5], maximum: [-4.2, -0.7]),
    .init(minimum: [4.2, 0.7], maximum: [5, 1.5]),
  ]
}

/// Rules and spatial authority for one duel. No scene objects, device input or feedback playback.
struct DuelSimulation: Sendable {
  static let fixedStep: Float = 1 / 120
  static let heroMaxHealth: Float = 100
  static let enemyMaxHealth: Float = 168
  static let maxStamina: Float = 100
  static let movementSpeed: Float = 2.8
  static let bufferWindow: Float = 0.15

  private struct BufferedAction: Sendable {
    let kind: DuelAction.Kind
    let direction: SIMD2<Float>
    var remaining: Float
  }

  private(set) var hero: DuelFighter
  private(set) var enemy: DuelFighter
  private(set) var outcome: DuelOutcome = .fighting
  private(set) var isFocused = false
  private(set) var elapsed: Float = 0
  private(set) var hitsLanded = 0
  private(set) var hitsTaken = 0
  private(set) var blocks = 0
  private(set) var evasions = 0
  private(set) var guardBreaks = 0
  private var events: [DuelEvent] = []
  private var buffered: BufferedAction?
  private var staminaDelay: Float = 0
  private var enemyCooldown: Float = 1.1
  private var nextEnemyAttack: DuelAction.Kind = .sweep
  private var enemyApproachSide: Float = 0
  private var enemyApproachTime: Float = 0
  private let collision = PartyMotion(radius: DuelArena.radius, obstacles: DuelArena.obstacles)

  init(
    heroPosition: SIMD2<Float> = DuelArena.heroSpawn,
    enemyPosition: SIMD2<Float> = DuelArena.enemySpawn,
    heroYaw: Float = 0
  ) {
    hero = DuelFighter(position: heroPosition, yaw: heroYaw, health: Self.heroMaxHealth)
    enemy = DuelFighter(position: enemyPosition, yaw: .pi, health: Self.enemyMaxHealth)
  }

  mutating func reset() { self = DuelSimulation() }

  /// Interruptions do not grant a fresh enemy attack or erase an owed recovery. The owning
  /// world freezes this simulation and requires released input before any further step.
  mutating func interrupt() {
    buffered = nil
    hero.guarding = false
    events.removeAll(keepingCapacity: true)
  }

  mutating func takeEvents() -> [DuelEvent] {
    let result = events
    events.removeAll(keepingCapacity: true)
    return result
  }

  /// The production world already supplies fixed steps. Bounded subdivision also makes direct
  /// callers cross contact/evasion windows correctly rather than skipping them on a slow frame.
  mutating func step(_ command: DuelCommand, deltaTime: Float) {
    guard deltaTime.isFinite, deltaTime > 0, outcome == .fighting else { return }
    var remaining = min(deltaTime, 0.25)
    var input = command
    while remaining > 0.000001, outcome == .fighting {
      let dt = min(remaining, Self.fixedStep)
      tick(input, dt: dt)
      input.attackPressed = false
      input.dodgePressed = false
      input.focusPressed = false
      remaining -= dt
    }
  }

  private mutating func tick(_ command: DuelCommand, dt: Float) {
    elapsed += dt
    if command.focusPressed {
      isFocused.toggle()
      buffered = nil
    }
    hero.hitFlash = max(0, hero.hitFlash - dt)
    enemy.hitFlash = max(0, enemy.hitFlash - dt)
    hero.stagger = max(0, hero.stagger - dt)
    staminaDelay = max(0, staminaDelay - dt)
    if var pending = buffered {
      pending.remaining -= dt
      buffered = pending.remaining > 0 ? pending : nil
    }

    moveHero(command, dt: dt)
    // Selecting a facing mode consumes simultaneous future combat, without cancelling an
    // existing committed swing or its owed recovery.
    if !command.focusPressed { chooseHeroAction(command) }
    chooseEnemyAction(dt: dt)
    advanceActions(dt: dt)
    resolveContacts()
    finishActions()

    if hero.action == nil, !command.guardHeld, hero.stagger == 0, staminaDelay == 0 {
      hero.stamina = min(Self.maxStamina, hero.stamina + 37 * dt)
    }
  }

  private mutating func moveHero(_ command: DuelCommand, dt: Float) {
    hero.guarding =
      command.guardHeld && hero.action == nil && hero.stagger == 0 && hero.stamina > 0
    guard hero.action == nil, hero.stagger == 0 else { return }
    let direction = Self.validMovement(command.movement)
    let speed = hero.guarding ? Self.movementSpeed * 0.4 : Self.movementSpeed
    hero.position = move(hero.position, delta: direction * speed * dt, avoiding: enemy.position)
    let facing = isFocused ? enemy.position - hero.position : hero.guarding ? .zero : direction
    if simd_length_squared(facing) > 0.0001 {
      hero.yaw = Movement.turn(
        from: hero.yaw, towards: Movement.yaw(towards: facing), limit: 5 * .pi * dt)
    }
  }

  private mutating func chooseHeroAction(_ command: DuelCommand) {
    // Dodge takes a simultaneous attack. Held guard suppresses attacks and their buffering.
    let moving = Self.validMovement(command.movement)
    let direction =
      simd_length_squared(moving) > 0.0001
      ? simd_normalize(moving) : Movement.facing(yaw: hero.yaw)
    var requested: BufferedAction?
    if command.dodgePressed {
      requested = BufferedAction(
        kind: .dodge, direction: direction, remaining: Self.bufferWindow + Self.fixedStep)
    } else if command.guardHeld {
      // Guard suppresses attacks, but an already accepted dodge keeps its higher priority
      // through the recovery handoff after the fresh Dodge edge has been consumed.
      guard buffered?.kind == .dodge else {
        buffered = nil
        return
      }
    } else if command.attackPressed {
      requested = BufferedAction(
        kind: .slash, direction: direction,
        remaining: Self.bufferWindow + Self.fixedStep)
    }

    if let action = hero.action {
      if let requested, action.phase == .recovery,
        action.duration - action.elapsed <= Self.bufferWindow
      {
        buffered = requested
      }
      return
    }
    guard hero.stagger == 0 else { return }
    guard let wanted = requested ?? buffered else { return }
    buffered = nil
    // A queued focused slash takes the current bounded facing at acceptance. After that,
    // its direction is committed, while a dodge always keeps its requested travel direction.
    let acceptedDirection =
      wanted.kind == .slash && isFocused ? Movement.facing(yaw: hero.yaw) : wanted.direction
    let action = DuelAction(kind: wanted.kind, direction: acceptedDirection)
    guard hero.stamina >= action.profile.stamina else { return }
    hero.stamina -= action.profile.stamina
    staminaDelay = 0.6
    hero.guarding = false
    hero.action = action
    if wanted.kind == .slash { hero.yaw = Movement.yaw(towards: acceptedDirection) }
  }

  private mutating func chooseEnemyAction(dt: Float) {
    guard enemy.action == nil else { return }
    enemyCooldown = max(0, enemyCooldown - dt)
    let offset = hero.position - enemy.position
    let distance = simd_length(offset)
    guard distance > 0.0001 else { return }

    // Retreating beyond the local engagement range makes room to recover; the enemy returns
    // home instead of following forever or attacking an unseen opponent at arbitrary range.
    let leashed = simd_distance(hero.position, DuelArena.enemySpawn) > 5.5
    let facing = leashed ? DuelArena.enemySpawn - enemy.position : offset
    if simd_length_squared(facing) > 0.001 {
      enemy.yaw = Movement.turn(
        from: enemy.yaw, towards: Movement.yaw(towards: facing), limit: 4 * dt)
    }
    let attackDistance: Float = nextEnemyAttack == .sweep ? 1.9 : 2.45
    var wanted = facing
    var approachReady = false
    if leashed || distance > attackDistance + 1 {
      enemyApproachSide = 0
      enemyApproachTime = 0
    } else {
      // One short lateral attempt makes the committed weapon readable. A latched side
      // avoids orbiting or alternating goals; blocked sides and moving targets cannot
      // postpone an otherwise valid attack forever.
      enemyApproachTime += dt
      let target = enemyLateralTarget(distance: attackDistance * 0.8)
      let lateral = abs(simd_dot(enemy.position - hero.position, DuelArena.screenRight))
      let separated = lateral >= attackDistance * 0.6 && lateral / distance >= 0.85
      if !separated, enemyApproachTime < 1.25, let target {
        wanted = target - enemy.position
      } else {
        approachReady = true
      }
    }
    if !leashed, distance <= attackDistance, enemyCooldown == 0,
      approachReady,
      simd_dot(Movement.facing(yaw: enemy.yaw), offset / distance) > 0.94
    {
      // Facing is committed here, before the visible preparation starts.
      enemy.action = DuelAction(kind: nextEnemyAttack, direction: offset / distance)
      enemy.yaw = Movement.yaw(towards: offset)
      enemyApproachSide = 0
      enemyApproachTime = 0
    } else if simd_length(wanted) > (leashed || !approachReady ? 0.1 : attackDistance * 0.9) {
      let speed: Float = leashed ? 1.2 : 1.6
      enemy.position = move(
        enemy.position, delta: simd_normalize(wanted) * speed * dt, avoiding: hero.position)
    }
  }

  private mutating func enemyLateralTarget(distance: Float) -> SIMD2<Float>? {
    let right = DuelArena.screenRight * distance
    if enemyApproachSide == 0 {
      let nearer: Float = simd_dot(enemy.position - hero.position, right) >= 0 ? 1 : -1
      for side in [nearer, -nearer] {
        let target = hero.position + right * side
        if canApproach(target) {
          enemyApproachSide = side
          return target
        }
      }
      return nil
    }
    let target = hero.position + right * enemyApproachSide
    return canApproach(target) ? target : nil
  }

  private func canApproach(_ target: SIMD2<Float>) -> Bool {
    guard collision.canTraverse(from: enemy.position, to: target) else { return false }
    // A route clear of scenery may still cut through the hero's occupied footprint.
    return simd_distance(
      move(enemy.position, delta: target - enemy.position, avoiding: hero.position), target) < 0.002
  }

  private mutating func advanceActions(dt: Float) {
    if var action = hero.action {
      if action.kind == .dodge {
        let travelEnd = action.profile.windup + action.profile.active
        let travel = max(0, min(action.elapsed + dt, travelEnd) - min(action.elapsed, travelEnd))
        hero.position = move(
          hero.position, delta: action.direction * (1.7 / travelEnd) * travel,
          avoiding: enemy.position)
      }
      action.previousElapsed = action.elapsed
      action.elapsed += dt
      if action.kind != .dodge, action.previousElapsed < action.profile.windup,
        action.elapsed >= action.profile.windup
      {
        emit(.swung(.hero))
      }
      hero.action = action
    }
    if var action = enemy.action {
      action.previousElapsed = action.elapsed
      action.elapsed += dt
      if action.previousElapsed < action.profile.windup, action.elapsed >= action.profile.windup {
        emit(.swung(.enemy))
      }
      enemy.action = action
    }
  }

  private mutating func resolveContacts() {
    // Both active contacts are sampled before defeat is applied, so a deliberate trade can
    // land. If the hero dies in that trade, defeat takes precedence over a victory screen.
    let heroContact = contact(from: hero, to: enemy)
    let enemyContact = contact(from: enemy, to: hero)
    if heroContact {
      hero.action?.contacted = true
      enemy.health = max(0, enemy.health - (hero.action?.profile.damage ?? 0))
      enemy.hitFlash = 0.16
      hitsLanded += 1
      emit(.hit(.enemy))
    }
    if enemyContact {
      enemy.action?.contacted = true
      if hero.action?.isInvulnerable == true {
        evasions += 1
        emit(.evaded)
      } else if blocksEnemy() {
        let cost = enemy.action?.profile.stamina ?? 0
        staminaDelay = 0.65
        if hero.stamina >= cost {
          hero.stamina -= cost
          blocks += 1
          emit(.blocked)
        } else {
          hero.stamina = 0
          hero.guarding = false
          hero.stagger = 0.5
          guardBreaks += 1
          emit(.guardBroken)
          damageHero()
        }
      } else {
        damageHero()
      }
    }
    if hero.health == 0 || enemy.health == 0 {
      outcome = hero.health == 0 ? .lost : .won
      isFocused = false
      hero.action = nil
      enemy.action = nil
      hero.guarding = false
      buffered = nil
      emit(.finished(outcome))
    }
  }

  private func contact(from attacker: DuelFighter, to target: DuelFighter) -> Bool {
    guard let action = attacker.action, action.kind != .dodge, !action.contacted,
      action.elapsed >= action.profile.windup,
      action.previousElapsed < action.profile.windup + action.profile.active
    else { return false }
    let difference = target.position - attacker.position
    let distance = simd_length(difference)
    guard distance <= action.bladeReach + DuelArena.radius,
      collision.canTraverse(from: attacker.position, to: target.position)
    else { return false }
    // Include the target disc's silhouette at the edge of the arc, rather than requiring its
    // centre to be inside a visual sword sweep. Close targets still require correct facing.
    let padding = asin(min(1, DuelArena.radius / max(distance, DuelArena.radius)))
    if distance < 0.0001 { return true }
    let relative =
      (Movement.yaw(towards: difference) - Movement.yaw(towards: action.direction))
      .remainder(dividingBy: 2 * .pi)
    if action.kind == .thrust { return abs(relative) <= action.profile.halfAngle + padding }
    let before = max(0, (action.previousElapsed - action.profile.windup) / action.profile.active)
    let after = min(1, (action.elapsed - action.profile.windup) / action.profile.active)
    let start = -action.profile.halfAngle + 2 * action.profile.halfAngle * before
    let end = -action.profile.halfAngle + 2 * action.profile.halfAngle * after
    return relative + padding >= start && relative - padding <= end
  }

  private func blocksEnemy() -> Bool {
    guard hero.guarding else { return false }
    let threat = enemy.position - hero.position
    let distance = simd_length(threat)
    return distance > 0.0001
      && simd_dot(Movement.facing(yaw: hero.yaw), threat / distance) >= cos(.pi * 0.36)
  }

  private mutating func damageHero() {
    hero.health = max(0, hero.health - (enemy.action?.profile.damage ?? 0))
    hero.hitFlash = 0.16
    hitsTaken += 1
    emit(.hit(.hero))
  }

  private mutating func finishActions() {
    if let action = hero.action, action.elapsed >= action.duration { hero.action = nil }
    if let action = enemy.action, action.elapsed >= action.duration {
      nextEnemyAttack = action.kind == .sweep ? .thrust : .sweep
      enemy.action = nil
      enemyCooldown = 0.35
    }
  }

  private func move(
    _ start: SIMD2<Float>, delta: SIMD2<Float>, avoiding other: SIMD2<Float>
  ) -> SIMD2<Float> {
    let candidate = collision.resolve(start: start, delta: delta)
    let displacement = candidate - start
    let offset = start - other
    let radius = DuelArena.radius * 2 + PartyMotion.skin
    let a = simd_length_squared(displacement)
    guard a > 0 else { return start }
    let b = simd_dot(offset, displacement)
    let c = simd_length_squared(offset) - radius * radius
    if c <= 0 { return b >= 0 ? candidate : start }
    let discriminant = b * b - a * c
    guard b < 0, discriminant >= 0 else { return candidate }
    let fraction = (-b - sqrt(discriminant)) / a
    return fraction >= 0 && fraction <= 1
      ? start + displacement * max(0, fraction - 0.001) : candidate
  }

  private mutating func emit(_ event: DuelEvent) {
    // Consumers normally drain every frame. A paused/unobserved scene cannot grow this queue.
    if events.count == 32 { events.removeFirst() }
    events.append(event)
  }

  private static func validMovement(_ movement: SIMD2<Float>) -> SIMD2<Float> {
    guard movement.x.isFinite, movement.y.isFinite else { return .zero }
    let length = simd_length(movement)
    return length > 1 ? movement / length : movement
  }
}
