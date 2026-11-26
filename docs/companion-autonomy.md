# Companion autonomy at the first tower

**Date:** 27 November 2026\
**Status:** The ordinary-attack extension for [shared guard health and damage feedback](damage-feedback.md) is in development on `codex/guard-damage` under [issue #183](https://github.com/RonildoBraga/lauder/issues/183), based on [PR #175](https://github.com/RonildoBraga/lauder/pull/175), source `5421873`. New source/rendered verification is pending in the [prototype plan](prototype-plan.md#guard-damage-and-feedback--in-development). Earlier autonomy/Attack/Defend results remain recorded below and in the [earlier plan section](prototype-plan.md#companion-autonomy--in-development). Internal build 35 remains the delivered preview; those results do not validate this revision.

## Maintainer direction

After playing build 33, the maintainer reported **“It worked nice”**, then asked for companions to act independently. The explicit follow-up choice was **“Companions can complete the weakpoint steps too”**. These are maintainer decisions relayed from chat, which has no public permalink. The first comment is generic phone feedback; it does not establish individual control acceptance, sustained performance or permission to merge.

The player always controls the leader. The other two may move and fight within this encounter, including completing their own native contributions to the [strategic guard](strategic-guard.md). All three characters still contribute, but the player need not switch leader for every step. Existing L1 / LB, Q and touch Next remain available for taking direct control.

The maintainer then clarified: **“they should only attack and complet the steps if I press to attack”** and **“if I press to defend on the d pad then they should seek cover and try to go back to me”**. This replaces automatic engagement permission with an explicit standing squad stance. The player firing or the guard noticing the party does not authorise companion attacks.

After build 34 the maintainer reported **“The Attack and Defend controls are working”**. This is basic command feedback, not every-input or sustained-performance acceptance. Their subsequent **“proceed”** authorises the [guard-retaliation comparison](guard-retaliation.md), recorded in [issue #171](https://github.com/RonildoBraga/lauder/issues/171), without changing the companion command contract. Its source and Simulator verification are recorded in the [prototype plan](prototype-plan.md#guard-retaliation--in-development). The later authorised [build 35 preview](prototype-plan.md#build-35-testflight-preview) is available to existing testers; the PRs remain unmerged and phone acceptance is pending.

On 27 November the maintainer requested positive damage from every successful hit and approved the shared-health/optional-weakness proposal with **“Proceed with your recommendations”** (chat; no public permalink). Companions therefore need a safe ordinary-attack fallback when their specialist opportunity is unavailable. This replaces the earlier all-three victory gate while preserving explicit commands and player ownership. The [damage contract](damage-feedback.md) owns the new rules; it does not settle biographies or add signature abilities.

## Attack and Defend

- Start in **Defend**. D-pad/arrow **Up** orders **Attack**; **Down** orders **Defend**. Left/right still position the individual companion. Keyboard **G/H** and the touch ground menu retain Both/Hold orders.
- **Attack** permits role-aware companion attacks once the fight is engaged: prefer a useful matching exposed part, otherwise use a safe ordinary shot. It persists across leader changes until Defend is ordered; the player-controlled leader is always manual.
- **Defend** immediately revokes companion fire permission, cancels old Hold/Go orders and recalls the companions without cycling the formation. They try legal nearby cover along the return toward the leader; remote cover cannot pin them away from the squad. If no useful returning cover exists, they follow normally. A new Go/Hold order may still position them defensively, but does not permit firing.
- The touch ground menu offers **Attack** on the upper-left diagonal and **Defend** on the upper-right; straight up still cancels. These stance commands do not require a reachable marked destination. Their current stance is visible in the HUD.
- Pause/dialogue cannot change the stance. Source switches and interruptions require fresh neutral input. Retry and Restart return to Defend and require a new Attack command.

## Bounded behaviour

| Companion | Preferred weakness opportunity | Ordinary fallback |
|---|---|---|
| Miki | Long rifle against the exposed front sensor | Long-rifle body shot |
| Laura | Reach an external side angle and strike the coupling with the energy sword | Shotgun body shot |
| Tom | Minigun against the exposed core | Minigun body shot |

The same weapon, exposure and physical-contact rules apply to player and companion hits. Every valid damaging contact reduces the shared guard health; matching exposed parts earn the bonus. The weapon match does not add an actor-identity damage gate. A companion's intention is not a scripted damage shortcut. Weapon draw, turning, magazine/reload, cadence, minigun spin-up, spread and cover remain real. Health loss and optional broken parts retain their persistence/reset rules. The health, weapon values and bonus multiplier are initial tuning rather than settled balance.

- **Engagement:** companion combat requires the explicit Attack stance as well as the guard noticing the party or the player attacking it. An unaware guard, quiet approach or west-arch bypass must not be turned into a fight by a companion.
- **Positions:** seek nearby legal places with useful sight or tower cover, avoid committed fire before ordinary firing, and keep tactical destinations within the existing **8 m leader leash**. Body-fire candidates are short local moves; connected regions admit cover destinations while the existing motor owns cached routes and real collision. Intended spacing and actual moving-body separation remain distinct, as the [cover contract](bridge-cover-spacing.md) explains. No teleportation or damage immunity supplies a successful move.
- **Order priority:** Hold keeps its anchor; Go keeps its destination and movement priority. A companion may not abandon those orders to obtain a firing angle or a coupling strike. If the ordered position cannot support the action, that action waits. Defend explicitly cancels old orders to recall both companions; later position orders remain defensive until Attack is pressed.
- **Regrouping:** the existing Formation/Follow press clears tactical intentions and grants a temporary regroup interval: at least 2 seconds and until followers return near the leader. It retains its existing order-clearing/formation-cycle behaviour and never changes the standing Attack/Defend stance. The leader withdrawing also suppresses attacks and brings uncommanded companions back. Defend supplies persistent cease-fire and recall; explicit Hold/Go movement orders otherwise remain authoritative until cleared.
- **Ownership:** switching immediately returns the new leader to player authority; the old leader may resume bounded companion behaviour. Autonomous decisions never drive the player's current leader or replay an action after a control transition.
- **Lifecycle:** Pause, dialogue, inactivity and release gates retain their authority. Retry and Restart reset transient combat intentions alongside the encounter.
- **Defence:** use legal movement and cover. This task does not add automatic shield activation, signature abilities, healing, invulnerability or a general tactical AI framework. Tom's player-controlled dome retains its existing switch/drop rule.

The existing retaliation pass makes a real attacking companion eligible for the guard's next warned cycle. Defend revokes attacks and recalls companions, but does not erase recent attack evidence or cancel a cycle already warned against them. The named target, finite turning and fixed committed point are owned by the [retaliation contract](guard-retaliation.md), rather than by companion navigation.

The aim is visible cooperation using the existing scene, weapons and simple signals. Exploration remains the main direction, and no new enemy, playable scene or art production is required.

## Verification gate

Before reporting the new behaviour as working, verify actual ordinary companion damage and useful exposed-part preferences; awareness/attack activation; a quiet bypass; legal side access and cover; destination leash and temporary regroup/retreat; Hold/Go precedence; player authority after switching; native firing limits; Pause/interruption and Retry/Restart. Include a rendered Simulator encounter with the player staying on one leader while the others contribute through their actual weapons. Shared-health progress must not require all three role steps.

Record the tested source and actual results in the prototype plan and PR. Simulator results will not by themselves establish phone controls, multi-touch, readability, sustained frame pacing or enjoyment. Merge and TestFlight delivery keep their own authorisation and verification gates.

**Earlier verification, 26 November:** The explicit stance correction passed the full source check, all nine headless routes and rendered `companions`, `first-fight` and `weapons` routes. That encounter ordered Attack, completed the mandatory prerequisites, ordered Defend and observed three seconds with no companion damage/ammo spend while recalling, then ordered Attack again to finish. Default cease-fire despite real player attacks, stale intent rejection, returning cover, mode/source cancellation and reset rules also passed their tests. The touch control's exposed accessibility actions changed the live Simulator HUD to Attack and back to Defend. This is not a physical touch-gesture or controller check, nor validation of the new shared-health damage rules. The [prototype plan](prototype-plan.md#explicit-stance-verification) records exact measurements and retains `14193d5`'s earlier results separately.
