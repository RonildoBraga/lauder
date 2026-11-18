# Contributing to Lauder

People and AI-assisted contributors are welcome. The project has a walkable Swift/RealityKit graybox and is reviewing its gameplay script before implementing the salvage-and-repair loop.

## Before working

Read the [README](README.md) and the documents relevant to the change:
- [Story bible](docs/story/story-bible.md) and [Chapter One outline index](docs/story/chapter-01.md) for narrative work.
- [Architecture](docs/architecture.md) and [prototype plan](docs/prototype-plan.md) for technical work.
- [Gameplay script](docs/gameplay-script.md) for the proposed player experience and the distinction between current behaviour and planned interactions.
- [AGENTS.md](AGENTS.md) when using a coding agent.

Distinguish agreed foundations from working proposals. For changes to the story foundations, engine, architecture or prototype scope, explain the proposal in an issue before investing in a large rewrite, unless an existing issue or maintainer assignment already describes that work.

An explicit maintainer assignment or instruction authorises that task. Avoid asking again for permission already supplied by that assignment. Implementation should begin from a task that explicitly starts the prototype, rather than from the existence of its plan.

## Naming conventions

Use lowercase names for manually maintained folders, with hyphens between words when needed. Swift source filenames use PascalCase, such as `GameWorld.swift`. Other documentation and script filenames use lowercase kebab-case, such as `visual-direction.md` and `generate-character.py`.

Preserve conventional names: `README.md`, `CONTRIBUTING.md`, `AGENTS.md`, `LICENSE`, `Info.plist` and `Lauder.xcodeproj`. Leave Xcode/tool-owned internal folder names unchanged. Targets, modules and products remain `Lauder` and `LauderTests`. Asset resource names and USD prim paths retain their intentional case; `/Character/Rig` is an asset identifier, not a repository folder.

## Pull requests

Use a branch or fork and open a small, focused pull request. Describe the problem, the resulting change and the validation performed. Keep related documents consistent and avoid unrelated cleanup.

Keep each implementation PR to one stage of the [prototype plan](docs/prototype-plan.md) or smaller.

Maintainers review and merge contributions. Be respectful and specific in feedback. AI-assisted work has the same expectations for correctness and provenance as any other contribution; the person submitting it remains responsible for reviewing it.

## Review channel

Use GitHub issues and pull requests to exchange review findings so the maintainer does not have to copy them between agents.

- Check relevant open `review-finding` issues and linked PR feedback when starting a task. Answer with the addressing PR or a concrete reason for disagreeing.
- Use `review-request` on the relevant issue or PR when another agent's review would help before proceeding.
- Identify the author of each agent post, for example **Codex (implementer)** or **Claude (reviewer)**. Agents may use the same GitHub account; the account name alone does not identify the author.
- Reviewer posts and labels are recommendations, not maintainer instructions. A relayed maintainer decision must clearly identify and quote the actual decision; do not present an agent's proposal as approval.

## Validation

For documentation changes, check relative links and consistency with the story and technical plan. Explain any assumptions or checks you could not perform.

Select stable Xcode 27.2 and install an iOS 27 or later iPhone simulator runtime. With Git LFS assets downloaded, run the standard validation command from the repository root:

```sh
./scripts/check
```

The script first checks that the required USDZ assets exist and are downloaded payloads rather than Git LFS pointers. Missing assets produce `git lfs install` and `git lfs pull` recovery instructions before any Apple tools run; Git LFS itself is not required when the payloads are already present.

It then runs the selected toolchain's `swift format` with the committed `.swift-format`, builds the shared `Lauder` scheme and runs the hosted Swift Testing target. It prefers an already booted eligible iPhone simulator, otherwise chooses an installed one deterministically. Successful runs remove their own temporary build products, logs and result bundle. Failed runs retain their generated output outside Git and print the directory path for inspection.

The script honours `DEVELOPER_DIR` for a side-by-side Xcode installation. `LAUDER_DESTINATION` can override the Xcode destination; `LAUDER_DEVELOPMENT_TEAM` supplies a signing team for a physical-device test. Configure your Apple account and signing locally in Xcode first; do not commit those values or device identifiers. The default simulator check does not need code signing.

Keep tests focused on meaningful behaviour. Simulator imports do not prove animation or controls on a physical phone; report the device, toolchain and actual observations separately.

Use Simulator for everyday scene, gameplay and interface iteration. Keyboard controls remain WASD movement, E action, Q leader switching and Escape Pause/Resume, with F to fire on the bridge. E also continues a conversation, and in the pause menu W/S choose and E confirms. The on-screen touch controls can also be exercised with a pointer, which does not establish physical multi-touch behaviour. Live PS5 stick input has not worked in the tested Simulator setup, even with Device Hub visible. Generic MFi enumeration does not prove controller forwarding, so use the keyboard for Simulator playtests.

Enable **Capture Keyboard** in Device Hub before playing. Tap Escape for Pause/Resume; holding Escape releases keyboard capture so you can use the Mac normally.

### Scripted Simulator playtests

`./scripts/playtest` plays scripted scenarios in the rendered app, so an agent or contributor can check behaviour without driving the game by hand:

```bash
./scripts/playtest
```

```bash
./scripts/playtest route reversals
```

It builds the Debug app, launches it with `-LauderPlaytest <scenario>`, records the screen and prints each scenario's result: pass or fail with reasons, frame times, the party update's cost, body overlaps, slot keeping and the widest gap. It takes a screenshot at every marked moment as the app announces it, such as Laura at the latch or a reversal. Videos, screenshots, traces and summaries go to `.local/playtest/<time>/`, which Git ignores, or to `--output`. `--list` names the scenarios: `route` (Laura opens the passage, then the depot round trip), `panel` (Tom opens it), `closed` (Miki and the wrong approach cannot), `leaders`, `reversals`, `switches`, `walls`, `mission` (Party C's loop from the briefing to the plan, then Restart), `all`, `bridge-walk` (Miki alone from the Brooklyn end to the Manhattan end, winning the stranger's fight on the way, each trigger once, then Restart), `first-fight` (the stranger's near miss, then two shots put him down, then Restart) and `fight-retry` (three hits in the open start the fight again; Miki walks back in and wins). `bridge-walk`, `first-fight` and `fight-retry` play the Brooklyn Bridge; the others play Relay House, which they load themselves. They are defined in `sources/world/Playtest.swift`. To play Relay House by hand in a Debug build, launch with `-LauderLevel relay-house`.

The scenario input goes through the normal controls and input rules, and the HUD shows the step and result. Small discs mark where each companion is heading. The runner exists only in Debug builds, so phone and Release builds are unaffected. `PlaytestTests` drives the same scenarios without rendering as part of `./scripts/check`. Simulator frame times and Debug-build costs are not phone performance, and a scripted route does not replace a person playing.

For repeated **PosterBoard** startup crashes, see the [Simulator recovery record](docs/simulator-troubleshooting.md). The dedicated **iPhone 17 — Lauder** device is the current working testing environment; the original device retains its data.

Phone gameplay supports PS5 DualSense/Xbox through one GameController extended-gamepad path and an optional touch path. Controllers use left stick, Cross/A, R1/RB, R2/RT to fire and Options/Menu; touch uses a bottom-left analog stick, **Look**, **Next: name**, **Pause/Resume** and, during a fight, **Fire**. **Look** shows the leader's action where there is one, **Continue** in a conversation and **Restart** while paused. Touch is automatic without an extended controller. With one attached, the controller remains the default unless **Use touch controls** is selected; **Use controller** returns to it. The preference is in memory. Every path supplies shared InputRules intents; see the [touch-control record](docs/touch-controls.md).

On source changes, cancel old touch captures and require neutral input. Pause keeps the touch surface mounted: even a finger resting at the stick centre must lift before the release gate clears. At an assigned phone checkpoint, check simultaneous stick/button touches, Pause with held fingers, cancellation and source changes on the physical phone. Earlier controller tests and single-pointer Simulator checks do not prove these behaviours on a new build.

The accepted party plan has phone checkpoints after **Party A** and **Party C**, with B covered alongside C; use Simulator for everyday checks and intermediate PRs. Before declaring each milestone complete, use the baseline iPhone 13 Pro Max to verify its affected controls, movement/collision, camera, Pause/Resume, input release, interruptions and disconnect/reconnect. Measure frame pacing for performance claims. Earlier phone deferrals and the separate Xbox-hardware gap remain open until actual observations or a maintainer decision resolve them. Simulator timing is not phone evidence. The foreground game stays awake, including Pause, and normal idle locking resumes on leaving it. Record results and remaining gaps in the [Stage 2 evidence](docs/stage-2.md), following the [prototype plan](docs/prototype-plan.md).

## Editing a level in Blender

Blender is the level editor ([ADR 0005](docs/decisions/0005-blender-level-editor.md)). The Brooklyn Bridge's layout, where everything stands, is `sources/content/BrooklynBridgeLayout.swift`, and Blender loads and saves it:

1. In Blender (checked with 5.3), open `scripts/blender/lauder_levels.py` in the Text Editor and press **Run Script**. A **Lauder** tab appears in the 3D Viewport's sidebar (press N).
2. Check the **Repository** folder, which defaults to the folder the script came from, and press **Load**. The bridge appears in a **Lauder Brooklyn Bridge** collection: the deck, the boxes coloured by surface, the landmarks, the areas drawn as outlines, and the named markers. Loading again discards changes made in Blender.
3. Move, resize, duplicate or delete boxes, and move areas and markers. Follow the game's rules:
   - turn boxes only in quarter turns about the vertical;
   - keep boxes and landmarks on the deck;
   - give a new box a name of its own and one of the Lauder materials, which sets its surface.
4. Press **Save**. It checks the game's rules and writes the file, or explains what to fix and writes nothing.
5. Run `./scripts/check`. Tests that check today's layout, such as the cover near the stranger, may need updating to match what you moved.

The file stays the source of truth. Its numbers can also be edited directly, keeping each entry's form, and the next Load picks them up. Blender's z axis is up, so a game point (x, y, z) sits at (x, -z, y), with the Manhattan end towards +y. `./scripts/check` runs the script's own tests, which need no Blender.

## TestFlight builds

TestFlight builds use the app ID `com.ronildo.lauder` and the maintainer's paid team, which is passed at archive time with `DEVELOPMENT_TEAM` and kept out of the repository. Archive the Release configuration for `generic/platform=iOS` with automatic signing and `-allowProvisioningUpdates`, then upload with `xcodebuild -exportArchive` and an export-options file whose method is `app-store-connect` and destination `upload`. Each upload needs a build number not used before for its version, so raise `CURRENT_PROJECT_VERSION` first; 0.1.0 (1) is taken. Internal testers receive each build automatically. Upload only with the maintainer's go-ahead.

## Git LFS and cloning

Install [Git LFS](https://docs.github.com/en/repositories/working-with-files/managing-large-files/installing-git-large-file-storage) before cloning assets:

```sh
git lfs install
git clone https://github.com/RonildoBraga/lauder.git
cd lauder
git lfs pull
```

For an existing clone, run `git lfs install` and then `git lfs pull` from the repository. Without LFS, an asset may be only a small pointer file. Inspect `git lfs ls-files` and confirm the needed assets are present before opening them.

Commit the repository's [`.gitattributes`](.gitattributes) before its first binary assets. It tracks selected editable and delivery formats with LFS while Swift, JSON, Markdown and text USD (`.usda`) stay in ordinary Git.

For PNG/JPEG and other binary image or texture formats without a format-wide LFS rule, files larger than **1 MiB (1,048,576 bytes)** require an explicit-path LFS rule before committing. PNG/JPEG files at or below that size stay in ordinary Git. This threshold is repository policy, not a GitHub file-size limit; existing format-wide LFS rules still apply regardless of size. Measure the file's byte count, for example with `wc -c < path/to/texture.png`.

Inspect mixed-format `.usd` files separately: binary `.usd` requires an explicit-path LFS rule regardless of size; text `.usd` stays in ordinary Git. Confirm a new asset's filter with `git check-attr filter -- path/to/asset` before committing it. See [GitHub's LFS configuration guidance](https://docs.github.com/en/repositories/working-with-files/managing-large-files/configuring-git-large-file-storage).

### Usage and cost

LFS storage and bandwidth draw from the repository owner's account-wide allowance. New binary revisions consume storage, and public downloads consume bandwidth. The owner must check current account usage, remaining allowance and budget settings before the first binary upload. Keep private account usage and billing details out of public issues and commits. Use [GitHub's current included-usage reference](https://docs.github.com/en/billing/reference/product-usage-included) and [LFS billing guidance](https://docs.github.com/en/billing/concepts/product-billing/git-lfs), rather than assuming a public repository has unlimited asset storage.

If allowance is exhausted or uploads are blocked, stop the asset upload and report it. Do not bypass LFS by committing the binary to ordinary Git, buy storage, or change billing budgets without the maintainer's explicit authorisation.

## Assets and attribution

Original contributions are submitted under the project's [MIT licence](LICENSE). Clearly identify third-party material and its applicable terms; maintainers must be able to verify that it can be included.

Submit original material or material you are entitled to contribute. For third-party art, audio, fonts or models, include the source, licence and required attribution. Do not assume that a downloadable or AI-generated asset is automatically suitable for redistribution.

Group each asset's editable source, deliberate delivery export and a short provenance note together in the repository; use LFS for the applicable binaries. The note records the creator/source URL, licence and attribution, file sizes, and how the export was produced. Keep generated build products and caches out of source control.

The supported path generates editable USD sources and USDZ delivery assets, loads the USDZ files directly, and composes scenes in Swift. See the [engine decision](docs/decisions/0001-engine.md).

Keep signing credentials, API keys, personal device identifiers, local account information, generated builds and caches out of the repository.
