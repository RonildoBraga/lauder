# Companion autonomy at the first tower

**Date:** 26 November 2026\
**Status:** Implemented on `codex/companion-autonomy`, with source and rendered Simulator results recorded in the [prototype plan](prototype-plan.md#companion-autonomy--in-development). Review, phone acceptance and delivery remain outstanding. [TestFlight build 33](prototype-plan.md#build-33-testflight-preview) remains the delivered manual-control baseline.

## Maintainer direction

After playing build 33, the maintainer reported **“It worked nice”**, then asked for companions to act independently. The explicit follow-up choice was **“Companions can complete the weakpoint steps too”**. These are maintainer decisions relayed from chat, which has no public permalink. The first comment is generic phone feedback; it does not establish individual control acceptance, sustained performance or permission to merge.

The player always controls the leader. The other two may move and fight within this encounter, including completing their own native contributions to the [strategic guard](strategic-guard.md). All three characters still contribute, but the player need not switch leader for every step. Existing L1 / LB, Q and touch Next remain available for taking direct control.

## Bounded behaviour

| Companion | Native contribution |
|---|---|
| Miki | Use the long rifle against the exposed front sensor |
| Laura | Reach an external side angle and strike the coupling with the energy sword |
| Tom | Use the minigun against the exposed core, across repeated windows when needed |

The ordinary role, weapon, exposure and physical-contact rules apply whichever character is leading. A companion's hit is not a scripted damage shortcut. Weapon draw, turning, magazine/reload, cadence, minigun spin-up, spread, armour and cover remain real. Broken parts and accepted core damage retain the existing persistence/reset rules. The exact sequence, exposure time and hit count remain prototype balance choices.

- **Engagement:** begin autonomous combat only after the guard has noticed the party or the player attacks it. An unaware guard, quiet approach or west-arch bypass must not be turned into a fight by a companion.
- **Positions:** seek nearby legal places with useful sight or tower cover, avoid committed fire when possible, and stay within an initial **8 m leader leash**. Routes respect stone, the living hull and other party members. No teleportation or damage immunity supplies a successful move.
- **Order priority:** Hold keeps its anchor; Go keeps its destination and movement priority. A companion may not abandon those orders to obtain a firing angle or a coupling strike. If the ordered position cannot support the action, that action waits.
- **Regrouping:** the existing Formation/Follow press clears tactical intentions and grants a temporary regroup interval: at least 2 seconds and until followers return near the leader. It retains its existing order-clearing/formation-cycle behaviour and label semantics; no new Recall button or permanent passive mode is added. The leader withdrawing also suppresses autonomous attacks and brings uncommanded companions back. Explicit Hold/Go movement orders remain authoritative until cleared.
- **Ownership:** switching immediately returns the new leader to player authority; the old leader may resume bounded companion behaviour. Autonomous decisions never drive the player's current leader or replay an action after a control transition.
- **Lifecycle:** Pause, dialogue, inactivity and release gates retain their authority. Retry and Restart reset transient combat intentions alongside the encounter.
- **Defence:** use legal movement and cover. This task does not add automatic shield activation, signature abilities, healing, invulnerability or a general tactical AI framework. Tom's player-controlled dome retains its existing switch/drop rule.

The aim is visible cooperation using the existing scene, weapons and simple signals. Exploration remains the main direction, and no new enemy, playable scene or art production is required.

## Verification gate

Before reporting the new behaviour as working, verify actual companion contacts and all three role contributions; awareness/attack activation; a quiet bypass; legal side access and cover; leash and temporary regroup/retreat; Hold/Go precedence; player authority after switching; native firing limits; Pause/interruption and retry/Restart. Include a rendered Simulator encounter with the player staying on one leader while the other characters complete their steps.

Record the tested source and actual results in the prototype plan and PR. Simulator results will not by themselves establish phone controls, multi-touch, readability, sustained frame pacing or enjoyment. Merge and TestFlight delivery keep their own authorisation and verification gates.

The rendered `companions` route passed with Miki remaining the player-controlled leader: she supplied the sensor shot, then Laura breached the coupling and Tom supplied all 12 accepted core rounds. No further player Fire or leader switch supplied those two steps. Its capture showed the native sword approach, minigun fire, the guard going down and Restart resetting the encounter. The `first-fight` and `weapons` routes also passed. A world test passed the alternative in which Miki and Laura prepare the core while Tom remains under player control without firing. The final full source check passed; measurements and physical-test limitations remain in the prototype plan.
