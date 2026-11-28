# ADR 0019 — Dodge roll

**Status:** Accepted, with starting values to tune in play; implemented with the party's [pawns](../visual-direction.md#characters-and-interface) in [PR #155](https://github.com/RonildoBraga/lauder/pull/155). Played on the phone in TestFlight build 32, where the maintainer said the weapons and controls feel right ([playtest](../bridge-prototype-plan.md#build-32-playtest)).

**Date:** 25 November 2026

## Assignment

While the party's figures were being simplified to pawns, the maintainer asked for a way to escape attacks: **“we should have an animation for dodge roll because this is something I need to implement in the game to escape an attack”**. The proposal in [issue #142](https://github.com/RonildoBraga/lauder/issues/142#issuecomment-7155287429) was accepted as starting values with **“Accept roll”** ([record](https://github.com/RonildoBraga/lauder/issues/142#issuecomment-7158435465)). The maintainer then said **“Start building”**. All three were said in a Claude session, which has no public permalink.

Unmerged draft PRs #150 to #154 proposed a different ADR 0019, for skeletal character animation profiles. That route is on hold now that the party are pawns, so this record takes the number on `main`.

## Decision

- **Input:**
  - Square on PS5, X on Xbox, Space on a keyboard, or the touch **Roll** button, which sits beside Fire and shows with it while exploring.
  - A roll needs a fresh press while exploring. Dialogue and Pause consume the press rather than queueing it.
  - A switch, formation or order command in the same sample cancels it, as it cancels the action.
  - A held press keeps the release gate closed, like every other button.
- **Movement:**
  - The leader covers 3 m in 0.45 s, fast at first and slowing at the end. The roll goes the way the stick points, or the way the leader faces if the stick is centred.
  - The roll replaces the leader's walking movement, and PartyMotion resolves it like any movement, so a tower or the road's edge stops it.
  - The leader turns to the roll's direction as it starts and does not turn during it.
- **Hits:** hostile shots pass through the leader for the whole roll. `EncounterSimulation` leaves the rolling leader out of the hostiles' shot targets only. Hostiles still see, aim at and follow the leader, and the companions can still be hit.
- **Limits:**
  - The leader does not fire during a roll. A Fire press during it is dropped, and a held Fire resumes when it ends.
  - The next roll waits 0.5 s after one ends.
  - Only the leader rolls.
  - A scene that holds the party, or a downed leader, cannot start a roll.
  - Switching leader, or a scene that begins mid-roll, ends the roll, and the next still waits 0.5 s.
  - A press that no fixed step took up before a Pause or interruption is dropped, as is a Fire press.
- **Presentation:** the pawn tumbles one full turn forward over the way it rolls. At the middle of the roll it is tucked to 55% of its height and 115% of its width, and lowered so that it stays on the ground. The fixed-step simulation owns the roll; the tumble only shows it.

## Consequences

- The roll is a strong escape: shots pass through for all of its 0.45 s, and only the cooldown limits how often it can be used. The guard's committed bursts, its injury limit and the tower's cover were tuned without it, so the fight's balance needs a playtest.
- Companions neither roll nor gain protection from the leader's roll.
- Square / X, Space and the bottom row left of Fire are now taken.

## Verification

Recorded in the prototype plan under [Pawns and dodge roll](../bridge-prototype-plan.md#pawns-and-dodge-roll).
