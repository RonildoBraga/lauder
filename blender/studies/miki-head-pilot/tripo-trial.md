# Tripo P2.0 head trial

**24 November 2026 — exported after Pro access; native inspection completed.** Codex ran one free P2.0 generation after the maintainer signed into Tripo Studio, using the [prepared bald input](../../../art/characters/angular-study/miki-head-pilot/README.md). After the maintainer enabled Pro, the existing job was exported and imported into Blender. This is a bounded workflow test, not final appearance approval.

## Request and observed result

| Setting | Value |
| --- | --- |
| Input | `bald-three-quarter-v1.png` only |
| Input SHA-256 | `ec4d5cdd0f8aecb0b926e3e569bf89253eeb8a7f8a2940dfcc04a454979ac1c7` |
| Model | Smart Mesh P2.0 |
| Topology / target | Quad / 5,000 faces |
| Generation count | 1 |
| Texture | None; geometry only |
| Privacy | Public, the free-tier setting |
| Cost | Free generation; subsequent Pro access enabled export |
| Job | `222ae975-6406-4c57-9fff-1e148e2143de` |
| Viewer | [Tripo model](https://studio.tripo3d.ai/workspace/generate/222ae975-6406-4c57-9fff-1e148e2143de) |

The completed viewer reports **Quad, 5,401 faces and 4,899 vertices**. Blender confirms those totals, with **4,334 quads, 1,067 triangles and 9,735 triangulated faces**. The Quad label therefore does not mean an all-quad anatomical head. The source job was not regenerated when the first export failed.

## Visual observations

The actual 3D viewer was inspected from front, three-quarter and a freely rotated side/rear angle, with wireframe on and off and no generated texture. The skull has depth, the neck attaches to a real head volume, and large facial planes broadly reflect the input.

Prominent projecting eyebrow slabs, ball-like eye details and a blocky mouth/chin transition need correction before judging this as Miki. The input already has heavier brows and larger eyes than the approved art, so the trial does not isolate all identity drift to the generator. These observations are visual, not a native topology or deformation audit. The browser views do not use the [baseline's matched cameras](README.md) and do not complete the Blender comparison.

Screenshots of the result and upgrade screen remain private evidence because they include account UI and unrelated gallery assets. No screenshot enhancement was used.

## Export history and native intake

The first **Export → FBX → Blender** attempt opened a subscription gate and produced no file. After the maintainer signed up for Pro, the existing job exported as `miki-head-p2-trial-v1.fbx`. Its binary header, size and hash were verified, and an untouched intake copy imported in background Blender 5.3. No viewer-cache extraction or paywall bypass was used.

The signup screen was prepared with Monthly Pro selected; the maintainer completed checkout. No payment details or billing receipt are stored here. Pro export access does not change this job's free-generation origin. The [untouched source and native findings](tripo/README.md) record the 205,584-byte export and SHA-256, its seven disconnected parts, imported normals and localized defects.

## Provenance before a public model import

This was a free-tier output. The [main Tripo terms](https://www.tripo3d.ai/terms), dated **13 November 2026**, describe free output under section 5.2.1 as public with a waiver or broad irrevocable public licence, excluding original uploaded inputs. Section 5.2.2(b) says a later subscription does not retroactively make free output paid content. Later paid edits can create new paid content while the original retains its status. The terms restrict competing AI uses. Section 3.2 separately restricts tampering with AI-origin identifiers; section 3.3(f) removes additional attribution/copyright/link-retention requirements for free outputs while retaining legally required identifiers. The exported Creator fields and source identifiers are preserved.

Official summaries conflict: the [pricing document](https://www.tripo3d.ai/product-doc/getting-started/pricing-credits) describes free commercial use with attribution, while the [commercial-use help](https://www.tripo3d.ai/help/privacy-policy/how-to-use-tripo-models-commercially) says free commercial rights are not granted and refers to the main terms. Preserve these dated distinctions and any trial-specific conditions before publishing an exported asset. Do not automatically mark the raw mesh MIT or claim exclusive ownership. The unchanged FBX is retained under its explicit [Tripo free-output provenance](tripo/README.md), separately from the repository's general MIT notice.

## Next modelling pass

The native head volume is more specific to Miki's graphic reference than the stock CC0 shapes, while the CC0 source supplies cleaner anatomical starting topology. Use the Tripo silhouette as the leading volume candidate and keep the CC0 source as a construction reference. Before hair or fitting, simplify the eye parts, replace the raised brow slabs with restrained forms, repair the one-sided skull/neck seam and localized eye/mouth defects, and review the expression. The maintainer subsequently assigned that bounded [cleanup pass](../miki-head-cleanup/README.md). Its derivative and matched renders are separate; this trial preserves the original export and comparison.

No final head is selected. Hair, body fitting, rigging, animation, runtime budgets, Laura/Tom, app integration, merge and release remain outside this trial. The live Blender file is unchanged.
