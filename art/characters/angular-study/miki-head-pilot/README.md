# Miki head-only pipeline trial

**Status: trial inputs prepared; no final appearance accepted.** On 24 November 2026 the maintainer said “lets proceed with your recommendation” after Codex recommended a bounded head-only comparison: a specialist image-to-3D result against Blender's CC0 head foundation, inspecting real geometry before hair, rigging or runtime integration. This is smaller than the broader research proposal in [issue #142](https://github.com/RonildoBraga/lauder/issues/142). The rejected hand-built attempts are recorded in [#141](https://github.com/RonildoBraga/lauder/issues/141).

## Inputs

![Bald Miki three-quarter pilot input](bald-three-quarter-v1.png)

- **Primary input:** `bald-three-quarter-v1.png`, derived from the [approved Miki references](../miki-reference/README.md). Use this single image for the first Tripo P2.0 attempt.
- **Supporting interpretation:** [front](bald-front-v1.png) and [profile](bald-profile-v1.png), generated from that hero. They help judge proportions, but are not registered or verified multiview geometry. Do not feed them together as if they were exact orthographic views.
- **Identity authority:** the original detail sheet's HEAD FRONT panel. The originals remain unchanged.

The bald design separates the skull/face from the swept hair. It preserves an adult angular face, high cheek planes, a compact blunt chin and restrained features. Independent review found useful continuity across these images but remaining drift: the eyes read larger and the brows heavier/sterner than the approved front; the profile eye reads too frontally, with a more projecting nose/chin and rounder back of skull. These limits belong in the comparison, not hidden by relabelling this as approved art.

## Comparison and next gate

The [native Blender baseline](../../../../blender/studies/miki-head-pilot/README.md) preserves actual CC0 foundation geometry, editable shape keys and matched clay views. It is a starting topology, not Miki's finished face. Judge the actual exported Tripo mesh against it using the same front/profile/three-quarter framing and neutral clay, then simple facial materials. Check adult identity, full skull depth, coherent eye placement, integrated nose/mouth/chin and volume that survives rotation.

After the maintainer signed in, one free Tripo P2.0 head was generated from the single hero. Its first FBX export was subscription-gated; subsequent Pro access enabled export of the existing job without regeneration. The [trial record](../../../../blender/studies/miki-head-pilot/tripo-trial.md) and [actual native comparison](../../../../blender/studies/miki-head-pilot/README.md#native-generator-comparison) now record the source, matched views, mesh defects and original cleanup recommendation. The subsequently assigned [native cleanup](../../../../blender/studies/miki-head-cleanup/README.md) is a separate derivative for appearance review. The complete comparison remains distinct from final appearance acceptance, hair, rigging or runtime integration.

Keep the winning head only after visual acceptance; add separate hair next. Body/clothing, skeleton fitting, animation tests, runtime budget, Laura/Tom and app integration follow separately. The maintainer's subsequent Pro signup enabled the recorded export; no new runtime polygon budget, merge or release is approved by this trial.

## Generation and provenance

- **Source:** original AI-generated illustrations using the built-in image-generation tool, guided by the approved Lauder references. No failed Blender render or third-party character mesh was used as an image input.
- **Process:** one bald hero, then front/profile interpretations derived independently from that hero. All three PNGs were copied unchanged from the tool output; the [exact prompt set](prompts.md) records input roles.
- **Licence:** These generated illustrations use the project's [MIT licence](../../../../LICENSE), without claiming exclusive rights in generated output or rights over reference works. The separate Tripo export retains its own [free-output provenance and grant](../../../../blender/studies/miki-head-pilot/tripo/README.md); it is not automatically licensed MIT.
- **Storage:** all three 1536 × 1024 opaque PNGs exceed 1 MiB and use explicit-path Git LFS.

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| `bald-three-quarter-v1.png` | 1,543,902 | `ec4d5cdd0f8aecb0b926e3e569bf89253eeb8a7f8a2940dfcc04a454979ac1c7` |
| `bald-front-v1.png` | 1,526,632 | `dbd6c89ec56bd11638d4008aac3461d3a2afabc7c139a5a199ea4e973bbe3f00` |
| `bald-profile-v1.png` | 1,556,866 | `22059d926b600b5a4798f218e70faf1bc855737a20e65eb3111911fe80387d06` |
