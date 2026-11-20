import RealityKit
import UIKit
import simd

/// Tall landmarks, such as the bridge's towers, fade while they stand between the camera and the
/// party, as the visual direction sets out. From the bridge's high camera, looking 50° down, a
/// 47 m tower hides the party for some 40 m beyond it, and at the Manhattan end the camera hangs
/// just above the second tower's top.
///
/// A part of the level's look whose top stands higher than `height` belongs to a landmark, with
/// the tall parts it touches, so a tower's legs, its pier and the top across its arches fade
/// together. The parts do not move, so their bounds are measured once.
///
/// A fading landmark becomes a see-through ghost of itself, so the player still sees what is in
/// the way. The ghost is unlit, in each part's own colour: close to the camera a landmark fills
/// much of the screen, and see-through lit stone held the iPhone 13 Pro Max to 42 fps at the
/// Manhattan end, its GPU at 97%. A landmark casts no live shadow: its shadow is baked into the
/// level's look in Blender, so it stays while the landmark fades.
@MainActor
struct LandmarkFade {
  /// A part whose top stands higher than this, in metres, belongs to a landmark.
  static let height: Float = 6
  /// How much of a landmark's ghost shows once it has faded.
  static let faded: Float = 0.3
  /// How long a landmark takes to fade out, or back in, in seconds.
  static let time: Float = 0.3
  /// How far clear of a part, in metres, a line of sight must pass.
  static let margin: Float = 1

  /// How long, in seconds, each landmark's material shows see-through in a speck before the
  /// camera, so that the renderer prepares it before the first fade instead of stalling then.
  static let preparing: Float = 0.5

  /// A landmark's part: its entity, its bounds, its own materials and its ghost's.
  private typealias Part = (
    entity: Entity, bounds: BoundingBox, materials: [any Material], ghost: [any Material]
  )

  private struct Landmark {
    var parts: [Part]
    var opacity: Float = 1
  }

  private var landmarks: [Landmark] = []
  private var specks: [Entity] = []
  private var prepared: Float = 0

  /// No landmarks.
  init() {}

  /// The landmarks among the parts under `look`, which holds the level's look alone.
  init(look: Entity) {
    var tall: [Part] = []
    func collect(_ entity: Entity) {
      if let model = entity.components[ModelComponent.self] {
        let bounds = entity.visualBounds(recursive: false, relativeTo: nil)
        if bounds.max.y > Self.height {
          tall.append((entity, bounds, model.materials, Self.ghost(of: model.materials)))
          entity.components.set(DynamicLightShadowComponent(castsShadow: false))
        }
      }
      for child in entity.children { collect(child) }
    }
    collect(look)
    for part in tall {
      let touching = landmarks.indices.filter { index in
        landmarks[index].parts.contains { Self.touch($0.bounds, part.bounds) }
      }
      var parts = [part]
      for index in touching.reversed() { parts += landmarks.remove(at: index).parts }
      landmarks.append(Landmark(parts: parts))
    }
  }

  /// Shows each landmark's ghost in a speck a metre before `camera`, too small and faint to
  /// notice, for the first `preparing` seconds of play. A landmark is usually out of view when
  /// play starts, and the first see-through frame of a material is slow to prepare: on the
  /// Simulator, the first fade stalled for 0.7 seconds. The specks stay, disabled.
  mutating func prepare(before camera: Entity) {
    for landmark in landmarks {
      guard let ghost = landmark.parts.first?.ghost else { continue }
      let speck = ModelEntity(mesh: .generateBox(size: 0.002), materials: ghost)
      speck.name = "landmark.speck"
      speck.position = [0, 0, -1]
      speck.components.set(OpacityComponent(opacity: 0.01))
      camera.addChild(speck)
      specks.append(speck)
    }
  }

  /// Fades each landmark out while the line from `eye` to any of `points` passes through one of
  /// its parts, and back in once none does. A camera that jumps without time passing, as at the
  /// start, on Restart or on a retry, settles every landmark at once.
  mutating func update(eye: SIMD3<Float>, seeing points: [SIMD3<Float>], deltaTime: Float) {
    if prepared < Self.preparing {
      prepared += max(0, deltaTime)
      if prepared >= Self.preparing {
        for speck in specks { speck.isEnabled = false }
      }
    }
    let step = deltaTime > 0 ? deltaTime / Self.time * (1 - Self.faded) : 1
    for index in landmarks.indices {
      let hides = landmarks[index].parts.contains { part in
        points.contains { Self.segment(from: eye, to: $0, meets: part.bounds, margin: Self.margin) }
      }
      let wanted: Float = hides ? Self.faded : 1
      let before = landmarks[index].opacity
      let opacity =
        abs(wanted - before) <= step ? wanted : before + (wanted > before ? step : -step)
      guard opacity != before else { continue }
      landmarks[index].opacity = opacity
      for part in landmarks[index].parts {
        // The ghost takes the part's place as the fade begins, and gives it back at the end.
        if opacity < 1, before == 1 {
          Self.wear(part.ghost, on: part.entity)
        } else if opacity == 1 {
          Self.wear(part.materials, on: part.entity)
        }
        if opacity < 1 {
          part.entity.components.set(OpacityComponent(opacity: opacity))
        } else {
          part.entity.components.remove(OpacityComponent.self)
        }
      }
    }
  }

  /// Whether the segment from `start` to `end` passes within `margin` of `box`.
  static func segment(
    from start: SIMD3<Float>, to end: SIMD3<Float>, meets box: BoundingBox, margin: Float = 0
  ) -> Bool {
    let low = box.min - margin
    let high = box.max + margin
    let direction = end - start
    var near: Float = 0
    var far: Float = 1
    for axis in 0..<3 {
      guard abs(direction[axis]) > 1e-6 else {
        if start[axis] < low[axis] || start[axis] > high[axis] { return false }
        continue
      }
      let first = (low[axis] - start[axis]) / direction[axis]
      let second = (high[axis] - start[axis]) / direction[axis]
      near = max(near, min(first, second))
      far = min(far, max(first, second))
      if near > far { return false }
    }
    return true
  }

  /// An unlit stand-in for each material, in its base colour.
  private static func ghost(of materials: [any Material]) -> [any Material] {
    materials.map { material in
      let colour =
        (material as? PhysicallyBasedMaterial)?.baseColor.tint
        ?? (material as? SimpleMaterial)?.color.tint ?? UIColor(white: 0.7, alpha: 1)
      return UnlitMaterial(color: colour)
    }
  }

  /// Puts these materials on the entity's model.
  private static func wear(_ materials: [any Material], on entity: Entity) {
    guard var model = entity.components[ModelComponent.self] else { return }
    model.materials = materials
    entity.components.set(model)
  }

  /// Whether two boxes touch or overlap.
  private static func touch(_ first: BoundingBox, _ second: BoundingBox) -> Bool {
    all(first.min .<= second.max + 0.01) && all(second.min .<= first.max + 0.01)
  }
}
