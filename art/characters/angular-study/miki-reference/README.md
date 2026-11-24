# Miki modelling references

**Status:** Approved modelling-reference basis, generated on 24 November 2026. After finding the earlier mesh unlike the selected concept, the maintainer approved this pair and assigned a fresh unrigged head, torso, shoulder and coat blockout, reviewed at matched projections before detail, rig or motion. This approves the reference basis, not a final mesh. The [original trio](../party-angular-v1.png) and its [prompt](../prompts.md) remain unchanged.

## Body turnaround

![Miki front, left profile, back and right profile in a relaxed A-pose](body-turnaround-v1.png)

Four full-body views align the head, anatomical landmarks and soles in the same relaxed A-pose. Front/back establish the silhouette; both profiles clarify depth and the asymmetric costume. The rifle and tablet are omitted because they are independent assets. The worn holster and strap remain part of her clothing/carrying arrangement.

## Head and construction

![Miki front and rear three-quarter views with front and right-profile head and collar close-ups](head-and-construction-v1.png)

The three-quarter views show shoulder, collar and coat depth. The head studies guide swept hair, cheek/chin/nose planes, attentive eyes and the folded collar wrapping the neck. These show the same approved reference design, not alternate faces or costumes.

## Construction interpretation to review

The approved sheets guide visible proportions and costume arrangement. This reading clarifies their construction, rather than establishing a measured 3D specification. Hidden surfaces and unseen joins still require modeller judgement and review:

- The ivory collar rises on **wearer-left** and overlaps diagonally towards **wearer-right**. It folds around the neck rather than floating as a flat slab.
- Longer pointed hair sweeps towards **wearer-right/back**.
- The broad right-side front wrap ends around the **knee**, while a distinct secondary right-rear tail reaches the **calf**. Both lengths must survive the side views.
- The empty brown slate holster stays on **wearer-right**; the strap runs from **wearer-left shoulder to wearer-right hip**. The holster has an open channel, cradle and retainer, with no closed satchel flap or inserted device.
- Shoulders, upper sleeves, forearms and cuffs form connected overlapping layers. Keep the waist narrow, legs tapered with readable knees, and boots compact.

Front views show wearer-right on viewer-left; back views show it on viewer-right. The left profile faces left on the page and the right profile faces right. Preserve anatomical sides when rotating the model rather than mirroring the drawings.

## Review and modelling gate

Visual consistency review checked identity, approximate landmark alignment, anatomical sides, holster construction and knee/calf hem lengths. The first body output shortened the profile tails and introduced a flap pouch; an image-tool edit repaired them. The first detail output labelled near-front/back figures as three-quarter views; an image-tool edit supplied actual rotated views. The final pair has no observed material construction contradiction, but remains an illustrated guide, **not a measured geometric blueprint**. Hidden rear/under-collar joins, panel thickness and motion clearances still require modelling decisions.

The maintainer approved these sheets as the modelling basis and assigned the separate [unrigged A-pose blockout](../../../../blender/studies/miki-reference-blockout/README.md) for the head, torso, shoulders and coat, with no weapon or tablet. Its actual mesh awaits matched front, side, back and three-quarter visual review before detail, rig or motion. The [earlier independent character source](../../../../blender/studies/miki-angular/character/README.md) and its four equipment-fit poses remain unchanged comparisons; their previous geometry and source-separation checks establish technical properties, not likeness or fresh verification of a new blockout. Hidden joins and motion clearance remain unresolved. Equipment, canonical/runtime models, shared motion and gameplay remain outside the assigned body blockout.

## Generation and provenance

- **Source:** Original AI-generated reference illustrations produced by Codex using the built-in image-generation tool, guided by the selected original Lauder trio sheet. No failed Blender render, third-party mesh or new external character artwork was used as a reference. The [original sheet's provenance](../README.md#generation-and-provenance) remains applicable to that input.
- **Process:** Body generation, targeted consistency repair, detail generation and targeted angle repair. The [complete prompt set](prompts.md) records all four requests and input roles. Only the two selected final outputs are project references. They were copied unchanged, with no resizing, painting or manual bitmap editing; generated provenance metadata is retained.
- **Licence:** Generated contributions under the project's [MIT licence](../../../../LICENSE), without claiming exclusive rights in AI output or rights over the original style-reference works.
- **Storage:** Both opaque RGB PNGs exceed 1 MiB and have explicit-path Git LFS rules. No application resource consumes them.

| File | Dimensions | Bytes | SHA-256 |
|---|---|---|---|
| `body-turnaround-v1.png` | 1774 × 887 | 1,587,974 | `c5505a6079c4d0c1ee8dacf2c6fd6eaa8de5bd1b1b4cece9b2d379a1a5a1b3a4` |
| `head-and-construction-v1.png` | 1536 × 1024 | 1,611,493 | `bb695b98212db55db2d741040f763dde56a6fb29515a5734c211c9d38a0a71fa` |
