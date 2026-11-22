import RealityKit
import Testing
import simd

@testable import Lauder

/// Reusing geometry must not reuse a run, accept a stale layout, or grow without a bound.
@MainActor
struct NavigationCacheTests {
  @Test
  func geometryCanBeReusedWhileStoryAndIdentityChange() {
    let cache = NavigationCache()
    let first = cache.prepare(for: yard(id: "first"))
    var changed = yard(id: "another-name")
    changed.startingAmmo = 17
    changed.combat.leaderCover = true
    #expect(cache.prepare(for: changed) === first)
    #expect(first.start.grid.isWalkable([2, 0]))
    #expect(first.start.grid.route(from: [-2, 0], to: [2, 0]) != nil)
  }

  @Test
  func theSameNameCannotReuseDifferentBoundsOrBlockers() {
    let cache = NavigationCache()
    let first = cache.prepare(for: yard())
    let blocked = cache.prepare(for: yard(block: true))
    #expect(blocked !== first)
    #expect(!blocked.start.grid.isWalkable([2, 0]))
    #expect(first.start.grid.isWalkable([2, 0]))
    let larger = cache.prepare(for: yard(width: 12))
    #expect(larger !== first)
    #expect(larger.start.grid.isWalkable([5, 0]))
    #expect(!first.start.grid.isWalkable([5, 0]))
  }

  @Test
  func onlyFourRecentlyUsedGeometriesStayPrepared() {
    let cache = NavigationCache()
    let first = cache.prepare(for: yard(width: 8))
    let second = cache.prepare(for: yard(width: 10))
    let third = cache.prepare(for: yard(width: 12))
    let fourth = cache.prepare(for: yard(width: 14))
    #expect(cache.prepare(for: yard(width: 8)) === first)
    _ = cache.prepare(for: yard(width: 16))
    #expect(cache.prepare(for: yard(width: 8)) === first)
    #expect(cache.prepare(for: yard(width: 12)) === third)
    #expect(cache.prepare(for: yard(width: 14)) === fourth)
    // The second, not the recently visited first or third, was the least recent.
    #expect(cache.prepare(for: yard(width: 10)) !== second)
  }

  @Test
  func bothGatePositionsArePreparedAndGateChangesInvalidateThem() throws {
    let cache = NavigationCache()
    let level = SalvageYard.level
    let prepared = cache.prepare(for: level)
    let open = try #require(prepared.gateOpen)
    let inside: SIMD2<Float> = [0, -8]
    let entrance = level.spawn(.miki)
    #expect(prepared.start.grid.region(at: inside) != prepared.start.grid.region(at: entrance))
    #expect(open.grid.region(at: inside) == open.grid.region(at: entrance))
    #expect(prepared.start.grid.isWalkable([-1, -5]))
    #expect(!open.grid.isWalkable([-1, -5]))
    // Removing a gate or changing its footprint must not reuse either old route grid.
    var ungated = level
    ungated.salvage = nil
    #expect(cache.prepare(for: ungated) !== prepared)
    let task = try #require(level.salvage)
    var movedGate = level
    movedGate.salvage = Level.Salvage(
      gate: Level.Box(
        name: task.gate.name, position: task.gate.position + [1, 0, 0], size: task.gate.size),
      latch: task.latch, panel: task.panel, latchMark: task.latchMark, panelMark: task.panelMark,
      cabinets: task.cabinets, transmitter: task.transmitter, aerial: task.aerial,
      transmitterApproach: task.transmitterApproach, doneObjective: task.doneObjective)
    #expect(cache.prepare(for: movedGate) !== prepared)
  }

  @Test
  func revisitingPreparedGeometryCreatesAFreshRunAndKeepsOnlyPreferences() throws {
    let game = Game(level: SalvageYard.level)
    let first = game.world
    first.toggleVibration()
    first.controls.useTouchControls()
    // Open the gate as Laura, then leave a run with live progress and a different leader.
    first.session.cycleLeader()
    first.session.cycleLeader()
    #expect(first.session.leader == .laura)
    _ = first.session.performSalvage(at: .latch)
    #expect(first.session.salvage.gateOpen)
    game.play(CombatYard.level)
    game.play(SalvageYard.level)
    let fresh = game.world
    #expect(fresh !== first && fresh.session !== first.session && fresh.controls !== first.controls)
    #expect(fresh.root !== first.root)
    #expect(fresh.session.leader == .miki && fresh.session.mode == .exploring)
    #expect(!fresh.session.salvage.gateOpen && fresh.session.salvage.known.isEmpty)
    #expect(fresh.session.salvage.regulators.isEmpty && fresh.session.orders.isEmpty)
    #expect(!fresh.vibrationEnabled && fresh.controls.prefersTouch)
    #expect(fresh.controls.needsNeutralInput)
    #expect(position(fresh, .miki) == SalvageYard.level.spawn(.miki))
    #expect(count(fresh.root) == count(first.root))
    // Held input arriving with the new world remains gated until neutral, as before reuse.
    let held = fresh.controls.resolve(InputRules.Raw(up: true), mode: .exploring)
    #expect(held.movement == .zero && fresh.controls.needsNeutralInput)
  }

  private func yard(id: String = "cache-yard", width: Float = 8, block: Bool = false) -> Level {
    Level(
      id: id,
      ground: Level.Box(name: "ground", position: [0, -0.15, 0], size: [width, 0.3, 8]),
      boxes: block ? [Level.Box(name: "block", position: [2, 0.5, 0], size: [1, 1, 1])] : [],
      interactions: [], triggers: [], party: [.miki],
      spawns: [.miki: .zero, .tom: [-1, 1], .laura: [1, 1]], heading: [0, -1],
      cameraOffset: [0, 10, 10], fieldOfView: 42, opening: "A yard.", objective: "Explore.",
      lookAround: "Ground.", restartNote: "Restart.")
  }
}
