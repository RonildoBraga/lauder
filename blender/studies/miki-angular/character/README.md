# Miki angular character source

**Retained comparison:** The maintainer approved new [Miki-only modelling references](../../../../art/characters/angular-study/miki-reference/README.md) and assigned a separate [unrigged A-pose rebuild](../../miki-reference-blockout/README.md). This source's four static poses remain unchanged; their equipment-fit checks do not transfer to the new mesh.

**Source:** Original Lauder geometry authored by Codex, guided by the [selected angular concept](../../../../art/characters/angular-study/README.md) and extracted from the static Miki study at `7d0e79b`. No third-party mesh, rig or animation was imported. **Licence:** Project [MIT licence](../../../../LICENSE).

Open `miki-angular-character.blend` to edit Miki's body, hair, face, clothing, gloves and worn holster/sling mounts. **No rifle or tablet geometry is stored in this file**, including hidden or unused mesh data. It has no external library dependencies. The default scene shows the directly editable stowed-character pose, with both equipment items absent.

| Scene | Character collection |
|---|---|
| `01 Stowed character` | `Miki character / stowed` |
| `02 Inspection character` | `Miki character / inspection` |
| `03 Lowered carry character` | `Miki character / lowered-carry` |
| `04 Low-ready character` | `Miki character / weapon-ready` |

Each static pose has **37 mesh parts, 998 triangles, 573 vertices and nine matte materials**. Shared body/clothing parts reuse mesh data within this file; arms have separate pose geometry. Editing shared geometry affects those poses, but placement, contact and clothing clearance must still be rechecked. Character-side contact markers follow their glove or coat parents. The holster's interior reference belongs to the worn mount.

The file uses metres, has soles at Z = 0 and contains no skeleton, skin weights, Actions, modifiers or runtime export. It remains a rough appearance/fit study. The current canonical characters and shared animation library remain separate and unchanged; fitting a skeleton to these proportions is later work.

The [review composition](../README.md) links the four character collections, the independent [equipment assets](../../equipment/README.md) and their review context. Save body/clothing changes here, then reopen the review composition to reload linked data. Save rifle/device geometry in its own source. Carry and hold placement belongs to the review composition. No library overrides or duplicate appended equipment are needed for this static setup.
