# Crawler pack at the first tower

**Date:** 27 November 2026  
**Status:** Built under [issue #208](https://github.com/RonildoBraga/lauder/issues/208), on top of the [scout drones](scout-drones.md). TestFlight build 44 delivered it, and the maintainer answered “Feels right” after playing it. The [prototype plan](prototype-plan.md#crawler-pack--in-development) records what has been checked.

## The request

The maintainer asked: **“Once it's merged, create another new enemy but check the git issues and comments to coordinate things with Codex”**, then **“start building the crawlers now”** (chat, 27 November 2026; no public permalink).

Asked which enemy and where it fights, they chose:
- **“Crawler pack”**, from the option “three or four small ground machines that rush the party and ram it after a short visible wind-up”.
- **“With the first guard”**, from the option “it joins the guard and drones at the first tower”.

The guard fight is still the bridge's only fight. The numbers below are my starting choices for a playtest, not further quoted decisions.

## How they fight

**Waiting.** Three crawlers wait folded behind and beside the guard. They're visible when the party enters the fight area and can be shot while folded.

**Fight start.** They get up only once the guard's fight is engaged: when the guard notices the party, or when a crawler or the guard is hit. They get up one after another, half a second apart. Walking into the area alone starts nothing, so the quiet west bypass still works.

**Approach.** A crawler goes for the member it senses nearest, preferring one no other crawler is ramming.
- **Sensing:** it senses over the low cover, so only the tower's stone hides a member from it.
- **Moving:** it walks at **3 m/s**, a little faster than the party, so the pack has to be fought.
- **Getting round things:** it slides round blockers and turns aside to get round a pier, keeping to one side. It never walks through the guard.
- **Leash:** it turns back home if its member is more than 16 m from its place.

**Ram.** At **2.5 m** it attacks in these steps:
1. It **winds up for 0.6 s**: it crouches and its sensor glows. The HUD names its target, and the guard's warning sound plays when the target is the leader. The HUD shows this warning over the guard's own status, such as its recovery, which is when crawlers attack. Only the guard's warned attack still comes first.
2. Its ram line is **fixed when the wind-up starts**, so the whole wind-up is the moment to step aside or roll. Its named target stays with that line through the wind-up and ram, even when they leave and return to sight. After the ram it can choose another member, with a new full wind-up before ramming them.
3. It rams **3 m** along that line at 9 m/s and stops at the first blocker in its way rather than sliding along it. A ram hurts at most one member, once: the first one ahead that its body runs into. Anyone beside or behind it as it sets off is left behind unhurt. Tom's raised dome shelters anyone inside it from a ram that set off outside, judged by where the ram began.
4. It then recovers, stopped and exposed, for **1.2 s**, and waits until 2.5 s have passed since its ram ended before the next wind-up; that interval includes recovery.

**One attack at a time.** A crawler starts a wind-up only while the guard patrols, recovers or searches. It never starts one over the guard's own warning or burst, or during its leg-break stagger, the same rule as the drones'. Two crawlers never wind up on the same member at once.

**Health.** Each crawler has **45 health**, so one long-rifle or shotgun round downs one, or two sword hits, nine assault-rifle rounds or fifteen minigun rounds. Tom's grenade catches a cluster.

**Reaching them.** The aim help, holding aim and the lock lower a shot to a crawler on the snow. A shot with no help flies at body height and passes over it.

**Falling.** A downed crawler collapses where it is. When the guard goes down, its crawlers and drones go down with it, so the fight still ends with the guard. After the quiet exit, the crawlers walk back to their places and fold, harmlessly.

**Lifecycle.** Pause freezes them, and Retry and Restart reset them. Like the guard's, a wind-up's warning sound isn't heard once Pause, Restart or leaving the app has interrupted it, and the same now holds for a drone's warning.

## Companions, lock and touch

**Companions.** Under **Attack**, a companion whose plan is already engaging shoots a crawler that is winding up, ramming, recovering or within 6 m, when one of its guns has a clear line. A diving drone comes first. Movement, orders, Defend, regrouping and seeking safety keep the guard plan's own authority.

**Getting out of the way.** A companion counts as in a crawler's way when it stands near the part of a crawler's fixed line still ahead of it, while that crawler winds up or rams.
- **Stepping aside:** a companion without a Go or Hold order steps aside to the nearest clear place, in either stance, and stops firing while it moves.
- **Not crossing:** if its own place lies across a line, it waits where it is clear rather than walk through.
- **Beyond the guard's reach:** this works there too, where the guard's plan doesn't run.
- **Orders:** a Go or Hold order keeps its place, as it does under the guard's burst.

**Camera.** The camera keeps leaning towards the guard, not the crawlers.

**Lock and touch.** The lock includes the crawlers, and tapping one selects it.

## Look and sound

These are simple shapes, as [AGENTS.md](../AGENTS.md) asks.
- **Model:** the [crawler model](../blender/assets/crawler/README.md) is a low hexagonal body with a ridge on its back, four stubby legs and the guard's red sensor across its front. It is exported like the other hostile models.
- **Motion:** the game swings its legs as it walks, keeps it low and tucked while folded, crouches it through a wind-up and tips it forward into a ram.
- **Sound:** the warning reuses the guard's warning sound, only when the leader is targeted. A ram's hit reuses the body-strike sound. The crawlers have no sounds of their own yet.

## Tests and playtest routes

- **New tests:** tests of the crawler alone cover waiting, getting up in turn, the approach, the line fixed at the wind-up's start, the ram, one hit per ram, recovery, the leash, walls and the guard's body, the fall and the quiet exit. Fight tests cover waiting for the guard, winding up only between its attacks, never two on one member, injuries only from rams, a single rifle round downing one, going down with the guard, the quiet exit and the lock.
- **World tests:** these use the real input rules and plans, the follow-up to the review of the drones' PR.
  - **Rams:** a crawler aimed at a free companion doesn't ram it, in either stance.
  - **Hold:** a held companion keeps its place under a ram line.
  - **Dives:** a companion in a drone's dive avoids it, and the drone override doesn't turn it to shooting.
- **Older routes:** the guard-only routes keep the guard-only bridge. The two drone routes now play `BrooklynBridge.guardAndDrones`, a debug copy without crawlers, so they keep testing what they were written for.
- **New route:** **crawler-fight** plays the shipped fight with the whole pack, the squad on Attack. Miki and the companions down the crawlers, Miki rolling out of their rams, and the route requires that companions shot at them. Then Miki downs the drones and the squad dismantles the guard.

## Limits

- **Simplifications:** the walking is a bounded prototype: it slides and turns aside rather than following planned paths. The crawler's body is a short cylinder rather than its mesh.
- **Tom's dome:** a crawler winds up within 2.5 m of its target, and the dome reaches 2.6 m. So a crawler aimed at Tom himself always sets off inside his dome, and the dome never shelters him from it. The playtest should judge whether the dome should also stop rams that start inside it.
- **Followers on Defend:** with the whole pack the fight lasts longer. On Defend, followers stay close to the leader and take more drone dives and guard bursts, which the agreed rule for those two attacks doesn't step them out of. Before the route switched to Attack, it failed when Laura took three such hits; the phone playtest should judge it.
- **What Simulator checks can't settle:** phone readability, audibility, balance, whether the busier fight is still enjoyable, and sustained frame rate.
- **Phone check:** the baseline-iPhone check that AGENTS.md asks of playable features came from build 44: general success on the phone, not a measured check of each control, sound, balance or frame rate.
