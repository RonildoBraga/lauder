# Contributing to Lauder

People and AI-assisted contributors are welcome. The project has a walkable Swift/RealityKit graybox and is reviewing its gameplay script before implementing the salvage-and-repair loop.

## Before working

Read the [README](README.md) and the documents relevant to the change:
- [Story bible](docs/story/story-bible.md) and [Chapter One](docs/story/chapter-01.md) for narrative work.
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

Use Simulator for everyday scene, gameplay and interface iteration with keyboard controls: WASD moves, E acts and Escape pauses/resumes. Live PS5 stick input has not worked in the tested Simulator setup, even with Device Hub visible. Generic MFi enumeration does not prove controller forwarding, so use the keyboard for Simulator playtests.

Enable **Capture Keyboard** in Device Hub before playing. Tap Escape for Pause/Resume; holding Escape releases keyboard capture so you can use the Mac normally.

Phone gameplay uses PS5 DualSense and Xbox through one GameController extended-gamepad input path: left stick moves, Cross/A acts and Options/Menu pauses/resumes. Both input methods supply the same gameplay intents. There are no virtual touch controls or clickable screen actions.

At milestones, before merging playable features, run the affected controls, lifecycle and performance checks on the baseline iPhone 13 Pro Max with the supported controllers. Verify movement, collision, camera, action while moving, Pause/Resume, release/interruptions and disconnect/reconnect. Measure phone frame pacing for performance claims; simulator frame rate, battery and thermal behavior are not phone evidence. The foreground app keeps the screen awake, including when paused; normal idle locking resumes on leaving it. Record actual outcomes and remaining gaps in the [Stage 2 evidence](docs/stage-2.md).

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
