# Reference-led Miki A-pose blockout

**Status:** Assigned modelling study, 24 November 2026. The maintainer approved the [Miki-only reference sheets](../../../art/characters/angular-study/miki-reference/README.md) as the modelling basis and asked to proceed. This fresh, unrigged A-pose rebuilds the head, torso, shoulders and coat from those views. The actual mesh awaits visual review before detail, rig or animation fitting. Reference approval does not establish final mesh approval.

![Approved three-quarter reference beside the actual Blender blockout](three-quarter.png)

## Open and compare

Open `miki-reference-blockout.blend`. It starts on the three-quarter comparison. The scene selector also provides:

| Scene | Purpose |
|---|---|
| `01 Front comparison` | Orthographic front beside the approved front reference |
| `02 Left profile comparison` | Wearer-left profile beside its reference |
| `03 Back comparison` | Orthographic back beside the approved back reference |
| `04 Right profile comparison` | Wearer-right profile beside its reference |
| `05 Three-quarter comparison` | Default comparison of the main silhouette and overlapping forms |
| `06 Character artist view` | Enlarged view of the actual model without a reference card |
| `07 Head and collar` | Face, hair, neck opening and collar folds |
| `08 Camera B scale` | Uncropped 926 × 428 perspective render at the current game projection |

The first four comparisons share an orthographic scale of **3.3 m**, square pixels and 1800 × 1200 resolution. In the raw body sheet, sole row 805 and hair-top row 112 register to Z = 0 and Z = 1.82 m. The three-quarter crop uses its detail sheet's sole row 915 and hair-top row 84 at the same height. The reference cards are UV crops of the unchanged source PNGs; they are not retouched to resemble the model. The generated illustrations still contain perspective and construction interpretations, so these registrations support comparison rather than proving an exact blueprint match.

All previews here are actual Blender renders. They are neither new concept illustrations nor Simulator captures.

![Front comparison with a fixed height registration](front.png)

## Asset ownership

```text
miki-reference-blockout/
  miki-reference-blockout.blend          Linked review, reference cards and cameras
  character/
    miki-reference-character.blend      Independently editable A-pose character
    README.md                           Source conventions and limits
  front.png / left.png / back.png / right.png
  three-quarter.png / artist.png / head.png / camera-b.png
  README.md
```

The [character source](character/README.md) owns the body, hair, face, clothing, gloves, carrying strap and empty worn slate holster. It has no external dependencies, rifle, tablet, skeleton or animation. This review links its single collection and owns lighting, floor, labels, cameras and reference images. Edit body geometry in the character source, then reopen the review to reload the linked asset. No library override or duplicate appended body is needed.

The [earlier four equipment-fit poses](../miki-angular/README.md) and [independent equipment sources](../equipment/README.md) remain unchanged comparisons. Their fit results do not transfer to this new body. This study is unregistered and does not export into the app.

## Forms under review

- A compact adult head with broad face planes, restrained eyes and a swept bob extending farther on wearer-right and behind the head.
- A close neck opening, dark shoulder fold and high ivory collar on wearer-left, with its front overlap dropping towards wearer-right.
- A nipped coat core, continuous underlying sleeves and overlapping flared shoulder caps.
- A broad wearer-right front wrap ending near the knee, a distinct rear point extending towards the calf, and a short wearer-left counter-panel. The panels have thickness and depth around the hips instead of sharing one flat plane.
- Tapered legs and compact boots as provisional supports for judging the silhouette.
- A diagonal carrying strap and empty wearer-right holster, keeping the field slate and rifle independent of the character mesh.

Native front is **−Y**, up is **+Z**, and wearer-right is **−X**. In the front render, wearer-right appears on the viewer's left. The **1.82 m** study height is an authoring convention, not a change to the runtime character dimensions. Hidden rear joins, fold thickness, facial construction and motion clearance remain modeller interpretations to review.

![Wearer-right profile comparison](right.png)

Further matched views: [wearer-left profile](left.png), [back](back.png). Detail views: [artist view](artist.png), [head and collar](head.png).

## Verification and next gate

The new body contains **47 mesh parts, 1,818 triangles, 1,001 vertices and ten matte materials**. These are study counts, not a proposed runtime or draw-call budget. The pieces are closed solids that intentionally overlap at clothing/body joins; they are not connected deforming topology. The source contains no armature, skin weights, Actions, constraints, modifiers, textures or equipment meshes.

An independent read-only audit of the saved public files passes finite/nondegenerate geometry, consistent winding, positive volume, grounding, matte/flat materials, metre units, declared shoulder/sleeve and neck/body joins, relative dependencies and comparison-camera/reference registration. The public body byte-matches the audited candidate; all eight review scenes retain identical geometry, normals, material appearances, cameras, lighting and labels after path remapping. The five reference-card crops, UVs and height registrations also match. All **95 protected source/runtime, equipment, prior-study and reference files** remain unchanged. The existing **62 Blender/export tests pass**, as do documentation links, privacy, whitespace and Git LFS checks. The saved linked comparison was opened and visually inspected in connected Blender. These checks establish technical construction and preservation, not likeness or final appearance approval.

The next gate is a visual review of proportions, front/profile/back silhouette, hair volume, collar and coat construction against the approved sheets. Review should identify the large forms that still differ before adding small costume detail. A technical mesh check cannot establish resemblance or appeal. Fingers, equipment fit, skinning, scoped aiming, coat deformation and transitions remain later work. The earlier running, sneaking and shooting animations have not been fitted to this body.

The camera B scene uses target **(0, 0, 0.95)**, eye **(0, −44, 56.95)**, **22° vertical field of view**, and the route-facing instance turned 180° around Z. Its [uncropped render](camera-b.png) establishes projection and scale only. It does not establish phone readability, gameplay appearance or performance. Canonical models, shared animations, bridge exports and runtime behaviour remain unchanged. No app build, Simulator run, phone test, merge or release is included in this authoring study.

## Source and licence

- **Source:** Original native Blender geometry authored by Codex for Lauder, guided by the [approved generated reference sheets](../../../art/characters/angular-study/miki-reference/README.md). No third-party model, rig, texture or animation was imported. Reference-image provenance remains recorded with those sheets.
- **Licence:** Original geometry and documentation under the project's [MIT licence](../../../LICENSE).
- **Storage:** Both editable `.blend` files use Git LFS. Deliberate PNG previews over 1 MiB have explicit-path LFS rules; smaller previews remain ordinary Git. Render metadata is removed without changing compressed pixel data.
