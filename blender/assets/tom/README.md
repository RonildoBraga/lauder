# tom

**Preserved bridge reference:** this model is not packaged by the active graybox duel. Its [reference export](../../reference-exports/README.md), authoring history and licence remain available. Descriptions below refer to the bridge prototype.

Tom's pawn: a tapering eight-sided body with shoulders in his colour, a round head in the party's skin tone, and a dark beanie with a turned-up fold and a snow-white pompom. The beanie sits square on his head, so it is his lean as he walks, rather than his head, that shows which way he faces. The game creates it from its own scene file, `blender/reference-exports/models/tom.usdz`, which saving this file exports ([ADR 0002](../../../docs/decisions/0002-blender-source-of-truth.md)). The Brooklyn Bridge shows it in its Preview collection, at his start. It has no rig: the game moves the whole figure as he walks and rolls.

- **Source:** Made for Lauder with Claude's assistance on 25 November 2026 from primitive shapes, to the pawn of the [mock-up sheet](../../../art/party/README.md) that the maintainer chose and confirmed ([issue #142](https://github.com/RonildoBraga/lauder/issues/142)). It replaces his stand-in of 19 November 2026. No third-party models or textures were used.
- **Licence:** The repository's [MIT licence](../../../LICENSE).
- **Size:** 0.55 m across, 0.55 m long and 1.635 m high, facing −y; six parts (body, shoulders, head, beanie, fold and pompom), 228 triangles in all; four materials, `tom clothing` (his colour, `#6182CF`), `tom skin` (the palette's Skin, `#D9A27E`), `tom beanie` (Ink, `#36414B`, which the fold shares) and `tom pompom` (Snow, `#ECE9E2`); no textures. About 95 KB, stored with Git LFS.
