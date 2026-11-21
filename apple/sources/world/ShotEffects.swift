import RealityKit
import simd

/// What shots look like (ADR 0007), in low-poly blocks of the palette's colours: a streak that
/// flies from the muzzle to where the shot strikes, a flash at the muzzle and where it strikes,
/// chips that fly back off a block, and a mark that stays on the block a few seconds. Every block
/// is made once, at load, and reused, so firing builds nothing, and only effects under way move.
@MainActor
final class ShotEffects {
  /// Whose shot it is: the party's, in amber, or a hostile's, in the threat's red.
  enum Side {
    case party, hostile
  }

  /// How fast a streak flies, in metres a second, and its longest length.
  static let streakSpeed: Float = 80
  static let streakLength: Float = 2.5
  /// How long a flash shows, chips fly and a mark stays, in seconds.
  static let flashTime: Float = 0.06
  static let chipTime: Float = 0.4
  static let markTime: Float = 4
  /// How many chips each strike on a block flings.
  static let chipsPerStrike = 4

  /// Blocks of one look, reused in turn; when all are in use, the oldest is taken.
  private struct Pool {
    let entities: [ModelEntity]
    private var next = 0

    init(_ count: Int, make: () -> ModelEntity) {
      entities = (0..<count).map { _ in make() }
    }

    mutating func take() -> Int {
      defer { next = (next + 1) % entities.count }
      return next
    }
  }

  private struct Streak {
    var from: SIMD3<Float> = .zero
    var direction: SIMD3<Float> = [0, 0, 1]
    var distance: Float = 0
    var travelled: Float = 0
    var active = false
  }

  private struct Chip {
    var position: SIMD3<Float> = .zero
    var velocity: SIMD3<Float> = .zero
    var remaining: Float = 0
  }

  private var streakPools: [Side: Pool]
  private var streaks: [Side: [Streak]]
  private var flashPools: [Side: Pool]
  private var flashRemaining: [Side: [Float]]
  private var chipPool: Pool
  private var chips: [Chip]
  private var markPool: Pool
  private var markRemaining: [Float]
  private let thickness: [Side: Float]
  private let flashSize: Float
  private let chipSize: Float

  /// How many marks show on blocks now. Tests read it.
  var marksShown: Int { markRemaining.filter { $0 > 0 }.count }

  /// The effects' blocks, unseen until a shot shows them, in `container`; `style` gives their
  /// colours, and its marker scale their size, so they read from the level's camera.
  init(style: SceneStyle, in container: Entity) {
    let scale = style.markerScale
    thickness = [.party: 0.06 * scale, .hostile: 0.045 * scale]
    flashSize = 0.16 * scale
    chipSize = 0.06 * scale
    func block(_ name: String, _ material: any Material) -> ModelEntity {
      let entity = style.block(size: [1, 1, 1], at: .zero, material: material)
      entity.name = name
      entity.isEnabled = false
      container.addChild(entity)
      return entity
    }
    var streakPools: [Side: Pool] = [:]
    var flashPools: [Side: Pool] = [:]
    for side in [Side.party, .hostile] {
      let party = side == .party
      let material = party ? style.warm : style.threat
      let name = party ? "party" : "hostile"
      streakPools[side] = Pool(party ? 6 : 4) { block("\(name).streak", material) }
      flashPools[side] = Pool(party ? 6 : 4) { block("\(name).flash", material) }
    }
    self.streakPools = streakPools
    self.flashPools = flashPools
    streaks = streakPools.mapValues { Array(repeating: Streak(), count: $0.entities.count) }
    flashRemaining = flashPools.mapValues { Array(repeating: 0, count: $0.entities.count) }
    chipPool = Pool(24) { block("shot.chip", style.ink) }
    chips = Array(repeating: Chip(), count: 24)
    markPool = Pool(12) { block("shot.mark", style.ink) }
    markRemaining = Array(repeating: 0, count: 12)
    let markSize = 0.12 * scale
    for mark in markPool.entities { mark.scale = [markSize, markSize, 0.01] }
  }

  /// Shows a shot fired at `height`: a streak along its path, a flash at the muzzle, and what
  /// it strikes: a flash on a body, or chips, a flash and a mark on a block. A shot from a weapon
  /// the figure shows starts at its `muzzle`; others start just ahead of the shooter.
  func show(_ path: ShotPath, side: Side, height: Float, muzzle: SIMD2<Float>? = nil) {
    let start = muzzle ?? path.start
    let from = SIMD3(start.x, height, start.y)
    let to = SIMD3(path.end.x, height, path.end.y)
    let span = to - from
    let distance = simd_length(span)
    let direction = distance > 0.001 ? span / distance : SIMD3<Float>(0, 0, 1)
    if var pool = streakPools[side], var list = streaks[side] {
      let index = pool.take()
      list[index] = Streak(
        from: from, direction: direction, distance: distance, travelled: 0, active: true)
      streakPools[side] = pool
      streaks[side] = list
      place(streak: list[index], pool.entities[index], side: side)
    }
    // The flash shows at the muzzle, or just ahead of a shooter that shows no weapon.
    flash(at: muzzle == nil ? from + direction * 0.3 : from, side: side, size: flashSize)
    switch path.strike {
    case .body: flash(at: to, side: side, size: flashSize * 1.4)
    case .scenery: strike(at: to, from: direction, side: side)
    case .nothing: break
    }
  }

  /// One frame: streaks fly on, flashes go out, chips fall and marks fade from sight.
  func update(dt: Float) {
    for side in [Side.party, .hostile] {
      guard let pool = streakPools[side], var list = streaks[side] else { continue }
      for index in list.indices where list[index].active {
        list[index].travelled += Self.streakSpeed * dt
        if list[index].travelled - Self.streakLength >= list[index].distance {
          list[index].active = false
          pool.entities[index].isEnabled = false
        } else {
          place(streak: list[index], pool.entities[index], side: side)
        }
      }
      streaks[side] = list
      if let flashes = flashPools[side], var remaining = flashRemaining[side] {
        for index in remaining.indices where remaining[index] > 0 {
          remaining[index] -= dt
          if remaining[index] <= 0 { flashes.entities[index].isEnabled = false }
        }
        flashRemaining[side] = remaining
      }
    }
    for index in chips.indices where chips[index].remaining > 0 {
      chips[index].remaining -= dt
      chips[index].velocity.y -= 9.8 * dt
      chips[index].position += chips[index].velocity * dt
      let entity = chipPool.entities[index]
      if chips[index].remaining <= 0 || chips[index].position.y < 0 {
        chips[index].remaining = 0
        entity.isEnabled = false
      } else {
        entity.position = chips[index].position
        let size = chipSize * chips[index].remaining / Self.chipTime
        entity.scale = [size, size, size]
      }
    }
    for index in markRemaining.indices where markRemaining[index] > 0 {
      markRemaining[index] -= dt
      if markRemaining[index] <= 0 { markPool.entities[index].isEnabled = false }
    }
  }

  /// Every effect out of sight, as when a fight starts again.
  func clear() {
    for side in [Side.party, .hostile] {
      streaks[side] = streaks[side]?.map { _ in Streak() }
      flashRemaining[side] = flashRemaining[side]?.map { _ in 0 }
      for entity in (streakPools[side]?.entities ?? []) + (flashPools[side]?.entities ?? []) {
        entity.isEnabled = false
      }
    }
    chips = chips.map { _ in Chip() }
    markRemaining = markRemaining.map { _ in 0 }
    for entity in chipPool.entities + markPool.entities { entity.isEnabled = false }
  }

  /// A streak's block from its tail to its head, both on the shot's path.
  private func place(streak: Streak, _ entity: ModelEntity, side: Side) {
    let head = min(streak.travelled, streak.distance)
    let tail = max(0, min(streak.travelled - Self.streakLength, streak.distance))
    let length = max(head - tail, 0.05)
    let width = thickness[side] ?? 0.1
    entity.position = streak.from + streak.direction * (head + tail) / 2
    entity.scale = [width, width, length]
    entity.orientation = simd_quatf(from: [0, 0, 1], to: streak.direction)
    entity.isEnabled = true
  }

  /// A flash, turned on its corner so it reads as a spark, for a moment.
  private func flash(at point: SIMD3<Float>, side: Side, size: Float) {
    guard var pool = flashPools[side], var remaining = flashRemaining[side] else { return }
    let index = pool.take()
    flashPools[side] = pool
    remaining[index] = Self.flashTime
    flashRemaining[side] = remaining
    let entity = pool.entities[index]
    entity.position = point
    entity.scale = [size, size, size]
    entity.orientation = simd_quatf(angle: .pi / 4, axis: simd_normalize([1, 1, 0]))
    entity.isEnabled = true
  }

  /// A shot striking a block: a small flash, chips flung back towards the shooter and up, and
  /// a mark on the block's face, turned to the shooter.
  private func strike(at point: SIMD3<Float>, from direction: SIMD3<Float>, side: Side) {
    flash(at: point - direction * 0.05, side: side, size: flashSize * 0.8)
    let back = -direction
    let across = SIMD3(-back.z, 0, back.x)
    for _ in 0..<Self.chipsPerStrike {
      let index = chipPool.take()
      let velocity =
        back * Float.random(in: 1.5...3.5) + across * Float.random(in: -2...2)
        + [0, Float.random(in: 1.5...3.5), 0]
      chips[index] = Chip(
        position: point + back * 0.05, velocity: velocity, remaining: Self.chipTime)
      let entity = chipPool.entities[index]
      entity.position = chips[index].position
      entity.scale = [chipSize, chipSize, chipSize]
      entity.isEnabled = true
    }
    let index = markPool.take()
    markRemaining[index] = Self.markTime
    let mark = markPool.entities[index]
    mark.position = point + back * 0.02
    mark.orientation = simd_quatf(from: [0, 0, 1], to: back)
    mark.isEnabled = true
  }
}
