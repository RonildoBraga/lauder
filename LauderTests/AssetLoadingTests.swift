import Foundation
import RealityKit
import Testing

@testable import Lauder

@MainActor
struct AssetLoadingTests {
  @Test
  func bundledCharacterImportsWithRigAndBothClips() async throws {
    let character = try await PreviewCharacter.load()

    #expect(character.jointCount > 1)
    #expect(Set(character.jointNames).count == character.jointCount)
    #expect(character.idle.definition.duration > 0)
    #expect(character.walk.definition.duration > 0)

    let library = try #require(character.animationEntity.components[AnimationLibraryComponent.self])
    #expect(Set(library.animations.map(\.key)) == Set(["idle", "walk"]))
  }
}
