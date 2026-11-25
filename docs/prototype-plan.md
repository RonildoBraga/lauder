# Lauder — bridge-only prototype

**Updated:** 26 November 2026

**Status:** The maintainer requested a smaller starting point before a gameplay revamp: keep the Brooklyn Bridge and delete the other playable scenes and their unused systems. [ADR 0017](decisions/0017-bridge-only-reset.md) records the boundary. New mechanics and scenes await a design decision.

The bridge concept and camera B remain selected. The maintainer accepted C's Blender form and walking/turning/shooting studies, then assigned its first-tower runtime integration and Simulator movement/shooting tests. The guard replaces the first human shooter while Miki is alone. A stays a possible later different-weapon variant; B is unselected. This is a bounded prototype of the [first-tower encounter](encounters/bridge-spider-bot.md), not an assignment for additional scenes or enemy types.

On 25 November 2026 the maintainer replaced the party's figures with [pawns](visual-direction.md#characters-and-interface) and asked for a [dodge roll](decisions/0019-dodge-roll.md) to escape attacks, then said **“Start building”**. Their verification is recorded under [Pawns and dodge roll](#pawns-and-dodge-roll).

On 26 November 2026 the maintainer asked for three changes to the controls: one leader switch on L1 / LB that goes round the party, the status panel's toggle moved from Circle / B into the pause menu, and a [lock-on](decisions/0020-lock-on.md) on a press of the right stick. Their verification is recorded under [Controls pass](#controls-pass).

## Structural preparation

The approved structural preparation is merged: [PR #125](https://github.com/RonildoBraga/lauder/pull/125) separates camera motion and bridge progression, clarifies encounter naming, splits combat values into cohesive files and adds narrow declaration checks with CI. [PR #126](https://github.com/RonildoBraga/lauder/pull/126) adds reproducible TestFlight tooling. [ADR 0018](decisions/0018-runtime-boundaries.md) records the boundaries. Gameplay and story are unchanged; the next gameplay task is the design gate below.

## Purpose and scope

Use the retained bridge to decide what is enjoyable before expanding again. This cleanup preserves its existing opening, party movement, native weapons and input paths. It does not redesign the story or author a replacement core loop.

The story's foundations remain in the [story bible](story/story-bible.md). Exploration and salvage lead the intended game, with occasional combat; the current opening samples movement, a guard that can be fought or bypassed, a supply case and recruitment. Later narrative proposals are reference material, not playable content or assignments.

## The opening

The [walkthrough](gameplay-script.md#the-brooklyn-bridge-opening) follows Miki from the Brooklyn end to Manhattan:

1. Move and look while alone on the snowbound bridge.
2. Meet the C robot at the first tower. Fight using the tower as cover, or take the west arch to its safe exit. Each committed burst can cause at most one injury; a third injury retries that fight.
3. Search the outgoing supply case for rounds and a medical kit after either resolution. A scripted ambush introduces Tom, who joins afterwards.
4. Find Laura, help her with the kit and hear her name. She joins after the short exchange.
5. Cross the second tower with both companions. Switch leaders, try Close/Spread/Column and move/hold orders, then gather at the Manhattan end.

Only the bridge is available. Pause has Resume, Restart, Vibration and, with a controller or keyboard, Status panel. There is no alternate-scene selector, weapon bench, endless spawn, automatic combat cover, companion auto-fire, grenade, signature, elevation or salvage-repair system.

## Input and interaction contract

| Intent | PS5 / Xbox | Touch | Keyboard |
|---|---|---|---|
| Move active character | Left stick | Bottom-left analog stick | WASD |
| Contextual action, advance dialogue or confirm menu | Cross / A | Look, Search, Help, Continue, or Restart while paused | E |
| Next leader after someone joins, going round the party | L1 / LB | Next: name | Q |
| Change formation with two companions; call ordered companions back first | Triangle / Y | Formation / Follow | R |
| Both go / left member / right member / both hold | D-pad up / left / right / down | Hold on ground, then Both / a name / Hold | Arrow keys |
| Draw and fire the leader's native weapon; hold to fire, automatic reload | R2 / RT | Fire with assisted aim | F |
| Aim apart from movement | Right stick | Assisted aim | I, K, J, L |
| [Lock the aim](decisions/0020-lock-on.md) on a hostile, or move it to the next; two quick presses let go | R3 / RS, a press of the right stick | None: Fire's assisted aim | O |
| Dodge roll: the leader tumbles 3 m the way they move, or face, while hostile shots pass through | Square / X | Roll | Space |
| Pause / Resume | Options / Menu | Pause / Resume | Escape |
| Choose Resume, Restart, Vibration or Status panel while paused | Stick or D-pad up/down, then Cross / A | Resume, Restart or Vibration | W/S or up/down, then E |
| Hide/show status panel | Pause, then Status panel | Always shown | Pause, then Status panel |

Touch is automatic without an extended controller. An attached controller is preferred unless **Use touch controls** is chosen; **Use controller** returns to it. Keyboard remains available. These sources share InputRules and session authority. Xbox uses the shared extended-gamepad path; hardware delivery remains unverified.

Switching preserves positions and progress; held movement can continue on the new leader. R1 / RB and Circle / B are unassigned. Switch, formation and order commands consume a simultaneous action or roll. A roll needs a fresh press, fires nothing and waits 0.5 s after the last. A lock press needs a fresh press too; one within 0.3 s of the last lets go, and a lock also lets go once its hostile is down or more than 30 m away. Dialogue and Pause consume gameplay edges rather than queueing them. Pause, interruptions, reconnection and source changes require neutral input; every button, key and finger must release, including a finger resting at stick centre.

Search and Help are revalidated on press against the leader's position and current progress. The supply case can be searched once after defeating or bypassing the guard, starting the ambush. Helping Laura uses the shared medical kit and starts her recruitment exchange.

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

The maintainer selected **C, Heavy walker**, for a Blender proportion study, then accepted its form after reviewing the renders. The source is `blender/assets/spider-bot-heavy/spider-bot-heavy.blend`, with its own [model README](../blender/assets/spider-bot-heavy/README.md). The initial static study had 2,428 triangles, 41 mesh parts, five matte materials and no textures or animation. Its exact vertex bounds measured 2.83 × 2.51 × 2.35 m, a provisional review scale rather than approved collision dimensions. Three-quarter, front, side, Miki-scale and camera-B Blender renders were inspected. Standalone intake reported zero problems; mesh inspection confirmed closed solids and flat feet on z = 0. The technical checks in the earlier section describe camera B and the rejected first model, not C. The standard `./scripts/check` also passed during the static C modelling pass, including the app build and Simulator tests; no application or runtime level data changed. Saved-file intake and geometry checks for that static pass are retained in its original PR and Git history. These are historical checks before the current motion and component-reuse work. The asset is not loaded by the game, and no new rendered Simulator route or phone run was performed for that static pass.

### Concept C Blender motion and shared parts

The maintainer accepted C's form and assigned Blender animations of walking, turning and shooting before placing the robot on the bridge. This authorises source motion studies and reusable linked components. The new source has 41 mesh Objects sharing 17 unique Mesh datablocks, with 2,428 evaluated triangles and five matte materials. Each leg uses the same six shared component meshes under independent joint pivots; paired gun, roof and antenna parts also share data. Neutral dimensions are about 3.00 × 2.53 × 2.35 m after opening the knees for articulation, still provisional. Walking, mirrored 90° step-turns and a planted brace/recoil/recovery are baked at 120 Hz in a 30-fps source timeline. The maintainer subsequently accepted the [30-second rendered reel](../blender/assets/spider-bot-heavy/motion-preview.mp4) and assigned runtime integration.

On the animated source, `./scripts/check` passed the contracts, 51 Blender tests, sounds, formatting, app build and hosted Simulator tests. Final independent saved-file inspection sampled 7,204 poses at 240 Hz: stance drift below 0.029 mm, foot tilt below 0.0053°, sole penetration below 0.012 mm and zero joint gaps. Neutral and mirrored-turn geometry/material symmetry, linked-data reuse, topology, contacts, muzzles, palette, intake and privacy checks pass. All 720 rendered movie frames decode. The model README records the timeline and tolerances. No runtime source, bridge export or rejected model changed; no new phone check, rendered Simulator route, release or bridge placement occurred. These source checks do not establish runtime clip compatibility, phone performance or motion approval.

The rest model's left and right assemblies must mirror exactly. Repeated legs and connectors must reuse identical linked mesh parts rather than separately maintained near-copies. Placement and pose may differ as the legs walk or turn; the geometry and matching joints must remain consistent. The maintainer reviewed these motion studies and assigned bridge integration; keep that shared component structure in the runtime asset.

**A, Armoured crawler**, is retained for a possible later variant with different gun types; no A modelling or new weapon work is assigned. **B, Low siege bot**, is unselected. Camera B remains unchanged. That authoring assignment did not implement runtime AI or firing. The subsequent bounded integration is recorded below; A and releases remain outside this task.

### C robot on the bridge

The maintainer assigned the first-shooter replacement after approving C's motion. Integration is implemented: a source-driven runtime robot, bounded east-side movement, honest twin-barrel rays, a finite warning/commit/burst/recovery cycle, and a west-side supply case with a verified bypass route. Internal first-fight beat and marker IDs retain `stranger` for continuity; player-facing content describes the guard and case. Tom's arrival marker moves closer to the case so the existing ambush can remain visible. Geometry blockers, camera B and lighting remain unchanged.

The model's named joint hierarchy and generated measurements are exported from Blender. Gameplay remains fixed-step Swift; presentation follows actual movement, turns, brace and gun state. The standard `./scripts/check` passed on a frozen runtime tree: 13 declaration-contract tests, 28 offline release tests, 52 Blender tests, seven sound fingerprints, Swift formatting, the app build and hosted Swift Testing. Source fingerprints remained unchanged through the rendered runs. Independent code review found no actionable issues.

Rendered Simulator checks passed with zero failures or companion warning frames:

| Route | Steps | Evidence |
|---|---:|---|
| `first-fight` | 35/35 | Patrol, tracking, commitment, burst, recovery, defeat and Restart; marks record six emitted shots across two bursts before defeat |
| `fight-retry` | 15/15 | Three mistakes, checkpoint restore and a successful second attempt |
| `opening` | 56/56 | Supply case, ambush, Tom and Laura recruitment, both towers, arrival and Restart |

Mean frame time was 16.7 ms in each Simulator run, with p99 between 16.8 and 17.1 ms. These are Simulator measurements, not baseline-phone evidence. The loaded USDZ tests verify grounded feet/joints, 3D barrel/ray agreement including yaw/pitch/recoil, and Pause/reset. Actual-guard motion regressions also verify planted feet stay reachable during combined translation and turning; the small fix uses a 1° stop-turn-advance gate and an earlier step trigger, rather than masking an unreachable foot through clamping. Private captures, summaries, hashes and logs are retained.

The initial integration task recorded no new phone or release evidence. Its frozen application and asset source was tested; the subsequent TestFlight delivery is recorded below.

The follow-up review for [PR #134](https://github.com/RonildoBraga/lauder/pull/134) checked combat, progression and the rig/export pipeline independently. It corrected stale human-shooter/body-search descriptions and clarified the existing injury policy: unresolved retreat preserves damage and ammunition; completed defeat or safe bypass recovers encounter-local injuries. An injured-bypass regression and a retreat-through-search-to-patrol regression verify that distinction. `./scripts/check` passed again, as did all 49 local links/anchors in the four changed Markdown documents. This follow-up changes tests, comments and documentation only; it adds no phone or rendered-performance claim.

**TestFlight integration, 23 November 2026:** The maintainer authorised integrating the reviewed work and delivering it through TestFlight. [PR #134](https://github.com/RonildoBraga/lauder/pull/134) incorporated #128–#133 as one squash because the repository allows squash merges only; the earlier drafts were closed as incorporated rather than individually merged. Integrated app/archive source `ea47e2b40d5fa4a4c4c16149e9755ac5475f9b7e` has the exact tree of reviewed release-preparation commit `26c5d99977290283b41e6a2a3ed93dfcabc17c4c`. Apple discovery selected unused **0.1.0 (29)**, and archive/upload rechecked accepted and processing uploads. The [delivery record](#testflight-delivery) confirms processing and unchanged tester access. Physical-phone behaviour and performance remain unverified.

### Pawns and dodge roll

On 25 November 2026 the maintainer chose simpler figures for the party from a [game-scale mock-up sheet](../art/party/README.md). The maintainer confirmed the pawn as mocked up, with one skin tone for all three and Snow for the white fur, accepted the [dodge roll](decisions/0019-dodge-roll.md)'s starting values, and said **“Start building”**. The decisions are relayed on [issue #142](https://github.com/RonildoBraga/lauder/issues/142).

- **Models:** Miki, Laura and Tom are rebuilt in Blender as the sheet's pawns. They have 216, 296 and 228 triangles, stand 1.535 to 1.635 m tall, and have no rig or textures. Each passes the model intake check and was exported with the registered exporter.
- **Motion:** `PawnGait` shows each step's resolved movement as a bob, a rock and a lean. `DodgeRoll` supplies the roll's movement and its tumble. The world's fixed step drives both, and both stay presentation apart from the roll's movement.
- **Checks:** `./scripts/check` passed:
  - 13 declaration-contract tests, 28 offline release tests, 52 Blender tests and seven sound fingerprints;
  - Swift formatting and the app build;
  - Swift Testing on an iOS 27 iPhone 17 simulator: 290 tests in 393 runs.

  New tests cover the walk, the roll's distance, tumble and direction, its cooldown, a roll ended by a leader switch or a scene, the dodge press and its release gate, shots passing through a rolling leader, and the pawn models' heights and facing.
- **Simulator:** the rendered routes passed with no failures or companion warning frames. Mean frame time was 16.7 ms and p99 16.8 ms, Simulator measurements only.

  | Route | Steps |
  |---|---:|
  | `first-fight` | 35/35 |
  | `opening` | 56/56 |

  Played by hand with touch on the iPhone 17 simulator:
  - **Roll from standing:** Roll tumbles Miki one full turn forward the way she faces, and she lands upright.
  - **Roll while moving:** with the stick already held to the side, she rolls that way and walks on.
  - **Walk:** her rock from side to side shows.
  - **Not exercised by hand:** Space. The Simulator tool's key presses are shorter than a frame, so the game never samples them held; the input tests cover the binding.
- **Review:** a second Claude review pass, by a separate agent and so not independent, found four defects. Each is fixed with a regression test:
  - a roll carried on into a scene that holds the party;
  - a leader switch skipped the cooldown;
  - a press that no fixed step took up survived a Pause;
  - the touch Roll button covered the conversation panel's lines.

  The two new GameWorld tests fail without their fix.
- **Not yet verified:** the phone. That covers how the pawns read at their real size, the walk and the roll's feel, the touch Roll button with a finger on the stick, controllers, frame pacing and the guard fight's balance with a roll.

### Controls pass

On 26 November 2026, after reviewing a map of the controller's buttons, the maintainer asked for three changes in a Claude session, which has no public permalink:
- **“instead of using R1 and L1 to navigate through the characters, we should just use L1 and go in circles”**. L1 / LB is now the only leader switch. It goes round the party in the order that Next keeps on touch and Q on a keyboard: Miki, Tom, then Laura. Previous and its Z key are gone, and R1 / RB is unassigned. The D-pad keeps its sides, so right sends whoever L1 would lead as.
- **“The circle button used for status panel, we should remove from the circle button and just make as a option in the pause menu.”** The pause menu has a fourth choice, **Status panel: Shown** or **Hidden**, which stays in the menu as Vibration does. Circle / B and the H key no longer hide the panel and are unassigned. Touch is unchanged: its pause screen has no such choice, and the panel always shows.
- **The [lock-on](decisions/0020-lock-on.md)**, quoted in its decision record. A press of the right stick locks the aim on a hostile, circled in red; the next press moves it on, and two quick presses let go.

Checks:
- **`./scripts/check` passed:**
  - 13 declaration-contract tests, 28 offline release tests, 52 Blender tests and seven sound fingerprints;
  - Swift formatting and the app build;
  - Swift Testing on an iOS 27 iPhone 17 simulator: 290 tests in 392 runs.

  New tests cover the lock press and its release gate, the first lock and going round clockwise, a quick second press letting go, letting go out of reach, the locked shot, the red ring's place and size, and Restart. A world test fights three guards: the stick aims left, the lock turns the leader right, and Fire downs the locked guard, not the one ahead. The pause menu's tests cover the Status panel choice.
- **Simulator:** the new `lock-on` route locks on the first-tower guard, fires until it is down and checks that the lock let go. Mean frame time was 16.7 ms and p99 16.8 ms, Simulator measurements only.

  | Route | Steps |
  |---|---:|
  | `lock-on` | 25/25 |
  | `first-fight` | 35/35 |

  The first rendered run showed no ring. The towers' baked shadows lie 3 cm over the snow and covered it, and the guard stands in the Brooklyn tower's shadow. The ring now stands above them, and the route's screenshot shows it round the guard.
- **Found on the way:** the assisted target's red disc and the companions' order rings are also drawn below those shadows, so a tower's shadow hides them. That predates this change and is left as it was.
- **Not exercised by hand:** a controller and the O key. The Simulator delivers no controller input, and its key presses are shorter than a frame, so the route drives the lock through the same input rules instead.
- **Not yet verified:** the phone. That covers L1's switch, the pause menu's new choice, the lock with a real DualSense, how the ring reads at the phone's size, and the guard fight's balance with a lock.

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

App/archive source `ea47e2b40d5fa4a4c4c16149e9755ac5475f9b7e`, integrated through [PR #134](https://github.com/RonildoBraga/lauder/pull/134), delivers the bridge environment, camera B and C robot in **0.1.0 (29)**. It matches the reviewed release tree and passed the source-bound standard check, signed archive identity/signature/team and matching-dSYM verification. At **2026-11-23 05:12:59 UTC**, Apple's read-only verification confirmed Lauder's identity, upload **COMPLETE** with **zero errors**, processing **VALID**, **IN_BETA_TESTING**, **INTERNAL_ONLY**, an unexpired build and availability to the existing internal testers. Existing internal groups contain the build; group and tester membership are unchanged. Private archives, symbols and full evidence are preserved. TestFlight availability does not establish phone installation, physical behaviour, performance or enjoyment.

Build **0.1.0 (30)** was delivered on 25 November 2026 from the head of draft [PR #154](https://github.com/RonildoBraga/lauder/pull/154), `f80fa13`, before any merge, so that the maintainer could play its detailed Miki on the phone. Its [delivery record](https://github.com/RonildoBraga/lauder/pull/154#issuecomment-7154103454) is on that PR. The [pawns](#pawns-and-dodge-roll) replace that character route, so build 30's characters never reached `main`.

### Simulator and physical evidence

Simulator is the everyday validation environment. The script drives ordinary input through shared rules, saves screenshots/video and reports frame time, simulation cost, companion spacing and route failures. DEBUG instrumentation and route helpers are absent from Release builds. Test-only flat ranges and a narrow doorway fixture remain outside the app target because they exercise bridge weapons and navigation boundaries.

The target remains 60 fps on the baseline iPhone 13 Pro Max. Simulator measurements do not establish phone frame pacing, haptics, thermals, multi-touch, hardware input or enjoyment. The user deferred frequent phone checks; do not claim a new physical result without one.

### Deferred phone and playtest checks

- Verify the retained bridge's current controller/touch controls, release gates, Pause, interruption recovery and camera on a physical phone at the next agreed checkpoint.
- Measure representative Release frame pacing and sustained performance before making baseline-device claims.
- Check on the phone that the pawns read at their real size and that the walk and the dodge roll feel right. Include the touch Roll button pressed while a finger holds the stick, and Square / X on a controller.
- Ask what is enjoyable and what should change before adding another scene or complex mechanic. TestFlight availability supplies no answer to that question.

### Historical delivery

Build **0.1.0 (27)** delivered the bridge-only reset ([PR #122](https://github.com/RonildoBraga/lauder/pull/122), [delivery record in PR #123](https://github.com/RonildoBraga/lauder/pull/123)) from app/archive source `de4d0db566a546217f3c3ca095cdf1b3944a21e3`, matching the exact tree of checked/reviewed `feabb43f10f3708bc6fef4f940f26c2d8b7b462d`. The standard check passed **255 Swift tests**, **51 Blender tests** and **seven generated sounds**; the signed archive passed bundle/team/signature/dSYM verification. At **2026-11-22 07:14:36 UTC**, Apple confirmed upload **COMPLETE** with **zero errors**, processing **VALID**, **IN_BETA_TESTING**, **INTERNAL_ONLY**, an unexpired build and existing internal tester availability with membership unchanged. Earlier recording details and review history remain in the original PRs and Git history; private archives, symbols and full processing evidence are preserved.

Build **0.1.0 (26)**, source `25195e8`, was verified as processed and available before the reset. It contains the removed scenes; [ADR 0016](decisions/0016-combat-balance-and-readability.md) and Git history preserve its historical decisions and delivery evidence. Private archives, symbols and full processing evidence remain preserved.

## Combat balance and readability

The build 26 tuning and measurements in [ADR 0016](decisions/0016-combat-balance-and-readability.md) are historical. Native weapon handling, shot effects, ballistics and companion yielding still serve the bridge. The arena, extra weapons, tactical enemies and preparation displays are retired; their old measurements do not assign a new implementation pass.

## Combat design review gate

The C first-tower runtime prototype is implemented and its source/Simulator checks pass. Review whether the short loop is readable and enjoyable; source tests and Simulator success do not settle balance or phone performance. New scenes, A's variant and releases remain separate work.

The broader squad combat direction, [The Quiet Yard](encounters/the-quiet-yard.md) and later narrative plans remain reference rather than assignments. The removed S4 experiments stay retired.

## Outside the first playable

Additional playable scenes, tactical combat AI, signature abilities, salvage-repair machinery, extra equipment, elevation, skill trees, health/hunger systems, multiplayer, crafting, branching dialogue, finished art, persistence, cloud services and App Store submission. The reset does not assign any replacement for them.

## Later hardening

Before persistence, define a versioned snapshot of session progress, inventory, stable member IDs and a safe group spawn. Keep entity graphs, routes and transient animation out of it. Use ordered atomic writes and explicit error handling; preserve an unreadable save until the player chooses Restart. Sustained physical-phone thermal and memory checks follow a loop worth keeping.
