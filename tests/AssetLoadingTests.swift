import Foundation
import RealityKit
import Testing

@MainActor
struct AssetLoadingTests {
  @Test
  func bundledCharacterImportsWithRigAndBothClips() async throws {
    let character = try await CharacterAsset.load()

    #expect(character.jointCount > 1)
    #expect(Set(character.jointNames).count == character.jointCount)
    #expect(character.idle.definition.duration > 0)
    #expect(character.walk.definition.duration > 0)

    let library = try #require(character.animationEntity.components[AnimationLibraryComponent.self])
    #expect(Set(library.animations.map(\.key)) == Set(["idle", "walk"]))
  }

  @Test
  func rejectsIncompatibleBindingHierarchy() async throws {
    let idle = try await loadEntity(named: "Idle")
    let walk = try await loadEntity(named: "Walk")
    let differentHierarchy = Entity()
    differentHierarchy.addChild(walk)

    #expect(throws: CharacterAssetError.incompatibleRigs) {
      _ = try CharacterAsset(validating: idle, walk: differentHierarchy)
    }
  }

  @Test
  func rejectsSkinnedModelWithoutAuthoredClip() async throws {
    let idle = try await loadEntity(named: "Idle")
    let walk = try await loadEntity(named: "Walk")
    let model = try #require(firstModel(in: walk))
    #expect(!model.mesh.contents.skeletons.isEmpty)

    let withoutAnimation = Entity()
    withoutAnimation.components.set(model)
    #expect(withoutAnimation.availableAnimations.isEmpty)

    #expect(throws: CharacterAssetError.invalidAnimations("Walk")) {
      _ = try CharacterAsset(validating: idle, walk: withoutAnimation)
    }
  }

  private func loadEntity(named name: String) async throws -> Entity {
    let url = try #require(Bundle.main.url(forResource: name, withExtension: "usdz"))
    return try await Entity(contentsOf: url)
  }

  private func firstModel(in entity: Entity) -> ModelComponent? {
    if let model = entity.components[ModelComponent.self] {
      return model
    }
    for child in entity.children {
      if let model = firstModel(in: child) {
        return model
      }
    }
    return nil
  }
}
