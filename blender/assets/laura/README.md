# laura

**Preserved bridge reference:** this model is not packaged by the active graybox duel. Its [reference export](../../reference-exports/README.md), authoring history and licence remain available. Descriptions below refer to the bridge prototype.

Laura's pawn: a tapering eight-sided body with shoulders in her colour, a round head in the party's skin tone, and a hood in her colour set back from her face, with a snow-white rim around the face that shows which way she faces. The game creates it from its own scene file, `blender/reference-exports/models/laura.usdz`, which saving this file exports ([ADR 0002](../../../docs/decisions/0002-blender-source-of-truth.md)). The Brooklyn Bridge shows it in its Preview collection, at her start. It has no rig: the game moves the whole figure as she walks and rolls.

- **Source:** Made for Lauder with Claude's assistance on 25 November 2026 from primitive shapes, to the pawn of the [mock-up sheet](../../../art/party/README.md) that the maintainer chose and confirmed ([issue #142](https://github.com/RonildoBraga/lauder/issues/142)). It replaces her stand-in of 19 November 2026. No third-party models or textures were used.
- **Licence:** The repository's [MIT licence](../../../LICENSE).
- **Size:** 0.55 m across, 0.62 m long and 1.54 m high, facing −y; five parts (body, shoulders, head, hood and rim), 296 triangles in all; three materials, `laura clothing` (her colour, `#E69C4A`, which the hood shares), `laura skin` (the palette's Skin, `#D9A27E`) and `laura fur` (Snow, `#ECE9E2`); no textures. About 94 KB, stored with Git LFS.
