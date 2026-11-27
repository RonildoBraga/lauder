# Guard retaliation

**Date:** 27 November 2026\
**Status:** The earlier internal [TestFlight 0.1.0 (35)](prototype-plan.md#build-35-testflight-preview), source `8a9908a` with app code matching reviewed `251ee09`, records the original retaliation comparison below. That stack subsequently merged into main and its targeting is retained in [build 40](prototype-plan.md#build-40-testflight-preview). The [leg-break stagger](robot-eye-legs-grenades.md#leg-break-stagger-follow-up), under closed [issue #199](https://github.com/RonildoBraga/lauder/issues/199), merged in [PR #202](https://github.com/RonildoBraga/lauder/pull/202) as `9b5ec53` and is delivered in build 40 after source/Simulator and release verification. Build 39’s basic phone success does not establish this revision’s behaviour or measured performance.

The [review follow-up](prototype-plan.md#claude-review-follow-ups--in-development) corrects the out-of-range tracking stall; its new source checks are separate from those delivered preview results.

## Direction and comparison

The following direction and comparison preserve the original retaliation assignment; later damage/locomotion changes and issue #199 keep their own source records.

After build 34 the maintainer reported **“The Attack and Defend controls are working”**, then said **“proceed”** to a bounded retaliation proposal. [Issue #171](https://github.com/RonildoBraga/lauder/issues/171) records this relayed chat direction. The report confirms the basic commands, not every physical input path or sustained performance. That implementation assignment did not authorise a merge, release or cover/level changes. After reviewing the Simulator preview, the maintainer separately replied **“proceed”** to publishing the reviewed version for a short TestFlight comparison. [PR #173](https://github.com/RonildoBraga/lauder/pull/173) records the resulting internal preview. On 27 November the maintainer separately assigned [cover and companion spacing](bridge-cover-spacing.md); that pass keeps this guard's damage, patterns, timings and weakpoint sequence unchanged, with merge still unassigned.

The question is whether the existing guard responding to attacking companions gives Attack and Defend useful consequences. Keep the current damage, three-round precision/five-round fan patterns, warning/recovery timings and [dismantling rules](strategic-guard.md#earlier-mandatory-prototype). Compare this change before tuning cover placement or expanding the encounter.

## One target for one warned cycle

- **Select between cycles:** only patrol/search may choose a new member. Once engaged, prefer the freshest actual native attacker who is visible through real line of sight and within the existing **12 m attack range**; otherwise retain the leader as the acquisition candidate. Attack intentions, a stance command and changing leader are not attack evidence. The initial attack-memory tuning is **8 seconds of simulation time**.
- **Keep the quiet approach:** before engagement the original leader-only sight cone applies. Exposing a companion or ordering Attack cannot wake the guard on its own or close the west bypass.
- **Acknowledge a flank fairly:** after engagement a visible recent attacker may be noticed outside that cone. The body must still turn at its finite rate, complete notice/tracking and align within **5°** before committing. This is not an immediate sideways shot.
- **Freeze identity:** the selected member stays fixed through notice, tracking, commitment, burst and recovery, including a leader switch. Before commitment the guard follows that member's actual visible position; losing sight returns it to searching rather than substituting someone else during the warning. If a still-visible target moves beyond attack range, the existing tracking warning completes before returning to searching for a fresh acquisition. Quiet detection and fixed-target sight still reach **14 m**.
- **Freeze the shot point:** after commitment, the existing aim point remains fixed for the burst. Movement and switching do not make committed fire home in. Real barrel geometry, cover, spread, dodge and the existing one-injury-per-burst rule still decide the result.

The new [leg-break stagger](robot-eye-legs-grenades.md#leg-break-stagger-follow-up) is an explicit interruption exception: an actual newly detached nonlethal leg cancels unresolved rounds and requires a fresh complete warning, while preserving the interrupted volley’s full recovery or an existing recovery’s remainder. Stagger time consumes that recovery; its completion retains the usual pattern change and bounded reposition. Already resolved injuries remain real. Ordinary hits, a leader switch and Defend still cannot cancel a warned burst. Final local source and rendered checks pass for this exception on `4e114bb`, as tracked in the [verification record](prototype-plan.md#leg-break-stagger--in-development) under [issue #199](https://github.com/RonildoBraga/lauder/issues/199); it is delivered in [build 40](prototype-plan.md#build-40-testflight-preview) and is not part of build 39.

The initial memory length and alignment threshold are prototype values, not settled balance. This remains a small guard-specific value, not a shared threat/aggro framework.

## Warning and player authority

On entering notice, show the target's name and a threat triangle beside that party member, with a compact named chip when the status panel is hidden. Play one short two-note acquisition cue through the existing spatial sound path. The event occurs once per notice entry, not each frame; it adds no haptic or new command. Body/gun direction continues to show the physical target without a red aim line. Targeted or already injured companions expose their existing injury pips too.

The player always owns the leader. [Attack/Defend](companion-autonomy.md#attack-and-defend), Hold/Go, temporary Formation/Follow regroup and retreat keep their existing authority. Defend stops companion attacks and recalls them via useful nearby cover; it does not erase the guard's recent attack memory or cancel an already warned burst. A quiet bypass still needs no attack.

Pause and source-release gates freeze simulation and suppress pending guard warnings; inactivity suspends feedback. A sound already playing may finish on Pause, retaining the existing audio behaviour. Retry, Restart, defeat and bypass discard stale guard warnings along with their transient targeting. No immunity, damage rebalance, automatic shield or geometry change is assigned.

## Verification gate

Check actual attack evidence, memory expiry, visibility/range, quiet acquisition, flank turning and complete warnings; selected identity through leader switches and recovery; fixed committed-point geometry; one warning event per notice entry; cease-fire/recall, bypass and lifecycle/reset behaviour. Exercise ordinary inputs in both headless and rendered Simulator encounters, recording party injuries/retries and whether a short fight leaves enough retaliation to judge.

The [prototype plan](prototype-plan.md#guard-retaliation--in-development) records the completed source checks and three rendered routes, including actual injuries, zero retries and the fixed Laura-targeted fan cycle. A rendered warning and generated waveform do not establish audibility, phone readability, physical controls or sustained phone performance. Merge and TestFlight delivery retain their own authorisation and verification gates.
