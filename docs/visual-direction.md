# Visual direction

**Status:** Death's Door remains the accepted visual reference. The earlier small visual pass is implemented. The maintainer has since prioritised graybox gameplay evaluation; further visual polish and asset production are deferred.

The main visual reference is [Death's Door, by Acid Nerve / Devolver Digital](https://store.steampowered.com/app/894020/Deaths_Door/). Use its strong silhouettes, restrained detail and readable elevated composition as references for Lauder's own futuristic world. All geometry, colours and materials in this pass are original; no reference-game assets, traced environments or UI are copied.

## Current priority

Use the greybox bridge, simple colours and primitive stand-ins to test the [opening](gameplay-script.md). New game assets are not a prerequisite. Add only the feedback needed to understand actions and their results. The guidance below records the earlier pass and the later direction, rather than a new art task.

## Applying the reference

- Give large structures, obstacles and useful props distinct silhouettes using simple generated geometry and a few bevels or layered forms.
- Use muted teal and stone for large structures, lighter neutral ground for the route, and small amber accents for useful things and landmarks. Keep Miki distinct from the ground and nearby props.
- Keep the route and its blockers legible from the camera. Keep the walking surface clear of decorative clutter and preserve visible feet and ground contact.
- Express the futuristic setting through equipment, utility cabinets, cable housings and salvaged panels, with only enough detail to tell places apart.

A visual pass keeps the route, collision layout, camera framing, interaction anchors and controls.

## Rendering budget

Build decoration once during scene setup. Reuse meshes and a small shared material palette, `apple/sources/content/Surfaces.swift`, which Blender edits. Decorative details do not need their own physics bodies.

- At most two explicit lights, with at most one casting shadows. Blender's Save checks this for the lights in a layout file.
- No new textures, particles or postprocessing effects.
- No added visual animation or per-frame visual work; existing character movement, skeletal animation and camera follow continue as before.

These are limits, not measured performance guarantees. Record the actual scene, material and light counts and the validation with the change.

## Review and performance

Review the scene at the landscape phone aspect ratio in Simulator. Miki, the walkable path, obstacles and useful landmarks should remain clear while moving. Run the standard checks.

The target remains **60 fps on iPhone 13 Pro Max**. The earlier visual pass was not measured on the phone. Simulator screenshots and successful checks do not establish device frame pacing, thermals or battery behaviour; report the verification gap explicitly.
