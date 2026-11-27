# crawler

The pack crawlers that join the first-tower guard's fight ([issue #208](https://github.com/RonildoBraga/lauder/issues/208)): a low hexagonal body with a ridge along its back, four stubby legs and the guard's red sensor across its front. The game creates one for each crawler from its own scene file, `apple/sources/content/models/crawler.usdz`, which saving this file exports ([ADR 0002](../../../docs/decisions/0002-blender-source-of-truth.md)). The game walks each crawler, swings its legs from their hips, crouches it for a wind-up, tips it into a ram and draws the sensor in unlit red, as it draws the guard's eye.

- **Source:** Made for Lauder with Claude's assistance on 27 November 2026, from simple shapes built by a script in Blender, in the guard's armour and slate colours. No third-party models or textures were used.
- **Licence:** The repository's [MIT licence](../../../LICENSE).
- **Size:** 0.62 m across, 0.79 m long and 0.43 m high, standing on z = 0 at its origin and facing −y. Eight parts, 104 triangles in all. Each leg's origin is its hip. Three materials, `crawler armour`, `crawler slate` and `crawler eye`, the eye glowing; no textures. About 92 KB, stored with Git LFS.
