# Robot enemy — concept proposal

**Status:** Visual design for maintainer review; no enemy implementation is assigned by these images.

**Created:** 23 November 2026.

The maintainer preferred the [bridge gameplay view](../bridge/bridge-gameplay-v1.png) and requested a robot enemy concept in the same low-poly style before implementation. These studies explore a compact four-legged maintenance machine as a possible threat. Its history, allegiance and reason for hostility remain undecided.

## Design sheet

![Low-poly robot design views and proposed motion poses](robot-design-v1.png)

The upper row shows three-quarter, side and overhead views of one proposed robot. The lower row explores idle, a crouched wind-up, a short grounded lunge and recovery, from left to right. These are pose ideas, not an animation clip or agreed attack rules.

The broad dark-red shell follows the existing hostile accent, with a small forward sensor, neutral panels, charcoal joints and four chunky legs. Large flat shapes and broad feet are intended to remain readable from the game camera. Exact materials, geometry and joint construction would need their own model review.

## Bridge-scale study

![One proposed robot placed on the snowbound bridge at a high gameplay angle](robot-bridge-scale-v1.png)

The robot is inserted into the preferred bridge concept to discuss silhouette, contrast, facing and relative scale. The surrounding composition is retained visually; this is not a pixel-exact scene edit, a playable encounter or approved enemy placement. The design prompt explores a knee-to-waist-high machine; the illustration does not establish metric dimensions.

## Review boundaries

- Preserve the bridge study's matte, untextured, faceted look and restrained palette.
- Keep the robot distinct from the party's teal, orange and blue and the existing amber interaction cues.
- Use body and leg poses to communicate intent. No glowing indicators, aim lines, weapons or extra effects are proposed by these images.
- Robot behaviour, targeting, detection, attack timing, damage, collision, retreat options and defeat rules remain undecided.
- No Swift, Blender, rigging, inverse-kinematics or procedural-animation implementation accompanies these studies. Mesh counts and phone performance are unverified.

## Provenance

Generated with the built-in image-generation tool. The design sheet uses an original text prompt based on the project's [visual direction](../../docs/visual-direction.md). The bridge-scale edit uses the generated [bridge gameplay image](../bridge/bridge-gameplay-v1.png) as its environment target and the design sheet as its robot identity reference. No third-party game assets or video frames were supplied. Exact prompts and input roles are preserved in [prompts.md](prompts.md).

| File | Dimensions | Size in bytes |
|---|---|---:|
| `robot-design-v1.png` | 1672 × 941 | 1,695,981 |
| `robot-bridge-scale-v1.png` | 1672 × 941 | 1,551,930 |

These are AI-generated PNG concept studies, with no corresponding editable Blender source or runtime model. See the project [licence](../../LICENSE) and [asset contribution guidance](../../CONTRIBUTING.md#assets-and-attribution). Both images exceed 1 MiB and have explicit Git LFS rules under the [storage policy](../../CONTRIBUTING.md#git-lfs-and-cloning).
