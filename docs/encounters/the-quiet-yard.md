# The Quiet Yard

**Date:** 17 November 2026\
**Status:** Proposed encounter for design review, not implemented or assigned for implementation. The character definitions it uses are agreed; the encounter itself remains a proposal, a future exercise beyond the opening.

Read the proposed [combat identities](../story/story-bible.md#combat-identities), the current [gameplay walkthrough](../gameplay-script.md) and the [combat design review gate](../prototype-plan.md#combat-design-review-gate) alongside this scene. Character histories, final dialogue, control bindings and combat tuning remain proposals. Miki's later [sniper rifle-family direction](../story/story-bible.md#sniper-rifle-family) applies to her combat identity, with one chosen rifle at a time. The example below does not require a particular variant or settle its range, cadence or equipment flow.

## Place in the journey

The community transmitter is restored. The trio is travelling towards its appointment with the coastal water crew at Old Lock. Beside the canal towpath, a maintenance yard contains a small case of filter seals that could help the crew keep older pumps running.

The seals are useful, optional salvage. The safe towpath detour remains available throughout: leaving the case behind does not block the journey, cancel the meeting or make the repair fail. There is no hidden requirement to fight here.

The yard contains two old security units of the same type. Their patrol is visible from the approach. Each can prepare a clearly telegraphed shot at range or advance on a nearby threat; neither has a surprise second form or a special counter requiring a particular character.

A solid service wall interrupts both sight and gunfire. A parked van supplies a landmark, but the wall is the reliable cover in this proposal. Each blocker needs a stated rule for sight and fire, because movement collision uses footprints without height. Proposed: full-height blockers such as the service wall block both; low barriers block movement only. The van is full height but short, so it hides a body from one direction only. The elevated camera sees over all of them. The covered route is wide enough for all three bodies, including companions changing position. The entrance gate stays open for the entire encounter. No ability is needed to open an escape route.

## 1. Read the place before committing

The party reaches the covered approach. One unit crosses a strip of sunlight; the other turns at a faded service boundary. Their movement and shot preparation can be understood from the elevated camera without tiny markings or a diagnostic overlay.

> **Security unit:** Evacuation clearance required.
>
> **Tom:** Those seals fit the older pumps.
>
> **Laura:** There’s a way around the yard.
>
> **Miki:** We can leave them. Let’s look first.

The player can continue along the towpath immediately, watch a patrol cycle from safety or enter the covered route. Companions do not start a fight because a unit is nearby. They follow the chosen approach, leave room to reverse and avoid exposing themselves merely to fill a formation slot.

The same detection rules apply to every party member. A visible companion can be noticed just as the leader can; switching does not make anyone disappear from a unit's attention. The layout and spacing must make the covered route credible for the whole party. This is observation and route choice, not a separate stealth minigame with crouching, noise meters or precision timing.

When a unit notices someone, its warning and preparation give the player a clear chance to back away behind the wall. The encounter must not require being hit to learn that the yard is guarded.

## 2. Leave, or cross without fighting

**Leave the yard:** The player takes the towpath detour. Both companions come along without firing. The case stays where it is; the party's journey continues.

**Try for the seals quietly:** The player waits for a readable opening, then moves along the protected route.

> **Laura:** Past the van, then behind that wall. There’s room for all of us.

The player need not press a formation button to fit through the route. Companions temporarily compress their spacing when necessary, then settle into nearby clear positions. They do not copy every footstep or wander into sight to maintain an exact triangle. The crossing window must be broad enough for the whole party, not only the leader.

At the case, the player switches to Miki and approaches to inspect the seals and confirm that they are usable before taking them. This is her salvage contribution, not a combat lock or a remote action by a companion elsewhere. The inspection and pickup are readable contextual actions; the player does not manually target individual seals or tiny machine components.

If a warning starts before the case is collected, retreat remains valid. If the party is noticed after collection, the seals remain theirs while they leave. Quiet collection is one possible outcome, not a promised result regardless of where the other bodies stand.

## 3. Fight for room to move

The player can choose to engage or defend after a warning. All three have usable primary weapons; companions handle ordinary defensive fire automatically once combat is under way. They avoid initiating the encounter and do not chase a target out of the party's useful area.

In this proposed experiment, only the character actively controlled by the player uses a signature ability. Switching offers another tactical option; companions do not secretly spend those abilities off screen.

One possible sequence shows how the identities complement each other:

- **Miki — Disrupt:** With her chosen rifle from a useful mid-range position, interrupt one unit during its shot preparation. It cancels **one** winding-up shot, creating a short movement opportunity. It does not switch off both units, grant permanent control or erase shots already fired.

  > **Miki:** Move now.

- **Laura — Reposition:** While that unit faces elsewhere, dash to a nearby reachable angle with a clear shot, quickly enough to leave the line of a shot already aimed at her. The destination is visible and unobstructed; this is not a teleport through the wall or a long dash into another encounter.

  > **Laura:** Going left.

- **Tom — Brace:** Meet a unit's close advance with a braced scatter-weapon blast, stopping that approach long enough to protect the route back to the gate. He holds useful space rather than becoming invulnerable or drawing every enemy automatically.

  > **Tom:** Gate’s clear. Your choice.

This is an illustrative sequence, **not a required Miki → Laura → Tom combo**. Any leader must offer a viable way to engage, collect the seals or disengage with help from the other two. A player can remain with a preferred character, use cover and ordinary fire, or retreat without using all three abilities. No unit is immune until a designated specialist acts.

The tactical decision is where to stand and when to move, interrupt, hold or leave. Assisted aiming should support that decision on a phone; repeatedly selecting tiny body parts is not part of the proposal. Each unit's wind-up lasts long enough for the player to switch to Miki and Disrupt it, and the HUD names who can answer it.

## 4. Break contact

Moving back towards the covered exit is enough to begin leaving. A proposed **Regroup** order can make that intention explicit: companions abandon attempts to finish a target, prioritise the exit and stay with the controlled character. They can defend the withdrawal without resuming a chase.

The service wall supplies real protection. The clearly marked guard perimeter explains why the units do not pursue along the towpath. Both matter: crossing an invisible line must not make an exposed party invulnerable. Shots already in flight behave normally, and every member must actually reach cover and leave the guarded area.

The gate never closes behind the party. There is no extra wave, dropped-salvage penalty or loot punishment for backing out. Collected seals remain with the party. If the player returns during the same run, damage already dealt to the units remains; retreat does not secretly restore them and demand the fight again. That damage and the collected seals are encounter state that must survive leaving the area, so the save and Restart design must include them when the encounter is assigned.

Once the whole party is safely clear:

> **Laura:** Everyone?
>
> **Tom:** Here.
>
> **Miki:** We keep going.

## 5. Carry a small question forward

Whether they collected the seals, fought or took the detour, the trio passes a recently repaired water pipe beyond the yard. The repair has been made with care using different fittings from the original installation.

> **Tom:** Someone’s still maintaining this.
>
> **Miki:** Then someone still needs it.

This is a local sign of continuing human work. The security warning and repair do not explain the global collapse, establish that an AI caused it or reveal a character's hidden biography. The player leaves with a question about who is still here and what they are sustaining.

## Placeholder hit rule

Health is not designed yet. So that exposure and retreat can be tested, the first experiment uses a deliberately simple rule, to be replaced:

- Each character can take three hits, shown beside their name. Hits do not slow anyone.
- When any character takes a third hit, the whole party falls back together to the yard entrance after a short fade. Nobody dies, is left behind or needs carrying. This is a short reset of the encounter, not a regroup by the following system.
- Collected seals and damage dealt to the units remain. Hits recover once the party is outside the guarded area.
- Because companions can be hit, their exposure must follow the player's choice of formation and position. The movement design has to keep companions in the cover the player chose.

## What this proposal should test

- Can a player understand the optional salvage and safe detour before entering? Does leaving feel like a valid choice?
- Can all three use the covered route under the same sight and collision rules, without managing every companion or forcing a formation change?
- Do Disrupt, Reposition and Brace suggest different decisions while every leader remains viable? Is ordinary companion defence useful without stealing control or starting a fight?
- Is the warning readable enough to permit backing off? Does retreat work after either collecting the seals or damaging a unit, without a chase restarting?
- Can the player read the threat, cover, destination and party on a phone while using assisted aim and a small number of inputs?
- Is switching to the right person under a telegraph quick enough on a phone, and does the HUD cue make the choice clear?
- Does the placeholder hit rule make exposure matter without making a retreat feel like a failure?

Formations and squad orders are built ([ADR 0003](../decisions/0003-squad-movement.md), phases S2 and S3). Regroup and the signature button remain proposed controls, not settled bindings; the gameplay script's [proposed input budget](../gameplay-script.md#future-squad-and-combat-design) is the starting point. Their design should serve these decisions rather than require a control for every behaviour. Beyond the placeholder hit rule, health, ammunition, cooldown, upgrade and enhancement-resource systems are not settled by this screenplay. No implementation, build, device run or performance result is claimed.
