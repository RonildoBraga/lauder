# Visual direction

**Status:** A minimalist low-poly frozen world, chosen by the maintainer on 20 November 2026. It replaces Death's Door as the reference. The bridge moves to it in small steps from today's greybox, keeping what exists where it serves, and gameplay stays readable throughout. Colours, angles and sizes below are starting values, tuned in the Simulator and on the phone. The bridge already uses the palette, the light and the camera's starting values, its towers fade while they hide the party, its world markers keep their size on screen, the HUD is light and frosted, and flagged poles and a compass show the way. A shared palette library in Blender comes with the first kit models; until then each file's materials take the palette's values.

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
| Shadow | `#CBC9CA` | Shadows baked into the snow, such as the towers'; lit like the snow, it lands where the live shadows do |
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

The party keeps its colours: Miki `#40A696`, Laura `#E69C4A` and Tom `#6182CF`. Hostiles are dark red, `#7A2E2A`, the only red figures on the ice. Shadows on snow should land near `#A9B7C6`; that is a target for the lighting. Today the bridge's live shadows land lighter and neutral, near `#D6D4D5`, and a shadow baked into the snow wears the shadow colour, which the sun brings to the same tone. When the light changes, the shadow colour is matched again.

## Materials

- One Principled BSDF per palette colour, with roughness 1, metallic 0 and no specular sparkle.
- Every level and model uses the shared palette materials, so a colour changes in one place. A new colour joins the palette before anything uses it.
- No textures, apart from baked ambient occlusion where contact needs it.

## Light and shadow

- One sun for the whole game: warm white, 25° to 35° high, from the south-west, so that shadows fall towards the top right of the screen. The sun's direction never changes within a level, so shadows are a consistent part of the composition.
- A cool fill from the opposite side, so that shadows read blue-grey, not black or neutral grey.
- The shadow covers the camera's view, about 70 to 90 m, and must stay crisp enough on the phone.
- A landmark that fades while it hides the party casts no live shadow. Its shadow is baked into the ground in Blender, where the sun throws it, so it never fades; it does not darken the people who walk through it.
- Baked ambient occlusion grounds vehicles, drifts and tower bases.

## Camera and scale

- A high three-quarter view along the route, rather than a strict isometric one, with a long lens of about 20° and a view about 50° down.
- The camera is far enough away that characters stand about 15 to 25 points tall on the baseline phone, and the whole deck and its surroundings show. The starting point is 65 m away with a 20° lens. The camera keeps that height, above the towers' tops, and comes closer through its lens rather than by moving lower.
- The view looks straight along the bridge, so pushing up walks towards Manhattan. Diagonal views may suit open areas later.
- Tall landmarks, such as tower tops and buildings, fade to a see-through ghost while they come between the camera and the party, so the player still sees what is in the way. The ghost is unlit, in each part's own colour, since a lit see-through landmark that fills the screen costs the phone's GPU too much.
- World markers, such as the leader's ring, order rings, the refusal cross and the aim marker, keep a readable size on screen: drawn larger by as much more of the ground as the camera shows than the 14 m, 42° camera they were made for, about twice as large on the bridge.

## Characters and interface

- Characters are about 400 triangles each, with one distinct silhouette and one strong colour per person, and a soft contact shadow. Facing shows through the body's shape. No rigging is needed at this size.
- The interface is light and small, so the world stays the subject: frosted panels with ink words. The status panel keeps to the essentials: the party and its formation, a new objective or line for a few seconds, and a threat or the carbine's rounds while they matter; Circle / B or H hides it. A compass at the top centre points to the next goal with its distance. A controller's or keyboard's controls that apply show in one strip at the bottom, and the touch buttons are frosted too. Controls and their rules do not change.

## The bridge in the frozen world

Snow has buried the bridge's road, everything left on it and the frozen East River alike: a flat white plain at the level of the old deck, with only the towers and their arches standing above it. The maintainer chose this on 20 November 2026, after playing the first build of the new look, and then chose to take every other obstacle out of the game as well, so the towers are the only cover and an invisible edge keeps the party on the line of the buried road. The towers' long shadows, baked into the snow, fall across the plain, and a tower fades to a ghost while it hides the party; its shadow stays. The maintainer chose the ghost and the baked shadows on 20 November 2026, after a full fade hid what stood in the way and took the towers' shadows with it. Thin ink poles with small rust flags stand every 25 m along both edges of the buried road, as on a polar route, so the way and the party's movement read on the white; they block nothing. Ice, with cracks, pressure ridges and rare channels of open water, can show where the wind has cleared the snow, and Brooklyn and Manhattan can show as half-buried blocks at the edges.

A visual pass keeps the route, the collision layout, interaction anchors and the controls.

## Rendering budget

Build decoration once, in the level's Blender file, with shared palette materials. A model in `blender/assets` keeps its own file. Decorative details do not need their own physics bodies.

- At most four explicit lights, with at most one casting shadows. Suns, point lights and spot lights count alike, and only a sun or a spot light can cast the shadow. Blender's export checks this for each level's lights. Under the daylight sun, a point or spot light shows only when it is very strong, in Blender's preview as in the game.
- At most 60,000 triangles and 150 draw calls in view, at most 16 materials, and characters of at most 400 triangles.
- No textures apart from baked ambient occlusion, at most 4 MB per level.
- No particles or postprocessing. A static paper-grain overlay and light snowfall are candidates, each to be measured on the phone and agreed first.
- No per-frame visual work beyond what gameplay needs, such as fading a landmark or sizing a marker.

These are limits, not measured performance guarantees. Record the actual scene, material and light counts and the validation with the change.

## Review and performance

Review the scene at the landscape phone aspect ratio in Simulator. The party, the walkable path, obstacles and useful landmarks should remain clear while moving, at the new camera distance as well.

The target is **60 fps on iPhone 13 Pro Max**. Simulator screenshots and successful checks do not establish device frame pacing, thermals or battery behaviour; report the verification gap explicitly.
