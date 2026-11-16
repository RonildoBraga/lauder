# Lauder — gameplay walkthrough

**Status:** Previous solo walkthrough, awaiting the ensemble rewrite. The [story bible, draft 0.4](story/story-bible.md) supersedes its family assumptions and specifies three characters travelling together with switchable leadership and distinct skills. The solo trip, stationary Tomas and remote Lara below are retained as earlier mechanics/script reference, not the current party proposal. The [prototype plan](prototype-plan.md) also needs replanning before gameplay implementation resumes; new dialogue and menus below remain unapproved proposals.

## The game we are building

You play Miki, travelling with her father toward a reunion with her daughter Nina. Nina went ahead with Lara, Miki's trusted friend, under a family plan. Their separation is practical and temporary. Miki is widowed; her husband's death remains unexplained. Tomas is the working name for her own father.

Their world is a ruined future. Advanced utilities survive among damaged buildings, stripped vehicles and places people still maintain. The full cause of the collapse remains uncertain. Miki's useful knowledge is local and practical: she notices a connection, checks a marking and asks who still depends on a machine before taking it apart.

The experience centres on exploration and purposeful salvage: understand a problem, read the place, find something useful, make a repair and gain a concrete step toward home. Survival gives those decisions weight. Light combat belongs to the broader vision, alongside opportunities to observe and avoid danger. Later mechanics should earn their place one at a time.

## What exists, and what this walkthrough proposes

The current build lets Miki walk the route, collide with obstacles, use the service passage, inspect nearby landmarks and pause. Actions display observations. Collection, mission dialogue, repair, the family call, completion, Read plan and Restart are still planned.

The proposed playable aims for roughly **3–5 minutes**, including short conversations. It begins at Relay House, after the opening home departure and bridge closure. The longer Chapter One security-machine encounter and historical clues remain outside this slice. There is no countdown, hunger depletion, health system or combat here. Tomas stays at the shelter; he needs no movement or pathfinding.

Gray and coloured primitives are sufficient to agree on this experience. Use neutral ground, darker solid obstacles and restrained teal/blue utility markers; identify interactions with text as well as colour. A small amber indicator can communicate restored power without becoming a general “collect everything glowing” rule. These presentation choices are proposals. No downloaded art, engine change or required sound pass is needed.

## 1. A reason to leave the shelter

Miki starts beside the relay shelter. Tomas and the transmitter are visible nearby; the route leads away toward the depot. Approaching Tomas offers **Talk**. The player uses Cross on PS5, A on Xbox, or E during Simulator testing.

The conversation establishes three facts: their crossing is closed, they lack water for the long detour, and the relay can receive but cannot answer Lara and Nina. Tomas points out where compatible equipment used to be.

**Proposed condensed dialogue:**

> **Tomas:** The depot used emergency sets like this. Check what's left.
>
> **Miki:** I'll check the markings before I bring anything back.

The objective becomes **Find a compatible regulator at the depot**. Tomas remains useful through preparing the repair test and gathering route information, rather than following Miki around.

## 2. Read the street

The player walks Miki between the shelter and depot, using the left stick or WASD. The elevated camera follows without rotating. A wreck and fallen panel make the district feel damaged, while the open walking surface remains easy to read.

The pleasure should come from recognising a place and choosing a route through it. The player need not search every corner or collect unrelated scrap. A glance back should make the shelter recognisable for the return journey.

## 3. Find another entrance

The depot's front entrance is visibly blocked. Walking into the obstruction stops Miki without damage or a failure screen. Looking along the wall reveals the existing service opening and its simple markers.

The player goes around and enters using ordinary movement. Finding the passage changes their understanding of the space. It does not ask for another key or fetch task. The opening must be readable without a developer explaining where to go.

## 4. Take something with a purpose

Inside the depot, one equipment housing contains the regulator. Near an accessible side, the prompt becomes **Take regulator**. Miki's brief text confirms that its markings match the relay's needs; this stands in for the chapter's longer inspection and removal sequence.

Pressing the action takes the part once. It disappears from the housing, a small carried-part indicator appears, and the objective becomes **Return to Relay House**. Pressing again cannot award another part. From outside the wall, the player cannot take it merely because the object is close.

## 5. Make the return matter

Miki retraces the route. The space is familiar now, and the carried regulator gives the trip a clear purpose. There is no surprise enemy wave or second component requirement.

At the transmitter, the prompt becomes **Repair**. One action completes this first repair: the regulator leaves the carried-part indicator and the equipment gains a visible **Ready** status. A small indicator changes; an optional sound may reinforce it, but text and the visible change must work alone.

Trying earlier without the part gives a short explanation, such as **A compatible regulator is still needed**, and changes nothing. Repeating Repair after success cannot consume the part again. The new prompt is **Call**.

## 6. Hear the people the journey is for

The player starts the call at the repaired transmitter. Short, speaker-labelled text brings Lara and Nina into the scene without adding physical characters, portraits or voice acting. The action advances each line; the player controls the reading pace.

The exchange confirms that Lara and Nina are safe at the coastal refuge. Miki and Tomas contribute current information from their side. Lara agrees to meet them at Old Lock with the water crew; Nina remains at the refuge.

**Proposed condensed lines:**

> **Lara:** Old Lock, tomorrow afternoon. I'll come with the water crew.
>
> **Nina:** Grandad, did you bring my cup?
>
> **Tomas:** In my bag.
>
> **Nina:** Mum, there's a place for your bag beside mine.

The cup and the space for Miki's bag connect the useful repair to an ordinary family relationship. The call secures a meeting plan; the actual reunion lies ahead.

## 7. Finish, reread, try again

Completion states what changed: **Transmitter restored. Meeting agreed at Old Lock.** The player can keep walking. The transmitter now offers **Read plan**, which repeats the meeting details without restarting the call or awarding progress again.

Options/Menu or Escape opens Pause. The proposed pause menu offers Resume and Restart; selection uses the stick or W/S, with the action input to confirm. Restart asks for confirmation, then returns Miki, the regulator and the transmitter to the beginning of this run. There are no clickable screen actions. This menu and Restart are proposed, not current features.

Pause freezes world movement and world interactions; menu navigation and confirmation remain available. Returning from pause or interruption requires released controls before fresh movement is accepted. Stepping away from an interaction must prevent a stale prompt from repairing or collecting at a distance. A fresh launch starts a fresh run; checkpoints are later work.

## Questions to settle before building the loop

- Does observing the service entrance and returning with one useful part feel satisfying without combat or a timer?
- Does this short briefing and family call explain the purpose without slowing the walk excessively?
- Are one carried-part indicator, a visible repair change and the proposed Pause/Restart menu enough feedback?

After a first playtest, ask whether the player knew why they were leaving, found the passage without coaching and cared more about the repair after the call. Let those answers guide the next single addition, rather than treating more mechanics or finished art as the solution in advance.
