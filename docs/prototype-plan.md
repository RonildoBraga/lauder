# Lauder — basic-rig dungeon prototype

**Updated:** 29 November 2026. **Tracking:** [issue #243](https://github.com/RonildoBraga/lauder/issues/243).

## Basic-rig dungeon — implementation in progress

The maintainer assigned the combined mannequin/dungeon experiment after reporting that the isolated duel lacked Soulslike combat feel and Eitr-style corridors. [Issue #243](https://github.com/RonildoBraga/lauder/issues/243) owns progress; [ADR 0023](decisions/0023-basic-rig-dungeon-prototype.md) records the selected simple 17-bone armature, route and reset semantics. The external character mesh and detailed hands are excluded. The anonymous mannequin does not replace the preserved story characters.

The route has a safe entry, bent approach, two sequential sentry rooms, a once-per-life recovery find, a far-side shortcut and an exit. Room kills leave exploration running. Health/stamina carry between rooms. Death Retry restores encounters/recovery while retaining an opened shortcut; Pause Restart resets the whole route. The shortcut provides a return/navigation loop; sequential encounters still both reset after death, so it does not bypass the first required fight. Focus is restricted to an active opponent with clear sight. Shared layout values supply terrain and triggers; Blender-authored body poses follow simulation-owned movement/action timing.

Fresh validation and review are pending. First verify the animated approach/first fight, then all four native and recorded routes: dungeon-journey, dungeon-defence, dungeon-recovery and dungeon-focus. Check readable limb/weapon poses, real contact/defence, room transitions, useful healing, return shortcut, exit, and input/Pause/Retry/Restart recovery. Source tests and recordings do not establish enjoyment or phone performance.

The current TestFlight build remains the earlier flat-duel **0.1.0 (48)**. Its release and earlier camera/duel results below retain their exact sources; they do not validate this new implementation.

## Duel readability follow-up — in progress

[PR #242](https://github.com/RonildoBraga/lauder/pull/242), tracked by [issue #241](https://github.com/RonildoBraga/lauder/issues/241), implements the maintainer-assigned subset of the [review triage](https://github.com/RonildoBraga/lauder/issues/240): compare parallel projection, reduce projected fighter overlap, make committed enemy preparation clearer and let a free slash follow movement aim. Work starts from decision/documentation checkpoint **16a202e6d4c97eef115701d2f3719f4ea9a4bc00**; the source-bound 83b79e7 comparison and build47 delivery below remain historical evidence. Their successful checks do not validate this changed source.

**Delivery status:** internal TestFlight **0.1.0 (48)** is available to the existing testers. Implementation and delivery are complete; #241 remains open for Claude's requested feedback and human phone evaluation. Merge is not authorised by this delivery.

### Working preview

- **Camera:** preserve the selected 35° downward pitch, 45° yaw, smooth hero/focused-pair following and approximately 10.1% centred 1.85 m actor height. Orthographic is the working preview after rendered comparison, including its Release configuration, with an approximately **14.998 m full vertical world span** at 35°. Debug can compare that with the preceding 24° vertical-FOV perspective view through `--camera-projection perspective|orthographic`; the 30.5°/35°/40° pitch comparisons remain available. Projection selection changes no combat or input rule. This preview choice awaits human evaluation on the phone.
- **Enemy approach:** try a short screen-lateral approach near attack range with a latched side, preferring a collision-clear route. A blocked route or a 1.25 s attempt limit restores direct engagement rather than indefinite circling. Existing fighter separation, swept scenery collision, leash, acceptance conditions and sweep/thrust timings remain.
- **Preparation cues:** cache a broad sweep mesh and narrow thrust mesh with subtle amber fill/outline. Their origin and orientation come from the accepted action; they do not independently follow the hero. Profile reach and half-angle include the same target-disc range/angular margin as contact. A 0.6 m centre cutout preserves feet/focus-ring visibility inside ordinary body separation. These are full-action warning envelopes, not exact hit maps: active timing, movement and scenery remain authoritative. Hide them during active/recovery, Pause/interruption, reset and outcome; resume presents only the current wind-up.
- **Free-slash aim:** valid movement at the fresh press supplies an unfocused slash's requested direction, including a late buffered request. With no valid movement, retain current facing. Snap the visible facing only when accepting the slash, then preserve its committed direction. Focused slashes retain the existing bounded facing at acceptance. Guard, dodge, stamina, buffer lifetime and shared input priority remain unchanged.

No extra enemy, art asset, target selector, orbit/zoom control, new input stick or combat authority is introduced. The [walkthrough](gameplay-script.md) describes the encounter and [architecture](architecture.md) identifies the owners.

### Verification and review

**Verified application/test/tooling source:** 0e57b6d6ca4e4e7afa098ea6405e953cc43b0dd5. The complete `./scripts/check` passed on 28 November 2026. Native tests cover action-direction and bounded-approach regressions; parallel projection/rays and actual renderer agreement; warning reach, angle, orientation, geometry reuse and phase cleanup; and world-level Pause/resume/Retry cleanup. Independent source reviews found no blocking issue in the core AI/aim or camera/stage/world integration.

Six recorded Simulator runs on that source pass, all at 35° and health100 with no failures. The orthographic runs use the default without a projection override; perspective is the Debug comparison.

| Projection | Route | Result | Actual evidence |
| --- | --- | --- | --- |
| Orthographic | duel-attack | 2/2, 18.9 s, 1,106 frames | Victory, seven sword contacts, six blocks, no Retry |
| Orthographic | duel-defence | 2/2, 4.7 s, 261 frames | One block and one timed evasion |
| Orthographic | duel-recovery | 4/4, 2.7 s, 138 frames | Pause/release/resume, fresh movement, one native Restart |
| Orthographic | duel-focus | 5/5, 21.6 s, 1,256 frames | Boundary retreat/strafe, seven contacts/seven blocks, victory, focus released |
| Perspective | duel-defence | 2/2, 4.6 s, 262 frames | One block and one timed evasion |
| Perspective | duel-focus | 5/5, 21.5 s, 1,254 frames | Boundary retreat/strafe, seven contacts/seven blocks, victory, focus released |

Summaries report actual projection, pitch/offset and the orthographic span, approximately 14.998 m, which is absent for perspective. Both warning kinds were observed on the attack, defence and focus runs; native stage/world tests establish active/recovery disappearance and interruption/reset cleanup. Matched sweep-preparation and orthographic boundary captures were inspected: parallel lines, consistent depth scale, feet, ring, weapons, warnings and HUD remain clear. Orthographic at 35° is the working preview for TestFlight evaluation, not claimed maintainer acceptance. Separate asynchronous captures show comparable phases, not identical poses. Recordings, screenshots, traces, summaries and the check receipt remain outside Git.

Core tests cover free-stick flicks and buffered aim; there is no dedicated rendered gesture or physical-control proof for those cases. Simulator p99 frame intervals are approximately 33.2–33.3 ms on five routes and 144.3 ms on the short recovery route, including startup/scheduling. This is not phone performance, touch/controller comfort or enjoyment evidence.

Delivery source **aa1cb30d25fa2078424136b4d3886abd91f5dc1a** has identical application/test/tooling content to 0e57b6d; the later change records documentation. [Check 238](https://github.com/RonildoBraga/lauder/actions/runs/46129594495) passed on that exact delivery source, and independent source/documentation review found no blocking issue. Hosted Codex app review completed without findings on 0e57b6d; PR #242 comments and review threads had no outstanding findings in the pre-upload check. Claude has been asked, with no response claimed. Earlier reviews and checks below remain tied to their recorded sources.

### Internal TestFlight build 48 — available

The maintainer explicitly authorised TestFlight delivery for this follow-up. Internal **0.1.0 (48)** is available from frozen reviewed source **aa1cb30d25fa2078424136b4d3886abd91f5dc1a**, using the [reviewed-preview release workflow](../CONTRIBUTING.md#reproducible-release-command) on the clean named branch before merge. Apple discovery checked accepted/processing uploads and confirmed the number was unused before archive/upload.

The archive workflow reran the complete standard check and bound its receipt to the frozen source. Bundle/version/build/team, signature/provisioning, matching dSYM, unchanged archive fingerprint and internal-only export policy passed verification. Independent pre-upload and post-upload audits passed.

The single API-authenticated upload finished **COMPLETE** with **zero upload errors**. Apple readback at **09:33:19 UTC on 28 November 2026** confirmed the build **VALID**, unexpired, **INTERNAL_ONLY**, **IN_BETA_TESTING** and available to the existing intended internal groups. Group/build/tester joins passed, with unchanged group and tester membership. Exact **en-AU** testing notes and their actual related-build readback were verified. Private archive, symbols, receipts and audit evidence remain outside Git.

Choose **TestFlight → Lauder → Update** to evaluate camera readability, side approaches, warnings, free-slash aiming, defence, Pause and Retry. Tester availability is verified; physical installation, controls, phone performance and enjoyment are not. No app was uninstalled, no tester invited and no public App Store submission or change to public pricing/availability was made. Build47 remains the earlier duel comparison; merge and Claude/human feedback remain separate.

## Camera and enemy-focus follow-up — in progress

**Earlier source record:** this section preserves the focus and three-angle perspective work through checkpoint 16a202e. The readability follow-up above owns historical duel changes and build48 delivery status; #243 above owns current work.

The maintainer requested a camera closer to Eitr's framing and a way to retreat without turning away from the enemy (chat, 28 November 2026; no public permalink). [Issue #238](https://github.com/RonildoBraga/lauder/issues/238) tracks this follow-up in [PR #239](https://github.com/RonildoBraga/lauder/pull/239), stacked on [PR #237](https://github.com/RonildoBraga/lauder/pull/237).

The view uses a fixed 45° diagonal orientation and a 24° vertical perspective field of view. The maintainer selected a 35° downward pitch (option B) after reviewing the three Simulator views below. These are our 3D adaptation informed by Eitr footage, not measured Eitr camera parameters. Translation follows the hero when free and the fighters' midpoint when focused, with smooth frame-rate-independent damping. The camera never orbits with movement or focus; Retry snaps it to the fresh composition. Rendered geometry and screen projection share that transform.

Focus is an explicit toggle, with bounded facing towards the one living opponent and a ground-ring indicator. It works while idle, moving or guarding, but cannot redirect or cancel an accepted slash or dodge. Focus persists through Pause and input interruption; Retry or either fighter's defeat clears it. Paused/suppressed commands are consumed rather than replayed.

### Camera-pitch comparison — verified in Simulator

**Selection:** after the side-by-side captures and the recommendation of option B, the maintainer said **“Let’s proceed with your recommendations”** (chat, 28 November 2026; no public permalink). This selects the implemented 35° perspective framing, retaining 45° yaw, 24° vertical FOV, following and Focus. The alternate Debug views remain useful verification controls. Selection is not a phone playtest, merge instruction or TestFlight upload.

The maintainer approved comparing 30.5°, 35° and 40° downward tilt, with 35° as the candidate default (chat, 28 November 2026; no public permalink). This continues the existing PR and issue; it does not authorise merge or TestFlight delivery. Yaw, lens, follow/focus behaviour, input and combat remain shared.

| Downward pitch | Camera offset (x, y, z), metres | Status |
| --- | --- | --- |
| 30.5° | (22.659590, 18.876242, 22.659590) | Debug comparison |
| 35° | (20.489737, 20.289818, 20.489737) | Selected/default |
| 40° | (17.929450, 21.276270, 17.929450) | Debug comparison |

The three offsets are calibrated for the same centred 1.85 m actor height, approximately 10.1041% of viewport height at 24° vertical FOV. All three are pulled back from the preceding revision's approximately 12.7254% actor height, making the actor about 20.6% smaller on screen to retain full opposite-corner feet at 40°. The new 30.5° option is recalibrated too; it is not the unchanged earlier framing. Equal centred scale does not imply identical perspective at every world position.

The existing [play and playtest scripts](../CONTRIBUTING.md#scripted-simulator-playtests) accept only `--camera-pitch 30.5`, `35` or `40`, forwarding a Debug-only launch argument. Release uses only the selected 35° view. Recorded summaries include the actual pitch and offset. Comparisons reuse `duel-defence` and `duel-focus` and show corresponding marked encounter phases with timestamps, rather than claiming identical poses across asynchronously captured runs. No extra scene, pose injection, gameplay control, orbit or zoom system is introduced.

**Verified source:** 83b79e78994052b95089e6ac555654dcf4d3f22d. The complete `./scripts/check` passed at 08:08:38 UTC on 28 November 2026, including formatting/build, hosted Swift Testing with all four native routes and the portable contracts. Projection tests verify the three actual pitches, common centred character scale, diagonal orientation and both fighters' head/feet at near and opposite corners without relaxing the viewport bounds. Independent Codex review found no actionable issue in the camera selection, launch arguments, release isolation, metadata or tests.

Eight recorded runs on that same built Debug app passed. The four 35° runs used the ordinary default with no camera override; the remaining runs verify both alternate launch selections. Every run ended with health100 and no failures. Only the recovery route intentionally uses Retry.

| Pitch | Route | Result | Actual evidence |
| --- | --- | --- | --- |
| 35° | duel-attack | 2/2, 18.6 s, 1,096 frames | Victory, seven sword contacts, six blocks |
| 35° | duel-defence | 2/2, 4.6 s, 255 frames | One block and one timed evasion |
| 35° | duel-recovery | 4/4, 2.7 s, 140 frames | Pause/release/resume, fresh movement, one native Restart |
| 35° | duel-focus | 5/5, 21.3 s, 1,230 frames | Boundary retreat/strafe, victory, seven contacts/seven blocks, focus released |
| 30.5° | duel-defence | 2/2, 4.5 s, 255 frames | One block and one timed evasion |
| 30.5° | duel-focus | 5/5, 20.4 s, 1,185 frames | Boundary retreat/strafe, victory, seven contacts/six blocks, focus released |
| 40° | duel-defence | 2/2, 4.6 s, 256 frames | One block and one timed evasion |
| 40° | duel-focus | 5/5, 21.4 s, 1,242 frames | Boundary retreat/strafe, victory, seven contacts/seven blocks, focus released |

The app-reported pitch/offset in every summary agrees with its requested view. Actual sweep-preparation and boundary-retreat captures were inspected at all three pitches: feet, weapons, shield, focus ring and HUD remain visible. The 35° view shows more ground and fighter separation than 30.5° while retaining a less overhead presentation than 40°. Captures, recordings, traces and a source-bound manifest remain in the ignored local comparison folder. These are comparable encounter phases, not identical poses; timing figures are Simulator observations, not phone performance evidence.

Hosted [Check235](https://github.com/RonildoBraga/lauder/actions/runs/46124844322) passed on head 77a5863c83e10c36267e652f1daf29a70e3f8a8d, whose application/test/tooling source remains 83b79e7. Claude's [review](https://github.com/RonildoBraga/lauder/pull/239#issuecomment-7236453857) reports no blocking findings on earlier source 222ffed; the later calibration review is still requested. The visual framing choice is settled from Simulator captures. Physical controls, phone readability/performance and human gameplay acceptance remain open; build47 is unchanged. Current PR checks are separate from this source-bound CI record.

### Review follow-ups

At checkpoint 16a202e, Claude’s review identified perspective convergence and occasional projected body overlap as remaining differences/readability risks. Matched scale at that revision was approximately 10.1%; the review’s earlier scale comparison predates its calibration. The 35° view improved separation without guaranteeing that one fighter could never obscure the other.

Orthographic/longer-lens comparisons, side-approach enemy movement, attack-area indicators and stick-directed free slashes were triaged as separate proposals through [issue #240](https://github.com/RonildoBraga/lauder/issues/240), outside that framing selection. The authorised subset is now implemented for validation in #241 above. At the earlier revision, free slashes still used bounded current facing; those historical results do not describe the new movement-directed request.

### Initial focus implementation — verified on earlier source

**Verified source:** 6c765af17a8372c70bb4a18b7b18887b1644336a. The complete `./scripts/check` passed at 07:23:40 UTC on 28 November 2026, including formatting/build, hosted Swift Testing with all four native routes, and the declaration/export/release/recording contracts. New regressions cover focused backpedal/strafe/guard, bounded turns, committed action directions, buffered attack facing, once-only sub-tick focus, Pause cancellation, source generations and Retry/defeat release. Input tests cover all three sources, rapid touch taps, separate finger release and non-overlapping touch targets.

Fresh rendered Simulator runs on that exact application/test/tooling source pass:

| Route | Result | Actual evidence |
| --- | --- | --- |
| duel-attack | 2/2, 17.8 s, 1,048 frames | Victory, seven sword contacts, six blocks, health100, no Retry/failures |
| duel-defence | 2/2, 4.6 s, 253 frames | One directional block and one timed evasion, health100 |
| duel-recovery | 4/4, 2.7 s, 138 frames | Paused input consumed, neutral resume, fresh movement and native Restart |
| duel-focus | 5/5, 18.8 s, 1,082 frames | Focus, boundary retreat and strafe while facing the enemy; seven sword contacts/five blocks, victory, health100, automatic focus release |

Before/after captures, videos, traces and summaries remain in the ignored local verification folders. Actual frames were inspected for diagonal scenery, upright fighters, focus ring, weapons, HUD and near-wall foot visibility. This exposed foreground walls hiding feet; the two foreground wall visuals now use 0.18m curbs while the flat collision boxes remain unchanged. Independent Codex source review found no blocking issue; its pending-focus/Pause and first-fixed-tick acquisition coverage suggestions were addressed. At that checkpoint, Claude/external review and human framing acceptance remained open; the later choice and review record above supersede that status.

At this checkpoint, no new TestFlight upload had been made: build47 remained the delivered earlier revision. Scripted raw commands and native touch tests do not establish physical R3/Tab delivery, real multi-touch comfort, sustained phone performance or enjoyment. Existing source-bound results below retain their original revisions; the #241 entry above owns subsequent delivery status.

## Internal TestFlight build 47 — available

**Verified delivery:** the maintainer requested delivery to the phone through TestFlight (chat, 28 November 2026; no public permalink), tracked in [issue #236](https://github.com/RonildoBraga/lauder/issues/236). Internal **0.1.0 (47)** is available to the existing Lauder testers from frozen reviewed source **e984b60446152716a1b3d1add7b2122b593a7f67**, on the clean named branch codex/graybox-duel. This uses the documented reviewed-preview path without merging [PR #235](https://github.com/RonildoBraga/lauder/pull/235) or [PR #237](https://github.com/RonildoBraga/lauder/pull/237).

The preview contains the single-hero duel, shared touch/controller/keyboard input and the corrected held-Guard/Dodge-buffer handoff. New positive, suppression and interruption regressions pass: the old branch fails eight assertions; corrected code passes all 26 combat test functions. Independent exact-tree review and the [fresh automatic review](https://github.com/RonildoBraga/lauder/pull/237#issuecomment-7235410783) report no findings. The reported P2 thread is resolved; Claude's separate requested review is not claimed complete.

Fresh source-bound ./scripts/check passed at **06:33:56 UTC on 28 November 2026**, including formatting/build, hosted Swift Testing, all three native command routes and resource/export/release/recording contracts. [CI231](https://github.com/RonildoBraga/lauder/actions/runs/46117051629) passed on that same source. Fresh rendered routes pass: duel-attack 2/2 (seven contacts, seven blocks, health100, no Retry); duel-defence 2/2 (one block and one real timed evasion, health100); duel-recovery 4/4 (Pause/release/resume/native Restart), all without failures. Simulator evidence does not establish phone performance or enjoyment.

Fresh Apple discovery selected unused build47 after checking accepted/processing reservations and captured the existing internal-group/tester baseline. The signed Release archive passes bundle/version/build/team signature and matching-dSYM verification. Independent pre-upload audit passes **66 assertions**; independent post-upload audit passes **111 assertions**, reconfirming source/check-log binding, unchanged full archive fingerprint, strict signature/provisioning/symbols, exactly the three intended WAVs, no retired models or DEBUG runner, and internal-only export policy.

The single API-authenticated upload returned exit0. Apple readback at **06:49:09 UTC** confirmed **COMPLETE**, **zero upload errors**, **VALID**, **unexpired**, **IN_BETA_TESTING**, **INTERNAL_ONLY**, and availability to all intended existing internal groups. Actual app/build/version and group/build/tester joins pass; a fresh raw internal-group snapshot also matches the original set. Exact **en-AU** testing notes and their actual related-build response were verified at **06:49:41 UTC**. Source remained frozen through upload and the independent post-upload audit; this later documentation record changes no app, tests, tooling or resources.

Choose **TestFlight → Lauder → Update**. Test attack readability, shield/dodge timing, stamina pressure, Pause/Retry and whether another attempt feels worthwhile. Physical installation, touch/controller comfort, audio, gameplay acceptance and sustained phone performance remain unverified. Private archive, symbols, logs, recordings and Apple receipts remain retained outside Git; no app was uninstalled, no tester invited and no public App Store submission made. Build46 remains the earlier bridge comparison. The issue stays open for human acceptance and a separately authorised merge.

## Assignment and scope

After the Eitr research and reuse audit, the maintainer said **“Proceed with your recommendations but don’t forget to open a git issue and track its progress”** (chat, 28 November 2026; no public permalink). This assigns the first small duel experiment. The [research](research/eitr-gameplay-and-reset-proposal.md) retains dated evidence and later proposals; [ADR 0022](decisions/0022-single-hero-graybox-duel.md) records the runtime change.

One anonymous hero, sword, held directional shield, dodge and stamina fight one enemy with a warned sweep and thrust in a flat primitive arena. No settled character/story replacement, progression, inventory, parry, charged attack, extra enemy roster or new artwork is included.

The active bridge/squad/shooting graph and its obsolete test requirements are retired. [Two named checkpoints](milestones/bridge-prototype.md) preserve merged main and the unmerged pilot separately. Authored Blender sources, reference exports, art, provenance, private delivery evidence and unrelated worktrees are retained. The [bridge verification history](bridge-prototype-plan.md) preserves the old source/build records. Existing TestFlight 0.1.0 (46) is still the bridge, not this duel.

## Input and interaction contract

| Action | Keyboard | PS5 / Xbox | Touch |
| --- | --- | --- | --- |
| Move | WASD | Left stick | Movement stick |
| Attack | F | R1 / RB | Attack |
| Hold guard | Q | L1 / LB | Guard |
| Dodge | Space | Circle / B | Dodge |
| Focus / unfocus enemy | Tab | R3 / Right stick click | Focus / Unfocus |
| Pause / resume | Escape | Options / Menu | Pause / Resume |
| Menu confirm / outcome Retry | E | Cross / A | Dedicated menu/Retry target |

Movement is camera-relative. Without focus, Guard holds facing while the hero moves more slowly. Focus turns towards the enemy at a bounded rate while the hero can strafe, retreat or guard; release Guard to regain stamina. Accepted attacks and dodges commit their direction even if focus changes. Simultaneous command priority is **Pause → fresh Focus → Dodge → Guard → Attack**. A fresh Focus consumes simultaneous Attack/Dodge requests while preserving held Guard; suppressed fresh commands are consumed. A late-recovery request may buffer one next action for a short bounded handoff, not an entire combo.

Source/lifecycle changes clear captures and pending actions and require neutral input. Pause freezes actors and action timers. Focus selection survives both; Retry and defeat clear it. Captured touch controls remain mounted until every finger lifts, including centred-stick contact. Resume does not replay inputs pressed while paused. Foreground Lauder keeps the screen awake; leaving it restores normal idle locking.

## Starting tuning

Values are this prototype's experiments, not recovered Eitr constants.

- Hero health 100, enemy health 168, stamina 100.
- Slash: 24 damage/24 stamina; 0.19 s preparation, 0.16 s contact sweep, 0.32 s recovery.
- Enemy sweep: 40 damage, 22 blocked stamina; 0.65/0.22/0.9 s preparation/contact/recovery.
- Enemy thrust: 65 damage, 34 blocked stamina; 0.95/0.16/1.1 s.
- Dodge: 30 stamina; 0.03 s vulnerable start, 0.2 s protected movement, 0.24 s vulnerable recovery.
- Movement 2.8 m/s; held guard slows it to 40%. Unheld stamina recovery starts after a short cost-dependent delay.

The blade's shared pose controls the swept contact interval and thrust reach. Hits resolve once per action with range, facing and scenery checks. Normal successful contact causes damage; there is no compulsory weak-point chain. Stationary mashing is tested as a negative control, while a defensive route must be able to win. These controls do not establish overall balance or enjoyment.

## Verification status

**Initial implementation verification:** the following record retains its original source; the build47 entry above owns the newer reviewed/delivered revision. Frozen implementation source cad54500e61fcbdb805c758a6c5b970776b88de3 passes the complete ./scripts/check on 28 November 2026: formatting, iOS build and hosted Swift Testing, including all three native command routes. Portable checks include 18 declaration mutations, 54 Blender export tests, 31 offline release-contract tests, six recording-lifecycle tests and three sound fingerprints. The combat suite covers once-per-action contact, the shared blade interval, facing, resource exhaustion, buffer handoff, invulnerability and reset; its stationary attack-spam control loses while causing useful damage. Actual captured-touch Retry and sub-tick source-generation regressions pass.

Fresh rendered Simulator recordings on that same implementation source pass:

| Route | Result | Actual evidence |
| --- | --- | --- |
| duel-attack | 2/2, 18.8 s, 1,099 frames | Victory, seven real sword contacts, six blocks, health 100, zero Retry/failures |
| duel-defence | 2/2, 4.6 s, 255 frames | One directional block and one real timed evasion, health 100, zero failures |
| duel-recovery | 4/4, 2.7 s, 140 frames | Paused inputs ignored, released controls resume, fresh movement and one native menu Restart |

Screenshots/video/traces and summaries remain in the ignored verification folder. Captured frames were inspected for readable actors, weapons and HUD. Frame-time observations are Simulator evidence, including startup/scheduling spikes; no 60 fps phone claim follows.

Independent review findings were addressed: buffered-facing drift, handoff tolerance, visual/contact timing, orphaned helpers and historical links. Twenty-five moved reference files match the original source bytes/LFS hashes; no Blender source changed. Documentation file/heading links pass. [PR #237](https://github.com/RonildoBraga/lauder/pull/237), stacked on research PR #235, owns current CI/external-review status. The later evidence-only documentation commit changes no application/test/tooling files.

No new phone, TestFlight, enjoyment or measured phone-performance acceptance is claimed. #236 stays open for review, the human gate and a separately authorised merge/delivery.

Historical checkpoint commands (use the README's dungeon routes on the current branch):

    ./scripts/check
    ./apple/scripts/playtest duel-attack duel-defence duel-recovery duel-focus

The routes drive real shared input, not injected damage or outcomes. The original three cover a native win, block/timed evasion, and pause/release/resume/Restart. The fourth covers focus, boundary retreat and strafe through a real victory; source-bound results are above. Retained collision tests include previous wall-contact escape regressions as plain geometry fixtures.

## Next gate

Complete source-bound checks and rendered recordings for #243, review the connected route and basic-rig animation, and address findings. Then a short human session should establish whether the corridor approach creates tension, enemy preparation is readable, block/dodge/repositioning offer distinct choices, the recovery find has value, and Retry invites another attempt. Physical touch/controller comfort and sustained phone performance remain separate evidence gates.

The maintainer has assigned this dungeon experiment after the flat-duel feedback; the earlier plan to wait before adding traversal is superseded by #243. Merge and another TestFlight delivery retain their applicable authorisation and release checks. More art, story, inventories and a campaign remain outside this experiment.
