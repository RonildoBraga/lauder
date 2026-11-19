# Levels

Each Blender file here is a level's source ([ADR 0006](../../docs/decisions/0006-blender-source-of-truth.md)). Saving it in Blender, with the Lauder extension, exports the files the game reads, as [Editing a level in Blender](../../CONTRIBUTING.md#editing-a-level-in-blender) describes.

## brooklyn-bridge.blend

The Brooklyn Bridge, the opening's greybox level.

- **Made** for Lauder on 19 November 2026, by the Lauder extension's Load, from the hand-kept layout and palette files that it replaces. It holds no third-party assets, models or textures.
- **Licence:** the repository's MIT licence.
- **Size:** about 180 KB, stored with Git LFS. A copy without its payload is a small pointer file; run `git lfs pull`.
- **Exports:** `apple/sources/content/BrooklynBridge.usdz`, about 14 KB, and `apple/sources/content/BrooklynBridgeLayout.swift`. `blender/level-exports.json` records the fingerprints of all three files.
