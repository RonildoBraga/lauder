import RealityKit
import Testing
import UIKit
import simd

@testable import Lauder

/// Cached level scenes are untouched templates, not shared live entities or faded materials.
@MainActor
struct SceneTemplateTests {
  @Test
  func recursiveClonesKeepTransformsMaterialsAndVisibilityIndependent() throws {
    let name = try #require(BrooklynBridge.level.scene)
    let first = try SceneStyle.scene(named: name)
    let second = try SceneStyle.scene(named: name)
    let rootPosition = second.position
    #expect(first !== second && first.parent == nil && second.parent == nil)
    let part = try #require(modelParts(first).first)
    let sibling = try #require(second.findEntity(named: part.name))
    #expect(part !== sibling)
    let position = sibling.position
    let scale = sibling.scale
    let materials = try #require(sibling.components[ModelComponent.self]).materials
    let kinds = materials.map { String(describing: type(of: $0)) }
    #expect(!materials.isEmpty && !materials.allSatisfy { $0 is UnlitMaterial })

    let parent = Entity()
    parent.addChild(first)
    first.name = "changed.scene"
    first.position = [17, 2, -9]
    part.position += [4, 3, 2]
    part.scale *= 0.5
    part.isEnabled = false
    part.components.set(OpacityComponent(opacity: 0.3))
    var faded = try #require(part.components[ModelComponent.self])
    faded.materials = [UnlitMaterial(color: .magenta)]
    part.components.set(faded)

    let third = try SceneStyle.scene(named: name)
    let pristine = try #require(third.findEntity(named: part.name))
    #expect(third !== first && third !== second && third.parent == nil)
    #expect(second.parent == nil && second.name != "changed.scene")
    #expect(second.position == rootPosition && third.position == rootPosition)
    for entity in [sibling, pristine] {
      #expect(entity.position == position && entity.scale == scale && entity.isEnabled)
      #expect((entity.components[OpacityComponent.self]?.opacity ?? 1) == 1)
      let component = try #require(entity.components[ModelComponent.self])
      #expect(component.materials.map { String(describing: type(of: $0)) } == kinds)
    }
    #expect(count(second) == count(third))
  }

  @Test
  func aDifferentResourceNameReplacesTheTemplateWithoutReturningThePreviousScene() throws {
    let bridge = try #require(BrooklynBridge.level.scene)
    let first = try SceneStyle.scene(named: bridge)
    let bridgeParts = modelParts(first).map(\.name).sorted()
    let miki = try SceneStyle.scene(named: "miki")
    let expected = try Entity.load(named: "miki", in: .main)
    #expect(modelParts(miki).map(\.name).sorted() == modelParts(expected).map(\.name).sorted())
    #expect(modelParts(miki).map(\.name).sorted() != bridgeParts)
    miki.isEnabled = false
    for child in Array(miki.children) { child.removeFromParent() }
    let returned = try SceneStyle.scene(named: bridge)
    #expect(returned !== first && returned.isEnabled && returned.parent == nil)
    #expect(modelParts(returned).map(\.name).sorted() == bridgeParts)
  }

  @Test
  func aFailedLoadThrowsInsteadOfReturningTheCachedScene() throws {
    let bridge = try #require(BrooklynBridge.level.scene)
    _ = try SceneStyle.scene(named: bridge)
    #expect(throws: (any Error).self) {
      _ = try SceneStyle.scene(named: "lauder-missing-scene-template-test")
    }
    let intact = try SceneStyle.scene(named: bridge)
    #expect(!modelParts(intact).isEmpty && intact.parent == nil)
  }

  private func modelParts(_ root: Entity) -> [Entity] {
    (root.components.has(ModelComponent.self) ? [root] : []) + root.children.flatMap(modelParts)
  }
}
