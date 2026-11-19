# hostile

The hostiles' stand-in: the party's shape in a dark red that reads as a threat. The game creates one for each hostile from its own scene file, `apple/sources/content/models/hostile.usdz`, which saving this file exports ([ADR 0002](../../../docs/decisions/0002-blender-source-of-truth.md)).

- **Source:** Made for Lauder with Claude's assistance on 19 November 2026, from the sizes and colours that the game's code drew the stand-ins with until then (`SceneStyle`). No third-party models or textures were used.
- **Licence:** The repository's [MIT licence](../../../LICENSE).
- **Size:** 0.4 m across, 0.34 m long and 1.58 m high, facing −y; seven parts, 1,032 triangles in all, 960 of them the head; four materials, `hostile clothing`, `hostile head`, `hostile gear` and `hostile mark`, the mark glowing as the game drew it, unlit; no textures. About 105 KB, stored with Git LFS.
