import RealityKit
import simd

@MainActor
enum SceneDressing {
  static let wallCapHeight: Float = 0.08
  static let planterSize: SIMD3<Float> = [0.42, 0.16, 0.35]
  static let planterPlacements: [PlanterPlacement] = [
    PlanterPlacement(support: .westBoundary, offset: [0, 4.7]),
    PlanterPlacement(support: .shelterBack, offset: [3.2, 0]),
    PlanterPlacement(support: .depotBack, offset: [2.6, 0]),
    PlanterPlacement(support: .depotBack, offset: [-2.6, 0]),
    PlanterPlacement(support: .southBoundary, offset: [13, 0]),
  ]

  @MainActor
  struct PlanterPlacement {
    let support: RelayHouse.BoxID
    let offset: SIMD2<Float>

    var basePosition: SIMD3<Float> {
      let wall = RelayHouse.box(support)
      return wall.position + [offset.x, wall.size.y / 2 + wallCapHeight, offset.y]
    }
  }

  /// Decoration that blocks nothing: the level's authored boxes carry all collision.
  static func add(to root: Entity, style: SceneStyle, level: Level.ID) {
    let dressing = Entity()
    dressing.name = "scene-dressing"
    root.addChild(dressing)
    let geometry = Geometry(root: dressing, style: style)
    switch level {
    case .relayHouse:
      addPaving(using: geometry)
      addWallCaps(using: geometry)
      addShelterDetails(using: geometry)
      addDepotDetails(using: geometry)
      addVegetationAndDebris(using: geometry)
      addWreckDetails(using: geometry)
    case .brooklynBridge:
      addRiver(using: geometry)
      addLaneLines(using: geometry)
      addTowerTops(using: geometry)
      addWalkway(using: geometry)
      addCables(using: geometry)
    }
  }

  private static func addPaving(using geometry: Geometry) {
    // These shallow slabs are decoration above the floor, not authored movement obstacles.
    for x: Float in [-10, -7.5, -5, -2.5, 0, 2.5, 5, 7.5, 10] {
      geometry.box(
        "street-slab", size: [2.32, 0.012, 2.3], at: [x, 0.009, 3.35],
        material: geometry.style.stone)
    }
    for z: Float in [-0.5, -2.5, -4.5] {
      geometry.box(
        "service-slab", size: [1.3, 0.012, 1.8], at: [2.7, 0.009, z],
        material: geometry.style.stone)
    }
    geometry.box(
      "service-threshold", size: [2.1, 0.014, 1.4], at: [3.95, 0.01, -4.5],
      material: geometry.style.stone)
    for x: Float in [5.2, 7.2, 9.2] {
      for z: Float in [-5.8, -3.8] {
        geometry.box(
          "depot-slab", size: [1.85, 0.012, 1.85], at: [x, 0.009, z],
          material: geometry.style.stone)
      }
    }
  }

  private static func addWallCaps(using geometry: Geometry) {
    for wall in RelayHouse.boxes where wall.wallCap {
      geometry.box(
        "\(wall.name)-cap", size: [wall.size.x, wallCapHeight, wall.size.z],
        at: wall.position + [0, wall.size.y / 2 + wallCapHeight / 2, 0],
        material: geometry.style.wallCap)
    }
  }

  private static func addShelterDetails(using geometry: Geometry) {
    let wall = RelayHouse.box(.shelterBack)
    let style = geometry.style
    let face = wall.position.z + wall.size.z / 2 + 0.045
    let window: SIMD3<Float> = [wall.position.x - 1.6, 0.58, face]
    geometry.box(
      "window-frame", size: [1.8, 0.5, 0.08], at: window, material: style.metal)
    geometry.box(
      "window-warmth", size: [1.48, 0.3, 0.025], at: window + [0, 0, 0.052],
      material: style.warm)
    geometry.box(
      "window-mullion", size: [0.065, 0.32, 0.035], at: window + [0, 0, 0.07],
      material: style.metal)
    geometry.box(
      "window-sill", size: [1.95, 0.07, 0.18], at: window + [0, -0.27, 0.025],
      material: style.wallCap)

    let mast: SIMD3<Float> = [wall.position.x - 2.7, 1.2, wall.position.z]
    geometry.cylinder(
      "antenna-mast", size: [0.055, 1.9, 0.055], at: mast, material: style.metal)
    geometry.box(
      "antenna-crossbar", size: [1.1, 0.035, 0.035], at: mast + [0, 0.65, 0],
      material: style.metal)
    geometry.box(
      "antenna-receiver", size: [0.035, 0.45, 0.035], at: mast + [0.37, 0.65, 0],
      material: style.rust)

    let sign: SIMD3<Float> = [wall.position.x + 2, 0.58, face + 0.015]
    geometry.box(
      "relay-sign", size: [0.75, 0.48, 0.05], at: sign, material: style.cloth)
    for index in 0..<3 {
      let height: Float = 0.12 + Float(index) * 0.08
      geometry.box(
        "relay-symbol", size: [0.08, height, 0.025],
        at: sign + [Float(index - 1) * 0.18, -0.15 + height / 2, 0.04],
        material: style.warm)
    }
    let patch: SIMD3<Float> = [wall.position.x + 0.2, 0.53, face + 0.005]
    geometry.box(
      "shelter-patch", size: [0.8, 0.38, 0.03], at: patch, material: style.cloth)
    geometry.box(
      "patch-strap", size: [0.95, 0.035, 0.04], at: patch + [0, 0, 0.025],
      material: style.rust, rotation: simd_quatf(angle: -0.18, axis: [0, 0, 1]))
  }

  private static func addDepotDetails(using geometry: Geometry) {
    let style = geometry.style
    let back = RelayHouse.box(.depotBack)
    let backFace = back.position.z + back.size.z / 2 + 0.035
    for x: Float in [-2.25, -0.75, 0.75, 2.25] {
      geometry.box(
        "depot-panel", size: [1.32, 0.72, 0.035],
        at: [back.position.x + x, 0.58, backFace], material: style.metal)
    }
    for x: Float in [-2.95, -1.5, 0, 1.5, 2.95] {
      geometry.box(
        "depot-seam", size: [0.045, 0.92, 0.065],
        at: [back.position.x + x, 0.55, backFace + 0.025], material: style.rust)
    }
    let side = RelayHouse.box(.depotEast)
    let sideFace = side.position.x + side.size.x / 2 + 0.035
    for z: Float in [-1.8, 0, 1.8] {
      geometry.box(
        "depot-side-panel", size: [0.035, 0.7, 1.55],
        at: [sideFace, 0.58, side.position.z + z], material: style.metal)
    }
    for z: Float in [-0.9, 0.9] {
      geometry.box(
        "depot-side-seam", size: [0.065, 0.92, 0.045],
        at: [sideFace + 0.025, 0.55, side.position.z + z], material: style.rust)
    }
    let entrance = RelayHouse.box(.blockedEntrance)
    let entranceFace = entrance.position.z + entrance.size.z / 2 + 0.035
    let panel: SIMD3<Float> = [entrance.position.x, 0.6, entranceFace]
    geometry.box(
      "damaged-access-panel", size: [1.45, 0.4, 0.07], at: panel, material: style.metal,
      rotation: simd_quatf(angle: 0.08, axis: [0, 0, 1]))
    for x: Float in [-0.45, 0, 0.45] {
      geometry.box(
        "access-panel-rib", size: [0.05, 0.32, 0.1], at: panel + [x, 0, 0.035],
        material: style.rust)
    }
    geometry.box(
      "damaged-status-strip", size: [0.22, 0.045, 0.025], at: panel + [-0.25, 0.1, 0.085],
      material: style.warm)

    // End-face accents stay on the existing wall pieces, outside the service opening.
    for id: RelayHouse.BoxID in [.depotWestBack, .depotWestFront] {
      let wall = RelayHouse.box(id)
      let direction: Float = id == .depotWestBack ? 1 : -1
      let end = wall.position.z + direction * (wall.size.z / 2 - 0.05)
      let x = wall.position.x - wall.size.x / 2 - 0.025
      geometry.box(
        "service-jamb", size: [0.045, 0.86, 0.1], at: [x, 0.55, end],
        material: style.metal)
      geometry.box(
        "service-signal", size: [0.025, 0.18, 0.1], at: [x - 0.035, 0.88, end],
        material: style.signal)
    }
  }

  private static func addVegetationAndDebris(using geometry: Geometry) {
    let style = geometry.style
    for placement in planterPlacements {
      let position = placement.basePosition
      geometry.box(
        "planter", size: planterSize, at: position + [0, planterSize.y / 2, 0],
        material: style.rust)
      for index in 0..<3 {
        let lean = Float(index - 1) * 0.38
        geometry.box(
          "leaf", size: [0.12, 0.38, 0.08],
          at: position + [Float(index - 1) * 0.08, 0.31, 0], material: style.foliage,
          rotation: simd_quatf(angle: lean, axis: [0, 0, 1]))
      }
    }
    let rubble: [SIMD3<Float>] = [
      [-11.8, 0, -0.7], [-6, 0, -0.45], [-12.9, 0, 7.3],
      [6, 0, -7.5], [10.6, 0, -2], [12.9, 0, -8.7],
    ]
    for (index, position) in rubble.enumerated() {
      geometry.box(
        "rubble", size: [0.4, 0.12, 0.28], at: position + [0, 0.06, 0],
        material: style.stone, rotation: simd_quatf(angle: Float(index) * 0.7, axis: [0, 1, 0]))
      geometry.box(
        "scrap", size: [0.35, 0.045, 0.14], at: position + [0.24, 0.045, 0.16],
        material: style.rust, rotation: simd_quatf(angle: -0.35, axis: [0, 1, 0]))
    }
  }

  private static func addWreckDetails(using geometry: Geometry) {
    let style = geometry.style
    let wreck = RelayHouse.box(.streetWreck)
    let top = wreck.position + [0, wreck.size.y / 2 + 0.04, 0]
    geometry.box(
      "wreck-hood", size: [1.5, 0.08, 0.95], at: top + [-0.35, 0, 0],
      material: style.metal)
    geometry.box(
      "wreck-hatch", size: [0.5, 0.15, 0.9], at: top + [0.85, 0.06, 0],
      material: style.wallCap, rotation: simd_quatf(angle: 0.2, axis: [0, 0, 1]))
    for z: Float in [-0.55, 0.55] {
      geometry.box(
        "wreck-rail", size: [2.35, 0.06, 0.05], at: top + [0, 0.04, z],
        material: style.rust)
    }
    let panel = RelayHouse.box(.fallenPanel)
    for z: Float in [-0.7, 0.7] {
      geometry.box(
        "fallen-panel-rib", size: [0.8, 0.06, 0.16],
        at: panel.position + [0, panel.size.y / 2 + 0.03, z], material: style.metal)
    }
  }

  // MARK: - The Brooklyn Bridge

  /// The river far below the deck, seen past the railings.
  private static func addRiver(using geometry: Geometry) {
    geometry.box(
      "river", size: [400, 0.2, 500], at: [0, -30, 0], material: geometry.style.river)
  }

  /// A pale line down the middle of each roadway.
  private static func addLaneLines(using geometry: Geometry) {
    for x: Float in [-7.3, 7.3] {
      geometry.box(
        "lane-line", size: [0.12, 0.01, BrooklynBridge.deckLength - 2], at: [x, 0.006, 0],
        material: geometry.style.wallCap)
    }
  }

  /// Each tower's upper mass above the arches. It is above the camera, so it shows mostly in
  /// the shadow it casts on the deck.
  private static func addTowerTops(using geometry: Geometry) {
    for z in [BrooklynBridge.brooklynTower, BrooklynBridge.manhattanTower] {
      geometry.box(
        "tower-top", size: [28.4, 12, BrooklynBridge.towerThickness],
        at: [0, BrooklynBridge.archHeight + 6, z], material: geometry.style.granite)
    }
  }

  /// The raised walkway above the divider, on posts. It is shown but cannot be walked on.
  private static func addWalkway(using geometry: Geometry) {
    let style = geometry.style
    for divider in BrooklynBridge.structure where divider.name.hasPrefix("divider") {
      let length = divider.size.z
      let centre = divider.position.z
      geometry.box(
        "walkway", size: [5.4, 0.3, length], at: [0, 4.2, centre], material: style.steel)
      for side: Float in [-1, 1] {
        geometry.box(
          "walkway-rail", size: [0.08, 0.9, length], at: [side * 2.66, 4.8, centre],
          material: style.metal)
        var z = centre - length / 2 + 6
        while z < centre + length / 2 - 2 {
          geometry.box(
            "walkway-post", size: [0.25, 3.05, 0.25], at: [side * 2.1, 2.53, z],
            material: style.metal)
          z += 20
        }
      }
    }
  }

  /// The main cables run from each end of the deck over both tower tops and sag between them;
  /// vertical suspenders drop from them to the railings, and stays fan out from the towers.
  private static func addCables(using geometry: Geometry) {
    let style = geometry.style
    let end = BrooklynBridge.deckLength / 2 - 1
    let first = BrooklynBridge.brooklynTower
    let second = BrooklynBridge.manhattanTower
    let top: Float = 26
    let lowest: Float = 3
    let middle = (first + second) / 2
    let halfSpan = (first - second) / 2
    /// The cable's height above the deck at a point along it.
    func height(at z: Float) -> Float {
      if z > first { return top + (1.5 - top) * (z - first) / (end - first) }
      if z < second { return top + (1.5 - top) * (second - z) / (end + second) }
      let t = (z - middle) / halfSpan
      return lowest + (top - lowest) * t * t
    }
    // Points along each cable, from the Brooklyn end to the Manhattan end.
    let stations: [Float] =
      (0..<3).map { end - Float($0) * (end - first) / 3 }
      + (0...8).map { first - Float($0) * (first - second) / 8 }
      + (1...3).map { second - Float($0) * (end + second) / 3 }
    for x: Float in [-12.4, 12.4] {
      for (from, to) in zip(stations, stations.dropFirst()) {
        geometry.line(
          "main-cable", from: [x, height(at: from), from], to: [x, height(at: to), to],
          thickness: 0.22, material: style.metal)
      }
      var z = -end + 6
      while z < end - 6 {
        let rise = height(at: z) - 1.1
        if rise > 0.6, abs(z - first) > 6, abs(z - second) > 6 {
          geometry.box(
            "suspender", size: [0.05, rise, 0.05], at: [x, 1.1 + rise / 2, z],
            material: style.metal)
        }
        z += 12
      }
      for tower in [first, second] {
        for direction: Float in [-1, 1] {
          for reach: Float in [14, 28] {
            geometry.line(
              "stay", from: [x, top - 1, tower], to: [x, 1.1, tower + direction * reach],
              thickness: 0.07, material: style.metal)
          }
        }
      }
    }
  }

  @MainActor
  private struct Geometry {
    let root: Entity
    let style: SceneStyle

    /// A thin box from one point to another, such as a cable.
    func line(
      _ name: String, from start: SIMD3<Float>, to end: SIMD3<Float>, thickness: Float,
      material: any Material
    ) {
      let span = end - start
      let length = simd_length(span)
      guard length > 0.01 else { return }
      box(
        name, size: [thickness, thickness, length], at: (start + end) / 2, material: material,
        rotation: simd_quatf(from: [0, 0, 1], to: span / length))
    }

    func box(
      _ name: String, size: SIMD3<Float>, at position: SIMD3<Float>, material: any Material,
      rotation: simd_quatf? = nil
    ) {
      let entity = style.block(size: size, at: position, material: material)
      entity.name = "dressing.\(name)"
      if let rotation { entity.orientation = rotation }
      root.addChild(entity)
    }

    func cylinder(
      _ name: String, size: SIMD3<Float>, at position: SIMD3<Float>, material: any Material
    ) {
      let entity = ModelEntity(mesh: style.unitCylinder, materials: [material])
      entity.name = "dressing.\(name)"
      entity.scale = [size.x / 2, size.y, size.z / 2]
      entity.position = position
      root.addChild(entity)
    }
  }
}
