# scout-drone

**Preserved bridge reference:** this model is not packaged by the active graybox duel. Its [reference export](../../reference-exports/README.md), authoring history and licence remain available. Descriptions below refer to the bridge prototype.

The scout drones that keep watch with the first-tower guard ([issue #201](https://github.com/RonildoBraga/lauder/issues/201)): a small dark body on four arms, with two-bladed rotors and the guard's red eye. The game creates one for each drone from its own scene file, `blender/reference-exports/models/scout-drone.usdz`, which saving this file exports ([ADR 0002](../../../docs/decisions/0002-blender-source-of-truth.md)). The game flies the drones, spins each rotor about its hub and draws the eye in unlit red, as it draws the guard's.

- **Source:** Made for Lauder with Claude's assistance on 27 November 2026, from simple shapes built by a script in Blender, in the guard's armour and slate colours. No third-party models or textures were used.
- **Licence:** The repository's [MIT licence](../../../LICENSE).
- **Size:** 0.75 m across, 0.75 m long and 0.18 m high, standing on z = 0 at its centred origin and facing −y. Eight parts, 228 triangles in all, 100 of them the eye. Each rotor's origin is its hub. Three materials, `scout-drone armour`, `scout-drone slate` and `scout-drone eye`, the eye glowing; no textures. About 94 KB, stored with Git LFS.
