# Reference-led Miki character source

**Source:** Original Lauder geometry authored by Codex from the [approved Miki modelling basis](../../../../art/characters/angular-study/miki-reference/README.md). No third-party mesh, rig or animation was imported. **Licence:** Project [MIT licence](../../../../LICENSE).

Open `miki-reference-character.blend` for the independently editable **`miki-reference-character`** collection in a neutral A-pose. Native front is −Y, up is +Z, wearer-right is −X, units are metres and soles are at Z = 0. The study's hair-top landmark is at 1.82 m.

The file owns the body, hair, face, clothing, gloves, carrying strap and empty worn slate holster. Its **43 mesh parts / 2,576 triangles / 1,392 vertices / ten matte materials** are closed, flat-shaded solids with intentional overlap at body/clothing joins. They are not a connected or rig-ready character surface. Landmark empties aid comparison; they are not joints or an attachment system.

There is no external library, image, rifle, tablet, armature, skinning, Action, constraint or modifier in the source, including hidden or unused equipment. The [review composition](../README.md) links this collection and owns the reference cards, cameras, neutral lighting and floor. Save body changes here, then reopen the review to reload linked geometry.

The maintainer found the previous face and hair distorted ([issue #141](https://github.com/RonildoBraga/lauder/issues/141)) and chose to rebuild the head, hair and neck, **“Head, hair and neck”**. The head is now one closed solid:
- a full skull to 1.808 m and 19 cm deep;
- a face that tapers to the jaw;
- the nose and mouth worked into its planes, so there is no separate nose part;
- larger dark almond eyes, lash lines and angled brows;
- a neck about 10 cm across.

The hair is a thin bob that follows the skull, with a broad fringe, locks swept outward and back, a wearer-left curtain and nape points. The chin landmark is at 1.607 m. These original Blender choices use the approved references as guidance where a 2D drawing does not settle construction. The result awaits the maintainer's visual review. Visual correction and acceptance precede skeleton or animation fitting. Hidden joins and movement clearance remain interpretations. The [earlier independent character](../../miki-angular/character/README.md), four equipment-fit poses, equipment sources, canonical characters, shared motions and app exports remain separate and unchanged. This file is an unregistered study and does not trigger runtime export.
