# ADR 0005 — A first squad combat experiment

**Status:** Accepted\
**Date:** 21 November 2026

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

The prototype plan's [combat design review gate](../prototype-plan.md#combat-design-review-gate) asks that the open design choices be settled with the maintainer before any combat beyond the opening. A bounded greybox experiment then needs its own assignment.

The working design is in three places: the characters' [combat identities](../story/story-bible.md#combat-identities), the [future squad and combat design](../gameplay-script.md#future-squad-and-combat-design) and [The Quiet Yard](../encounters/the-quiet-yard.md). Several questions there were still open, among them four from the 17 November review of that design: how signatures work, switching leader under pressure, the failure rule and the input budget. On 21 November 2026, after choosing the combat design review as the next track, the maintainer settled the four that most shape a first experiment:

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

Companions fight from their formation slots, or from the points that squad orders send them to (ADR 0003, phase S3). They do not seek cover by themselves: ADR 0003's [combat positioning](0003-squad-movement.md#combat-positioning), phase S4, waits for evidence from this experiment.

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

Every other control stays as the [input contract](../prototype-plan.md#input-and-interaction-contract) has it. Tapping a companion's name to lead is left out. Both new intents go through InputRules, and session authority and command priority hold as before.

### 8. Ammunition

Only the leader's carbine uses the one ammunition count. Companions' weapons spend none. The yard starts with enough rounds that ammunition does not decide the experiment.

## How the experiment is judged

Scripted Simulator playtests come first. Then the maintainer plays it on the baseline iPhone 13 Pro Max, with touch and the PS5 controller, over at most three focused sessions. These questions decide it:
- Can whoever leads switch to Miki and Disrupt within a 1.5 s telegraph?
- Do companions placed by orders survive and help?
- From the 65 m camera, is it clear who fires, who is exposed and who can answer?
- Does the yard hold 60 fps?
- Does the maintainer want companions to seek cover by themselves? A yes is the evidence for S4.

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
  - companions seeking cover (S4);
  - Reposition and Brace;
  - chargers that strike;
  - patrols, noticing and a perimeter;
  - Regroup;
  - an ammunition economy;
  - persistence across a saved game;
  - how often fights happen and whether any is required.
- **Answered by evidence:** the experiment's results decide which of them come next.
- **Nothing is assigned yet:** building the experiment needs the maintainer's explicit assignment.
