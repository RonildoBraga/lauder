import simd

extension Level {
  /// Where a level's things stand and how it is lit, as plain data with stable names (ADR 0005).
  /// Blender loads it and saves it back through the Lauder extension,
  /// `blender/extensions/lauder_levels`; the level's content refers to its entries by name and
  /// adds the words: what each place is called and what it says.
  struct Layout: Sendable {
    /// A block that can be looked at. Its position is the centre of its base, on the floor.
    struct Landmark: Sendable {
      let name: String
      let position: SIMD3<Float>
      let size: SIMD3<Float>

      static func landmark(_ name: String, at position: SIMD3<Float>, size: SIMD3<Float>) -> Self {
        Self(name: name, position: position, size: size)
      }
    }

    /// A flat area of the floor, such as a trigger or where a fight begins.
    struct Area: Sendable {
      let name: String
      let minimum: SIMD2<Float>
      let maximum: SIMD2<Float>

      var box: PartyMotion.Box { PartyMotion.Box(minimum: minimum, maximum: maximum) }

      static func area(_ name: String, from minimum: SIMD2<Float>, to maximum: SIMD2<Float>) -> Self
      {
        Self(name: name, minimum: minimum, maximum: maximum)
      }
    }

    /// A point on the floor, such as a spawn or where someone stands.
    struct Marker: Sendable {
      let name: String
      let position: SIMD2<Float>

      static func marker(_ name: String, at position: SIMD2<Float>) -> Self {
        Self(name: name, position: position)
      }
    }

    /// The game camera: from its target, just above the leader, to the camera, and its
    /// vertical field of view in degrees.
    struct Camera: Sendable {
      let offset: SIMD3<Float>
      let fieldOfView: Float

      static func camera(offset: SIMD3<Float>, fieldOfView: Float) -> Self {
        Self(offset: offset, fieldOfView: fieldOfView)
      }
    }

    /// The floor, which blocks nothing.
    let ground: Box
    /// The scenery; every box blocks movement and sight with its footprint.
    let boxes: [Box]
    let landmarks: [Landmark]
    let areas: [Area]
    let markers: [Marker]
    /// Decoration that blocks nothing.
    let pieces: [Piece]
    let camera: Camera
    /// The visual direction allows at most two lights, with at most one casting shadows.
    let lights: [Light]

    func box(named name: String) -> Box {
      guard let box = boxes.first(where: { $0.name == name }) else {
        preconditionFailure("The layout has no box named \(name).")
      }
      return box
    }

    func landmark(named name: String) -> Landmark {
      guard let landmark = landmarks.first(where: { $0.name == name }) else {
        preconditionFailure("The layout has no landmark named \(name).")
      }
      return landmark
    }

    func area(named name: String) -> PartyMotion.Box {
      guard let area = areas.first(where: { $0.name == name }) else {
        preconditionFailure("The layout has no area named \(name).")
      }
      return area.box
    }

    func marker(named name: String) -> SIMD2<Float> {
      guard let marker = markers.first(where: { $0.name == name }) else {
        preconditionFailure("The layout has no marker named \(name).")
      }
      return marker.position
    }
  }
}

extension Level {
  /// Decoration that blocks nothing, such as the bridge's walkway and cables: a box, turned as
  /// it needs. Blender edits pieces like everything else in a layout (ADR 0005).
  struct Piece: Sendable {
    let name: String
    /// The centre.
    let position: SIMD3<Float>
    /// Along the piece's own axes.
    let size: SIMD3<Float>
    var rotation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    let surface: Surface

    /// A piece in a layout file, written briefly; `turn` is a quaternion as (x, y, z, w).
    static func piece(
      _ name: String, at position: SIMD3<Float>, size: SIMD3<Float>,
      turn: SIMD4<Float> = [0, 0, 0, 1], surface: Surface
    ) -> Self {
      Self(
        name: name, position: position, size: size,
        rotation: simd_normalize(simd_quatf(ix: turn.x, iy: turn.y, iz: turn.z, r: turn.w)),
        surface: surface)
    }
  }
}

extension Level {
  /// A light as far away as the sun, shining from one direction over the whole level: a
  /// RealityKit directional light. Blender edits it as a sun light (ADR 0005).
  struct Light: Sendable {
    let name: String
    /// A point in the direction the light comes from: it shines from there towards the origin,
    /// so only the direction matters.
    let source: SIMD3<Float>
    /// In sRGB, each channel from 0 to 1.
    let color: SIMD3<Float>
    /// In lux.
    let intensity: Float
    /// How far from the camera its shadows reach, in metres, or nil when it casts none.
    let shadowDistance: Float?

    /// A sun in a layout file, written briefly.
    static func sun(
      _ name: String, from source: SIMD3<Float>, color: SIMD3<Float>, intensity: Float,
      shadowDistance: Float? = nil
    ) -> Self {
      Self(
        name: name, source: source, color: color, intensity: intensity,
        shadowDistance: shadowDistance)
    }
  }

  /// How a surface looks, in the terms that Blender's Principled BSDF and RealityKit's materials
  /// share: a colour in sRGB, each channel from 0 to 1, a roughness from 0 to 1, and how
  /// metallic it is, from 0 to 1.
  struct Finish: Equatable, Sendable {
    let color: SIMD3<Float>
    let roughness: Float
    var metallic: Float = 0

    /// A finish in the palette file, written briefly.
    static func finish(color: SIMD3<Float>, roughness: Float, metallic: Float = 0) -> Self {
      Self(color: color, roughness: roughness, metallic: metallic)
    }
  }
}

extension Level.Box {
  /// A box in a level's layout file, written briefly.
  static func box(
    _ name: String, at position: SIMD3<Float>, size: SIMD3<Float>, surface: Level.Surface
  ) -> Self {
    Self(name: name, position: position, size: size, surface: surface)
  }
}
