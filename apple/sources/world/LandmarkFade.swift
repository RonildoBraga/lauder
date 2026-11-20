import RealityKit
import simd

/// Tall landmarks, such as the bridge's towers, fade while they stand between the camera and the
/// party, as the visual direction sets out. From the bridge's high camera, looking 50° down, a
/// 47 m tower hides the party for some 40 m beyond it, and at the Manhattan end the camera hangs
/// just above the second tower's top.
///
/// A part of the level's look whose top stands higher than `height` belongs to a landmark, with
/// the tall parts it touches, so a tower's legs, its pier and the top across its arches fade
/// together. The parts do not move, so their bounds are measured once.
@MainActor
struct LandmarkFade {
  /// A part whose top stands higher than this, in metres, belongs to a landmark.
  static let height: Float = 6
  /// How much of a landmark shows while it fades.
  static let faded: Float = 0.2
  /// How long a landmark takes to fade out, or back in, in seconds.
  static let time: Float = 0.3
  /// How far clear of a part, in metres, a line of sight must pass.
  static let margin: Float = 1

  private struct Landmark {
    var parts: [(entity: Entity, bounds: BoundingBox)]
    var opacity: Float = 1
  }

  private var landmarks: [Landmark] = []

  /// No landmarks.
  init() {}

  /// The landmarks among the parts under `look`, which holds the level's look alone.
  init(look: Entity) {
    var tall: [(entity: Entity, bounds: BoundingBox)] = []
    func collect(_ entity: Entity) {
      if entity.components.has(ModelComponent.self) {
        let bounds = entity.visualBounds(recursive: false, relativeTo: nil)
        if bounds.max.y > Self.height { tall.append((entity, bounds)) }
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

  /// Fades each landmark out while the line from `eye` to any of `points` passes through one of
  /// its parts, and back in once none does. A camera that jumps without time passing, as at the
  /// start, on Restart or on a retry, settles every landmark at once.
  mutating func update(eye: SIMD3<Float>, seeing points: [SIMD3<Float>], deltaTime: Float) {
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

  /// Whether two boxes touch or overlap.
  private static func touch(_ first: BoundingBox, _ second: BoundingBox) -> Bool {
    all(first.min .<= second.max + 0.01) && all(second.min .<= first.max + 0.01)
  }
}
