# ADR 0006 — Blender as the source of levels and models

**Status:** Accepted by the maintainer on 19 November 2026 (**“Yes, record it”**) and [merged](https://github.com/RonildoBraga/lauder/pull/51#issuecomment-6999540584) under the maintainer's standing permission (“you dont need for my reviews, you can always merge it”), without an independent review. Steps [2](#step-2--the-path-into-the-game), [3](#step-3--the-blender-file-as-the-source) and [4](#step-4--models-and-files-from-elsewhere) are built: each level's Blender file is its source, levels link models from `blender/assets`, and [ADR 0005](0005-blender-level-editor.md)'s round trip has ended. [Step 5](#step-5--art-and-richer-light) is built, apart from its phone check.\
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
   - the gameplay signals and future effects, and the stand-ins until [step 5c](#5c--models-the-code-spawns) made them models;
   - loading the level's scene once at start, which Restart keeps.
7. **Files the maintainer provides go through an intake check** before use. It reports on units and scale, axes, names, materials and textures, and size budgets. Each file keeps a note of its source and licence, as [CONTRIBUTING](../../CONTRIBUTING.md#assets-and-attribution) requires.
8. **The contract between Blender and the game:**
   - names are lowercase, unique and stable, and the exporter maps them predictably to USD's;
   - lengths are in metres, on the game's axes;
   - materials use Principled BSDF with image textures, and anything else is baked into images first. Step 5 checked which inputs images reach in the game, and which settings the scene file leaves out;
   - lights keep the [visual direction](../visual-direction.md#rendering-budget)'s budget, at most two with one casting shadows, at 1 W/m² of sun for every 700 lux, as ADR 0005 set. Step 5 raised the budget to four and added point and spot lights.

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
- The game stops drawing the level's look. `SceneStyle` keeps the stand-ins, the gameplay signals and the lights. Step 5c later moved the stand-ins into models.
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

**Date:** 19 November 2026. The maintainer assigned it (**“Yes, start step 3”**) and, asked whether the level file could go into Git LFS, answered **“Yes, push it”**. It was [merged](https://github.com/RonildoBraga/lauder/pull/53#issuecomment-7000891999) under the standing permission, without an independent review.

1. **The level file.** `blender/levels/brooklyn-bridge.blend`, stored with Git LFS, is the bridge's source. The step 2 extension's Load made it once from the Swift files it replaces, and it was then sorted into five collections:
   - **Visual**, 172 parts: each box's look, as a block parented to its gameplay box; each vehicle's body and windows; each landmark's block and band; and the 111 decoration pieces.
   - **Gameplay**, 56 objects, each with a `lauder_role`: the ground, 34 boxes, 3 landmarks, 10 areas and 8 markers, shown as outlines. A mesh without a role counts as a box, and an empty as a marker.
   - **Lights**, the two suns, and **Camera**, the game camera's rig.
   - **Preview**, the party's stand-ins at their start markers. It is never exported.
2. **Export reads the saved file.** Saving the level file in Blender checks the game's rules there, then exports in a background Blender with `blender/scripts/export-level.py`; Play does the same before it builds.
   - The layout file is generated now, and says so at its top.
   - The scene file comes from the Visual collection, each part placed where it stands in the world.
   - Both exports are written only once both are ready, so a refusal leaves the pair as it was.
   - `blender/level-exports.json` records the fingerprints of the Blender file as it was read, of any file it uses, and of both exports. `./scripts/check` fails when any of them no longer matches.
3. **Names the story uses stay.** Export refuses to drop a layout entry whose name the level's Swift file quotes, since the game would stop at the missing name. Without the layout file it cannot tell which names those are, so it refuses and says how to restore the file.
4. **No local paths.** A Blender file keeps the folder each file browser last showed, such as the home folder, in its saved interface. Saving a level file points them at the level's own folder first, and drops the Repository folder that the Lauder tab stores, since an open level file finds its repository from where it is. A level file in the public repository holds no paths from the computer it was saved on, and the bridge's file holds none. Step 4 found this incomplete: the [tail of a home folder's path](#step-4--models-and-files-from-elsewhere) stayed behind the new folder.
5. **What retired:**
   - Load and the Swift reader, the safe Save and Save Anyway, and the working file in `.local/blender`;
   - the palette file, `Surfaces.swift`, and the boxes' surfaces;
   - the decoration's entries in the layout file, and the game's code that drew it: `SceneDressing`, and the vehicles' and landmarks' looks in `SceneStyle`.

   A level without a scene file, such as a test's, is drawn as plain blocks. The extension shrank from 2,276 lines to 1,143.
6. **Not done: Git LFS locking.** Decision 1 has Git LFS lock a Blender file while someone edits it. Everyone editing levels so far, the maintainer and the agents, pushes as the maintainer's account, and a lock stops only other accounts. It would protect nothing yet, while making the files read-only until locked, so it waits for a second person to edit levels.

### Checks of step 3

- The layout file exported from the new Blender file holds the same 58 entries as the hand-kept one it replaces. Every box, landmark, area and marker keeps its position and size, the camera is the same, and so are the lights, apart from one direction that rounding moved by 0.02°.
- `./scripts/check` passes: the extension's 27 tests, Swift formatting, the build, and the Swift tests on the iPhone 17 / iOS 27 Simulator. The tests cover:
  - the layout file's rules and form, and the names the story uses, which Export cannot tell without the layout file;
  - the export record going stale when the Blender file changes, or when an export is edited by hand or goes missing;
  - in the game, each box's look filling its box while the bridge is a greybox, each vehicle inside its box, and the decoration in the scene file alone.
- In Blender 5.3, run in the background on a copy:
  - Open Level opened the level file;
  - saving after moving `car-a1` exported the level, and the layout file showed the move;
  - a box turned at an angle was refused at save, and nothing was exported;
  - Play queued behind the save's export;
  - a level file saved with its file browser in the home folder, and a Repository folder chosen in the Lauder tab, held no local path;
  - an export refused because the Visual collection was gone left both exports as they were.
- In the Simulator, the opening frame looks the same as `main`'s, whose scene file step 2 exported from the Swift files: of its 3.2 million pixels, 4,012 differ (0.13%), only 10 of them by more than 8 steps in 255. Two runs of `main` give the same frame, pixel for pixel.
- Codex's and Copilot's automatic reviews found four problems, all fixed before the merge:
  - a save landing between the export loading the level file and fingerprinting it;
  - a story-name check that a missing layout file turned off;
  - a Repository path stored in the level file;
  - a layout file written before an export was refused.
- Not checked: the Lauder tab's buttons in the maintainer's own Blender, whose functions the background runs called; and the phone, since nothing the game shows or plays changed.

## Step 4 — models and files from elsewhere

**Date:** 19 November 2026. The maintainer assigned it (**“Start step 4”**). It was [merged](https://github.com/RonildoBraga/lauder/pull/54#issuecomment-7003938273) under the standing permission, without an independent review.

1. **The models.** Each model is a Blender file of its own, `blender/assets/<model>/<model>.blend`, stored with Git LFS. Beside it are a `README.md` with its source and licence, and any textures it uses. One collection, named after the model, holds it, at its real size in metres and standing on the ground at its origin. [The library's README](../../blender/assets/README.md) sets out the rest of the contract. The first three models, `car`, `van` and `truck`, are the bridge's greybox vehicles. Each was made from its parts in the level file: their meshes, moved to the model's origin, and copies of their materials, renamed after the model, such as `car paint`.
2. **Levels link them.** A model appears in a level as an instance of its collection, in Visual and parented to its gameplay box, so that moving the box moves it. The bridge's 20 vehicles are copies of the three models now, in place of 40 parts of their own. `car-b4`, a 4 m car turned across the lanes, is the car turned and shortened to fill its box. The Lauder tab's **Add Model** places a model on the selected box, turned along the box's longer side, or at the 3D cursor. **Open Model** opens the selected model's file.
3. **Export carries them.** The scene file holds each instance as real meshes, under one entity named after the instance, such as `car_a1_model`. USD's instancing stays off: in a test, RealityKit shared each part's mesh among a model's copies either way, and instancing only added an entity to each part. Export leaves nothing but Visual in the scene, so a model linked straight into another collection stays out of the scene file. The export record lists every model and texture that the level uses. Each is fingerprinted before Blender reads it, so a save that lands during an export leaves the export stale, never current. Saving a model exports each level whose last export used it.
4. **Export checks what the game would show.** Besides the layout's rules, it refuses:
   - a linked file that is not a model in `blender/assets`, or a model that is missing or not downloaded;
   - a material whose surface is not a Principled BSDF, or that is made with other nodes than image textures, UV maps, Separate Color and Normal Map nodes, and Math nodes for Alpha. Blender's USD export cannot carry the rest, so Game Look and the game would differ. [Step 5b](#5b--texture-maps) later refused Separate Color too;
   - two materials, or two objects in Visual, whose names USD would make the same. A test showed why: when the car's and the van's materials were both named “Lauder vehicle”, Blender's USD export wrote one material for both, and the car lost its texture;
   - a texture that is packed into a Blender file, missing or not downloaded, outside the repository, not a PNG or JPEG, or over 1 MiB without the Git LFS rule that the repository's policy asks for;
   - a model in Gameplay.
5. **The intake check.** `blender/scripts/check-model.py`, or **Check Model** in the Lauder tab, lists what a model must change before a level can use it:
   - its collection, metric units, and any lights or cameras;
   - the material and texture rules, with its textures in its own folder;
   - names that USD would make the same;
   - its README's source and licence.

   It then notes what is worth a look:
   - its size, and a lowest point off the ground or a middle away from its origin;
   - more than 10,000 triangles;
   - textures, which the visual direction does not allow yet, and any over 2048 pixels on a side;
   - parts hidden from renders, and Blender's duplicate suffixes.

   Both budgets are starting points, until the phone measures real ones.
6. **Files from elsewhere.** `blender/scripts/add-model.py` makes a model's folder from a Blender, glTF, FBX, OBJ or USD file, and refuses to overwrite one:
   - the model's Blender file holds what the file shows, in the model's collection: for a Blender file, what its first scene shows, without collections excluded from it. Lights, cameras and empty helpers stay out, and each instance of a collection becomes copies of its parts where it stands, sharing their meshes;
   - each texture it uses is copied into `textures/`, unpacked if need be;
   - its `README.md` leaves the Source and Licence lines to fill in.

   It then runs the intake check. `./scripts/check` fails while a model lacks its Blender file, or a README naming its source and licence.
7. **Paths are overwritten in full.** Blender keeps each path in a buffer of fixed size and saves the bytes beyond the path's end, so a shorter path written over a longer one keeps the longer one's tail. Step 3's reset of the file browsers left such a tail in the level file it committed: `//`, then the end of a folder path that names the account. The same happens when Blender makes a linked model's or texture's path relative, and when it records where appended data came from. Saving a level or model file now overwrites each of these in full. That covers the file browsers' folders and file names, the paths of linked models and textures, and the source paths of appended data. The bridge's file and the models hold no part of a local path, and `./scripts/check` searches every committed Blender file for one. The level file that step 3 committed keeps its fragment in the repository's history.
8. **Not done: USDZ files for things the code spawns.** The plan gives characters and other things the game spawns USDZ files of their own. Nothing the game spawns uses a model yet: under decision 6 the code draws the party's stand-ins, and the stage 1 mannequin is a test fixture with a generator of its own. That export arrives with the first such model, when a task asks for one. [Step 5c](#5c--models-the-code-spawns) brought it, with the stand-ins as the first such models.
9. **Also not done:**
   - Git LFS locking, for the reason step 3 gives;
   - a library of shared materials: each model keeps its own, so the scene file has 14 materials where it had 10, six of them the vehicles' instead of two.

### Checks of step 4

- The layout file exported after the change is the one before it, byte for byte: no box moved.
- RealityKit on macOS loaded `main`'s scene file and the new one. All 172 parts stand where they stood, with the same colours, to the centimetre. In the new file, the vehicles' 40 parts share 6 meshes.
- In the Simulator, the opening frame, which shows part of one vehicle, looks the same as `main`'s. Of its 3.2 million pixels, 2 differ, by 2 steps in 255. Two runs of `main` give the same frame, pixel for pixel.
- `./scripts/check` passes: the extension's 41 tests, Swift formatting, the build, and the Swift tests on the iPhone 17 / iOS 27 Simulator. The new and changed tests cover:
  - names as USD writes them, and the materials, textures and names that Export refuses;
  - every committed Blender file holding no part of a local path, a test that the level file step 3 committed fails;
  - the intake check's problems and notes, and a README's source and licence;
  - every model in the repository having its file and provenance;
  - the export record going stale when a model changes or goes missing;
  - a model's save exporting the levels that used it, and each level's export standing in only for its own;
  - in the game, each vehicle's model filling its box.
- In Blender 5.3, run in the background on a copy of the repository:
  - Add Model placed the van on a box longer across than along, turned a quarter, on the deck and parented to the box. Moving the box moved it, and without a box the model stood at the cursor;
  - Open Model opened the car's file, and Check Model found it ready;
  - saving the car with a new paint colour exported the bridge, and the scene file showed the colour;
  - Export refused, and said why, for: a model in Gameplay; the van's paint renamed `car-paint`; the truck's glass made with an Emission shader; a packed texture; the truck's file missing, and as a Git LFS pointer; the van linked by its full path, which saving the level then made relative; and the truck's collection renamed, refused as soon as the truck was saved;
  - a texture in the car's folder reached the export record and the USDZ, and one that was still a Git LFS pointer failed the intake check;
  - the car linked straight into the scene, outside Visual, stayed out of the scene file, which kept its 20 vehicles;
  - add-model brought in one small model from each of a Blender, glTF, FBX, OBJ and USDZ file, with its texture copied. The intake check then asked only for the README's source and licence;
  - from a Blender file with two instances of a part from an excluded collection, beside an excluded reference and a light, add-model brought in two copies of the part, where the instances stood, and nothing else. Codex's review had found that the first version lost the instances;
  - no saved model or level file held any part of a local path, searched for in the decompressed files: the account's folder, the folders above the repository, and the scratch folders, including where a model brought in from a Blender file came from.
- Codex's and Copilot's automatic reviews found four problems, all fixed before the merge:
  - add-model lost a Blender file's collection instances, which both reviews found;
  - a file that a level came to use between export's two reads could be fingerprinted after it was read;
  - a model linked straight into a collection outside Visual reached the scene file;
  - a texture still a Git LFS pointer passed the intake check.
- Not checked:
  - the Lauder tab's new buttons in the maintainer's own Blender, whose functions the background runs called;
  - files made outside Blender, rather than exported from it;
  - normal, roughness and metallic maps;
  - the phone, since the game shows and plays the same.

## Step 5 — art and richer light

**Date:** 19 November 2026. The maintainer assigned it: **“proceed with the next step”** and **“lets focus in finisging that pipeline”**. Asked which parts to build, they chose all four: **“Point and spot lights”**, **“Full texture maps”**, **“Models the code spawns”** and **“Baked lighting”**. Asked how many lights the visual direction should allow, they chose **“Up to 4, 1 shadowed”**. Each part is a pull request of its own.

### 5a — point and spot lights

It was [merged](https://github.com/RonildoBraga/lauder/pull/56#issuecomment-7006540355) under the standing permission, without an independent review.

1. **The budget is four lights.** At most one may cast shadows, as before. The [visual direction](../visual-direction.md#rendering-budget) and the export's check say so.
2. **Point and spot lights travel as data,** like the suns, since RealityKit drops a spot light's cone from USD. The layout file holds, for each:
   - its place, colour and intensity, in lumens: 683 lm for each watt in Blender, the luminous efficacy that defines the candela;
   - its reach, which is Blender's Custom Distance;
   - for a spot light, the point it shines towards and its cone. The cone's outer width is Blender's spot size, and its full-strength width comes from the spot blend, as Blender fades it. Both are full widths, as RealityKit's spot angles are.
3. **The game makes RealityKit's own lights:** a `PointLight` and a `SpotLight` beside each sun's `DirectionalLight`. A spot light may cast the level's one shadow.
4. **Export refuses** a point light with its shadow on, since the game draws no shadows from point lights: RealityKit's point light component offers none, though a newer shadow component has not been tried. It also refuses a point or spot light without Custom Distance, which Blender's preview would then show reaching further than the game, area lights, more than four lights, and more than one light casting shadows. Blender's Exposure multiplies a light's strength in the layout file, as it does in the preview. Export refuses a light whose colour comes from Temperature, or with Normalize off, which makes it brighter as it grows: the game reads neither.
5. **The bridge keeps its two suns.** Under its 4,500 lux sun, a 30 W lamp adds about 180 lux three metres below it, so point and spot lights show only when very strong, in Blender's preview as in the game.

### Checks of 5a

- The extension's 43 tests cover the layout file's point and spot lights, their cones, Exposure, and each refusal. The Swift tests check that the game builds a point light where the layout puts it, with its intensity and reach, and a spot light aimed at its target with its cone and shadow.
- In Blender 5.3, run in the background on a copy of the repository, a point light and a spot light added beside the two suns were exported as written. A new point light with Blender's default shadow, a spot light without Custom Distance and a spot light's shadow beside the sun's were each refused, saying why.
- In the Simulator, a 30 W lamp beside Miki's start showed nothing in daylight, as Blender's preview predicts. At 3,000 W, its warm light lay on the road where the layout put it.
- RealityKit's spot angles are full cone widths. Rendered offscreen on the Mac with RealityKit, a spot light 10 m above a white plane, with angles of 58° and 60°, lit a circle of 5.7 m radius: 10 tan 30° is 5.77 m, while a 60° angle from the beam would light 17.3 m.
- Not checked: how the lights look and perform on the phone, and RealityKit's spot falloff between the cone's two widths, which may differ from Blender's.

### 5b — texture maps

It was [merged](https://github.com/RonildoBraga/lauder/pull/57#issuecomment-7007123450) under the standing permission, without an independent review.

1. **Six inputs take images.** Each was tried from Blender's USD export into RealityKit, on the Mac and in the iOS Simulator, and arrived where Blender uses it:
   - **Base Color** and **Emission Color**, from an image's colour;
   - **Roughness** and **Metallic**, from a greyscale image's colour or from an image's alpha;
   - **Normal**, through a Normal Map node;
   - **Alpha**, from an image's alpha or a greyscale mask, either blended or cut off at one half through a Math node.
2. **Export and the intake check refuse what the game would show differently:**
   - Separate Color, since RealityKit drops a map read from an image's green or blue channel: each map packed into one image needs an image of its own;
   - a Normal Map Strength other than 1 or fed by nodes, and an Emission Strength other than 1 on an emission image. Blender's USD export leaves both out, so the game would show the normal map at full strength, and the emission image at strength 1 even where Blender shows no glow;
   - images or other nodes on any other input, until each is checked.
3. **Ambient occlusion has no way in yet:** the Principled BSDF has no input for it, and Blender's USD export writes none.
4. **The bridge's materials are plain colours,** so its exports do not change. The [visual direction](../visual-direction.md) still allows no new textures; this step readies the pipeline for them.

### Checks of 5b

- In Blender 5.3, test cubes held each map: an image each for base colour, roughness, metallic, normal and emission; roughness and metallic packed into one image's green and blue; alpha blended, cut off and from a mask; a striped normal map at Strength 1 and 0.25; and an emission image at Emission Strength 4. They were exported with the level export's USD settings.
- RealityKit loaded them on macOS 27 and in the iOS 27 Simulator with the same result. Every map reached its place in RealityKit's physically based material, except roughness and metallic from green and blue, which were dropped. The scene file held neither the Normal Map Strength nor the emission image's Emission Strength. A plain emission colour arrived multiplied by its strength, as Blender shows it.
- Rendered offscreen with RealityKit on the Mac, under one sun:
  - the striped normal map looked the same at both strengths, and the emission image at strength 4 looked as at 1;
  - checkerboard alpha showed the backdrop through its holes, soft-edged when blended and sharp when cut off;
  - metallic from an image's alpha followed the checkerboard held in the alpha, not the image's even red.
- In Blender 5.3, run in the background on a copy of the repository, export refused each cube added to the bridge's Visual collection, saying why: Separate Color on Roughness, a Normal Map Strength of 0.25 and one fed by an image, an emission image at Blender's default Emission Strength of 0, and an image on Coat Weight. A cube with every checked map was exported, and the scene file carried its five images.
- The extension's 44 tests cover each refusal.
- Not checked: the phone, texture memory and compression, Image Texture settings such as interpolation and extension, and normal maps baked in object space.

### 5c — models the code spawns

It was [merged](https://github.com/RonildoBraga/lauder/pull/58#issuecomment-7007658513) under the standing permission, without an independent review.

The maintainer's choice reversed decision 6's rule that the code keeps the stand-ins: **“Models the code spawns”**, described as models that the game creates at runtime getting USDZ files of their own, with the stand-ins becoming the first, with the same look.

1. **The stand-ins are models.** `miki`, `tom` and `laura` are the party's, and `hostile` is every hostile's. Each was made from the sizes and colours that `SceneStyle` drew its stand-in with: a body, a head, two legs and two feet, and a front mark that glows, as the code drew it unlit. As the models' contract asks, each stands on the ground at its origin with its front towards −y, so the game turns it half a turn to face its −z.
2. **Each model the game creates gets a scene file of its own,** `apple/sources/content/models/<model>.usdz`. The extension's `SPAWNED` list names these models. Saving such a model exports its scene file in the background, with `blender/scripts/export-model.py`, once the intake check finds nothing to fix. Play exports any that no longer match. Models that only levels show, such as the vehicles, get none.
3. **The export record covers them,** under `models/<model>`: the model's Blender file and its textures, and its scene file. `./scripts/check` fails when any no longer matches.
4. **The game loads each model once,** with `Entity.load(named:in:)` as for the level's scene, and gives every figure a copy. The carbine, the markers, the aim lines and the tracers stay in code, as the gameplay signals.
5. **The bridge's Preview shows the party's models,** linked at their start markers in place of the plain meshes that copied the stand-ins. Export leaves out Preview and the files only Preview uses, so the bridge's export is not made from the party's models, and saving one does not export the bridge again.

### Checks of 5c

- The intake check found nothing to fix in the four models, and each was exported.
- Rendered offscreen with RealityKit on the Mac, under the bridge's two suns, the code's stand-in and the model for Miki and for the hostile looked the same, facing ahead and turned by 135°: 86 of 230,400 pixels differed by more than 8 levels.
- In the iOS 27 Simulator, the opening frame differs from `main`'s in 40 of 3.2 million pixels, all within 38 pixels of Miki's head, where Blender's sphere has other facets than RealityKit's.
- The bridge's scene file, exported again, holds the same 118 prims with the same content as before. Its layout file is unchanged.
- In Blender 5.3, run in the background on a copy of the repository: saving a changed Miki through the extension exported her scene file and left the bridge's exports current. The bridge opened with the three models in Preview, passed its check and exported, made from its own file and the vehicles. Saving the car exported nothing of its own.
- The extension's 46 tests cover the export record of these models, their freshness, and Play's and saving's background steps. A Swift test checks that each member of the party and a hostile shows its model, standing on the ground, 1.58 m tall and facing ahead.
- Not checked: the phone.

### 5d — baked occlusion

The maintainer chose **“Baked lighting”**, described as baking light into textures in Blender for the scene file. A trial found two limits. The game's RealityView adds RealityKit's built-in sky light, which neither Blender nor an offscreen RealityKit render can reproduce. And a fully baked surface, shown through emission, stops showing live shadows, such as Miki's on the road. Asked how to go on, the maintainer chose **“Bake occlusion”**: Blender bakes soft ambient occlusion into each chosen part's colour image, and the game's suns, sky light and shadows still light it.

1. **Bake Occlusion,** in the Lauder tab, bakes the selected parts of Visual and every part already baked.
   - Cycles bakes each part's colour and its ambient occlusion, within 1.5 m, through a UV map of the part's own, `baked`, made with Smart UV Project.
   - It multiplies them into a PNG in `blender/levels/baked/<level>/`.
   - The part then shows a copy of its material, `<part> baked`, with that image as Base Color.
   - Its earlier materials and UV map stay in the file. **Clear Occlusion** gives them back and removes the image.
2. **What bakes:** a part of the level's own with one material, a Principled BSDF fed by nodes only at Base Color, since the game reads one UV map, the baked colour's. Other parts are refused, saying why, and linked models are not baked in a level. A part's image grows with its size, at 8 texels a metre, as a power of two from 64 to 1,024 pixels on a side. A long part, such as the bridge's 644 m deck, gets coarse texels along its length, and is better split first.
3. **The game needs no change:** a baked part shows an ordinary material with an image on Base Color, which step 5b checked. Occlusion darkens the part under every light, not only the sky light, as a colour image must.
4. **The bridge bakes nothing,** since the [visual direction](../visual-direction.md) allows no new textures yet.

### Checks of 5d

- The trial of a full bake:
  - Blender's diffuse bake holds the light leaving a surface: 0.79 against 0.82 predicted, for a grey plane under the bridge's sun-key.
  - Rendered offscreen with RealityKit, emission showed 11% brighter than a rough plane lit live with the same light, by the same factor under 1,500 and 4,500 lux.
  - In the Simulator, the toll booth, fully baked, came out darker and warmer than when lit live. An offscreen render of the live bridge, without image-based light, was darker than the game throughout: the game has a sky light that the bake lacked.
- In Blender 5.3, run in the background on a copy of the repository:
  - Bake Occlusion baked the booth, its band, the barricade, the deck and a railing, in a run of about 13 seconds with the export, into images of 2 to 95 KB;
  - the level passed its check and exported with the five images, and pressing it again kept all five baked;
  - Clear Occlusion gave the barricade back its material, and removed its baked UV map and its image;
  - a cube coloured by an image kept that image's colours where nothing shades it, and a cube with an image on Roughness was refused, leaving everything unbaked.
- In the iOS 27 Simulator, with those five parts baked, the opening frame changed in 6.8% of its pixels, every one darker. Miki's live shadow stayed on the road.
- The extension's 49 tests cover the images' sizes and names, and which parts can bake.
- Not checked: the phone, and how baked images weigh on its memory.
