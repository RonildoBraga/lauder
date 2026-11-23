# Visual direction

**Status:** A minimalist low-poly frozen world, chosen by the maintainer on 20 November 2026 to replace Death's Door as the reference. The bridge moves to it in small steps from today's greybox, keeping gameplay readable throughout, and the colours, angles and sizes below are starting values, tuned in the Simulator and on the phone.

**Angular character direction, 24 November 2026:** The maintainer selected the [angular trio sheet](../art/characters/angular-study/README.md) as the basis for modelling and authorised a static [Miki blockout](../blender/studies/miki-angular/README.md) before animation fitting. Small simplified heads, exaggerated mass and limb ratios, angular negative spaces and flat graphic colour planes guide this pass. The blockout's exact proportions and appearance await review; current runtime rendering and the frozen world remain unchanged.

## The direction

**Quiet, cold, sparse and legible.** The world is frozen: rivers and the sea lie under ice, and most of the land is buried under snow. Most of the screen is flat white ground, with a few structures and landmarks on it. Simple geometry, a small palette, long shadows and carefully placed objects make the world distinctive, rather than detail or graphical complexity.

Every object earns its place by helping the player read the route, the story or a danger.

## References

The maintainer's reference images show:
- a snowy cabin among pines, with a trail of footprints to a small hiker;
- an icebreaker cutting a dark channel through white sea ice;
- a desert petrol station drawn in flat shapes beside a road with power poles;
- tiny figures beside tall faceted rock pillars on pale ground.

They share these qualities:
- **Empty ground is most of the picture,** usually seventy to ninety per cent of the frame. The emptiness carries the mood.
- **Objects come in small clusters,** and the detail thins out around each one.
- **The palette is small:** one dominant neutral for the ground, one shadow colour, and one or two accents used sparingly.
- **Shading is flat or faceted,** without realistic textures. Forms read through their silhouettes and the faces that catch the light.
- **Shadows are part of the drawing:** long, crisp, diagonal and tinted.
- **People are tiny,** and a single strong colour makes each one findable.
- **Small marks tell the story:** footprints, smoke, a broken channel through ice.
- **The camera is high and distant,** with a long lens and weak perspective, close to a diorama.

Lauder takes the mood and the methods, not the drawings: all geometry, colours and materials are original. It leaves out the ink outlines and stippling of the cabin and the icebreaker. Those are hard to do well in RealityKit and add geometry to everything outlined, and the petrol station and the rock pillars show the same mood without them.

## Geometry and composition

- Faceted low-poly forms with flat shading and hard edges, with at most one chamfer on large forms.
- Silhouette before detail. Nothing smaller than about 30 cm, except scattered debris.
- Snow sits on top faces as its own slightly rounded cap, 5 to 30 cm thick, in the snow colour.
- Built forms are straight and square. Natural forms, such as drifts, ice ridges and rocks, are irregular faceted lumps.
- Landmarks stay recognisable: the bridge towers' twin pointed arches, the cable fans, a half-buried skyline.
- Most of the screen stays empty. Detail gathers around landmarks and story moments, and thins out between them.
- The walking surface stays clear and readable, with clutter at edges and corners. Feet and ground contact stay visible.

## Palette

One shared set of colours serves every level and model. At least 80% of the screen is neutral; accents appear only where they mean something: the party, things to use, threats, and one or two story props in a place.

| Colour | Value | Use |
|---|---|---|
| Snow | `#ECE9E2` | Deck, ground, roofs and snow caps; slightly warm, so it separates from ice |
| Shadow | `#A9B7C6` | Blue-grey colour of the shadows baked into the snow, such as the towers'; lit by the level's lights |
| Ice | `#D3DFE6` | Frozen river and sea; cooler than snow, so it reads as not the route |
| Ice ridge | `#8FA5B3` | Cracks, pressure ridges and floe edges |
| Open water | `#23343F` | Rare channels of dark water, the strongest dark in the world |
| Stone | `#B7AC9D` | Towers, piers and old masonry |
| Weathered stone | `#857B70` | Bases, rubble and debris |
| Ink | `#36414B` | Railings, cables, poles and window holes, which read as line work |
| Rust | `#A65A43` | Accent: barriers, signage, an occasional vehicle |
| Faded teal | `#5E7C80` | Accent: vehicles and old paintwork |
| Mustard | `#B69A5A` | Accent: taxis and warning paint |
| Amber | `#E2A64B` | Things to use and the leader's ring; kept clearly apart from Laura's orange |

The party keeps its colours: Miki `#40A696`, Laura `#E69C4A` and Tom `#6182CF`. Hostiles are dark red, `#7A2E2A`, the only red figures on the ice. The bridge environment pass uses `#A9B7C6` as the baked shadow material's base colour, replacing the earlier neutral `#CBC9CA`. These are sRGB palette values, converted to scene-linear values in Blender. The lights change their displayed appearance; the palette is not a sampled screen-colour or phone performance claim.

## Materials

- One Principled BSDF per palette colour, with roughness 1, metallic 0 and no specular sparkle.
- Every level and model uses the shared palette materials, so a colour changes in one place. A new colour joins the palette before anything uses it. A shared palette library in Blender comes with the first kit models; until then each file's materials take the palette's values.
- No textures, apart from baked ambient occlusion where contact needs it.

### Robot blockout palette

The rejected first robot blockout used asset-specific matte materials from the earlier [dark armed concept](../art/robot/README.md). Its Principled BSDF materials have roughness 1 and metallic 0, with no emission or textures. The table below records that historical palette, also shown in the [bulkier proportion studies](../art/robot/bulk-studies/README.md) and retained motion reel. It is not the current C finish. A remains a possible later different-weapon variant; the existing world palette is unchanged.

| Part | Base colour |
|---|---|
| Armour | `#30343E` |
| Slate facets | `#4B5260` |
| Joints and muzzles | `#151D24` |
| Burgundy face | `#662E30` |
| Pale sensor | `#E9DFCA` |

### Current C finish

After accepting the refined body and legs, the maintainer requested removal of the reddish-brown face colour and a red sensor. The current [C source and previews](../blender/assets/spider-bot-heavy/README.md) use **charcoal face `#30343E`**, matching the armour, and **red sensor `#C83C38`**. Armour, slate facets and joints otherwise retain the values above. Materials remain matte, with roughness 1, metallic 0 and emission 0; the red square adds no light or glow effect. This finish and the 12% smaller cannons await visual review. Historical artwork, movie colours and build 29 are unchanged.

The maintainer subsequently authorised a Blender pass guided by the AI-generated [finish study](../art/robot/finish-study/README.md): a real recessed sensor socket and clearer stepped/chamfered roof and cannon plates. That geometry is modelled. The maintainer then requested a stronger leg reduction: the current upper-leg armour narrows 15% at its main bulge and 20% towards the knee, below the unchanged hip edge; shins narrow 20%. The maintainer then assigned lowering the hip mounts **15 cm**, from **1.28 to 1.13 m**, to give the guns more space. The current model preserves those slimmer meshes and all body/gun geometry, reposing and rebaking leg rotations while preserving the feet's world paths. This mount/pose result awaits visual review. The full red front outline, body proportions, socket/joint/foot geometry, reduced gun bodies/barrels, structural symmetry, shared components and five matte materials remain. Shoulder construction is expressed through the cannon plates rather than reshaping the leg covers. The concept image remains a visual reference; revision-specific authoring and Simulator verification is recorded in the [model README](../blender/assets/spider-bot-heavy/README.md). A separate [dormant-to-pursuit Blender study](../blender/assets/spider-bot-heavy/README.md#dormant-to-pursuit-blender-study) stages the requested low rest, eye cue, rise and pursuit for animation review; it links the canonical meshes and adds no runtime wake/approach trigger. The current study tests heavier pursuit with roughly twice the foot travel per step, slower swings, a brief planted dwell and restrained contact-driven compression rather than a repeating bob. Wake/rise, actor travel, camera, guns and linked production meshes remain intact; canonical motion and runtime gait are unchanged. Its fresh 240 Hz motion/contact audit and live Blender playback pass, while the heavier-step preview awaits visual approval. No further leg reduction is assigned. Snow/wear is deferred.

## Light and shadow

- One sun for the whole game: warm white, 25° to 35° high, from the south-west, so that shadows fall towards the top right of the screen. The sun's direction never changes within a level, so shadows are a consistent part of the composition.
- A cool fill from the opposite side, so that shadows read blue-grey, not black or neutral grey.
- The shadow covers the camera's view, about 70 to 90 m, and must stay crisp enough on the phone.
- A landmark that fades while it hides the party casts no live shadow. Its shadow is baked into the ground in Blender, where the sun throws it, so it never fades; it does not darken the people who walk through it.
- Baked ambient occlusion grounds vehicles, drifts and tower bases.

## Camera and scale

- A high three-quarter view along the route, rather than a strict isometric one, with the selected camera B's 22° lens and a view about 51.8° down.
- Camera B's offset is `[0, 56, 44]` in game coordinates: 56 m above and 44 m behind its target, about 71.2 m away. The maintainer selected it on 23 November 2026 after comparing it with the previous `[0, 50, 42]`, 20° framing in Simulator. It shows about 20% more width at the target and makes characters smaller. The intended character-size range of 15 to 25 points on the baseline phone remains a readability target, not a new physical measurement. The camera keeps its height, above the towers' tops, and comes closer through its lens rather than by moving lower. In a fight, or while the right stick aims, the lens narrows to 70%, 15.4° ([ADR 0007](decisions/0007-aiming-and-shot-feedback.md)).
- The view looks straight along the bridge, so pushing up walks towards Manhattan. Diagonal views may suit open areas later.
- Tall landmarks, such as tower tops and buildings, fade to a see-through ghost while they come between the camera and the party, so the player still sees what is in the way. The ghost is unlit, in each part's own colour, since a lit see-through landmark that fills the screen costs the phone's GPU too much.
- World markers, such as the leader's ring, order rings, the refusal cross and the aim marker, keep a readable size on screen: a camera that shows more of the ground draws them larger, as the [architecture](architecture.md#movement-and-presentation) sets out.

## Characters and interface

- Characters are about 400 triangles each, with one distinct silhouette and one strong colour per person, and a soft contact shadow. Facing shows through the body's shape. On 23 November 2026 the maintainer assigned playable-character models and animations and selected more stylised proportions with larger heads. The [party study](../blender/studies/party-characters/README.md) established a lightweight shared 17-bone humanoid rig within that triangle target. The subsequent integration assignment uses those meshes and shared motion, adding distinct running and crouched sneaking. Human hostiles retain the original whole-figure motion.
- The retained [rounded Miki study](../blender/studies/miki-concept/README.md) is a historical comparison. The maintainer selected the [angular trio direction](../art/characters/angular-study/README.md): Miki uses a tapered coat wedge, Laura a lean diagonal and Tom a broad compact trapezoid. The assigned [static Miki blockout](../blender/studies/miki-angular/README.md) tests those large forms beside the concept and at camera B, with restrained facial marks and flat shading. Its directly editable components are unrigged; silhouette review precedes fresh rest-joint, skinning, foot/weapon-contact and shared-motion fitting. Exact camera projection and a close artist view are recorded separately. Current canonical assets, palette and runtime budget remain unchanged; no Blender still establishes phone performance.
- The interface is light and small, so the world stays the subject: frosted panels with ink words. The status panel keeps to the essentials: the party and its formation, a new objective or line for a few seconds, and a threat or the carbine's rounds while they matter; Circle / B or H hides it. A compass at the top centre points to the next goal with its distance. A controller's or keyboard's controls that apply show in one strip at the bottom, and the touch buttons are frosted too. Controls and their rules do not change.

## The bridge in the frozen world

Snow has buried the bridge's road, everything left on it and the frozen East River alike: a flat white plain at the level of the old deck, with only the towers and their arches standing above it. The maintainer chose this on 20 November 2026, after playing the first build of the new look, and then chose to take every other obstacle out of the game as well, so the towers are the only cover and an invisible edge keeps the party on the line of the buried road. The towers' long shadows, baked into the snow, fall across the plain, and a tower fades to a ghost while it hides the party; its shadow stays. The maintainer chose the ghost and the baked shadows on 20 November 2026, after a full fade hid what stood in the way and took the towers' shadows with it. Thin ink poles with small rust flags stand every 25 m along both edges of the buried road, as on a polar route, so the way and the party's movement read on the white; they block nothing. Ice, with cracks, pressure ridges and rare channels of open water, can show where the wind has cleared the snow, and Brooklyn and Manhattan can show as half-buried blocks at the edges.

The bridge also uses the palette, the light and the camera's starting values, its world markers keep their size on screen, and its HUD is light and frosted, with the compass. A visual pass keeps the route, the collision layout, interaction anchors and the controls.

On 23 November 2026 the maintainer assigned the bridge environment in Blender before the robot. The [level source](../blender/levels/README.md#brooklyn-bridgeblend) now gives the towers faceted pointed arches and weathered bases, adds thin cable fans and places broad, low snow facets outside the walking route. The selected [gameplay concept](../art/bridge/bridge-gameplay-v1.png) guides form and palette; its compressed composition does not replace the existing tower dimensions or spacing. The later camera B choice changes the framing while retaining that geometry. It gives more breathing room, but the towers' arches still crop up close. Both towers retain their independent ghost fade. The cables cast no runtime shadow and are omitted from the masonry's bounding-box shadow bake, which would otherwise turn thin strands into broad slabs. The subsequent robot blockout was rejected for its proportions. The maintainer subsequently selected C for a new Blender form study, retaining A for a possible later different-weapon variant. The maintainer accepted the resulting form and assigned Blender walking, turning and visual shooting studies with mirrored, reusable leg assemblies before bridge placement. The subsequent first-tower runtime integration is implemented and verified in Simulator; phone performance remains unverified.

## Rendering budget

Build decoration once, in the level's Blender file, with shared palette materials. A model in `blender/assets` keeps its own file. Decorative details do not need their own physics bodies.

- At most four explicit lights, with at most one casting shadows. Suns, point lights and spot lights count alike, and only a sun or a spot light can cast the shadow. Blender's export checks this for each level's lights. Under the daylight sun, a point or spot light shows only when it is very strong, in Blender's preview as in the game.
- At most 60,000 triangles and 150 draw calls in view, at most 16 materials, and party characters of at most 400 triangles: [Miki's README](../blender/assets/miki/README.md) records the current mesh count. The older static human hostile remains a stand-in; source counts do not establish whole-scene GPU budgets.
- No textures apart from baked ambient occlusion, at most 4 MB per level.
- No particles or postprocessing. A static paper-grain overlay and light snowfall are candidates, each to be measured on the phone and agreed first. Shots are the exception ([ADR 0007](decisions/0007-aiming-and-shot-feedback.md)): streaks, flashes, chips and marks made of plain blocks in the palette's colours, made once and reused.
- No line shows the leader's aim ([ADR 0008](decisions/0008-weapon-feel-and-combat-plan.md)). Her pose shows it: the carbine held low across her body, or raised to her shoulder along her facing, and kicked by each shot. Party joint reactions follow accepted combat events while the hands fit the authoritative weapon pose. Static human hostiles retain whole-figure reactions and a downed hostile falls away from the shot.
- No per-frame visual work beyond what gameplay needs, such as fading a landmark or sizing a marker.

These are limits, not measured performance guarantees. Record the actual scene, material and light counts and the validation with the change.

## Review and performance

Review the scene at the landscape phone aspect ratio in Simulator. The party, the walkable path, obstacles and useful landmarks should remain clear while moving, at the new camera distance as well.

The target is **60 fps on iPhone 13 Pro Max**. Simulator screenshots and successful checks do not establish device frame pacing, thermals or battery behaviour; report the verification gap explicitly.
