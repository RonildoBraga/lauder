# Graybox duel — gameplay walkthrough

**Current experiment:** [issue #236](https://github.com/RonildoBraga/lauder/issues/236). The earlier bridge/story party is preserved at the [checkpoint](milestones/bridge-prototype.md). The anonymous hero here does not recast Miki or settle a new world/story.

The camera/focus follow-up is tracked in [issue #238](https://github.com/RonildoBraga/lauder/issues/238); its source-bound verification and remaining gates are in the [prototype plan](prototype-plan.md#camera-and-enemy-focus-follow-up--in-progress). The delivered TestFlight build47 predates this follow-up.

You arrive in a small, open arena with a sword and shield. A single opponent waits ahead. You can immediately practise moving and turning; there are no conversations, equipment screens or long approaches before the fight.

The lower diagonal camera follows you, keeping the fighters upright and the floor directions clear. Toggle **Focus** with Tab, R3/right-stick click or the touch button. A ring appears beneath the opponent and the camera frames the pair. You can strafe or walk backwards while turning towards the enemy, including behind your raised shield. Turning takes time; focus does not guarantee a block. Toggle again to move and turn freely. Without focus, Guard keeps your current facing.

As you approach, the enemy raises the blade for a broad sweep. Its facing commits before the attack. You can back away, move around it, hold your shield towards it or time a short dodge. The pose should communicate the danger; colour is supplementary.

If you block, your health stays intact but stamina drops. Keep holding guard and you will eventually exhaust it. Release guard and make space to regain stamina. A dodge has a vulnerable beginning and recovery, so pressing it early is not permanent protection.

The enemy finishes the sweep and visibly recovers. Face it and attack. Your slash prepares, travels through its contact arc and follows through; it cannot instantly pivot to hit behind you. Focus cannot steer an accepted slash or dodge into a new direction. One swing can damage the opponent once. An action pressed very late in recovery can buffer once, but holding a button does not play an automatic combo.

The opponent next draws the weapon back for a longer-reaching thrust. Its longer preparation and narrower line ask a different positioning question. Its direction remains committed, so a sidestep or retreat is useful. A successful defence earns another chance to respond.

There is no requirement to select a companion or match a weak point. The goal is to learn distance, timing and how much stamina to keep for the next response. Attack spam is a comparison case, not the intended best solution.

Health and stamina remain visible above the action. When either combatant falls, focus clears and the outcome panel offers an immediate Retry. Retry restores both fighters, resets the camera and consumes stale controls before the next attempt. Pause and app interruption freeze the current combat clock and preserve focus selection; returning does not reset the enemy into an unfair surprise or replay a held attack or focus press.

**What we need to learn:** can the player tell why a hit landed, choose a defence deliberately and want another attempt? Automated routes establish rule execution, not those subjective answers. If the duel fails that test, adjust it before adding parry, weapons, another enemy or new artwork.

A purposeful exploration route remains the next proposed experiment after combat: an optional useful find, a harder choice and a shortcut back. It is not part of this scene.
