# Lauder — gameplay walkthrough

**Updated:** 23 November 2026\
**Status:** The game opens on the Brooklyn Bridge ([ADR 0004](decisions/0004-brooklyn-bridge-opening.md)), and the whole opening is built. Biographies and dialogue remain working proposals from the [story bible](story/story-bible.md), whose [Chapter One outline](story/story-bible.md#chapter-one--across-the-bridge) this walkthrough follows. The [prototype plan](prototype-plan.md) defines the checks.

Combat stays occasional. The [future squad and combat design](#future-squad-and-combat-design) passes a design gate before any combat or formation work beyond the opening.

The bridge is the only playable scene after the maintainer's [bridge-only reset](decisions/0017-bridge-only-reset.md). Other prototype venues and their dedicated systems are retired.

**Robot revision:** The maintainer accepted C's form and Blender motion studies, then assigned integration at the first tower. The first human shooter is replaced with the [C guard](encounters/bridge-spider-bot.md). Since 26 November 2026 the three start together, and the later knife attacker, Tom's introduction and Laura's recruitment are gone. Internal `stranger` marker and beat identifiers remain stable references; they no longer describe the visible first enemy. Current verification belongs in the [prototype plan](prototype-plan.md), separate from this walkthrough.

## The game we are building

One human player directs up to three characters travelling together. The selected character leads; the others follow through the same physical world. Switching changes who the player controls, not the group's progress, belongings or relationships.

The proposed trio is Miki, who understands systems and careful salvage; Laura, who is agile and reads access routes; and Tom, whose strength and load-handling experience offer another approach. Their abilities are understandable before the player knows their histories. Internal synthetic replacements and biological changes belong to the world, but this slice needs no medical exposition or visible machinery in anyone's body.

They travel together through a ruined future, in which safe water, maintained equipment and current route information matter. Why each of them is crossing, and how they came to travel together, is revealed gradually. Their deeper connections emerge through what they recognise and choose to do.

## The Brooklyn Bridge opening

The game begins with Miki, Tom and Laura together at the Brooklyn end of the bridge, heading towards Manhattan through a post-apocalyptic New York. It is built as a greybox, with simple shapes and colours for the layout, the encounters and the story's progress. Its look is moving to the frozen low-poly [visual direction](visual-direction.md), with the bridge's road and the river buried under snow. [ADR 0004](decisions/0004-brooklyn-bridge-opening.md) sets out how it is built.

### 1. Together on the bridge (M1, built)

The three start together at the Brooklyn end, Miki leading and Tom and Laura in the Close formation behind her. On 26 November 2026 the maintainer simplified the opening so that nobody has to be met on the way: **“I want to simplify the starting of the game so all the 3 companions will start together so no need to meet Tom and Laura later in the game”**.

Snow has buried the bridge's road, everything left on it and the river under it: a flat white plain, with the bridge 644 m from end to end and only its two granite towers standing above the snow, at their real spacing, 486 m apart, and at their real size, with tall arches the old roadways pass through. Nothing else stands on the snow but a line of thin poles with small rust flags every 25 m along both edges of the buried road, as on a polar route, so the way and the party's movement read on the white. The party keeps to that line, inside an invisible edge at the road's width, and walks straight across to the Manhattan end. A compass at the top of the screen points to Manhattan and counts down the metres to it.

The player learns to move, look, switch leader and try the formations. A few places show a short line the first time the leader reaches them, such as "Snow covers the road and everything left on it." and "The first tower. Its arches still stand." The camera stands high and far back, showing the buried road and the snow on both sides, and looks straight along the bridge, so pushing up walks towards Manhattan. While a tower stands between the camera and the party, it fades.

### 2. The guard at the first tower (M2)

A heavy, four-legged machine patrols the outgoing side of the first tower. Its dark faceted armour, square sensor and twin guns identify it as a different kind of threat. Miki notices that it is still guarding something; the scene does not explain who built it or why it remains there.

The robot turns toward Miki at a limited rate, gives notice, stops and braces while tracking, then commits to one aim point. It fires three rounds, alternating its guns, and recovers before trying again. There is no red aiming line or projected danger cone. Its body and gun direction, the planted pause and the shots supply the warning. Actual barrel-origin shots meet the tower's stone; neither a gun nor a committed shot can ignore cover.

**Fire** uses the leader's weapon in hand, Miki's long rifle at first, and takes the assisted target in sight; the right stick gives manual aim, and R1 switches to the other weapon ([ADR 0021](decisions/0021-paired-weapons.md)). The robot is a valid target when engaged, without waiting for a human's deliberate warning miss. It takes six hits in this prototype: two long-rifle shots, one shotgun blast or one swing of Laura's sword, or a moment of minigun fire. Miki can take three hits, with at most one injury from a robot burst. A third mistake fades the screen and retries from the existing first-tower checkpoint with the encounter's initial inventory restored.

The machine remains within its small guard area. Miki can break sight, withdraw and return without resetting her spent ammunition or the robot's damage. She can also take the west arch and reach the authored safe exit beyond the whole guard envelope. That resolves the encounter without pretending that the robot was killed and cancels any queued fire before the party walks on. This route remains available with no ammunition.

### 3. Onwards (M4 and M5, built)

Beyond the guard, nothing more stops the three. The maintainer chose to keep the guard as the bridge's only fight, so the supply case's search, the knife attacker's ambush with Tom's shot and Laura's rescue with the medical kit are gone. The case still stands on the tower's outgoing west side, as scenery with nothing in it.

The three cross the second tower together to the Manhattan end, where the party stops for a short closing exchange and the objective reads "Manhattan, together.": the end of the opening. The formations of [ADR 0003](decisions/0003-squad-movement.md) are there from the start (M5). **Formation** cycles **Close**; **Spread**, a wider front; and **Column**, single file on the leader's route. Where a passage is too narrow for it, Spread pulls in or falls into single file, then spreads out again beyond; the buried bridge's arches leave room for it. The HUD names the formation, the closing exchange and a change of leader keep it, and Restart returns to Close. Orders work from the start too ([ADR 0003](decisions/0003-squad-movement.md)'s phase S3): the D-pad sends both companions, or one of them, to a point ahead, or tells them to hold where they stand, and on touch pressing and holding on the ground does the same through a small menu at the finger. **Formation** then reads **Follow** and calls everyone back. The closing exchange waits until all three are at the Manhattan end.

Lines stay provisional and brief. None of the scenes explains anyone's past beyond what the moment needs.

## What the opening has

The bridge is one level value: its scenery, starting party, spawns, trigger areas and encounters, while the session holds the party and the story's beat. Three [pawns](visual-direction.md#characters-and-interface) share session-owned leadership and Pause, leader cycling and an eased camera, and companions follow as a squad ([ADR 0003](decisions/0003-squad-movement.md) phases S1 to S3) rather than on the leader's exact path: in whichever formation the player chooses, or where an order sends them. The guard's encounter has bounded patrol, a committed burst, real cover, retreat, a safe bypass and a retry; then comes the end of the opening. Every character can fire their own weapon as leader ([ADR 0010](decisions/0010-squad-weapons.md)), and the leader can dodge-roll through a burst ([ADR 0019](decisions/0019-dodge-roll.md)). [Touch controls](touch-controls.md) give the phone a second input path.

## Readable controls and party feedback

Every input, controller, touch or keyboard, uses the same movement, action, switching and Pause rules, and the action also advances a conversation and confirms the pause menu's choice; the [input contract](prototype-plan.md#input-and-interaction-contract) lists the controls. Show the active character's name, the next switch target and the appropriate input hint. The status panel keeps to the essentials: the party and its formation always, a new objective or line for a few seconds, and a threat or the active weapon's readiness while they matter. It shows the weapon in hand: its loaded rounds or a reload countdown, how long Tom's dome lasts, or just the sword; outside fights it labels free practice. Three differently coloured pawns are sufficient, with text so colour alone carries no essential information; no new art is a prerequisite.

Switching is available while exploring, including during movement. Each character stays at their current location. The camera eases over a short transition to the new leader while keeping its elevated angle. The previous leader becomes a follower, and held movement applies only to the new leader. Switching does not replay an action the player was already holding. A simultaneous switch and action performs the switch alone; a fresh action press is needed afterwards. The formation button and the orders follow the same rules: they work only while exploring, and pressed with the action they give their command alone. A switch ends the new leader's order; if the others are going or holding, the previous leader holds where they stand, and otherwise follows. The HUD shows the formation and what the squad is doing, such as "Close · following" or "Laura holding", and for a controller or keyboard the companions' fixed sides, "◀ Laura · Tom ▶".

Pause and dialogue suspend switching and world movement. Release guidance and fresh-input recovery apply after source changes, interruption, reconnection and pause transitions. On touch, lift every finger before continuing, even one resting at the stick centre. The stick and buttons can be held together; Pause keeps their contacts tracked while gameplay is frozen. The [party architecture](architecture.md) records command routing and ownership.

## Future squad and combat design

This section is design context, not a description of working features or a new implementation assignment. Exploration and salvage remain the intended main activities, with occasional tense combat. The [story bible](story/story-bible.md#combat-identities) gives Miki precision and disruption, Laura mobility and useful angles, and Tom protection and close-range stopping power. Their native weapons remain usable by the player on the bridge; signature abilities and autonomous companion combat do not.

The retained Close, Spread and Column formations and move/hold/follow orders test readable group movement. They should serve an enjoyable loop rather than require extra controls to justify themselves. A future combat experiment can reconsider useful cover, coordinated fire or withdrawal once the core experience is agreed; the retired arena's presence in Git history does not commit the project to restoring it.

[The Quiet Yard](encounters/the-quiet-yard.md) and the story bible's later Relay House screenplay remain unimplemented narrative proposals. The Quiet Yard offers optional filter seals, a safe detour, a covered patrol gap, combat and retreat. It is retained to discuss the trio's roles and emotional purpose, not as an additional playable scene.

Next, use the bridge to settle one small gameplay loop and the questions a prototype should answer. Weapon tuning, abilities and further places follow that decision. The [prototype plan](prototype-plan.md#combat-design-review-gate) records this gate.
