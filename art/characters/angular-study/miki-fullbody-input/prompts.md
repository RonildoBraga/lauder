# Full-body reconstruction input prompts

Codex used the built-in image-generation tool on 25 November 2026. The original approved sheets remain unchanged. These are generated derivatives, not literal crops or newly approved designs.

## 1. Single-figure input

Reference/edit target: [approved head and construction sheet](../miki-reference/head-and-construction-v1.png).

Output: `miki-three-quarter-v1.png`.

```text
Use case: identity-preserve. Edit target: the attached approved Miki construction reference sheet. Produce a SINGLE clean full-body reference image for image-to-3D reconstruction. Isolate the LEFTMOST full-body FRONT THREE-QUARTER figure, including complete hair, both hands, both feet and all coat tails. Preserve that exact figure's proportions, pose, attentive adult female face, swept graphite hair, teal angular layered coat, folded ivory collar, charcoal clothing, brown diagonal strap and OPEN EMPTY slate holster, small boots. Do not redesign, beautify, change pose, add anatomy details or change garment construction. Remove every other figure, close-up, label and all text. Centre the single isolated figure large in a portrait canvas with a little margin all around, on a plain uniform light grey background, minimal ground shadow. Empty hands, no rifle, no weapon, no tablet, no extra satchel, no additional views. It must be a faithful standalone version of the exact left figure, with no perspective exaggeration and no loss of the angular graphic low-poly aesthetic.
```

## 2. Maintainer's bag correction

Reference/edit target: [single-figure input](miki-three-quarter-v1.png).

Output: `miki-three-quarter-v2.png`, the selected input for the full-body generator trial. The maintainer asked to make the side item read as a bag; the resulting illustration itself still needs appearance review.

```text
Use case: precise-object-edit. Edit target: the attached SINGLE full-body angular Miki reference. Change ONLY the brown cage/open-frame item at her near/right hip into a believable compact brown FIELD SATCHEL. The user says it does not look like a bag. Replace the hollow ladder/cage with a solid closed fabric/leather satchel body: softly bevelled angular rectangular volume, clearly visible side gusset and bottom thickness, a simple folded overlapping flap with a small restrained closure, subtle seam defining the opening underneath. Same muted brown palette and existing diagonal shoulder strap, visibly connected to the satchel. Compact hip-width bag, not an oversized box, no hollow window or exposed bars, no decorative hardware clutter. A plausible place to stow her independent field tablet, but do not add a tablet or weapon. Preserve EXACTLY all other things: adult woman's face, expression, swept dark hair, ivory folded collar, teal layered angular coat and tails, body proportions, empty hands, boots, three-quarter A-pose, full-body framing, background, shading and graphic low-poly style. This is a targeted bag repair, not a character redesign. Single figure only, no text.
```

Both calls used `transparent_background=false`; selected tool outputs were copied unchanged. No manual bitmap painting or failed Blender render was used.
