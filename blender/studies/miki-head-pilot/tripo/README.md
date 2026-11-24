# Tripo head source

This is the **untouched FBX export** of the [head-only P2.0 trial](../tripo-trial.md), generated from the project's [bald Miki hero](../../../../art/characters/angular-study/miki-head-pilot/README.md) on 24 November 2026. The generation used a free P2.0 trial; subsequent Pro access enabled export. It is an unaccepted modelling candidate, not a game resource or a rig-ready character.

## Source and provenance

- Provider: Tripo, Smart Mesh P2.0.
- Job: `222ae975-6406-4c57-9fff-1e148e2143de`; [source viewer](https://studio.tripo3d.ai/workspace/generate/222ae975-6406-4c57-9fff-1e148e2143de).
- Input: the single bald three-quarter hero; no failed Blender model or third-party game asset was uploaded.
- Export: FBX, Blender preset, geometry only.
- File: `miki-head-p2-trial-v1.fbx`, binary FBX 7400, **205,584 bytes**.
- SHA-256: `42b633426b1e30f3905e1ed3dc53fc7de0e085b015518c1154569b2494a09d55`.
- Both embedded Creator fields remain `Tripo`; the generated `tripo_` model/geometry/material identifiers and FileId remain byte-for-byte unchanged. The file has no external image or local filesystem reference.

## File-level licence

This third-party source uses the **Tripo Free Output grant** in section 5.2.1 of the [main terms dated 13 November 2026](https://www.tripo3d.ai/terms), rather than the repository's general MIT notice. That provision describes a copyright waiver or broad permanent public licence permitting copying, modification, distribution and commercial use. Original uploaded inputs are excluded from that output grant; third-party rights are not supplied by it.

Section 5.2.2(b) preserves the original free-output status after a subscription. This is **free generation, subsequent Pro export**, not a paid/private generation or a claim of exclusive ownership. Section 3.2 restricts tampering with AI-origin identifiers; the raw file and its source identifiers are preserved. Section 3.3(f) removes an additional attribution/copyright/link-retention requirement for free output. The [trial record](../tripo-trial.md) retains the conflict with older pricing/help summaries and distinguishes the head from the CC0 baseline and original MIT review setup.

## Native intake

Blender 5.3 imports one mesh object with seven disconnected parts: head/ears/neck, two eye-white shells, two iris/pupil parts and two brows. It has **4,899 vertices**, **4,334 quads + 1,067 triangles**, and **9,735 triangles after triangulation**. All polygons are smooth-shaded with imported custom corner normals. There are no UV maps, images, rig, Actions or external dependencies.

The 49 boundary edges include an ordinary open neck cutoff as well as localized head/eye/mouth openings; two iris edges are nonmanifold. A one-sided seam below an ear, a pinched eye opening, an iris seam and a mouth-winding issue require inspection and repair. Eye parts consume 88.41% of vertices; the head/ears/neck shell has only 538 vertices and 681 faces. These are starting geometry and cleanup findings, not approval for animation or runtime use. The raw export remains unchanged so any later repair can be compared honestly.
