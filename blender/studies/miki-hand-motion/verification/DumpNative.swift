import Foundation
import RealityKit
import simd

func requireNewOutput(_ raw: URL, inputs: [URL]) throws -> URL {
  let output = raw.standardizedFileURL
  let manager = FileManager.default
  var ancestor = output
  while true {
    if (try? manager.destinationOfSymbolicLink(atPath: ancestor.path)) != nil {
      throw NSError(
        domain: "NativeProbe", code: 90,
        userInfo: [NSLocalizedDescriptionKey: "Output and ancestors must not be symbolic links"])
    }
    let parent = ancestor.deletingLastPathComponent()
    if parent == ancestor { break }
    ancestor = parent
  }
  guard !manager.fileExists(atPath: output.path),
    !inputs.contains(where: {
      $0.standardizedFileURL.resolvingSymlinksInPath() == output.resolvingSymlinksInPath()
    })
  else {
    throw NSError(
      domain: "NativeProbe", code: 91,
      userInfo: [NSLocalizedDescriptionKey: "Output must be new and must not alias an input"])
  }
  for input in inputs {
    var directory = input.standardizedFileURL.resolvingSymlinksInPath().deletingLastPathComponent()
    while directory.path != "/" {
      if manager.fileExists(atPath: directory.appendingPathComponent("AGENTS.md").path) {
        for name in ["blender", "apple", "art", "docs", ".git"] {
          let protected = directory.appendingPathComponent(name).path
          guard output.path != protected, !output.path.hasPrefix(protected + "/") else {
            throw NSError(
              domain: "NativeProbe", code: 92,
              userInfo: [
                NSLocalizedDescriptionKey:
                  "Use a scratch output outside authored source directories"
              ])
          }
        }
        break
      }
      directory.deleteLastPathComponent()
    }
  }
  return output
}

@main
struct DumpNative {
  @MainActor static func findSkin(_ root: Entity) -> ModelEntity? {
    if let model = root as? ModelEntity, !model.jointNames.isEmpty { return model }
    return root.children.compactMap(findSkin).first
  }
  static func columns(_ matrix: simd_float4x4) -> [[Float]] {
    (0..<4).map { c in (0..<4).map { r in matrix[c][r] } }
  }
  static func flatten(_ definition: any AnimationDefinition) -> [any AnimationDefinition] {
    if let group = definition as? AnimationGroup { return group.group.flatMap(flatten) }
    return [definition]
  }
  @MainActor static func definitions(_ root: Entity) -> [any AnimationDefinition] {
    root.availableAnimations.flatMap { flatten($0.definition) } + root.children.flatMap(definitions)
  }
  @MainActor static func blendState(_ model: ModelEntity) -> [String: [Float]] {
    guard let component = model.components[BlendShapeWeightsComponent.self] else { return [:] }
    return Dictionary(uniqueKeysWithValues: component.weightSet.map { ($0.id, Array($0.weights)) })
  }
  @MainActor static func applyBlends(_ values: [String: Float], model: ModelEntity) {
    guard var component = model.components[BlendShapeWeightsComponent.self] else { return }
    for i in component.weightSet.indices {
      var set = component.weightSet[i]
      set.weights = BlendShapeWeights(set.weightNames.map { values[$0] ?? 0 })
      component.weightSet[i] = set
    }
    model.components.set(component)
  }
  @MainActor static func main() async throws {
    guard CommandLine.arguments.count == 4 else { throw NSError(domain: "DumpNative", code: 1) }
    let destination = try requireNewOutput(
      URL(fileURLWithPath: CommandLine.arguments[3]),
      inputs: [
        URL(fileURLWithPath: CommandLine.arguments[1]),
        URL(fileURLWithPath: CommandLine.arguments[2]),
      ])
    let reference =
      try JSONSerialization.jsonObject(
        with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]))) as! [String: Any]
    let requested = (reference["frames"] as! [NSNumber]).map(\.doubleValue)
    let fps = (reference["fps"] as! NSNumber).doubleValue
    let root = try await Entity(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
    guard let model = findSkin(root), let mesh = model.model?.mesh,
      let skeleton = mesh.contents.skeletons.first
    else { throw NSError(domain: "DumpNative", code: 2) }
    let definitions = definitions(root)
    guard let sampled = definitions.compactMap({ $0 as? SampledAnimation<JointTransforms> }).first
    else {
      throw NSError(domain: "DumpNative", code: 3)
    }
    let blends = definitions.compactMap { $0 as? SampledAnimation<BlendShapeWeights> }
    let order = try model.jointNames.map { name in
      guard let i = sampled.jointNames.firstIndex(of: name) else {
        throw NSError(domain: "DumpNative", code: 4)
      }
      return i
    }
    var parts: [[String: Any]] = []
    for part in mesh.contents.models.flatMap({ Array($0.parts) }) {
      guard let influences = part.jointInfluences else { continue }
      let positions = part.positions.elements
      var shapeOffsets: [String: [[Float]]] = [:]
      for name in part.blendShapeNames {
        if let offsets = part.blendShapeOffsets(named: name) {
          shapeOffsets[name] = offsets.elements.map { [$0.x, $0.y, $0.z] }
        }
      }
      parts.append([
        "id": part.id, "skeleton_id": part.skeletonID ?? "",
        "positions": positions.map { [$0.x, $0.y, $0.z] },
        "influences_per_vertex": influences.influences.elements.count / positions.count,
        "influences": influences.influences.elements.map {
          ["index": $0.jointIndex, "weight": $0.weight]
        },
        "blend_shape_offsets": shapeOffsets,
      ])
    }
    let other = root.clone(recursive: true)
    guard let second = findSkin(other) else { throw NSError(domain: "DumpNative", code: 5) }
    let untouched = second.jointTransforms
    let untouchedBlends = blendState(second)
    let firstPose = order.map { sampled.frames[0][$0] }
    var frames: [String: Any] = [:]
    for frame in requested {
      let index = Int(round((frame - requested.min()!) / fps / Double(sampled.frameInterval)))
      guard index < sampled.frames.count else { throw NSError(domain: "DumpNative", code: 6) }
      let pose = order.map { sampled.frames[index][$0] }
      model.jointTransforms = pose
      var blendValues: [String: Float] = [:]
      for blend in blends {
        let j = min(
          blend.frames.count - 1,
          Int(round((frame - requested.min()!) / fps / Double(blend.frameInterval))))
        for (name, value) in zip(blend.weightNames, blend.frames[j]) { blendValues[name] = value }
      }
      applyBlends(blendValues, model: model)
      frames[String(frame)] = [
        "sample_index": index, "joint_local_matrices_columns": pose.map { columns($0.matrix) },
        "blend_weights": blendValues,
      ]
    }
    var componentSets: [[String: Any]] = []
    if let component = model.components[BlendShapeWeightsComponent.self] {
      componentSets = component.weightSet.map {
        ["id": $0.id, "names": $0.weightNames, "weights": Array($0.weights)]
      }
    }
    model.jointTransforms = firstPose
    let result: [String: Any] = [
      "joint_names": model.jointNames, "joint_count": model.jointNames.count,
      "joint_parent_indices": skeleton.joints.map { $0.parentIndex as Any? ?? NSNull() },
      "skeleton_joint_names": skeleton.joints.map(\.name),
      "inverse_bind_matrices_columns": skeleton.joints.map { columns($0.inverseBindPoseMatrix) },
      "sampled_joint_frame_count": sampled.frames.count, "frame_interval_s": sampled.frameInterval,
      "animation_definition_types": definitions.map { String(describing: type(of: $0)) },
      "blend_animation_count": blends.count, "blend_component_sets": componentSets,
      "parts": parts, "frames": frames,
      "independent_instance_pose": second.jointTransforms == untouched,
      "independent_instance_blend_weights": blendState(second) == untouchedBlends,
      "reset_joint_pose_exact": model.jointTransforms == firstPose,
      "shared_mesh_resource": model.model?.mesh === second.model?.mesh,
      "matrix_encoding":
        "Each nested4x4 array contains SIMD columns, matching Gf matrix rows for row-vector USD conventions.",
    ]
    let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
    try data.write(to: destination, options: .withoutOverwriting)
    print(
      "NATIVE_DUMP joints=\(model.jointNames.count) jointFrames=\(sampled.frames.count) blendAnimations=\(blends.count) parts=\(parts.count) independent=\(second.jointTransforms == untouched)"
    )
  }
}
