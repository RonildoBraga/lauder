# Levels

Each Blender file here is a level's source ([ADR 0002](../../docs/decisions/0002-blender-source-of-truth.md)). Saving it in Blender, with the Lauder extension, exports the files the game reads, as [Editing a level in Blender](../../CONTRIBUTING.md#editing-a-level-in-blender) describes.

## brooklyn-bridge.blend

The Brooklyn Bridge, the opening's level, buried in snow as the frozen [visual direction](../../docs/visual-direction.md) has it. The low-poly environment pass of 23 November 2026 follows the [selected gameplay concept](../../art/bridge/bridge-gameplay-v1.png): twin pointed arches, chamfered stone piers with weathered bases and snow-coloured tops, thin dark cable fans and broad, low snow facets beside the route. Thin flagged poles still mark both edges of the buried road every 25 m, and an invisible edge keeps the party on its line.

The environment pass preserved the six tower collision boxes, markers, encounter areas, route, camera and lights. The maintainer subsequently selected camera B: offset `[0, 56, 44]` in game coordinates and vertical field of view 22°. The camera changes in Blender and the layout export; the gameplay geometry and lights remain unchanged. The snow drifts stay outside the walkable width and add no terrain or cover. Each tower's cable fans fade with that tower when it hides the party. The masonry's long shadows are baked into the snow; thin cables have no baked or runtime shadow. The first human shooter is being replaced by C; the later knife-attacker scene remains. The first robot blockout's proportions were rejected; the maintainer then selected concept C for a new, separate Blender form study. Its encounter behaviour remains proposed.

- **Made** for Lauder on 19 November 2026, by the Lauder extension's Load, from the hand-kept layout and palette files that it replaces. Codex authored the environment pass directly in Blender through MCP on 23 November 2026. It has linked no exported [models](../assets/README.md) since the snow buried its vehicles on 20 November 2026; linked party models remain preview-only. It holds no third-party assets or textures.
- **Licence:** the repository's MIT licence.
- **Size:** about 129 KB, stored with Git LFS. A copy without its payload is a small pointer file; run `git lfs pull`.
- **Exports:** `apple/sources/content/BrooklynBridge.usdz`, about 44 KB, and `apple/sources/content/BrooklynBridgeLayout.swift`. Saving queues the standard background exporter; `blender/level-exports.json` records the fingerprints of both and of the level file. The layout export is byte-for-byte unchanged by the environment pass.
- **Visual budget:** 19 mesh objects, 2,724 triangles, six materials and 33 used object/material partitions in the whole exported scene. The runtime layout retains two suns, one casting shadows. Partitions are an authoring measure, not measured GPU draw calls or a phone performance result.

The C integration adds one nonblocking `bridge-supply-case` Visual mesh at game coordinates `[-8.5, -8]`, its `supply.case` marker, an outgoing west-side search area and `robot.exit` area. Tom's spawn marker moves to `[2, -3]` for the case/ambush framing. The six tower blockers, ground, camera B and lights are unchanged. The C guard is spawned by gameplay from its own model export, so it is not duplicated as bridge scenery.
