# ADR 0005 — A first squad combat experiment

**Status:** Accepted; amended after the first and second sessions; its three sessions are done\
**Date:** 21 November 2026


**Retired implementation:** The bridge-only reset removed this experiment and its dedicated runtime. This record preserves the assignment, decisions and historical delivery evidence; it is not current playable scope. See [ADR 0017](0017-bridge-only-reset.md) and the current [architecture](../architecture.md).

## Context

The first playable is complete. Its fights are deliberately small ([ADR 0004](0004-brooklyn-bridge-opening.md)):
- Only Miki fires, with assisted aim.
- Enemies shoot only the leader, and become targets after their first shot.
- A third hit restarts the fight with everything restored.
- Companions neither fire nor take hits.
- Since the snow buried the bridge, its towers' piers are the only cover.

The maintainer's goals stand:
- **“Occasional combat; exploration and salvage lead”**.
- Companions who **“behave like a coordinated squad of soldiers rather than just following the player”**, with **“simple controls that still provide meaningful tactical depth”**.

The prototype plan's [combat design review gate](../bridge-prototype-plan.md#combat-design-review-gate) asks that the open design choices be settled with the maintainer before any combat beyond the opening. A bounded greybox experiment then needs its own assignment.

The working design is in three places: the characters' [combat identities](../story/story-bible.md#combat-identities), the [future squad and combat design](https://github.com/RonildoBraga/lauder/blob/milestone/bridge-main-2026-11-28/docs/gameplay-script.md#future-squad-and-combat-design) and [The Quiet Yard](../encounters/the-quiet-yard.md). Several questions there were still open, among them four from the 17 November review of that design: how signatures work, switching leader under pressure, the failure rule and the input budget. On 21 November 2026, after choosing the combat design review as the next track, the maintainer settled the four that most shape a first experiment:

| Question | The maintainer's choice |
|---|---|
| How companions position themselves | **“Slots and orders”** |
| Whether companions fire by themselves | **“Automatic”** |
| What a third hit does | **“Fall back, keep damage”** |
| Which signatures the first experiment has | **“Disrupt only”** |

Each was the recommended option. The defaults offered alongside them drew no objection: a separate test yard, two of today's shooters able to target anyone, a Signature button and a Previous button, ammunition for the leader only, and three focused sessions. This record turns them into one experiment.

## Decision

### 1. A test yard, outside the story

The experiment runs in a greybox test yard, a level of its own that the story never reaches. It holds:
- one full-height wall;
- two small blocks;
- the whole trio, already recruited.

All of it fits inside the roughly 19 m the bridge's camera shows ahead, under the same camera, light and look.

A launch switch cannot reach the yard on a phone that installed the game from TestFlight. So while the experiment lasts, the pause menu offers a third choice, **Combat test**, beside Resume and Restart. Restart in the yard starts the yard again.

### 2. Two shooters that can target anyone

Two hostiles of today's shooter type stand in the yard: a telegraphed shot with a wind-up of about 1.5 s, then a recovery. The experiment changes them in two ways:
- **Any target:** each aims at any party member in clear sight within its reach, not only the leader.
- **Targets from the start:** each becomes a target from its first wind-up, so a first shot can be answered.

### 3. Companions fire by themselves

Once a fight is under way, each companion fires by themselves at their own assisted target, in clear sight and within reach:
- Laura uses a light burst weapon.
- Tom uses a close scatter weapon.

Their starting values are set in the experiment and tuned in play. Companions never start a fight. A fight is under way once a hostile begins a wind-up or the leader fires.

### 4. Everyone can be hit; a third hit falls the party back

Every member can take three hits, each shown beside their name. A third hit on anyone fades the screen, and then:
- the whole party falls back to the yard's entrance, with their hits restored;
- the hostiles keep the damage dealt;
- nobody is lost.

This follows The Quiet Yard's rule, without the persistence across a saved game that it would need later.

### 5. Positioning: slots and orders

Companions fight from their formation slots, or from the points that squad orders send them to (ADR 0003, phase S3). They do not seek cover by themselves: ADR 0003's [combat positioning](0003-squad-movement.md#combat-positioning), phase S4, waits for evidence from this experiment. The first session gave it: companions now take cover near those places ([after the first session](#after-the-first-session)).

### 6. Disrupt, Miki's signature

While Miki leads, a hostile's wind-up within reach and in her clear sight can be answered by **Disrupt**. Disrupt cancels that shot, and the hostile recovers before it can try again.
- **When it can be used:** only the leader uses a signature. The HUD shows **Miki can Disrupt** while an answer is possible.
- **When someone else leads:** the player switches to Miki first.
- **Left out:** Reposition and Brace.

### 7. Input

| Intent | PS5 / Xbox | Touch | Keyboard |
|---|---|---|---|
| Signature | Square / X | A **Signature** button, shown in a fight | A key of its own |
| Previous leader | L1 / LB | None: **Next** cycles | A key of its own |

Every other control stays as the [input contract](../bridge-prototype-plan.md#input-and-interaction-contract) has it. Tapping a companion's name to lead is left out. Both new intents go through InputRules, and session authority and command priority hold as before.

### 8. Ammunition

Only the leader's carbine uses the one ammunition count. Companions' weapons spend none. The yard starts with enough rounds that ammunition does not decide the experiment.

## How the experiment is judged

Scripted Simulator playtests come first. Then the maintainer plays it on the baseline iPhone 13 Pro Max, with touch and the PS5 controller, over at most three focused sessions. These questions decide it:
- Can whoever leads switch to Miki and Disrupt within a 1.5 s telegraph?
- Do companions placed by orders survive and help?
- From the 65 m camera, is it clear who fires, who is exposed and who can answer?
- Does the yard hold 60 fps?
- Does the maintainer want companions to seek cover by themselves? A yes is the evidence for S4.

## After the first session

On 21 November 2026, asked how the first session in the combat yard went on TestFlight build 0.1.0 (12), the maintainer answered **“Everything worked as expected”**. Asked whether companions should take cover by themselves next, the maintainer answered **“Yes, try cover next”**: the evidence for S4 that this record asks for.

So the yard now tries the first part of ADR 0003's [combat positioning](0003-squad-movement.md#combat-positioning), cover near the slot:
- **Where:** once a fight is under way, each companion weighs the spots within about 1.5 m of their place in Close and Column, or 2.5 m in Spread. Their place is their formation slot, or the point an order keeps them to, so orders still win.
- **What a spot scores for:** being hidden from the shooters, the most dangerous first; a firing position within a metre; being near the place; and a way there that the shooters cannot see. Keeping to the place is weighed too, so that in the open a companion follows as before.
- **Commitment:** a companion keeps a choice for at least two seconds.
- **Firing:** from a spot, a companion steps out to its firing position while a target is in sight from there, and back into cover while a shooter's wind-up aims at them. The telegraph counts for companions too.
- **Left out:** the rest of S4, which is the personality weights, sight-aware routes and Regroup. The opening keeps its rules.

The second session judges it, with the questions above and two more:
- Do companions in cover look like a coordinated squad?
- Does cover make the fights too safe?

On build 0.1.0 (13), asked how companions taking cover played in the combat yard, the maintainer answered **“Worked well”**. One of the three sessions remains.

## After the second session

Asked whether the third session should finish the rest of S4 in the yard, the maintainer answered **“Yes, finish S4”**. So the yard now has all of ADR 0003's [combat positioning](0003-squad-movement.md#combat-positioning):
- **Each member's preference** weighs their choice of cover, but never outweighs being hidden. Their place, from the formation or an order, still bounds the choice:
  - Miki likes 6 to 10 m between her firing position and her target;
  - Laura likes to stand, or step out to fire, off the most dangerous threat's facing;
  - Tom likes to stand between a close threat and the teammate nearest it.
- **Sight-aware routes:** in a fight, ground the shooters see costs four times as much to cross. A companion takes no straight way of more than 1.5 m across it while the grid offers another. Sight is the game's own, the same straight line against the blockers' footprints as for shots: The Quiet Yard's proposal that low barriers block only movement is not used.
- **Regroup:** in a yard fight, the formation button reads **Regroup**, so the formation can only be changed outside a fight.
  - **What it does:** it clears any orders, and the companions leave cover and firing positions, hold their fire and come back to the formation on sight-aware routes.
  - **When it ends:** once both are within a metre of their places in the formation, when a new order is given, or when the fight ends. Then they take cover near those places again.
  - **Not to be confused with** ADR 0003's regroup option for a stuck companion, which would move them to a safe point and stays unbuilt.

The third session judges it, with the questions above and two more:
- Does Regroup bring the companions back when they are needed?
- Do they keep out of the shooters' sight on the move?

## After the third session

On build 0.1.0 (15), asked how the rest of S4 played in the combat yard, the maintainer answered **“Worked well”**. That was the last of the experiment's three sessions. None of them was instrumented, so the yard's frame rate on the phone has not been measured. What comes next, from what this record leaves unsettled, needs the maintainer's decision.

## Options considered

- **Venue:**
  - A greybox Quiet Yard would also need patrols, noticing, a perimeter and retreat.
  - A fight on the bridge would change the opening.
- **Positioning:**
  - Cover near the slot.
  - The full S4.
  - Both would build movement before play shows it is needed.
- **Companions' fire:**
  - Automatic, with a hold-fire command, costs a button.
  - Firing only while the leader fires makes the party less like a squad.
- **Hits:**
  - A retry for everyone reuses what is built, but cannot test falling back.
  - Hits on the leader only would make positioning risk-free.
- **Signatures:**
  - Brace needs an enemy that charges and strikes.
  - Reposition needs a way to choose her destination on stick and touch, the costliest unknown.

## What this does not settle

- **Not settled here:**
  - S4 outside the combat yard;
  - Reposition and Brace;
  - chargers that strike;
  - patrols, noticing and a perimeter;
  - an ammunition economy;
  - persistence across a saved game;
  - how often fights happen and whether any is required.
- **Answered by evidence:** the experiment's results decide which of them come next.
- **Nothing is assigned yet:** building the experiment needs the maintainer's explicit assignment.
