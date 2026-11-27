# Guard damage and feedback

**Date:** 27 November 2026\
**Status:** The current [eye/leg/grenade revision](robot-eye-legs-grenades.md), under [issue #192](https://github.com/RonildoBraga/lauder/issues/192), retains the shared-health and feedback pipeline while simplifying part bonuses. Source/native and rendered Simulator verification passed on `303617b`, recorded in the [prototype plan](prototype-plan.md#eye-legs-and-grenades--in-development); it is unmerged and not delivered. Earlier source `533f012` passed its recorded checks and was delivered in [build 36](prototype-plan.md#build-36-testflight-preview), then retained in [build 37](prototype-plan.md#build-37-testflight-preview). Those historical results do not validate these new mechanics or establish physical acceptance.

## Maintainer direction

For the earlier shared-health revision, the maintainer asked for **“every successful hit”** to deal damage, with larger rewards for the appropriate companion and weak point, white normal-damage numbers, red weak-point numbers and restrained feedback for highly effective attacks. After the proposal to use shared enemy health and an optional weakness route, they said **“Proceed with your recommendations”**. These are relayed chat instructions on 27 November 2026; there is no public chat permalink. They authorised that bounded revision, including the related contact and feedback findings in [issue #180](https://github.com/RonildoBraga/lauder/issues/180).

That assignment replaced the earlier first-guard requirement that all three characters complete a mandatory sequence without changing biographies, enhancement histories or the exploration-led story direction. It added no scene, enemy, weapon, signature ability, random critical-chance system or dependency. The implementation assignment did not authorise merge or release. A later explicit TestFlight request authorised the verified [build 36 preview](prototype-plan.md#build-36-testflight-preview); merge and further deliveries keep their own authorisation.

**Current revision:** [Issue #192](https://github.com/RonildoBraga/lauder/issues/192) replaces the former weapon/exposure-gated bonus sequence with a persistent eye critical target, independent breakable legs and Tom's manual grenade. The [robot contract](robot-eye-legs-grenades.md) owns those new part/resource rules. Build 37 remains the delivered baseline until a separately verified upload. Earlier authorisation and delivery statements above describe that baseline.

## One health pool

The guard starts with **1,500 health**. Every valid damaging enemy contact reduces that same pool; reaching zero is the only damage-based victory condition. Ordinary body and leg contacts receive normal damage. A shot stopped by scenery or an ally is not a successful enemy hit, and a missed sword swing causes no damage.

```text
damage = weapon base damage × range modifier × weakness multiplier
```

Firearms use the actual hit distance for their existing positive range reduction; sword contacts use base damage after reach, arc and cover checks. Normal damage uses **×1**. An actual firearm hit on the visible front eye uses **×3**, with any gun and at any robot attack phase. Physical contact matters. A multiplier is not awarded merely because a particular character is selected, the aim is locked, or a shot starts inside an oversized component volume. The actual health reduction is clamped to the remaining health; feedback reports that applied amount.

| Weapon | Starting damage per contact | Existing cost |
|---|---:|---|
| Miki's long rifle | 48 | Slow firing, draw time, magazine and accuracy |
| Miki's assault rifle | 5 | Spread, magazine and reload |
| Laura's shotgun | 45 | Close effective range, slow cadence and reload |
| Laura's energy sword | 30 | Short reach, facing, swing arc and approach risk |
| Tom's minigun | 3 | Spin-up, fast magazine use, spread and slower movement |

These values and the guard's health are prototype tuning, not settled balance. The current shotgun is one scattered ray per blast; this task does not introduce pellets. Existing effective-range reduction remains positive. Tom's dome remains defensive equipment rather than another damaging weapon. Enemy attack timing, the party injury/retry rules and ordinary physical vulnerability retain their existing owners.

## Eye and leg opportunities

The eye remains available for later criticals; there is no disabled-sensor prerequisite, coupling breach or timed reactor window. The existing coarse body collision is refined only for a real front-eye ray, retaining scenery, allies and other enemies as blockers. The [robot contract](robot-eye-legs-grenades.md) records the measured target and collision approximation.

Laura's first two sword contacts damage a leg and the third detaches that individual leg, while every accepted contact also removes normal shared health once. Distinct leg counters, missing target volumes and progressive translation penalties replace the old coupling progress. Retry and Restart restore the counters and health; retreat within the encounter preserves them. No part chain is required before a kill.

Tom's grenade produces one ordinary area-damage result per enemy, with actual blast-cover checks and no eye or sword-leg multiplier. Its damage source has no paired weapon; it cannot aggregate with rapid gun contacts. Player and companion weapon hits otherwise use the same health rules.

## Companion authority

Under an explicit **Attack** command in an engaged fight, a companion prefers its useful reachable target: the eye for Miki/Tom and an intact leg for Laura. When that opportunity is closed or unavailable, they can use a safe ordinary attack: Miki's long rifle, Laura's shotgun or Tom's minigun. Useful local firing places respect the existing cover, hull, ally rays, intended spacing and destination bounds. If no legal shot is available, nearby support and movement remain useful; intention alone never causes damage.

**Defend** remains immediate companion cease-fire and recall. Hold keeps its anchor and allows only a shot possible from there; Go keeps movement priority. The selected leader is always player-controlled. Quiet acquisition, the west bypass, retreat, neutral-input gates and lifecycle retain authority. This adds neither automatic shielding nor a general tactical AI framework.

## Readable feedback

The simulation emits a resolved `DamageHit` only after an accepted health reduction. It includes the enemy, attacker, weapon, actual amount, impact position, effectiveness and whether a component broke. The existing frame's event batch supplies health feedback and presentation together; a shot, a planning label or an impact alone cannot stand in for damage.

- **Normal:** white number with a dark outline/shadow against the snow.
- **Eye critical:** red number with a small weak-point symbol and stronger type, so colour is not the only distinction.
- **Effective impact:** a restrained, rate-limited glint from the existing pooled effects, especially on a component break. This does not add another damage multiplier or a random critical roll.
- **Health:** one guard health bar; the eye/leg cue explains an opportunity rather than claiming immunity elsewhere.

Numbers keep a readable screen size at the actual projected impact position, rise gently and fade over an initial **0.8 seconds**. The presenter keeps a bounded visible set, initially **eight** labels. Fast minigun and assault-rifle contacts accumulate over **0.30 seconds**, keyed by enemy, attacker, weapon and effectiveness; every hit contributes to the displayed amount, and white and red totals are never combined into a misleading red value. Single rifle, shotgun and sword contacts retain individual feedback. The overlay is not interactive and cannot intercept touch controls. Reduce Motion uses stable separate positions instead of rising labels, so consecutive totals remain readable without movement.

Pause suspends or hides feedback alongside play. Backgrounding, Retry and Restart cancel stale labels and accumulators so a previous attempt's damage cannot appear on a restored enemy. Impact sounds retain the existing single event path; a damage number must not play a duplicate strike sound.

## Verification gate

Run rule and native-contact checks for ordinary solo damage/victory, persistent eye bonuses with each gun, independent sword-leg progress, finite/overkill/reset behaviour and player/AI equality. Verify body/component overlap counts a bullet only once, clear oblique eye contacts remain critical, rear hull and cover still block them, point-blank classification respects the aimed contact, and sword-body damage retains real reach, arc and solid-cover checks. Marker materials should be reused rather than rebuilt every update.

Check actual companion normal attacks and eye/leg preferences under Attack, cease-fire on Defend, hard orders, spacing, manual leadership, quiet bypass and lifecycle. Compare displayed sums against accepted health reduction, including rapid fire, mixed effectiveness, a killing blow, multiple fixed steps per presented frame and cancellation across Pause/interruption/Retry/Restart.

The standard `./scripts/check` and ordinary-input rendered Simulator encounters must pass on a recorded source. Record damage contributions, time to defeat, injuries/retries, clarity and remaining limits in the prototype plan and PR. Simulator checks do not establish physical controls, audibility, phone readability, sustained performance or enjoyment. Verification for earlier previews does not validate this damage revision.

The five ordinary-solo native contact tests isolate incoming damage to verify outgoing weapon and health rules. Debug encounter drivers explicitly order **Attack** and permit genuine companion support; their completion demonstrates squad play with ordinary incoming damage, rather than solo survival.
