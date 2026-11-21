# ADR 0006 — A first salvage and exploration experiment

**Status:** Accepted; amended after the first session\
**Date:** 21 November 2026

## Context

The combat experiment of [ADR 0005](0005-squad-combat-experiment.md) has had its three sessions, each of which the maintainer reported as working. Combat now has a greybox venue, companions who fight as a squad and a full set of positioning rules. The game has very little of what the maintainer's goals put first, **“Occasional combat; exploration and salvage lead”**: the opening offers one body to search and one medical kit.

The story bible records the agreed direction:
- **What leads:** “Exploration, purposeful salvage and survival lead the experience.”
- **What each member brings:**
  - Miki has systems knowledge, inspection and careful salvage.
  - Laura has agility, balance and the reading of a route.
  - Tom has strength, controlled load handling and delivery knowledge.
- **How leadership should create decisions:**
  - favour readable alternatives;
  - avoid “three obstacles each labelled for a different character”;
  - let a specialist opening admit the whole party;
  - represent actions simply, “not free climbing or a physics lifting system”.
- **What gives salvage its purpose:** water, warmth, load and reliable information, “without requiring a meter for every bodily need”.
- **A worked example:** its [Relay House scene](../story/story-bible.md#later-scene--relay-house) is a salvage trip of this kind.
  - Laura reaches a release latch, or Tom shifts a loose panel, and either opens the depot to everyone.
  - Miki identifies a compatible regulator and leaves a live supply that someone still uses connected.

The prototype plan keeps separate character inventories, health and hunger systems, and crafting outside the first playable.

On 21 November 2026 the maintainer chose salvage and exploration as the next track, “Salvage and exploration (Recommended)”, and settled the four choices that most shape a first experiment:

| Question | The maintainer's choice |
|---|---|
| Where the experiment runs | **“A test yard”** |
| What the salvage is for | **“A part for a repair”** |
| How each member helps | **“Alternative approaches”** |
| How the party carries what it finds | **“Shared bag only”** |

Each was the recommended option. Asked to build the experiment with the defaults offered alongside them, the maintainer answered **“Yes, build it”**:
- no hostiles in the salvage yard;
- the pause menu's choice for other levels naming the next in a cycle;
- Miki unable to open the gate herself, with the HUD naming who could;
- nobody opening the live cabinet;
- at most three focused sessions.

This record turns them into one experiment, whose details play will tune.

## Decision

### 1. A salvage yard, outside the story

The experiment runs in a greybox salvage yard, a level of its own that the story never reaches, built from plain shapes and colours under the bridge's camera and lights. It holds:
- a broken transmitter in a shelter at the entrance;
- a fenced depot whose front is blocked, with a service gate in its fence;
- three equipment cabinets inside;
- the whole trio, already recruited.

There are no hostiles: this repair needs no fight.

**Reaching it:** the pause menu keeps one choice for the other levels, which now names the next in a cycle. On the bridge it reads **Combat test**. In the combat yard it reads **Salvage test**. In the salvage yard it reads **Bridge**. No new button is needed on touch, and Restart in the yard starts the yard again.

### 2. A part for a repair

The transmitter needs a regulator, and the three cabinets each hold one:
- **The right one:** a compatible regulator in disconnected equipment.
- **The wrong model:** a regulator of a different model, which will not fit.
- **The live one:** a compatible regulator in equipment that still feeds a neighbouring shelter. It stays connected for everyone. As in the Relay House scene, this is ordinary salvage judgement, not a branching choice.

Fitting the right regulator at the transmitter completes the repair, and the HUD says so. Fitting the wrong model fails with a line saying so, and the party can go back for another.

### 3. Alternative approaches

No step needs one particular member, but each member makes some step better. Each action is a contextual action for whoever leads, in an approach area, through the action button.

- **The service gate** opens in either of two ways, and either way it opens for everyone:
  - **Laura** reaches its release latch from the fence's ledge.
  - **Tom** shifts a loose panel beside it.
  - **Miki** cannot open it. While she leads there, the HUD says who could, such as “Laura could reach the latch.”
- **The cabinets:**
  - **Miki** inspects each one and learns which holds the right regulator, which holds the wrong model and which is live, then takes the right one.
  - **Anyone else** can search a cabinet and take its regulator without knowing which it is, but nobody opens the live one.
  - So without Miki, the party may carry the wrong model to the transmitter and have to go back.

### 4. The shared bag

A regulator goes into the party's shared inventory, as rounds and medical kits do. It has no weight, and nobody has to carry it. The HUD's panel lists what the bag holds.

## How the experiment is judged

Scripted Simulator playtests come first. Then the maintainer plays it on the baseline iPhone 13 Pro Max, with touch and the PS5 controller, over at most three focused sessions. These questions decide it:
- From the camera, is it clear where to go and who can do what?
- Does switching leader follow the player's reading of the place, rather than a checklist?
- Do Miki's inspection and the wrong model make the search satisfying rather than a chore?
- Does the trip feel purposeful without any meters?
- Does the yard hold 60 fps?

## After the first session

On build 0.1.0 (16), asked how the salvage yard played, the maintainer answered **“Yes it went well”**. It was not instrumented, so the yard's frame rate on the phone has not been measured. Two of the three sessions remain.

Asked what the second session should try, the maintainer chose **“Shuffle the cabinets (Recommended)”**.
- **What changes:** each run, Restart included, deals the right regulator, the wrong model and the live equipment to the three cabinets in a random order. Miki's inspection matters every time, instead of being memorised after one run.
- **Playtests:** scripted playtests find each cabinet by what it holds in their run.

The second session judges it with the questions above.

## After Claude's Simulator playtest

On 21 November 2026, instead of playing build 0.1.0 (17) on the phone, the maintainer asked Claude to play it: **“instead of asking me, can you test on the simulator and let me know what you think ?”**. Claude played three runs by touch in the Simulator. It opened the gate both ways, searched blind and fitted the wrong model once. The deal differed in each run and the rules held, but the yard did not explain itself from the camera: nearly everything came as a line that left the panel after 6 seconds.
- **The gate:** the same grey as the fence, so the way in did not show, and opening it made it vanish, although the line said it swings open.
- **The latch and the panel:** nothing marked them, so their prompts appeared only on an unmarked spot.
- **The transmitter:** a plain grey block, smaller than the cabinets, which only Look named. A leader coming back from the depot stood behind it, nearly hidden and short of its prompt.
- **The cabinets:** an inspected cabinet looked as before, so what it held had to be remembered.
- **The wrong model:** after a failed fit the bag still read “a regulator” and Fit stayed offered, and a blind search's line did not say that only Miki could tell the model.
- **The touch button:** “Take the regulator” and “Fit the regulator” were cut off.

Asked **“Merge the shuffle and fix these clarity problems next?”**, the maintainer answered **“Yes, do both”**. With plain shapes in the palette's colours:
- **The gate** is rust, like the world's other barriers, and swings open into the depot over a moment, where it stands as a thin wall.
- **The latch,** high on the fence beside the gate, and **the loose panel** on its other side show in amber, as things to use, until the gate opens.
- **The transmitter** is lower, faded teal under ink aerials, and turns amber once repaired. Its approach reaches back towards the depot.
- **A cabinet the party knows** wears a tag on its top: amber for the right regulator, stone for the wrong model and rust for the live equipment. An emptied cabinet turns ink.
- **The bag** names a regulator known to be of a different model. Fit is offered only while a regulator in the bag might fit, and otherwise Look at the transmitter says “Miki could tell the models apart.”
- **Once the party knows a cabinet,** anyone takes the right regulator from it, and nobody takes the wrong model.
- **A blind search** says so, such as “Tom takes a regulator, but only Miki can tell its model.”
- **The touch labels** read **Take regulator** and **Fit regulator**.

The second session judges the yard with these changes, on the questions above.

## After the second session

On build 0.1.0 (18), with those changes, asked **“How did the salvage yard play on build 18?”**, the maintainer answered **“It reads well”**. That answers the first question, whether it is clear from the camera where to go and who can do what. Switching, the search, the trip's purpose and the frame rate were not asked about, and the session was not instrumented, so the yard's frame rate on the phone is still unmeasured. One of the three sessions remains.

Asked what that last session should cover, the maintainer chose **“The other questions”**: build 18 again, judged on switching, the search and the trip's purpose. Measuring its frame rate needs the phone connected to the Mac.

## Options considered

- **Venue:**
  - Salvage on the bridge would change the opening that ADR 0004 settled.
- **Purpose:**
  - Fuel and water as counts would bring the story's survival pressure, but come close to the health and hunger systems the plan leaves out.
  - Both a part and supplies would test two things at once.
- **Leadership:**
  - Letting anyone do anything at a cost would blur what each member brings.
  - Offering each action only to its specialist would make switching a checklist.
- **Load:**
  - One heavy item, or a load limit, would test carrying before searching does.

## What this does not settle

- **Not settled here:**
  - fuel, water and warmth as resources;
  - heavy items and load limits;
  - hazards to read, such as thin ice off the buried road;
  - salvage on the bridge or in the story, and where the Relay House scene falls;
  - more kinds of equipment and parts;
  - persistence across a saved game.
- **Answered by evidence:** the experiment's results decide which of them come next.
