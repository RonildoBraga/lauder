# ADR 0005 — Blender as the level editor

**Status:** Accepted by the maintainer on 18 November 2026 (**“Yes, as recommended”**) and implemented for the Brooklyn Bridge. The maintainer [authorised the merge](https://github.com/RonildoBraga/lauder/pull/43#issuecomment-6973768300) (“Yes, merge it”) without an independent review.\
**Date:** 18 November 2026\
**Amended:** 18 November 2026, at the maintainer's request: [the decoration and the game camera](#amendment--the-decoration-and-the-game-camera) join the layout file. The maintainer [authorised the merge](https://github.com/RonildoBraga/lauder/pull/45#issuecomment-6975951390) (“Yes, merge both”) without an independent review\
**Deciders:** Maintainer\
**Author:** Claude

## Context

Levels are typed Swift values written by hand ([ADR 0004](0004-brooklyn-bridge-opening.md), decision 1). Each box in a level is what the player sees, what blocks movement and companion routes, and what stops shots, and the tests check exact positions in it, such as the cover near the stranger.

Asked whether the greybox should be built in Blender, Claude recommended keeping it in Swift and saving Blender for art. The maintainer answered: **“I would rather use Blender because I'm familiar with it and it's to visualize the scene and make the necessary changes”**. Claude then proposed the design below, and the maintainer accepted it as recommended.

Two earlier decisions frame it. The maintainer's code-first rule on issue #9 is “Swift scene construction, direct USDZ loading and source-controlled asset generation/exports”. ADR 0004 turned down levels in JSON, because typed Swift data is checked by the compiler.

## Decision

1. **A layout file per level.** Where everything stands is a plain-data Swift file with stable names: for the bridge, `sources/content/BrooklynBridgeLayout.swift`. It holds the ground, the boxes with their surfaces, the landmarks, flat areas such as triggers and fight areas, and markers such as spawn points. The level's own file adds the words and refers to entries by name: what each place is called, what it says and when.
2. **Blender edits it.** `scripts/blender/lauder_levels.py` adds a Lauder tab to Blender's 3D Viewport:
   - **Load** builds the layout in the open Blender file, in collections by role and coloured by surface. Blender is z-up, so a game point (x, y, z) sits at (x, −z, y).
   - **Save** writes the file back after checking the game's rules, and writes nothing if any rule fails:
     - boxes stay square to the level, so they turn only in quarter turns about the vertical, and stay boxes;
     - boxes and landmarks stand on the deck;
     - every box has a Lauder material;
     - names have no Blender duplicate suffix;
     - no required box, landmark, area or marker disappears, because the level's words refer to them.
3. **The Swift file is the source of truth.** Blender loads it fresh each time, so a direct edit to the file shows up at the next Load. Nothing from Blender is committed.
4. **The game does not change at runtime.** It still compiles typed Swift data, with no parser and no loading. `./scripts/check` runs the script's plain-Python tests: the bridge's file reads and writes back unchanged, and the rules above hold.

## Options considered

| Option | Why not |
|---|---|
| Keep editing Swift by hand | Works, but the maintainer wants to see and change the scene in Blender |
| A committed `.blend` file as the source, with the Swift exported from it | A little simpler day to day, but a direct edit to the Swift file, by an agent or a contributor without Blender, would be overwritten at the next export unless someone reloaded first; the source would be binary |
| Levels as USD from Blender, read by the game at runtime | A loader, and collision and the level's words in a second place; asynchronous loading changes the start-up and Restart guarantees |
| Levels in JSON read at runtime | Turned down by ADR 0004: typed Swift data is checked by the compiler |

## Consequences

- A layout change can be made in Blender or in the file, and is reviewed as text: a moved car is one changed line.
- The file's entries keep the form the script reads. The script refuses to load anything it cannot read exactly, so a save never drops an entry.
- Some tests check positions in today's layout, such as the cover near the stranger and the fight's area. Moving those things means updating the tests with them.
- The decoration that blocks nothing (the walkway, cables, lane lines and tower tops) follows the deck, towers and dividers in the layout. It is not edited in Blender. The [amendment](#amendment--the-decoration-and-the-game-camera) below moves it into the layout file.
- Relay House stayed hand-written Swift until the maintainer removed its level later on 18 November 2026. Art made in Blender and loaded as USDZ remains a later, separate step.

## Amendment — the decoration and the game camera

**Date:** 18 November 2026

After playing M3, the maintainer noted that the scene in the game did not look exactly like the one in Blender. Claude rendered Blender's scene through a camera set up like the game's. Everything in the layout stood where the game puts it; the differences were what Blender did not show: the decoration, the vehicles' cabins and windows, the landmarks' bands, the characters and the lighting. Claude offered to add the game's decoration and camera to Blender. The maintainer answered **“Yes, add them”**, then **“I rather have as much as possible in Blender”**. This amends decision 1 and the decoration's consequence above:

1. **The decoration is in the layout file.** Its entries, *pieces*, are boxes that block nothing and may turn at any angle. The bridge has 111: the river, the lane lines, the tower tops, the raised walkway with its rails and posts, and the cables, suspenders and stays. Each has a name, a size, a surface and, when it is turned, a `turn`: a quaternion written as Swift's `simd_quatf` takes it, (x, y, z, w). The game draws the pieces as written. The Swift rules that made the bridge's decoration are gone; a temporary test showed that the pieces reproduce what those rules made.
2. **So is the game camera:** its offset from its target, just above the leader, and its vertical field of view.
   - Load adds a rig: a target to drag anywhere, and the camera hanging from it and looking at it.
   - Looking through the camera (Numpad 0) frames the scene as the game does on the baseline iPhone's screen.
   - Save writes the camera's offset from the target and its field of view. Dragging the target changes only where Blender looks.
3. **Blender shows the game's details.** By fixed rules from its box, the game draws each vehicle as a body with a cabin, or with a band of windows when it is tall, and each landmark with a band. Load draws them the same way, with each vehicle's box shown as an outline around them. The details follow their box, cannot be selected and are not saved.
4. **Save checks pieces too.** Each stays a box, unmirrored, with a Lauder material and a name of its own. Unlike a box, a piece may stand anywhere and turn any way. A turn that Blender hands back unchanged is kept as written, so a save without edits changes nothing.

### Consequences of the amendment

- The decoration no longer follows the layout by itself. Moving a tower or a divider leaves its top, walkway and cables where they were, so they have to be moved with it.
- Blender still does not show the characters, the game's lighting and shadows, or the materials' finish.

### Checks

- `./scripts/check` passes: 124 Swift tests in 19 suites on the iPhone 17 / iOS 27 Simulator, and the layout script's 22 tests. The new tests cover:
  - pieces and the camera reading and writing back unchanged;
  - rotations converting between the game's axes and Blender's;
  - a turned piece and a moved camera saving as expected, down to a half-degree turn;
  - a hand-written turn surviving a save;
  - Save's rules for pieces, and the camera kept when its rig is gone;
  - the details of a car, a truck and a landmark;
  - the game drawing every piece where and as the file says, with the file's camera.
- In Blender 5.3:
  - Load builds the 111 pieces, 43 details and the camera rig, and Save with no edits writes nothing.
  - Turning a cable 30° about the vertical, moving the river, dragging the camera's target and widening the field of view to 50° saved exactly three changes, to a copy of the file: the river's position, the cable's turn, which matched a 30° turn, and the field of view.
  - The view through the game camera matches the game's opening frame in the Simulator, apart from Miki and the lighting.
- Rendered Simulator runs in a Debug build: `bridge-walk` passed 37 of 37 steps and `ambush` 35 of 35. Frames averaged 16.7 ms in both, and the only frame longer than 34 ms in each was its first. These are Simulator figures, not phone performance; the phone was not checked.
