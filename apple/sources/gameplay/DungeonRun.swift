import simd

enum DungeonEvent: Equatable, Sendable {
  case combat(DuelEvent)
  case encounterStarted(Int)
  case encounterCleared(Int)
  case healed(Float)
  case shortcutOpened
  case finished(DuelOutcome)
}

/// Route progress wraps the same combat owner; it does not copy hero state or advance another clock.
struct DungeonRun: Sendable {
  private(set) var simulation: DuelSimulation
  private(set) var activeEncounter: Int?
  private(set) var clearedEncounters: Set<Int> = []
  private(set) var healingUsed = false
  private(set) var shortcutOpen: Bool
  private var events: [DungeonEvent] = []

  var hero: DuelFighter { simulation.hero }
  var enemy: DuelFighter? { activeEncounter == nil ? nil : simulation.enemy }
  var outcome: DuelOutcome { simulation.outcome }
  var isFocused: Bool { simulation.isFocused }

  /// An idle guard can be seen before engagement; hidden/distant rooms expose no actor.
  var visibleEnemy: DuelFighter? {
    if let enemy { return enemy }
    guard outcome == .fighting, let next = nextEncounter,
      simd_distance(hero.position, next.home) <= 7,
      simulation.hasClearPath(to: next.home)
    else { return nil }
    return DuelFighter(
      position: next.home, yaw: Movement.yaw(towards: hero.position - next.home),
      health: DuelSimulation.enemyMaxHealth)
  }

  var objective: String {
    if outcome == .lost { return "Return to the entry and try again." }
    if outcome == .won { return "Dungeon route complete." }
    if let activeEncounter {
      return activeEncounter == 0 ? "Defeat the first sentry." : "Defeat the second sentry."
    }
    if clearedEncounters.isEmpty { return "Follow the corridor to the first chamber." }
    if clearedEncounters.count == 1 { return "Take the western passage to the second chamber." }
    return "Reach the western exit. The northern passage opens a shortcut home."
  }

  private var nextEncounter: DungeonLayout.Encounter? {
    DungeonLayout.encounters.first { !clearedEncounters.contains($0.id) }
  }

  init() { self.init(shortcutOpen: false) }

  private init(shortcutOpen: Bool) {
    self.shortcutOpen = shortcutOpen
    simulation = DuelSimulation(
      heroPosition: DungeonLayout.heroSpawn,
      obstacles: DungeonLayout.obstacles(shortcutOpen: shortcutOpen),
      enemyEnabled: false, endsOnEnemyDefeat: false)
  }

  /// Death restarts encounters and the recovery find, retaining only the discovered shortcut.
  mutating func retry() { self = DungeonRun(shortcutOpen: shortcutOpen) }

  /// Pause's Restart begins a fresh run, including its shortcut and recovery find.
  mutating func restart() { self = DungeonRun() }

  mutating func interrupt() {
    simulation.interrupt()
    events.removeAll(keepingCapacity: true)
  }

  mutating func takeEvents() -> [DungeonEvent] {
    let result = events
    events.removeAll(keepingCapacity: true)
    return result
  }

  mutating func step(_ command: DuelCommand, deltaTime: Float) {
    guard outcome == .fighting, deltaTime.isFinite, deltaTime > 0 else { return }
    // A slow direct caller must observe the same doorway/find crossings as GameWorld's
    // fixed ticks. The combat owner remains the only clock; route progress follows each tick.
    var remaining = min(deltaTime, 0.25)
    var input = command
    while remaining > 0.000001, outcome == .fighting {
      let dt = min(remaining, DuelSimulation.fixedStep)
      tick(input, deltaTime: dt)
      input.attackPressed = false
      input.dodgePressed = false
      input.focusPressed = false
      remaining -= dt
    }
  }

  private mutating func tick(_ command: DuelCommand, deltaTime: Float) {
    simulation.step(command, deltaTime: deltaTime)
    collectCombatEvents()
    guard outcome == .fighting else { return }
    if let id = activeEncounter, simulation.enemy.health == 0 {
      clearedEncounters.insert(id)
      activeEncounter = nil
      emit(.encounterCleared(id))
    }
    if activeEncounter == nil, let next = nextEncounter, next.activation.contains(hero.position) {
      simulation.beginEncounter(at: next.home, leash: next.leash, firstAttack: next.firstAttack)
      activeEncounter = next.id
      emit(.encounterStarted(next.id))
    }
    if !healingUsed, activeEncounter == nil, DungeonLayout.healingArea.contains(hero.position) {
      let recovered = simulation.heal(40)
      if recovered > 0 {
        healingUsed = true
        emit(.healed(recovered))
      }
    }
    if !shortcutOpen, DungeonLayout.shortcutOpening.contains(hero.position) {
      shortcutOpen = true
      simulation.setObstacles(DungeonLayout.obstacles(shortcutOpen: true))
      emit(.shortcutOpened)
    }
    if clearedEncounters.count == DungeonLayout.encounters.count,
      DungeonLayout.exitArea.contains(hero.position)
    {
      simulation.complete()
      collectCombatEvents()
    }
  }

  private mutating func collectCombatEvents() {
    for event in simulation.takeEvents() {
      if case .finished(let result) = event {
        emit(.finished(result))
      } else {
        emit(.combat(event))
      }
    }
  }

  private mutating func emit(_ event: DungeonEvent) {
    if events.count == 32 { events.removeFirst() }
    events.append(event)
  }
}
