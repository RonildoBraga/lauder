import simd

extension Level {
  /// Where everything that plays on a level stands and how it is lit, as plain data with stable
  /// names. Blender's Lauder extension, `blender/extensions/lauder_levels`, writes it from the
  /// level's Blender file (ADR 0006); the level's content refers to its entries by name and adds
  /// the words: what each place is called and what it says.
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
  /// A light on the level, from the Lights collection of its Blender file (ADR 0006): a sun, a
  /// point light or a spot light.
  struct Light: Sendable {
    enum Kind: Sendable {
      /// As far away as the sun, shining from `source`'s direction over the whole level: a
      /// RealityKit directional light. Its shadow, if any, reaches `shadowDistance` metres from
      /// the camera.
      case sun(source: SIMD3<Float>, shadowDistance: Float?)
      /// At `position`, shining every way as far as `radius` metres. The game draws no shadows
      /// from point lights.
      case point(position: SIMD3<Float>, radius: Float)
      /// At `position`, shining towards `target` as far as `radius` metres, at full strength
      /// within a cone of `innerAngle` degrees and fading to nothing at `outerAngle`, both the
      /// cone's full width.
      case spot(
        position: SIMD3<Float>, target: SIMD3<Float>, radius: Float, innerAngle: Float,
        outerAngle: Float, shadow: Bool)
    }

    let name: String
    let kind: Kind
    /// In sRGB, each channel from 0 to 1.
    let color: SIMD3<Float>
    /// In lux for a sun, and in lumens for a point or spot light.
    let intensity: Float

    var castsShadows: Bool {
      switch kind {
      case .sun(_, let shadowDistance): shadowDistance != nil
      case .point: false
      case .spot(_, _, _, _, _, let shadow): shadow
      }
    }

    /// A sun in a layout file, written briefly: it shines from `source` towards the origin, so
    /// only the direction matters.
    static func sun(
      _ name: String, from source: SIMD3<Float>, color: SIMD3<Float>, intensity: Float,
      shadowDistance: Float? = nil
    ) -> Self {
      Self(
        name: name, kind: .sun(source: source, shadowDistance: shadowDistance), color: color,
        intensity: intensity)
    }

    /// A point light in a layout file, written briefly.
    static func point(
      _ name: String, at position: SIMD3<Float>, color: SIMD3<Float>, intensity: Float,
      radius: Float
    ) -> Self {
      Self(
        name: name, kind: .point(position: position, radius: radius), color: color,
        intensity: intensity)
    }

    /// A spot light in a layout file, written briefly: `angles` are the full-strength and outer
    /// widths of its cone, in degrees.
    static func spot(
      _ name: String, at position: SIMD3<Float>, toward target: SIMD3<Float>,
      color: SIMD3<Float>, intensity: Float, radius: Float, angles: SIMD2<Float>,
      shadow: Bool = false
    ) -> Self {
      Self(
        name: name,
        kind: .spot(
          position: position, target: target, radius: radius, innerAngle: angles.x,
          outerAngle: angles.y, shadow: shadow),
        color: color, intensity: intensity)
    }
  }
}

extension Level.Box {
  /// A box in a level's layout file, written briefly.
  static func box(_ name: String, at position: SIMD3<Float>, size: SIMD3<Float>) -> Self {
    Self(name: name, position: position, size: size)
  }
}
