# Lauder

An open-source, Apple-only survival exploration game about three travellers finding belonging through the ruins of a futuristic world.

## Project status

The **Brooklyn Bridge opening is the only playable scene**. On 22 November 2026 the maintainer asked to keep the bridge and remove all other scenes and their unused systems before reconsidering what makes the game enjoyable. The combat arena, salvage yard and Relay Run are removed, along with their menu entries, test weapons, elevation, tactical combat and salvage machinery. This is a smaller starting point for the next design discussion, not an assignment to rebuild those experiments.

Miki, Tom and Laura cross the snowbound bridge together towards Manhattan, past the robot that guards the first tower, to the far end. The bridge keeps its movement, paired weapons, the first-tower guard fight, party switching, formations, orders, camera and controller/touch/keyboard inputs. Dialogue remains provisional. The [gameplay walkthrough](docs/gameplay-script.md) describes the current opening; the [prototype plan](docs/prototype-plan.md) records verification and the next gate.

**Current review follow-ups, 27 November 2026:** The maintainer asked Codex to address Claude’s GitHub findings. The [bounded fixes](docs/prototype-plan.md#claude-review-follow-ups--in-development) correct regrouping, hull destinations, tracking and touch-menu selection, restore story provenance and relocate old worktrees without data loss. [PR #187](https://github.com/RonildoBraga/lauder/pull/187) passes the full source check and three fresh rendered regression routes on `ae3519d`; it is unmerged and not uploaded. Build 36 remains the delivered preview. The newer [touch-parity follow-up](docs/prototype-plan.md#touch-parity--in-development) adds tap-to-target, the selected short Defend order hint and the Pause status choice. [PR #188](https://github.com/RonildoBraga/lauder/pull/188) passes the full check and a fresh touch-only fight on the baseline-size Simulator; it remains unmerged and unuploaded.

**Guard damage and feedback — verified implementation, 27 November 2026:** After asking for every successful hit to cause damage, the maintainer said **“Proceed with your recommendations”**. [Issue #183](https://github.com/RonildoBraga/lauder/issues/183) records the authorised revision on `codex/guard-damage`, based on [PR #175](https://github.com/RonildoBraga/lauder/pull/175), source `5421873`: one guard health pool, useful normal attacks, optional matched-weapon weak-point bonuses, ordinary companion fire under Attack and readable white/red damage feedback. The [damage contract](docs/damage-feedback.md) defines the scope and starting tuning; [source and rendered checks passed on `533f012`](docs/prototype-plan.md#guard-damage-and-feedback--in-development), recorded in [PR #184](https://github.com/RonildoBraga/lauder/pull/184). Earlier preview results below do not validate this revision. That implementation assignment did not authorise merge or release; the maintainer subsequently requested the [build 36 TestFlight preview](docs/prototype-plan.md#build-36-testflight-preview), now verified as available to the existing internal testers. Physical acceptance and merge remain separate gates.

**Companion autonomy, 26 November 2026:** After playing the strategic guard in [TestFlight build 33](docs/prototype-plan.md#build-33-testflight-preview), the maintainer asked for independent companions and chose **“Companions can complete the weakpoint steps too”**. The [bounded revision](docs/companion-autonomy.md) is implemented on `codex/companion-autonomy`, with source and rendered Simulator verification recorded in the [prototype plan](docs/prototype-plan.md#companion-autonomy--in-development). The player retains the leader; nearby companions may supply their own native guard contributions once the fight is engaged, respecting orders, cover and retreat. Switching remains available, but is no longer required for every contribution. The west bypass stays available. The [build 34 preview](docs/prototype-plan.md#build-34-testflight-preview) is delivered; physical acceptance and merge remain separate gates.

**Delivered preview:** Internal TestFlight **0.1.0 (36)** is available from archive source `2db6130` through [PR #185](https://github.com/RonildoBraga/lauder/pull/185). It carries [PR #184](https://github.com/RonildoBraga/lauder/pull/184)'s shared guard health, optional weakness bonuses, ordinary companion attacks and white/red damage feedback, plus the preceding bridge cover/spacing and retaliation changes. Full source checks, signed archive verification, Apple processing and access for the existing internal testers passed, with membership unchanged. The [build 36 delivery record](docs/prototype-plan.md#build-36-testflight-preview) records exact source, review, CI, processing and en-AU test-note readback. Update Lauder in TestFlight to try it. Availability does not establish physical installation, controls, balance or performance, and no preview PR was merged. Earlier build 35/34/33 results remain historical evidence below.

**Explicit squad commands:** The maintainer clarified that companions attack only when ordered. The squad now starts in **Defend**. D-pad/arrow **Up** orders **Attack**; **Down** orders **Defend**, stopping companion fire and recalling them using nearby cover. The touch ground menu offers both stances too. Leader Fire does not arm companion attacks. The [prototype plan](docs/prototype-plan.md#companion-autonomy--in-development) distinguishes the previous checks from validation of this correction.

**Guard retaliation — delivered preview:** After build 34, the maintainer confirmed **“The Attack and Defend controls are working”** and authorised [issue #171](https://github.com/RonildoBraga/lauder/issues/171). The basic command feedback does not establish every physical input path or sustained performance. The engaged guard may choose a visible recent attacker between warned cycles, name the threatened member and retain that target through the cycle. The [bounded contract](docs/guard-retaliation.md) preserves committed aim, current damage/timing, explicit commands and the west bypass. Source and Simulator verification are recorded in the [prototype plan](docs/prototype-plan.md#guard-retaliation--in-development). The maintainer subsequently authorised the [build 35 internal comparison](docs/prototype-plan.md#build-35-testflight-preview); phone acceptance and merge remain pending.

**Bridge cover and spacing — verified implementation, 27 November 2026:** The maintainer authorised [issue #174](https://github.com/RonildoBraga/lauder/issues/174): improve the bridge's cover and companion spacing. [PR #175](https://github.com/RonildoBraga/lauder/pull/175), on `codex/bridge-cover-spacing`, adds two simple shelters and reserved companion destinations with the same guard damage, timing and weakpoints. Source `60428d3` passed the full check, all eleven headless routes and four rendered Simulator routes, including separate real covered positions through Pause/Resume and later native Attack. The [prototype plan](docs/prototype-plan.md#bridge-cover-and-spacing--in-development) records injuries, timings and remaining transient overlaps. The [bounded contract](docs/bridge-cover-spacing.md) preserves explicit orders, native collision/rays and the quiet bypass. The shelters and reserved destinations are included in the [build 36 preview](docs/prototype-plan.md#build-36-testflight-preview). Phone performance and acceptance remain unverified; merge and further releases keep their own gates.

Swift, RealityKit and SwiftUI remain the technical direction ([ADR 0001](docs/decisions/0001-engine.md)). Blender remains the source of the bridge and character models ([ADR 0002](docs/decisions/0002-blender-source-of-truth.md)). Use simple shapes and colours until a concrete gameplay need warrants art work.

The last build archived from `main` itself is **TestFlight 0.1.0 (29)**, app/archive source `ea47e2b`, with the Blender environment, camera B and C robot guard. The source-bound standard check and signed archive verification passed. Apple confirmed successful processing and availability to the existing internal testers, with membership unchanged. The [prototype plan](docs/prototype-plan.md#testflight-delivery) records exact sources, checks and delivery proof, including the earlier structural-preparation build **0.1.0 (28)**. Physical-phone installation, behaviour, performance and enjoyment remain unverified for build 29. Build **0.1.0 (30)** was a pre-merge playtest of draft [PR #154](https://github.com/RonildoBraga/lauder/pull/154)'s detailed Miki, a route that the pawns below replace; it was never part of `main`. Build **0.1.0 (32)** was made before merge from [PR #158](https://github.com/RonildoBraga/lauder/pull/158)'s head `0a50613`, with the four changes below. They merged into `main` on 26 November 2026 with the same app sources, so build 32 matches the merged baseline before the strategic guard branch; its [playtest](docs/prototype-plan.md#build-32-playtest) is recorded in the prototype plan.

**Paired weapons, 26 November 2026:** Each character now carries [two weapons](docs/decisions/0021-paired-weapons.md) and switches between them with R1, RB, T or the touch **Swap** button. Miki has a long rifle and an assault rifle, Laura a shotgun and an energy sword that turns shots from in front of her, and Tom a minigun and a shield dome that protects everyone inside it. Rounds are no longer counted beyond each magazine. The [prototype plan](docs/prototype-plan.md#paired-weapons) records the checks. On the phone, in TestFlight build 32, the maintainer said the weapons and controls feel right; the guard fight's balance is still to tune.

**Three together, 26 November 2026:** The maintainer simplified the opening: the three start together at the Brooklyn end, and the first-tower guard is the bridge's only fight. The supply case's search, the knife attacker's ambush, Tom's introduction and Laura's rescue are gone. The [prototype plan](docs/prototype-plan.md#three-together) records the checks. On the phone, in TestFlight build 32, the maintainer said the weapons and controls feel right.

**Controls pass, 26 November 2026:** After seeing a map of the controller, the maintainer asked for three changes. L1 or LB alone now switches leader, going round the party, which leaves R1 / RB free. The status panel's toggle has moved from Circle / B into the pause menu. A press of the right stick, R3 or RS, [locks the aim](docs/decisions/0020-lock-on.md) on a hostile and marks them with a red ring; the next press moves the lock on, and two quick presses let go. The [prototype plan](docs/prototype-plan.md#controls-pass) records the checks. On the phone, in TestFlight build 32, the maintainer said the weapons and controls feel right.

**Pawns and dodge roll, 25 November 2026:** In play the party is only about 18 points tall on the phone. The maintainer therefore replaced its figures with [pawns](art/party/README.md): one shared body, told apart by colour and headwear, with one skin tone for all three. They have no rig; the game bobs, rocks and leans them as they walk. The leader can also [dodge-roll](docs/decisions/0019-dodge-roll.md) 3 m while hostile shots pass through them, with Square, X, Space or the touch **Roll** button. The roll's values are starting points to tune. The [prototype plan](docs/prototype-plan.md#pawns-and-dodge-roll) records the checks. On the phone, in TestFlight build 32, the maintainer said the weapons and controls feel right.

**Robot integration, 23 November 2026:** The maintainer accepted C's form and motion and assigned replacing the first human shooter on the bridge, with movement and shooting verified in Simulator. That pass implemented the first-tower guard, bounded movement, committed alternating burst and supply-case/bypass handoff. The knife attacker and Tom/Laura recruitment were still present at that stage; the Three together change above removed them on 26 November. [Concept A](art/robot/bulk-studies/README.md#a--armoured-crawler) stays a possible later different-weapon variant; concept B is unselected. Prototype timing and balance are starting values, not settled design. The [encounter record](docs/encounters/bridge-spider-bot.md) preserves that baseline.

**Bridge environment, 23 November 2026:** The maintainer first assigned the scene in Blender, deferring the robot. The [level source](blender/levels/README.md) now has low-poly pointed arches, weathered stone, dark cable fans and low off-route snow facets, guided by the selected concept. That environment pass preserved the gameplay layout and camera. Its verification is recorded in the [prototype plan](docs/prototype-plan.md#bridge-environment-pass).

**Camera and robot, 23 November 2026:** Camera B remains approved: offset `[0, 56, 44]`, 22° lens. C's [Blender source](blender/assets/spider-bot-heavy/README.md) retains the accepted form, [motion studies](blender/assets/spider-bot-heavy/motion-preview.mp4) and shared symmetric leg components. Runtime geometry and joint/muzzle measurements come from that source; fixed-step combat owns decisions and the presenter poses the loaded parts from actual movement and firing. The standard check and rendered Simulator guard, retry and full-opening routes pass; the [prototype plan](docs/prototype-plan.md#c-robot-on-the-bridge) records the evidence. This work is included in TestFlight build 29; physical-phone behaviour and performance remain unverified.

## Start here

- [Story bible](docs/story/story-bible.md): ensemble foundations, proposed identities, enhancements and Chapter One.
- [Gameplay walkthrough](docs/gameplay-script.md): the retained bridge and the distinction between it and future design ideas.
- [Architecture](docs/architecture.md): ownership, input, movement, weapons, encounters and lifecycle.
- [Prototype plan](docs/prototype-plan.md): retained scope, controls, checks and the design gate.
- [Strategic guard](docs/strategic-guard.md): the delivered dismantling prototype and its current revision.
- [Guard damage and feedback](docs/damage-feedback.md): shared health, optional weaknesses, companion fallback and readable damage numbers.
- [Companion autonomy](docs/companion-autonomy.md): the authorised independent-companion scope and verification gates.
- [Guard retaliation](docs/guard-retaliation.md): the current target-selection and warning comparison.
- [Touch controls](docs/touch-controls.md): the phone's controller-free input path.
- [Visual direction](docs/visual-direction.md): the frozen minimalist low-poly reference.
- [Art studies](art/README.md): the selected bridge and robot concept C, earlier references and alternatives, with prompts and source credits.
- [First-tower robot encounter](docs/encounters/bridge-spider-bot.md): implemented guard behaviour, its bypass and remaining playtest questions.
- [The Quiet Yard](docs/encounters/the-quiet-yard.md): an unimplemented encounter proposal, retained for narrative reference, not an active level or assignment.

The player controls one character at a time, switching leadership while the other two follow. Miki, Laura and Tom travel together from the start; their connections emerge through play. Their backgrounds, enhancement histories and onward journey remain working story proposals. Removing prototype scenes does not settle or discard those narrative questions.

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

The focused runtime/contract improvements in [ADR 0018](docs/decisions/0018-runtime-boundaries.md) are implemented in [PR #125](https://github.com/RonildoBraga/lauder/pull/125), with reproducible release tooling in [PR #126](https://github.com/RonildoBraga/lauder/pull/126). The bounded guard-damage revision above is implemented and available in TestFlight build 36. The next gate is a phone comparison of whether ordinary attacks and optional weaknesses make the bridge fight more enjoyable. Other story proposals and historical plans are not implementation assignments. Further scenes, systems and art need an explicit task.

## Licence

[MIT](LICENSE) applies to original code, story and documentation unless a file or directory states otherwise. Third-party material retains its own licence and attribution notices.
