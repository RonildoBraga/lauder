# ADR 0002 — Blender as the source of levels and models

**Status:** Accepted\
**Date:** 19 November 2026

## Context

Blender is the single source of truth for the game's environments, levels, models and lighting. Levels and models are made and changed in Blender, by people or by agents through Blender's MCP server, and files made elsewhere can be brought in. The game should show what Blender shows, the export should be automatic, and nothing should be kept in two places.

The game is Swift and RealityKit ([ADR 0001](0001-engine.md)), and RealityKit reads USD, which Blender exports. In RealityKit, positions, meshes, materials and image textures arrive as Blender holds them, and names change in a predictable way. RealityKit ignores suns, drops a spot light's cone and offers no way to read Blender's custom properties. So the look can travel as USD, but lights and what plays have to travel another way.

## Decision

1. **Blender files are the source.** Each level is a Blender file, `blender/levels/<level>.blend`, and each model is one of its own, `blender/assets/<model>/<model>.blend`, both stored with Git LFS. Nobody edits what is made from them by hand: every change starts in Blender.
2. **One export, two files.** Exporting a level writes:
   - its **scene file**, a USDZ of everything the player sees, which the game loads at start;
   - its **layout file**, typed Swift for what plays: the ground, the boxes that block movement and sight, landmarks, trigger and fight areas, markers, the game camera and the lights. The game compiles it, with no parser.
3. **Collections decide where objects go.** A level's file has:
   - **Visual**, written to the scene file;
   - **Gameplay**, **Lights** and **Camera**, written to the layout file. Gameplay objects show in Blender as outlines and the game never draws them, so a vehicle is its model in Visual and its box in Gameplay;
   - **Preview**, the party's models at their start markers, which is never exported. The files only Preview uses do not count among those an export is made from.
4. **Export checks the game's rules first,** and writes nothing when one fails. It runs in a Blender of its own, in the background, when a level's file is saved and before Play, and from `blender/scripts/export-level.py`, which agents run too.
5. **The exports are committed,** so the app builds without Blender. `blender/level-exports.json` records each export's fingerprints: of the files it was made from, the level's Blender file, the models it links and their textures, and of the files it wrote. `./scripts/check` fails when any of them no longer matches.
6. **Levels link models.** A level shows a model as an instance of the model's collection, so a change to the model reaches every level that uses it, and saving a model exports each level whose last export used it. The models that the game creates itself while it plays, the party and the hostiles, get scene files of their own in `apple/sources/content/models`, written when the model is saved, which the game loads by the model's name.
7. **Files from elsewhere go through the intake check.** It reports on units, axes, names, materials, textures and size budgets. `blender/scripts/add-model.py` makes a model's folder from a Blender, glTF, FBX, OBJ or USD file, and every model keeps a README with its source and licence.
8. **The contract between Blender and the game:**
   - names become USD's predictably, and two names that USD would make the same are refused;
   - lengths are in metres. Blender's z is up, so a game point (x, y, z) sits at (x, -z, y);
   - materials use a Principled BSDF. Images reach the game on Base Color, Roughness, Metallic, Normal through a Normal Map node, Emission Color and Alpha, with an image of its own for each map. A Normal Map's Strength, and an emission image's Emission Strength, stay at 1, since the scene file leaves both out. Anything else is baked into an image first;
   - textures are PNG or JPEG files in the repository, never packed into a Blender file;
   - lights travel as data in the layout file: suns, and point and spot lights with Custom Distance, within the [visual direction](../visual-direction.md#rendering-budget)'s budget of four lights, one casting shadows. Blender's Exposure carries over; a light coloured by Temperature, or with Normalize off, is refused;
   - a part can bake ambient occlusion into its colour, as an image of its own, and the game's lights still light it.
9. **The game's code keeps the behaviour:** the story and its words, interactions, fights and AI; movement and navigation, which use Blender's blockers; how light renders, with RealityKit's lights, shadows and image-based light; the camera's behaviour; the gameplay signals; and loading the scene files once at start, which Restart keeps.
10. **Saved files keep no local paths.** Saving a level or a model overwrites in full the paths that Blender keeps, which would otherwise hold the tails of longer ones, and `./scripts/check` searches the committed Blender files for any part of a local path.

The Lauder extension in `blender/extensions/lauder_levels` holds the checks, the export and the Lauder tab, in a module for each job. Its tests run in `./scripts/check` without Blender.

## What the scene file carries

| | In RealityKit |
|---|---|
| Positions, meshes and scale | As Blender holds them, in metres on the game's axes |
| Principled BSDF materials | As physically based materials |
| Base colour, roughness, metallic, normal, emissive and alpha maps | Kept, alpha blended or cut off at one half |
| Maps read from an image's green or blue channel | Dropped, so export refuses them |
| Normal Map Strength, an emission image's Emission Strength | Left out, so export refuses any but 1 |
| Suns and a spot light's cone | Dropped, so lights travel as data |
| Custom properties | Unreadable, so what plays travels as data |
| The game's built-in sky light | Not reproducible in a bake, so parts bake occlusion, not light |

Spot angles are full cone widths in Blender and in RealityKit alike. Blender's USD export writes a scene file's prims in a different order each time, so a scene file's bytes change whenever it is exported, even when nothing in it changed.

## Consequences

- Blender files are binary, so two people cannot merge their edits to the same level. Git LFS locking waits until a second person edits levels.
- The game depends on Blender's USD export. After a Blender update, export the levels and models again and run `./scripts/check`.
- What reaches the game is checked by the extension's tests and `./scripts/check`; how it looks and performs is checked in the Simulator and on the phone.
