# Lauder

An open-source, Apple-only survival exploration game about three travellers finding belonging through the ruins of a futuristic world.

## Project status

The **Brooklyn Bridge opening is the only playable scene**. On 22 November 2026 the maintainer asked to keep the bridge and remove all other scenes and their unused systems before reconsidering what makes the game enjoyable. The combat arena, salvage yard and Relay Run are removed, along with their menu entries, test weapons, elevation and salvage machinery. The later C robot pursuit/cover assignment below is limited to the retained bridge. This is a smaller starting point for the next design discussion, not an assignment to rebuild those experiments.

Miki crosses the snowbound bridge towards Manhattan, meets Tom through a fight and ambush, helps Laura, and reaches the far end with both companions. The bridge keeps its movement, native weapons, encounters, recruitment, party switching, formations, orders, camera and controller/touch/keyboard inputs. Dialogue remains provisional. The [gameplay walkthrough](docs/gameplay-script.md) describes the current opening; the [prototype plan](docs/prototype-plan.md) records verification and the next gate.

Swift, RealityKit and SwiftUI remain the technical direction ([ADR 0001](docs/decisions/0001-engine.md)). Blender remains the source of the bridge and character models ([ADR 0002](docs/decisions/0002-blender-source-of-truth.md)). Use simple shapes and colours until a concrete gameplay need warrants art work.

The latest TestFlight delivery is the bridge-only prototype with the Blender environment, camera B and the previous C robot form: **0.1.0 (29)**, app/archive source `ea47e2b`. The source-bound standard check and signed archive verification passed. Apple confirmed successful processing and availability to the existing internal testers, with membership unchanged. The [prototype plan](docs/prototype-plan.md#testflight-delivery) records exact sources, checks and delivery proof, including the earlier structural-preparation build **0.1.0 (28)**. Physical-phone installation, behaviour, performance and enjoyment remain unverified for build 29.

**Robot integration, 23 November 2026:** The maintainer accepted C's form and motion and assigned replacing the first human shooter on the bridge, with movement and shooting verified in Simulator. The first-tower guard, bounded movement, committed alternating burst and supply-case/bypass handoff are implemented. The later knife attacker and Tom/Laura recruitment remain. [Concept A](art/robot/bulk-studies/README.md#a--armoured-crawler) stays a possible later different-weapon variant; concept B is unselected. Prototype timing and balance are starting values, not settled design. The [encounter record](docs/encounters/bridge-spider-bot.md) describes the implementation and remaining playtest questions.

**Bridge environment, 23 November 2026:** The maintainer first assigned the scene in Blender, deferring the robot. The [level source](blender/levels/README.md) now has low-poly pointed arches, weathered stone, dark cable fans and low off-route snow facets, guided by the selected concept. That environment pass preserved the gameplay layout and camera. Its verification is recorded in the [prototype plan](docs/prototype-plan.md#bridge-environment-pass).

**Camera and robot, 23 November 2026:** Camera B remains approved: offset `[0, 56, 44]`, 22° lens. C's retained [motion reel](blender/assets/spider-bot-heavy/motion-preview.mp4) records the earlier accepted form and rig studies. Runtime geometry and joint/muzzle measurements come from Blender; fixed-step combat owns decisions and the presenter poses the loaded parts from actual movement and firing. The original standard check and rendered Simulator guard, retry and full-opening routes passed; the [prototype plan](docs/prototype-plan.md#c-robot-on-the-bridge) records that evidence for TestFlight build 29. Physical-phone behaviour and performance remain unverified.

**C lowered hips and Blender motion review:** After the slimmer-leg pass, the maintainer assigned lowering the hip mounts **15 cm**, retaining the body, guns and mesh geometry while rebaking the leg poses to preserve the feet's paths. The current [source and four PNG previews](blender/assets/spider-bot-heavy/README.md) show that change. That canonical revision at `74f69e9` passed the full check, motion/contact audits and rendered first-fight (35/35). The separate [dormant-to-pursuit Blender study](blender/assets/spider-bot-heavy/README.md#dormant-to-pursuit-blender-study) now tests the assigned heavier pursuit: roughly twice the foot travel per step, slower swings, firm plants and restrained contact-driven compression. Its fresh 240 Hz study audit passes. This preview changes no canonical model, runtime gait or wake/approach trigger. Visual review, merge and release remain pending. Build 29 retains the previous form. A's later variation remains deferred.

**C walking and tactics, 23 November 2026:** The maintainer assigned [the video’s damped walking response](https://www.youtube.com/watch?v=KPoeNZZ6H4s) and a robot that can pursue its opponent and take cover. This focused runtime change gives RobotGuard fixed-step ownership of the gait and body response; the same pose drives feet, visible joints and shot origins. Bounded pursuit uses sight and last-known positions, while damage can prompt a reachable tower-cover position, a short hold and a warned return. The existing eight Simulator routes remain, with `first-fight` extended to observe pursuit, real cover and reengagement. The full standard check and rendered `first-fight` (50/50), `fight-retry` (15/15) and `opening` (56/56) pass on the frozen runtime source; the [prototype plan](docs/prototype-plan.md#c-runtime-walking-pursuit-and-cover) records the evidence. The Blender study at `09feda6` remains a separate keyframed preview; no new scene, controls, weapons, merge, TestFlight upload or phone-performance claim is included.

**C style study:** The AI-generated [finish study](art/robot/finish-study/README.md) supplied the direction for the assigned Blender pass. It remains a visual reference, separate from the actual mesh and its verification. Snow and wear remain deferred.

**Playable character study, 23 November 2026:** The maintainer assigned character models and animations and selected more stylised proportions with larger heads. The retained [Blender party study](blender/studies/party-characters/README.md) contains original Miki, Laura and Tom candidates, distinct winter clothing, a shared 17-bone skeleton and nine reusable motion clips. Each mesh is below 400 triangles. Saved-source motion checks and a native RealityKit import/deformation proof passed for that asset review. It preceded the integration assignment below and remains a separate review reference.

**Party animation integration, 24 November 2026:** The maintainer subsequently said to proceed, then requested distinct running and sneaking cycles and chose light stick pressure with a keyboard modifier for sneaking. The accepted models now use their canonical files and one [shared animation source](blender/animations/README.md). Joint presentation follows resolved movement and accepted combat reactions at the existing simulation step; weapons and gameplay retain their authority. Light stick pressure sneaks, medium pressure walks, full pressure runs, and Shift with WASD supplies light keyboard pressure. The full local check and rendered combat, retry, opening and orders routes pass; direct Simulator keyboard checks verify Shift-sneak, full-speed movement and Pause. Enemy hearing and detection remain separate design work. Review, merge, phone validation and release remain pending. Exact verification is recorded in the [prototype plan](docs/prototype-plan.md#party-runtime-animation-integration).

**Angular character blockout, 24 November 2026:** The maintainer selected the [angular graphic trio](art/characters/angular-study/README.md), approved the [Miki modelling references](art/characters/angular-study/miki-reference/README.md), and assigned a separate [unrigged A-pose blockout](blender/studies/miki-reference-blockout/README.md). The earlier [four-pose study](blender/studies/miki-angular/README.md) remains a comparison. Codex's head refinement and Claude's subsequent head/hair/neck rebuild at `930d51c` were not visually accepted; [issue #141](https://github.com/RonildoBraga/lauder/issues/141) records the rejected passes and handover. Technical geometry checks establish neither likeness nor appeal.

**Current head-only trial:** Following independent research, the maintainer assigned a bounded comparison of a specialist image-to-3D head and Blender's CC0 foundation. The [bald Miki inputs](art/characters/angular-study/miki-head-pilot/README.md) and [native Blender baseline](blender/studies/miki-head-pilot/README.md) distinguish illustrations from actual mesh renders. One free Tripo P2.0 head has been generated and inspected in its 3D viewer; [the trial record](blender/studies/miki-head-pilot/tripo-trial.md) documents its visible defects and subscription-gated FBX export. No file has been downloaded or inspected in Blender, so the matched comparison remains incomplete. Visual head acceptance precedes separate hair, skeleton or animation fitting. Canonical models, shared motion, runtime/gameplay, Laura and Tom remain unchanged; no purchase, installation, merge or release is included.

**Miki field-navigation direction, 24 November 2026:** The maintainer agreed Miki's [field navigator/explorer role](docs/story/story-bible.md#tablet-and-field-navigation) and authorised a tablet/carrying design pass. Miki interprets incomplete records and observed clues, Laura checks present access, and Tom assesses practical group passage. The earlier [Blender review](blender/studies/miki-angular/README.md) develops the field-tool shape and four static inspection/carry/stow/weapon-ready poses; the body remains rough. The [first-tower vignette](docs/gameplay-script.md#mikis-tablet-exploration-vignette-proposal) and precise gameplay/UI/input behaviour remain proposals, with no runtime tablet feature built.

**Miki sniper direction, 24 November 2026:** The maintainer specified Miki as a sniper able to use different compatible sniper rifle types, alongside her field-navigator role. The [rifle-family design](docs/story/story-bible.md#sniper-rifle-family) proposes scout, balanced and heavy alternatives with one carried rifle at a time; the balanced rifle is the default authoring model. The earlier [Blender review composition](blender/studies/miki-angular/README.md) links an independent [static character source](blender/studies/miki-angular/character/miki-angular-character.blend), three separate rifle sources and a separate field slate. Attachment transforms belong to the review composition; the character file contains no weapon or device. This is an authoring split, with no new rig or runtime attachment system. Variant fitting, tuning and equipment flow remain open, with no new interface or runtime weapon feature built. The playable bridge retains its carbine and existing combat rules.

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
  animations/                    Shared party skeleton, Actions and export timeline
  studies/                       Unregistered Blender asset/animation studies
    miki-angular/                Earlier linked Miki/equipment review composition
      character/                 Independent static Miki body/clothing/holster/sling poses
    miki-reference-blockout/      Fresh unrigged reference-led A-pose study
    miki-head-pilot/              Head-only CC0 foundation and pending generator comparison
    equipment/                   Independent field slate and Scout/Precision/Heavy rifles
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
