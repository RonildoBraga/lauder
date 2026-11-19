// How each surface looks (ADR 0005): the game's small shared material palette, for every
// level. Colours are sRGB, each channel from 0 to 1. Blender edits this file through its Lauder
// extension (blender/extensions/lauder_levels): Load builds Blender's materials from it and Save
// writes them back. The numbers can also be edited here, and the next Load picks them up. Keep
// the entries in this form so that the script can read them.
// After an edit here, export the scene file again: blender/scripts/export-scene.py.

enum Surfaces {
  static let palette: [Level.Surface: Level.Finish] = [
    .concrete: .finish(color: [0.56, 0.57, 0.45], roughness: 1),
    .hazard: .finish(color: [0.59, 0.33, 0.23], roughness: 1),
    .asphalt: .finish(color: [0.27, 0.29, 0.29], roughness: 1),
    .steel: .finish(color: [0.42, 0.48, 0.5], roughness: 0.9),
    .granite: .finish(color: [0.66, 0.62, 0.54], roughness: 1),
    .vehicle: .finish(color: [0.47, 0.38, 0.33], roughness: 1),
    .metal: .finish(color: [0.16, 0.25, 0.25], roughness: 0.9),
    .river: .finish(color: [0.13, 0.2, 0.24], roughness: 0.8),
    .paint: .finish(color: [0.65, 0.68, 0.55], roughness: 1),
    .glass: .finish(color: [0.14, 0.19, 0.21], roughness: 0.7),
  ]
}
