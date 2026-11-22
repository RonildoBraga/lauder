import simd

/// The combat test reuses a finite set of authored actors. This planner owns only cadence and
/// safe arrival warnings; the fight owns actors, damage, projectiles and the actual spawn.
struct ArenaWaves {
  struct Slot: Equatable, Sendable {
    let id: String
    let point: SIMD2<Float>
  }

  struct Configuration: Sendable {
    let slots: [Slot]
    var maxActive = 4
    var warningDuration: Float = 2
    var intermission: Float = 4
    var minimumDistance: Float = 8
  }

  enum Phase: Equatable {
    case preparing
    case fighting
    case recovering
  }

  struct Update {
    var spawn: [String] = []
    var resupply = false
  }

  private let config: Configuration
  private(set) var wave = 1
  private(set) var phase = Phase.preparing
  private(set) var activeIDs: Set<String> = []
  /// Remaining seconds on the visible arrival markers. These IDs are not yet targetable.
  private(set) var warnings: [String: Float] = [:]
  private var issuedIDs: Set<String> = []
  private var recovery: Float = 0
  private var rotation = 0
  private var needsResupply = false

  init(config: Configuration) {
    precondition(!config.slots.isEmpty && Set(config.slots.map(\.id)).count == config.slots.count)
    precondition(config.maxActive > 0 && config.warningDuration > 0 && config.intermission > 0)
    precondition(config.warningDuration.isFinite && config.intermission.isFinite)
    precondition(config.minimumDistance > 0 && config.minimumDistance.isFinite)
    precondition(config.slots.allSatisfy { $0.point.x.isFinite && $0.point.y.isFinite })
    self.config = config
  }

  /// Alternate three- and four-actor packs, varying the composition without increasing health
  /// or retaining an encounter history. The fixed pool supplies the cap even for bad settings.
  var packSize: Int { min(config.maxActive, config.slots.count, wave.isMultiple(of: 2) ? 4 : 3) }

  mutating func reset() {
    wave = 1
    phase = .preparing
    activeIDs = []
    warnings = [:]
    issuedIDs = []
    recovery = 0
    rotation = 0
    needsResupply = false
  }

  /// A fallback retries the same pack number after a breather, with fresh resources. Restart
  /// uses reset() instead. The fight clears the pool's damage and disables its actors first.
  mutating func retry() {
    phase = .recovering
    activeIDs = []
    warnings = [:]
    issuedIDs = []
    recovery = config.intermission
    needsResupply = true
  }

  /// Call only during live exploration. No wall clock or asynchronous work can advance a
  /// warning while paused. The final safety check is repeated when a warning expires, so a
  /// party member entering the marker cancels it and a different slot gets a fresh warning.
  /// canFinishWave keeps the pack alive until its projectiles have finished.
  mutating func step(
    dt: Float, defeated: Set<String>, party: [SIMD2<Float>], canFinishWave: Bool = true,
    canSpawn: (Slot) -> Bool = { _ in true }
  ) -> Update {
    guard dt.isFinite, dt > 0, !party.isEmpty,
      party.allSatisfy({ $0.x.isFinite && $0.y.isFinite })
    else { return Update() }
    var update = Update(resupply: needsResupply)
    needsResupply = false
    activeIDs.subtract(defeated)

    if phase == .recovering {
      recovery = max(0, recovery - dt)
      guard recovery == 0 else { return update }
      phase = .preparing
    }

    if issuedIDs.count == packSize && activeIDs.isEmpty && warnings.isEmpty && canFinishWave {
      let completedPack = packSize
      wave = wave == Int.max ? wave : wave + 1
      rotation = (rotation + completedPack) % config.slots.count
      phase = .recovering
      recovery = config.intermission
      issuedIDs = []
      update.resupply = true
      return update
    }

    let minimumDistance = config.minimumDistance
    func safe(_ slot: Slot) -> Bool {
      party.allSatisfy { simd_distance($0, slot.point) >= minimumDistance } && canSpawn(slot)
    }

    // Only warnings present before this step age. A new marker always receives its full
    // telegraph, even after an unusually long frame or the end of an intermission.
    for slot in config.slots where warnings[slot.id] != nil {
      guard safe(slot) else {
        warnings.removeValue(forKey: slot.id)
        continue
      }
      let remaining = max(0, warnings[slot.id, default: config.warningDuration] - dt)
      if remaining == 0 {
        warnings.removeValue(forKey: slot.id)
        activeIDs.insert(slot.id)
        issuedIDs.insert(slot.id)
        update.spawn.append(slot.id)
      } else {
        warnings[slot.id] = remaining
      }
    }

    // Scan once through the fixed pool. Unsafe entries defer their arrival rather than pop
    // into a party member or grow a queue. Other safe slots can replace a cancelled warning.
    for offset in 0..<config.slots.count {
      guard issuedIDs.count + warnings.count < packSize,
        activeIDs.count + warnings.count < config.maxActive
      else { break }
      let slot = config.slots[(rotation + offset) % config.slots.count]
      guard !issuedIDs.contains(slot.id), warnings[slot.id] == nil, safe(slot) else { continue }
      warnings[slot.id] = config.warningDuration
    }
    if issuedIDs.count == packSize { phase = .fighting }
    return update
  }
}
