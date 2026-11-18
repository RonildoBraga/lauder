import RealityKit

/// The decoration that blocks nothing: the level's pieces, which its layout file lists and
/// Blender edits (ADR 0005). The level's boxes carry all collision.
@MainActor
enum SceneDressing {
  static func add(to root: Entity, style: SceneStyle, level: Level) {
    let dressing = Entity()
    dressing.name = "scene-dressing"
    root.addChild(dressing)
    for piece in level.pieces {
      let entity = style.block(
        size: piece.size, at: piece.position, material: style.material(for: piece.surface))
      entity.name = "dressing.\(piece.name)"
      entity.orientation = piece.rotation
      dressing.addChild(entity)
    }
  }
}
