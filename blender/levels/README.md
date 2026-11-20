# Levels

Each Blender file here is a level's source ([ADR 0002](../../docs/decisions/0002-blender-source-of-truth.md)). Saving it in Blender, with the Lauder extension, exports the files the game reads, as [Editing a level in Blender](../../CONTRIBUTING.md#editing-a-level-in-blender) describes.

## brooklyn-bridge.blend

The Brooklyn Bridge, the opening's greybox level, buried in snow as the frozen [visual direction](../../docs/visual-direction.md) has it: only the towers stand above a white plain, and snowbanks and drifts show where the railings, the walkway's base and the vehicles were.

- **Made** for Lauder on 19 November 2026, by the Lauder extension's Load, from the hand-kept layout and palette files that it replaces. Its vehicles are copies of the `car`, `van` and `truck` models, linked from [blender/assets](../assets/README.md). It holds no third-party assets or textures.
- **Licence:** the repository's MIT licence.
- **Size:** about 117 KB, stored with Git LFS. A copy without its payload is a small pointer file; run `git lfs pull`.
- **Exports:** `apple/sources/content/BrooklynBridge.usdz`, about 8 KB, and `apple/sources/content/BrooklynBridgeLayout.swift`. `blender/level-exports.json` records the fingerprints of both, of the level file, and of the models it links.
