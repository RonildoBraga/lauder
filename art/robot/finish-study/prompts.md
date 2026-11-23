# C finish-study prompts

Generated with the built-in image-generation tool on 23 November 2026, using two targeted edit calls with opaque backgrounds. The final selected output is [robot-finish-v1.png](robot-finish-v1.png). It is a concept proposal, not an export from Blender or a game screenshot.

## First call

Input 1 is the edit target: the actual [C Blender hero render](../../../blender/assets/spider-bot-heavy/preview.png) at source commit `2df4b45be850b3a1aaff8a103547e502b83a9bd8`. The current path may change with later modelling; the [source revision](https://github.com/RonildoBraga/lauder/blob/2df4b45be850b3a1aaff8a103547e502b83a9bd8/blender/assets/spider-bot-heavy/preview.png) identifies the input. It inherits the model's [CC BY 4.0 source chain](../attribution.md).

```text
Use case: precise-object-edit.
Asset type: a restrained low-poly robot finish concept for a mobile game, to review before changing the actual Blender model.
Input image 1 is the EDIT TARGET: the actual current C robot Blender hero render. Preserve its composition, lighting, background, camera, stance and accepted overall geometry.

Change only these two design features:
1. Recess the single red square sensor into a protected near-black square socket with one broad chamfered frame. Keep its red visible face approximately the same size, clearly readable from above, with a matte red lens and no light emission or glow. Make the eye look engineered into the face rather than a red tile attached to it.
2. Give the existing large charcoal/slate armour plates on the roof and shoulders clearer construction: subtle stepped thickness, a few wide recessed joins and deliberate single chamfered edges. Repeat one consistent industrial edge treatment on the existing small cannon housings. Make the two lighter roof bands read as structural armour plates. Preserve the long rear-rising body and narrow front mask.

Invariants: exactly four identical-component articulated legs, unchanged leg shapes/proportions and feet; exactly two small paired forward cannon pods with one barrel each; two short antennas; neutral left/right mirror symmetry of structural parts; charcoal face/armour #30343E, slate facets #4B5260, near-black joints #151D24, single red square sensor #C83C38. Preserve the recently reduced gun size, current overall silhouette, four planted feet and negative space between the legs. All of the robot fully visible, same pale background and blue-grey shadow. One robot, one view, no labels.

Style: attractive very low-poly matte untextured flat-shaded 3D game concept. A small number of purposeful large planes and bevels. It must remain feasible to reproduce as simple shared meshes for iPhone gameplay. This is a modest finish pass, not a redesign.
Do not add snow, weathering, scratches, bolts, tiny seams, grille meshes, vents, cables, greebles, new guns, limbs, weapons, characters, props, text, logos, glowing outlines, shiny metal, realistic textures, fog or dramatic presentation lighting. Preserve the current render's grounded industrial character.
```

## Correction call

Input 1 is the first generated candidate, used as the edit target. Input 2 is the same actual Blender hero render, used as an invariant reference for the sensor colour/visible area and plain leg shapes. The first candidate reduced the red lens and added narrow plates to the legs; this call corrects those issues. Only the final candidate is retained in the repository. The prompts describe requested invariants; AI imagery is approximate and does not verify mesh dimensions, symmetry, materials or runtime performance.

```text
Use case: precise-object-edit.
Input image 1 is the EDIT TARGET: the new robot finish concept. Input image 2 is a supporting invariant reference: the actual current Blender hero render.
Make one targeted correction pass to image 1:
- Enlarge the visible red square sensor by about 30% in both dimensions, refitting its existing dark broad-chamfered socket within the same front mask. Match the clear matte red #C83C38 from image 2. Keep the new recessed housing, but ensure the red lens itself remains as readable and proportionally prominent as in image 2. No glow or emission.
- Remove the thin added armour strips sitting on top of the upper-leg plates. Restore the simple broad unadorned leg surfaces from image 2. Do not redesign, reshape or detail the legs or feet.
Preserve image 1's roof/shoulder plate construction, subtle stepped joins and single-chamfer language, the accepted long rear-rising body and narrow charcoal face, smaller paired cannons, exactly four legs, two antennae, symmetric structural construction, stance, framing, pale background and lighting. One fully visible robot only. No additional changes, no snow, textures, scratches, tiny details, effects, labels or text. Keep the same restrained matte low-poly style.
```
