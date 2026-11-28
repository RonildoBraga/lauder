# Gameplay walkthrough — a short dungeon journey

**Assigned prototype:** [issue #243](https://github.com/RonildoBraga/lauder/issues/243), following the maintainer's negative duel feedback and basic-armature direction on [#241](https://github.com/RonildoBraga/lauder/issues/241). Implementation is in progress; fresh validation and human acceptance belong in the [prototype plan](prototype-plan.md#basic-rig-dungeon--implementation-in-progress). This anonymous mannequin does not rewrite the preserved [story bible](story/story-bible.md).

You begin at a quiet entry landing with a sword and shield. A closed side gate hints at a connection you cannot yet use. Ahead, a bent passage leads into the first chamber. The camera keeps its selected diagonal orientation while following you; low foreground wall cuts preserve your feet and nearby threats.

A sentry becomes visible through a clear doorway before engaging. Entering its room starts the encounter. You can approach, draw back towards the doorway, guard, dodge or exploit a committed attack's recovery. Focus lets you strafe and backpedal while facing an engaged opponent; it cannot select a guard hidden in another room. The sentry owes its preparation and recovery. Its body and weapon show the attack, with an amber ground warning where scenery permits the full envelope to be shown clearly.

The hero's plain articulated body makes foot placement, weight transfer, the shield and the swing readable. The basic Blender armature drives rigid limb shapes. Hands are simple blocks; sword and shield remain separate. Character skin, clothes, face and finger detail are outside this experiment. Gameplay still decides movement, accepted actions and actual contact.

After defeating the first sentry, continue through the western passage. Exploration continues with your remaining health and stamina. In a small side alcove, a recovery find restores up to 40 health once per life. It remains available if you are already healthy, and cannot be consumed during an active encounter. Taking the detour has an immediate purpose before the next room.

The second sentry guards the next chamber with the same small, readable combat vocabulary and a different opening attack. Only one encounter is active at a time. After clearing it, the western exit completes the route. The northern connection instead loops back towards the entry: approaching the side gate from its far side opens the shortcut, giving a short way back and making the layout recognisable.

If you die, **Return to checkpoint** restores the encounters and the recovery find, while retaining an opened shortcut for the current run. **Restart** on Pause begins everything again, including the gate. Finishing the route offers **Run again**. These are this prototype's explicit reset rules, not a claimed copy of every historical Eitr demo mechanic.

## Controls and interruption

Move with the left stick, touch stick or WASD. Attack uses R1/RB, touch Attack or F; hold L1/LB, touch Guard or Q to defend; Circle/B, touch Dodge or Space makes a short evasive step. R3, touch Focus or Tab toggles facing towards the active enemy. Options/Menu, touch Pause or Escape pauses. E/Cross/A confirms menu choices; touch has dedicated controls. The find and shortcut use proximity, so this experiment adds no interaction button.

Pause freezes the run. Source changes, disconnection and returning to the app require neutral controls before new input. Every captured touch finger must lift, including one resting at the centre of the stick. Returning to checkpoint or restarting also clears pending actions and focus.

## What this experiment should establish

The target is a short route with purposeful approach, readable combat, a useful detour and a satisfying connection back. Its intended first-play length is approximately three to five minutes, not an automatic-playtest duration guarantee. Judge whether movement and contact feel coherent, whether positioning and defence offer useful choices, and whether another attempt is appealing. A larger dungeon, character artwork, extra weapons and progression follow that evidence.
