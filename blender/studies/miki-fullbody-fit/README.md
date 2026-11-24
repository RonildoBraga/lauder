# Miki full-body fitting study

**Work-in-progress motion review, 25 November 2026.** The maintainer accepted the coherent full-body approach as Miki's working visual base and assigned simplification, detail refinement and reuse of the existing skeleton and animations. This separate authoring study awaits final motion/appearance review. Canonical characters, shared motion, gameplay and app resources remain unchanged.



## Review in Blender

Open [miki-fullbody-fit-review.blend](miki-fullbody-fit-review.blend), keeping `character` beside it and the existing [Precision rifle source](../equipment/rifle-precision/README.md). Relative libraries supply both assets. **01 Run Sneak Shoot** presents the motion sequence; **02 Rest and details** supplies static inspection. The review has five orthographic body views, a face camera and a motion camera. The editable source is [character/miki-fullbody-fit.blend](character/miki-fullbody-fit.blend), collection `miki-fullbody-fit`.

![Actual native Blender view](three-quarter.png)

[Front](front.png) · [Back](back.png) · [Face](face.png)

The images and [motion reel](motion-preview.mp4) are native Blender renders of the saved candidate, with no AI image replacement or retouching. The earlier [Tripo review](../miki-fullbody-tripo/README.md) remains an unchanged comparison. The editorial sequence uses 120 fps:

| Take | Frames | Repetitions |
| --- | --- | ---: |
| Run | 1–312 | 4 |
| Sneak | 313–744 | 3 |
| Fire | 745–1104 | 5 |

The sequence lasts **9.2 seconds**. The 960 × 900 H.264 reel encodes 276 native frames at 30 fps, sampling every fourth source frame. Editorial cuts separate the clips; this does not demonstrate gameplay blending.

## Geometry, colour and equipment

A UV-preserving reduction takes the [1,931,766-triangle Tripo draft](../miki-fullbody-tripo/README.md#source-and-settings) to a **12,000-triangle core** with 5,998 unique source vertices. Semantic splitting duplicates seam vertices across objects. The saved candidate totals **8,103 vertices / 14,846 triangles**, including the auxiliary pieces below; garment correctives preserve topology. The topology is a simplified triangulated generator mesh; dedicated deformation retopology and iPhone performance are unestablished.

The bounded detail pass changes **159 source vertices**, at most approximately **1.992 mm**, around the jaw/mouth/adjacent neck. All semantic copies of an edited source vertex receive its same delta. The accepted swept-hair silhouette remains. Darker irises and the **558-vertex glove palette region** are baked through native Blender emission into one [1,024² base-colour atlas](character/textures/miki-basecolour-1k.png). UV-bearing parts share a simple matte material; auxiliary pieces use plain colours. The gloves retain their original thumb gaps and fused-finger topology, with no finger articulation. Normal and roughness/metallic maps are removed from this derivative.

| Additional piece | Vertices | Triangles |
| --- | ---: | ---: |
| Bounded coat inner shell | 1,094 | 2,009 |
| Hidden cut-boundary caps | 183 | 177 |
| Hidden hip/thigh bridge | 142 | 272 |
| Rear shoulder strap | 196 | 388 |

The closed caps seal seven original cut cycles. The hip/thigh bridge uses closed overlapping opaque lofts beneath the coat, with narrower hidden lower overlaps inside the retained pants. The back strap continues the satchel's front strap. These additions have their own provenance; their source IDs are distinct from original visible faces.

The **280-triangle Precision rifle stays independent and linked**. The review owns carry/hold transforms; neither rifle nor tablet is part of the character mesh. Fire is a fitted low-ready review, with scoped aiming, draw/stow transitions and runtime weapon attachment remaining separate work.

## Shared skeleton, derived motion and garment correctives

The study keeps **17 fitted body bones**, preserving shared names and hierarchy while adapting rest positions to Miki's proportions. The canonical [skeleton and eleven `party.*` Actions](../../animations/README.md) remain immutable. Eleven local `miki.fitted.*` body Actions regenerate from them through rest-space rotation mapping, sole-contact correction and fitted palm targets; the source opens unposed at frame 0 and preserves those reusable Actions.

The garment uses **83 corrective shape keys per part plus Basis**: 27 Run, 49 Sneak and seven Fire samples. Six local Key Actions pair the three clips with the outer coat and its lining. The experimental 18-bone pilot was rejected; it is not included. The animated review owns local mesh/Key-data copies and matching body/corrective NLA tracks; the static review owns its rest configuration. All channels are explicit, including zero values for other clips, to prevent stale shapes when switching Actions. Shared-source changes require reauthoring/rechecking the correctives; the helper checks the shared source SHA before a refresh so a body refresh cannot silently invalidate them.

[refresh-motions.py](refresh-motions.py) exposes `refresh_target(rig, body_objects, source_library, fit)` and a CLI entry point restricted to this exact study source. Its fit metadata and source signature preserve lineage. From the repository root, the public helper is invoked with Blender:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup -Y \
  blender/studies/miki-fullbody-fit/character/miki-fullbody-fit.blend \
  --python-exit-code 1 --python blender/studies/miki-fullbody-fit/refresh-motions.py
```

The helper updates only this study's derived motion and saves that study source. The linked review and garment pairing need rebuilding/verification after a valid refresh; canonical files are not saved.

## Verification and limits

The final candidate is checked through fresh native loads, resolving relative libraries/atlas, normalized skin weights, the 17-bone/eleven-body-Action contract, six matching Key Actions, exact core-motion preservation and source-bound renders. Follow [repository validation/storage rules](../../../CONTRIBUTING.md#validation).

All **62 existing Blender/export tests pass**, including compressed-file path hygiene. A read-only refresh reproduces 33 sampled body poses across all eleven Actions exactly, restores the previous pose/frame, leaves the saved character unchanged and rejects a mismatched source fingerprint before reusing garment correctives. The encoded reel fully decodes with 276 frames at 30 fps.

Independent scratch-file inspection confirms the final 17-bone rest rig and eleven body Actions match the fitted basis, all 12,000 original surface faces and declared detail edits are preserved, and **591 skinned Run/Sneak/Fire poses** stay finite with at most four normalized weights per vertex. Fourteen source-to-review comparisons, including the reported worst midpoints, match evaluated body and corrective geometry exactly. The animated and static actors own independent Key data; the static actor remains unposed. Both relative libraries and the external atlas resolve. These checks verify playback and lineage, not clean clothing contact.

Bounded auxiliary checks passed: original underbody plus caps has zero boundary/nonmanifold edges, winding conflicts or degenerate faces after a 1 µm weld; cap seam positions/weights are exact. The hip bridge's 822 rest samples stayed inside the accepted surface with at least 4.24 mm sampled clearance. Its **591 Run/Sneak/Fire poses at 240 Hz** passed **14,184 overlap-anchor tests** with finite, nondegenerate geometry and positive component volumes. A semantic colour-bake test matched all tested covered texels of the equivalent single-mesh bake; variation was confined to padding.

**Unresolved visual defect:** the coat still contacts the legs, has a ragged inner edge in some moving poses and visibly pokes through the front of the satchel in part of Run. The corrective sampling/midpoint audit measures up to approximately **36.94 mm** Run and **36.09 mm** Sneak point penetration; selected corrected samples are substantially better, so three attractive stills do not establish a clean loop. This is a review draft, not completed garment deformation. The next art task is coherent garment topology/weight cleanup before promoting it to the game. These local checks establish no collision-free clothing guarantee, final appearance, all-clip deformation approval, runtime intake or phone performance. This study includes no Swift changes, app/Simulator/phone run, canonical replacement, merge or release.

## Saved review files

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| [Character](character/miki-fullbody-fit.blend) | 19,990,597 | `4e64323bd2135b3c606e92df75b1962aabb6714facd7ae4a05f211260f47b0d6` |
| [Review](miki-fullbody-fit-review.blend) | 6,001,582 | `e6b991fd520e2470e6cb7b7b8347260b3a9934c08906d16697c7747a51faa7c8` |
| [Colour atlas](character/textures/miki-basecolour-1k.png) | 1,017,022 | `855bda50135fb7d79eb251582335e5a91a8dd0593445ef5bcab6dd89b5d543e3` |
| [Motion reel](motion-preview.mp4) | 743,137 | `f66dd340734bfe76b1be9c465a7881e1a54eba767c3af7a9b1b165dcf39098a8` |

Hashes bind this revision’s native files and encoded media. New renders are needed after any geometry, motion or material change.

## Provenance and licence

The preserved [raw GLB](../miki-fullbody-tripo/source/miki-h3-trial-v1.glb) has SHA-256 `c21f1c753a5bc2b85017ddbd9428894af0732683daae48f50832059e7ad09edd`, Tripo H3.1 job `c6145ced-0843-4f0e-bcce-283c000f5238`, generated under an active paid subscription. The [input and satchel correction](../../../art/characters/angular-study/miki-fullbody-input/README.md) retain reference lineage and exact prompts. This fitting phase uses no new generation or purchase. Raw vendor identifiers and earlier sources remain preserved.

The mesh/atlas retain the [source's paid-output provenance and applicable Tripo terms](../miki-fullbody-tripo/README.md#provenance-and-licence), separately from the earlier free head trial. Do not automatically relabel the underlying generator output as exclusively owned MIT material. Original Lauder motion, rifle, added geometry, fitting/review work, helper and documentation use the project's [MIT licence](../../../LICENSE), subject to recorded underlying rights and without an exclusive-rights claim over AI output. Native processing is agent-assisted; no human sculpting is claimed.
