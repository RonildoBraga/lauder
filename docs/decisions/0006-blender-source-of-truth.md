# ADR 0006 — Blender as the source of levels and models

**Status:** Accepted by the maintainer on 19 November 2026 (**“Yes, record it”**) and [merged](https://github.com/RonildoBraga/lauder/pull/51#issuecomment-6999540584) under the maintainer's standing permission (“you dont need for my reviews, you can always merge it”), without an independent review. Steps [2](#step-2--the-path-into-the-game) and [3](#step-3--the-blender-file-as-the-source) are built: each level's Blender file is its source, and [ADR 0005](0005-blender-level-editor.md)'s round trip has ended.\
**Date:** 19 November 2026\
**Supersedes:** ADR 0005's decision 3 and its Load and Save round trip, once step 3 lands. [ADR 0004](0004-brooklyn-bridge-opening.md)'s typed level data stays, generated from Blender.\
**Deciders:** Maintainer\
**Author:** Claude

## Context

On 19 November 2026 the maintainer asked to revisit the earlier decisions: **“From my perspective, Blender should be the single source of truth for designing and building the game's environments, levels, assets, lighting, and other visual elements.”** They asked for a pipeline that:

- treats Blender files as the authority;
- works with files made together through Blender's MCP connection and with files they provide;
- automates export and import;
- keeps materials, textures, lighting and positions wherever feasible;
- separates what Blender manages from what the game must handle, such as gameplay logic, collisions, navigation and engine-specific lighting.

They added: **“don't assume my proposed approach is necessarily the best one.”**

ADR 0005 rests on the opposite rule: the Swift files are the source of truth, and nothing from Blender is committed. Claude reviewed it against these goals. It suits a greybox but cannot carry the rest:

- Only what the Swift files can describe reaches the game: boxes, two suns and ten flat finishes. Meshes, textures and files the maintainer provides have no way in.
- The look is drawn by code and imitated in Blender, so the vehicles' details are written twice.
- Every new kind of thing needs a reader, a writer and a round-trip test in the extension.

### What a test export showed

Claude exported a copy of the bridge's working file with Blender 5.3's own USD exporter, after adding an image texture, a point light, a spot light and a custom property. RealityKit on macOS 27 loaded the result, as `.usdz` and as text `.usda`, with the same outcome:

| What | Result |
|---|---|
| Positions and scale | Exact: `car-a1` stood at (9.6, 0.75, 100), where the layout puts it, in metres and the game's axes |
| Materials | All 224 meshes arrived with physically based materials made from Principled BSDF |
| Image texture | Arrived |
| Camera | Arrived as a camera |
| Names | Changed: USD allows no hyphens or dots, so `car-a1` became `car_a1` and `spawn.miki` became `spawn_miki` |
| Point and spot lights | The point light arrived; the spot light arrived as a point light, without its cone |
| Suns | Dropped |
| Custom properties | Written to the file, but RealityKit offers no way to read them |
| Size | 183 KB as the `.blend`, 43 KB as the USDZ |

RealityKit can take a scene's look from Blender, but not its meaning: nothing in the scene can tell the game which box is a trigger. The iPhone uses the same framework; step 2 confirms the result there.

## Decision

1. **Blender files are the source** of levels and models. Each level is a committed Blender file, `blender/levels/<level>.blend`. Each model is a file of its own under `blender/assets/`, linked into the levels that use it. Git LFS stores them, as `.gitattributes` already provides, and locks a file while someone edits it.
2. **One Export writes what the game reads:** two generated files per level, both committed and marked as generated at the top.
   - A USDZ scene holds what the player sees: meshes, materials and textures.
   - The typed Swift layout holds what plays: blockers, trigger and fight areas, markers, landmarks, the game camera and the lights. Lights travel as data because RealityKit drops suns from USD.

   Nobody edits a generated file by hand; every change starts in Blender.
3. **Collections decide where objects go.** A level file has four: **Visual**, exported to the USDZ, and **Gameplay**, **Lights** and **Camera**, exported to the layout. Gameplay objects show in Blender as outlines and the game never draws them. A vehicle is therefore its model in Visual and its box in Gameplay, so the model can change without changing how the level plays. A simple model can serve as its own box.
4. **Export checks the game's rules first,** as Save does today, and writes nothing when one fails. It runs when the level's file is saved, from Play, and from a script that agents can run in the background.
5. **The exports are committed,** so the app builds without Blender. Each records every file it was made from, with a fingerprint of each: the level's Blender file, the models linked into it and their textures. It also records a fingerprint of its own content. `./scripts/check` fails when any of these files is missing or no longer matches, without running Blender.
6. **The game's code keeps the behaviour:**
   - the story and its words, interactions, fights and AI;
   - movement and navigation, which use Blender's blockers;
   - how light renders, with RealityKit's light components, shadows and image-based light;
   - the camera's behaviour: following, easing and leaning during fights;
   - the stand-ins, the gameplay signals and future effects;
   - loading the level's scene once at start, which Restart keeps.
7. **Files the maintainer provides go through an intake check** before use. It reports on units and scale, axes, names, materials and textures, and size budgets. Each file keeps a note of its source and licence, as [CONTRIBUTING](../../CONTRIBUTING.md#assets-and-attribution) requires.
8. **The contract between Blender and the game:**
   - names are lowercase, unique and stable, and the exporter maps them predictably to USD's;
   - lengths are in metres, on the game's axes;
   - materials use Principled BSDF with image textures, and anything else is baked into images first;
   - lights keep the [visual direction](../visual-direction.md#rendering-budget)'s budget, at most two with one casting shadows, at 1 W/m² of sun for every 700 lux, as ADR 0005 set.

ADR 0005 turned down both halves of this design, and this decision answers its reasons:

- **A committed `.blend` with the Swift exported from it:** a direct edit to the Swift file would be overwritten at the next export. Under this decision nobody edits the generated files, and the check catches an edit.
- **Levels as USD read at runtime:** collision and the level's words would sit in a second place, and loading would change the start-up and Restart guarantees. Under this decision collision stays in the typed layout and the words stay in Swift. The one load happens before the first frame, and Restart keeps the loaded scene.

## Options considered

| Option | Why not |
|---|---|
| Keep the Swift files as the source (ADR 0005) | Reviewable and mergeable as text, but meshes, textures and provided files cannot travel, and each new kind of thing needs new reader code |
| One USD file, with the game reading gameplay from names at runtime | One output instead of two, but RealityKit reads names and not properties and drops suns, and mistakes would show only when the game runs |
| Reality Composer Pro as the scene editor | Excluded by the maintainer on issue #9, and a second editor beside Blender |
| Export during every Xcode build | Nothing to forget, but every build and every agent would need Blender, and builds would slow down |
| An engine with its own level editor, such as Unity or Godot | Most studios build levels this way, but it would reverse [ADR 0001](0001-engine.md) for a problem that Blender solves here |

## Consequences

- When step 3 lands, ADR 0005's decision 3 ends. The following retire:
  - Load, and reading the Swift back into Blender;
  - safe Save, and the working file in `.local/blender`;
  - the palette file, `Surfaces.swift`.

  The decoration pieces leave the layout for the USDZ. The extension gets smaller, and the look needs no new code for each new kind of thing.
- The game stops drawing the level's look. `SceneStyle` keeps the stand-ins, the gameplay signals and the lights.
- A `.blend` cannot be read or merged in a pull request. A pull request that changes one also carries the generated Swift, which shows each gameplay change line by line, and a picture through the game camera for the look. Git LFS locks stop two people editing one file.
- Nobody moves a box by editing Swift any more. Agents use Blender in the background or over MCP.
- Git LFS storage grows with each committed version of a Blender file or a USDZ. Keeping textures in files of their own keeps them out of the Blender files, but each USDZ packages the textures it uses: every new version of a level's USDZ stores them again, and levels that share a texture each carry a copy. The allowance check has to count both.
- The scene loads before the first frame instead of being compiled in.
- Blender's renderer is not RealityKit. Game Look comes close, and Play shows the real result.
- Tests that check positions read the generated layout, so they keep working.
- Three things stay as they are:
  - ADR 0004's typed level data, now generated;
  - the code-first rule on issue #9, now put to use by loading each level's USDZ directly;
  - the visual direction's limits. The pipeline makes room for art without requiring any.

## Plan

Each step is a pull request of its own and needs its own go-ahead.

1. **Record the decision:** this ADR and the documents it changes.
2. **Prove the path in the game:** export today's bridge to USDZ and have the game load it instead of drawing boxes. The opening frame should look the same, the lights still come from data, and Restart is unchanged. It is checked in the Simulator, with a phone check before merging.
3. **Make the Blender file the source:**
   - commit `blender/levels/brooklyn-bridge.blend` with its four collections;
   - turn Save into Export;
   - retire Load, the Swift reader, safe Save, the working file and the palette file;
   - add the freshness check.

   Before this step commits the first Blender file, the maintainer checks the account's Git LFS allowance, as CONTRIBUTING asks, and `.gitattributes` marks `.blend` files lockable. This step may still adjust folder and file names.
4. **Models and provided files:** `blender/assets` with linked models, the intake check and provenance notes. Things the code spawns, such as characters, get USDZ files of their own.
5. **Art and richer light:** models, textures, point and spot lights, and baked lighting, once the visual direction's limits change and a task asks for them.

## Checks

- The test export ran Blender 5.3 in the background on a copy of the working file, with no other add-ons. It used Blender's USD exporter with materials, preview surfaces, lights, cameras and custom properties, converted to a y-up scene. A small Swift program loaded the results with RealityKit's `Entity(contentsOf:)` on macOS 27 and listed their entities, materials, lights and cameras.
- Not checked yet:
  - the result on iOS, in the Simulator or on the phone;
  - a file provided from elsewhere;
  - armatures and animation;
  - normal, roughness and metallic maps;
  - how long the scene takes to load on the phone.

## Step 2 — the path into the game

**Date:** 19 November 2026. The maintainer assigned it (**“go ahead”**) after this ADR's merge and, after the phone check, [authorised the merge](https://github.com/RonildoBraga/lauder/pull/52#issuecomment-7000152015) (**“Yes, merge it”**) without an independent review.

1. **The scene file.** `apple/sources/content/BrooklynBridge.usdz` holds everything the game shows of the bridge, as its code drew it:
   - the deck and the boxes;
   - each vehicle's body and windows, inside its box;
   - the landmarks with their bands;
   - the pieces, turned.

   Blender builds them from the layout file and the palette and exports them with its own USD exporter, on the game's axes, one prim per block, with the surfaces as single-sided preview-surface materials. The file holds no lights, camera, areas, markers or stand-ins. It is 14 KB, stored with Git LFS.
2. **The game loads it.** `GameWorld` loads the scene file synchronously while it is made, in place of drawing the bridge, so start-up gains no asynchronous step, and Restart keeps it. The lights still come from the layout file. A level without a scene file, such as a test's, is still drawn from its boxes and pieces.
3. **It stays up to date.** Until step 3, the Swift files remain the source.
   - Saving in Blender, with **Save** or ⌘S, exports the scene file whenever the layout file or the palette changed since the last export. The export runs in a Blender of its own, in the background.
   - Play does the same before it builds.
   - `blender/scripts/export-scene.py` exports it by hand, after the files are edited outside Blender.
   - `blender/scene-exports.json` records the fingerprints of both files and of the scene file. `./scripts/check` fails when any of them no longer matches.

### Checks of step 2

- `./scripts/check` passes: the extension's 48 tests, Swift formatting, the build, and the Swift tests on the iPhone 17 / iOS 27 Simulator. The new and changed tests cover:
  - the scene file holding what the game drew, with names safe for USD, and refusing names that would clash;
  - the bridge's scene file matching its layout file and the palette, and going stale when either changes;
  - Save and Play exporting only a stale scene file, an export already running or waiting standing in for a new one, and a scene file left stale by a later save being exported again;
  - in the game, the ground, every box, vehicle, landmark and piece standing where the layout file puts them, with no part of the scene taking part in physics.
- In Blender 5.3, run in the background on copies of the files:
  - moving `car-a1` and saving wrote the layout file and started the export, which made the scene file current again, and a save without edits exported nothing;
  - Play pressed after a save queued only its build behind that save's export, and a save made after an export had read the files got an export of its own. Both ended with the scene file current.
- In the Simulator, the opening frame looks the same as `main`'s. Of its 3.2 million pixels, 24.6% differ: all but 123 of them by one step in 255, and only 36 by more than 8. Two runs of `main` give the same frame, pixel for pixel.
- Codex's and Copilot's automatic reviews found the same two problems in the background exports: Play after a save started a second export beside the save's, and a save made during an export was dropped. Both were fixed before the merge.
- On the baseline iPhone 13 Pro Max, a directly installed Release build of `110617b` held **59.92 fps** over 103 s after the first 15 s of a two-minute recording of the maintainer's play, with frames averaging 16.69 ms. Four frames ran long, one of 50 ms and three of 33 ms, about 80, 81, 88 and 118 s in; as with M4's, their cause is unknown. None was skipped, and the thermal state stayed Nominal. A first attempt stopped after a second, when the phone's connection dropped. The next commit changed only the Blender extension.
- Not checked: how long the scene file takes to load at start-up, which happens before the first frame; and the Lauder tab's buttons in the maintainer's own Blender, whose functions the background runs called.

## Step 3 — the Blender file as the source

**Date:** 19 November 2026. The maintainer assigned it (**“Yes, start step 3”**).

1. **The level file.** `blender/levels/brooklyn-bridge.blend`, stored with Git LFS, is the bridge's source. The step 2 extension's Load made it once from the Swift files it replaces, and it was then sorted into five collections:
   - **Visual**, 172 parts: each box's look, as a block parented to its gameplay box; each vehicle's body and windows; each landmark's block and band; and the 111 decoration pieces.
   - **Gameplay**, 56 objects, each with a `lauder_role`: the ground, 34 boxes, 3 landmarks, 10 areas and 8 markers, shown as outlines. A mesh without a role counts as a box, and an empty as a marker.
   - **Lights**, the two suns, and **Camera**, the game camera's rig.
   - **Preview**, the party's stand-ins at their start markers. It is never exported.
2. **Export reads the saved file.** Saving the level file in Blender checks the game's rules there, then exports in a background Blender with `blender/scripts/export-level.py`; Play does the same before it builds.
   - The layout file is generated now, and says so at its top.
   - The scene file comes from the Visual collection, each part placed where it stands in the world.
   - `blender/level-exports.json` records the fingerprints of the Blender file, of any file it uses, and of both exports. `./scripts/check` fails when any of them no longer matches.
3. **Names the story uses stay.** Export refuses to drop a layout entry whose name the level's Swift file quotes, since the game would stop at the missing name.
4. **No local paths.** A Blender file keeps the folder each file browser last showed, such as the home folder, in its saved interface. Saving a level file points them at the level's own folder first, so a level file in the public repository holds no paths from the computer it was saved on. The bridge's file holds none.
5. **What retired:**
   - Load and the Swift reader, the safe Save and Save Anyway, and the working file in `.local/blender`;
   - the palette file, `Surfaces.swift`, and the boxes' surfaces;
   - the decoration's entries in the layout file, and the game's code that drew it: `SceneDressing`, and the vehicles' and landmarks' looks in `SceneStyle`.

   A level without a scene file, such as a test's, is drawn as plain blocks. The extension shrank from 2,276 lines to 1,143.
6. **Not done: Git LFS locking.** Decision 1 has Git LFS lock a Blender file while someone edits it. Everyone editing levels so far, the maintainer and the agents, pushes as the maintainer's account, and a lock stops only other accounts. It would protect nothing yet, while making the files read-only until locked, so it waits for a second person to edit levels.

### Checks of step 3

- The layout file exported from the new Blender file holds the same 58 entries as the hand-kept one it replaces. Every box, landmark, area and marker keeps its position and size, the camera is the same, and so are the lights, apart from one direction that rounding moved by 0.02°.
- `./scripts/check` passes: the extension's 26 tests, Swift formatting, the build, and the Swift tests on the iPhone 17 / iOS 27 Simulator. The tests cover:
  - the layout file's rules and form, and the names the story uses;
  - the export record going stale when the Blender file changes, or when an export is edited by hand or goes missing;
  - in the game, each box's look filling its box while the bridge is a greybox, each vehicle inside its box, and the decoration in the scene file alone.
- In Blender 5.3, run in the background on a copy:
  - Open Level opened the level file;
  - saving after moving `car-a1` exported the level, and the layout file showed the move;
  - a box turned at an angle was refused at save, and nothing was exported;
  - Play queued behind the save's export;
  - a level file saved after its file browser had gone to the home folder held no local path.
- In the Simulator, the opening frame looks the same as `main`'s, whose scene file step 2 exported from the Swift files: of its 3.2 million pixels, 4,012 differ (0.13%), only 10 of them by more than 8 steps in 255. Two runs of `main` give the same frame, pixel for pixel.
- Not checked: the Lauder tab's buttons in the maintainer's own Blender, whose functions the background runs called; and the phone, since nothing the game shows or plays changed.
