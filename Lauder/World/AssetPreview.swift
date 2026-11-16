import Foundation
import Observation
import RealityKit
import SwiftUI

@MainActor
struct PreviewCharacter {
  let entity: Entity
  let animationEntity: Entity
  let idle: AnimationResource
  let walk: AnimationResource
  let jointNames: [String]

  var jointCount: Int { jointNames.count }

  static func load(from bundle: Bundle = .main) async throws -> PreviewCharacter {
    let idleAsset = try await ImportedCharacter.load(named: "Idle", from: bundle)
    let walkAsset = try await ImportedCharacter.load(named: "Walk", from: bundle)
    try Task.checkCancellation()

    guard idleAsset.rig == walkAsset.rig,
      idleAsset.animationPath == walkAsset.animationPath
    else {
      throw PreviewAssetError.incompatibleRigs
    }

    idleAsset.animationEntity.components.set(
      AnimationLibraryComponent(
        animations: ["idle": idleAsset.animation, "walk": walkAsset.animation]
      )
    )
    return PreviewCharacter(
      entity: idleAsset.entity,
      animationEntity: idleAsset.animationEntity,
      idle: idleAsset.animation,
      walk: walkAsset.animation,
      jointNames: idleAsset.rig.joints
    )
  }
}

private struct RigSignature: Equatable {
  let meshPath: [String]
  let joints: [String]
  let parents: [Int?]
}

@MainActor
private struct ImportedCharacter {
  let entity: Entity
  let animationEntity: Entity
  let animationPath: [String]
  let animation: AnimationResource
  let rig: RigSignature

  static func load(named name: String, from bundle: Bundle) async throws -> ImportedCharacter {
    guard let url = bundle.url(forResource: name, withExtension: "usdz") else {
      throw PreviewAssetError.missingFile(name)
    }
    let root = try await Entity(contentsOf: url)
    try Task.checkCancellation()

    var nodes: [(entity: Entity, path: [String])] = []
    func visit(_ entity: Entity, path: [String]) {
      nodes.append((entity, path))
      for child in entity.children {
        visit(child, path: path + [child.name])
      }
    }
    visit(root, path: [])

    var rigs: [RigSignature] = []
    for node in nodes {
      guard let model = node.entity.components[ModelComponent.self] else { continue }
      let mesh = model.mesh.contents
      for skeleton in mesh.skeletons where !skeleton.joints.isEmpty {
        let hasSkin = mesh.models.contains { model in
          model.parts.contains { part in
            part.skeletonID == skeleton.id && part.jointInfluences != nil
          }
        }
        guard hasSkin else { continue }
        rigs.append(
          RigSignature(
            meshPath: node.path,
            joints: skeleton.joints.map(\.name),
            parents: skeleton.joints.map(\.parentIndex)
          )
        )
      }
    }
    guard rigs.count == 1, let rig = rigs.first, rig.joints.count > 1 else {
      throw PreviewAssetError.missingRig(name)
    }

    // RealityKit also imports aggregate scene/subtree clips. Select the authored USD clip.
    var authoredClips: [(owner: Entity, path: [String], animation: AnimationResource)] = []
    for node in nodes {
      for animation in node.entity.availableAnimations
      where animation.name?.hasPrefix("/Character/Motion[") == true {
        authoredClips.append((node.entity, node.path, animation))
      }
    }
    guard authoredClips.count == 1 else {
      throw PreviewAssetError.invalidAnimations(name)
    }
    let clip = authoredClips[0]
    let duration = clip.animation.definition.duration
    guard clip.animation.definition is SampledAnimation<JointTransforms>,
      duration.isFinite, duration > 0
    else {
      throw PreviewAssetError.invalidAnimations(name)
    }
    return ImportedCharacter(
      entity: root,
      animationEntity: clip.owner,
      animationPath: clip.path,
      animation: clip.animation,
      rig: rig
    )
  }
}

private enum PreviewAssetError: LocalizedError {
  case missingFile(String)
  case missingRig(String)
  case invalidAnimations(String)
  case incompatibleRigs

  var errorDescription: String? {
    switch self {
    case .missingFile(let name):
      "The app bundle is missing \(name).usdz."
    case .missingRig(let name):
      "\(name).usdz must contain one skinned mesh with a joint hierarchy."
    case .invalidAnimations(let name):
      "\(name).usdz must import one authored Character/Motion joint clip with a positive duration."
    case .incompatibleRigs:
      "Idle and Walk must use the same mesh, joint hierarchy and animation binding location."
    }
  }
}

private enum PreviewClip: String, CaseIterable {
  case idle = "Idle"
  case walk = "Walk"
}

@MainActor
@Observable
private final class PreviewWorld {
  enum Status: Equatable {
    case loading
    case ready
    case failed(String)
  }

  let scene = Entity()
  private(set) var status = Status.loading
  private(set) var selectedClip = PreviewClip.idle
  private(set) var jointCount = 0

  @ObservationIgnored private var character: PreviewCharacter?
  @ObservationIgnored private var playback: AnimationPlaybackController?
  @ObservationIgnored private var loadGeneration: UUID?
  @ObservationIgnored private var isActive = true
  @ObservationIgnored private var sceneConfigured = false

  func load() async {
    if character != nil {
      play(selectedClip)
      return
    }
    if !sceneConfigured {
      configureScene()
      sceneConfigured = true
    }
    let generation = UUID()
    loadGeneration = generation
    status = .loading
    do {
      let loaded = try await PreviewCharacter.load()
      try Task.checkCancellation()
      guard loadGeneration == generation else { return }
      scene.addChild(loaded.entity)
      character = loaded
      jointCount = loaded.jointCount
      status = .ready
      play(.idle)
    } catch is CancellationError {
      // SwiftUI cancels this load when the preview leaves the screen.
    } catch {
      guard loadGeneration == generation else { return }
      status = .failed(error.localizedDescription)
    }
  }

  func play(_ clip: PreviewClip) {
    guard let character else { return }
    playback?.stop()
    let animation = clip == .idle ? character.idle : character.walk
    playback = character.animationEntity.playAnimation(
      animation.repeat(), transitionDuration: 0, startsPaused: !isActive
    )
    selectedClip = clip
  }

  func setActive(_ active: Bool) {
    isActive = active
    if active {
      playback?.resume()
    } else {
      playback?.pause()
    }
  }

  func stop() {
    loadGeneration = nil
    playback?.stop()
    playback = nil
  }

  private func configureScene() {
    let floor = ModelEntity(
      mesh: .generatePlane(width: 6, depth: 6),
      materials: [SimpleMaterial(color: .darkGray, isMetallic: false)]
    )
    let landmark = ModelEntity(
      mesh: .generateBox(size: 0.4),
      materials: [SimpleMaterial(color: .cyan, isMetallic: false)]
    )
    landmark.position = [1.4, 0.2, -1]

    let light = DirectionalLight()
    light.light.intensity = 3000
    light.look(at: [0, 0, 0], from: [2, 5, 3], relativeTo: nil)

    let camera = PerspectiveCamera()
    camera.camera.fieldOfViewInDegrees = 45
    camera.look(at: [0, 0.9, 0], from: [3.4, 3.5, 5], relativeTo: nil)
    for entity in [floor, landmark, light, camera] {
      scene.addChild(entity)
    }
  }
}

@MainActor
struct AssetPreview: View {
  @Environment(\.scenePhase) private var scenePhase
  @State private var world = PreviewWorld()

  var body: some View {
    ZStack(alignment: .topLeading) {
      Color.black.ignoresSafeArea()
      RealityView { content in
        content.camera = .virtual
        content.add(world.scene)
      }
      .realityViewCameraControls(.none)
      .ignoresSafeArea()

      VStack(alignment: .leading, spacing: 12) {
        Text("Character asset preview")
          .font(.headline)
        switch world.status {
        case .loading:
          ProgressView("Loading character…")
        case .failed(let message):
          Text(message)
            .foregroundStyle(.red)
            .multilineTextAlignment(.center)
        case .ready:
          Text("\(world.jointCount) joints · \(world.selectedClip.rawValue)")
            .font(.subheadline)
          HStack {
            ForEach(PreviewClip.allCases, id: \.self) { clip in
              Button(clip.rawValue) {
                world.play(clip)
              }
              .buttonStyle(.borderedProminent)
              .tint(world.selectedClip == clip ? .blue : .gray)
            }
          }
        }
      }
      .padding()
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
      .padding()
    }
    .task { await world.load() }
    .onChange(of: scenePhase, initial: true) { _, phase in
      world.setActive(phase == .active)
    }
    .onDisappear { world.stop() }
  }
}
