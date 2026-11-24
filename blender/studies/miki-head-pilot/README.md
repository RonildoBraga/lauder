# Miki head-only pipeline trial: CC0 foundations

**Status:** A native anatomy baseline for the assigned head-only comparison, not a finished or accepted Miki likeness. The [pilot art and input record](../../../art/characters/angular-study/miki-head-pilot/README.md) defines the single image-to-3D input and the limits of its supporting illustrations. One free Tripo P2.0 head has now been generated and inspected in its 3D viewer. The [trial record](tripo-trial.md) records the subscription-gated FBX export; no generator mesh has been downloaded or imported into Blender. This baseline therefore does not complete the matched comparison.

## Open and inspect

Open [head-foundations.blend](head-foundations.blend) in Blender 5.3 or later. It is self-contained and unregistered: it does not export to the game. Five scenes each contain one editable head, neutral clay, three orthographic cameras and identical lighting:

| Scene | Source shape | Review geometry |
| --- | --- | --- |
| `01-generic-basis` | Generic Basis | 2,528 triangles |
| `02-generic-real-female` | `Real_FEMALE = 1` | 2,528 triangles |
| `03-generic-toon-female` | `Toon_FEMALE = 1` | 2,528 triangles |
| `04-generic-mix` | `Real_FEMALE = 0.6`, `Toon_FEMALE = 0.4` | 2,528 triangles |
| `05-planar-default` | Planar source Multires level 5 | 647,168 triangles |

Choose a scene in Blender's scene selector. The front camera is selected by default; use Camera View to inspect it. The other two cameras in that scene provide a right-facing profile and three-quarter view by orbiting the camera, without mirroring geometry. All views share orthographic scale and framing; no view is rescaled to conceal a shape change. Freely orbit the head as well.

![Actual Blender clay renders of the five source-head variants](head-foundations.png)

These are actual untextured Blender renders, with labels assembled from those renders. No image generation, painted anatomy or screenshot enhancement was used for this sheet. The first four use the source's flat polygon normals with one subdivision level; Planar preserves its smooth sculpted multires finish. That difference is labelled, so it is not a like-for-like topology comparison.

## What is preserved and changed

Each Generic copy retains the source's **318 vertices, 316 quads (632 base triangles), UV map and all ten editable shape keys**. The key coordinates and polygon connectivity are unchanged. Display subdivision is one level for all four (the source's render default is two). The source object's **Show Only Shape Key** setting was enabled on Basis; it is disabled here so the requested mixtures actually evaluate. The head objects have gallery translations, a neutral material and source credits, with no coordinate sculpting, painted facial features, separate eyeballs, hair, neck, skeleton, Actions or animation.

Planar has the same small base cage but stores its visible anatomical planes in internal multires displacement. Its 632-triangle cage alone does not reproduce the pictured form. It is a secondary anatomy reference rather than a proposed runtime model.

The **Generic** head is the more practical editable foundation. Its sockets, cheek transitions, integrated nose/mouth and full skull provide topology to work from. Its stock female/cartoon shapes are not Miki's facial identity. Neither the source defaults nor this gallery settle the final skull, jaw, eyes, budget or style.

## Source and licence

Derived from **Head - Generic Topology** and **Head - Planar**, by **Paul Kotelevets**, in **Blender Human Base Meshes v1.4.1**, Blender Studio and community contributions.

- [Official listing](https://www.blender.org/download/demo-files/#assets).
- [Exact source archive](https://mirror.blender.org/demo/asset-bundles/human-base-meshes/human-base-meshes-bundle-v1.4.1.zip).
- Both selected objects carry explicit **CC0** asset metadata; the bundle README declares all supplied assets public domain under CC0.
- The bundle also has a text named `License` referring to **Rain Rig / CC BY 4.0**. This discrepancy is retained in the provenance record; the selected heads' explicit CC0 metadata and package README are the basis for this intake. The unrelated text, rig and other assets are not appended.
- ZIP SHA-256: `811f43accbb31a88266d932f8f5563b2d13586fca0ba2693aad1f5fe582b3515`.
- Source `.blend` SHA-256: `3c121505651140ceb4d69fd1d8923f7788ffadd81672f5be14845a5f2c75c137`.
- These are locally computed intake fingerprints, not publisher-signed authenticity proofs.
- Gallery presentation and documentation contributions use the project's [MIT licence](../../../LICENSE); the source heads remain CC0. No Tripo output is included or licensed by this file.

Only the two head object assets were appended. No software, extension or asset-library preference was installed or registered. The official full archive remains local intake material rather than a duplicate committed asset bundle. The editable study uses Git LFS, as does the deliberate preview above 1 MiB.

## Verification and remaining gate

Native Blender 5.3 inspection confirms unchanged source vertex/key data and polygon connectivity, independent editable key data, closed manifold base meshes with positive volume, no zero-area faces, no external libraries or images, no armatures or Actions. The saved file reopens; rerendered front views match their PNG pixels. Privacy inspection of the decompressed native file finds no local user path.

The initial gallery exposed the source's Basis-only display setting: key values alone did not establish the displayed shape. After disabling that setting, all four Generic variants have different evaluated-coordinate and front-render pixel hashes. Versus Basis, maximum evaluated vertex deltas are approximately **15.30 mm** (Real), **24.10 mm** (Toon) and **15.31 mm** (mix); direct cage evaluation agrees with the source-key mixtures within **8.34 nm**. These checks establish that the controls affect real volume; they do not establish attractiveness or Miki likeness.

The existing **62 Blender/export tests pass**. Canonical assets, shared animations, bridge, app, prior studies and approved reference images remain unchanged. No app build, Simulator run, physical-device test, performance claim, merge or release is part of this authoring-only trial. The live Blender file was left untouched.

The single free P2.0 attempt used the hero, geometry only, quad topology and a requested 5,000-face target. These are trial settings, not an adopted runtime budget or a guarantee of anatomical edge loops. Its [actual job and export gate](tripo-trial.md) are recorded separately. A paid subscription needs a maintainer decision before downloading; there is no native Tripo import or matched Blender comparison yet. Choose a head route on volume and identity before separate hair, body fitting, shared-skeleton/animation verification or an explicitly agreed runtime budget.
