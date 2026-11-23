# Lauder — bridge-only prototype

**Updated:** 23 November 2026

**Status:** The maintainer requested a smaller starting point before a gameplay revamp: keep the Brooklyn Bridge and delete the other playable scenes and their unused systems. [ADR 0017](decisions/0017-bridge-only-reset.md) records the boundary. New mechanics and scenes await a design decision.

The bridge concept and camera B remain selected. The maintainer chose the robot to **replace the first human shooter**, with Miki alone. After rejecting the first Blender blockout's proportions and reviewing the bulkier [concept options](../art/robot/bulk-studies/README.md), the maintainer selected **C, Heavy walker**, for a new Blender proportion study. A is retained for a possible later different-weapon variant, which is not assigned; B is unselected. The current assignment is model form first, without animation or runtime combat. The [first-tower behaviour proposal](encounters/bridge-spider-bot.md) remains the separate combat design discussion; its rules and tuning are not approved or implemented.

## Structural preparation

The approved structural preparation is merged: [PR #125](https://github.com/RonildoBraga/lauder/pull/125) separates camera motion and bridge progression, clarifies encounter naming, splits combat values into cohesive files and adds narrow declaration checks with CI. [PR #126](https://github.com/RonildoBraga/lauder/pull/126) adds reproducible TestFlight tooling. [ADR 0018](decisions/0018-runtime-boundaries.md) records the boundaries. Gameplay and story are unchanged; the next gameplay task is the design gate below.

## Purpose and scope

Use the retained bridge to decide what is enjoyable before expanding again. This cleanup preserves its existing opening, party movement, native weapons and input paths. It does not redesign the story or author a replacement core loop.

The story's foundations remain in the [story bible](story/story-bible.md). Exploration and salvage lead the intended game, with occasional combat; the current opening only samples movement, a small fight, a body search and recruitment. Later narrative proposals are reference material, not playable content or assignments.

## The opening

The [walkthrough](gameplay-script.md#the-brooklyn-bridge-opening) follows Miki from the Brooklyn end to Manhattan:

1. Move and look while alone on the snowbound bridge.
2. Meet the stranger at the first tower. His first shot deliberately misses; fight using the tower as cover. A third hit retries that fight.
3. Search the body for rounds and a medical kit. A scripted ambush introduces Tom, who joins afterwards.
4. Find Laura, help her with the kit and hear her name. She joins after the short exchange.
5. Cross the second tower with both companions. Switch leaders, try Close/Spread/Column and move/hold orders, then gather at the Manhattan end.

Only the bridge is available. Pause has Resume, Restart and Vibration. There is no alternate-scene selector, weapon bench, endless spawn, automatic combat cover, companion auto-fire, grenade, signature, elevation or salvage-repair system.

## Input and interaction contract

| Intent | PS5 / Xbox | Touch | Keyboard |
|---|---|---|---|
| Move active character | Left stick | Bottom-left analog stick | WASD |
| Contextual action, advance dialogue or confirm menu | Cross / A | Look, Search, Help, Continue, or Restart while paused | E |
| Next leader, after someone joins | R1 / RB | Next: name | Q |
| Previous leader | L1 / LB | Next cycles | Z |
| Change formation with two companions; call ordered companions back first | Triangle / Y | Formation / Follow | R |
| Both go / left member / right member / both hold | D-pad up / left / right / down | Hold on ground, then Both / a name / Hold | Arrow keys |
| Draw and fire the leader's native weapon; hold to fire, automatic reload | R2 / RT | Fire with assisted aim | F |
| Aim apart from movement | Right stick | Assisted aim | I, K, J, L |
| Pause / Resume | Options / Menu | Pause / Resume | Escape |
| Choose Resume, Restart or Vibration while paused | Stick or D-pad up/down, then Cross / A | Resume, Restart or Vibration | W/S or up/down, then E |
| Hide/show status panel | Circle / B | Always shown | H |

Touch is automatic without an extended controller. An attached controller is preferred unless **Use touch controls** is chosen; **Use controller** returns to it. Keyboard remains available. These sources share InputRules and session authority. Xbox uses the shared extended-gamepad path; hardware delivery remains unverified.

Switching preserves positions and progress; held movement can continue on the new leader. Next wins over Previous in one sample. Switch, formation and order commands consume a simultaneous action. Dialogue and Pause consume gameplay edges rather than queueing them. Pause, interruptions, reconnection and source changes require neutral input; every button, key and finger must release, including a finger resting at stick centre.

Search and Help are revalidated on press against the leader's position and current progress. Searching the downed stranger happens once and starts the ambush. Helping Laura uses the shared medical kit and starts her recruitment exchange.

## Verification and performance

### Bridge environment pass

On 23 November 2026 the maintainer assigned the bridge scene in Blender before implementing the robot. The [level source](../blender/levels/README.md) and its USDZ now contain faceted pointed arches, weathered stone bases, four local cable fans and two low off-route snow meshes. The complete scene has 2,724 triangles, six materials and 33 used object/material partitions. These counts fit the authoring budget; they do not establish GPU draw calls or phone performance.

For that environment pass, the Gameplay, Camera and Lights collections were compared against a pre-edit snapshot, with object transforms, dimensions, properties and gameplay mesh vertices unchanged. Its generated Swift layout was byte-for-byte unchanged. The subsequent camera B adoption below changes only the camera data in that layout. The robot, supply handoff, narrative, weapons and controls were outside the environment pass.

`./scripts/check` passed the source/release contracts, all 51 Blender tests, sound fingerprints, Swift formatting, the app build and hosted Swift Testing, including all eight headless routes. Scene regressions retain the exact mesh inventory, require each tower's cable fans to fade with it while the other tower stays opaque, and check that the snow drifts remain low, off-route and noncolliding. Source/export fingerprints and all 61 local links in the six changed Markdown documents were checked.

Rendered Simulator runs passed `first-fight` **23/23** and `opening` **56/56**, with no failures or companion warning frames. Screenshots were inspected at the first fight, recruitment and both sides of the second tower; the party remains visible. The opening recorded 16.7 ms mean frame time and 16.8 ms p99 on Simulator. Private captures and logs are retained locally. This is Simulator evidence for the environment pass with its original camera, not a phone performance check or a new TestFlight delivery.

### Camera B selection and robot modelling

On 23 November 2026 the maintainer selected **B**, the higher, wider framing, after reviewing matched Simulator captures and crossing clips. The bridge's Blender camera and generated layout use offset `[0, 56, 44]` and vertical field of view **22°**. The existing 70% combat/aim lens rule therefore reaches **15.4°**. Geometry, lighting, controls and encounter rules are preserved. The world-marker scale expectation changes from 2.13 to 2.56; the projected-size and actual entity-scale checks remain intact.

The comparison used scene source `5cfb064` with temporary neutral capture holds and an additional waypoint in the existing opening route. Both camera options completed **67/67** steps with no failures or companion warning frames. Matched leader positions differed by less than 3 cm. The candidate's standard check passed with its camera-specific marker-scale expectation updated. These comparison copies are not exact-head captures of the canonical adoption. Validation of the canonical source is recorded with the adoption PR; phone performance remains unverified.

The maintainer then assigned the first robot's Blender blockout and movement poses, using the earlier [dark armed concept](../art/robot/README.md). That assignment produced the study below; it did not approve the proposed combat rules, supply-case handoff or replacement encounter.

The retained first [robot source](../blender/assets/spider-bot/README.md) has 298 triangles, 17 rigid mesh parts, five matte materials and no textures. A diagonal-pair walk study, a stepped brace, separate gun recoil and recovery are authored as object-transform keyframes; frame 1 is the neutral source pose. These measurements describe the rejected study, not a budget or proportion target for a new design. The model is not in `SPAWNED` or the bridge's exported scene. Existing exports sample one frame, so these are Blender motion studies rather than runtime animation clips. Its reference-derived source and preview retain CC BY 4.0 attribution.

On the canonical camera-B source, `./scripts/check` passed source/release contracts, 51 Blender tests, sound fingerprints, formatting, the app build and hosted Swift Testing, including all eight headless routes. The rendered `opening` passed **56/56**, with zero failures and companion warning frames. The robot passed standalone intake with zero problems. Neutral, front, side, brace/recovery and camera-B scale renders were inspected, alongside a rendered walk study. Post-save Blender/privacy checks also passed. These are technical checks, not visual approval. The maintainer subsequently rejected the blockout's proportions. Camera B remains adopted; the rejected model and motion are retained as reference, with runtime integration and phone performance unverified.

### Concept C proportion study

The maintainer selected **C, Heavy walker**, for the next Blender proportion study. The new source is `blender/assets/spider-bot-heavy/spider-bot-heavy.blend`, with its own [model README](../blender/assets/spider-bot-heavy/README.md). Model form and silhouette come first. The static source is built with 2,428 triangles, 41 mesh parts, five matte materials and no textures or animation. Exact vertex bounds are 2.83 × 2.51 × 2.35 m, a provisional review scale, not approved collision dimensions. Three-quarter, front, side, Miki-scale and camera-B Blender renders were inspected. Standalone intake reports zero problems; mesh inspection confirms closed solids and flat feet on z = 0. The technical checks above describe camera B and the rejected earlier model; they are not validation or visual approval of C. The standard `./scripts/check` also passed during this source-only modelling pass, including the app build and Simulator tests; no application or runtime level data changed. Final saved-file intake and geometry checks are recorded in the model README. No new rendered Simulator route or phone run was needed for this static authoring asset, which is not loaded by the game.

**A, Armoured crawler**, is retained for a possible later variant with different gun types; no A modelling or new weapon work is assigned. **B, Low siege bot**, is unselected. Camera B is a separate approved framing choice and remains unchanged. The C assignment does not approve metric dimensions, a triangle cap, animation, runtime combat or encounter tuning.

### Architecture checks

Integrated source `7158f29a44738cfd0188292ef3839d0338bd7c73` has the exact tree of reviewed source `c01dd03f6532063c959f2da9fcd663b3f9d393f3`. On `c01dd03`, `./scripts/check` passed formatting, the shared app build and hosted Swift suite, including all eight retained headless routes and six new camera/progression regression tests, plus **13 declaration-contract tests**, **28 offline release-contract tests**, **51 Blender tests** and **seven generated sounds**. [GitHub Actions run 45002053969](https://github.com/RonildoBraga/lauder/actions/runs/45002053969) passed on that reviewed source. Source review completed with no outstanding findings.

The retained headless routes are `bridge-walk`, `first-fight`, `fight-retry`, `ambush`, `laura`, `opening`, `formations` and `orders`.

Rendered Simulator checks on `b533e2ff8ee210eb030737293e47524ed008f47e` passed with no route failures or companion warning frames:

| Source | Route | Result |
|---|---|---:|
| `b533e2f` | `opening` | 56/56 |
| `b533e2f` | `orders` | 130/130 |

The app, Swift-test and Blender sources in those recordings are unchanged in integrated source `7158f29`; the recordings are not exact-head repository captures.

### TestFlight delivery

The source-bound standard check also passed on app/archive source `7158f29`. Its signed **0.1.0 (28)** Release archive passed bundle, signing-team, signature and matching-dSYM verification. At **2026-11-22 08:38:25 UTC**, Apple's read-only verification confirmed Lauder's identity, upload **COMPLETE** with **zero errors**, processing **VALID**, **IN_BETA_TESTING**, **INTERNAL_ONLY**, an unexpired build and availability to the existing internal testers. Existing internal groups contain the build; group and tester membership are unchanged. Private archives, symbols and full processing evidence are preserved. Availability does not establish phone installation, physical behaviour, performance or enjoyment.

### Simulator and physical evidence

Simulator is the everyday validation environment. The script drives ordinary input through shared rules, saves screenshots/video and reports frame time, simulation cost, companion spacing and route failures. DEBUG instrumentation and route helpers are absent from Release builds. Test-only flat ranges and a narrow doorway fixture remain outside the app target because they exercise bridge weapons and navigation boundaries.

The target remains 60 fps on the baseline iPhone 13 Pro Max. Simulator measurements do not establish phone frame pacing, haptics, thermals, multi-touch, hardware input or enjoyment. The user deferred frequent phone checks; do not claim a new physical result without one.

### Deferred phone and playtest checks

- Verify the retained bridge's current controller/touch controls, release gates, Pause, interruption recovery and camera on a physical phone at the next agreed checkpoint.
- Measure representative Release frame pacing and sustained performance before making baseline-device claims.
- Ask what is enjoyable and what should change before adding another scene or complex mechanic. TestFlight availability supplies no answer to that question.

### Historical delivery

Build **0.1.0 (27)** delivered the bridge-only reset ([PR #122](https://github.com/RonildoBraga/lauder/pull/122), [delivery record in PR #123](https://github.com/RonildoBraga/lauder/pull/123)) from app/archive source `de4d0db566a546217f3c3ca095cdf1b3944a21e3`, matching the exact tree of checked/reviewed `feabb43f10f3708bc6fef4f940f26c2d8b7b462d`. The standard check passed **255 Swift tests**, **51 Blender tests** and **seven generated sounds**; the signed archive passed bundle/team/signature/dSYM verification. At **2026-11-22 07:14:36 UTC**, Apple confirmed upload **COMPLETE** with **zero errors**, processing **VALID**, **IN_BETA_TESTING**, **INTERNAL_ONLY**, an unexpired build and existing internal tester availability with membership unchanged. Earlier recording details and review history remain in the original PRs and Git history; private archives, symbols and full processing evidence are preserved.

Build **0.1.0 (26)**, source `25195e8`, was verified as processed and available before the reset. It contains the removed scenes; [ADR 0016](decisions/0016-combat-balance-and-readability.md) and Git history preserve its historical decisions and delivery evidence. Private archives, symbols and full processing evidence remain preserved.

## Combat balance and readability

The build 26 tuning and measurements in [ADR 0016](decisions/0016-combat-balance-and-readability.md) are historical. Native weapon handling, shot effects, ballistics and companion yielding still serve the bridge. The arena, extra weapons, tactical enemies and preparation displays are retired; their old measurements do not assign a new implementation pass.

## Combat design review gate

The selected C Blender proportion study is assigned. Review its model form, then the [first-tower robot proposal](encounters/bridge-spider-bot.md) before assigning motion, combat or encounter implementation. The proposal describes a brace/commit/burst/recovery pattern using existing tower cover, and a supply-case handoff that preserves Tom's introduction and Laura's medical kit. The bypass route, handoff, hit allowance and tuning still require agreement and geometry validation. The existing app and TestFlight build 28 continue to describe the human encounter.

The requested coordinated-squad direction and the trio's [combat identities](story/story-bible.md#combat-identities) remain design context. The bridge keeps formations and orders from [ADR 0003](decisions/0003-squad-movement.md), phases S1–S3. Its removed S4 experiments are not a current assignment. [The Quiet Yard](encounters/the-quiet-yard.md) and the Relay House screenplay remain unimplemented story proposals.

Next, review the selected C model's proportions from the approved camera B. Animation, runtime integration and a bounded playable encounter follow their own assignments; the tower loop and its concrete playtest questions still need agreement. The possible A variant remains future reference. A plan, historical assignment or review recommendation does not independently authorise implementation or bringing retired systems back.

## Outside the first playable

Additional playable scenes, tactical combat AI, signature abilities, salvage-repair machinery, extra equipment, elevation, skill trees, health/hunger systems, multiplayer, crafting, branching dialogue, finished art, persistence, cloud services and App Store submission. The reset does not assign any replacement for them.

## Later hardening

Before persistence, define a versioned snapshot of session progress, inventory, stable member IDs and a safe group spawn. Keep entity graphs, routes and transient animation out of it. Use ordered atomic writes and explicit error handling; preserve an unreadable save until the player chooses Restart. Sustained physical-phone thermal and memory checks follow a loop worth keeping.
