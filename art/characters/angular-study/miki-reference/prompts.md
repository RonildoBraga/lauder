# Miki modelling-reference prompts

Generated with the built-in image-generation tool on 24 November 2026, using opaque backgrounds. The input is the [selected original trio sheet](../party-angular-v1.png), with only Miki used. The failed Blender mesh was not an input. The two final images are copied unchanged; no resizing, painting or manual bitmap editing was performed.

The complete generation/edit requests follow. Intermediate outputs were reviewed and repaired, rather than being adopted as separate character designs. They are not project references. Final outputs: `body-turnaround-v1.png` (body generation followed by repair) and `head-and-construction-v1.png` (detail generation followed by angle repair). Reference-image arguments are described with repository-relative inputs or preceding generation steps; no local machine paths are recorded.

## Body generation

Input image 1: `../party-angular-v1.png`.

```text
Use case: stylized-concept.
Asset type: MIKI-only orthographic character turnaround for 3D modelling, candidate reference sheet for Lauder.
Input image 1: the SELECTED original art-direction sheet. Use ONLY MIKI, the teal woman on the LEFT, as identity, proportion, clothing and visual-style reference. Laura and Tom must not appear. This is a continuation of that exact graphic design, not a new character or realistic reinterpretation. Do not use the failed Blender mesh as a reference.

Create ONE clean wide landscape sheet containing FOUR equally large full-body views of the SAME Miki, ordered: FRONT, LEFT PROFILE, BACK, RIGHT PROFILE. These are orthographic rotations of ONE character, not four different costume or face designs. Align soles on one subtle ground line and align head top, chin, shoulders, waist, hips, knees and ankles horizontally. All feet and hair visible with space around each figure. Left profile (viewing her anatomical left side) faces LEFT on the page; right profile faces RIGHT. Plain uniform muted warm grey-green background. Faint horizontal construction guides are allowed, no environment or dramatic ground shadows.

Pose: neutral relaxed A-pose in all four views, upright head, level gaze, weight evenly distributed, feet comfortably hip-width, arms straight but relaxed about 25–30 degrees away from torso so coat/sleeve construction is visible. Identical pose and anatomy through rotation. Empty gloved hands. Do not use the expressive contrapposto as modelling pose.

Preserve Miki's original angular adult caricature: small sharply simplified HUMAN head, swept asymmetric dark bob with distinct pointed ends and visible face, clean cheek/chin/nose/brow planes and alert tiny dark eyes; fitted warm teal wrap-parka with narrow waist; broad off-centre ivory FOLDED collar that wraps and attaches around the neck; overlapping angular shoulder/sleeve construction; offset layered coat panels, unequal hem lengths and clear zig-zag silhouette; long tapered dark trousers with readable knees/calves; compact tapering flat-soled winter boots. Roughly six to six-and-a-half heads tall, preserve the selected image's head/body feel and human adult massing; no extremely spindly rods, heavy cuboid shoes, broad blank face, hair helmet or detached box-tube arms. Facial features remain small and graphic, not giant white eyes.

LOCKED ANATOMICAL ASYMMETRY FOR ALL VIEWS (do not mirror costume):
- Ivory collar is HIGHER on Miki's anatomical LEFT, dropping diagonally to a pointed overlap toward her anatomical RIGHT.
- The broad long front coat panel and longer rear swept points favour her anatomical RIGHT; shorter counter-panel is on her LEFT.
- Hair's longer swept pointed ends favour her anatomical RIGHT/back.
- One compact brown WORN SLATE HOLSTER on her anatomical RIGHT hip. Strap travels from LEFT shoulder to RIGHT hip, following the coat. This is the current authorised equipment-carry adaptation: keep it compact, not a new large messenger bag or satchel.
Thus front view shows the right-hip holster on VIEWER LEFT; back view shows it on VIEWER RIGHT. It is clearly visible in RIGHT PROFILE and mostly hidden in LEFT PROFILE.
Keep back construction simple and plausible, repeating the same panels and strap; no invented ornament, backpack or armour.

Style: match reference's polished 2D angular graphic / cut-paper polygon illustration. Crisp unoutlined edges, broad FLAT solid colour planes, one or two deliberate shadow planes per mass, restrained warm teal/ivory/charcoal/brown/skin palette. It should translate into intentionally modelled low-poly solids. Not photorealism, smooth rendered plastic, a toy, Lego, anime or a highly detailed science-fiction painting. No gradients, textures, tiny bevels, dense facets, outlines, surface greebles or seam clutter. Keep cloth folds as meaningful overlapping planes, not flat detached slabs.

The rifle and tablet are independent assets: OMIT both completely, including back gun, barrel, held slate or inserted device. Retain only the worn holster and existing strap; no new accessories. No medical/cybernetic machinery. Fully clothed for a frozen futuristic survival world.
Text only: a modest title "MIKI — MODELLING TURNAROUND" and four view labels "FRONT", "LEFT PROFILE", "BACK", "RIGHT PROFILE". No other text, diagrams, logos or watermark.
This is a proposed coherent construction interpretation of the selected character; prioritise SAME DESIGN and model-usable alignment over decorative presentation.
```

## Body consistency repair

Input image 1: the preceding body-generation output. Its side hems and worn holster were inconsistent. Output is `body-turnaround-v1.png`.

```text
Edit the supplied Miki turnaround sheet with two precise construction-consistency repairs. KEEP the same four-view layout, identical character identity, head/face/hair, shoulder and body proportions, relaxed A-pose, boots, colour palette, lighting, title, view labels and alignment guides. Preserve the successful FRONT and BACK character silhouettes except for the small brown holster repair below. This remains the same flat unoutlined angular graphic character illustration, not a 3D render.

Repair 1 — side-view coat depth and length:
The FRONT and BACK establish a long anatomical-RIGHT rear coat point reaching MID-CALF, below the knee. Both profiles currently truncate it near the knee. Preserve front/back and make LEFT PROFILE and RIGHT PROFILE true projections of that same coat:
- Add/show the same long rear right-side tail down to the horizontal height of the longest rear point in FRONT/BACK (roughly 675 on this 887-high image), clearly below the knee.
- RIGHT PROFILE faces right: the rear is PAGE LEFT, so its long trailing rear point must project behind the leg toward PAGE LEFT and reach that mid-calf line.
- LEFT PROFILE faces left: rear is PAGE RIGHT, and the far-side long right-rear tail should still be visible projecting behind the calf toward PAGE RIGHT to the same line.
- Keep the broader FRONT wrap panel distinct from that narrow longer rear tail; it ends nearer the knee/upper calf, consistent with the front view. Do not swap front and rear hems or shorten the back-view tail to make the problem disappear.
Do not move any anatomical landmark or alter limbs/pose to hide the discrepancy.

Repair 2 — worn equipment mount, all applicable views:
The brown item on anatomical RIGHT hip must be an EMPTY COMPACT SLATE HOLSTER, not a closed messenger pouch/satchel with envelope flap. Retain its current size, side and strap path. Show a simple brown back plate and side strips, an open central vertical channel with teal coat visible through it, a shallow bottom cradle, and a short broad top retaining loop/strap. Omit the large diagonal closed flap. No tablet/device inside. Front shows holder on viewer LEFT; back on viewer RIGHT; it is visible on RIGHT PROFILE and mostly hidden on LEFT PROFILE. No second bag or accessory.

All other geometry/design choices must remain unchanged. Keep broad clean solid planes and crisp edges; no new tiny hardware, texture, annotation or decorative detail. Return the repaired four-view sheet.
```

## Detail generation

Inputs: image 1 `../party-angular-v1.png`; image 2 `body-turnaround-v1.png`.

```text
Use case: stylized-concept.
Asset type: MIKI-only modelling detail/construction sheet, companion to an existing four-view turnaround.
Input image 1: original SELECTED trio art. Only MIKI, the teal woman on the left, supplies the original identity and angular graphic language; omit Laura and Tom.
Input image 2: corrected MIKI TURNAROUND. This is the controlling body/costume/side reference. Continue this EXACT candidate design, proportions, face, haircut, garment inventory and anatomical asymmetries. No redesign and no borrowing from the failed Blender mesh.

Create one polished wide landscape sheet with a plain muted warm grey-green background in the SAME flat unoutlined geometric low-poly/cut-paper illustration style.
Layout: two equally large full-body figures occupy the left two-thirds, labelled "FRONT 3/4" and "REAR 3/4". On the right third, two large clear head-and-collar close-ups stacked vertically, labelled "HEAD FRONT" and "HEAD RIGHT PROFILE". Small modest overall title: "MIKI — CONSTRUCTION DETAILS". All feet, hair tips and collar edges remain inside the canvas. Plenty of separation; no decorative borders, equipment thumbnails, numerical dimensions or extra text.

The full-body figures show ONE Miki rotated to front-three-quarter and rear-three-quarter, with identical relaxed neutral A-pose as image 2, level head, weight evenly on both feet, arms about 25–30 degrees clear of torso. No heroic lean, walking, gesture, weapon or hand prop. Same full-body scale/ground line. Choose the front-three-quarter angle from her anatomical RIGHT side so the right-hip holster and diagonal wrap are visible; rear-three-quarter also makes the long right-side hem readable. The two drawings must explain depth of the same forms, not invent alternative coat panels.

Match the established small adult human head, swept pointed asymmetrical dark bob, faceted cheek/chin/nose/brow, attentive small dark eyes, narrow waist, attached layered shoulders/sleeves, long tapered dark legs and compact winter boots. Keep broad meaningful flat colour planes, one or two hard shadow regions per form, sharp polygonal silhouettes. Teal wrap coat, ivory collar, charcoal hair/trousers/gloves, brown strap/holster and natural skin. No smooth 3D rendering, plastic, texture, gradient, outline, glossy eyes, tiny facets or ornamental sci-fi greebles.

HEAD / COLLAR CLOSE-UPS: derive the SAME head from image 2. Show clear front and true anatomical-right profile facial planes, angular nose and jaw, visible ear where appropriate, restrained eyebrows and alert eyes, pointed hair ends and coherent hair volume. Include neck, folded ivory collar and upper shoulder attachment, so the drawings explain how the collar WRAPS around the neck and overlaps the coat. It must be a folded volume with an inside/underside, not a detached plank or new scarf style. No alternate expressions, head sizes, hairstyles or extra face accessories.

LOCKED CONSTRUCTION IN EVERY PANEL:
- Collar high on anatomical LEFT; pale front overlap drops toward anatomical RIGHT.
- Hair has longer swept points toward anatomical RIGHT/back.
- Broad front wrap panel ends around the KNEE; a distinct secondary right-rear tail extends to MID-CALF. Preserve BOTH panel lengths and side projections from image 2, rather than merging into a single flat skirt triangle.
- Brown EMPTY compact SLATE HOLSTER on anatomical RIGHT hip, with brown back/side strips, OPEN central vertical channel showing teal beneath, bottom cradle and short top retainer. It is not a closed flap satchel and contains no tablet.
- Existing strap from LEFT shoulder to RIGHT hip, follows the coat; no second bag, backpack, weapon, back barrel, tablet or new accessories.
- Shoulder cap, upper sleeve, forearm and glove/cuff are a coherent connected layered construction with no visible joint gaps.
- Fully clothed for the frozen futuristic survival setting; no exposed machinery or fantasy armour.

This is a proposed model-building aid, not a rendered screenshot of an existing model. Preserve the original reference's character appeal and the corrected turnaround's consistency. No logos or watermark.
```

## Three-quarter angle repair

Input image 1: the preceding detail-generation output. Its full bodies were too close to front/back views. Output is `head-and-construction-v1.png`.

```text
Edit this Miki construction sheet. Preserve the existing title, layout, colours, visual style and BOTH RIGHT-HAND HEAD/COLLAR CLOSE-UPS EXACTLY. Those two close-ups must not change. Keep all costume pieces, proportions, anatomical sides, open right-hip holster, empty hands and neutral relaxed A-pose.

Correct ONLY the two full-body figures on the left: they are currently almost straight FRONT and BACK despite their labels. REPLACE them with true three-quarter BODY rotations, approximately 45 degrees, of the same Miki.
- FRONT 3/4: rotate the WHOLE body, head, legs and shoulders together so we see her FRONT and anatomical RIGHT SIDE. Her nose points diagonally toward PAGE RIGHT. The nearer right arm/shoulder/hip have visible depth; the far shoulder and far boot are visibly foreshortened. The right-hip holster appears on viewer-left and shows front plus side thickness. We must see both chest front and side plane, not a bilateral straight-on front drawing.
- REAR 3/4: rotate the WHOLE body approximately 45 degrees so we see her BACK and anatomical RIGHT SIDE. The nearer right shoulder, sleeve, hip and holster show real side thickness; the far shoulder is foreshortened and a narrow edge of the right face can appear beyond the hair. The right-hip holster is on viewer-right. We must see both the back plane and side plane, not a straight-on rear drawing.
Use an orthographic-style 45-degree modelling view, not a perspective action pose. Do not rotate ONLY the head; do not merely offset a shoulder or relabel a front drawing. The full-body figures remain equal height on the same ground line.

Preserve the SAME character construction as existing right-head insets and the established turnaround: small adult angular face, dark pointed bob longer toward wearer-right/back; ivory folded collar high on wearer-left with overlap dropping to wearer-right; fitted teal coat, connected layered shoulder cap/sleeves, broad front wrap panel ending around knee, distinct wearer-right secondary rear tail extending to mid-calf; dark tapered legs and compact boots. In the 45-degree views show the folded collar's volume and overlapping coat layers clearly. Holster stays EMPTY with open central channel, cradle and retainer, no flap bag. Strap remains wearer-left shoulder to wearer-right hip. No rifle, tablet, new accessories, extra characters or new text.
Keep the crisp flat unoutlined polygon illustration, simple matte planes and muted grey-green background. Output the corrected construction sheet; change nothing in the right head close-ups.
```

