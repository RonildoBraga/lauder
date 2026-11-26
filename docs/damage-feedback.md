# Guard damage and feedback

**Date:** 27 November 2026\
**Status:** In development on `codex/guard-damage`, following [issue #183](https://github.com/RonildoBraga/lauder/issues/183). This revision starts from [PR #175](https://github.com/RonildoBraga/lauder/pull/175), source `5421873`, retaining its bridge cover and companion spacing. Source, rendered Simulator and physical-phone verification are pending for the new damage rules. The [prototype plan](prototype-plan.md#guard-damage-and-feedback--in-development) owns completed results when available. Internal [TestFlight 0.1.0 (35)](prototype-plan.md#build-35-testflight-preview) remains the delivered preview.

## Maintainer direction

The maintainer asked for **“every successful hit”** to deal damage, with larger rewards for the appropriate companion and weak point, white normal-damage numbers, red weak-point numbers and restrained feedback for highly effective attacks. After the proposal to use shared enemy health and an optional weakness route, they said **“Proceed with your recommendations”**. These are relayed chat instructions on 27 November 2026; there is no public chat permalink. They authorise this bounded combat revision, including the related contact and feedback findings in [issue #180](https://github.com/RonildoBraga/lauder/issues/180).

This replaces the earlier first-guard requirement that all three characters complete a mandatory sequence. It does not change biographies, enhancement histories or the exploration-led story direction. No new scene, enemy, weapon, signature ability, random critical-chance system or dependency is part of the task. Merge and another TestFlight delivery keep their own authorisation.

## One health pool

The guard starts with **1,500 health**. Every valid damaging enemy contact reduces that same pool; reaching zero is the only damage-based victory condition. Armour, a closed component or an unmatched weapon receives normal damage. A shot stopped by scenery or an ally is not a successful enemy hit, and a missed sword swing causes no damage.

```text
damage = weapon base damage × range modifier × weakness multiplier
```

Firearms use the actual hit distance for their existing positive range reduction; sword contacts use base damage after reach, arc and cover checks. Normal damage uses **×1**. The appropriate weapon hitting its matching exposed part uses **×3**. Exposure and actual contact both matter. A multiplier is not awarded merely because a particular character is selected, the aim is locked, or a shot starts inside an oversized component volume. The actual health reduction is clamped to the remaining health; feedback reports that applied amount.

| Weapon | Starting damage per contact | Existing cost |
|---|---:|---|
| Miki's long rifle | 48 | Slow firing, draw time, magazine and accuracy |
| Miki's assault rifle | 5 | Spread, magazine and reload |
| Laura's shotgun | 45 | Close effective range, slow cadence and reload |
| Laura's energy sword | 30 | Short reach, facing, swing arc and approach risk |
| Tom's minigun | 3 | Spin-up, fast magazine use, spread and slower movement |

These values and the guard's health are prototype tuning, not settled balance. The current shotgun is one scattered ray per blast; this task does not introduce pellets. Existing effective-range reduction remains positive. Tom's dome remains defensive equipment rather than another damaging weapon. Enemy attack timing, the party injury/retry rules and ordinary physical vulnerability retain their existing owners.

## Optional weakness route

| Opportunity | Preferred native weapon | Result |
|---|---|---|
| Exposed front sensor during recovery | Long rifle | Bonus damage and persistent sensor disable |
| Exposed side coupling after the sensor | Energy sword | Bonus damage and persistent coupling breach |
| Exposed core after the breach | Minigun | Bonus damage to the shared health pool |

The breach opens a **4-second** core window if made during recovery; otherwise entering the next recovery opens it. Later recovery entries supply another window. Closed windows retain ordinary damage and existing health loss. Sensor and coupling state survive retreat within the encounter and switching; Retry and Restart reset them with health. There is no separate required core-round total and no requirement to finish this route before health can reach zero.

Weapon behaviour determines the match, not an additional actor-identity damage gate. Player and companion hits use the same rules. Switching still gives the player direct control of positioning and timing. All damage-dealing characters can make progress through ordinary attacks.

## Companion authority

Under an explicit **Attack** command in an engaged fight, a companion prefers a reachable exposed matching part. When that opportunity is closed or unavailable, they can use a safe ordinary attack: Miki's long rifle, Laura's shotgun or Tom's minigun. Useful local firing places respect the existing cover, hull, ally rays, intended spacing and destination bounds. If no legal shot is available, nearby support and movement remain useful; intention alone never causes damage.

**Defend** remains immediate companion cease-fire and recall. Hold keeps its anchor and allows only a shot possible from there; Go keeps movement priority. The selected leader is always player-controlled. Quiet acquisition, the west bypass, retreat, neutral-input gates and lifecycle retain authority. This adds neither automatic shielding nor a general tactical AI framework.

## Readable feedback

The simulation emits a resolved `DamageHit` only after an accepted health reduction. It includes the enemy, attacker, weapon, actual amount, impact position, effectiveness and whether a component broke. The existing frame's event batch supplies health feedback and presentation together; a shot, a planning label or an impact alone cannot stand in for damage.

- **Normal:** white number with a dark outline/shadow against the snow.
- **Matched weakness:** red number with a small weak-point symbol and stronger type, so colour is not the only distinction.
- **Effective impact:** a restrained, rate-limited glint from the existing pooled effects, especially on a component break. This does not add another damage multiplier or a random critical roll.
- **Health:** one guard health bar; the optional part cue explains an opportunity rather than claiming immunity elsewhere.

Numbers keep a readable screen size at the actual projected impact position, rise gently and fade over an initial **0.8 seconds**. The presenter keeps a bounded visible set, initially **eight** labels. Fast minigun contacts accumulate over **0.15 seconds**, keyed by enemy, attacker and effectiveness; every hit contributes to the displayed amount, and white and red totals are never combined into a misleading red value. Single rifle, shotgun and sword contacts retain individual feedback. The overlay is not interactive and cannot intercept touch controls. Reduced-motion presentation retains the information with less movement.

Pause suspends or hides feedback alongside play. Backgrounding, Retry and Restart cancel stale labels and accumulators so a previous attempt's damage cannot appear on a restored enemy. Impact sounds retain the existing single event path; a damage number must not play a duplicate strike sound.

## Verification gate

Run rule and native-contact checks for ordinary solo damage/victory, positive closed/unmatched damage, correct exposed bonuses, optional structural progress, finite/overkill/reset behaviour and player/AI equality. Verify body/component overlap counts a bullet only once, point-blank classification respects the aimed contact, and sword-body damage retains real reach, arc and solid-cover checks. Marker materials should be reused rather than rebuilt every update.

Check actual companion normal attacks and weak-point preferences under Attack, cease-fire on Defend, hard orders, spacing, manual leadership, quiet bypass and lifecycle. Compare displayed sums against accepted health reduction, including rapid fire, mixed effectiveness, a killing blow, multiple fixed steps per presented frame and cancellation across Pause/interruption/Retry/Restart.

The standard `./scripts/check` and ordinary-input rendered Simulator encounters must pass on a recorded source. Record damage contributions, time to defeat, injuries/retries, clarity and remaining limits in the prototype plan and PR. Simulator checks do not establish physical controls, audibility, phone readability, sustained performance or enjoyment. Verification for earlier previews does not validate this damage revision.

The five ordinary-solo native contact tests isolate incoming damage to verify outgoing weapon and health rules. Debug encounter drivers explicitly order **Attack** and permit genuine companion support; their completion demonstrates squad play with ordinary incoming damage, rather than solo survival.
