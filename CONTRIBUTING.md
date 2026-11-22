# Contributing to Lauder

People and AI-assisted contributors are welcome. The Brooklyn Bridge opening is playable in a Swift/RealityKit greybox; the README's [project status](README.md#project-status) has the current status.

## Before working

Read the [README](README.md) and the documents relevant to the change:
- [Story bible](docs/story/story-bible.md), with its [Chapter One outline](docs/story/story-bible.md#chapter-one--across-the-bridge), for narrative work.
- [Architecture](docs/architecture.md) and [prototype plan](docs/prototype-plan.md) for technical work.
- [Gameplay walkthrough](docs/gameplay-script.md) for the player experience, and the distinction between current behaviour and planned interactions.
- [AGENTS.md](AGENTS.md) when using a coding agent.

Distinguish agreed foundations from working proposals. For changes to the story foundations, engine, architecture or prototype scope, explain the proposal in an issue before investing in a large rewrite, unless an existing issue or maintainer assignment already describes that work.

An explicit maintainer assignment or instruction authorises that task. Avoid asking again for permission already supplied by that assignment. Implementation begins from an explicit assignment, not from the existence of a plan.

## Naming conventions

Keep each platform's and tool's files in its own top-level folder, as the [project structure](README.md#project-structure) shows: `apple/` for the iPhone app and `blender/` for the level editor. A later platform gets a folder of its own beside `apple/`. Use lowercase names for manually maintained folders, with hyphens between words when needed. Swift source filenames use PascalCase, such as `GameWorld.swift`. Other documentation and script filenames use lowercase kebab-case, such as `visual-direction.md` and `export-level.py`.

Preserve conventional names: `README.md`, `CONTRIBUTING.md`, `AGENTS.md`, `LICENSE`, `Info.plist` and `Lauder.xcodeproj`. Leave Xcode/tool-owned internal folder names unchanged. Targets, modules and products remain `Lauder` and `LauderTests`. Asset resource names and USD prim paths retain their intentional case.

## Pull requests

Use a branch or fork and open a small, focused pull request. Describe the problem, the resulting change and the validation performed. Keep related documents consistent and avoid unrelated cleanup.

Keep each implementation PR to one milestone, phase or assignment, or smaller.

Maintainers review and merge contributions. Be respectful and specific in feedback. AI-assisted work has the same expectations for correctness and provenance as any other contribution; the person submitting it remains responsible for reviewing it.

## Review channel

Reviewers and implementers exchange findings in GitHub issues and pull requests, as [AGENTS.md](AGENTS.md#review-channel) sets out.

## Validation

For documentation changes, check relative links and consistency with the story and technical plan. Explain any assumptions or checks you could not perform.

Select stable Xcode 27.2 and install an iOS 27 or later iPhone simulator runtime. With Git LFS assets downloaded, run the standard validation command from the repository root:

```sh
./scripts/check
```

The script first checks that the required Git LFS assets, the USDZ files and the combat sounds, exist and are downloaded payloads rather than Git LFS pointers. Missing assets produce `git lfs install` and `git lfs pull` recovery instructions before any Apple tools run; Git LFS itself is not required when the payloads are already present.

It then runs the Blender extension's tests, confirms that the [combat sounds](#sounds) match their generator, then runs the selected toolchain's `swift format` with the committed `apple/.swift-format`, builds the shared `Lauder` scheme and runs the hosted Swift Testing target. It prefers an already booted eligible iPhone simulator, otherwise chooses an installed one deterministically. Successful runs remove their own temporary build products, logs and result bundle. Failed runs retain their generated output outside Git and print the directory path for inspection.

The script honours `DEVELOPER_DIR` for a side-by-side Xcode installation. `LAUDER_DESTINATION` can override the Xcode destination; `LAUDER_DEVELOPMENT_TEAM` supplies a signing team for a physical-device test. Configure your Apple account and signing locally in Xcode first; do not commit those values or device identifiers. The default simulator check does not need code signing.

Keep tests focused on meaningful behaviour. Simulator imports do not prove animation or controls on a physical phone; report the device, toolchain and actual observations separately.

Use Simulator for everyday scene, gameplay and interface iteration, with the keyboard controls of the [input contract](docs/prototype-plan.md#input-and-interaction-contract). The on-screen touch controls can also be exercised with a pointer, which does not establish physical multi-touch behaviour. Live PS5 stick input has not worked in the tested Simulator setup, even with Device Hub visible. Generic MFi enumeration does not prove controller forwarding, so use the keyboard for Simulator playtests.

Enable **Capture Keyboard** in Device Hub before playing. Tap Escape for Pause/Resume; holding Escape releases keyboard capture so you can use the Mac normally.

### Scripted Simulator playtests

`./apple/scripts/playtest` plays scripted scenarios in the rendered app, so an agent or contributor can check behaviour without driving the game by hand:

```bash
./apple/scripts/playtest
```

```bash
./apple/scripts/playtest first-fight ambush
```

It builds the Debug app, launches it with `-LauderPlaytest <scenario>`, records the screen and reports pass/fail with reasons, frame times, party-update cost, body overlaps, slot keeping and the widest gap. It saves marked screenshots, video, traces and summaries under `.local/playtest/<time>/`, which Git ignores, or under `--output`.

Use `./apple/scripts/playtest --list` for the current scenario names. The scenario families cover:

- The bridge opening, fights, recruitment and Restart.
- Formations, squad orders and refused destinations.

Scenarios are defined in `apple/sources/world/Playtest.swift`. With no scenario names, the script runs the current complete set. Keep names and exact completed results in the [prototype plan](docs/prototype-plan.md#verification-and-performance), rather than maintaining a second scenario list here.

Scenario input passes through the ordinary controls and input rules. The HUD shows the step/result and small discs mark companion destinations. The runner is compiled only in Debug and starts only when requested; released TestFlight builds contain no runner. `PlaytestTests` drives the same scenarios without rendering as part of `./scripts/check`. Headless success, rendered Simulator timing and pointer-driven touches do not establish physical controls, multi-touch, haptics or enjoyment.

The bridge is the only playable level. Its pause menu offers **Resume**, **Restart** and **Vibration**. There is no level selector or weapon bench. Small test-only levels in `apple/tests/support` exercise collision and weapons; they are not app content.

If the Simulator keeps crashing in Apple's **PosterBoard** at startup, before Lauder launches, create a new Simulator device rather than looking for the cause in Lauder.

On the phone, controllers and touch share one input path, whose controls the [input contract](docs/prototype-plan.md#input-and-interaction-contract) lists. On source changes, cancel old touch captures and require neutral input. Pause keeps the touch surface mounted: even a finger resting at the stick centre must lift before the release gate clears. At an assigned phone checkpoint, check simultaneous stick/button touches, Pause with held fingers, cancellation and source changes on the physical phone. Earlier controller tests and single-pointer Simulator checks do not prove these behaviours on a new build.

Use Simulator for everyday checks and intermediate PRs; the [prototype plan](docs/prototype-plan.md) sets the phone checkpoints. Before declaring each milestone complete, use the baseline iPhone 13 Pro Max to verify its affected controls, movement/collision, camera, Pause/Resume, input release, interruptions and disconnect/reconnect. Measure frame pacing for performance claims. Xbox controllers share the input path but have not been tested on hardware. Simulator timing is not phone evidence. The foreground game stays awake, including Pause, and normal idle locking resumes on leaving it. Record results and remaining gaps in the milestone's pull request.

## Editing a level in Blender

Each level is a Blender file in the repository, the level's source ([ADR 0002](docs/decisions/0002-blender-source-of-truth.md)): for the Brooklyn Bridge, `blender/levels/brooklyn-bridge.blend`, stored with Git LFS. Saving it in Blender exports the two files the game reads:

- `apple/sources/content/BrooklynBridge.usdz`, the scene file: everything the player sees;
- `apple/sources/content/BrooklynBridgeLayout.swift`, the layout file: where everything that plays stands, and the lights and camera.

Never edit those two by hand; change the level in Blender instead.

1. Install the Lauder extension once, in Blender 5.3 or later:
   - In **Preferences › Get Extensions**, open the **Repositories** menu, choose **+ › Add Local Repository**, and pick this repository's `blender/extensions` folder.
   - In **Preferences › Add-ons**, enable **Lauder levels**.

   A **Lauder** tab appears in the 3D Viewport's sidebar (press N). The extension runs from the repository, so after a pull or a branch switch it is up to date once Blender restarts.
2. Check the **Repository** folder, which defaults to the repository the extension came from, and press **Open Level**. The level file's collections decide where each object goes:
   - **Visual**: everything the player sees, exported to the scene file. Each box's look is a block parented to its gameplay box, and the decoration, such as the towers' tops, the route poles, the baked tower shadows and the snow plain, stands on its own. Reshape or replace any of it.
   - **Gameplay**: the ground, the boxes that block movement and sight, the trigger and fight areas, and the named markers, drawn as outlines. Each has a role, which the Lauder tab shows for the selected object; a new mesh counts as a box and a new empty as a marker.
   - **Lights**: the suns, point lights and spot lights. **Camera**: the game camera and its target.
   - **Preview**: the party's models at their start markers, which the game places itself. It is never exported, and the level's exports are not made from the models only it shows.
3. Move, resize, duplicate or delete what you need. Moving a gameplay box moves the look parented to it. Gameplay objects follow the game's rules:
   - turn boxes only in quarter turns about the vertical;
   - keep boxes on the deck;
   - give each a name of its own, and keep the names that `BrooklynBridge.swift` uses.
4. To see the game's view, look through the camera (Numpad 0) and drag **camera-target** to where the leader would stand. The frame is the baseline iPhone's screen. Moving **game-camera** changes the game's camera offset, and its **Field of View**, in the camera's properties, changes the game's. Keep its **Sensor Fit** at Vertical.
5. To change the lighting, turn the suns in **Lights** and change their **Color**, **Strength** and **Shadow** in the light's properties, or add point and spot lights there. A point or spot light needs its **Custom Distance** on, which sets how far it reaches, in Blender's preview as in the game, and a point light needs its **Shadow** off, since the game draws no shadows from point lights. Set a light's colour with **Color**, not **Temperature**, and keep **Normalize** on: the game reads neither, though it follows **Exposure**. Keep to the visual direction's budget: at most four lights, one casting shadows. Press **Game Look** to see the scene lit by its own lights, close to the game, and press it again for Solid shading. It asks you to hide any light that is not in **Lights** first.
6. To change how something looks, edit its material's Principled BSDF. **Base Color**, **Roughness** and **Metallic** reach the game, and image textures reach it on those and on **Normal**, through a **Normal Map** node, **Emission Color** and **Alpha**. Export refuses what the [contract between Blender and the game](docs/decisions/0002-blender-source-of-truth.md#decision) rules out, such as another shader, so bake a procedural look into an image first.

   To darken where parts meet, select them in Visual and press **Bake Occlusion**. Blender bakes ambient occlusion, within 1.5 m, into an image of each part's colour in `blender/levels/baked/<level>`, and the part shows a copy of its material with that image as **Base Color**; the game's lights and shadows still light it. Press it again after moving things, which bakes every part already baked. **Clear Occlusion** gives the selected parts their material back. A part to bake needs one material, with nodes feeding only its **Base Color**, and no UV map of its own named `baked`. Split a long part first, since its image is at most 1,024 pixels on a side. The bridge bakes nothing yet.

   The towers cast no live shadow in the game, since a tower fades to a ghost while it hides the party and its shadow must stay. Their shadows are parts of Visual, `tower-shadow-brooklyn` and `tower-shadow-manhattan`, in the palette's shadow material, and each names the parts whose shadow it is, separated by commas, in its `lauder_shadow_of` property, under **Object Properties › Custom Properties**. After turning the sun that casts the shadow, or moving or resizing a tower, press **Bake Shadows**: it lays every such shadow again where that sun throws its parts. `./scripts/check` fails while a tower's shadow lies anywhere else.
7. Press ⌘S. Saving checks the game's rules: if one fails, it explains what to fix, and only the Blender file is saved. Otherwise it exports, in a Blender of its own in the background, in about two seconds, and the Lauder tab says when it is done. **Export** does the same for a file you have not changed, for example after a pull.
8. Press **Play** to see the level in the game. It saves the level, exports it if needed, then builds the app and opens it in the iOS Simulator through `./apple/scripts/play`, which can also be run on its own. The first build takes a few minutes; later ones take a few seconds.
9. Run `./scripts/check`. Tests that check the layout, such as the cover near the stranger, may need updating to match what you moved.

To change a level without Blender's interface, for example with a script in a background Blender, export it afterwards, giving the path of your Blender:

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python-exit-code 1 --python blender/scripts/export-level.py
```

`blender/level-exports.json` records the fingerprints of the level's Blender file, of the models and textures it uses, and of its two exports, and of each [model the game creates](#models) and its scene file. `./scripts/check` fails while they no longer match, including after an edit by hand. Blender's z axis is up, so a game point (x, y, z) sits at (x, -z, y), with the Manhattan end towards +y. `./scripts/check` runs the Blender extension's tests, which need no Blender.

## Models

A model is a Blender file of its own, `blender/assets/<model>/<model>.blend`, stored with Git LFS ([ADR 0002](docs/decisions/0002-blender-source-of-truth.md)). Beside it are a `README.md`, which says where the model comes from and under which licence, and any textures it uses. One collection, named after the model, holds it, at its real size in metres and standing on the ground at its origin. Levels link the model, so a change to it reaches every level that uses it. The models so far are the stand-ins that the game creates itself, for the party and the hostiles. The [models' README](blender/assets/README.md) sets out the rest of what a model's file needs.

- **Place a model in a level:** with the level open, select the gameplay box the model belongs to, press **Add Model** in the Lauder tab, and choose the model. It stands on the box's base, turned along the box's longer side, in Visual and parented to the box, so that it moves with the box. Without a box selected, it stands at the 3D cursor. The game blocks movement and sight with the box, not the model, so give the box the model's size.
- **Change a model:** select it in the level and press **Open Model**, or open its file. Change it and save: each level whose export used it exports again. **Open Level** goes back. A level cannot change a linked model; a variant, such as one in another colour, is a model of its own.
- **Check a model:** press **Check Model** with the model open, or run the intake check, giving the path of your Blender:

  ```bash
  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python-exit-code 1 --python blender/scripts/check-model.py -- miki
  ```

  It lists what must change before a level can use the model, such as a material the game cannot show, a texture outside the model's folder, or a README without the model's source and licence. Then it notes what is worth a look, such as the model's size.
- **Bring in a model from a file:** run `add-model.py` with the file and a name for the model, in lowercase letters, digits and hyphens:

  ```bash
  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python-exit-code 1 --python blender/scripts/add-model.py -- taxi.glb taxi
  ```

  It takes Blender files, and the glTF, FBX, OBJ and USD files that Blender imports. It makes the model's folder: the model's Blender file, holding what the file shows, without its lights and cameras; a copy of every texture it uses; and a `README.md`. From a Blender file it takes what the first scene shows, and each instance of a collection becomes copies of its parts. Fill in the README's **Source** and **Licence** lines before committing, as [Assets and attribution](#assets-and-attribution) asks, then open the model in Blender to look at it.

Some models the game creates itself as it plays, rather than a level placing them: the party, `miki`, `tom` and `laura`, and `hostile`, which every hostile shows. The extension's `SPAWNED` list names them. Saving such a model also exports its own scene file, `apple/sources/content/models/<model>.usdz`, which the game loads by the model's name. Play exports any that no longer match, and so does `export-model.py` with the model's name:

```bash
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python-exit-code 1 --python blender/scripts/export-model.py -- miki
```

A new kind of thing for the game to create needs its name in `SPAWNED` and code that loads it.

A model follows the same rules as the rest of a level's look, and Export refuses a level whose models break them. Its materials use a Principled BSDF with image textures, each named after the model so that no two share a name. Its textures are PNG or JPEG files in its own folder, never packed into the Blender file; the [visual direction](docs/visual-direction.md) allows no new ones for now. After changing a texture outside Blender, press **Export** in the level, or run `export-level.py`. `./scripts/check` fails while a model lacks a README naming its source and licence, while a level's exports no longer match its models, or while a model the game creates no longer matches its scene file.

## TestFlight builds

TestFlight builds use the app ID `com.ronildo.lauder` and the maintainer's paid team, which is passed at archive time with `DEVELOPMENT_TEAM` and kept out of the repository. Archive the Release configuration for `generic/platform=iOS` with automatic signing and `-allowProvisioningUpdates`, then upload with `xcodebuild -exportArchive` and an export-options file whose method is `app-store-connect` and destination `upload`. Each upload needs a build number not used before for its version. The committed `CURRENT_PROJECT_VERSION` is the last build uploaded, so raise it before the next upload. Internal testers receive each build automatically, and the pause menu shows which one they are playing, such as **Lauder 0.1.0 (14)**. Upload only with the maintainer's go-ahead.

An existing App Store Connect API upload key can authenticate both archive and export/upload. Pass `-authenticationKeyPath "$LAUDER_ASC_KEY_PATH"`, `-authenticationKeyID "$LAUDER_ASC_KEY_ID"`, `-authenticationKeyIssuerID "$LAUDER_ASC_ISSUER_ID"` and `-allowProvisioningUpdates`; these variables refer to private local values, never committed credentials. Identify the existing authorised key rather than choosing arbitrarily if several exist. API authentication does not depend on Xcode's saved Apple-account session or a connected phone; signing material must still match the selected team. Keep keys, JWTs and full signing logs private.

Discover Lauder's own App Store Connect record by bundle ID, and inspect both build records and accepted/processing build uploads before selecting and committing a number. Record the source commit and verify the signed archive's bundle ID, version/build, team and symbols. A previous archive is reusable only when its source is correct and its number remains unused. Upload for internal TestFlight testing using Lauder's distribution settings; preserve existing tester membership. Completion requires successful Apple processing and verified availability to the existing intended groups, not only a successful upload command. An explicit assignment may authorise a sequence of reviewed merges and TestFlight deliveries, as [ADR 0011](docs/decisions/0011-companion-combat.md) does for the current combat work; do not request the same approval at every milestone or treat Simulator delivery as physical-playtest evidence.

## Git LFS and cloning

Install [Git LFS](https://docs.github.com/en/repositories/working-with-files/managing-large-files/installing-git-large-file-storage) before cloning assets:

```sh
git lfs install
git clone https://github.com/RonildoBraga/lauder.git
cd lauder
git lfs pull
```

For an existing clone, run `git lfs install` and then `git lfs pull` from the repository. Without LFS, an asset may be only a small pointer file. Inspect `git lfs ls-files` and confirm the needed assets are present before opening them.

The repository's [`.gitattributes`](.gitattributes) tracks selected editable and delivery formats with LFS while Swift, JSON, Markdown and text USD (`.usda`) stay in ordinary Git.

For PNG/JPEG and other binary image or texture formats without a format-wide LFS rule, files larger than **1 MiB (1,048,576 bytes)** require an explicit-path LFS rule before committing. PNG/JPEG files at or below that size stay in ordinary Git. This threshold is repository policy, not a GitHub file-size limit; existing format-wide LFS rules still apply regardless of size. Measure the file's byte count, for example with `wc -c < path/to/texture.png`.

Inspect mixed-format `.usd` files separately: binary `.usd` requires an explicit-path LFS rule regardless of size; text `.usd` stays in ordinary Git. Confirm a new asset's filter with `git check-attr filter -- path/to/asset` before committing it. See [GitHub's LFS configuration guidance](https://docs.github.com/en/repositories/working-with-files/managing-large-files/configuring-git-large-file-storage).

### Usage and cost

LFS storage and bandwidth draw from the repository owner's account-wide allowance. New binary revisions consume storage, and public downloads consume bandwidth. Keep private account usage and billing details out of public issues and commits. Use [GitHub's current included-usage reference](https://docs.github.com/en/billing/reference/product-usage-included) and [LFS billing guidance](https://docs.github.com/en/billing/concepts/product-billing/git-lfs), rather than assuming a public repository has unlimited asset storage.

If allowance is exhausted or uploads are blocked, stop the asset upload and report it. Do not bypass LFS by committing the binary to ordinary Git, buy storage, or change billing budgets without the maintainer's explicit authorisation.

## Assets and attribution

Original contributions are submitted under the project's [MIT licence](LICENSE). Clearly identify third-party material and its applicable terms; maintainers must be able to verify that it can be included.

Submit original material or material you are entitled to contribute. For third-party art, audio, fonts or models, include the source, licence and required attribution. Do not assume that a downloadable or AI-generated asset is automatically suitable for redistribution.

Group each asset's editable source, deliberate delivery export and a short provenance note together in the repository; use LFS for the applicable binaries. The note records the creator/source URL, licence and attribution, file sizes, and how the export was produced. A [model](#models) keeps its Blender file, textures and `README.md` in its own folder in `blender/assets`; each level's scene file is its export. Keep generated build products and caches out of source control.

The supported path makes levels and models in Blender, exports each level's look as a USDZ that the game loads directly, and composes the rest in Swift. See the [engine decision](docs/decisions/0001-engine.md) and [ADR 0002](docs/decisions/0002-blender-source-of-truth.md).

### Sounds

The combat sounds in `apple/sources/content/sounds` are original: [`apple/scripts/make-sounds.py`](apple/scripts/make-sounds.py) generates them with Python's standard library, from filtered noise and simple tones, under the project's MIT licence ([ADR 0008](docs/decisions/0008-weapon-feel-and-combat-plan.md)). They are 16-bit mono WAV files at 44.1 kHz, about 310 KB in all, stored with Git LFS. After changing the script, run it from the repository root and commit the files it writes:

```sh
python3 apple/scripts/make-sounds.py
```

`./scripts/check` fails while the committed files differ from what the script makes. A recording can later replace a sound under the same name, with no change to the game's code: record its source, licence and attribution here, and change the script so that it no longer makes or checks that sound.

### Target membership

`apple/sources/` and `apple/tests/` are Xcode folder-synchronised groups, so Swift files and the runtime USDZ and WAV resources join their targets automatically. The app target does not copy `apple/sources/app/Info.plist` as a resource, since the build uses it as the typed input to the bundle's plist. Review target membership when adding other non-runtime files beneath either folder, so authoring files are not copied into the app.

Keep signing credentials, API keys, personal device identifiers, local account information, generated builds and caches out of the repository.
