# ADR 0005 — Blender as the level editor

**Status:** Accepted by the maintainer on 18 November 2026 (**“Yes, as recommended”**) and implemented for the Brooklyn Bridge.\
**Date:** 18 November 2026\
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
- The decoration that blocks nothing (the walkway, cables, lane lines and tower tops) follows the deck, towers and dividers in the layout. It is not edited in Blender.
- Relay House stays hand-written Swift for now. Art made in Blender and loaded as USDZ remains a later, separate step.
