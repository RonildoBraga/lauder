# Miki concept mesh review

**Status:** Assigned on 24 November 2026 after the maintainer reviewed the [party concept sheet](../../../art/characters/README.md). Miki's new mesh is a Blender-first study for visual review. Laura and Tom, canonical party models, shared motion, runtime exports and gameplay remain unchanged. Review the result before promoting it into the game or rebuilding the other characters.

Open `miki-concept.blend`, enter its camera view and play the timeline. The original concept appears beside the animated mesh. The reference card uses a UV crop of the original image, not an edited image or a character texture.

![Actual Miki mesh running beside the concept reference](preview.png)

## Appearance and rig

The mesh explores Miki's swept angular bob, tapered teal work parka, split coat tails, raised pale collar, cuffs, dark trousers/boots, belt, sling and compact tool pouch. Large forms take priority over the concept's smaller details. The sling is clothing; no weapon is baked into the body.

The `miki` collection contains one manually weighted body and its local rig Object. Its Armature data and all eleven source Actions link relatively to [the existing shared library](../../animations/README.md). Rest joints, hierarchy and source keyframes are unchanged. All characters continue to share the same motion source; there is no new retargeting or animation system.

The new appearance stays at **400 triangles and 233 vertices**, with five matte Principled materials, no character textures, emission, cloth simulation, new bones or facial rig. Rest height remains 1.74 m. This study does not change the game's navigation footprint or make a performance claim.

## Playback

| Take | Review frames at 120 fps | Repetitions |
|---|---:|---:|
| Run | 1–313 | Four 0.65-second cycles |
| Sneak | 314–746 | Three 1.2-second cycles |
| Aim | 747–927 | One 1.5-second cycle |
| Shoot | 928–1288 | Five 0.6-second demonstrations |

The local review Action concatenates exact source keys with labelled cuts. It illustrates motion, not gameplay transitions or an animation-driven firing system. Muted `SOURCE ONLY` NLA tracks retain direct references to all eleven unchanged source Actions; they do not evaluate over the review timeline.

The [motion reel](motion-preview.mp4) renders this saved scene at 1080 × 810, H.264, 30 fps, 322 decoded frames and about 10.73 seconds, including the explicit take cuts. It is review media outside the app's resources.

The **Review context - never exported** collection contains the concept card, camera, labels, floor, placement parent and a simple carbine proxy. Bridge lighting is linked relatively. The proxy follows the shooting hand during Aim/Shoot to check the source pose. It is not new weapon art, a gameplay shot origin or proof of runtime grip alignment. The game already fits hands to its authoritative weapon separately.

## Source and licence

- **Source:** Original mesh and manual skin weights authored for Lauder by Codex in Blender 5.3, using the accepted [Miki source](../../assets/miki/README.md) and rig convention as the starting point. The [AI-generated concept](../../../art/characters/README.md) guides appearance; no third-party mesh, rig, texture or animation was imported.
- **Licence:** The project's [MIT licence](../../../LICENSE). Shared motion and the reference image retain their existing provenance.
- **Editable source:** `miki-concept.blend`, stored with Git LFS. It is unregistered review material under `blender/studies`, so saving it does not replace the canonical model or export review context to the game.

| File | Size in bytes | Storage |
|---|---:|---|
| `miki-concept.blend` | 3,754,249 | Format-wide Git LFS rule |
| `preview.png` | 1,751,733 | Explicit Git LFS rule; PNG metadata removed with compressed pixels unchanged |
| `motion-preview.mp4` | 714,955 | Explicit Git LFS rule for deliberate review footage |

## Verification

An independent saved-source audit samples **2,303 poses across all eleven clips at 240 Hz**. The shared 17-bone rest hierarchy and all eleven linked source Action curves match the canonical library exactly. All surface vertices have valid normalized weights; the maximum sum error is below 0.00000003. No nonfinite coordinates, degenerate rest triangles or joint gaps were found. The lowest sole sample is **−0.250 mm**, rounded outwards.

The first candidate exposed small trouser patches through the lower coat. The final hem adds 4 cm of outward depth and 2 cm of clearance in height, with 55% thigh/45% pelvis weighting; the notch weights stay separate. The first sleeve ring blends 70% upper arm/30% chest to reduce socket stretching. The final audit detects **zero strict coat/trouser surface crossings** across the eleven clips, with at least **14.15 mm** from sampled hem vertices to the trouser surface. This distance is not a global minimum between every pair of surfaces. Maximum mesh-edge length change is below 1.867 times rest length; it is a deformation diagnostic, not a physical cloth guarantee.

Actual front, side and rear renders were inspected for the requested running, sneaking and shooting poses. The previous visible trouser patches are absent in those rechecked views; the shooting proxy meets the hands and clears the face. All 48 construction-start fingerprints for canonical Blender sources, runtime content and the export ledger remain unchanged. The existing **62 Blender/export tests pass**, including saved-file path hygiene. No app or Simulator test was run for this Blender-only study.

Visual likeness, skin deformation, weapon contact and camera readability require review. Blender checks do not establish native runtime import, physical-phone performance or approval of the character's biography.
