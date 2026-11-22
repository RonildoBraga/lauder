import RealityKit
import simd

/// A small static mesh for the test yard's terraces. Separate top and riser faces preserve the
/// palette and show real changes in height, including the floor below the surrounding ground.
enum TerrainMesh {
  struct Faces {
    var positions: [SIMD3<Float>] = []
    var normals: [SIMD3<Float>] = []
    var triangles: [UInt32] = []

    mutating func quad(
      _ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, _ d: SIMD3<Float>
    ) {
      let firstCross = simd_cross(b - a, c - a)
      let cross =
        simd_length_squared(firstCross) > 0.00000001
        ? firstCross : simd_cross(c - a, d - a)
      guard simd_length_squared(cross) > 0.00000001 else { return }
      let first = UInt32(positions.count)
      positions += [a, b, c, d]
      normals += [SIMD3<Float>](repeating: simd_normalize(cross), count: 4)
      triangles += [first, first + 1, first + 2, first, first + 2, first + 3]
    }
  }

  struct Geometry {
    var tops = Faces()
    var risers = Faces()
  }

  static func geometry(terrain: Terrain, bounds: PartyMotion.Box) -> Geometry {
    let lines = terrain.divisions(in: bounds)
    var result = Geometry()
    let skirt = min(0, terrain.patches.map { min($0.from, $0.to) }.min() ?? 0) - 0.3
    for (x0, x1) in zip(lines.x, lines.x.dropFirst()) {
      for (z0, z1) in zip(lines.z, lines.z.dropFirst()) {
        let middle = SIMD2<Float>((x0 + x1) / 2, (z0 + z1) / 2)
        func point(_ x: Float, _ z: Float, tile: SIMD2<Float>? = nil) -> SIMD3<Float> {
          [x, terrain.height(at: [x, z], inTileContaining: tile ?? middle), z]
        }
        let a = point(x0, z0)
        let b = point(x0, z1)
        let c = point(x1, z1)
        let d = point(x1, z0)
        result.tops.quad(a, b, c, d)

        // Only each tile's right and far edge is visited, so an internal riser is made once.
        let right = SIMD2<Float>(x1 + 0.0001, middle.y)
        let far = SIMD2<Float>(middle.x, z1 + 0.0001)
        if x1 < bounds.maximum.x {
          wall(d, c, point(x1, z0, tile: right), point(x1, z1, tile: right), into: &result)
        } else {
          wall(d, c, [x1, skirt, z0], [x1, skirt, z1], into: &result)
        }
        if z1 < bounds.maximum.y {
          wall(c, b, point(x1, z1, tile: far), point(x0, z1, tile: far), into: &result)
        } else {
          wall(c, b, [x1, skirt, z1], [x0, skirt, z1], into: &result)
        }
        if x0 == bounds.minimum.x {
          wall(b, a, [x0, skirt, z1], [x0, skirt, z0], into: &result)
        }
        if z0 == bounds.minimum.y {
          wall(a, d, [x0, skirt, z0], [x1, skirt, z0], into: &result)
        }
      }
    }
    return result
  }

  private static func wall(
    _ a: SIMD3<Float>, _ b: SIMD3<Float>, _ otherA: SIMD3<Float>, _ otherB: SIMD3<Float>,
    into result: inout Geometry
  ) {
    guard abs(a.y - otherA.y) > 0.0001 || abs(b.y - otherB.y) > 0.0001 else { return }
    // Two sides are useful at a ramp's edge: the lower court and upper lane both see its wall.
    result.risers.quad(a, b, otherB, otherA)
    result.risers.quad(otherA, otherB, b, a)
  }

  @MainActor
  static func entity(terrain: Terrain, ground: Level.Box, style: SceneStyle) -> Entity {
    let data = geometry(terrain: terrain, bounds: ground.footprint)
    let result = Entity()
    result.name = ground.name
    for (name, faces, material) in [
      ("floor", data.tops, style.snow), ("risers", data.risers, style.scenery),
    ] where !faces.triangles.isEmpty {
      var descriptor = MeshDescriptor(name: name)
      descriptor.positions = MeshBuffers.Positions(faces.positions)
      descriptor.normals = MeshBuffers.Normals(faces.normals)
      descriptor.primitives = .triangles(faces.triangles)
      do {
        let model = ModelEntity(
          mesh: try MeshResource.generate(from: [descriptor]), materials: [material])
        model.name = "\(ground.name).\(name)"
        result.addChild(model)
      } catch {
        preconditionFailure("The terrain mesh did not load: \(error)")
      }
    }
    return result
  }
}
