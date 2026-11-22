# ADR 0013 — Relay Run, a complete salvage mission

**Status:** Implementation prepared; Simulator and release verification pending\
**Date:** 22 November 2026

## Assignment and boundary

After build 22, Codex recommended one coherent exploration-and-salvage mission: reach a shelter with a broken transmitter, explore a small frozen district with a safe detour and optional guarded shortcut, recover a compatible part using the trio's existing strengths, then return and repair the transmitter. Codex proposed a short walkthrough and bounded implementation plan first, followed by Simulator implementation and TestFlight delivery. The maintainer answered **“Proceed with your recommendation”**.

This assigns **Relay Run**, level `relay-run`, as a standalone greybox prototype. The [walkthrough](../relay-run-walkthrough.md) describes its player experience. Its location in the journey, dialogue and character implications remain provisional. It does not place [Relay House](../story/story-bible.md#later-scene--relay-house) on the map, change the bridge opening or assign the full [Quiet Yard](../encounters/the-quiet-yard.md) screenplay.

The mission details below are engineering defaults within that assignment, not additional quotations or permanent character canon. Existing Simulator-first development and TestFlight delivery continue; physical results and subjective judgement remain in the [deferred checklist](../prototype-plan.md#deferred-phone-and-playtest-checks).

## Decisions

### One continuous journey

The whole trio starts together beside the shelter's broken transmitter. A short district route leads to the depot and back. Tall, readable blocks separate a longer safe route from a shorter guarded route. The elevated camera, current palette and contextual prompts explain the choice before a commitment. The safe route admits all three in their normal formations and permits the repair without entering combat or firing a shot. Mission data supplies outward guidance to the depot, return guidance while the bag holds a regulator that might fit, and the completed objective after repair. An unidentified wrong model also offers return guidance; the compass must not reveal knowledge the party has not acquired. A failed fit identifies that model and sends the search back to the depot.

Relay Run is reached through the existing pause-menu level choice while prototypes remain separate: **Combat test** from the bridge, **Salvage test** from the combat yard, then **Relay mission** from the salvage yard. Its own next-level choice returns to **Bridge**. The mission itself uses ordinary movement and contextual actions, with no additional travel menu. Existing venues and the bridge remain available.

### Reuse the salvage task

The depot reuses [ADR 0006](0006-salvage-and-exploration-experiment.md)'s rules:

- Laura reaches the release latch or Tom shifts the loose panel. Either opens access for everyone; neither must act first.
- The disconnected compatible regulator, wrong model and live supply are dealt among the cabinets each run. Miki identifies them. Others can search blind and discover a wrong model on attempting the fit.
- Nobody disconnects the live supply. Once a regulator is known not to fit, the existing rules prevent taking it unnecessarily.
- The shared bag has no weight or separate character inventory. The compatible part is fitted at the shelter, giving the outward trip a purposeful return.

The repair completes the mission and gives a brief provisional exchange through the existing conversation path. Before a fit attempt in this mission, the party must be out of an encounter and gathered within 5 m of the leader beside the transmitter; otherwise a line asks the player to bring everyone back. This keeps the closing exchange from freezing a distant or exposed companion. It discloses no family relationships, enhancement histories or cause of the collapse. No non-playable quest-giver or new conversation framework is required.

### One optional guard

The shortcut has one stationary rifle guard using the existing hostile stand-in, weapon warnings and hit rules. Rust posts mark its defended frontage; the longer west lane is marked separately and separated by a full-height service wall. An exposed party member inside the defended area can alert it; leadership switching must not hide a companion from detection. It selects targets within that area, under the existing sight and range rules. Authored starting values are a displayed warning line, engagement after 0.9 seconds, a 0.35-second reaction delay and the normal 1.5-second wind-up, giving time to reverse before a hit is required. These are tuning defaults. The bridge and earlier yards keep their encounter defaults.

The guard does not patrol, chase onto the safe route, summon reinforcements or require a particular signature. All three leaders keep their current weapons. Companion defence, cover, orders and Miki's Disrupt use their existing controls and rules. The encounter changes the shortcut's risk, not the repair's availability.

### Retreat retains progress

The player can turn back behind the service wall. Regroup recalls companions and suppresses their fire through its existing mapping. The whole party must clear the guarded area before contact ends. The service wall provides real sight and shot protection along the route out; the visible perimeter bounds the guard's targets and explains why it stays at its post. Ordinary sight, range and damage rules still apply to targets inside that area while contact remains active.

Leaving keeps collected regulators, the open gate, inspection knowledge, spent shared rounds and damage already dealt to the guard. Returning in the same run preserves that progress. Withdrawal cancels unspent burst shots without refilling magazines or clearing reload readiness. Hits recover after a completed withdrawal. The current third-hit fallback remains available as failure recovery and keeps the existing salvage/damage retention policy; it is distinct from a successful walking retreat.

Restart starts a fresh run: close the gate, reshuffle the cabinets, clear the bag and repair, reset guard damage and warnings, restore spawn points and require neutral input. Pause freezes movement and combat timers. A level change owns a fresh mission.

## Implementation sequence

1. **Content and journey:** add the standalone level, its shelter/depot/routes, clear landmarks, short provisional lines and access through the existing level cycle. Reuse the existing task and inventory.
2. **Bounded contact:** add only the level data and runtime handling needed for the stationary guard's fair detection and whole-party withdrawal. Preserve defaults for the bridge and existing yards.
3. **Completion and verification:** show the completed repair, exercise Restart and interruption rules, and run focused tests plus rendered Simulator routes. Verify level cycling and construction costs with the additional venue.
4. **Review and delivery:** address review findings, run `./scripts/check`, verify the signed Release archive and deliver through the established API-authenticated TestFlight workflow. Confirm Apple processing and availability to existing testers. Record actual source/build and results in the shared status documents.

## Acceptance criteria

- A complete safe-route run repairs the transmitter without an encounter, party damage or ammunition spent.
- Both gate approaches admit the whole party; neither is a compulsory character sequence. Inspection, blind search, wrong-model handling and the live supply retain their existing rules.
- A companion exposed inside the defended area can alert the guard. The covered safe path keeps the whole party clear; changing leader does not erase contact.
- The warning, optional fight and retreat are readable. Retreat ends only with everyone safely clear, and re-entry preserves salvage and guard damage.
- Repair completes once; the short exchange remains provisional. Restart, Pause, input recovery and level changes reset or preserve the intended state without duplicate entities or stale commands.
- Focused rule/navigation/integration tests pass. Rendered runs cover a no-shot repair, guard contact and withdrawal/re-entry, and optional combat with onward salvage. Existing opening, combat and salvage scenarios remain regressions.
- Signed Release and TestFlight verification pass before delivery is reported. Simulator timings and screenshots do not establish physical multi-touch, controller feel, baseline-phone 60 fps or whether the mission is enjoyable.

## Scope kept for later

No new art production, patrol or stealth framework, new signatures, climbing, lifting physics, crafting, survival meters, health system, skill trees, branching dialogue, persistent saving or additional story encounter is assigned. Use existing patterns and simple shapes to answer whether a complete journey makes exploration, switching and useful salvage work together.
