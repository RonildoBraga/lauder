# Lauder — gameplay walkthrough

**Date:** 18 November 2026\
**Status:** The game opens on the Brooklyn Bridge, as the maintainer accepted in [ADR 0004](decisions/0004-brooklyn-bridge-opening.md) on 18 November 2026. M1 to M3 are merged, as the [opening record](opening.md) describes, and Laura follows in M4. Biographies and dialogue remain working proposals from the [story bible](story/story-bible.md), whose [Chapter One outline](story/story-bible.md#chapter-one--across-the-bridge) this walkthrough follows. The [prototype plan](prototype-plan.md) defines staged checks.

The maintainer has endorsed the occasional-combat direction and assigned the [combat-role and Quiet Yard documentation](#future-squad-and-combat-design) for Claude's review before implementation. That separate design gate precedes any combat or formation work beyond the opening's milestones.

## The game we are building

One human player directs up to three characters travelling together. The selected character leads; the others follow through the same physical world. Switching changes who the player controls, not the group's progress, belongings or relationships.

The proposed trio is Miki, who understands systems and careful salvage; Laura, who is agile and reads access routes; and Tom, whose strength and load-handling experience offer another approach. Their abilities are understandable before the player knows their histories. Internal synthetic replacements and biological changes belong to the world, but this slice needs no medical exposition or visible machinery in anyone's body.

They meet as strangers in a ruined future, in which safe water, maintained equipment and current route information matter. Why each of them is crossing is revealed gradually. Their deeper connections emerge through what they recognise and choose to do.

## The Brooklyn Bridge opening

The game begins with Miki alone on the Brooklyn Bridge, heading from Brooklyn towards Manhattan through a post-apocalyptic New York. Everything is greybox: simple shapes and colours for the layout, the encounters and the story's progress, before any detailed art. [ADR 0004](decisions/0004-brooklyn-bridge-opening.md) sets out how it is built.

### 1. Alone on the bridge (M1, built)

Miki starts at the Brooklyn end. The deck is a flat, compressed greybox about 250 m long. Two roadways run either side of the raised walkway's base, and two granite towers stand over them, with tall arches the roadway passes through. Cables descend to the railings, and the river lies far below. Abandoned cars, a van, a truck and debris stand in the lanes. A bus jammed across the east roadway at mid-span sends her through a gap where the walkway's base has collapsed, onto the west roadway and on to a barricade at the Manhattan end.

She is alone, so the player learns to move and look. **Next** does not appear until someone joins. A few places show a short line the first time she reaches them, such as "Cars stand where they stopped, doors still open." and "The first tower. Its arches still stand." The camera keeps its usual height and distance but looks straight along the deck, so pushing up walks towards Manhattan.

### 2. Friendly? (M2, built)

A stranger waits among the cars before the first tower. As Miki nears him he steps out into the lane, and she calls out, "Friendly!" He aims, with a red line to her and a warning on the HUD, and fires: a near miss, scripted. The HUD says "He opened fire. Fire back, or take cover." and shows how to fire, and while he stands the camera leans towards him so both are on screen. **Fire** draws Miki's carbine on the first press and shoots at the nearest hostile in sight, marked on the deck, with no manual aiming. Before he has fired, he is not a target. Cars give cover to both sides. Miki can take three hits, shown beside her name, and he two. A third hit fades the screen and starts the fight again with nothing lost, Miki just short of the cars.

### 3. The search, and Tom (M3, built)

Miki can search the body for ammunition and a medical kit. While she searches, an attacker runs at her from behind a van with a knife. Tom, close by, shoots him before he reaches her. A short exchange follows, and Tom joins: **Next** appears, and he follows in the Close formation. The scene plays the same way every time, and Miki stands still while it plays.

### 4. Laura (M4)

At mid-span, beside the gap in the divider, Laura is crawling beside a car. Miki can **Help**; the exchange gives only her name. With the medical kit from the first body she can stand, and she joins.

### 5. Onwards (M4, M5)

The three cross the second tower together to the Manhattan end. With two companions, the formations of [ADR 0003](https://github.com/RonildoBraga/lauder/blob/a5437e5/docs/decisions/0003-squad-movement.md) come into play on the open deck.

Lines stay provisional and brief. None of the scenes explains anyone's past beyond what the moment needs.

## What exists today

The bridge is one level value: its scenery, starting party, spawns, trigger areas, interactions and encounters, while the session holds who has joined and the story's beat. Three primitive stand-ins share session-owned leadership and Pause, leader cycling and an eased camera, and companions follow as a squad in a Close formation ([ADR 0003](decisions/0003-squad-movement.md) phase S1) rather than on the leader's exact path. [M2](opening.md#m2--the-first-fight) adds the stranger's fight, with assisted aim, cover, the placeholder hit rule and a retry, and [M3](opening.md#m3--the-search-the-ambush-and-tom) the search, the ambush and Tom joining. The authorised [touch-control option](touch-controls.md) adds a second phone input path; its validation is recorded separately.

## Readable controls and party feedback

The current input mappings use the same movement, action, switching and Pause rules, and the action also advances a conversation and confirms the pause menu's choice:

| Intent | PS5 | Xbox | Touch | Keyboard |
|---|---|---|---|---|
| Move the leader | Left stick | Left stick | Bottom-left analog stick | WASD |
| Act / advance a line / confirm a menu choice | Cross | A | Look, the leader's action, Continue in a conversation, or Restart while paused | E |
| Cycle leader through who has joined | R1 | RB | Next: name | Q |
| Pause / resume | Options | Menu | Pause / Resume | Escape |
| Fire at the assisted target: press to draw, hold to keep firing | R2 | RT | Fire, shown during a fight | F |

The maintainer's [touch request](touch-controls.md#authorisation) supersedes the earlier no-touch decision. Touch appears automatically without an extended controller. With a controller attached, it remains the default unless the player chooses **Use touch controls**; **Use controller** returns to it. The selection is not persisted across app launches. Q remains the keyboard switch key. Show the active character's name and role, the next switch target and the appropriate input hint. Three differently shaped or coloured stand-ins are sufficient, with text so colour alone carries no essential information. The current character asset may be reused where useful; no new art is a prerequisite.

Switching is available while exploring, including during movement. Each character stays at their current location. The camera eases over a short transition to the new leader while keeping its elevated angle. The previous leader becomes a follower, and held movement applies only to the new leader. Switching does not replay an action the player was already holding. A simultaneous switch and action performs the switch alone; a fresh action press is needed afterward.

Pause and dialogue suspend switching and world movement. Release guidance and fresh-input recovery apply after source changes, interruption, reconnection and pause transitions. On touch, lift every finger before continuing, even one resting at the stick centre. The stick and buttons can be held together; Pause keeps their contacts tracked while gameplay is frozen. The [party architecture](architecture.md) records command routing and ownership.

## Future squad and combat design

Exploration and salvage lead; occasional, tense encounters offer meaningful avoidance and withdrawal. The [story bible owns the combat identities](story/story-bible.md#combat-identities): Miki offers precision and disruption, Laura mobility and useful angles, and Tom protection and close-range stopping power. All three carry a weapon in this future design and can defend themselves. Their existing inspection, route-reading and load-handling contributions continue between encounters. Weapons and signature abilities are working choices for review, not implemented equipment or settled balance.

The future movement goal gives companions reachable nearby destinations and room to cooperate, rather than requiring them to repeat every footstep. Proposed **Close** and **Spread** formations change spacing; narrow passages compress the group automatically before it reforms. A proposed positioning order uses a visible destination and clear acknowledgement. A **Regroup** intent returns companions to supporting distance through traversable space, without a teleport. Individual placement, formation cycling, D-pad assignments and equivalent touch controls are set out in the accepted [ADR 0003](decisions/0003-squad-movement.md); the current input table above is not a combat mapping.

**Proposed input budget.** A starting point for review, not settled bindings. Each character's combat identity fits one signature button, so switching changes what that button does rather than adding buttons.

| Intent | PS5 | Xbox | Touch |
|---|---|---|---|
| Move | Left stick | Left stick | Analog stick |
| Fire at the assisted target (hold) | R2 | RT | Fire |
| Leader's signature | Square | X | Signature |
| Next / previous leader | R1 / L1 | RB / LB | Next, or tap a name |
| Cycle formation | Triangle | Y | Formation |
| Position companions | D-pad | D-pad | Press and hold on the ground ([ADR 0003](decisions/0003-squad-movement.md#orders)) |
| Look / act | Cross | A | Look |
| Pause / resume | Options | Menu | Pause |

Fire stays a deliberate press so that a quiet approach never starts a fight by accident; companions fire automatically only once a fight is under way. Touch has no D-pad; [ADR 0003](decisions/0003-squad-movement.md#orders) uses pressing and holding on the ground, which opens a small menu at the finger. Five buttons around the right thumb is about the limit that stays comfortable on a phone, so a later addition should replace one rather than add a sixth. Simulator keyboard keys follow when these are implemented; Fire, built with M2, is F.

For the proposed first combat experiment, the player directs the current leader's attack and signature ability while companions use ordinary weapons and defensive positioning. Companions favour the group's immediate threats, useful weapon distance, clear firing lines and reachable cover. They do not initiate a fight with a visible patrol, pursue enemies far from the group or activate remote specialist interactions. Withdrawal takes priority over maintaining a firing position. Personality affects preferred positions without making orders unreliable. Switching preserves positions and changes the ability the player can trigger; it does not require a fixed Miki → Laura → Tom combat sequence.

**The Quiet Yard** is the [complete encounter script](encounters/the-quiet-yard.md), set on the onward journey toward Old Lock after the Relay House scene. The party can leave optional filter components behind, retrieve them through a covered patrol gap, fight two security units, or retreat during an encounter. A recently maintained water pipe provides a local human clue whichever route the player chooses. The encounter neither adds a required regulator nor makes fighting a condition of restoring the transmitter.

This remains a paper design. The [combat design review gate](prototype-plan.md#combat-design-review-gate) owns the next step. These pages implement or authorise no combat controls, formation AI, enemy behaviour, health, ammunition economy or weapon progression. The opening's first fight is a separate assignment under [ADR 0004](decisions/0004-brooklyn-bridge-opening.md): [M2](opening.md#m2--the-first-fight) built Fire with assisted aim, one scripted enemy, the placeholder hit rule and one ammunition count.
