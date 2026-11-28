# Lauder — single-hero graybox duel

**Updated:** 28 November 2026. **Tracking:** [issue #236](https://github.com/RonildoBraga/lauder/issues/236).

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
| Pause / resume | Escape | Options / Menu | Pause / Resume |
| Menu confirm / outcome Retry | E | Cross / A | Dedicated menu/Retry target |

Movement is camera-relative. Guard holds facing while the hero moves more slowly; release it to turn and regain stamina. Attack commits its direction. A fresh dodge wins simultaneous attack; guard suppresses an attack. Pause wins all combat input. A late-recovery request may buffer one next action for a short bounded handoff, not an entire combo.

Source/lifecycle changes clear captures and pending actions and require neutral input. Pause freezes actors and action timers. Captured touch controls remain mounted until every finger lifts, including centred-stick contact. Resume does not replay inputs pressed while paused. Foreground Lauder keeps the screen awake; leaving it restores normal idle locking.

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

Run:

    ./scripts/check
    ./apple/scripts/playtest duel-attack duel-defence duel-recovery

The routes drive real shared input, not injected damage or outcomes. They cover a native win, block/timed evasion, and pause/release/resume/Restart. Retained collision tests include previous wall-contact escape regressions as plain geometry fixtures.

## Next gate

A short human session should establish whether preparation is readable, block/dodge/repositioning offer distinct choices, damage feels fair and Retry invites another attempt. Physical touch/controller comfort and sustained phone performance require a separately arranged milestone.

Only after the duel works should we compare parry/charged actions, another enemy pattern and camera alternatives. Then test a short exploration route with a useful optional reward and shortcut. More art, story, inventories and a campaign do not repair an unsatisfying duel. Merge and TestFlight publication retain their own go-ahead.
