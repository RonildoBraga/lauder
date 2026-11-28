# Lauder — single-hero graybox duel

**Updated:** 28 November 2026. **Tracking:** [issue #236](https://github.com/RonildoBraga/lauder/issues/236).

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

**Implemented and locally verified:** frozen implementation source cad54500e61fcbdb805c758a6c5b970776b88de3 passes the complete ./scripts/check on 28 November 2026: formatting, iOS build and hosted Swift Testing, including all three native command routes. Portable checks include 18 declaration mutations, 54 Blender export tests, 31 offline release-contract tests, six recording-lifecycle tests and three sound fingerprints. The combat suite covers once-per-action contact, the shared blade interval, facing, resource exhaustion, buffer handoff, invulnerability and reset; its stationary attack-spam control loses while causing useful damage. Actual captured-touch Retry and sub-tick source-generation regressions pass.

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
