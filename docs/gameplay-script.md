# Lauder — gameplay walkthrough

**Date:** 17 November 2026\
**Status:** Three-character walkthrough, with Party A implementation assigned regardless of Claude's response. The [Party A record](party-a.md) tracks actual checks. Biographies, dialogue and B/C interactions remain working proposals from the [story bible](story/story-bible.md). The [prototype plan](prototype-plan.md) defines staged checks; the [Chapter One index](story/chapter-01.md) points to the current outline.

The maintainer has endorsed the occasional-combat direction and assigned the [combat-role and Quiet Yard documentation](#future-squad-and-combat-design) for Claude's review before implementation. That separate design gate does not extend the earlier Party A implementation assignment.

## The game we are building

One human player directs three characters travelling together. The selected character leads; the other two follow through the same physical world. Switching changes who the player controls, not the group's progress, belongings or relationships.

The proposed trio is Miki, who understands systems and careful salvage; Lara, who is agile and reads access routes; and Tomas, whose strength and load-handling experience offer another approach. Their abilities are understandable before the player knows their histories. Internal synthetic replacements and biological changes belong to the world, but this slice needs no medical exposition or visible machinery in anyone's body.

They are crossing a ruined future in which safe water, maintained equipment and current route information matter. Their immediate reasons to cooperate are clear. Miki wants a viable route to the coastal settlement; Lara needs contact with its water crew. Tomas needs to reach the coastal supply team to arrange the next inland deliveries. Meeting that crew at Old Lock gives him an onward route and people with whom to make those arrangements. Their deeper connections emerge through what they recognise and choose to do.

This walkthrough starts at Relay House after the East Span closure. The party restores its transmitter by recovering one regulator from the nearby depot, then makes a concrete onward plan. The trip tests exploration, switching and cooperation without combat, a timer or survival meters. Its duration will be measured once the party can actually play the route; the earlier solo 3–5 minute estimate is not a party target.

## What exists today

The Party A branch introduces three primitive stand-ins, session-owned leadership/Pause, Q/R1/RB cycling, collision-checked trail following and an eased camera target. Observations remain the only action. Skill interactions, collection, repair, mission dialogue, completion and Restart are not included. See the session record for actual verification.

The accepted sequence is: **party movement and switching → one shared access problem → salvage, repair and contact**. Party A is assigned; the old solo Stage 3 is superseded. Add later stages only after the party movement checkpoint is established.

## Readable controls and party feedback

The following mappings are the initial planning defaults, to verify during Party A alongside the existing movement/action/pause inputs:

| Intent | PS5 | Xbox | Simulator keyboard |
|---|---|---|---|
| Move the leader | Left stick | Left stick | WASD |
| Act / advance a line / confirm a menu choice | Cross | A | E |
| Cycle leader: Miki → Lara → Tomas → Miki | R1 | RB | Q |
| Pause / resume | Options | Menu | Escape |

There are no touch controls or clickable screen actions. Q replaces the earlier Tab proposal to avoid using a focus-navigation key; actual delivery must still be verified in Simulator during Party A. Show the active character's name and role, the next switch target and the appropriate input hint. Three differently shaped or coloured stand-ins are sufficient, with text so colour alone carries no essential information. The current character asset may be reused where useful; no new art is a prerequisite.

Switching is available while exploring, including during movement. Each character stays at their current location. The camera eases over a short transition to the new leader while keeping its elevated angle. The previous leader becomes a follower, and held movement applies only to the new leader. Switching does not replay an action the player was already holding. A simultaneous switch and action performs the switch alone; a fresh action press is needed afterward.

Pause suspends switching and world movement; dialogue will do the same when introduced in C. Release guidance and fresh-input recovery apply after interruption, reconnection and pause transitions. The [party architecture](architecture.md) records command routing and ownership.

## 1. Three people with a reason to leave

Miki starts as leader beside the shelter's transmitter. Lara and Tomas are nearby and ready to travel. The keeper can be represented through labelled text; this slice does not require a fourth animated body.

The briefing establishes that East Span is closed, the dry detour exceeds their water supply, and the shelter can hear the coastal operator but cannot answer. All three contribute to a plan:

> **Miki:** The receiver works. The regulator cuts out when we transmit.
>
> **Tomas:** The depot used emergency sets like this. There may be one in a protected bay.
>
> **Lara:** Then we check the side access. We come back together.

These lines are a condensed proposal, not a biography. The objective becomes **Find a compatible regulator at the depot**. The player can initiate the briefing with any leader; Miki's technical observation is still her line.

## 2. Learn the party on the street

The player walks away with two companions following. An early open stretch offers space to try the switch button before an obstacle demands a specialty.

The camera remains at the accepted elevated angle and follows the selected character. A switch makes the change of leader clear through the name, marker and camera target. The initial follow method uses recorded, collision-resolved movement trails. Followers still check their own movement against scenery; the leader's path alone does not prove clearance at corners. Party members do not physically collide with each other, and trail spacing keeps their presentation readable.

Initial Party A has no automatic teleport or regroup. A blocked follower holds safely and the failed route is recorded for correction. A simpler layout is the first remedy. If the bounded experiment reaches its stop criterion, a constrained out-of-view regroup can be discussed with the maintainer as an alternative; it is not an approved fallback or an implementation requirement.

Following should require little attention. The player should be reading the district, not repeatedly rescuing companions. If this short route cannot support reliable following, simplify its layout and retest before adding mission content. Do not hide the problem with another control mode or a formation menu.

## 3. Open a way everyone can use

The front entrance remains blocked. Following the wall reveals the existing service passage, now proposed to have one closed, movable barrier. Both useful approaches are visible from the street side:

- Lara can **Reach latch**, representing a brief controlled reach/balance manoeuvre that releases the barrier.
- Tomas can **Shift panel**, moving the same loose barrier from a stable grip.

Either action opens the same ordinary ground passage for everyone. They are alternatives; the player does not need to perform both. The first graybox can use text and a simple change of pose or panel placement. It adds no free-jump, climbing control, physics lifting simulation or specialist-only navigation surface.

With Miki leading, the hint explains that Lara can reach the release or Tomas can shift the panel. It does not silently make a companion perform an action from elsewhere. The player switches, approaches the appropriate accessible point and presses the action input.

The action works only from its valid side and with the appropriate leader. From behind a wall or out of reach, it cannot open the gate. Once open, repeat requests do nothing. All three traverse the opening on the way in and out.

This one access problem lets the player choose an approach. It avoids a compulsory sequence of agility, strength and technical locks. With both methods represented by one action press, this slice tests eligible-character prompts and switching, not whether agility and strength feel different in movement or combat. Record which method an unfamiliar player chooses and whether they notice the alternative.

## 4. Salvage without cutting someone else's supply

Inside the depot, a disconnected equipment housing contains the regulator. A separate maintained water bypass serves a block marked empty in an old transport record.

Near the housing, Miki can **Inspect and take regulator**. Her inspection confirms compatibility and distinguishes the disconnected source from the live supply. Other leaders get a short explanation that Miki should inspect it. A correct action takes the part once, removes its visible stand-in and changes the objective to **Return to Relay House**.

The part belongs to the party. Switching to Lara or Tomas keeps the carried-part indicator and objective; there is no transfer action or separate inventory for each person.

The water connection stays intact. Its story beat is part of the inspection, not another pickup or branching resource system:

> **Lara:** We kept that tap open for the people who stayed.
>
> **Tomas:** That block was marked empty.
>
> **Lara:** Some people never left.

The observation establishes continuing habitation and a piece of Lara's experience. It does not identify who caused the collapse or prove that Tomas knowingly abandoned anyone. The local explanation proposed in the [story bible](story/story-bible.md#author-knowledge-and-fair-disclosure) remains for review before this dialogue becomes game content.

## 5. Return together and make the repair

The party retraces a recognisable route through its open passage. The player can change leaders for the return. There is no new enemy wave, second component or forced escort event.

At the transmitter, Miki can **Repair**. Without the regulator, the action explains what is missing and changes nothing. With it, one action consumes the shared carried part and changes the transmitter to **Ready**. A visible indicator and text communicate the result without relying on sound or finished art. Repeating the action cannot consume another part or advance the mission twice.

Lara and Tomas remain nearby as participants. A small exchange can credit their contributions without making them stand at fixed quest-giver positions. The regulator stays in the community transmitter.

## 6. Make contact and secure an appointment

Any leader can now **Call**. Short speaker-labelled text reaches the coastal operator and water crew; Miki, Lara and Tomas speak from Relay House. The selected leader does not replace another character's lines.

The party reports the closure. Information from both approaches supports a canal route with a water stop. They agree on Old Lock, the following afternoon, and the next radio appointment if a route fails.

> **Coastal operator:** The crew can meet you at Old Lock tomorrow afternoon.
>
> **Lara:** We'll take the canal path. Keep the next check-in for us.
>
> **Tomas:** I'll mark the closure for anyone coming after us.

Nina is part of the wider story, but this first prototype omits her dialogue until her underlying relationship is decided. The scene does not use family titles or an emergency involving her to supply motivation.

The achievement is concrete: **Transmitter restored. Meeting agreed at Old Lock.** A proposed coda shows the repaired set serving someone else and the party making room for one another:

> **Miki:** I'll check it once more.
>
> **Lara:** The next caller's waiting.
>
> **Tomas, indicating their meal:** Come on. We've kept you a place.

This can test a small moment of inclusion among the three adults. It does not prove that the full chapter's emotional ending works. Decide the underlying relationships, including Nina's role, before finalising Party C dialogue; no kinship is implied by these provisional lines.

## 7. Finish, reread, restart

After the call the trio can keep walking and switching. Any leader can use **Read plan** at the transmitter to reread the meeting details without restarting the call or awarding progress.

The proposed Pause menu contains Resume and Restart. Stick up/down or W/S selects; Cross/A/E confirms; Options/Menu/Escape resumes. Restart returns directly to the beginning of the slice without a second confirmation screen. These menu details are proposals for review, not current features.

During dialogue, Pause preserves the current line; resuming returns there. Restart resets the whole run: all three positions, active leader Miki, follower state, closed service barrier, visible regulator, unrepaired radio, briefing, dialogue and objectives. It must not duplicate characters, scene subscriptions or callbacks. A fresh launch starts a new in-memory run; saved Continue is later work.

## What we should learn from this slice

Observe an unfamiliar player without explaining the route. Can they identify the leader, switch deliberately and move all three through the service passage? Does choosing Lara or Tomas feel useful? Do they understand why Miki inspects the part, who benefits from leaving the water supply alone and what the call achieved?

The [prototype plan](prototype-plan.md) turns those questions into staged checks. Test the uncertain party behaviour first, then add the single access problem and the repair loop. More mechanics, backstory or finished art should follow evidence about what is enjoyable and unclear.

## Future squad and combat design

Exploration and salvage lead; occasional, tense encounters offer meaningful avoidance and withdrawal. The [story bible owns the combat identities](story/story-bible.md#combat-identities): Miki offers precision and disruption, Lara mobility and useful angles, and Tomas protection and close-range stopping power. All three carry a weapon in this future design and can defend themselves. Their existing inspection, route-reading and load-handling contributions continue between encounters. Weapons and signature abilities are working choices for review, not implemented equipment or settled balance.

The future movement goal gives companions reachable nearby destinations and room to cooperate, rather than requiring them to repeat every footstep. Proposed **Close** and **Spread** formations change spacing; narrow passages compress the group automatically before it reforms. A proposed positioning order uses a visible destination and clear acknowledgement. A **Regroup** intent returns companions to supporting distance through traversable space, without a teleport. Individual placement, formation cycling, D-pad assignments and equivalent touch controls still need design review; the current input table above is not a combat mapping.

**Proposed input budget.** A starting point for review, not settled bindings. Each character's combat identity fits one signature button, so switching changes what that button does rather than adding buttons.

| Intent | PS5 | Xbox | Touch |
|---|---|---|---|
| Move | Left stick | Left stick | Analog stick |
| Fire at the assisted target (hold) | R2 | RT | Fire |
| Leader's signature | Square | X | Signature |
| Next / previous leader | R1 / L1 | RB / LB | Next, or tap a name |
| Cycle formation | Triangle | Y | Formation |
| Position companions | D-pad | D-pad | Designed with the movement system |
| Look / act | Cross | A | Look |
| Pause / resume | Options | Menu | Pause |

Fire stays a deliberate press so that a quiet approach never starts a fight by accident; companions fire automatically only once a fight is under way. Touch has no D-pad, so its positioning gesture belongs to the movement design; candidates are pressing and holding on the ground, or a short menu on the Formation button. Five buttons around the right thumb is about the limit that stays comfortable on a phone, so a later addition should replace one rather than add a sixth. Simulator keyboard keys follow when these are implemented.

For the proposed first combat experiment, the player directs the current leader's attack and signature ability while companions use ordinary weapons and defensive positioning. Companions favour the group's immediate threats, useful weapon distance, clear firing lines and reachable cover. They do not initiate a fight with a visible patrol, pursue enemies far from the group or activate remote specialist interactions. Withdrawal takes priority over maintaining a firing position. Personality affects preferred positions without making orders unreliable. Switching preserves positions and changes the ability the player can trigger; it does not require a fixed Miki → Lara → Tomas combat sequence.

**The Quiet Yard** is the [complete encounter script](encounters/the-quiet-yard.md), set on the onward journey toward Old Lock after Chapter One's transmitter repair and crew appointment. The party can leave optional filter components behind, retrieve them through a covered patrol gap, fight two security units, or retreat during an encounter. A recently maintained water pipe provides a local human clue whichever route the player chooses. The encounter neither adds a required regulator nor makes fighting a condition of restoring the transmitter.

This remains a paper design outside Parties A–C. The [combat design review gate](prototype-plan.md#combat-design-review-gate) owns the next step. No combat controls, formation AI, enemy behaviour, health, ammunition economy or weapon progression is implemented or authorised by these pages.
