# Project history

**Updated:** 18 November 2026

How Lauder reached the Brooklyn Bridge opening: what each finished stage built, what was checked on the phone, and what remains open. The [README](../README.md) and the [prototype plan](prototype-plan.md) own the current status, and the [opening record](opening.md) covers the bridge's milestones.

This page replaces the detailed records of each stage. They are kept in Git history; the last version of all of them is in [docs at `a6b23a9`](https://github.com/RonildoBraga/lauder/tree/a6b23a9/docs), and the full code of the Relay House level is in that commit too.

## Stage 1 — device and asset workflow

**16 November 2026.** Merged in [PR #8](https://github.com/RonildoBraga/lauder/pull/8).

- The exit criterion: a small scene and one rigged character with idle and walk animation running on the baseline iPhone, to prove the import, composition and app workflow before producing content ([ADR 0001](decisions/0001-engine.md)).
- The maintainer [confirmed the code-first workflow](https://github.com/RonildoBraga/lauder/issues/9#issuecomment-6907224023): Swift scene construction and direct USDZ loading.
- A signed build ran on the iPhone 13 Pro Max (iOS 27.2.1), built with Xcode 27.2 / SDK 27.2, and the maintainer confirmed that Idle and Walk both work. The animated stand-in, its sources and its provenance are preserved for later characters.
- The project uses Xcode's folder-synchronised groups for `sources/` and `tests/` ([issue #10](https://github.com/RonildoBraga/lauder/issues/10)), so new Swift files need no project-file edits.

## Stage 2 — movement and controls

**16–17 November 2026.**

- Movement, collision, camera follow and observation prompts; the shared PS5 DualSense and Xbox extended-gamepad input; Simulator keyboard play with WASD, E and Escape; and a screen that stays awake while the game is active. The maintainer adopted the Simulator for everyday testing, with the baseline iPhone at milestones.
- On the PS5 revisions of that stage, the maintainer confirmed on the phone: movement and stopping on release, Cross, Options Pause/Resume, camera follow, wall collision, the screen staying awake, disconnect and reconnect, and background and lock recovery.
- A first visual pass followed the [visual direction](visual-direction.md), with Death's Door as the reference.
- The maintainer later authorised [touch controls](touch-controls.md), superseding the earlier controller-only rule.

**Still open from Stage 2:**

- **PR #11's phone check.** After PR #11 the maintainer explicitly deferred the refreshed phone check: “I dont want to do tests on the phone so often so we can disregard that for now”. That is a deferral, not a passed device check, and the prepared-work integration retains the gap. Later phone checks cover only their own builds.
- **Controller input in the Simulator.** Live game-controller input never reached the game in the tested Simulator setup; the controller enumerating there does not show that its input is delivered. Keyboard play is the Simulator path.
- **Xbox hardware.** The maintainer deferred testing with an Xbox controller; its delivery is unverified.
- Normal Auto-Lock timing after leaving the app, walking-cadence calibration ([#14](https://github.com/RonildoBraga/lauder/issues/14)) and the consolidated phone checks in [#18](https://github.com/RonildoBraga/lauder/issues/18) remain open.

## Party A — three characters

**17 November 2026.** Merged in [PR #24](https://github.com/RonildoBraga/lauder/pull/24).

- Three primitive stand-ins, session-owned leadership and Pause, switching with R1, RB or Q, companions following, and an eased camera on switching, in the Relay House level.
- **Phone checkpoint.** On a Release build of `fc53d52`, the maintainer confirmed PS5 movement and release, switching and following, camera and HUD, Pause/Resume, paused input being ignored, disconnect and reconnect, background and lock recovery, and the full round trip during a timed recording. The sample averaged **59.98 fps** over 59 seconds, with a longest interval of 33.3 ms; the thermal state went from Nominal to Fair. It was a short sample, which shows neither hitch-free nor sustained performance. The maintainer deferred the remaining manual tests.
- **Wall contact ([#25](https://github.com/RonildoBraga/lauder/issues/25)).** Bodies froze against walls because movement used engine shape queries. Movement now resolves against the level's authored footprints in plain Swift, revising [ADR 0002](decisions/0002-party-following.md).
- **Follower spacing ([#28](https://github.com/RonildoBraga/lauder/issues/28)).** Followers lost distance when frame times varied. Movement now advances in fixed 1/120 s steps.

## Squad movement, phase S1

**17–18 November 2026.**

- The maintainer accepted [ADR 0003](decisions/0003-squad-movement.md) and assigned its first phase: **“Accept, S1 first”**. Companions keep a Close formation, choose their own routes around scenery and fall into single file in narrow places, replacing the recorded trails.
- After playing it on the baseline iPhone, the maintainer reported “it looks good”. Which inputs and situations were tried was not recorded, and S1's phone timing was not measured.

## Parties B and C — the Relay House loop

**18 November 2026.** Merged in [PR #36](https://github.com/RonildoBraga/lauder/pull/36) and [PR #37](https://github.com/RonildoBraga/lauder/pull/37), without an independent review.

- **Party B:** a closed barrier in Relay House's service passage, opened either by Laura reaching a latch or by Tom shifting a loose panel, with Miki explaining both.
- **Party C:** the keeper's briefing, Miki's regulator, the repair, a call that agreed the Old Lock meeting, **Read plan**, and an in-place Restart chosen from a two-choice pause menu. The pause menu and Restart remain in the game.
- **Phone checkpoint.** On a Release build of `4cd58ab`, after playing the loop, the maintainer reported: **“everything worked as expected”**. A two-minute sample averaged **59.96 fps** over 104 seconds, with a longest interval of 50.0 ms and three longer frames whose cause is unknown; the thermal state stayed Nominal. It shows neither hitch-free nor sustained performance.
- By the maintainer's decision the dialogue stayed provisional, to be settled with the relationships.

## Simulator note

On 17 November the original iPhone 17 Simulator kept crashing in Apple's PosterBoard during startup, before Lauder launched, apparently from damaged wallpaper state. A newly created Simulator device fixed it. If it recurs, make a new device rather than looking for the cause in Lauder.

## The opening moves to the bridge

**18 November 2026.**

- The maintainer accepted [ADR 0004](decisions/0004-brooklyn-bridge-opening.md): the game opens with Miki alone on a greybox Brooklyn Bridge, and Relay House became a second level. The [opening record](opening.md) follows M1 to M3.
- The maintainer chose Blender as the level editor ([ADR 0005](decisions/0005-blender-level-editor.md)), then moved the bridge's decoration and game camera into the layout file too.
- **Relay House removed.** Asked whether to keep it, the maintainer answered **“Remove it”**. The level, Parties B and C's mechanics and lines, their tests and playtests, and its walkthrough are gone. The story bible keeps Relay House as a later scene. The squad-movement tests keep their coverage in a test-only yard with the old level's walls, because the bridge has no doorway narrow enough.
