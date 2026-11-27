# Bridge robot: eye, legs and grenades

**Date:** 27 November 2026  
**Status:** Bounded implementation under [issue #192](https://github.com/RonildoBraga/lauder/issues/192), on `codex/robot-eye-legs-grenades`, based on the delivered [build 37 preview](prototype-plan.md#build-37-testflight-preview). New source/native and rendered verification remains pending in the [prototype plan](prototype-plan.md#eye-legs-and-grenades--in-development). This source is not yet a TestFlight delivery or a merge.

After testing build 37, the maintainer requested that hitting the eye be a critical hit and that repeated Laura sword strikes on one leg make it fall off and slow the robot. They also requested grenade throwing and selected **“Tom only; manual throws”** in the task clarification (chat; no public permalink). This authorises the bounded mechanic revision, not new characters, scenes, biographies, enemy families or a general ability system. Numeric values below are prototype tuning choices, not additional quoted maintainer decisions.

## Eye and ordinary damage

The guard retains **1,500 shared health**. Every actual damaging contact remains useful. The visible front eye is a persistent critical target: any firearm that actually strikes it receives **×3** damage, without a weapon match, disabled-sensor state or recovery window. Normal hits remain white; eye hits are red with the existing extra symbol and restrained impact glint. The [damage contract](damage-feedback.md) owns weapon damage, positive range reduction, applied amounts and bounded feedback.

The runtime colours the existing square eye red. Its centre is measured from the existing export, rather than placing a floating target ahead of the face. The broad cylindrical body proxy otherwise swallows this recessed eye. A real front-eye ray, including a clear oblique contact, may therefore refine a hit on that same body's coarse proxy into an eye-volume contact; the refined trace still includes scenery, allies and other enemies. A rear-hull shot cannot become an eye critical through the body. Interior-volume rejection remains in force. This is a small analytical collision approximation, not per-triangle mesh collision.

Assistance and lock aim ranged weapons at the eye; spread, facing, range and physical occlusion still determine the result. Locking an enemy alone does not award a critical. A critical does not permanently remove the eye or prevent another critical later. The previous sensor → coupling → timed core sequence is removed from this source, while its historical preview records remain intact.

## Four independent legs

The existing C robot already contains **four reusable leg assemblies**. Each intact leg has its own count of accepted sword contacts. **Three** actual sword strikes on that same leg detach it. Hits on another leg do not advance its counter; bullets and explosions cannot count as sword strikes. Each swing causes at most one health change per enemy and normal sword damage still applies. The leader's sword selects the nearest reachable intact leg inside its real arc; cover and reach remain authoritative.

Each missing leg reduces translation by **25%**: 75%, 50%, 25%, then no translation after four losses. Turning, warned attacks and the ordinary burst/recovery cycle remain available. With all four gone, a measured shared body drop settles the hull onto the ground; native eye/muzzle positions and presentation use that same drop. This is a bounded prototype, not a simulated balance or falling-body system.

A damaged leg gains a small warm indicator, stronger after its second contact. On the third, the full existing connector/leg assembly drops and tumbles into a noncolliding prop. Removed legs no longer offer target volumes or take turns in the gait. At most four props exist; Retry/Restart removes them and restores all four legs, health and counters. Navigation clearance remains conservative rather than shrinking around the missing limb.

Under an explicit **Attack** order, Miki and Tom prefer real eye opportunities and Laura prefers reachable intact legs with her sword; safe ordinary fire remains available. Defend still stops companion attacks and recalls them. Go/Hold, player leadership, native handling, ally rays, spacing and the quiet bypass retain their existing authority. A companion cannot throw a grenade.

## Tom's manual grenade

While **Tom leads**, press **Circle/B**, keyboard **C**, or touch **Grenade** once. G/H remain squad Go/Hold. The touch button is absent for other leaders and during dialogue/Pause, retaining any already captured contact until its finger lifts. Grenade input passes through the shared release/priority rules. A held button cannot repeat or queue a throw. The other character's request is ignored by gameplay authority.

A throw uses the current locked enemy position, a visible assisted target, or the manual aim/facing direction. It commits that point at launch and caps horizontal range at **10 m**. The simple arc lasts **0.75 s**, stops on actual solid scenery and explodes after a **0.6 s** landing fuse. There is no bounce, cooking, held targeting mode or homing. Geometry segments and fuse timing belong to the fixed-step simulation; RealityKit only draws the projectile and a brief blast footprint.

The **3 m** blast causes **180** damage at its centre, falling linearly to **60** at its edge. Actual solid cover blocks blast visibility; one explosion applies ordinary damage once per enemy, with no eye multiplier or several leg contacts. Splash has no paired-weapon attribution and cannot be grouped with a gun's rapid hits. Friendly fire is omitted from this first prototype. The blast reuses one existing impact sound rather than adding an unreviewed audio package.

Tom's grenade recharges over **8 s** of active simulation. Switching leaders cannot refill it or transfer a pending throw, and companions never spend it. The touch label and controller/keyboard hint show the rounded-up recharge. Scripted party holds reject new throws. Pause freezes flight, fuse and recharge; interruption release gates prevent stale throw requests on return. Retry/Restart clears the projectile, blast and recharge. Taking the quiet exit cancels an unfinished projectile so it cannot damage a cleared encounter.

This first version has no ammunition inventory, new weapon slot, dependency, general projectile framework or automatic grenade AI. The new input and visual footprint need physical-phone acceptance after source and Simulator checks; build 37's generic success does not establish these controls or combat balance.
