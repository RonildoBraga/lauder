import Foundation
import RealityKit

@MainActor
struct CharacterAsset {
  let entity: Entity
  let animationEntity: Entity
  let idle: AnimationResource
  let walk: AnimationResource
  let jointNames: [String]

  var jointCount: Int { jointNames.count }

  static func load(from bundle: Bundle = .main) async throws -> CharacterAsset {
    let idle = try await loadEntity(named: "Idle", from: bundle)
    let walk = try await loadEntity(named: "Walk", from: bundle)
    try Task.checkCancellation()
    return try CharacterAsset(validating: idle, walk: walk)
  }

  init(validating idle: Entity, walk: Entity) throws {
    let idleAsset = try ImportedCharacter.validate(idle, named: "Idle")
    let walkAsset = try ImportedCharacter.validate(walk, named: "Walk")

    guard idleAsset.rig == walkAsset.rig,
      idleAsset.animationPath == walkAsset.animationPath
    else {
      throw CharacterAssetError.incompatibleRigs
    }

    idleAsset.animationEntity.components.set(
      AnimationLibraryComponent(
        animations: ["idle": idleAsset.animation, "walk": walkAsset.animation]
      )
    )
    entity = idleAsset.entity
    animationEntity = idleAsset.animationEntity
    self.idle = idleAsset.animation
    self.walk = walkAsset.animation
    jointNames = idleAsset.rig.joints
  }

  private static func loadEntity(named name: String, from bundle: Bundle) async throws -> Entity {
    guard let url = bundle.url(forResource: name, withExtension: "usdz") else {
      throw CharacterAssetError.missingFile(name)
    }
    let entity = try await Entity(contentsOf: url)
    try Task.checkCancellation()
    return entity
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

  static func validate(_ root: Entity, named name: String) throws -> ImportedCharacter {
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
      throw CharacterAssetError.missingRig(name)
    }

    // RealityKit also imports aggregate scene/subtree clips. This imported name is guarded
    // by AssetLoadingTests; it is not a documented importer contract.
    var authoredClips: [(owner: Entity, path: [String], animation: AnimationResource)] = []
    for node in nodes {
      for animation in node.entity.availableAnimations
      where animation.name?.hasPrefix("/Character/Motion[") == true {
        authoredClips.append((node.entity, node.path, animation))
      }
    }
    guard authoredClips.count == 1 else {
      throw CharacterAssetError.invalidAnimations(name)
    }
    let clip = authoredClips[0]
    let duration = clip.animation.definition.duration
    guard clip.animation.definition is SampledAnimation<JointTransforms>,
      duration.isFinite, duration > 0
    else {
      throw CharacterAssetError.invalidAnimations(name)
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

enum CharacterAssetError: LocalizedError, Equatable {
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
