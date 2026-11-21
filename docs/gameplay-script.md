# Lauder — gameplay walkthrough

**Updated:** 21 November 2026\
**Status:** The game opens on the Brooklyn Bridge ([ADR 0004](decisions/0004-brooklyn-bridge-opening.md)), and the whole opening is built. Biographies and dialogue remain working proposals from the [story bible](story/story-bible.md), whose [Chapter One outline](story/story-bible.md#chapter-one--across-the-bridge) this walkthrough follows. The [prototype plan](prototype-plan.md) defines the checks.

Combat stays occasional. The [future squad and combat design](#future-squad-and-combat-design) passes a design gate before any combat or formation work beyond the opening.

## The game we are building

One human player directs up to three characters travelling together. The selected character leads; the others follow through the same physical world. Switching changes who the player controls, not the group's progress, belongings or relationships.

The proposed trio is Miki, who understands systems and careful salvage; Laura, who is agile and reads access routes; and Tom, whose strength and load-handling experience offer another approach. Their abilities are understandable before the player knows their histories. Internal synthetic replacements and biological changes belong to the world, but this slice needs no medical exposition or visible machinery in anyone's body.

They meet as strangers in a ruined future, in which safe water, maintained equipment and current route information matter. Why each of them is crossing is revealed gradually. Their deeper connections emerge through what they recognise and choose to do.

## The Brooklyn Bridge opening

The game begins with Miki alone on the Brooklyn Bridge, heading from Brooklyn towards Manhattan through a post-apocalyptic New York. It is built as a greybox, with simple shapes and colours for the layout, the encounters and the story's progress. Its look is moving to the frozen low-poly [visual direction](visual-direction.md), with the bridge's road and the river buried under snow. [ADR 0004](decisions/0004-brooklyn-bridge-opening.md) sets out how it is built.

### 1. Alone on the bridge (M1, built)

Miki starts at the Brooklyn end. Snow has buried the bridge's road, everything left on it and the river under it: a flat white plain, with the bridge 644 m from end to end and only its two granite towers standing above the snow, at their real spacing, 486 m apart, and at their real size, with tall arches the old roadways pass through. Nothing else stands on the snow but a line of thin poles with small rust flags every 25 m along both edges of the buried road, as on a polar route, so the way and the party's movement read on the white. The party keeps to that line, inside an invisible edge at the road's width, and walks straight across to the Manhattan end. A compass at the top of the screen points to the next goal and counts down the metres to it: Manhattan, the woman while she waits for help, then Manhattan again.

She is alone, so the player learns to move and look. **Next** does not appear until someone joins. A few places show a short line the first time she reaches them, such as "Snow covers the road and everything left on it." and "The first tower. Its arches still stand." The camera stands high and far back, showing the buried road and the snow on both sides, and looks straight along the bridge, so pushing up walks towards Manhattan. While a tower stands between the camera and the party, it fades.

### 2. Friendly? (M2, built)

A stranger waits behind the first tower's pier, between its two arches. As Miki comes through the east arch he steps out beyond it, and she calls out, "Friendly!" He aims, with a red line to her and a warning on the HUD, and fires: a near miss, scripted. The HUD says "He opened fire. Fire back, or take cover." and shows how to fire, and while he stands the camera leans towards him so both are on screen. **Fire** draws Miki's carbine on the first press and shoots at the nearest hostile in sight, marked on the snow, with no manual aiming. Before he has fired, he is not a target. Out on the snow only the pier gives cover, to whoever keeps it between them. Miki can take three hits, shown beside her name, and he two. A third hit fades the screen and starts the fight again with nothing lost, Miki back in the arch.

### 3. The search, and Tom (M3, built)

Miki can search the body for ammunition and a medical kit. While she searches, an attacker runs at her out of the tower's west arch with a knife. Tom, coming out of the east arch, shoots him before he reaches her. A short exchange follows, and Tom joins: **Next** appears, and he follows in the Close formation. The scene plays the same way every time, and Miki stands still while it plays.

### 4. Laura (M4, built)

Laura lies hurt, face down, in the snow beyond mid-span, in view from the start. Once Tom has joined, nearing her finds her: she calls out, "Please. Over here.", and the objective becomes "Help the woman in the snow." Beside her, the action reads **Help**, for whoever leads. It uses the medical kit from the first body, and a short scene holds the party: she stands, she and Miki turn to each other, and the exchange gives only her name. When it ends she joins, and Tom and Laura follow in the Close formation.

### 5. Onwards (M4 and M5, built)

The three cross the second tower together to the Manhattan end, where the party stops for a short closing exchange and the objective reads "Manhattan, together.": the end of the opening. With two companions, the formations of [ADR 0003](decisions/0003-squad-movement.md) come into play on the open snow (M5). **Formation** cycles **Close**; **Spread**, a wider front; and **Column**, single file on the leader's route. Where a passage is too narrow for it, Spread pulls in or falls into single file, then spreads out again beyond; the buried bridge's arches leave room for it. The HUD names the formation, the closing exchange and a change of leader keep it, and Restart returns to Close. Orders come into play too ([ADR 0003](decisions/0003-squad-movement.md)'s phase S3): the D-pad sends both companions, or one of them, to a point ahead, or tells them to hold where they stand, and on touch pressing and holding on the ground does the same through a small menu at the finger. **Formation** then reads **Follow** and calls everyone back. The closing exchange waits until all three are at the Manhattan end.

Lines stay provisional and brief. None of the scenes explains anyone's past beyond what the moment needs.

## What the opening has

The bridge is one level value: its scenery, starting party, spawns, trigger areas, interactions and encounters, while the session holds who has joined and the story's beat. Three primitive stand-ins share session-owned leadership and Pause, leader cycling and an eased camera, and companions follow as a squad ([ADR 0003](decisions/0003-squad-movement.md) phases S1 to S3) rather than on the leader's exact path: in the Close formation, and once Laura joins in whichever formation the player chooses, or where an order sends them. The stranger's fight has assisted aim, cover, the placeholder hit rule and a retry; then come the search, the ambush and Tom joining, and Laura and the end of the opening. [Touch controls](touch-controls.md) give the phone a second input path.

## Readable controls and party feedback

Every input, controller, touch or keyboard, uses the same movement, action, switching and Pause rules, and the action also advances a conversation and confirms the pause menu's choice; the [input contract](prototype-plan.md#input-and-interaction-contract) lists the controls. Show the active character's name, the next switch target and the appropriate input hint. The status panel keeps to the essentials: the party and its formation always, a new objective or line for a few seconds, and a threat or the carbine's rounds while they matter. Three differently coloured stand-ins are sufficient, with text so colour alone carries no essential information; no new art is a prerequisite.

Switching is available while exploring, including during movement. Each character stays at their current location. The camera eases over a short transition to the new leader while keeping its elevated angle. The previous leader becomes a follower, and held movement applies only to the new leader. Switching does not replay an action the player was already holding. A simultaneous switch and action performs the switch alone; a fresh action press is needed afterwards. The formation button and the orders follow the same rules: they work only while exploring, and pressed with the action they give their command alone. A switch ends the new leader's order; if the others are going or holding, the previous leader holds where they stand, and otherwise follows. The HUD shows the formation and what the squad is doing, such as "Close · following" or "Laura holding", and for a controller or keyboard the companions' fixed sides, "◀ Laura · Tom ▶".

Pause and dialogue suspend switching and world movement. Release guidance and fresh-input recovery apply after source changes, interruption, reconnection and pause transitions. On touch, lift every finger before continuing, even one resting at the stick centre. The stick and buttons can be held together; Pause keeps their contacts tracked while gameplay is frozen. The [party architecture](architecture.md) records command routing and ownership.

## Future squad and combat design

Exploration and salvage lead; occasional, tense encounters offer meaningful avoidance and withdrawal. The [story bible owns the combat identities](story/story-bible.md#combat-identities): Miki offers precision and disruption, Laura mobility and useful angles, and Tom protection and close-range stopping power. All three carry a weapon in this future design and can defend themselves. Their existing inspection, route-reading and load-handling contributions continue between encounters. Weapons and signature abilities are working choices for review, not implemented equipment or settled balance.

The future movement goal gives companions reachable nearby destinations and room to cooperate, rather than requiring them to repeat every footstep. The **Close**, **Spread** and **Column** formations, built for the opening in M5, change spacing, and narrow passages compress the group automatically before it re-forms. Orders that send companions to a marked point, shown by a ring in their colour until they arrive, and Hold are built for the opening (S3); **Follow** brings them back through traversable space, without a teleport. A **Regroup** intent in a fight, which withdraws companions to supporting distance, comes with combat positioning (S4), which the combat yard tries. Individual placement, formation cycling, D-pad assignments and equivalent touch controls are set out in the accepted [ADR 0003](decisions/0003-squad-movement.md); the current [input contract](prototype-plan.md#input-and-interaction-contract) is not a combat mapping.

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

Fire stays a deliberate press so that a quiet approach never starts a fight by accident; companions fire automatically only once a fight is under way. Touch has no D-pad; [ADR 0003](decisions/0003-squad-movement.md#orders) uses pressing and holding on the ground, which opens a small menu at the finger. Five buttons around the right thumb is about the limit that stays comfortable on a phone, so a later addition should replace one rather than add a sixth. Simulator keyboard keys follow when these are implemented, as the [input contract](prototype-plan.md#input-and-interaction-contract) lists them for Fire, Formation and the orders. Circle / B hides or shows the status panel, leaving Square / X free for the signature.

The first experiment, [ADR 0005](decisions/0005-squad-combat-experiment.md), is built in a greybox combat yard outside the story, which the pause menu's **Combat test** opens: two shooters that aim at anyone, companions who fire by themselves once a fight is under way, three hits for everyone with a fall back to the entrance, and Miki's **Disrupt**. Since its first session the companions also take cover near their places, stepping out to fire and back while a shooter aims at them, and since its second the yard has the rest of combat positioning: each companion's own preferences in cover, routes that keep out of the shooters' sight, and **Regroup** on the formation button.

The first salvage and exploration experiment, [ADR 0006](decisions/0006-salvage-and-exploration-experiment.md), is built in a greybox salvage yard outside the story, which the pause menu's third choice reaches from the combat yard:
- **The goal:** the trio must fix a transmitter at the entrance, marked by its aerial, with the right regulator from a fenced depot.
- **The gate:** the depot's rust gate swings open when Laura reaches its latch or Tom shifts a loose panel, both marked in amber on the fence, and either opens it for everyone. Miki hears who could.
- **The cabinets:** Miki's inspection tells them apart: the right regulator, one of a different model, and one still feeding a neighbouring shelter, which nobody opens. Each then wears a tag in its own colour. Each run deals them afresh. Anyone else can search a cabinet without knowing which it is, and only Miki can tell the model.
- **The bag:** what the party finds goes in the shared bag, which names a regulator known not to fit.

For the proposed first combat experiment, the player directs the current leader's attack and signature ability while companions use ordinary weapons and defensive positioning. Companions favour the group's immediate threats, useful weapon distance, clear firing lines and reachable cover. They do not initiate a fight with a visible patrol, pursue enemies far from the group or activate remote specialist interactions. Withdrawal takes priority over maintaining a firing position. Personality affects preferred positions without making orders unreliable. Switching preserves positions and changes the ability the player can trigger; it does not require a fixed Miki → Laura → Tom combat sequence.

**The Quiet Yard** is the [complete encounter script](encounters/the-quiet-yard.md), set on the onward journey towards Old Lock after the Relay House scene. The party can leave optional filter seals behind, retrieve them through a covered patrol gap, fight two security units, or retreat during an encounter. A recently maintained water pipe provides a local human clue whichever route the player chooses.

This remains a paper design. The [combat design review gate](prototype-plan.md#combat-design-review-gate) has settled a first greybox experiment from it, [ADR 0005](decisions/0005-squad-combat-experiment.md), which needs its own assignment. These pages implement or authorise no combat controls, formation AI, enemy behaviour, health, ammunition economy or weapon progression. The opening's fights come from [ADR 0004](decisions/0004-brooklyn-bridge-opening.md): Fire with assisted aim, scripted enemies, the placeholder hit rule and one ammunition count.
