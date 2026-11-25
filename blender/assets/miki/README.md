# miki

Miki's pawn: a tapering eight-sided body with shoulders in her colour, a round head in the party's skin tone, and dark hair set back so that her bare face shows which way she faces. The game creates it from its own scene file, `apple/sources/content/models/miki.usdz`, which saving this file exports ([ADR 0002](../../../docs/decisions/0002-blender-source-of-truth.md)). The Brooklyn Bridge shows it in its Preview collection, at her start. It has no rig: the game moves the whole figure as she walks and rolls.

- **Source:** Made for Lauder with Claude's assistance on 25 November 2026 from primitive shapes, to the pawn of the [mock-up sheet](../../../art/party/README.md) that the maintainer chose and confirmed ([issue #142](https://github.com/RonildoBraga/lauder/issues/142)). It replaces her stand-in of 19 November 2026. No third-party models or textures were used.
- **Licence:** The repository's [MIT licence](../../../LICENSE).
- **Size:** 0.55 m across, 0.55 m long and 1.535 m high, facing −y; four parts (body, shoulders, head and hair), 216 triangles in all; three materials, `miki clothing` (her colour, `#40A696`), `miki skin` (the palette's Skin, `#D9A27E`) and `miki hair` (Ink, `#36414B`); no textures. About 93 KB, stored with Git LFS.
