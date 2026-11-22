import simd

/// Immutable movement geometry prepared for a level, including both salvage-gate positions.
/// A fresh world may reuse these values; sessions, routes, entities and controls never live here.
@MainActor
final class WorldNavigation {
  typealias Way = (motion: PartyMotion, grid: NavigationGrid)

  /// Only geometry affects navigation. Names, story progress and camera settings do not.
  struct Geometry: Equatable {
    struct Footprint: Equatable {
      let minimum: SIMD2<Float>
      let maximum: SIMD2<Float>

      init(_ box: PartyMotion.Box) {
        minimum = box.minimum
        maximum = box.maximum
      }
    }

    let bounds: Footprint
    let obstacles: [Footprint]
    let shutGate: Footprint?
    let openGate: Footprint?

    init(level: Level) {
      bounds = Footprint(level.bounds)
      obstacles = level.obstacles.map(Footprint.init)
      shutGate = level.salvage.map { Footprint($0.gate.footprint) }
      openGate = level.salvage.map { Footprint($0.openGate) }
    }
  }

  let geometry: Geometry
  let start: Way
  let gateOpen: Way?

  init(level: Level) {
    geometry = Geometry(level: level)
    func ways(adding gate: [PartyMotion.Box]) -> Way {
      (
        PartyMotion(radius: PartyBody.radius, obstacles: level.obstacles + gate),
        NavigationGrid(level: level, adding: gate)
      )
    }
    start = ways(adding: level.salvage.map { [$0.gate.footprint] } ?? [])
    gateOpen = level.salvage.map { ways(adding: [$0.openGate]) }
  }
}

/// The game's three current venues fit here. Least-recently-used geometry is discarded if a
/// fourth arrives, so arbitrary levels cannot retain an unbounded collection of large grids.
@MainActor
final class NavigationCache {
  static let capacity = 3
  private var entries: [WorldNavigation] = []

  func prepare(for level: Level) -> WorldNavigation {
    let geometry = WorldNavigation.Geometry(level: level)
    if let index = entries.firstIndex(where: { $0.geometry == geometry }) {
      let prepared = entries.remove(at: index)
      entries.append(prepared)
      return prepared
    }
    let prepared = WorldNavigation(level: level)
    if entries.count == Self.capacity { entries.removeFirst() }
    entries.append(prepared)
    return prepared
  }
}
