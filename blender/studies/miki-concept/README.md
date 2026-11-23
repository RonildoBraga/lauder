# Miki concept mesh review

**Status:** Blender-first visual review, refined on 24 November 2026 after the maintainer said the first mesh looked very different from the [party concept](../../../art/characters/README.md) and assigned an enhancement. The current candidate replaces that 400-triangle attempt in this study. Laura and Tom, canonical models, shared motion, runtime exports and gameplay remain unchanged. Review the likeness and proposed asset budget before promotion or work on the other characters.

Open `miki-concept.blend`, enter its camera view and play the timeline. The original concept appears beside the animated mesh. The reference card uses a UV crop of the original image, not an edited image or a character texture.

![Actual refined Miki mesh in the existing standing Idle pose beside the concept reference](preview.png)

## Appearance and rig

The refined mesh has a tapered jaw and cheek planes, shaped eyes/brows, a shallow nose and mouth, a continuous volumetric bob with an asymmetric sweep, solid folded lapels, fuller eight-sided sleeves and trousers, longer gloves with thumbs, ankle shafts and chamfered shoe/sole geometry. The broader sling follows the torso's skin weights, and the pouch has a bevel and flap. Large forms take priority over small details. No weapon is baked into the body.

The `miki` collection contains one manually weighted body and its local rig Object. Its Armature data and all eleven source Actions link relatively to [the existing shared library](../../animations/README.md). Rest joints, hierarchy and source keyframes are unchanged. All characters continue to share the same motion source; there is no new retargeting or animation system.

The current study has **1,287 triangles, 735 vertices and nine matte Principled materials**, with no character textures, emission, cloth simulation, new bones or facial rig. Its visual height is about 1.78 m; the original bone rest positions and lengths remain exact. This is a **higher-detail visual proposal**, above the current 400-triangle runtime target. It does not change that target, the navigation footprint or the canonical models. Runtime import, material/draw-call budgets and phone performance need verification before integration.

The local study palette uses muted teal `#4A8B80`, dark cloth `#34363B`, trousers `#505052`, collar `#E7D7B8`, hair `#3D383C`, skin `#D4A07B`, nose shade `#BC8567`, lips `#A66F5B` and boots `#49464A`. These are appearance proposals; the canonical party/world palette in the [visual direction](../../../docs/visual-direction.md) is unchanged.

## Playback

| Take | Review frames at 120 fps | Repetitions |
|---|---:|---:|
| Standing comparison (existing Idle) | 1–241 | One 2-second cycle |
| Run | 242–554 | Four 0.65-second cycles |
| Sneak | 555–987 | Three 1.2-second cycles |
| Aim | 988–1168 | One 1.5-second cycle |
| Shoot | 1169–1529 | Five 0.6-second demonstrations |

The local review Action concatenates exact source keys with labelled cuts. It illustrates motion, not gameplay transitions or an animation-driven firing system. Muted `SOURCE ONLY` NLA tracks retain direct references to all eleven unchanged source Actions; they do not evaluate over the review timeline.

The [motion reel](motion-preview.mp4) renders the saved scene as H.264 at 1080 × 810 and 30 fps, with 383 decoded frames and about 12.77 seconds, including explicit take cuts and the standing comparison. It is review media outside the app's resources.

The **Review context - never exported** collection contains the concept card, camera, labels, snow floor, placement parent, local soft front-fill light and simple carbine proxy. Bridge lights remain linked and unchanged. The added fill, camera framing and standing take help compare the shapes; this is an artist review, not an exact game-camera/lighting capture or an identical reference pose. The proxy follows the shooting hand during Aim/Shoot. It is not new weapon art, a gameplay shot origin or proof of runtime grip alignment. The game fits hands to its authoritative weapon separately.

## Source and licence

- **Source:** Original mesh and manual skin weights authored for Lauder by Codex in Blender 5.3, retaining the [Miki rig convention](../../assets/miki/README.md) and linked shared motion. Geometry was rebuilt for the assigned likeness refinement; the AI-generated concept guides appearance. No third-party mesh, rig, texture or animation was imported.
- **Licence:** The project's [MIT licence](../../../LICENSE). Shared motion and the reference image retain their existing provenance.
- **Editable source:** `miki-concept.blend`, stored with Git LFS. It is unregistered review material under `blender/studies`, so saving it does not replace the canonical model or export review context to the game.

| File | Size in bytes | Storage |
|---|---:|---|
| `miki-concept.blend` | 3,494,232 | Format-wide Git LFS rule |
| `preview.png` | 1,684,268 | Explicit Git LFS rule; PNG metadata removed with compressed pixels unchanged |
| `motion-preview.mp4` | 724,733 | Explicit Git LFS rule for deliberate review footage |

## Verification

An independent saved-source audit samples **2,303 poses across all eleven clips at 240 Hz**. The shared 17-bone rest hierarchy and all eleven linked source Action curves match the canonical library exactly. All vertices have valid normalized weights, with no loose geometry, nonfinite coordinates, degenerate rest triangles or joint gaps. The lowest sole sample is **−0.248 mm**, rounded outwards. Fifty-two additional matrix comparisons verify that the five-take editorial timeline reproduces the selected source poses exactly.

The shallower coat openings and fuller trousers were fitted together, and sleeve/ankle weights blend over neighbouring rings. The final audit detects **zero strict coat/trouser surface crossings** across the eleven clips, with at least **28.70 mm** from sampled hem vertices to the trouser surface. This is not a global minimum between every pair of surfaces. A sleeve edge reaches **2.173 times** its rest length during Aim/Shoot; the inspected surface remains continuous. This diagnostic is recorded rather than treated as a physical cloth guarantee or proof that every surface is free of self-intersection.

Actual standing/front, side and rear renders were inspected for running, sneaking and shooting; final side views recheck the weight/clearance changes. Live Blender playback shows the standing take, Run, Sneak and Shoot beside the concept. No visible tear or new trouser puncture was found in those views; the shooting proxy meets the hands and clears the face. All 48 construction-start fingerprints for canonical Blender sources, runtime content and the export ledger remain unchanged. Relative image/library paths resolve. The existing **62 Blender/export tests pass**, including saved-file path hygiene. No app or Simulator test was run for this Blender-only refinement.

Visual likeness, skin deformation, weapon contact and camera readability require review. Blender checks do not establish native runtime import, physical-phone performance or approval of the character's biography.
