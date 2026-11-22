# Lauder — gameplay walkthrough

**Updated:** 22 November 2026\
**Status:** The game opens on the Brooklyn Bridge ([ADR 0004](decisions/0004-brooklyn-bridge-opening.md)), and the whole opening is built. Biographies and dialogue remain working proposals from the [story bible](story/story-bible.md), whose [Chapter One outline](story/story-bible.md#chapter-one--across-the-bridge) this walkthrough follows. The [prototype plan](prototype-plan.md) defines the checks.

Combat stays occasional. The [future squad and combat design](#future-squad-and-combat-design) passes a design gate before any combat or formation work beyond the opening.

The assigned [Relay Run walkthrough](relay-run-walkthrough.md) brings exploration, the existing salvage rules and an optional guarded shortcut into one standalone journey. [ADR 0013](decisions/0013-relay-run.md) owns that prototype's scope. It preserves a no-combat completion path; its dialogue and place in the story remain provisional.

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

A stranger waits behind the first tower's pier, between its two arches. As Miki comes through the east arch he steps out beyond it, and she calls out, "Friendly!" He aims, with a red line to her and a warning on the HUD, and fires: a near miss, scripted. The HUD says "He opened fire. Fire back, or take cover." and shows how to fire, and while he stands the camera leans towards him so both are on screen. **Fire** draws Miki's carbine on the first press and shoots at the nearest hostile in sight, marked on the snow; on a controller the right stick aims instead, and a shot that hits nobody strikes a wall ([ADR 0007](decisions/0007-aiming-and-shot-feedback.md)). Before he has fired, he is not a target, and Miki holds her fire at him. Out on the snow only the pier gives cover, to whoever keeps it between them. Miki can take three hits, shown beside her name, and he two. A third hit fades the screen and starts the fight again with nothing lost, Miki back in the arch.

### 3. The search, and Tom (M3, built)

Miki can search the body for ammunition and a medical kit. While she searches, an attacker runs at her out of the tower's west arch with a knife. Tom, coming out of the east arch, shoots him before he reaches her. A short exchange follows, and Tom joins: **Next** appears, and he follows in the Close formation. The scene plays the same way every time, and Miki stands still while it plays.

### 4. Laura (M4, built)

Laura lies hurt, face down, in the snow beyond mid-span, in view from the start. Once Tom has joined, nearing her finds her: she calls out, "Please. Over here.", and the objective becomes "Help the woman in the snow." Beside her, the action reads **Help**, for whoever leads. It uses the medical kit from the first body, and a short scene holds the party: she stands, she and Miki turn to each other, and the exchange gives only her name. When it ends she joins, and Tom and Laura follow in the Close formation.

### 5. Onwards (M4 and M5, built)

The three cross the second tower together to the Manhattan end, where the party stops for a short closing exchange and the objective reads "Manhattan, together.": the end of the opening. With two companions, the formations of [ADR 0003](decisions/0003-squad-movement.md) come into play on the open snow (M5). **Formation** cycles **Close**; **Spread**, a wider front; and **Column**, single file on the leader's route. Where a passage is too narrow for it, Spread pulls in or falls into single file, then spreads out again beyond; the buried bridge's arches leave room for it. The HUD names the formation, the closing exchange and a change of leader keep it, and Restart returns to Close. Orders come into play too ([ADR 0003](decisions/0003-squad-movement.md)'s phase S3): the D-pad sends both companions, or one of them, to a point ahead, or tells them to hold where they stand, and on touch pressing and holding on the ground does the same through a small menu at the finger. **Formation** then reads **Follow** and calls everyone back. The closing exchange waits until all three are at the Manhattan end.

Lines stay provisional and brief. None of the scenes explains anyone's past beyond what the moment needs.

## What the opening has

The bridge is one level value: its scenery, starting party, spawns, trigger areas, interactions and encounters, while the session holds who has joined and the story's beat. Three primitive stand-ins share session-owned leadership and Pause, leader cycling and an eased camera, and companions follow as a squad ([ADR 0003](decisions/0003-squad-movement.md) phases S1 to S3) rather than on the leader's exact path: in the Close formation, and once Laura joins in whichever formation the player chooses, or where an order sends them. The stranger's fight has assisted aim, cover, the placeholder hit rule and a retry; then come the search, the ambush and Tom joining, and Laura and the end of the opening. Every recruited character can fire their own weapon as leader ([ADR 0010](decisions/0010-squad-weapons.md)). [Touch controls](touch-controls.md) give the phone a second input path.

## Readable controls and party feedback

Every input, controller, touch or keyboard, uses the same movement, action, switching and Pause rules, and the action also advances a conversation and confirms the pause menu's choice; the [input contract](prototype-plan.md#input-and-interaction-contract) lists the controls. Show the active character's name, the next switch target and the appropriate input hint. The status panel keeps to the essentials: the party and its formation always, a new objective or line for a few seconds, and a threat or the active weapon's readiness while they matter. In encounters it shows loaded rounds and the shared total, or a reload countdown; outside them it labels free practice. Three differently coloured stand-ins are sufficient, with text so colour alone carries no essential information; no new art is a prerequisite.

Switching is available while exploring, including during movement. Each character stays at their current location. The camera eases over a short transition to the new leader while keeping its elevated angle. The previous leader becomes a follower, and held movement applies only to the new leader. Switching does not replay an action the player was already holding. A simultaneous switch and action performs the switch alone; a fresh action press is needed afterwards. The formation button and the orders follow the same rules: they work only while exploring, and pressed with the action they give their command alone. A switch ends the new leader's order; if the others are going or holding, the previous leader holds where they stand, and otherwise follows. The HUD shows the formation and what the squad is doing, such as "Close · following" or "Laura holding", and for a controller or keyboard the companions' fixed sides, "◀ Laura · Tom ▶".

Pause and dialogue suspend switching and world movement. Release guidance and fresh-input recovery apply after source changes, interruption, reconnection and pause transitions. On touch, lift every finger before continuing, even one resting at the stick centre. The stick and buttons can be held together; Pause keeps their contacts tracked while gameplay is frozen. The [party architecture](architecture.md) records command routing and ownership.

## Future squad and combat design

Exploration and salvage lead; occasional, tense encounters offer meaningful avoidance and withdrawal. The [story bible owns the combat identities](story/story-bible.md#combat-identities): Miki offers precision and disruption, Laura mobility and useful angles, and Tom protection and close-range stopping power. All three now carry usable weapons in the bounded [ADR 0010](decisions/0010-squad-weapons.md) prototype. Their existing inspection, route-reading and load-handling contributions continue between encounters. The weapons' numerical tuning and the wider combat design remain working choices; Laura's and Tom's signatures remain proposals.

The future movement goal gives companions reachable nearby destinations and room to cooperate, rather than requiring them to repeat every footstep. The **Close**, **Spread** and **Column** formations, built for the opening in M5, change spacing, and narrow passages compress the group automatically before it re-forms. Orders that send companions to a marked point, shown by a ring in their colour until they arrive, and Hold are built for the opening (S3); **Follow** brings them back through traversable space, without a teleport. A **Regroup** intent in a fight, which withdraws companions to supporting distance, comes with combat positioning (S4), which the combat yard tries. Individual placement, formation cycling, D-pad assignments and equivalent touch controls are set out in the accepted [ADR 0003](decisions/0003-squad-movement.md); the current [input contract](prototype-plan.md#input-and-interaction-contract) lists the built combat and exploration bindings.

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

Fire stays a deliberate press so that a quiet approach never starts a fight by accident; companions fire automatically only once a fight is under way. Touch has no D-pad; [ADR 0003](decisions/0003-squad-movement.md#orders) uses pressing and holding on the ground, which opens a small menu at the finger. Five buttons around the right thumb is about the limit that stays comfortable on a phone, so a later addition should replace one rather than add a sixth. Simulator keyboard keys are listed in the [input contract](prototype-plan.md#input-and-interaction-contract), including Fire, Formation and the orders. Circle / B hides or shows the status panel, leaving Square / X free for the signature.

The first experiment, [ADR 0005](decisions/0005-squad-combat-experiment.md), is built in a greybox combat yard outside the story, which the pause menu's **Combat test** opens: two shooters that aim at anyone, companions who fire by themselves once a fight is under way, three hits for everyone with a fall back to the entrance, and Miki's **Disrupt**. Since its first session the companions also take cover near their places, stepping out to fire and back while a shooter aims at them, and since its second the yard has the rest of combat positioning: each companion's own preferences in cover, routes that keep out of the shooters' sight, and **Regroup** on the formation button.

The active-character cover prototype ([ADR 0009](decisions/0009-leader-cover.md)) also starts in that yard. Move beside a block to crouch without pressing another button. The half-ring points towards the block: signal colour for protection, red if a shooter has a clear shot, including from a flank. Firing over a low block raises the character for 0.3 seconds after each shot. A tall wall offers a peek only near a clear edge; its middle still stops the shot. Walking away leaves cover. Pause freezes the stance, and switching leaders evaluates the next character's own position. Phase 4 extends this rule and its shields to companions; the bridge and onward story keep their previous scope.

Phase 3's squad weapons ([ADR 0010](decisions/0010-squad-weapons.md)) are built for any recruited leader: Miki's measured carbine, Laura's three-shot burst and Tom's short-range wide shot dealing two hits. Holding Fire uses their own pace and reloads automatically after 12, 18 or 4 discharges respectively; the starting reloads take 1.2, 1.4 and 1.8 seconds. These are tunable implementation defaults. Each member keeps their magazine and timing across switches, which cancel unspent burst shots; Pause freezes reloads. There is still one ammunition total, reduced once per actual leader shot in an encounter. Magazines limit readiness without adding another inventory, and practice and companion shots remain free. Companions use spread and can miss. Props, poses, sound and player feedback distinguish the weapons without new controls or rigged animation. That phase passed Simulator checks; touch combinations, physical feedback and baseline-phone performance remain unverified.

The assigned phase 4 prototype ([ADR 0011](decisions/0011-companion-combat.md)) shares the cover stance and directional shields across the trio. A companion first tries the leader's marked target when its own weapon can reach it from a clear firing point, otherwise picks its own target. A flank that exposes its shelter can prompt a new nearby position, within the formation or order's limits. Hold and move orders remain useful; Regroup suppresses firing. Companions do not start fights, chase far from the group or use signatures without the player.

Phase 5's assigned yard prototype ([ADR 0012](decisions/0012-tactical-enemies.md)) adds three readable pressures: a shooter seeking cover, a flanker seeking a side angle, and a thrower. Rifle movement stays near the actors' starting places and pauses their firing timer. A thrown grenade fixes its landing point, shows a large warning ring for a 2.5-second fuse and threatens a 2.2 m radius; walking off the marked ground is enough. Tall scenery stops the blast, low cover does not. Companions step to safe reachable ground while retaining their orders, then return to normal positioning. Pause freezes the warning and movement, and Restart or fallback clears live grenades. These additions need no extra touch or controller button.

The combined phase 4/5 implementation passed Simulator validation and is delivered in TestFlight **0.1.0 (21)**. [The prototype plan](prototype-plan.md#verification-and-performance) owns the checks and verified Apple availability. The maintainer authorised finishing this combat sequence, reviewed integration and TestFlight delivery without stopping for repeated milestone responses. Delivery does not establish a judgement of the new squad/enemy feel or physical-phone results.

The first salvage and exploration experiment, [ADR 0006](decisions/0006-salvage-and-exploration-experiment.md), is built in a greybox salvage yard outside the story, which the pause menu's third choice reaches from the combat yard:
- **The goal:** the trio must fix a transmitter at the entrance, marked by its aerials, with the right regulator from a fenced depot.
- **The gate:** the depot's rust gate swings open when Laura reaches its latch or Tom shifts a loose panel, both marked in amber on the fence, and either opens it for everyone. Miki hears who could.
- **The cabinets:** Miki's inspection tells them apart: the right regulator, one of a different model, and one still feeding a neighbouring shelter, which nobody opens. Each then wears a tag in its own colour. Each run deals them afresh. Anyone else can search a cabinet without knowing which it is, and only Miki can tell the model.
- **The bag:** what the party finds goes in the shared bag, which names a regulator known not to fit.

The wider combat proposal lets the player direct the current leader's attack and signature ability while companions use ordinary weapons and defensive positioning. Companions favour the group's immediate threats, useful weapon distance, clear firing lines and reachable cover. They do not initiate a fight with a visible patrol, pursue enemies far from the group or activate remote specialist interactions. Withdrawal takes priority over maintaining a firing position. Personality affects preferred positions without making orders unreliable. Switching preserves positions and changes the ability the player can trigger; it does not require a fixed Miki → Laura → Tom combat sequence.

**The Quiet Yard** is the [complete encounter script](encounters/the-quiet-yard.md), set on the onward journey towards Old Lock after the Relay House scene. The party can leave optional filter seals behind, retrieve them through a covered patrol gap, fight two security units, or retreat during an encounter. A recently maintained water pipe provides a local human clue whichever route the player chooses.

The Quiet Yard and the onward story remain paper designs. The opening and assigned combat and salvage prototypes above come from their decision records; they do not imply that the full encounter proposal is implemented or that work still in validation has passed. The [combat design review gate](prototype-plan.md#combat-design-review-gate) records the current continuous assignment and its remaining boundaries. Changes beyond that scope, such as a health system, ammunition economy or weapon progression, need their own assignment.
