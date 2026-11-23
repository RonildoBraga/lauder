# Lauder

An open-source, Apple-only survival exploration game about three travellers finding belonging through the ruins of a futuristic world.

## Project status

The **Brooklyn Bridge opening is the only playable scene**. On 22 November 2026 the maintainer asked to keep the bridge and remove all other scenes and their unused systems before reconsidering what makes the game enjoyable. The combat arena, salvage yard and Relay Run are removed, along with their menu entries, test weapons, elevation, tactical combat and salvage machinery. This is a smaller starting point for the next design discussion, not an assignment to rebuild those experiments.

Miki crosses the snowbound bridge towards Manhattan, meets Tom through a fight and ambush, helps Laura, and reaches the far end with both companions. The bridge keeps its movement, native weapons, encounters, recruitment, party switching, formations, orders, camera and controller/touch/keyboard inputs. Dialogue remains provisional. The [gameplay walkthrough](docs/gameplay-script.md) describes the current opening; the [prototype plan](docs/prototype-plan.md) records verification and the next gate.

Swift, RealityKit and SwiftUI remain the technical direction ([ADR 0001](docs/decisions/0001-engine.md)). Blender remains the source of the bridge and character models ([ADR 0002](docs/decisions/0002-blender-source-of-truth.md)). Use simple shapes and colours until a concrete gameplay need warrants art work.

The latest TestFlight delivery is the bridge-only prototype with the Blender environment, camera B and the previous C robot form: **0.1.0 (29)**, app/archive source `ea47e2b`. The source-bound standard check and signed archive verification passed. Apple confirmed successful processing and availability to the existing internal testers, with membership unchanged. The [prototype plan](docs/prototype-plan.md#testflight-delivery) records exact sources, checks and delivery proof, including the earlier structural-preparation build **0.1.0 (28)**. Physical-phone installation, behaviour, performance and enjoyment remain unverified for build 29.

**Robot integration, 23 November 2026:** The maintainer accepted C's form and motion and assigned replacing the first human shooter on the bridge, with movement and shooting verified in Simulator. The first-tower guard, bounded movement, committed alternating burst and supply-case/bypass handoff are implemented. The later knife attacker and Tom/Laura recruitment remain. [Concept A](art/robot/bulk-studies/README.md#a--armoured-crawler) stays a possible later different-weapon variant; concept B is unselected. Prototype timing and balance are starting values, not settled design. The [encounter record](docs/encounters/bridge-spider-bot.md) describes the implementation and remaining playtest questions.

**Bridge environment, 23 November 2026:** The maintainer first assigned the scene in Blender, deferring the robot. The [level source](blender/levels/README.md) now has low-poly pointed arches, weathered stone, dark cable fans and low off-route snow facets, guided by the selected concept. That environment pass preserved the gameplay layout and camera. Its verification is recorded in the [prototype plan](docs/prototype-plan.md#bridge-environment-pass).

**Camera and robot, 23 November 2026:** Camera B remains approved: offset `[0, 56, 44]`, 22° lens. C's retained [motion reel](blender/assets/spider-bot-heavy/motion-preview.mp4) records the earlier accepted form and rig studies. Runtime geometry and joint/muzzle measurements come from Blender; fixed-step combat owns decisions and the presenter poses the loaded parts from actual movement and firing. The original standard check and rendered Simulator guard, retry and full-opening routes passed; the [prototype plan](docs/prototype-plan.md#c-robot-on-the-bridge) records that evidence for TestFlight build 29. Physical-phone behaviour and performance remain unverified.

**C modelled finish, pending review:** The maintainer authorised a Blender pass guided by the [finish study](art/robot/finish-study/README.md). The current [source and four PNG previews](blender/assets/spider-bot-heavy/README.md) have a real recessed red-sensor pocket and stepped roof/cannon plates, retaining the accepted body proportions, plain legs, smaller guns, five matte materials and rig/muzzle transforms. The preceding charcoal/smaller-cannon revision at `2df4b45` passed the full check and rendered first-fight test (35/35); this later geometry pass also passes the full check and a fresh rendered first-fight test (35/35). Its visual review, merge and release remain pending. Build 29 retains the previous form. A's later variation remains deferred.

**C style study:** The AI-generated [finish study](art/robot/finish-study/README.md) supplied the direction for the assigned Blender pass. It remains a visual reference, separate from the actual mesh and its verification. Snow and wear remain deferred.

## Start here

- [Story bible](docs/story/story-bible.md): ensemble foundations, proposed identities, enhancements and Chapter One.
- [Gameplay walkthrough](docs/gameplay-script.md): the retained bridge and the distinction between it and future design ideas.
- [Architecture](docs/architecture.md): ownership, input, movement, weapons, encounters and lifecycle.
- [Prototype plan](docs/prototype-plan.md): retained scope, controls, checks and the design gate.
- [Touch controls](docs/touch-controls.md): the phone's controller-free input path.
- [Visual direction](docs/visual-direction.md): the frozen minimalist low-poly reference.
- [Art studies](art/README.md): the selected bridge and robot concept C, earlier references and alternatives, with prompts and source credits.
- [First-tower robot encounter](docs/encounters/bridge-spider-bot.md): implemented guard behaviour, supply-case/bypass progression and remaining playtest questions.
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
    combat/                      Weapon, spread, aiming, ray geometry, hostile rules and RobotGuard
    world/                       Bodies, squad movement, presentation, WorldCamera and CameraRig
    content/
      Level.swift                Typed bridge and test-fixture data
      LevelLayout.swift          Blender layout schema
      BrooklynBridge.swift       Bridge names, encounters, interactions and dialogue cues
      BrooklynBridgeLayout.swift Generated bridge layout
      RobotModelGeometry.swift   Generated robot joints, bounds and gun measurements
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
  encounters/                    Encounter records and narrative proposals
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
