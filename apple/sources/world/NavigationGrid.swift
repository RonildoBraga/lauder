import simd

/// A coarse walkability grid over the authored footprints, used to plan routes around scenery
/// (ADR 0003). It only proposes waypoints; PartyMotion still resolves every movement.
struct NavigationGrid: Sendable {
  let cellSize: Float
  let columns: Int
  let rows: Int
  /// Centre of cell (0, 0).
  private let origin: SIMD2<Float>
  private let walkable: [Bool]
  /// Walkable cells inside a passage narrower than 1.5 m along either axis.
  private let tight: [Bool]
  /// Connected walkable areas; -1 marks a blocked cell.
  private let region: [Int32]

  /// The level's floor and blockers, in 20 cm cells.
  init(level: Level) {
    let minimum = level.bounds.minimum
    let maximum = level.bounds.maximum
    precondition(minimum.x < maximum.x && minimum.y < maximum.y)
    let cellSize: Float = 0.2
    // The body's radius, the 2 mm skin and a 3 cm margin.
    let clearance = PartyBody.radius + PartyMotion.skin + 0.03
    let tightWidth: Float = 1.5
    self.cellSize = cellSize
    columns = Int(((maximum.x - minimum.x) / cellSize).rounded(.up))
    rows = Int(((maximum.y - minimum.y) / cellSize).rounded(.up))
    origin = minimum + cellSize / 2

    // A cell is walkable when every obstacle is at least `clearance` from its centre. Only the
    // cells inside an obstacle's box grown by the clearance can be closer, so each obstacle
    // checks just those: the same result as testing every cell against every obstacle, at a
    // cost that suits a long level such as the bridge.
    var walkable = [Bool](repeating: true, count: columns * rows)
    for box in level.obstacles {
      let low = (box.minimum - clearance - origin) / cellSize
      let high = (box.maximum + clearance - origin) / cellSize
      let firstColumn = max(0, Int(low.x.rounded(.up)))
      let lastColumn = min(columns - 1, Int(high.x.rounded(.down)))
      let firstRow = max(0, Int(low.y.rounded(.up)))
      let lastRow = min(rows - 1, Int(high.y.rounded(.down)))
      guard firstColumn <= lastColumn, firstRow <= lastRow else { continue }
      for row in firstRow...lastRow {
        for column in firstColumn...lastColumn where walkable[row * columns + column] {
          let centre = origin + SIMD2(Float(column), Float(row)) * cellSize
          if Self.distance(from: centre, to: box) < clearance {
            walkable[row * columns + column] = false
          }
        }
      }
    }
    self.walkable = walkable

    // A cell is tight when its contiguous walkable run along a row or a column is short:
    // walls on both sides, as in a doorway. A cell beside one long wall is not tight.
    var rowRun = [Int](repeating: 0, count: columns * rows)
    var columnRun = [Int](repeating: 0, count: columns * rows)
    for row in 0..<rows {
      var column = 0
      while column < columns {
        guard walkable[row * columns + column] else {
          column += 1
          continue
        }
        let start = column
        while column < columns && walkable[row * columns + column] { column += 1 }
        for index in start..<column { rowRun[row * columns + index] = column - start }
      }
    }
    for column in 0..<columns {
      var row = 0
      while row < rows {
        guard walkable[row * columns + column] else {
          row += 1
          continue
        }
        let start = row
        while row < rows && walkable[row * columns + column] { row += 1 }
        for index in start..<row { columnRun[index * columns + column] = row - start }
      }
    }
    let tightCells = max(1, Int((tightWidth / cellSize).rounded(.up)))
    tight = (0..<walkable.count).map {
      walkable[$0] && min(rowRun[$0], columnRun[$0]) < tightCells
    }

    var region = [Int32](repeating: -1, count: columns * rows)
    var next: Int32 = 0
    var stack: [Int] = []
    for seed in 0..<walkable.count where walkable[seed] && region[seed] < 0 {
      region[seed] = next
      stack.append(seed)
      while let cell = stack.popLast() {
        Self.forEachNeighbour(of: cell, columns: columns, rows: rows, walkable) { neighbour, _ in
          guard region[neighbour] < 0 else { return }
          region[neighbour] = next
          stack.append(neighbour)
        }
      }
      next += 1
    }
    self.region = region
  }

  func isWalkable(_ point: SIMD2<Float>) -> Bool {
    index(of: point).map { walkable[$0] } ?? false
  }

  /// Walkable and not inside a doorway-like passage: somewhere a companion may settle.
  func isRoomy(_ point: SIMD2<Float>) -> Bool {
    index(of: point).map { walkable[$0] && !tight[$0] } ?? false
  }

  func region(at point: SIMD2<Float>) -> Int32? {
    index(of: point).flatMap { region[$0] >= 0 ? region[$0] : nil }
  }

  /// The centre of the closest walkable cell within `radius` that satisfies `accept`.
  func nearestWalkable(
    to point: SIMD2<Float>, within radius: Float, region required: Int32? = nil,
    where accept: (SIMD2<Float>) -> Bool = { _ in true }
  ) -> SIMD2<Float>? {
    guard let cells = cells(around: point, within: radius) else { return nil }
    var best: (distance: Float, point: SIMD2<Float>)?
    for row in cells.rows {
      for column in cells.columns {
        let cell = row * columns + column
        guard walkable[cell], required == nil || region[cell] == required else { continue }
        let candidate = self.centre(of: cell)
        let distance = simd_distance(candidate, point)
        guard distance <= radius, best == nil || distance < best!.distance, accept(candidate)
        else { continue }
        best = (distance, candidate)
      }
    }
    return best?.point
  }

  /// The centres of the roomy cells within `radius` of `point`, taking every `stride`-th row and
  /// column counted from the grid's corner, so that nearby points share them: the spots where a
  /// companion may take cover (ADR 0003, phase S4).
  func roomySpots(within radius: Float, of point: SIMD2<Float>, stride: Int = 1) -> [SIMD2<Float>] {
    guard stride > 0, let cells = cells(around: point, within: radius) else { return [] }
    var spots: [SIMD2<Float>] = []
    for row in cells.rows where row % stride == 0 {
      for column in cells.columns where column % stride == 0 {
        let cell = row * columns + column
        guard walkable[cell], !tight[cell] else { continue }
        let candidate = centre(of: cell)
        if simd_distance(candidate, point) <= radius { spots.append(candidate) }
      }
    }
    return spots
  }

  /// The rows and columns of the cells that can lie within `radius` of `point`, clipped to the
  /// grid; nil when there are none.
  private func cells(around point: SIMD2<Float>, within radius: Float)
    -> (rows: ClosedRange<Int>, columns: ClosedRange<Int>)?
  {
    guard point.x.isFinite, point.y.isFinite else { return nil }
    let reach = Int((radius / cellSize).rounded(.up))
    let centre = cellCoordinates(of: point)
    // A point far outside the grid has no cells within reach; check before forming ranges.
    guard centre.row - reach <= rows - 1, centre.column - reach <= columns - 1,
      centre.row + reach >= 0, centre.column + reach >= 0
    else { return nil }
    return (
      max(0, centre.row - reach)...min(rows - 1, centre.row + reach),
      max(0, centre.column - reach)...min(columns - 1, centre.column + reach)
    )
  }

  /// Cell centres from near `start` to near `goal`, or nil when no connected route exists.
  /// `extraCost` adds to each metre of crossing a cell, given its centre: in a fight, ground a
  /// shooter sees costs more (ADR 0003, phase S4). The result is not straightened; see
  /// `straightened(_:isClear:)`.
  func route(
    from start: SIMD2<Float>, to goal: SIMD2<Float>,
    extraCost: ((SIMD2<Float>) -> Float)? = nil
  ) -> [SIMD2<Float>]? {
    guard let first = nearestWalkable(to: start, within: 0.6).flatMap(index(of:)),
      let last = nearestWalkable(to: goal, within: 1, region: region[first]).flatMap(index(of:))
    else { return nil }
    if first == last { return [centre(of: last)] }

    // Each cell's extra cost is worked out once in a search, when it is first reached.
    var extra = [Float](repeating: -1, count: extraCost == nil ? 0 : walkable.count)
    func weight(of cell: Int) -> Float {
      guard let extraCost else { return 1 }
      if extra[cell] < 0 { extra[cell] = max(0, extraCost(centre(of: cell))) }
      return 1 + extra[cell]
    }
    var cost = [Float](repeating: .infinity, count: walkable.count)
    var previous = [Int32](repeating: -1, count: walkable.count)
    var closed = [Bool](repeating: false, count: walkable.count)
    var open = MinimumHeap()
    cost[first] = 0
    open.push(heuristic(first, last), first)
    while let current = open.pop() {
      guard !closed[current] else { continue }
      if current == last { break }
      closed[current] = true
      Self.forEachNeighbour(of: current, columns: columns, rows: rows, walkable) {
        neighbour, step in
        guard !closed[neighbour] else { return }
        let candidate = cost[current] + step * cellSize * weight(of: neighbour)
        guard candidate < cost[neighbour] else { return }
        cost[neighbour] = candidate
        previous[neighbour] = Int32(current)
        open.push(candidate + heuristic(neighbour, last), neighbour)
      }
    }
    guard previous[last] >= 0 else { return nil }
    var cells = [last]
    while let tail = cells.last, tail != first { cells.append(Int(previous[tail])) }
    return cells.reversed().map(centre(of:))
  }

  /// Drop intermediate points wherever the straight line between kept points is clear.
  static func straightened(
    _ points: [SIMD2<Float>], isClear: (SIMD2<Float>, SIMD2<Float>) -> Bool
  ) -> [SIMD2<Float>] {
    guard points.count > 2 else { return points }
    var result = [points[0]]
    var anchor = 0
    while anchor < points.count - 1 {
      var reach = anchor + 1
      for candidate in stride(from: points.count - 1, to: anchor + 1, by: -1)
      where isClear(points[anchor], points[candidate]) {
        reach = candidate
        break
      }
      result.append(points[reach])
      anchor = reach
    }
    return result
  }

  private func index(of point: SIMD2<Float>) -> Int? {
    guard point.x.isFinite, point.y.isFinite else { return nil }
    let cell = cellCoordinates(of: point)
    guard (0..<columns).contains(cell.column), (0..<rows).contains(cell.row) else { return nil }
    return cell.row * columns + cell.column
  }

  private func cellCoordinates(of point: SIMD2<Float>) -> (column: Int, row: Int) {
    let scaled = (point - origin) / cellSize
    return (Int(scaled.x.rounded()), Int(scaled.y.rounded()))
  }

  private func centre(of cell: Int) -> SIMD2<Float> {
    origin + SIMD2(Float(cell % columns), Float(cell / columns)) * cellSize
  }

  private func heuristic(_ from: Int, _ to: Int) -> Float {
    // Octile distance: exact on an empty eight-direction grid, never an overestimate.
    let dx = Float(abs(from % columns - to % columns))
    let dy = Float(abs(from / columns - to / columns))
    return (max(dx, dy) + (Float(2).squareRoot() - 1) * min(dx, dy)) * cellSize
  }

  /// Each of a cell's eight-direction neighbours, with the length of the step to it in cells,
  /// in a fixed order: east, west, south and north, then the diagonals. A diagonal step needs
  /// both orthogonal cells walkable, so a route never cuts past a corner. It builds nothing, as
  /// a search in a fight may visit most of a level's cells.
  private static func forEachNeighbour(
    of cell: Int, columns: Int, rows: Int, _ walkable: [Bool], _ body: (Int, Float) -> Void
  ) {
    let column = cell % columns
    let row = cell / columns
    func open(_ c: Int, _ r: Int) -> Bool {
      c >= 0 && c < columns && r >= 0 && r < rows && walkable[r * columns + c]
    }
    let east = open(column + 1, row)
    let west = open(column - 1, row)
    let south = open(column, row + 1)
    let north = open(column, row - 1)
    if east { body(cell + 1, 1) }
    if west { body(cell - 1, 1) }
    if south { body(cell + columns, 1) }
    if north { body(cell - columns, 1) }
    if east && south && open(column + 1, row + 1) { body(cell + columns + 1, diagonal) }
    if east && north && open(column + 1, row - 1) { body(cell - columns + 1, diagonal) }
    if west && south && open(column - 1, row + 1) { body(cell + columns - 1, diagonal) }
    if west && north && open(column - 1, row - 1) { body(cell - columns - 1, diagonal) }
  }

  /// The length of a diagonal step, in cells.
  private static let diagonal = Float(2).squareRoot()

  private static func distance(from point: SIMD2<Float>, to box: PartyMotion.Box) -> Float {
    simd_distance(point, simd_clamp(point, box.minimum, box.maximum))
  }
}

/// A small binary heap of (priority, cell) for the route search.
private struct MinimumHeap {
  private var items: [(priority: Float, cell: Int)] = []

  mutating func push(_ priority: Float, _ cell: Int) {
    items.append((priority, cell))
    var child = items.count - 1
    while child > 0 {
      let parent = (child - 1) / 2
      guard items[child].priority < items[parent].priority else { break }
      items.swapAt(child, parent)
      child = parent
    }
  }

  mutating func pop() -> Int? {
    guard let top = items.first else { return nil }
    let last = items.removeLast()
    if !items.isEmpty {
      items[0] = last
      var parent = 0
      while true {
        let left = parent * 2 + 1
        let right = left + 1
        var smallest = parent
        if left < items.count && items[left].priority < items[smallest].priority {
          smallest = left
        }
        if right < items.count && items[right].priority < items[smallest].priority {
          smallest = right
        }
        guard smallest != parent else { break }
        items.swapAt(parent, smallest)
        parent = smallest
      }
    }
    return top.cell
  }
}
