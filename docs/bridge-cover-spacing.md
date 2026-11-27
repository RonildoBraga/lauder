# Bridge cover and companion spacing

**Date:** 27 November 2026\
**Status:** Implemented and source/Simulator verified on `codex/bridge-cover-spacing`, in [PR #175](https://github.com/RonildoBraga/lauder/pull/175) for [issue #174](https://github.com/RonildoBraga/lauder/issues/174). The [prototype plan](prototype-plan.md#bridge-cover-and-spacing--in-development) records the original source and results and owns current release gates and delivery evidence; the comparison below retains its original baseline.

## Assignment and comparison

The maintainer said **“Looks good. Go ahead and improve the cover and companion spacing on the bridge.”** This is a relayed chat instruction on 27 November 2026; no public chat permalink is available. It authorises the bounded layout and positioning changes below. “Looks good” is generic feedback, not a measured phone-control, audibility or performance result. Merge and another release are not part of this assignment.

The question is whether useful separate shelter and less crowded companion destinations make [Attack/Defend](companion-autonomy.md#attack-and-defend) more meaningful. Keep the existing guard damage, alternating precision/fan patterns, warning and recovery timings, [then-current weakpoint sequence](strategic-guard.md#earlier-mandatory-prototype), input rules and quiet west bypass as the comparison baseline. This adds no enemy, weapon, ability, cover-snap input or general tactical framework.

## Two simple shelters

The bridge's [Blender source](../blender/levels/brooklyn-bridge.blend) remains authoritative. Its generated [layout](../apple/sources/content/BrooklynBridgeLayout.swift) and scene must come from the normal export workflow.

| Gameplay box | Size across / up / along | Purpose |
|---|---|---|
| `bridge-cover-west` | 1.8 / 1.65 / 1.4 m | A separate sheltered place near the tower's centre pier |
| `bridge-cover-east` | 2.4 / 1.65 / 1.4 m | A second, wider sheltered place towards the east flank |

These are simple blocks, with their visible shapes matching their movement and ballistic boxes. They stand on the approach side of the first-tower guard area. The centre passage, east side approach to the coupling and existing quiet west arch must remain usable. Shelter must come from real cover blocking both gun origins through the ordinary guard poses; no hidden damage exemption supplies it. The dimensions and placement are prototype values, not settled level balance.

## Separate intended places

Within the engaged guard fight, autonomous destinations seek **1.2 m clearance** from the leader and other reserved destinations. The world seeds reservations from explicit Hold/Go anchors, previous intended places or formation slots, then updates them in the stable companion order. It does not permanently reserve every moving body's current position. A cached destination becomes invalid immediately when another reservation occupies it.

The policy checks standability, connected navigation regions, the living hull, threat, cover and firing. A destination behind a block can be admitted without a direct clear line through that block; the existing motor alone builds and caches its route, with real collision checks while moving. A crowded firing stance can use a short legal step; a companion without useful nearby cover can settle at a clear local recall/support point when its current or normal formation place conflicts.

Defend may choose real shelter within **2.6 m** of the leader even when the formation faces away from it. Outside that nearby-recall distance, a destination must progress towards both the leader and the formation. All tactical destinations retain the **8 m** combat leash. These bounds apply to selected endpoints; connectivity does not guarantee every point of a detour stays within them. Cover must not become a remote implicit Hold order or constant orbit.

The 1.2 m value is a desired destination gap, not a guarantee about every transient body or path. Bodies retain their ordinary **0.26 m radius**, collision, motor yield and route rules. A narrow route, a newly moving leader or an unavoidable threat may temporarily prevent that gap. No teleportation, forced placement, immunity or larger physical collision radius is added.

Explicit Go/Hold positioning keeps priority over autonomous spacing. The player always owns the leader; switching cannot turn their previous destination into an autonomous command for the new leader. Defend remains cease-fire and recall, while Attack still requires explicit permission. Ordinary formations outside this fight, lifecycle/release gates, bypass, Retry and Restart retain their existing authority.

## Verification gate

Check the authored shelter from both real muzzles, accessible separate places, the centre/east/west lanes and clearance around the guard. Exercise reservation conflicts, immediate cache invalidation, stable settling, Hold/Go priority, switching and reset. Native weapon, collision, actual ray and injury rules must remain in control.

Use ordinary-input headless and rendered Simulator routes for Attack, Defend, return to cover, spacing, dismantling, quiet bypass and Restart. Record actual injuries/retries, useful cover and separation over time rather than claiming every frame keeps an ideal gap. The [prototype plan](prototype-plan.md#bridge-cover-and-spacing--in-development) owns the exact completed results when available. Source tests and Simulator recordings do not establish physical-phone controls, audibility, sustained performance or enjoyment.
