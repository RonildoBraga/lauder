# Companion autonomy at the first tower

**Date:** 26 November 2026\
**Status:** Implemented on `codex/companion-autonomy`, with source and rendered Simulator results recorded in the [prototype plan](prototype-plan.md#companion-autonomy--in-development). The [build 34 TestFlight preview](prototype-plan.md#build-34-testflight-preview) is delivered with explicit Attack/Defend controls; physical acceptance and merge remain separate gates. Build 33 is the earlier manual-control baseline.

## Maintainer direction

After playing build 33, the maintainer reported **“It worked nice”**, then asked for companions to act independently. The explicit follow-up choice was **“Companions can complete the weakpoint steps too”**. These are maintainer decisions relayed from chat, which has no public permalink. The first comment is generic phone feedback; it does not establish individual control acceptance, sustained performance or permission to merge.

The player always controls the leader. The other two may move and fight within this encounter, including completing their own native contributions to the [strategic guard](strategic-guard.md). All three characters still contribute, but the player need not switch leader for every step. Existing L1 / LB, Q and touch Next remain available for taking direct control.

The maintainer then clarified: **“they should only attack and complet the steps if I press to attack”** and **“if I press to defend on the d pad then they should seek cover and try to go back to me”**. This replaces automatic engagement permission with an explicit standing squad stance. The player firing or the guard noticing the party does not authorise companion attacks.

After build 34 the maintainer reported **“The Attack and Defend controls are working”**. This is basic command feedback, not every-input or sustained-performance acceptance. Their subsequent **“proceed”** authorises the [guard-retaliation comparison](guard-retaliation.md), recorded in [issue #171](https://github.com/RonildoBraga/lauder/issues/171), without changing the companion command contract. Its source and Simulator verification are recorded in the [prototype plan](prototype-plan.md#guard-retaliation--in-development); it has not been merged or delivered.

## Attack and Defend

- Start in **Defend**. D-pad/arrow **Up** orders **Attack**; **Down** orders **Defend**. Left/right still position the individual companion. Keyboard **G/H** and the touch ground menu retain Both/Hold orders.
- **Attack** permits role-aware companion attacks and weakpoint completion once the fight is engaged. It persists across leader changes until Defend is ordered; the player-controlled leader is always manual.
- **Defend** immediately revokes companion fire permission, cancels old Hold/Go orders and recalls the companions without cycling the formation. They try legal nearby cover along the return toward the leader; remote cover cannot pin them away from the squad. If no useful returning cover exists, they follow normally. A new Go/Hold order may still position them defensively, but does not permit firing.
- The touch ground menu offers **Attack** on the upper-left diagonal and **Defend** on the upper-right; straight up still cancels. These stance commands do not require a reachable marked destination. Their current stance is visible in the HUD.
- Pause/dialogue cannot change the stance. Source switches and interruptions require fresh neutral input. Retry and Restart return to Defend and require a new Attack command.

## Bounded behaviour

| Companion | Native contribution |
|---|---|
| Miki | Use the long rifle against the exposed front sensor |
| Laura | Reach an external side angle and strike the coupling with the energy sword |
| Tom | Use the minigun against the exposed core, across repeated windows when needed |

The ordinary role, weapon, exposure and physical-contact rules apply whichever character is leading. A companion's hit is not a scripted damage shortcut. Weapon draw, turning, magazine/reload, cadence, minigun spin-up, spread, armour and cover remain real. Broken parts and accepted core damage retain the existing persistence/reset rules. The exact sequence, exposure time and hit count remain prototype balance choices.

- **Engagement:** companion combat requires the explicit Attack stance as well as the guard noticing the party or the player attacking it. An unaware guard, quiet approach or west-arch bypass must not be turned into a fight by a companion.
- **Positions:** seek nearby legal places with useful sight or tower cover, avoid committed fire when possible, and stay within an initial **8 m leader leash**. Routes respect stone, the living hull and other party members. No teleportation or damage immunity supplies a successful move.
- **Order priority:** Hold keeps its anchor; Go keeps its destination and movement priority. A companion may not abandon those orders to obtain a firing angle or a coupling strike. If the ordered position cannot support the action, that action waits. Defend explicitly cancels old orders to recall both companions; later position orders remain defensive until Attack is pressed.
- **Regrouping:** the existing Formation/Follow press clears tactical intentions and grants a temporary regroup interval: at least 2 seconds and until followers return near the leader. It retains its existing order-clearing/formation-cycle behaviour and never changes the standing Attack/Defend stance. The leader withdrawing also suppresses attacks and brings uncommanded companions back. Defend supplies persistent cease-fire and recall; explicit Hold/Go movement orders otherwise remain authoritative until cleared.
- **Ownership:** switching immediately returns the new leader to player authority; the old leader may resume bounded companion behaviour. Autonomous decisions never drive the player's current leader or replay an action after a control transition.
- **Lifecycle:** Pause, dialogue, inactivity and release gates retain their authority. Retry and Restart reset transient combat intentions alongside the encounter.
- **Defence:** use legal movement and cover. This task does not add automatic shield activation, signature abilities, healing, invulnerability or a general tactical AI framework. Tom's player-controlled dome retains its existing switch/drop rule.

The next retaliation pass makes a real attacking companion eligible for the guard's next warned cycle. Defend revokes attacks and recalls companions, but does not erase recent attack evidence or cancel a cycle already warned against them. The named target, finite turning and fixed committed point are owned by the [retaliation contract](guard-retaliation.md), rather than by companion navigation.

The aim is visible cooperation using the existing scene, weapons and simple signals. Exploration remains the main direction, and no new enemy, playable scene or art production is required.

## Verification gate

Before reporting the new behaviour as working, verify actual companion contacts and all three role contributions; awareness/attack activation; a quiet bypass; legal side access and cover; leash and temporary regroup/retreat; Hold/Go precedence; player authority after switching; native firing limits; Pause/interruption and retry/Restart. Include a rendered Simulator encounter with the player staying on one leader while the other characters complete their steps.

Record the tested source and actual results in the prototype plan and PR. Simulator results will not by themselves establish phone controls, multi-touch, readability, sustained frame pacing or enjoyment. Merge and TestFlight delivery keep their own authorisation and verification gates.

The explicit stance correction passed the full source check, all nine headless routes and rendered `companions`, `first-fight` and `weapons` routes. The new encounter ordered Attack, completed the prerequisites, ordered Defend and observed three seconds with no companion damage/ammo spend while recalling, then ordered Attack again to finish. Default cease-fire despite real player attacks, stale intent rejection, returning cover, mode/source cancellation and reset rules also passed their tests. The touch control's exposed accessibility actions changed the live Simulator HUD to Attack and back to Defend. This is not a physical touch-gesture or controller check. The [prototype plan](prototype-plan.md#explicit-stance-verification) records exact measurements and retains `14193d5`'s earlier results separately.
