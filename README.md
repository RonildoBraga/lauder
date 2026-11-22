# Lauder

An open-source, Apple-only survival exploration game about three travellers finding belonging through the ruins of a futuristic world.

## Project status

The **Brooklyn Bridge opening is the only playable scene**. On 22 November 2026 the maintainer asked to keep the bridge and remove all other scenes and their unused systems before reconsidering what makes the game enjoyable. The combat arena, salvage yard and Relay Run are removed, along with their menu entries, test weapons, elevation, tactical combat and salvage machinery. This is a smaller starting point for the next design discussion, not an assignment to rebuild those experiments.

Miki crosses the snowbound bridge towards Manhattan, meets Tom through a fight and ambush, helps Laura, and reaches the far end with both companions. The bridge keeps its movement, native weapons, encounters, recruitment, party switching, formations, orders, camera and controller/touch/keyboard inputs. Dialogue remains provisional. The [gameplay walkthrough](docs/gameplay-script.md) describes the current opening; the [prototype plan](docs/prototype-plan.md) records verification and the next gate.

Swift, RealityKit and SwiftUI remain the technical direction ([ADR 0001](docs/decisions/0001-engine.md)). Blender remains the source of the bridge and character models ([ADR 0002](docs/decisions/0002-blender-source-of-truth.md)). Use simple shapes and colours until a concrete gameplay need warrants art work.

The bridge-only prototype's structural preparation is delivered in **TestFlight 0.1.0 (28)**, app/archive source `7158f29`. The standard check and rendered Simulator checks passed; source review has no outstanding findings. Apple confirmed successful processing and availability to the existing internal testers, with membership unchanged. The [prototype plan](docs/prototype-plan.md#verification-and-performance) records exact sources, checks and delivery proof. Physical-phone behaviour, performance and enjoyment remain unverified for this build.

## Start here

- [Story bible](docs/story/story-bible.md): ensemble foundations, proposed identities, enhancements and Chapter One.
- [Gameplay walkthrough](docs/gameplay-script.md): the retained bridge and the distinction between it and future design ideas.
- [Architecture](docs/architecture.md): ownership, input, movement, weapons, encounters and lifecycle.
- [Prototype plan](docs/prototype-plan.md): retained scope, controls, checks and the design gate.
- [Touch controls](docs/touch-controls.md): the phone's controller-free input path.
- [Visual direction](docs/visual-direction.md): the frozen minimalist low-poly reference.
- [Art studies](art/README.md): proposed bridge concept images for review before scene changes.
- [The Quiet Yard](docs/encounters/the-quiet-yard.md): an unimplemented encounter proposal, retained for narrative reference, not an active level or assignment.

The player controls one character at a time, switching leadership while the other recruited characters follow. Miki, Laura and Tom meet as strangers; their connections emerge through play. Their backgrounds, enhancement histories and onward journey remain working story proposals. Removing prototype scenes does not settle or discard those narrative questions.

## Project structure

```text
apple/
  Lauder.xcodeproj/              App/test targets and shared Lauder scheme
  sources/
    app/                         App entry, world ownership and bundle configuration
    interface/                   HUD, controller/keyboard/touch input and InputRules
    gameplay/                    Session authority, BridgeProgress and EncounterSimulation
    combat/                      Weapon, spread, aiming, ray geometry and hostile rules
    world/                       Bodies, squad movement, presentation, WorldCamera and CameraRig
    content/
      Level.swift                Typed bridge and test-fixture data
      LevelLayout.swift          Blender layout schema
      BrooklynBridge.swift       Bridge names, encounters, interactions and dialogue cues
      BrooklynBridgeLayout.swift Generated bridge layout
      BrooklynBridge.usdz        Exported bridge scene
      MissionScript.swift        Provisional bridge conversations
      StoryBeat.swift            Authored progression markers independent of the session
      models/                    Exported party/hostile figures
      sounds/                    Generated combat sounds
  tests/                         Bridge and shared input/movement/weapon regressions
    support/                     Test-only navigation/range geometry and headless helpers
  scripts/                       Simulator tools, contract checks, assets and TestFlight CLI
blender/
  levels/                        Bridge Blender source
  assets/                        Character model sources
  extensions/lauder_levels/      Export extension and tests
art/                             Concept proposals, previews and generation provenance
docs/                            Current design, architecture and prototype plan
  story/                         Story bible
  encounters/                    Unimplemented narrative proposals
  decisions/                     Accepted decisions and clearly marked historical experiments
scripts/check                    Contract, Blender, asset, formatting, app-build and Swift checks
.github/                         Pull request template and standard-check workflow
```

Manually maintained folders use lowercase names; Swift filenames use PascalCase. Read [CONTRIBUTING.md](CONTRIBUTING.md) for naming, validation, Blender authoring, licensing and TestFlight procedures. Public documentation uses relative paths and contains no signing secrets or private device identifiers.

## Contribute

Open `apple/Lauder.xcodeproj` with the shared `Lauder` scheme. Use Simulator for daily iteration and `./scripts/check` before a focused pull request. Coding agents should also read [AGENTS.md](AGENTS.md).

The focused runtime/contract improvements in [ADR 0018](docs/decisions/0018-runtime-boundaries.md) are implemented in [PR #125](https://github.com/RonildoBraga/lauder/pull/125), with reproducible release tooling in [PR #126](https://github.com/RonildoBraga/lauder/pull/126). The next gameplay task remains agreeing on an enjoyable core loop using the bridge as a small test space. Story proposals and historical plans are not implementation assignments. Further scenes, systems and art need an explicit task.

## Licence

[MIT](LICENSE) applies to original code, story and documentation unless a file or directory states otherwise. Third-party material retains its own licence and attribution notices.
