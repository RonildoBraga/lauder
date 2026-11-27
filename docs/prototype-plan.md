# Lauder — bridge-only prototype

**Updated:** 27 November 2026

**Status:** The Brooklyn Bridge remains the only playable scene after the [bridge-only reset](decisions/0017-bridge-only-reset.md). The strategic guard was delivered as the [build 33 reviewed preview](#build-33-testflight-preview). [Bounded companion autonomy](companion-autonomy.md) is implemented, with validation below. The [build 37 preview](#build-37-testflight-preview) is delivered, retaining build 36's damage, cover/spacing and retaliation changes and adding reviewed touch/squad corrections and weapon sounds. The build 33–37 stack [merged into `main`](#merged-into-main) on 27 November 2026; physical acceptance remains a separate gate. The player keeps direct control of the leader while companions may complete their own weakpoint contributions. Further scenes and mechanics require their own decision.

The current assignment is the [eye, legs and Tom grenade revision](#eye-legs-and-grenades--in-development), building on the delivered [build 37](#build-37-testflight-preview) touch/squad and sound fixes. The guard-damage implementation under [issue #183](https://github.com/RonildoBraga/lauder/issues/183), based on [PR #175](https://github.com/RonildoBraga/lauder/pull/175), source `5421873`, replaces the mandatory role gate with shared health and optional weakness rewards. Its original source and rendered checks passed on `533f012`, recorded below and in [PR #184](https://github.com/RonildoBraga/lauder/pull/184). The preceding [build 36](#build-36-testflight-preview), cover/spacing and [build 35 retaliation](#build-35-testflight-preview) results remain recorded below as historical evidence. Generic phone feedback for earlier previews does not establish controls, audibility or sustained performance for this new revision.

The bridge concept and camera B remain selected. The maintainer accepted C's Blender form and walking/turning/shooting studies, then assigned its first-tower runtime integration and Simulator movement/shooting tests. The guard replaced the first human shooter; since 26 November the three meet it together, and it is the bridge's only fight. A stays a possible later different-weapon variant; B is unselected. This is a bounded prototype of the [first-tower encounter](encounters/bridge-spider-bot.md), not an assignment for additional scenes or enemy types.

On 25 November 2026 the maintainer replaced the party's figures with [pawns](visual-direction.md#characters-and-interface) and asked for a [dodge roll](decisions/0019-dodge-roll.md) to escape attacks, then said **“Start building”**. Their verification is recorded under [Pawns and dodge roll](#pawns-and-dodge-roll).

On 26 November 2026 the maintainer asked for three changes to the controls: one leader switch on L1 / LB that goes round the party, the status panel's toggle moved from Circle / B into the pause menu, and a [lock-on](decisions/0020-lock-on.md) on a press of the right stick. Their verification is recorded under [Controls pass](#controls-pass).

Later that day the maintainer started Miki, Tom and Laura together and kept the first-tower guard as the bridge's only fight. That change is recorded under [Three together](#three-together). In the same message the maintainer gave each character two weapons to switch between, recorded under [Paired weapons](#paired-weapons).

## Eye, legs and grenades — in development

The maintainer's build 37 playtest found ordinary hits dominant. They requested persistent eye criticals, repeated Laura sword contacts detaching individual legs and slowing the robot, and grenade throws. The task clarification selected **“Tom only; manual throws”** (chat, 27 November 2026; no public permalink). [Issue #192](https://github.com/RonildoBraga/lauder/issues/192) assigns the bounded revision based on `a44537e`; the [contract](robot-eye-legs-grenades.md) owns the rules and prototype tuning. It does not authorise merge or another TestFlight upload.

The source replaces the sensor/coupling/core gate with actual front-eye criticals and four independent sword-leg counters. It reuses the existing leg assemblies for bounded detachment and gait changes, without changing Blender assets or adding physics. Tom gets a manual grenade through shared input authority, a committed scenery-tested arc, one ordinary cover-tested blast result per enemy and an 8-second recharge that survives switching. Attack/Defend, hard orders, player leadership, warnings and the quiet bypass remain authoritative.

**Verified on source `303617b1b3f2c67d793f7c4cf6d5f8a1daebb03e`:** full `./scripts/check` passes: **13 declaration contracts, 31 offline release contracts, 52 Blender tests, sixteen sound fingerprints**, strict Swift formatting, app build and hosted Swift Testing including **all fourteen headless gameplay routes**. Native regressions verify repeated real eye criticals with all four guns; ordinary damage with all five damaging weapons; three contacts on one leg, independent later breaks and real removed volumes; movement penalties and measured grounded hull/muzzle/eye agreement; actual wall/ally/rear-body occlusion; companion authority and Defend; Tom-only grenade execution, one ordinary applied result per blast, scenery/falloff, shared recharge, Pause/reset, held contacts and pending-input ownership across substeps and switches. The initial full run passed 506/507 cases; its remaining driver-only expectation was updated for the new Laura-first demonstration before the successful complete rerun.

Independent reviews prompted fixes for oblique eye contacts, scripted party holds and a pending grenade crossing leaders; native regressions cover them. Automatic Codex review completed without findings on the same source. No Claude review of this new revision is claimed. Hosted checks for the latest documented tree are tracked in [PR #193](https://github.com/RonildoBraga/lauder/pull/193); documentation-only follow-ups retain the same application, assets, tests and tooling as `303617b`.

Fresh rendered iPhone 13 Pro Max / iOS 27.0 Simulator comparisons:

| Route | Duration | Normal / eye-critical damage | Grenade damage (included in normal) | Legs lost before victory | Retries / party-stop frames | Maximum labels | Body overlap |
|---|---:|---:|---:|---:|---:|---:|---:|
| `robot-parts` | 61.2 s | 438 / 1,062 | 180 | 2 | 0 / 0 | 8 | 0.5% |
| `touch-fight` | 57.2 s | 150 / 1,350 | 0 | 1 | 0 / 0 | 6 | 2.8% |

Both pass through native victory and Restart. Each total is exactly **1,500**, and every member contributes. The first route throws as Tom, pauses the actual flight, breaks legs through Laura's real sword and finishes with native squad support. Its member contributions are **576 / 210 / 714** for Miki / Laura / Tom. The touch-only route records **zero non-touch frames**, retains targeting, swaps, orders, Pause/status and Restart, and contributes **1,152 / 147 / 201**. Each records at most one injury to Miki and no injury to Laura/Tom. Restart restores health to 1,500 and legs lost to zero.

Inspected captures/video frames show the red eye, critical/ordinary numbers and an actual missing leg during a live fight. The early grenade mark is captured after Pause covers the scene, so that still alone does not demonstrate the projectile arc; the recording and native flight tests remain the evidence. Loaded-model tests verify complete detached assemblies, bounded props, restored geometry and real export/eye/muzzle measurements. The grenade control is covered through sampled UIKit callbacks, not physical fingers. The touch fight does not throw a grenade. The two rendered runs used a separate Simulator while the full regression suite ran; their frame times are not phone performance evidence.

**Limits and next gate:** [PR #193](https://github.com/RonildoBraga/lauder/pull/193) is unmerged. Build 37 remains the latest delivered comparison; this source has not been uploaded to TestFlight. Phone controls, multi-touch, audibility/haptics, enjoyment and sustained performance remain unverified. Navigation clearance stays conservative after a leg loss, debris does not collide, eye contact uses an analytical approximation, and the blast reuses an impact sound. Review this bounded revision before a separately authorised merge or phone delivery. The earlier records below retain their original sources and results.

## Build 37 TestFlight preview

The maintainer requested **“Send it to my phone for testing using the TestFlight”** (chat, 27 November 2026; no public permalink). This authorises an internal TestFlight preview of the latest reviewed changes, without merging the open stack into `main` or claiming physical acceptance. The release branch `codex/testflight-controls-audio` combines [PR #187](https://github.com/RonildoBraga/lauder/pull/187), [PR #188](https://github.com/RonildoBraga/lauder/pull/188) and [PR #189](https://github.com/RonildoBraga/lauder/pull/189). The source integration preserves their existing damage, squad authority, input release rules and native audio owners. Main remains unchanged.

Fresh Lauder-specific Apple discovery checked accepted/processing uploads and builds, identified **37** as unused, and preserved the existing tester/group baseline. Internal **0.1.0 (37)** is now available from exact app/archive source **`cce555acb5ca8502a5c3db5f5fcf5d33e56fdccb`**, recorded in [PR #191](https://github.com/RonildoBraga/lauder/pull/191). Build 36 remains the preceding delivered comparison; its results are historical evidence.

The combined source also addresses the final reviews on #187/#188: drawn order-menu items and clamped selection share geometry; release rechecks dialogue action visibility; hidden-HUD neutral guidance remains visible; projected robot width participates in the 30 pt exterior tap tolerance; an empty tap can release a wholly off-screen lock; and repeated impossible-range warnings are bounded while preserving initial quiet detection. The short hint names the visible Attack/Defend menu labels. The input contract is corrected and backlog provenance is quoted. The original-position reset remains authoritative within 30 pt; extreme-top holds still lack upward cancel travel. Touch picking uses a projected body envelope rather than exact mesh pixels.

**Verified on the exact archive source:** independent UI/backend cross-review and final fixture/document-delta review found no blocker. Automatic Codex review completed without findings; Claude was asked to review the combined source, with no reply at the delivery checkpoint. Focused regressions pass, including sampled UIKit callbacks, visible-label selection, release-time dialogue hiding, hidden-panel guidance, full-width/native-cover picking and unreachable-warning behaviour. These callbacks are not physical finger delivery. Full archive-bound `./scripts/check` passes: **13 declaration-contract tests, 31 offline release-contract tests, 52 Blender tests, sixteen sound fingerprints**, strict formatting, app build and hosted Swift Testing with **all thirteen headless routes**. [Exact-source GitHub Check 109](https://github.com/RonildoBraga/lauder/actions/runs/45919771945) passed.

Fresh rendered iPhone 13 Pro Max / iOS 27.0 Simulator `touch-fight`, `retaliation` and `weapons` routes passed in **63.8 / 61.2 / 65.5 s**, through native victory and Restart with **zero retries and party-stop diagnostics**. The touch route records **zero non-touch input frames**. Each damage total equals **1,500**; normal/weak-point totals are **888/612, 807/693 and 906/594**, with at most **7/6/5** simultaneous labels. Inspected captures show the short visible-choice hint and hidden Pause status panel on build 37. Body overlap persists in **1.7% / 2.0% / 12.4%** of recorded frames; these results do not establish permanent separation or phone frame rates.

The signed Release archive's identity, team, strict signature, matching dSYM and fingerprint passed verification. The single API-authenticated upload succeeded. Apple readback at **2026-11-27 01:13:21 UTC** confirmed **COMPLETE**, **zero upload errors**, **VALID**, **IN_BETA_TESTING**, **INTERNAL_ONLY**, an unexpired build and availability to the existing intended internal groups. Group and tester membership are unchanged. The **en-AU testing notes were written and read back exactly**. Private archives, symbols and evidence are retained; no main merge or public App Store submission occurred.

Update Lauder in TestFlight for the phone comparison. Installation, physical multi-touch/VoiceOver/controller usability, audio/haptics, combat balance, sustained phone performance and acceptance remain unverified for this source. A moving guard temporarily occupying a previously valid Go point remains an un-reproduced review observation; the collision boundary remains authoritative, without a promise of permanently clear dynamic destinations.

### Merged into main

On 27 November 2026 the maintainer said **“merge the stack once Codex fixes the review findings”** (Claude chat; no public permalink). Claude's review of `cce555a` [found each finding fixed](https://github.com/RonildoBraga/lauder/pull/191#issuecomment-7207912303). The pull requests then merged into `main` in order: [#166](https://github.com/RonildoBraga/lauder/pull/166) as `4708ef3`, [#167](https://github.com/RonildoBraga/lauder/pull/167) as `212ecf1`, [#169](https://github.com/RonildoBraga/lauder/pull/169) as `64ab95b`, [#170](https://github.com/RonildoBraga/lauder/pull/170) as `2d9074d`, [#172](https://github.com/RonildoBraga/lauder/pull/172) as `4f740c4`, [#173](https://github.com/RonildoBraga/lauder/pull/173) as `036d728`, [#175](https://github.com/RonildoBraga/lauder/pull/175) as `12c9db6`, [#184](https://github.com/RonildoBraga/lauder/pull/184) as `b90ac12`, [#185](https://github.com/RonildoBraga/lauder/pull/185) as `8a7844e`, [#187](https://github.com/RonildoBraga/lauder/pull/187) as `550517a`, [#188](https://github.com/RonildoBraga/lauder/pull/188) as `d302ff3`, [#189](https://github.com/RonildoBraga/lauder/pull/189) as `b9db6dc` and [#191](https://github.com/RonildoBraga/lauder/pull/191) as `2532577`.

Each squash has exactly the files of its pull request's head. Where a Codex branch first needed `main` recorded, a bookkeeping merge changed no file. #189 needed a real merge, which reused the resolution Codex had made in `040d81f` for build 37. `main`'s app sources are those of `cce555a`, and only status documents differ. `./scripts/check` passed on #189's merged tree before it landed. #191's head `a44537e` passed [check run 110](https://github.com/RonildoBraga/lauder/actions/runs/45921635509) with the tree that `main` then had.

## Touch parity — in development

**Historical source record:** the behaviour and measurements below describe `e2e9575` and its original review handoff. The later [build 37 preview](#build-37-testflight-preview) includes this work and the final targeting, drawn-menu and guidance corrections; the earlier empty-tap and edge-gesture descriptions are not its current contract.

Under the maintainer's assignment to address Claude's GitHub findings, [issue #186](https://github.com/RonildoBraga/lauder/issues/186) adds the missing touch targeting and discoverability on top of the [review fixes](#claude-review-follow-ups--in-development). The maintainer chose **“Short order hint (recommended)”** (chat; no public permalink). A noninteractive hint appears during a fight while Defend is active: hold open ground and slide upper-left for Attack or upper-right for Defend.

A quick ground tap selects the nearest eligible on-screen enemy body within 30 screen points, using the normal lock, aim, range and damage paths; tapping that selected body again releases it. Empty taps leave it alone. Holds retain the spatial order menu and original ground mark. There is no second aim stick or tap-to-fire. Explicit VoiceOver target/next/release and existing Go/Hold actions supplement the unchanged gameplay button layout. Fire is absent during dialogue; Pause exposes the existing status-panel choice. These defaults are implementation choices within the assigned audit, not additional quoted maintainer decisions. The [touch contract](touch-controls.md) and [lock-on record](decisions/0020-lock-on.md) own the exact rules.

**Verified on source `e2e9575`:** full `./scripts/check` passes on a dedicated iPhone 13 Pro Max / iOS 27.0 Simulator: 13 declaration-contract tests, 31 offline release tests, 52 Blender tests, eight sound fingerprints, strict formatting, app build and hosted Swift Testing including all thirteen headless routes. Focused capture/native-target/panel and inset-window regressions pass. An initial test-only missing-spawn fixture was corrected; the final check has no new Swift deprecation warning. Peer review found no source blocker, and automatic Codex review completed without findings on `98192ff`; subsequent changes modernise the test window and hold Debug capture marks, without changing gameplay.

The fresh rendered `touch-fight` route passes in **63.8 s** with **zero non-touch input frames**, zero retries and zero party-stop diagnostics. Accepted Go/Hold, both weapon swaps, a full leader cycle, target acquisition/release, real Fire/roll movement, native victory, actual panel visibility and Restart pass through shared input/session rules. Applied damage totals exactly **1,500**: Miki **768**, Laura **315**, Tom **417**; normal **888**, weak-point **612**, **75** contacts, at most **seven** labels. Inspected stills show the short hint while Defend is active, the lock ring and the status panel hidden on Pause. Initial rapidly advancing capture marks skipped those UI states; the final Debug route deliberately holds them long enough to capture. This route injects touch fields rather than physical UIKit fingers. Unit tests cover capture classification, final endpoints, delayed menu tasks, generation cancellation and accessibility dispatch; they do not establish real multi-touch or VoiceOver usability.

Brief existing body overlap remains (**1.77%** of recorded frames). Simulator pacing is not phone performance. At this source, extreme-top holds still lacked upward travel for stance/cancel gestures; physical controls, audibility, balance, sustained phone performance and acceptance remained unverified. At the handoff, [PR #188](https://github.com/RonildoBraga/lauder/pull/188) was unmerged and unuploaded, with build 36 the delivered preview. The subsequent [build 37 delivery](#build-37-testflight-preview) supersedes that availability checkpoint without establishing physical acceptance or merging the PR. For backlog retirement, the maintainer instructed **“Please resolve and close all git issues and wherever what is stale or outdated we should close. Also me mindful Claude is also working to resolve and close all git issues so you guys need to divide and conquer.”** ([relayed decision](https://github.com/RonildoBraga/lauder/issues/165#issuecomment-7206268433)). That authorises issue retirement with factual limitations; closing implementation tracking does not merge or authorise a new upload.

## Claude review follow-ups — in development

**Historical source record:** the rules and verification below describe `ae3519d`. The later [build 37 preview](#build-37-testflight-preview) delivers this work with the final touch-menu and tracking corrections; the source-specific results below remain unchanged.

On 27 November 2026 the maintainer asked **“Also please address the Claude comments on git issues”** (chat; no public permalink). This authorises the bounded corrections in [#176](https://github.com/RonildoBraga/lauder/issues/176)–[#182](https://github.com/RonildoBraga/lauder/issues/182), building on the delivered [build 36](#build-36-testflight-preview) source and its documentation. The already-addressed #180 contact/material fixes remain in build 36. The newer [touch-parity audit #186](https://github.com/RonildoBraga/lauder/issues/186) is a separate implementation follow-up. Neither review recommendations nor this source task authorise merging the open stack or another TestFlight upload.

- **Regroup:** an accepted Go or Hold replaces temporary Formation/Follow regrouping without changing Attack/Defend. A refused order leaves regrouping intact.
- **Destinations:** forward marks stop before a living guard’s hull; direct and snapped destinations, single sends and Both fallback require the same party/hull clearance as movement. An impossible touch point shows the existing refusal cross.
- **Tracking:** retaliation chooses recent visible attackers within the existing 12 m attack range, retaining 14 m sight/quiet detection. A still-visible fixed target beyond attack range returns to searching after the existing tracking warning, so another eligible target gets a fresh full warning. Committed shots retain their fixed point.
- **Touch order menu:** movement is measured from the original finger position, independent of clamped artwork. Returning inside the 30 pt centre resets to Both; the wider upward sector cancels, upper diagonals select stances and horizontal travel selects companions. Start far enough below the top edge for upward gestures; extreme-top presses retain this physical limitation.
- **Shared context:** the story bible restores occasional light combat and useful ordinary fire, separating proposed biographies from assigned prototype mechanics. CONTRIBUTING records `.local/worktrees/<name>/`. Seven old worktrees were relocated there with all 17,103 original file entries preserved; only three private archive-location fields changed, with original manifests and relocation receipts retained. Builds 33/34/35 retain matching archive fingerprints, dSYMs and signatures. No data or branches were deleted.

**Verified on source `ae3519d`:** the full `./scripts/check` passes, including all twelve retained headless routes. Focused before-source checks reproduce the order/regroup, hull-admission, guard-tracking and cancel-sector failures; focused after-fix suites pass. Fresh rendered `orders`, `companions` and `retaliation` routes pass in 322.1 s, 66.4 s and 70.5 s respectively, with no retry or party-stop diagnostic, through combat and Restart. Read-only peer review found no blocking correctness gap. Recordings, traces and regression result bundles remain in ignored local evidence. The touch-parity work additionally validates the final release position, rather than relying on the last move callback. These checks do not establish phone gestures, multi-touch, audibility, performance or acceptance. At this handoff [PR #187](https://github.com/RonildoBraga/lauder/pull/187) was unmerged and not uploaded, and build 36 remained delivered. The separately authorised [build 37 preview](#build-37-testflight-preview) subsequently delivered the integrated corrections; it does not merge the PR or establish physical acceptance.

## Weapon sounds — in development

[Issue #162](https://github.com/RonildoBraga/lauder/issues/162) gives the paired weapons their own sounds. In a Claude session on 27 November 2026, which has no public permalink, the maintainer said: “see if you can help and start resolving all the git issues”. The work is on `claude/weapon-sounds`, based on the build 36 source (`codex/testflight-guard-damage`, [PR #185](https://github.com/RonildoBraga/lauder/pull/185)).

- **Sounds:** `apple/scripts/make-sounds.py` now generates sixteen sounds instead of eight.
  - **Weapons:** the five damaging paired weapons each have a voice: long rifle, assault rifle, shotgun, sword swing and minigun round. The dome is the sixth paired weapon, with separate state cues below; the hostiles' rifle retains its own.
  - **Minigun:** it whines as it spins up.
  - **Tom's dome:** it has five: rising, running down with 1.5 s left, let go or dropped, run out, and recharged in his hands.
  - **Removed:** the old carbine, light-burst and close-scatter sounds, made for the weapons that [ADR 0021](decisions/0021-paired-weapons.md) replaced.
- **Events:** the fight reports when a minigun begins to spin up, for the leader and for companions. It reports each change of the dome once.
- **Vibration:** the leader feels each weapon, the spin-up, and the dome rising and breaking. The DualSense trigger profiles are unchanged.
- **Verification:** `./scripts/check` passed on an iOS 27 iPhone 17 Simulator:
  - 13 declaration-contract tests, 31 offline release-contract tests and 52 Blender tests;
  - the 16 generated sounds;
  - strict Swift formatting, the app build and Swift Testing.
  - **New tests** cover each sound's mapping, the spin-up heard once for each hold, and each change of the dome heard once.
  - A script measured each sound's length, loudness over time and pitch direction. None has been heard on a phone.
- **Not verified:** nobody has heard the sounds or felt the vibrations on a phone. That waits for the next agreed phone check, listed under [deferred phone and playtest checks](#deferred-phone-and-playtest-checks).

## Guard damage and feedback — in development

On 27 November 2026 the maintainer requested damage from every successful hit, with increased damage for the appropriate companion/weapon at an enemy weakness, white normal numbers, red weak-point numbers and restrained effective-hit feedback. They approved the shared-health proposal with **“Proceed with your recommendations”** (chat; no public permalink). [Issue #183](https://github.com/RonildoBraga/lauder/issues/183) records that explicit assignment. It authorises this bounded damage/feedback revision, including directly related contact and presentation findings in [issue #180](https://github.com/RonildoBraga/lauder/issues/180), without authorising merge or another TestFlight delivery.

The [damage contract](damage-feedback.md) owns the exact rules. Starting tuning is **1,500 shared guard health**, normal damage **48 / 5 / 45 / 30 / 3** for long rifle / assault rifle / shotgun / sword / minigun, and **×3** for the matching weapon at an exposed part. Real body, closed-part and unmatched hits cause normal damage; misses and scenery/ally contacts do not cause enemy damage. Values are playtest starting points rather than settled balance. Player and companion hits use the same math, with no additional actor-identity gate.

The sensor → coupling → core route becomes optional. Matched sensor/coupling hits retain persistent structural progress and recovery still supplies four-second core windows, but neither the part chain nor twelve core contacts is required for a kill. Zero health is the sole damage-based victory condition. This supersedes the mandatory-rule assertions in earlier preview records below, without rewriting what those sources actually tested or delivered.

After explicit Attack and engagement, companions prefer useful exposed matching parts and otherwise use safe ordinary fire with their native guns. Defend remains cease-fire and recall; hard Go/Hold, manual leadership, cover/spacing, ordinary weapon timing, the quiet bypass and lifecycle remain authoritative. The guard's existing warnings, precision/fan patterns and party injury/retry rules retain their owners. No random critical-chance system, signature ability, new enemy, scene or art is assigned.

Resolved applied-damage events supply one health bar and bounded noninteractive white/red numbers with a weak-point symbol, dark contrast and brief animation. Minigun and assault-rifle contacts aggregate over an initial **0.30 s** by enemy/attacker/weapon/effectiveness, preserving every applied amount without mixing normal and effective totals. Initial label lifetime is **0.8 s**, with at most **eight** visible labels. The existing shot presenter adds four reusable effective-hit glints; marker materials are cached. Pause/interruption/Retry/Restart must not replay stale numbers or duplicate strike sounds.

### Damage and feedback verification

On 27 November 2026, application/test/tooling source **`533f012`** passed the full `./scripts/check`: 13 declaration-contract tests, 31 offline release-contract tests, 52 Blender extension tests, eight generated sound fingerprints, strict Swift formatting, the app build and hosted Swift Testing, including all **twelve headless gameplay routes**. [GitHub Check run 98](https://github.com/RonildoBraga/lauder/actions/runs/45906054883) also passed on that source. No Swift source warnings remained. Read-only code and documentation reviews found no remaining blocker. Later documentation-only changes retain the same app, asset, test and tooling fingerprints.

Native rule/contact regressions verify positive ordinary, closed-part and unmatched damage; exact exposed bonuses; optional sensor/coupling progress and recurring core windows; all five damaging weapons reaching zero health without a part prerequisite; correct finite/overkill/reset behaviour; one applied result per contact; point-blank weak-point interior rejection; and sword-body reach, facing and solid-cover feedback. Those ordinary-solo tests isolate incoming damage to test outgoing rules. The encounter drivers explicitly order **Attack** and allow real companion support, so their completion demonstrates squad play with the ordinary injury/retry rules rather than solo survival. They use ordinary shared inputs, without injecting health, phase, weapon state or immunity.

Planner/native regressions verify safe ordinary companion attacks when a specialist opening is unavailable, persistent draw/reload through cached body-fire goals, actual damage, weak-point preference, hard Go/Hold priority, Defend cease-fire/recall, player ownership and quiet bypass. World/feedback regressions verify one captured damage/audio event batch, actual applied sums, projection height, rapid aggregation boundaries and separated categories, bounded labels, stable Reduce Motion placement, Pause freeze, background cancellation and Retry/Restart. The damage event does not duplicate impact audio or haptics. Marker materials are reused rather than recreated each frame.

Clean rendered iPhone 17 / iOS 27.0 Simulator runs on the same source:

| Route | Duration | Peak hits: Miki / Laura / Tom | Retries | Applied normal / weak-point damage | Frame p99 / max | Party update mean / p99 | Body overlap frames |
|---|---:|---:|---:|---:|---:|---:|---:|
| `damage-feedback` | 63.8 s | 2 / 0 / 0 | 0 | 1194 / 306 | 16.76 / 33.35 ms | 1.247 / 2.875 ms | 2.2% |
| `companions` | 71.8 s | 0 / 0 / 1 | 0 | 483 / 1017 | 16.81 / 220.23 ms | 1.246 / 3.811 ms | 2.7% |
| `weapons` | 65.5 s | 1 / 0 / 0 | 0 | 906 / 594 | 16.76 / 232.39 ms | 1.145 / 2.590 ms | 12.5% |
| `first-fight` | 84.9 s | 2 / 0 / 1 | 0 | 780 / 720 | 16.77 / 164.77 ms | 1.252 / 5.719 ms | 0.2% |
| `retaliation` | 62.3 s | 0 / 1 / 0 | 0 | 663 / 837 | 16.79 / 198.87 ms | 1.380 / 4.634 ms | 2.3% |

All five passed through native victory and Restart, with zero stuck-companion diagnostic frames. Every route's normal plus weak-point totals and member contributions equal exactly **1,500 health lost**. Each observed at most **five** simultaneous labels, within the cap of eight. In `damage-feedback`, six real assault-rifle contacts first removed **30 health** while the squad remained in Defend; the complete encounter total was **1,194 normal + 306 weak-point damage**. Miki / Laura / Tom contributed **795 / 540 / 165**. The rendered white grouped total and red **144** sensor hit with its accent are readable against the snow, and the compact health row/bar does not wrap. Restart restores health to 1,500 and cancels prior feedback. The Debug summary alone retains cumulative evidence across Restart; live labels and encounter state reset.

In `companions`, Miki stayed player-controlled while native companion weapons supplied the other contributions: **144 / 501 / 855** by Miki / Laura / Tom. Defend retained health and stopped companion ammo spend/fire during the three-second recall observation; later Attack resumed contributions. The observation records actual inward companion movement and an improved live gap, so a late leader roll does not invalidate an earlier return. Regressions reject a stationary follower even when the leader moves towards them; this corrects a driver measurement, not production AI or collision.

**Limits and next gate:** These are scripted Simulator observations, not settled combat balance or phone acceptance. Physical controls, multi-touch, warning audibility, phone readability, sustained performance and enjoyment remain unverified for this revision. Reduce Motion allocation is regression-tested; the recording uses normal motion. Moving bodies still overlap, reaching **12.5%** of frames in the paired-weapon route, and isolated rendered frames reached **232.39 ms**. This does not establish permanent companion separation or sustained 60 fps on the phone. Other findings in #176–179, including the [guard-tracking case in #178](https://github.com/RonildoBraga/lauder/issues/178), remain separate. Review [PR #184](https://github.com/RonildoBraga/lauder/pull/184), then use an agreed phone comparison to judge whether ordinary hits feel useful and weakness rewards justify repositioning/switching. The implementation task added no further scene, enemy, signature or art and did not authorise merge or release. The later explicit delivery request and verified [build 36 preview](#build-36-testflight-preview) supersede that delivery checkpoint; physical acceptance and merge remain separate.

## Bridge cover and spacing — in development

On 27 November 2026 the maintainer said **“Looks good. Go ahead and improve the cover and companion spacing on the bridge.”** This explicitly assigns the bounded [cover/spacing comparison](bridge-cover-spacing.md), recorded in [issue #174](https://github.com/RonildoBraga/lauder/issues/174), without authorising a merge or another TestFlight delivery.

Two simple approach shelters, `bridge-cover-west` and `bridge-cover-east`, accompany **1.2 m desired clearance between autonomous destinations**. The existing centre passage, east coupling approach and quiet west arch must remain usable. Reservations respect explicit Hold/Go anchors, the leader and other intended places; actual collision, rays, threat, weapon execution and the existing leash/recall bounds retain authority. Normal formations outside the fight, guard damage, alternating patterns, timings and weakpoint rules remain unchanged.

### Cover and spacing verification

On 27 November 2026, source **`60428d3`** passed `./scripts/check`: 13 declaration-contract tests, 31 offline release-contract tests, 52 Blender extension tests, eight generated sounds, strict Swift formatting, the app build and hosted Swift Testing, including all **eleven headless gameplay routes**. No Swift source warnings remained. Read-only source and documentation reviews found no outstanding blocker after replacing repeated tactical path construction with connected-region admission; the existing motor retains sole ownership of cached routes. Subsequent documentation records these results without changing application source, assets, tests or tooling.

Geometry tests verify separate roomy rear places, both real gun origins blocked at samples throughout native patrol/turning/bracing/precision/fan/recovery poses, traversable centre/east/quiet-west lanes and clearance around the guard's whole movement envelope. Visual bounds match the authored boxes. Planner/native regressions cover shared reservations, immediate occupied-goal invalidation, crowded firing steps, stable uncovered fallback, nearby shelter behind a forward-facing formation, progressive distant recall, explicit Go/Hold, switching, lifecycle, native role weapons and reset. Older fight drivers now peek through a real clear lane and roll on an observed commitment; hit/discharge tests observe actual native events rather than a transient activity label. No phase, damage or weapon state is injected into the ordinary-input routes.

Clean rendered iPhone 17 / iOS 27.0 Simulator runs on the same source:

| Route | Duration | Peak hits: Miki / Laura / Tom | Retries | Frame p99 / max | Party update mean / p99 | Body overlap frames |
|---|---:|---:|---:|---:|---:|---:|
| `cover-spacing` | 63.1 s | 0 / 0 / 1 | 0 | 16.75 / 33.37 ms | 1.264 / 4.088 ms | 1.9% |
| `companions` | 63.9 s | 0 / 1 / 1 | 0 | 17.05 / 216.50 ms | 1.363 / 4.751 ms | 2.7% |
| `first-fight` | 81.1 s | 1 / 0 / 1 | 0 | 16.76 / 220.08 ms | 1.385 / 5.581 ms | 0.0% |
| `retaliation` | 55.0 s | 0 / 0 / 0 | 0 | 16.80 / 230.74 ms | 1.297 / 3.903 ms | 0.7% |

All four passed through ordinary shared input, including native dismantling and Restart, with zero stuck-companion diagnostic frames. In `cover-spacing`, both followers arrived at their actual destinations by 52.90 s: Tom `[4.953, 10.346]` and Laura `[8.322, 10.422]`, with Miki `[6.439, 9.834]`. Their **3.37 m** separation and respective **1.57 / 1.97 m** leader distances satisfied the selected spacing/nearby-recall bounds. The real two-muzzle cover query stayed true for both bodies during a continuous **1.00 s** settled interval, and another **0.52 s** after Pause/Resume. Companion ammo/progress stayed unchanged throughout Defend. A later Attack completed the real core contribution while Miki remained player-controlled. Tom's earlier hit remained recorded; the route does not depend on immunity.

Visual inspection of the recordings confirms two independently occupied shelters and an open central lane. The headless opening/order routes retain quiet bypass, formations, hard orders, switching and reset. The cover route's continuous settled intervals are bounded observations, not a claim of permanent safety or spacing. Body overlap still occurred briefly during movement, reaching 2.7% of frames in one run, and three recordings include isolated long frames above 200 ms. Simulator timings do not establish sustained phone performance. Physical controls, warning audibility, phone readability, balance and enjoyment remain unverified for this change. [PR #175](https://github.com/RonildoBraga/lauder/pull/175) is the cover review handoff. At that checkpoint build 35 remained delivered, with no merge or new upload in the cover assignment. The later [build 36 preview](#build-36-testflight-preview) includes these changes without establishing phone acceptance.

## Guard retaliation — in development

The maintainer reported **“The Attack and Defend controls are working”**, then authorised the bounded recommendation with **“proceed”**. [Issue #171](https://github.com/RonildoBraga/lauder/issues/171) records that chat direction. The report confirms basic commands only; it is not every-input acceptance, sustained performance evidence or merge/release permission.

On `codex/guard-retaliation`, the engaged guard chooses a visible recent native attacker between cycles, otherwise acquiring the leader under the existing rules. A named HUD warning and one two-note cue identify the threatened member. Target identity stays fixed through warning, commitment, burst and recovery; the committed point stays fixed after commitment. The [retaliation contract](guard-retaliation.md) owns selection, flank fairness and lifecycle details. Damage, patterns, existing timing and weakpoint requirements remain unchanged, as do explicit Attack/Defend, orders and the west bypass. That earlier comparison did not include cover edits; the 27 November cover/spacing assignment above is separate.

### Retaliation verification

On 26 November 2026, the frozen application source passed `./scripts/check`: 13 declaration-contract tests, 31 release-contract tests, 52 Blender extension tests, eight generated sounds, strict Swift formatting, app build and hosted Swift Testing, including all ten headless gameplay routes. No Swift source warnings remained. Rule/native/world regressions cover actual discharges and sword contact rather than intentions, attack-memory expiry and deterministic ties, real visibility, quiet acquisition, target identity across switches and Defend, fixed committed rays, one warning per notice entry, Pause, bypass, Retry and Restart. Pending-warning tests reject cues after interruption or an ended burst while retaining real shot/impact history; Defend retains an already warned attack. Read-only implementation and feedback reviews found no remaining correctness blocker.

Clean rendered iPhone 17 / iOS 27.0 Simulator runs on the same application source, through ordinary shared input:

| Route | Duration | Peak hits: Miki / Laura / Tom | Retries | Frame p99 / max | Party update mean / p99 | Body overlap frames |
|---|---:|---:|---:|---:|---:|---:|
| `retaliation` | 54.2 s | 0 / 0 / 2 | 0 | 16.80 / 33.35 ms | 1.584 / 5.044 ms | 0.6% |
| `companions` | 55.2 s | 1 / 0 / 0 | 0 | 16.84 / 200.29 ms | 1.500 / 5.183 ms | 1.2% |
| `first-fight` | 80.4 s | 2 / 0 / 1 | 0 | 17.10 / 164.79 ms | 1.953 / 7.033 ms | 0.4% |

All three passed with Restart and zero stuck-companion diagnostic frames. The Debug runner now retains each member's peak injury count and counts retry transitions, including across cleared injury snapshots at victory/Restart. These are observed injuries under the ordinary three-hit retry rule, not injected damage or immunity. Simulator timings, including the recorded long frames, do not establish phone performance.

The new route keeps Tom under player control without Fire, allowing real Miki/Laura contributions to provoke retaliation. At 47.12 s the guard warned Laura; normal leader cycling, Defend and a real roll followed. Commitment at 49.04 s and recovery at 50.29 s both retained Laura and exactly `[4.7238855, 8.224512]` as the committed point. The five-round fan completed, then Attack resumed and native core fire dismantled the guard at 51.74 s. Tom's two hits show that Defend and switching do not cancel enemy fire or protect the rest of the party from crossfire. The independent `companions` route also retained the sensor/coupling/core sequence, cease-fire/recall and a later Laura-targeted cycle without taking control from Miki.

Visual inspection caught and corrected wrapping of a threatened companion's name: the three short name/pip groups now occupy their own row, with formation text below. The corrected full-panel warning is readable in the recording. Waveform/resource/event tests establish the generated two-note cue and its cancellation boundaries, not actual audibility; Simulator video has no audio. Phone readability, physical controls, sustained performance, balance and enjoyment remain unverified for this branch. A short scripted fight supplies only a small number of retaliation cycles; evaluate the comparison before changing cover, damage or timings. At that source-verification checkpoint, build 34 was the latest delivered preview and no new upload had occurred. The later authorised build 35 delivery below supersedes that delivery status; no merge occurred.

## Companion autonomy — in development

The maintainer reported build 33 **“It worked nice”**, then asked for independent companions and chose **“Companions can complete the weakpoint steps too”**. This authorises the [bounded companion contract](companion-autonomy.md), not a generic AI framework or new scene. All three characters still contribute through their actual native weapons; changing leader is available but no longer mandatory for every step.

The maintainer then clarified that companions should attack only after **Attack**, while **Defend** on the D-pad should make them seek cover and return. The squad now defaults to Defend. D-pad/arrow Up orders Attack; Down orders Defend, immediately revoking companion fire permission and clearing old position orders to recall them via nearby legal cover. Fire alone controls only the leader. The stance persists across leader switches; Retry/Restart returns to Defend. This correction has passed the checks below.

With Attack permission and an engaged guard, companions choose nearby legal positions/cover and avoid committed fire where possible, with an initial 8 m leader leash. Hold anchors and Go destinations otherwise override autonomous movement, and subsequently issued position orders do not arm attacks. Formation/Follow retains its existing meaning and temporary regroup without changing stance; retreat suppresses attacks. Actual rays, armour, weapon readiness/ammunition/cadence and turn rates remain authoritative; companions gain no teleportation, immunity, automatic shields or signatures.

### Explicit stance verification

On 26 November 2026, `./scripts/check` passed after the correction: 13 declaration-contract tests, 31 release-contract tests, 52 Blender extension tests, seven generated sounds, strict Swift formatting, the app build and hosted Swift Testing, including all nine headless gameplay routes. No Swift source warnings remained. Added coverage verifies default Defend despite real player engagement, no companion damage/ammo spend after Defend even with stale fire intentions, recall replacing Hold without cycling formation, player Fire remaining available, Attack restored only by command, local returning cover, command priority, touch cancellation, Pause/dialogue and stance reset on Retry/Restart. Read-only implementation and input reviews found no remaining correctness blocker.

Clean rendered iPhone 17 / iOS 27.0 Simulator runs, through shared input:

| Route | Duration | Warning frames | Frame p99 / max | Party update mean / p99 | Body overlap frames |
|---|---:|---:|---:|---:|---:|
| `companions` | 54.9 s | 0 | 16.74 / 50.75 ms | 1.440 / 4.921 ms | 0.0% |
| `first-fight` | 80.9 s | 0 | 16.72 / 33.34 ms | 1.941 / 7.054 ms | 0.7% |
| `weapons` | 62.2 s | 0 | 16.73 / 37.78 ms | 1.698 / 5.094 ms | 1.2% |

All three passed, including Restart. The new route explicitly ordered Attack, allowed the real sensor/coupling steps, issued Hold then Defend, observed three seconds with no companion damage or ammo spend while recalling, then issued Attack again and completed the core. Miki remained player-controlled. The observed state stayed Defend throughout the cease-fire and core damage stayed zero; the final accepted core count reached 12 only after the new Attack. The widest leader gaps were 3.44, 3.82 and 3.58 m respectively. The HUD showed the stance and Up/Down commands. A subsequent native Simulator UI check invoked the touch Formation control's exposed Squad Attack and Squad Defend actions and observed each HUD transition, ending in Defend.

These are Simulator results; brief overlaps and the recorded frame maxima remain limitations, and the controller-hint strip remains dense. The touch-menu selection/clamping and cancellation tests passed, but the UI check used its accessibility actions rather than a physical ground-menu gesture. No new physical controller, multi-touch, sustained phone performance or enjoyment is established. The [build 34 delivery](#build-34-testflight-preview) is verified below; physical acceptance and merge remain separate gates.

### Earlier autonomous-engagement verification

The first autonomy source, `14193d5`, passed these checks on 26 November 2026 before the explicit stance correction:

- `./scripts/check` passed on the final source: 13 declaration-contract tests, 31 offline release-contract tests, 52 Blender extension tests, seven generated sounds, strict Swift formatting, the shared app build and hosted Swift Testing suite. This includes 20 new companion tests and all nine headless gameplay routes, with no Swift source warnings in the final run.
- Pure planner and native/world tests cover role weapons, closed components, real contact/cover/ally rays, draw/cadence/magazines, facing, awareness and player-contact activation, quiet bypass, local routes/leash, cached-target invalidation, threat avoidance, order priority, leader authority and Pause. The nine headless gameplay routes passed in the integrated run.
- Read-only peer reviews found a formation-target feedback issue; separate fresh formation targets now prevent tactical targets feeding into the next base formation. Real sword contact activates support, and actual per-frame companion movement/turning drives spread. Re-review found no remaining correctness blocker.
- A second world regression kept Tom under ordinary player control without firing: Miki disabled the sensor and Laura breached the coupling, while Tom retained a full magazine and the core stayed undamaged. Thus each companion's native contribution is covered without making the selected leader automatic.

Rendered iPhone 17 / iOS 27.0 Simulator results, through ordinary shared input:

| Route | Duration | Warning frames | Frame p99 | Party update mean / p99 | Body overlap frames |
|---|---:|---:|---:|---:|---:|
| `companions` | 49.0 s | 0 | 17.29 ms | 1.171 / 3.085 ms | 0.0% |
| `first-fight` | 80.9 s | 0 | 16.73 ms | 1.417 / 3.493 ms | 0.7% |
| `weapons` | 58.4 s | 0 | 16.82 ms | 1.216 / 3.699 ms | 1.3% |

All three rendered routes passed, including Restart. In `companions`, Miki stayed under player control and supplied only the sensor shot; Laura breached the coupling and Tom supplied 12 accepted core rounds. The captured stage changed from sensor through coupling and reactor to complete, without another player Fire or leader switch. The widest leader gaps were 3.46, 4.10 and 3.23 m respectively. Short body overlaps on the other routes remain visible in the measurements. The runs use the ordinary roll defence, with no added immunity or teleportation. Frame maxima were 33.34, 180.37 and 33.33 ms, so the first-fight run includes an isolated hitch despite its low p99.

The new activity line is readable in the Simulator captures; the bottom controller-hint strip remains dense. These are Mac Simulator results, not sustained phone frame-pacing, controller/touch acceptance or a judgment of enjoyment. The AI remains limited to this guard, and the player must still supply the currently controlled character's role. At that earlier checkpoint, review and the next authorised phone/release were outstanding and build 33 was the delivered version; the later build 34 record below supersedes that delivery status.

## Strategic guard — in development

This section records the manual-control implementation delivered in build 33 below; its heading remains a stable link for earlier PRs. Companion autonomy is the newer assignment above.

The maintainer authorised an encounter that rewards manually directing all three existing characters. [Strategic guard](strategic-guard.md) records the branch's prototype rules: Miki's long rifle persistently disables the sensor, Laura's sword persistently breaches a side coupling, and Tom's minigun supplies 12 accepted reactor rounds across repeatable 4-second exposure windows opened by recovery. Ordinary armour damage and wrong-role weapons cannot skip those contributions. The guard alternates three precision rounds and a five-round fan cannon attack, with readable wind-ups and no exact red aim line. The west bypass stays open.

In delivered build 33, L1 / LB, Q and touch Next switch leader manually; followers follow or hold without automatic attacks. Tom's dome drops on a leader switch. That preview also contains the fixes for sword strikes through solid cover and ground markers hidden by baked tower shadows. Existing pawns, camera, scene, input authority and real shot geometry remain the basis of the experiment.

Verification on 26 November 2026:

- `./scripts/check` passed: declaration contracts and 13 contract tests, 28 offline release-contract tests, 52 Blender extension tests, seven generated sounds, strict Swift formatting, the app build and hosted Swift Testing suite. All eight headless gameplay routes passed through ordinary input.
- Contact tests cover assisted/manual/locked shots, every missing-role solo/pair, wrong weapons, real armour/cover, outside-hull side contact, elevated targets, persistent progress, missed windows, Pause, retry and reset. Continuous hull tests cover walking, rolling, sliding and safe overlap escape.
- Read-only peer review identified the hull-entry and low-cover elevation defects; both were addressed and re-reviewed with no remaining blocker.

Rendered iPhone 17 / iOS 27.0 Simulator results:

| Route | Duration | Companion warning frames | Frame p99 | Party update mean / p99 |
|---|---:|---:|---:|---:|
| `first-fight` | 81.0 s | 0 | 16.75 ms | 0.993 / 2.017 ms |
| `weapons` | 65.0 s | 0 | 16.89 ms | 1.006 / 2.249 ms |
| `lock-on` | 54.7 s | 0 | 16.76 ms | 1.010 / 2.006 ms |

All three routes passed, including the complete dismantling sequence and Restart. Captures show the front sensor, side coupling, closed/open core and countdown, both attack warnings, and ground markers above the tower shadows. These are Simulator measurements on the Mac, not phone performance results. Component spheres remain prototype targeting cues and the controller-hint strip remains dense.

### Build 33 TestFlight preview

Internal TestFlight **0.1.0 (33)** was delivered from `f67bd2c` through [PR #167](https://github.com/RonildoBraga/lauder/pull/167), using the explicit reviewed-preview path before merge. Its manual strategic guard builds on [PR #166](https://github.com/RonildoBraga/lauder/pull/166); followers in that build do not attack. The delivery record on PR #167 is the source for processing and existing-tester availability.

The maintainer reported **“It worked nice”** in chat. Record this as general phone success only: no individual controller/touch checklist, readability measurement or sustained frame-pacing capture was supplied. It is not merge permission. The reviewed preview does not establish that either PR has merged into `main`. Remaining phone-specific checks and any merge/release require their applicable gates; the newer autonomy branch has its own verification above.

### Build 34 TestFlight preview

On 26 November 2026 the maintainer explicitly requested delivery of the Attack/Defend controls through TestFlight. Internal **0.1.0 (34)** was archived and uploaded from clean reviewed-preview source **`7d0d5cadae82d5da2e03020629be27732169240a`** on `codex/testflight-squad-commands`, through [PR #170](https://github.com/RonildoBraga/lauder/pull/170). App code is exactly [PR #169](https://github.com/RonildoBraga/lauder/pull/169)'s `1cdbcb0`; the only archive-source difference is the committed Debug/Release build number 33 → 34. This delivery did not merge the open preview PRs.

- Discovered Lauder's own App Store Connect record by `com.ronildo.lauder` and checked accepted/processing uploads plus existing builds before selecting unused build 34; refreshed reservations before archive and upload.
- Independent review verified the exact metadata-only source change. Automated review completed on the exact archive source with no findings, and [GitHub Check passed](https://github.com/RonildoBraga/lauder/actions/runs/45745307506) for that same commit.
- The release workflow reran `./scripts/check` on that frozen tree: formatting, app build, hosted Swift Testing and all nine headless routes, 13 declaration-contract tests, 31 release-contract tests, 52 Blender extension tests and seven generated sounds. A successful receipt and log digest bind those checks to the archived commit. The preceding rendered Attack/Defend results remain recorded above; no app code changed afterward.
- Verified Release archive identity/version/build, selected signing team, code signature and matching dSYM. Archive and upload used the existing API key with provisioning updates, not a saved-account login. Signing material, credentials and full receipts remain private.
- Apple confirmed upload **COMPLETE**, processing **VALID**, **IN_BETA_TESTING**, **INTERNAL_ONLY**, unexpired. Every intended existing internal group contains the build; group set and tester membership are unchanged. The en-AU test notes were written and read back exactly.

The preview starts in Defend. D-pad Up permits companion attacks and weakpoint completion; Down stops their fire and recalls them via available cover. TestFlight availability is verified. The maintainer later reported **“The Attack and Defend controls are working”**: basic command feedback only, without an individual D-pad/touch checklist, sustained performance capture or balance judgement. No uninstall, additional testers, pricing change or public App Store submission occurred. At that build-34 checkpoint, retaliation had not been delivered; the subsequent build 35 record below covers its delivery. Build 33 remains the historical manual-control preview.

### Build 35 TestFlight preview

After viewing the reviewed Simulator result, the maintainer replied **“proceed”** to the recommendation to publish the retaliation version for a short TestFlight comparison. Internal **0.1.0 (35)** was archived and uploaded from clean reviewed-preview source **`8a9908a910ec065a534d45546bf6804e18971513`** on `codex/testflight-guard-retaliation`, through [PR #173](https://github.com/RonildoBraga/lauder/pull/173). App code is exactly [PR #172](https://github.com/RonildoBraga/lauder/pull/172)'s reviewed `251ee09`; the only archive-source difference is the committed Debug/Release build number 34 → 35. This delivery did not merge the open preview PRs or change cover, damage or timing.

- Discovered Lauder's own App Store Connect record by `com.ronildo.lauder` and checked accepted/processing uploads plus existing builds before selecting unused build 35; refreshed reservations before archive and upload.
- Independent review verified the exact metadata-only source change. Automated Codex review completed on the exact archive source with no findings, and [GitHub Check passed](https://github.com/RonildoBraga/lauder/actions/runs/45796142046) for that same commit.
- The release workflow reran `./scripts/check` on that frozen tree: formatting, app build, hosted Swift Testing and all ten headless routes, 13 declaration-contract tests, 31 release-contract tests, 52 Blender extension tests and eight generated sounds. A successful receipt and log digest bind those checks to the archived commit. The earlier rendered retaliation comparison remains recorded above; no gameplay code changed afterward.
- Verified Release archive identity/version/build, selected signing team, code signature and matching dSYM. The new warning sound is present in the archive. Archive and upload used the existing API key with provisioning updates, not a saved-account login. Signing material, credentials and full receipts remain private.
- Apple confirmed upload **COMPLETE** with no upload errors, processing **VALID**, **IN_BETA_TESTING**, **INTERNAL_ONLY**, unexpired. Every intended existing internal group contains the build; the internal group set and tester membership are unchanged. The en-AU test notes were written and read back exactly.

Build 35 is available to install from TestFlight. The notes ask whether the threatened character is obvious, Defend returns companions towards useful cover, and switching leaders/resuming Attack feels satisfying. Physical installation, warning audibility, phone readability/controls, sustained performance and enjoyment remain unverified. No uninstall, additional testers, pricing change or public App Store submission occurred. Cover/spacing changes follow this comparison and their own assignment.

### Build 36 TestFlight preview

On 27 November 2026 the maintainer asked **“Can you deploy to my phone using TestFlight so I can test it”** (chat; no public permalink). This separately authorised an internal preview of the reviewed guard-damage revision, not a merge or public App Store submission. Internal **0.1.0 (36)** was archived and uploaded from clean reviewed-preview source **`2db6130494002369222b4980b6aa46efa8b36d99`** on `codex/testflight-guard-damage`, through [PR #185](https://github.com/RonildoBraga/lauder/pull/185).

App code, assets, tests and tooling match [PR #184](https://github.com/RonildoBraga/lauder/pull/184)'s reviewed `e4d5f86`; the only source change is the committed Debug/Release build number **35 → 36**. This delivers the shared health and optional weakness rules, ordinary companion attacks and white/red feedback verified above, along with the preceding bridge cover/spacing and guard retaliation. Later delivery-documentation edits do not change the frozen archive source. The open preview PRs remain unmerged.

- Discovered Lauder's own App Store Connect record by `com.ronildo.lauder`, checked accepted/processing uploads and existing builds before selecting unused build 36, and refreshed reservations before archive and upload. Existing internal-group and tester membership supplied the unchanged delivery baseline.
- Independent review verified the exact two-field build-number change. Automated Codex review completed on the exact archive source with no findings; [GitHub Check run 100](https://github.com/RonildoBraga/lauder/actions/runs/45908158640) passed on that same commit.
- The release workflow reran `./scripts/check` on the frozen source: 13 declaration-contract tests, 31 offline release-contract tests, 52 Blender extension tests, eight generated sound fingerprints, strict Swift formatting, the app build and hosted Swift Testing, including all **twelve headless gameplay routes**. A successful receipt and log digest bind those checks to the archive. The five preceding rendered damage/companion/weapon/retaliation runs remain recorded above; the version-number change did not alter their gameplay source.
- Verified the Release archive's Lauder identity, version/build, selected signing team, code signature and matching dSYM. Archive and upload used the existing App Store Connect API key with provisioning updates, without relying on Xcode's saved-account session. Credentials, signing material, archive, symbols and full receipts remain private.
- At **2026-11-26 23:15:59 UTC**, Apple verification confirmed upload **COMPLETE** with **zero errors**, processing **VALID**, **IN_BETA_TESTING**, **INTERNAL_ONLY** and an unexpired build. Every intended existing internal group contains the build; the internal group set and tester membership are unchanged.
- The **en-AU** test notes were written and read back exactly at **2026-11-26 23:14:27 UTC**. They ask testers to compare ordinary hits and matching weak-point attacks, Attack/Defend, leader/weapon switching, cover recall, number/warning readability, Pause/Resume and Restart.

Build 36 is available by choosing **Update** for Lauder in TestFlight; the pause menu identifies **0.1.0 (36)**. Availability is verified, while physical installation, controller/touch behaviour, audibility, phone readability, combat balance, sustained performance and enjoyment remain unverified. The recorded companion overlaps and isolated Simulator frame spikes remain playtest questions, not resolved phone-performance claims. No uninstall, additional tester invitation, pricing/availability change or public App Store submission occurred. Merge and any further delivery keep their own gates.

## Structural preparation

The approved structural preparation is merged: [PR #125](https://github.com/RonildoBraga/lauder/pull/125) separates camera motion and bridge progression, clarifies encounter naming, splits combat values into cohesive files and adds narrow declaration checks with CI. [PR #126](https://github.com/RonildoBraga/lauder/pull/126) adds reproducible TestFlight tooling. [ADR 0018](decisions/0018-runtime-boundaries.md) records the boundaries. Those structural changes did not change gameplay or story.

## Purpose and scope

Use the retained bridge to decide what is enjoyable before expanding again. This cleanup preserves its existing opening, party movement, native weapons and input paths. It does not redesign the story or author a replacement core loop.

The story's foundations remain in the [story bible](story/story-bible.md). Exploration and salvage lead the intended game, with occasional combat; the current opening samples movement, one guard that can be fought or bypassed, and a crossing by all three from the start. The supply-case interaction and recruitment scenes are removed. Later narrative proposals are reference material, not playable content or assignments.

## The opening

The [walkthrough](gameplay-script.md#the-brooklyn-bridge-opening) follows Miki, Tom and Laura from the Brooklyn end to Manhattan:

1. Move, look, switch leaders and try the formations on the snowbound bridge, the three together from the start.
2. Meet the C robot at the first tower. Fight using the tower as cover, or take the west arch to its safe exit. Each committed burst can cause at most one injury; a third injury retries that fight.
3. Cross the second tower together. Try Close/Spread/Column and move/hold orders, then gather at the Manhattan end.

Only the bridge is available. Pause has Resume, Restart, Vibration and, with a controller or keyboard, Status panel. There is no alternate-scene selector, weapon bench, endless spawn, automatic combat-cover controls, grenade, signature, elevation or salvage-repair system.

## Input and interaction contract

| Intent | PS5 / Xbox | Touch | Keyboard |
|---|---|---|---|
| Move active character | Left stick | Bottom-left analog stick | WASD |
| Look around, advance dialogue or confirm menu | Cross / A | Look, Continue, or Restart while paused | E |
| Next leader, going round the party | L1 / LB | Next: name | Q |
| Change formation; call ordered companions back first | Triangle / Y | Formation / Follow | R |
| Permit companion attacks / cease fire and recall via cover | D-pad up / down | Hold on ground, then the drawn Attack / Defend choice | Up / down arrows |
| Send left / right member ahead | D-pad left / right | Hold on ground, then a name | Left / right arrows |
| Both go / both hold | No direct binding | Hold on ground, then Both / Hold | G / H |
| Tom throws one grenade while leading | Circle / B | Grenade (Tom only) | C |
| Use the weapon in hand: fire a gun, swing the sword or hold up the dome; automatic reload | R2 / RT | Fire, with assisted aim | F |
| [Switch](decisions/0021-paired-weapons.md) to the other weapon | R1 / RB | Swap: weapon | T |
| Aim apart from movement | Right stick | Assisted aim | I, K, J, L |
| [Lock the aim](decisions/0020-lock-on.md) on a hostile, or move it to the next; two quick controller/keyboard presses let go | R3 / RS, a press of the right stick | Tap an enemy to select; tap it again to release; Fire accessibility actions target / next / let go | O |
| Dodge roll: the leader tumbles 3 m the way they move, or face, while hostile shots pass through | Square / X | Roll | Space |
| Pause / Resume | Options / Menu | Pause / Resume | Escape |
| Choose Resume, Restart, Vibration or Status panel while paused | Stick or D-pad up/down, then Cross / A | Resume, Restart, Vibration or Status panel | W/S or up/down, then E |
| Hide/show status panel | Pause, then Status panel | Pause, then Status panel: On/Off | Pause, then Status panel |

Touch is automatic without an extended controller. An attached controller is preferred unless **Use touch controls** is chosen; **Use controller** returns to it. Keyboard remains available. These sources share InputRules and session authority. Xbox uses the shared extended-gamepad path; hardware delivery remains unverified.

Touch taps select the visible whole-body envelope, using full height and navigation radius with a 30-point exterior allowance. An empty valid tap retains an on-screen or partly visible lock and releases an entirely off-screen one; assisted aim remains available without a lock. The [touch contract](touch-controls.md) describes the short-tap/hold distinction, shared drawn order-menu choices and edge limitations. Release guidance stays visible when the status panel is hidden.

Switching preserves positions and progress; held movement can continue on the new leader. Circle / B throws a grenade only while Tom leads. A weapon switch needs a fresh press, and each weapon keeps its magazine. Switch, formation and order commands consume a simultaneous action, roll or grenade request. Grenades need a fresh press and cannot queue during recharge. A roll needs a fresh press, fires nothing and waits 0.5 s after the last. A lock press needs a fresh press too; one within 0.3 s of the last lets go, and a lock also lets go once its hostile is down or more than 30 m away. Dialogue and Pause consume gameplay edges rather than queueing them. Pause, interruptions, reconnection and source changes require neutral input; every button, key and finger must release, including a finger resting at stick centre.

Formations and orders still need two companions, so a level that starts with fewer than three offers them once the others join; the bridge starts with all three. There is nothing on the bridge to search or help with, so Look only looks around.

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
- **Phone:** in the [build 32 playtest](#build-32-playtest) the maintainer said the weapons and controls, the roll among them, feel right. Not yet verified: frame pacing, how the pawns read at their real size, the touch Roll button with a finger on the stick, and the guard fight's balance with a roll.

### Controls pass

On 26 November 2026, after reviewing a map of the controller's buttons, the maintainer asked for three changes in a Claude session, which has no public permalink:
- **“instead of using R1 and L1 to navigate through the characters, we should just use L1 and go in circles”**. L1 / LB is now the only leader switch. It goes round the party in the order that Next keeps on touch and Q on a keyboard: Miki, Tom, then Laura. Previous and its Z key are gone. This pass freed R1 / RB; the later paired-weapons pass below assigned it to Swap. The D-pad keeps its sides, so right sends whoever L1 would lead as.
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
- **Phone:** in the [build 32 playtest](#build-32-playtest) the maintainer said the weapons and controls feel right. Not yet verified: frame pacing, how the ring reads at the phone's size, and the guard fight's balance with a lock.

### Three together

On 26 November 2026 the maintainer asked: **“I want to simplify the starting of the game so all the 3 companions will start together so no need to meet Tom and Laura later in the game”**. Asked what then happens to the scenes that introduced Tom and Laura, the maintainer chose **“Guard fight only”**. Both were said in a Claude session, which has no public permalink.

- **Start:** Miki, Tom and Laura start at the Brooklyn end, Tom and Laura in the Close formation's places behind Miki, Tom on the right and Laura on the left. Next, the formations and the orders work from the start.
- **Story:** the beats are the crossing, the first-tower guard and the Manhattan end. The supply case's search, the knife attacker's ambush with Tom's shot, Laura's rescue and the medical kit are gone, with their conversations. The closing exchange stays.
- **Removed with them:** the Search and Help actions, loot and the medical kit, so Look only looks around. The supply case stays as scenery, and its unused layout names go at the level's next export. The shared rounds stay until the weapons pass replaces them.
- **Checks:** `./scripts/check` passed: 13 declaration-contract tests, 28 offline release tests, 52 Blender tests, seven sound fingerprints, Swift formatting, the app build, and Swift Testing on an iOS 27 iPhone 17 simulator, 273 tests in 373 runs. Rewritten tests cover the three starting together in their Close places, the beats in order, a bypass leading on to Manhattan, a retry and Restart keeping the three together, and the closing exchange. The headless routes now run `bridge-walk`, `first-fight`, `fight-retry`, `opening`, `formations`, `orders` and `lock-on`; `ambush` and `laura` went with their scenes.
- **Phone:** played in the [build 32 playtest](#build-32-playtest). Not yet verified: frame pacing, and how the guard fight plays with the companions beside the leader from the start.

### Paired weapons

On 26 November 2026 the maintainer gave each character two weapons, and chose how the open points work. The request and choices are quoted in [ADR 0021](decisions/0021-paired-weapons.md).

- **Weapons:**
  - Miki: a long rifle and an assault rifle.
  - Laura: a shotgun and an energy sword that strikes close by and turns shots from in front of her.
  - Tom: a minigun that spins up, and a shield dome that stays up round him while Fire is held.
- **Switching:** R1 / RB, T or the touch **Swap** button brings the other weapon into hand, and each keeps its magazine.
- **Rounds:** none are counted beyond the magazine, and the status shows the weapon in hand.
- **Sounds:** at first each weapon borrowed the nearest existing sound. [Weapon sounds](#weapon-sounds--in-development) gives each its own.
- **Checks:** `./scripts/check` passed: 13 declaration-contract tests, 28 offline release tests, 52 Blender tests, seven sound fingerprints, Swift formatting, the app build, and Swift Testing on an iOS 27 iPhone 17 simulator, 283 tests in 395 runs. New tests cover the pairs and the switch keeping each magazine, the switch press, the long rifle's heavy hit, the assault rifle's rapid fire past a reload, the minigun's spin-up and slower walk, the dome stopping shots for everyone inside it and shots landing once it drops, its run-down and recharge, and the sword striking in front within reach and turning shots from in front only.
- **Simulator:** in the new `weapons` route Tom raises his dome against the guard's bursts and nobody is hurt, then switches to the minigun and brings the guard down. Its screenshot shows the dome round all three, with the status reading **Shield · Up**. Mean frame time was 16.7 ms and p99 16.8 ms, Simulator measurements only.

  | Route | Steps |
  |---|---:|
  | `weapons` | 28/28 |
  | `first-fight` | 35/35 |
- **Phone:** in the [build 32 playtest](#build-32-playtest) the maintainer said the weapons and controls feel right. Not yet verified: frame pacing, the touch Swap button, how the blade and the dome read at the phone's size, and the guard fight's balance, which the heavier hits change.

### Build 32 playtest

TestFlight 0.1.0 (32) was delivered on 26 November 2026 from the head of [PR #158](https://github.com/RonildoBraga/lauder/pull/158), `0a50613`, before any merge. It carries the pawns and dodge roll, the controls pass, the three starting together and the paired weapons. The [delivery record](https://github.com/RonildoBraga/lauder/pull/158#issuecomment-7176893712) gives Apple's confirmation.

Asked **“How do the weapons and controls feel on your phone?”**, the maintainer answered **“Feels right”**. That is the maintainer's judgement of the weapons and controls as played. No frame-pacing capture was taken, and the question did not cover the guard fight's balance or how the pawns read at their size.

All four pull requests then merged into `main` on 26 November 2026, in order: [#155](https://github.com/RonildoBraga/lauder/pull/155) as `c757cad`, [#156](https://github.com/RonildoBraga/lauder/pull/156) as `a8e7dc9`, [#157](https://github.com/RonildoBraga/lauder/pull/157) as `52fa921` and [#158](https://github.com/RonildoBraga/lauder/pull/158) as `135c2a4`. `main`'s app sources are those of `0a50613`; only the five documents that record the playtest differ. Main's check [passed](https://github.com/RonildoBraga/lauder/actions/runs/45720003568) on `135c2a4`.

### Historical architecture checks

Integrated source `7158f29a44738cfd0188292ef3839d0338bd7c73` has the exact tree of reviewed source `c01dd03f6532063c959f2da9fcd663b3f9d393f3`. On `c01dd03`, `./scripts/check` passed formatting, the shared app build and hosted Swift suite, including all eight retained headless routes and six new camera/progression regression tests, plus **13 declaration-contract tests**, **28 offline release-contract tests**, **51 Blender tests** and **seven generated sounds**. [GitHub Actions run 45002053969](https://github.com/RonildoBraga/lauder/actions/runs/45002053969) passed on that reviewed source. Source review completed with no outstanding findings.

At that historical source, the retained headless routes were `bridge-walk`, `first-fight`, `fight-retry`, `ambush`, `laura`, `opening`, `formations` and `orders`. The current merged baseline instead has eight: `bridge-walk`, `first-fight`, `fight-retry`, `opening`, `formations`, `orders`, `lock-on` and `weapons`. The strategic branch updates these existing routes for the dismantling fight; use `./apple/scripts/playtest --list` for the checked-out source.

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
- Listen on the phone to each weapon's sound, the minigun's spin-up and the dome's sounds, and feel their vibrations ([weapon sounds](#weapon-sounds--in-development)).
- Ask what is enjoyable and what should change before adding another scene or complex mechanic. TestFlight availability supplies no answer to that question.

### Historical delivery

Build **0.1.0 (27)** delivered the bridge-only reset ([PR #122](https://github.com/RonildoBraga/lauder/pull/122), [delivery record in PR #123](https://github.com/RonildoBraga/lauder/pull/123)) from app/archive source `de4d0db566a546217f3c3ca095cdf1b3944a21e3`, matching the exact tree of checked/reviewed `feabb43f10f3708bc6fef4f940f26c2d8b7b462d`. The standard check passed **255 Swift tests**, **51 Blender tests** and **seven generated sounds**; the signed archive passed bundle/team/signature/dSYM verification. At **2026-11-22 07:14:36 UTC**, Apple confirmed upload **COMPLETE** with **zero errors**, processing **VALID**, **IN_BETA_TESTING**, **INTERNAL_ONLY**, an unexpired build and existing internal tester availability with membership unchanged. Earlier recording details and review history remain in the original PRs and Git history; private archives, symbols and full processing evidence are preserved.

Build **0.1.0 (26)**, source `25195e8`, was verified as processed and available before the reset. It contains the removed scenes; [ADR 0016](decisions/0016-combat-balance-and-readability.md) and Git history preserve its historical decisions and delivery evidence. Private archives, symbols and full processing evidence remain preserved.

## Combat balance and readability

The build 26 tuning and measurements in [ADR 0016](decisions/0016-combat-balance-and-readability.md) are historical. Native weapon handling, shot effects, ballistics and companion yielding still serve the bridge. The arena, extra weapons, tactical enemies and preparation displays are retired; their old measurements do not assign a new implementation pass.

## Combat design review gate

The preceding C first-tower prototype is implemented in the merged baseline, with its recorded source/Simulator checks. Build 34 delivered explicit companion commands, and the maintainer confirmed the basic commands work. Build 35 delivered bounded retaliation, and build 36 added bridge cover/spacing, useful ordinary damage, optional weak-point rewards and visible damage feedback. The latest [build 37 preview](#build-37-testflight-preview) retains those changes and adds reviewed touch/squad corrections and distinct weapon, minigun-spin and dome sounds. The next gate is a phone comparison: do touch targeting and drawn orders work naturally, ordinary hits feel useful, weakness opportunities reward positioning/switching, numbers and sound cues stay clear, and Defend recalls companions around cover without unwanted fire? Source tests, Simulator success and TestFlight availability do not settle physical acceptance, balance, enjoyment or phone performance. New scenes, A's variant and further releases remain separate work.

The broader squad combat direction, [The Quiet Yard](encounters/the-quiet-yard.md) and later narrative plans remain reference rather than assignments. The removed S4 experiments stay retired.

## Outside the first playable

Additional playable scenes, general tactical combat AI beyond the assigned guard and its bounded companion revision, signature abilities, salvage-repair machinery, extra equipment, elevation, skill trees, health/hunger systems, multiplayer, crafting, branching dialogue, finished art, persistence, cloud services and App Store submission. The strategic guard does not assign those systems.

## Later hardening

Before persistence, define a versioned snapshot of session progress, inventory, stable member IDs and a safe group spawn. Keep entity graphs, routes and transient animation out of it. Use ordered atomic writes and explicit error handling; preserve an unreadable save until the player chooses Restart. Sustained physical-phone thermal and memory checks follow a loop worth keeping.
