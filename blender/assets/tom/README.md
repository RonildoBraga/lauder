# tom

Tom's stand-in: a body in his colour, a head, two legs and two feet, and a front mark that shows which way he faces. The game creates it from its own scene file, `apple/sources/content/models/tom.usdz`, which saving this file exports ([ADR 0002](../../../docs/decisions/0002-blender-source-of-truth.md)). The Brooklyn Bridge shows it in its Preview collection, at his start.

- **Source:** Made for Lauder with Claude's assistance on 19 November 2026, from the sizes and colours that the game's code drew the stand-ins with until then (`SceneStyle`). No third-party models or textures were used.
- **Licence:** The repository's [MIT licence](../../../LICENSE).
- **Size:** 0.49 m across, 0.34 m long and 1.58 m high, facing −y; seven parts, 1,032 triangles in all, 960 of them the head; four materials, `tom clothing`, `tom head`, `tom gear` and `tom mark`, the mark glowing as the game drew it, unlit; no textures. About 105 KB, stored with Git LFS.
