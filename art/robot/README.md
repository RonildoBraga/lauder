# Robot enemy — concept proposal

**Status:** Dark armed v3 look selected by the maintainer. [Movement and combat](../../docs/encounters/bridge-spider-bot.md) are being designed before implementation.

**Updated:** 23 November 2026.

After the first study, the maintainer supplied [Low-poly Spider Bot (Rigged) by rznn7](https://rznn7.itch.io/low-poly-spider-bot) as the shape reference, then requested guns and darker colours. The selected revision uses that upright head and leggy stance in the preferred [bridge gameplay view](../bridge/bridge-gameplay-v1.png)'s matte low-poly style. Its history, allegiance and combat behaviour remain undecided.

## Current design — dark armed spider bot

![Dark armed spider-robot concept sheet with multiple views and body poses](robot-design-v3.png)

The upright chamfered head has a square front sensor, two antennae, a small disk-shaped underside and four long angular legs. Four legs are this concept's interpretation, rather than a verified count for the linked model. Charcoal armour and slate facets replace the earlier pale casing; a deep-red face and pale square sensor identify the front. Two compact side-mounted gun pods each have one forward-facing barrel.

The upper row shows three-quarter, side and overhead views. The lower row explores body poses only. Adding guns does not settle whether the robot lunges, how it fires, or how attacks and recovery work.

## Current bridge-scale study

![One dark armed spider robot on the snowbound bridge at a high gameplay angle](robot-bridge-scale-v3.png)

This composite explores silhouette, facing, contrast and gun-pod readability. Relative size and placement are illustrative; the image is not a pixel-exact scene edit, metric specification, playable encounter or approved spawn.

The three travellers are shown for visual scale. The selected first-encounter replacement happens earlier with Miki alone; the picture does not set story staging.

## Review boundaries

- Preserve the sparse, matte, untextured, faceted look and clear separation from the party.
- Keep the central head, four-leg stance and square sensor readable before adding detail.
- Guns are visual proposals. Targeting, detection, firing, ammunition, damage, attack timing, movement, collision and retreat rules remain undecided.
- No aim lines, warning zones, muzzle flashes, projectiles or effects are depicted.
- No Swift, Blender, rig, inverse-kinematics or procedural-animation implementation accompanies the studies. Mesh budgets and phone performance are unverified.

## Current provenance and licensing

Generated with the built-in image-generation tool. The shape study used the creator's public preview and our historical v1 sheet; the darker armed edit then added gun pods, and the final composite used the bridge view and armed sheet. Superseded comparison art and the unarmed intermediate were removed at the maintainer's request. Exact prompts, input roles and historical source links remain in [prompts-v3.md](prompts-v3.md).

These two reference-derived PNGs carry the source attribution and **CC BY 4.0** file-level notice in [attribution.md](attribution.md). They must not be described as wholly original, third-party-free MIT artwork. No Blender or FBX file was downloaded or imported, and no creator endorsement is implied.

| File | Dimensions | Size in bytes |
|---|---|---:|
| `robot-design-v3.png` | 1672 × 941 | 1,643,963 |
| `robot-bridge-scale-v3.png` | 1672 × 941 | 1,559,198 |

Both exceed 1 MiB and have explicit Git LFS rules under the [storage policy](../../CONTRIBUTING.md#git-lfs-and-cloning).
