# ADR 0005 — Blender as the level editor

**Status:** Accepted by the maintainer on 18 November 2026 (**“Yes, as recommended”**) and implemented for the Brooklyn Bridge. The maintainer [authorised the merge](https://github.com/RonildoBraga/lauder/pull/43#issuecomment-6973768300) (“Yes, merge it”) without an independent review.\
**Date:** 18 November 2026\
**Amended:** 18 November 2026, at the maintainer's request: [the decoration and the game camera](#amendment--the-decoration-and-the-game-camera) join the layout file. The maintainer [authorised the merge](https://github.com/RonildoBraga/lauder/pull/45#issuecomment-6975951390) (“Yes, merge both”) without an independent review\
**Amended again:** 19 November 2026, at the maintainer's request: [the lights and the surface materials](#amendment--lights-and-surface-materials) are built in Blender too. After trying it in Blender and the Simulator, the maintainer [authorised the merge](https://github.com/RonildoBraga/lauder/pull/49#issuecomment-6996641912) (“Yes, merge it”) without an independent review\
**Amended a third time:** 19 November 2026, at the maintainer's request: [the working file, a safe Save and Play](#amendment--the-working-file-a-safe-save-and-play). Not yet merged\
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

## Amendment — lights and surface materials

**Date:** 19 November 2026

Reviewing a proposed workflow for Blender, the maintainer noted that its lights would only be shown in Blender, not built there, and asked **“can we change so we also build that on Blender ?”**, then **“What about the materials, can we also build on Blender and use on the game ?”** Claude proposed moving both into files that Blender edits. The maintainer chose **“Lights and materials first”**, ahead of the rest of that workflow, and asked to keep them simple but to prepare the pipeline, because **“eventually I want most of the things to be build on blender if not everything”**. This amends decision 1, and the earlier amendment's consequence that Blender does not show the game's lighting or the materials' finish:

1. **The lights are in the layout file.** A `lights:` section follows the camera. Each light is a sun, as RealityKit's directional light: a name, the direction it comes `from`, an sRGB colour, an intensity in lux and, when it casts shadows, how far from the camera they reach. The bridge's two lights moved there from the game's code unchanged.
   - Load builds each as a Blender sun light, turned to shine from its direction, with its colour, its shadow on or off, and a strength of 1 W/m² for every 700 lux. The factor brings Blender's preview close to the game; it is not a physical conversion.
   - Save writes back each sun's direction, colour, strength and shadow. A direction keeps the length the file had, and a value that Blender hands back unchanged is kept as written.
   - Save keeps the [visual direction](../visual-direction.md#rendering-budget)'s budget: at least one light, at most two, and at most one casting shadows. It refuses other kinds of light for now.
2. **The surfaces' materials are a shared palette,** `apple/sources/content/Surfaces.swift`, for every level: one finish per surface, made of an sRGB colour, a roughness and a metalness. Glass, used for the vehicles' windows, joins the surfaces. The game makes its surface materials from the palette. The stand-ins and the gameplay signals keep their own colours in code, so the palette cannot change them.
   - Load builds a Lauder material for each surface, setting both its Principled BSDF, which Material Preview shows, and its viewport display, which Solid shading shows.
   - Save writes whichever of the two was changed, then sets both to what it wrote, so that the setting an edit did not touch cannot undo it at the next Save. It checks the palette and the layout together: if either fails, neither file is written.
   - The palette's entries are the surfaces Blender accepts, so the script no longer keeps its own copy of the game's colours. Adding a surface still needs a case in `Level.Surface`, and a test checks that the two match.
3. **Game Look**, a button in the Lauder tab, shows the 3D Viewport in Material Preview, lit only by the level's own lights. It refuses while lights outside the level are visible, such as the one in Blender's default scene, because the game has none. Blender's renderer is not RealityKit, so the view comes close to the game without matching it.
4. **The recipe for the next move into Blender:** give the thing a typed entry in a Swift data file, read and write that entry exactly in `blender/lauder_levels.py`, build it in Load and read it back in Save, check the game's rules before anything is written, and test the round trip. The formats leave room to grow: another kind of light would be another kind of entry in `lights:`, and a texture another field of a finish.

### Consequences of this amendment

- Blender shows the game's lighting and the surfaces' finish, approximately. It still does not show the characters.
- Changing a surface's finish changes it everywhere the surface is used, in every level.
- Point and spot lights and textures wait for a need. Textures also wait for the visual direction's limit on new textures to change.

### Checks

- `./scripts/check` passes: 104 Swift tests in 17 suites on the iPhone 17 / iOS 27 Simulator, and the layout script's 31 tests. The new tests cover:
  - the lights and the palette reading and writing back unchanged;
  - a turned, brightened and recoloured sun saving as expected, and shadows following each sun's setting;
  - Save refusing a second shadow, a third light, a point light, no light, a dark light and a duplicate name, and keeping the file's lights when Blender has none;
  - the layout and palette readers refusing an entry written in any other form, which a save would otherwise drop;
  - a material changed in its own settings or in its viewport display, a saved change surviving the next save, materials left alone, and palettes the game cannot use;
  - the game lighting the bridge from the layout file within the budget, and every surface taking its finish from the palette.
- The game's opening frame in the Simulator is the same, pixel for pixel, from `main` and from this change, as it is between two runs of `main`.
- In Blender 5.3, run in the background on a copy of the two files:
  - Load built the two suns, aimed as the file says, and the ten surface materials, and Save with no edits wrote nothing.
  - Turning `sun-key` to shine from straight above, doubling `sky-fill`'s strength and making steel smoother saved exactly those three changes, and a second Save straight after changed nothing. A second shadow was refused and wrote nothing, and loading again brought the saved values back.
  - Rendered through the game camera with EEVEE and lit by the two suns, the asphalt's red and green match the game's opening frame to about 1%. The game's light is a little bluer and its shadows softer.
- Not checked: the Game Look button, which needs an open 3D Viewport; the script in the maintainer's own Blender session; the phone, since the game's frame did not change.

## Amendment — the working file, a safe Save and Play

**Date:** 19 November 2026

With the lights and materials merged, Claude asked whether to start the rest of the Blender workflow proposed with them, and the maintainer answered **“Yes, start it”**. This amends decisions 2 and 3:

1. **The script is a Blender extension,** `blender/extensions/lauder_levels`, installed once from a local extension repository at `blender/extensions`. It runs from the repository, so it follows the checked-out branch. Run Script in Blender's Text Editor still works.
2. **Each level has a working Blender file,** `.local/blender/<level>.blend`, which Git ignores.
   - **Open Level** opens it, and makes it from the level's files the first time.
   - Saving it with ⌘S also saves the level after the usual checks. If they fail, only the Blender file is saved.
   - When the level's files changed while the working file was closed, opening it loads them again. If the file also holds level edits never saved to them, it changes nothing and leaves the choice to the person.
   - Decision 3 stands: the Swift files are the source of truth, and nothing from Blender is committed. The working file can be rebuilt from them at any time.
3. **Save is safe.** Load and Save record the files' text on the level's collection. Save refuses when the files changed since then, through an agent's edit, a pull or a branch switch: it names what changed and writes nothing. **Save Anyway** replaces those changes with what Blender holds.
4. **Play** saves the level and runs `apple/scripts/play`, which builds the Debug app in `.local/play` and opens it in the iOS Simulator. The script reuses the playtest script's helpers. Play runs in the background, so Blender stays usable, and reports the result in the Lauder tab.
5. **The party shows at its start markers,** drawn as the game's stand-ins, as a preview that follows each marker and is not saved. Laura shows standing, although the game has her lying hurt.

### Checks

- `./scripts/check` passes: the extension's tests, Swift formatting, the build, and the Swift tests on the iPhone 17 / iOS 27 Simulator. The extension's 38 tests include seven new ones:
  - the changes Save names;
  - the refusal's wording;
  - the working file's place;
  - the repository found from the extension;
  - the figures standing on the floor;
  - the manifest.
- In Blender 5.3, run in the background on copies of the two files:
  - The extension installed from a local repository at `blender/extensions` and enabled, with its operators and both handlers.
  - After an outside edit, Save refused with "car-b4 changed" and wrote nothing. Save Anyway then kept Blender's version.
  - Open Level's working file:
    - ⌘S wrote the level.
    - A change made to the files while the working file was closed was loaded again on opening, and named.
    - When the working file also held level edits that had not been saved, opening it changed nothing and flagged the conflict.
  - Load drew the figures, 21 parts at the three spawn markers, and Save without edits wrote nothing.
- `./apple/scripts/play` built and launched the game in the iOS Simulator and brought Device Hub to the front. It took 8 s the first time and 2 to 3 s afterwards.
- Not checked: the buttons in a person's own Blender, and the install steps in Preferences.
