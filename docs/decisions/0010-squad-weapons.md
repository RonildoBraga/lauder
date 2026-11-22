# ADR 0010 — The squad's weapons

**Status:** Built and checked in Simulator; physical checkpoint pending\
**Date:** 22 November 2026


**Current scope:** The bridge-only reset retired the non-bridge experiments described here. Shared rules remain only where the bridge uses them; this record preserves the earlier decisions and measurements, not an assignment to restore deleted systems. See [ADR 0017](0017-bridge-only-reset.md) and the current [architecture](../architecture.md).

## Context and assignment

Phase 3 of [ADR 0008](0008-weapon-feel-and-combat-plan.md), tracked in [issue #93](https://github.com/RonildoBraga/lauder/issues/93), lets every member fire their own weapon as leader. The [story bible](../story/story-bible.md#combat-identities) supplies Miki's precision carbine, Laura's light burst weapon and Tom's close scatter weapon.

After the successful TestFlight delivery, the maintainer instructed: **“It worked please continue and don’t wait for me because you can do your tests using the simulator”**. This assigns continued Simulator development without waiting for repeated phone sessions. The numeric defaults below are Codex's implementation choices for this bounded prototype, not separately quoted maintainer decisions or permanent character canon. They remain tunable through playtests. The delivery response does not establish every pending phone behaviour or performance result.

## Prototype decisions

| Member | Weapon | Magazine gate | Automatic reload | Handling |
| --- | --- | ---: | ---: | --- |
| Miki | Precision carbine | 12 shots | 1.2 s | Existing 14 m reach, 0.4 s interval and measured-shot spread |
| Laura | Light burst weapon | 18 shots | 1.4 s | Three shots 0.12 s apart, 1.8 s between bursts, 12 m reach; lighter recoil and wider spread |
| Tom | Close scatter weapon | 4 shots | 1.8 s | One wide shot dealing two hits, 1.5 s interval, 7 m reach; heavier recoil |

- **One ammunition count.** `GameSession.ammo` remains the total number of player-fired rounds left. Each actual leader shot during an encounter spends one; practice outside an encounter and companion shots spend none. Reloading never adds or subtracts shared rounds. The magazine is a readiness gate, not a second inventory; during an encounter the HUD clamps its displayed loaded count to available shared rounds. Outside one, it identifies free practice and shows the mechanical gate, so an empty shared pool does not misleadingly say the practice weapon cannot fire.
- **Automatic reload.** The last magazine shot starts the timer. While reloading the character cannot fire; they can move, take cover and switch leader. No reload button or ammunition selection is added. The mechanical gate refills after its timer, but an empty shared pool still prevents player fire during an encounter.
- **State belongs to the character.** Draw, cooldown, partial burst, magazine and reload state are shared by their leader and companion roles. Switching cancels a queued burst without refilling or resetting timing. Timers advance once per exploring fixed step, including for an inactive party member, and freeze on Pause. Restart and fallback restore weapon readiness while preserving the existing rules for shared ammunition and hostile damage.
- **Trigger release matters.** Releasing Fire or losing a companion's target stops unspent burst shots. Starting another burst cannot bypass the weapon's interval. The existing input authority, priority and recovery gates remain the only route to commands.
- **Companions can miss.** Each member keeps their own seeded spread state across roles. Companion shots pass through `Scatter`; this phase retained their earlier obstruction rules, and they still do not start a fight or activate signatures by themselves. The subsequently assigned [phase 4](0011-companion-combat.md) shares the cover rule and adds coordinated target selection.
- **Presentation follows the weapon.** Reusable primitive props differ in length and width. Grip, muzzle and kick values match the prop. Existing generated sounds are reused; leader-fired burst/scatter shots get distinct haptic cues and DualSense resistance settings. Readiness, Pause, source changes and reload clear resistance through the existing feedback owner.
- **Phase 3 scope.** The weapons work wherever a recruited character leads. Cover remains the combat-yard experiment of [ADR 0009](0009-leader-cover.md). This phase adds no pellets, separate inventories, pickups, rigged animation, new signatures, enemy behaviours or extra combat encounters. The later companion/enemy work has its own bounded assignments in [ADR 0011](0011-companion-combat.md) and [ADR 0012](0012-tactical-enemies.md).

## Validation and remaining limits

Plain-Swift tests cover cadence, burst cancellation, magazines, exact reload boundaries and switching without free refills. Production tests cover all three weapons, shared-round spending, companion misses, Pause and reset. A separate scripted Simulator route exercises the trio, reloads, switching and Pause; the existing bridge, combat and salvage routes remain regressions.

This phase passed `./scripts/check`, including all twelve headless scenarios. Rendered Simulator routes passed: `squad-weapons` (60/60 steps), `combat-yard` (90/90), `leader-cover` (74/74) and `ambush` (35/35). Recorded frames show the three props, loaded counts and reload status. An unsigned Release Simulator build also passed. Hardware haptics, DualSense trigger feel, touch combinations and baseline-phone performance still need physical evidence. The reviewed weapon work is integrated, and the later continuous assignment in [ADR 0011](0011-companion-combat.md) covers subsequent reviewed merges and TestFlight deliveries without repeated milestone approval. These weapons and the subsequent combat phases are delivered in **0.1.0 (21)**. The [prototype plan](../prototype-plan.md#verification-and-performance) records the final integrated checks, signed Release archive and verified Apple/TestFlight availability.
