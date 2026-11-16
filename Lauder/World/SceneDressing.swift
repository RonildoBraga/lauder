import RealityKit
import simd

@MainActor
enum SceneDressing {
  static func add(to root: Entity, style: SceneStyle) {
    let dressing = Entity()
    dressing.name = "scene-dressing"
    root.addChild(dressing)
    let geometry = Geometry(root: dressing, style: style)
    addPaving(using: geometry)
    addWallCaps(using: geometry)
    addShelterDetails(using: geometry)
    addDepotDetails(using: geometry)
    addVegetationAndDebris(using: geometry)
    addWreckDetails(using: geometry)
  }

  private static func addPaving(using geometry: Geometry) {
    // These shallow slabs sit above the floor without changing its collision surface.
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
    for wall in PrototypeLayout.boxes
    where wall.name.contains("boundary") || wall.name.hasPrefix("shelter-")
      || wall.name.hasPrefix("depot-")
    {
      geometry.box(
        "\(wall.name)-cap", size: [wall.size.x, 0.08, wall.size.z],
        at: wall.position + [0, wall.size.y / 2 + 0.04, 0],
        material: geometry.style.wallCap)
    }
  }

  private static func addShelterDetails(using geometry: Geometry) {
    guard let wall = PrototypeLayout.boxes.first(where: { $0.name == "shelter-back" }) else {
      return
    }
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
    if let back = PrototypeLayout.boxes.first(where: { $0.name == "depot-back" }) {
      let face = back.position.z + back.size.z / 2 + 0.035
      for x: Float in [-2.25, -0.75, 0.75, 2.25] {
        geometry.box(
          "depot-panel", size: [1.32, 0.72, 0.035],
          at: [back.position.x + x, 0.58, face], material: style.metal)
      }
      for x: Float in [-2.95, -1.5, 0, 1.5, 2.95] {
        geometry.box(
          "depot-seam", size: [0.045, 0.92, 0.065],
          at: [back.position.x + x, 0.55, face + 0.025], material: style.rust)
      }
    }
    if let side = PrototypeLayout.boxes.first(where: { $0.name == "depot-east" }) {
      let face = side.position.x + side.size.x / 2 + 0.035
      for z: Float in [-1.8, 0, 1.8] {
        geometry.box(
          "depot-side-panel", size: [0.035, 0.7, 1.55],
          at: [face, 0.58, side.position.z + z], material: style.metal)
      }
      for z: Float in [-0.9, 0.9] {
        geometry.box(
          "depot-side-seam", size: [0.065, 0.92, 0.045],
          at: [face + 0.025, 0.55, side.position.z + z], material: style.rust)
      }
    }
    if let entrance = PrototypeLayout.boxes.first(where: { $0.name == "blocked-entrance" }) {
      let face = entrance.position.z + entrance.size.z / 2 + 0.035
      let panel: SIMD3<Float> = [entrance.position.x, 0.6, face]
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
    }

    // End-face accents stay on the existing wall pieces, outside the service opening.
    for name in ["depot-west-back", "depot-west-front"] {
      guard let wall = PrototypeLayout.boxes.first(where: { $0.name == name }) else { continue }
      let direction: Float = name == "depot-west-back" ? 1 : -1
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
    let plants: [SIMD3<Float>] = [
      [-12.8, 0, 4.7], [-5.8, 0, -0.5], [10.5, 0, -6.7], [3.45, 0, -6.7], [13, 0, 8.9],
    ]
    for position in plants {
      geometry.box(
        "planter", size: [0.42, 0.16, 0.35], at: position + [0, 0.08, 0],
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
    if let wreck = PrototypeLayout.boxes.first(where: { $0.name == "street-wreck" }) {
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
    }
    if let panel = PrototypeLayout.boxes.first(where: { $0.name == "fallen-panel" }) {
      for z: Float in [-0.7, 0.7] {
        geometry.box(
          "fallen-panel-rib", size: [0.8, 0.06, 0.16],
          at: panel.position + [0, panel.size.y / 2 + 0.03, z], material: style.metal)
      }
    }
  }

  @MainActor
  private struct Geometry {
    let root: Entity
    let style: SceneStyle

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
