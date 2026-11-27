# Scout drones at the first tower

**Date:** 27 November 2026  
**Status:** The separate [build 41 preview](prototype-plan.md#build-41-testflight-preview) received general “Feels right” phone feedback. Claude’s [issue #207](https://github.com/RonildoBraga/lauder/issues/207) warning-target fix and Codex’s missing companion/drone coverage are integrated in `4800560`, with full source and rendered checks passed. PR #203 remains unmerged; the [combined build 43 preparation](prototype-plan.md#build-43-combined-testflight-preview) records pending final CI/review and release gates. Build 42 remains delivered without drones.

## The request

While Codex worked on the guard's leg stagger (#199), the maintainer asked: **“We should in the mentime also create a different enemy while Codex is working”** (chat, 27 November 2026; no public permalink).

Asked which enemy and where it fights, they chose:
- **“Scout drones”**, from the option “two or three small hovering machines that circle out of reach and make a warned strafing dive”.
- **“With the first guard”**, from the option “it joins the guard fight at the first tower, making that one fight busier and harder”.

The guard fight is still the bridge's only fight, as after the 26 November “Guard fight only” choice. The numbers below are my starting choices for a playtest, not further quoted decisions.

## How they fight

**Patrol.** Two drones patrol with the guard. They appear with it when the party enters the fight area and circle it at **3 m**, which is above sword reach and the bridge's low cover.

**Fight start.** They attack only once the guard's fight is engaged: when the guard notices the party, or when a drone or the guard is hit. Hitting a drone also alerts the guard. Walking into the area alone starts nothing, so the quiet west bypass still works.

**Dive.** A drone attacks in these steps:
1. It picks the nearest member it can see between **4 m** and **12 m** away. The 4 m is its shortest run-up.
2. It warns for **1 s**: it hovers, its eye glows, the guard's warning sound plays, and the HUD names its target. If the member comes closer than its run-up, it backs off.
3. It commits to where that member stood when the warning ended, then dives along that straight line at **6 m/s**.
4. It fires a burst of **three** rounds at the committed point, the first **0.35 s** after it commits. A burst hurts at most one member once, like the guard's.
5. It levels off at **1.3 m** for a low pass that carries **2.5 m** beyond the point, then climbs back.

**Warning-target correction, source-verified:** [Claude’s accepted fix](https://github.com/RonildoBraga/lauder/issues/207#issuecomment-7211731957) keeps a warning with the member it named. If that member loses sight, the drone retains their last-seen point and commits there only with a valid run-up, otherwise gives up. Another member may be selected only through a fresh full one-second warning, cue and HUD line. Companion danger during the warning follows that same last-seen point. The fix in `3e5d362` and its native sight-loss regression pass in integrated source `4800560`; earlier build 41 feedback does not verify this correction on a phone.

The dive doesn't follow its target, so a step aside in the 0.35 s before the first round, or cover, beats it. The guard's committed aim gives the same kind of moment before its burst.

**One attack at a time.** A drone starts its warning only while the guard patrols, recovers or searches. It never starts one over the guard's own warning or burst, or during any other opening the guard gives, such as a leg-break stagger. So a dive never lands on top of a guard volley it cannot answer. Codex suggested this on [#201](https://github.com/RonildoBraga/lauder/issues/201); the guard's own timing is unchanged.

**Taking turns.** The two drones never warn or dive at the same time. The first dive comes **3 s** after the fight is engaged and the second drone's **4.5 s** after that. Each drone waits **9 s** between its own dives, so with both flying a dive comes about every 4.5 s.

**Health.** Each drone has **60 health**. Two long-rifle, shotgun or sword hits bring one down, or about twelve assault-rifle rounds or twenty minigun rounds.

**Reaching them.** The aim help, holding aim and the lock raise a shot to a drone at its height. A shot with no help stays at body height, so it reaches a drone only on its low pass. The sword reaches a drone only during the low pass, at **2 m** or lower. Tom's grenade blast reaches anything within its 3 m radius, so a drone passing low over it can be caught.

**Flying.** Drones go round the tower's stone and rise over the low cover. A dive whose line crosses stone isn't started, and one blocked partway climbs away.

**Falling.** A downed drone falls to the snow, or onto any low cover beneath it, and stays as a wreck. When the guard goes down, its drones fall with it, so the fight still ends with the guard. After the quiet exit, the drones keep circling harmlessly.

**Lifecycle.** Pause freezes them, and Retry and Restart reset them.

## Companions, lock and touch

**Companions.** Under **Attack**, a companion whose plan is already engaging shoots a drone while it dives or climbs back from a dive, when the gun in its hand, or its other gun, has a clear line. It leaves circling drones to the player. Movement, orders, Defend, regrouping and seeking safety keep the guard plan's own authority. Companions cannot throw grenades.

**Getting out of the way.** A companion counts as in a drone's way within **1.3 m** of where the member a warning drone watches stands, or of the point a diving drone has committed to. Its plan then moves it somewhere safe, as it does for the guard's committed burst.

**Camera.** The camera still leans towards the guard. Drones never draw it, so it doesn't sway after them as they circle.

**Lock and touch.** The lock includes the drones. Tapping a drone or its shadow selects it, and its red ring sits on the snow beneath it.

## Look and sound

These are simple shapes, as [AGENTS.md](../AGENTS.md) asks.
- **Model:** the [scout-drone model](../blender/assets/scout-drone/README.md) is a small dark body on four arms, with two-bladed rotors and the guard's red eye. It is exported like the other hostile models.
- **Motion:** the game spins the rotors and tilts a drone into its dive. A shadow on the snow tightens as the drone comes down, which shows its height from the camera.
- **Sound:** the warning reuses the guard's warning sound, and the rounds reuse the guard's rifle sound. The drones have no sounds of their own yet.

## Tests and playtest routes

- **New tests:** tests of the drone's own flight cover circling, the warning, the commit, the burst, the low pass, walls, low cover, the fall and the quiet exit. Fight tests cover taking turns, waking the guard, rising to assisted fire, falling with the guard, the quiet exit and the lock.
- **The older tests:** the guard's own tests that the drones broke now run on `BrooklynBridge.guardOnly`, a debug copy of the bridge without the drones. Each keeps testing the guard alone, as it was written to.
- **Routes:** the fourteen earlier playtest routes play the guard alone in the same way. The new **drone-fight** route plays the shipped fight: Miki shoots both drones down through the aim help, stepping out of their dives, and then the squad dismantles the guard.

**New combined verification:** Full checks pass on `4800560`, including twenty drone tests, four new native companion/drone tests and all sixteen headless routes. The rendered `companion-drones` and `drone-fight` routes pass with actual vulnerable combat; the rendered touch route passes on the guard-only fixture. The [prototype plan](prototype-plan.md#build-43-combined-testflight-preview) records exact results and pending release gates; earlier build 41 phone feedback does not verify this combined revision.

## Limits

- **Simplifications:** the flight is a bounded prototype without physics, and the drone's body is a short cylinder rather than its mesh.
- **What Simulator checks can't settle:** phone readability, audibility, balance, whether the fight is still enjoyable, and sustained frame rate.
- **Phone check:** the maintainer's “Feels right” on build 41 is general success on the phone. Frame pacing, sound and balance are still unmeasured there.
