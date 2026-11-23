# Miki cartoon mesh review

**Status:** Blender-first visual proposal, revised on 24 November 2026. After two concept-based passes, the maintainer clarified that the concept is loose inspiration and assigned a more appealing, cartoonish character developed directly in Blender. This study replaces the earlier candidates in the same file; both remain in Git history. Review this appearance before canonical promotion or work on Laura and Tom.

Open `miki-concept.blend`, enter its camera view and play the timeline. The model is centred without the concept card, followed by running, sneaking, aiming and shooting.

![Actual Miki cartoon mesh in its local relaxed review pose](preview.png)

## Appearance and rig

The new mesh uses a larger rounded head and cheeks, larger eyes with whites, dark pupils and small highlights, a button nose and a slight smile. Three broad hair masses frame the face. A chunky rolled fleece collar, fuller teal parka, rounded mittens and boots soften the silhouette; a simple centre zip and one pouch keep the costume readable. The coat's split hem has a matching inner rim, fitted against the existing motion. No weapon is baked into the body.

Selective smooth normals soften the face, hair, fleece, coat and boots while retaining low-poly geometry. There are no textures, subdivision modifiers, cloth simulation, facial bones or new rig controls. The palette and shading are local appearance proposals, not changes to the [canonical visual direction](../../../docs/visual-direction.md).

The `miki` collection contains one manually weighted body and its local rig Object. The Armature data and all eleven canonical `party.*` Actions link relatively to [the shared library](../../animations/README.md). The same 17 rest bones, hierarchy and source keyframes remain exact. A separate local `review.portrait` Action relaxes the arms for a static model review; it is not shared game motion or a new runtime clip.

The saved candidate has **1,974 triangles, 1,119 vertices and nine matte Principled materials**, with a rest-geometry height of about 1.86 m. Its local palette is teal `#45998B`, ink `#303443`, trousers `#4C5061`, fleece `#EFDFBE`, hair `#493B43`, skin `#DFAD86`, lips `#975D53`, boots `#44404B` and eye whites `#FAF4E9`. There is no character emission.

This is a **higher-detail visual proposal**, above the current 400-triangle runtime target. It changes no canonical character, navigation footprint, shared motion, runtime export or gameplay. Runtime import, visual scale, material/draw-call budgets and phone performance need verification before integration.

## Playback

| Take | Review frames at 120 fps | Repetitions |
|---|---:|---:|
| Relaxed portrait, local review pose | 1–241 | Static for two seconds |
| Run | 242–554 | Four 0.65-second cycles |
| Sneak | 555–987 | Three 1.2-second cycles |
| Aim | 988–1168 | One 1.5-second cycle |
| Shoot | 1169–1529 | Five 0.6-second demonstrations |

The editorial Action concatenates the local portrait and exact shared source keys with labelled cuts. It demonstrates motion rather than gameplay transitions or animation-driven firing. Muted `SOURCE ONLY` NLA tracks retain all eleven unchanged source Actions without evaluating over the review timeline.

The [motion reel](motion-preview.mp4) renders the saved scene as H.264 at 1080 × 864 and 30 fps, with 383 decoded frames and about 12.77 seconds. It is review media outside the app's resources.

The **Review context - never exported** collection contains the camera, labels, snow floor, placement parent, local soft front-fill light and simple carbine proxy. Bridge lights stay linked and unchanged. The proxy follows the shooting hand during Aim/Shoot; it is not new weapon art, a gameplay shot origin or proof of runtime grip alignment. The game fits hands to its authoritative weapon separately. These views use artist review framing and lighting rather than the exact gameplay camera.

## Source and licence

- **Source:** Original mesh and manual skin weights authored for Lauder by Codex in Blender 5.3, retaining the [Miki rig convention](../../assets/miki/README.md) and linked shared motion. The [AI-generated party concept](../../../art/characters/README.md) is loose inspiration. No third-party mesh, rig, texture or animation was imported.
- **Licence:** The project's [MIT licence](../../../LICENSE). Shared motion and the concept image retain their existing provenance.
- **Editable source:** `miki-concept.blend`, stored with Git LFS. It is unregistered review material under `blender/studies`, so saving it does not replace the canonical model or export review context into the game.

| File | Size in bytes | Storage |
|---|---:|---|
| `miki-concept.blend` | 3,195,863 | Format-wide Git LFS rule |
| `preview.png` | 1,336,753 | Explicit Git LFS rule; PNG metadata removed with compressed pixels unchanged |
| `motion-preview.mp4` | 945,234 | Explicit Git LFS rule for deliberate review footage |

## Verification

A fresh independent audit samples **2,303 poses across all eleven canonical clips at 240 Hz**. Rest hierarchy and linked source Action curves match the shared library exactly. Weights are normalized, with no loose vertices, nonfinite deformation, degenerate rest triangles or joint gaps. The 469 tagged head vertices follow the head rigidly, within **0.000125 mm**. The lowest sampled sole is **−0.250 mm**, rounded outwards. Fifty-two additional matrix comparisons confirm the editorial timeline's selected source poses, including five comparisons to the separate local portrait pose.

After fitting the openings and matching the inner rim, the audit detects **zero strict coat/trouser surface crossings** across all eleven clips. Sampled hem vertices remain at least **39.39 mm** from the trouser surface; that is not the global minimum between every pair of surfaces. A sleeve edge reaches **2.390 times** rest length during Aim/Shoot, rounded outwards. The inspected surfaces stay continuous; sampled checks do not establish complete self-collision or physical cloth behaviour.

Actual front, rear, running, sneaking and shooting renders were inspected. Connected Blender playback was observed through Run, Sneak and Shoot and left playing the full review timeline. The preview has no visible hem slivers or detached sleeve in those views. A small step remains in the rear hair silhouette, and the raised-arm shoulders remain angular. These are visual-review limitations, not accepted final art.

Public/private geometry, weights, materials, skeleton and motion fingerprints match after relative-path resaving. Both linked libraries resolve, with no image dependencies. All 48 construction-start fingerprints for canonical Blender sources, runtime content and the export ledger remain unchanged. The existing **62 Blender/export tests pass**, including saved-file path hygiene. No app build, Simulator test, phone test, merge or release is included in this Blender-only revision.

Visual acceptance, final hand contact and game-camera readability still require review. Blender checks do not establish native runtime import, phone performance or the character's biography.
