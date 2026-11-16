# Visual direction

**Status:** Death's Door remains the accepted visual reference. The earlier small visual pass is implemented. The maintainer has since prioritised graybox gameplay evaluation; further visual polish and asset production are deferred.

The main visual reference is [Death's Door, by Acid Nerve / Devolver Digital](https://store.steampowered.com/app/894020/Deaths_Door/). Use its strong silhouettes, restrained detail and readable elevated composition as references for Lauder's own futuristic world. All geometry, colours and materials in this pass are original; no reference-game assets, traced environments or UI are copied.

## Current priority

Use the existing primitive scene, simple colours and animated stand-in to test the [proposed gameplay loop](gameplay-script.md). New game assets are not a prerequisite. Add only the feedback needed to understand actions and their results; retain the current presentation while the script is reviewed. The guidance below describes the earlier pass and a later visual direction, rather than a new art task.

## Apply to the current route

- Give the shelter, depot, obstacles and utility props distinct silhouettes using simple generated geometry and a few bevels or layered forms.
- Use muted teal and stone for large structures, lighter neutral ground for the route, and small amber accents for useful utilities and landmarks. Keep Miki distinct from the ground and nearby props.
- Make the blocked depot entrance and open service passage legible from the existing camera. Keep the walking surface clear of decorative clutter and preserve visible feet and ground contact.
- Express the futuristic setting through relay equipment, utility cabinets, cable housings and salvaged panels. Add only enough detail to distinguish the shelter, street and depot.

Keep the current route, collision layout, camera framing, interaction anchors and controls. This pass does not add a level, combat, mission rules, pickup/repair behaviour or Stage 3 dialogue.

## Rendering budget

Build decoration once during scene setup. Reuse meshes and a small shared material palette. Decorative details do not need their own physics bodies.

- At most two explicit lights, with at most one casting shadows.
- No new textures, particles or postprocessing effects.
- No added visual animation or per-frame visual work; existing character movement, skeletal animation and camera follow continue as before.

These are limits for this pass, not measured performance guarantees. Record the actual scene/material/light counts and validation in the [Stage 2 evidence](stage-2.md).

## Review and performance

Review the start, street and depot at the landscape phone aspect ratio in Simulator. Miki, the walkable path, obstacles and useful landmarks should remain clear while moving, including at the service opening. Run the existing formatting, build and test checks.

The target remains **60 fps on iPhone 13 Pro Max**. Phone checks are currently deferred at the maintainer's request; performance for this visual pass is **unmeasured on the phone**. Simulator screenshots and successful checks do not establish device frame pacing, thermals or battery behaviour. Preserve the limits of the existing [phone-check deferral](../AGENTS.md#work-and-verify) and report the verification gap explicitly.
