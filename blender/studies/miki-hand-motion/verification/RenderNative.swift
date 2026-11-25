import AppKit
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

@MainActor
final class NativeRender: NSObject, NSApplicationDelegate {
  var window: NSWindow!
  var view: ARView!

  func applicationDidFinishLaunching(_ notification: Notification) {
    Task { @MainActor in
      do { try await render() } catch {
        fputs("NATIVE_RENDER_ERROR: \(error)\n", stderr)
        exit(1)
      }
      NSApplication.shared.terminate(nil)
    }
  }

  func skin(_ entity: Entity) -> ModelEntity? {
    if let model = entity as? ModelEntity, !model.jointNames.isEmpty { return model }
    return entity.children.compactMap(skin).first
  }
  func definitions(_ root: Entity) -> [any AnimationDefinition] {
    func flatten(_ value: any AnimationDefinition) -> [any AnimationDefinition] {
      if let group = value as? AnimationGroup { return group.group.flatMap(flatten) }
      return [value]
    }
    return root.availableAnimations.flatMap { flatten($0.definition) }
      + root.children.flatMap(definitions)
  }
  func applyBlends(_ values: [String: Float], model: ModelEntity) throws {
    guard var component = model.components[BlendShapeWeightsComponent.self] else {
      if !values.isEmpty { throw NSError(domain: "NativeRender", code: 5) }
      return
    }
    for i in component.weightSet.indices {
      var set = component.weightSet[i]
      set.weights = BlendShapeWeights(set.weightNames.map { values[$0] ?? 0 })
      component.weightSet[i] = set
    }
    model.components.set(component)
  }

  func render() async throws {
    guard CommandLine.arguments.count >= 3 else { throw NSError(domain: "NativeRender", code: 1) }
    let input = URL(fileURLWithPath: CommandLine.arguments[1])
    let inputs =
      [input]
      + (CommandLine.arguments.count >= 4 ? [URL(fileURLWithPath: CommandLine.arguments[3])] : [])
    let output = try requireNewOutput(
      URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true), inputs: inputs)
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    view = ARView(frame: NSRect(x: 0, y: 0, width: 720, height: 900))
    view.environment.background = .color(
      NSColor(calibratedRed: 0.55, green: 0.55, blue: 0.52, alpha: 1))
    window = NSWindow(
      contentRect: view.frame, styleMask: [.titled, .closable], backing: .buffered, defer: false)
    window.title = "Lauder — isolated RealityKit skin verification"
    window.contentView = view
    window.center()
    window.makeKeyAndOrderFront(nil)
    let reference: [String: Any]? =
      CommandLine.arguments.count >= 4
      ? try JSONSerialization.jsonObject(
        with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[3]))) as? [String: Any]
      : nil
    let root = try await Entity(contentsOf: input)
    let definitions = definitions(root)
    guard let model = skin(root),
      let sampled = definitions.compactMap({
        $0 as? SampledAnimation<JointTransforms>
      }).first
    else { throw NSError(domain: "NativeRender", code: 2) }
    let blendAnimations = definitions.compactMap { $0 as? SampledAnimation<BlendShapeWeights> }
    let anchor = AnchorEntity(world: .zero)
    anchor.addChild(root)
    var riflePlacement: Entity?
    if let asset = reference?["rifle_asset"] as? String {
      let referenceURL = URL(fileURLWithPath: CommandLine.arguments[3])
      let rifleRoot = try await Entity(
        contentsOf: referenceURL.deletingLastPathComponent().appendingPathComponent(asset))
      let placement = Entity()
      placement.name = "Independent rifle placement"
      placement.addChild(rifleRoot)
      anchor.addChild(placement)
      riflePlacement = placement
    }
    let camera = PerspectiveCamera()
    camera.camera.fieldOfViewInDegrees = 25
    anchor.addChild(camera)
    for (name, position, power) in [
      ("Key", SIMD3<Float>(-3, 4, 5), Float(4000)), ("Fill", SIMD3<Float>(4, 3, 1), Float(1700)),
    ] {
      let light = DirectionalLight()
      light.name = name
      light.light.intensity = power
      light.look(at: [0, 1, 0], from: position, relativeTo: nil)
      anchor.addChild(light)
    }
    view.scene.anchors.append(anchor)
    let order = try model.jointNames.map { name in
      guard let i = sampled.jointNames.firstIndex(of: name) else {
        throw NSError(domain: "NativeRender", code: 3)
      }
      return i
    }
    let sourceFrames = (reference?["frames"] as? [NSNumber])?.map(\.doubleValue)
    let fps = (reference?["fps"] as? NSNumber)?.doubleValue ?? 120
    let requests: [(String, Int)] =
      sourceFrames?.map {
        (
          "frame-\(Int($0))",
          Int(round(($0 - sourceFrames!.min()!) / fps / Double(sampled.frameInterval)))
        )
      } ?? [("start", 0), ("end", sampled.frames.count - 1)]
    var states: [[String: Any]] = []
    var pixelSizes: [[Int]] = []
    for (label, frame) in requests {
      model.jointTransforms = order.map { sampled.frames[frame][$0] }
      if let placement = riflePlacement, let reference,
        let matrices = reference["rifle_world_matrices"] as? [String: [[NSNumber]]],
        let sourceFrame = Double(label.replacingOccurrences(of: "frame-", with: "")),
        let rows = matrices[String(sourceFrame)],
        let cRows = reference["usd_skeleton_to_world"] as? [[NSNumber]]
      {
        let m = simd_float4x4(
          rows: rows.map {
            SIMD4<Float>($0[0].floatValue, $0[1].floatValue, $0[2].floatValue, $0[3].floatValue)
          })
        let c = simd_float4x4(
          columns: (
            SIMD4(cRows[0].map(\.floatValue)), SIMD4(cRows[1].map(\.floatValue)),
            SIMD4(cRows[2].map(\.floatValue)), SIMD4(cRows[3].map(\.floatValue))
          ))
        placement.transform = Transform(matrix: c * m * c.inverse)
      }
      var blendValues: [String: Float] = [:]
      for animation in blendAnimations {
        let j = min(
          animation.frames.count - 1,
          Int(
            round(Double(frame) * Double(sampled.frameInterval) / Double(animation.frameInterval))))
        for (name, value) in zip(animation.weightNames, animation.frames[j]) {
          blendValues[name] = value
        }
      }
      try applyBlends(blendValues, model: model)
      states.append([
        "label": label, "sample_index": frame, "applied_native_blend_weights": blendValues,
      ])
      var views = [("full", SIMD3<Float>(0, 0.92, 0), SIMD3<Float>(2.6, 2.1, 4.8))]
      if reference == nil || (reference?["action"] as? String)?.contains("controls") == true {
        views.append(("hand", SIMD3<Float>(0.35, 1.04, 0.29), SIMD3<Float>(0.38, 1.48, 1.2)))
      }
      for (viewName, target, position) in views {
        camera.look(at: target, from: position, relativeTo: nil)
        try await Task.sleep(for: .milliseconds(900))
        let image: NSImage? = await withCheckedContinuation { continuation in
          view.snapshot(saveToHDR: false) { image in continuation.resume(returning: image) }
        }
        guard let tiff = image?.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:])
        else {
          throw NSError(domain: "NativeRender", code: 4)
        }
        let name = "\(label)-\(viewName).png"
        try png.write(to: output.appendingPathComponent(name))
        pixelSizes.append([bitmap.pixelsWide, bitmap.pixelsHigh])
        print("SAVED \(name)")
      }
      if label == requests.last!.0 && blendValues.values.contains(where: { $0 > 0.01 }) {
        try applyBlends(blendValues.mapValues { _ in 0 }, model: model)
        camera.look(at: [0, 0.92, 0], from: [2.6, 2.1, 4.8], relativeTo: nil)
        try await Task.sleep(for: .milliseconds(700))
        let image: NSImage? = await withCheckedContinuation { continuation in
          view.snapshot(saveToHDR: false) { continuation.resume(returning: $0) }
        }
        if let tiff = image?.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:])
        {
          try png.write(to: output.appendingPathComponent("\(label)-no-correctives-full.png"))
        }
        try applyBlends(blendValues, model: model)
      }
    }
    let record: [String: Any] = [
      "joint_count": model.jointNames.count, "sampled_frames": sampled.frames.count,
      "renderer": "macOS RealityKit ARView.snapshot", "source": input.lastPathComponent,
      "states": states, "view_size_points": [720, 900], "snapshot_pixel_sizes": pixelSizes,
      "independent_rifle_loaded": riflePlacement != nil,
    ]
    let data = try JSONSerialization.data(
      withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: output.appendingPathComponent("render.json"))
    window.close()
  }
}

@main
struct Main {
  @MainActor static func main() {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = NativeRender()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
  }
}
