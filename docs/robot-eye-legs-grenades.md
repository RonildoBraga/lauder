# Bridge robot: eye, legs and grenades

**Date:** 27 November 2026  
**Status:** The eye/leg/grenade implementation under [issue #192](https://github.com/RonildoBraga/lauder/issues/192) is delivered in [build 38](prototype-plan.md#build-38-testflight-preview), archive source `d08ae6f`; PRs #193/#195 are merged into `main`. The maintainer reported basic phone success. The current [locomotion follow-up](#leg-loss-locomotion-follow-up), under [issue #196](https://github.com/RonildoBraga/lauder/issues/196), uses gameplay code `b6e0b83`, equivalent to full-check source `3c0cb6b`, with rendered Simulator comparisons on preceding `aa9d0f5` as detailed in the plan; it merged in [PR #197](https://github.com/RonildoBraga/lauder/pull/197) as `2b35510`, closing issue #196. [Build 39](prototype-plan.md#build-39-testflight-preview) now delivers it from frozen main/archive source `2b35510`, with Apple processing and existing-tester access verified. The [prototype plan](prototype-plan.md#leg-loss-locomotion--in-development) separates current verification from the earlier `303617b` results.

**Current delivered revision:** Closed [issue #199](https://github.com/RonildoBraga/lauder/issues/199) adds the [leg-break stagger](#leg-break-stagger-follow-up), accepted after basic build 39 phone success. Original source and rendered checks pass on `4e114bb`. It merged in [PR #202](https://github.com/RonildoBraga/lauder/pull/202) as `9b5ec53`; [build 40](prototype-plan.md#build-40-testflight-preview) is verified as available to the existing testers after fresh archive-bound checks, signed artifact audits and exact notes readback. Build 39 remains the earlier comparison; physical acceptance of the stagger is unverified.

After testing build 37, the maintainer requested that hitting the eye be a critical hit and that repeated Laura sword strikes on one leg make it fall off and slow the robot. They also requested grenade throwing and selected **“Tom only; manual throws”** in the task clarification (chat; no public permalink). This authorises the bounded mechanic revision, not new characters, scenes, biographies, enemy families or a general ability system. Numeric values below are prototype tuning choices, not additional quoted maintainer decisions.

## Eye and ordinary damage

The guard retains **1,500 shared health**. Every actual damaging contact remains useful. The visible front eye is a persistent critical target: any firearm that actually strikes it receives **×3** damage, without a weapon match, disabled-sensor state or recovery window. Normal hits remain white; eye hits are red with the existing extra symbol and restrained impact glint. The [damage contract](damage-feedback.md) owns weapon damage, positive range reduction, applied amounts and bounded feedback.

The runtime colours the existing square eye red. Its centre is measured from the existing export, rather than placing a floating target ahead of the face. The broad cylindrical body proxy otherwise swallows this recessed eye. A ray from within **60°** of the guard's facing, measured from the eye, may therefore refine a hit on that same body's coarse proxy into an eye-volume contact. From further round, where the recessed eye can't be seen, the body takes the hit; the maintainer chose that angle on [#200](https://github.com/RonildoBraga/lauder/issues/200) (chat, 28 November 2026; no public permalink). The refined trace still includes scenery and other enemies, and, for companion fire, allies. A rear-hull shot cannot become an eye critical through the body. Interior-volume rejection remains in force. This is a small analytical collision approximation, not per-triangle mesh collision.

Assistance and lock aim ranged weapons at the eye; spread, facing, range and physical occlusion still determine the result. Locking an enemy alone does not award a critical. A critical does not permanently remove the eye or prevent another critical later. The previous sensor → coupling → timed core sequence is removed from this source, while its historical preview records remain intact.

## Four independent legs

The existing C robot already contains **four reusable leg assemblies**. Each intact leg has its own count of accepted sword contacts. **Three** actual sword strikes on that same leg detach it. Hits on another leg do not advance its counter; bullets and explosions cannot count as sword strikes. Each swing causes at most one health change per enemy and normal sword damage still applies. The leader's sword selects the nearest reachable intact leg inside its real arc; cover and reach remain authoritative.

Each missing leg reduces translation by **25%**: 75%, 50%, 25%, then no translation after four losses. Build 38 retains healthy turn speed and step timing; the [locomotion follow-up](#leg-loss-locomotion-follow-up) below adds progressive turn and gait impairment. Warned attacks and the ordinary burst/recovery cycle remain available. With all four gone, a measured shared body drop settles the hull onto the ground; native eye/muzzle positions and presentation use that same drop. This is a bounded prototype, not a simulated balance or falling-body system.

A damaged leg gains a small warm indicator, stronger after its second contact. On the third, the full existing connector/leg assembly drops and tumbles into a noncolliding prop. Removed legs no longer offer target volumes or take turns in the gait. At most four props exist; Retry/Restart removes them and restores all four legs, health and counters. Navigation clearance remains conservative rather than shrinking around the missing limb.

Under an explicit **Attack** order, Miki and Tom prefer real eye opportunities and Laura prefers reachable intact legs with her sword; safe ordinary fire remains available. Defend still stops companion attacks and recalls them. Go/Hold, player leadership, native handling, ally rays, spacing and the quiet bypass retain their existing authority. A companion cannot throw a grenade.

### Leg-loss locomotion follow-up

After the build 38 phone comparison, the maintainer requested compromised walking and spinning when a leg is lost. [Issue #196](https://github.com/RonildoBraga/lauder/issues/196) adds the following starting tuning; these numbers are implementation choices, not extra quoted maintainer decisions:

| Missing legs | Travel speed limit | Body turn limit | Remaining-leg swing time |
|---|---:|---:|---:|
| 0 | 100% | 0.80 rad/s (100%) | 0.12 s |
| 1 | 75% | 0.52 rad/s (65%) | 0.16 s |
| 2 | 50% | 0.32 rad/s (40%) | 0.24 s |
| 3 | 25% | 0.16 rad/s (20%) | 0.48 s |
| 4 | None | 0.08 rad/s (10%) | No legs to step |

The physical turn cap applies during patrol, searching, repositioning and target tracking. It cannot be bypassed by switching a target or seeking a movement goal. A grounded guard keeps only a very slow emergency pivot, so a flank target does not silently deadlock its existing warning/attack cycle. The committed point, gun yaw limits, real cover and actual muzzle rays keep their existing authority; a committed burst does not home in on a moving target.

The remaining feet retain the existing world-space planting and two-link IK. Slower swing timing prevents the queue from becoming quicker merely because missing feet are skipped. There is no presentation-only body tilt, new mesh, physics simulation or navigation-radius change. Pause freezes the motion; Retry/Restart restore the healthy rules and all legs. Build 39 delivers this follow-up; its source and rendered verification are [tracked separately](prototype-plan.md#leg-loss-locomotion--in-development) from the earlier build 38 results.

### Leg-break stagger follow-up

The maintainer accepted a short tactical opening on a leg break, with a distinct mechanical sound/body reaction and a fresh warning before further fire. [Issue #199](https://github.com/RonildoBraga/lauder/issues/199) owns this implementation. The initial **0.6 s** duration and maximum **0.08 m** body dip are prototype tuning, not a new story foundation or settled balance.

Only an actual newly detached leg on a still-living guard starts the stagger. Ground movement and body turning stop during the opening. It cancels remaining unresolved robot rounds; already resolved shots and injuries remain real. Ordinary hits, eye criticals and repeated contacts on a detached leg cannot retrigger it. Another distinct leg break during the opening restarts its finite duration, bounded by the four available legs. Lethal damage follows defeat instead of starting a new stagger.

An interrupted burst still owes its full upcoming recovery; a break during recovery owes only that cycle’s unexpired remainder. Time spent staggered consumes the owed time. Another distinct leg break restarts the stagger without replenishing or discarding the remaining recovery. At the end of the stagger, any positive remainder resumes; if that interrupted recovery has already elapsed, the normal completion path advances the attack pattern and chooses the usual bounded reposition. A break before a volley has no recovery cycle to complete.

Before further fire, the guard must reacquire through a complete notice/tracking/commitment warning. An interrupted warning or burst cannot bank a nearly ready shot, and cancelling the last pending rounds cannot skip their recovery. The committed point of a subsequent burst remains fixed; normal target selection, real sight/range, body-turn limits, cover and the one-injury-per-burst rule keep their owners.

The body reaction uses the same native `bodyDrop` as hull, eye, muzzle, sight and presentation, capped at the settled belly height. The guard looks out from its guns' height, so a grounded guard sees from 0.745 m and can lose a target behind low cover; the maintainer chose to let its sight drop on [#226](https://github.com/RonildoBraga/lauder/issues/226) (chat, 28 November 2026; no public permalink). It adds no presentation-only tilt or pose that moves the visible target away from the physical one. One original generated mechanical break cue follows each accepted new nonlethal break through the existing feedback path. Existing rigid model components are reused; no mesh rewrite, new input, physics solver or dependency is assigned.

Pause and interruption freeze simulation progress and must not replay stale cues. Defeat cancels the opening and pending rounds while preserving the current shared body drop, so the dying robot does not jump up as the pulse ends. The quiet bypass cancels the opening and pending rounds; Retry/Restart restore healthy state and clear the reaction. The generated sound may finish while paused under the existing audio rule. Final local source and rendered checks pass on `4e114bb` in the [verification record](prototype-plan.md#leg-break-stagger--in-development). The pre-existing all-leg wreck settling limitation remains tracked in issue #200; this stagger is not in build 39. The later [build 40 request and delivery](prototype-plan.md#build-40-testflight-preview) records its authorised merge in PR #202 and verified availability to existing TestFlight testers; physical acceptance remains unverified.

## Tom's manual grenade

While **Tom leads**, press **Circle/B**, keyboard **C**, or touch **Grenade** once. G/H remain squad Go/Hold. The touch button is absent for other leaders and during dialogue/Pause, retaining any already captured contact until its finger lifts. Grenade input passes through the shared release/priority rules. A held button cannot repeat or queue a throw. The other character's request is ignored by gameplay authority.

Only an eligible throw takes priority over simultaneous Fire and Action. A refused request leaves otherwise valid inputs intact, including Tom's minigun spin and raised dome. Recharge, an active grenade, another leader, a roll or a scripted hold cannot bank a rejected request for later. The simulation supplies shared eligibility and rechecks it at launch; the world retains the existing roll and fixed-step input gates.

A throw uses the current locked enemy position, a visible assisted target, or the manual aim/facing direction. It commits that point at launch and caps horizontal range at **10 m**. The simple arc lasts **0.75 s**, stops on actual solid scenery and explodes after a **0.6 s** landing fuse. There is no bounce, cooking, held targeting mode or homing. Geometry segments and fuse timing belong to the fixed-step simulation; RealityKit only draws the projectile and a brief blast footprint.

The **3 m** blast causes **180** damage at its centre, falling linearly to **60** at its edge. Actual solid cover blocks blast visibility; one explosion applies ordinary damage once per enemy, with no eye multiplier or several leg contacts. Splash has no paired-weapon attribution and cannot be grouped with a gun's rapid hits. Friendly fire is omitted from this first prototype. The blast reuses one existing impact sound rather than adding an unreviewed audio package.

Tom's grenade recharges over **8 s** of active simulation. Switching leaders cannot refill it or transfer a pending throw, and companions never spend it. The touch label and controller/keyboard hint show the rounded-up recharge. Scripted party holds reject new throws. Pause freezes flight, fuse and recharge; interruption release gates prevent stale throw requests on return. Retry/Restart clears the projectile, blast and recharge. Taking the quiet exit cancels an unfinished projectile so it cannot damage a cleared encounter.

This first version has no ammunition inventory, new weapon slot, dependency, general projectile framework or automatic grenade AI. The build 38 report establishes basic phone success, not exhaustive controls or combat balance. The locomotion’s source and Simulator checks pass, and build 39 is available for its phone comparison. Physical acceptance remains unverified.
