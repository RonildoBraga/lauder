# Opening M3 — the search, the ambush and Tom

**Date:** 18 November 2026

## Assignment and scope

After M2 and [ADR 0005](decisions/0005-blender-level-editor.md) merged, the maintainer assigned the third milestone of [ADR 0004](decisions/0004-brooklyn-bridge-opening.md): **“Yes, start M3”**. M3 adds searching and loot, the ambush, Tom's shot, recruitment, and following with one companion. Laura, helping her and using the medical kit follow in M4.

Claude implemented and checked M3, so nothing below is an independent review. The [README](../README.md) and [prototype plan](prototype-plan.md#opening--the-brooklyn-bridge) own stage and review status.

## What changed

- **Searching.** Once the stranger is down and his fight is over, standing at his body offers **Search**: the action button reads Search, as other actions do. It is an entry in the level's list of interactions, offered only then, with the same approach, prompt and recheck rules as Relay House's actions. The search takes 1.5 s and adds 6 rounds and a medical kit to the party's small shared inventory. The HUD says “Found 6 rounds and a medical kit.” and from then on shows the medical kit under the objective. Searching again says “Nothing more on him.”
- **The ambush.** The search begins it, as a short scene that plays the same way every time. The scene holds Miki where she stands, though Pause still works:
  1. The attacker steps out from behind the van and runs at her at 5 m/s, and the HUD reads “The attacker is running at you.” The camera leans towards him, as in a fight.
  2. Tom appears just past the van, to the right of Miki's lane, and drops him with one shot, about 8 m short of Miki.
  3. Miki and Tom turn to face each other, and a four-line exchange follows. It gives their names and nothing more.
  4. When it ends, Tom joins: **Next** appears, and he follows in the Close formation.
- **Tom joining.** Tom's body, hidden since load, appears for the scene. The session adds him to the party when the exchange ends, so a Restart during it leaves Miki alone. The squad planner places him in a Close slot, as it places any companion. His waiting spot moves from beyond the first tower to just past the van, so that the scene plays on screen. The first rendered run had him to the left of the lane, where the HUD's panel hid him, so he now stands to the right.
- **Only Miki carries the carbine.** While Tom leads, Fire does nothing.
- **Ownership.**
  - The session owns the beats, now *alone*, *stranger*, *ambush*, then *with Tom*. It also owns the bodies searched, the medical kits in the shared inventory, scripted takedowns such as Tom's shot, and the exchange's effect.
  - The encounter stage owns the attacker's run, Tom's shot on screen and holding the leader during a scene.
  - `BrooklynBridge.swift` holds the search, the attacker and the ambush's timeline. The new positions (the search area, where the attacker hides and steps out to, and Tom's spot) are in the layout file, so they can be edited in Blender.
- **Timelines.** Five cues join the encounter's timeline:
  - taking a body's loot;
  - a member appearing;
  - a member's scripted shot;
  - two members turning to face each other;
  - starting a conversation.

  An encounter can now begin with an action as well as an area, can have no retry when the leader cannot be hurt, and as a scene ends only after its last cue. A hostile can charge as well as shoot.
- **Restart.** Restart also empties the inventory and the searched bodies, hides Tom again, returns the attacker behind the van and ends any scene or exchange. It still adds no entities.

## Checks

- `./scripts/check` passes: 123 Swift tests in 19 suites on the iPhone 17 / iOS 27 Simulator, and the layout script's 13 tests. The `ambush` scenario also runs headless in the check.
- New tests cover:
  - the search: offered only after the fight and only once, its loot taken once, and Restart clearing it;
  - the exchange ending with Tom joining, unless a Restart comes first;
  - the attacker's charge: 5 m/s, stopping at arm's reach, never shooting and never a target;
  - the search offered only at the body once the stranger is down;
  - the scene playing identically three times, with Miki held despite the stick and Fire;
  - Tom's shot landing short of Miki, then Tom joining and following her through the tower;
  - Pause holding the scene, and Restart putting everything back without adding entities.

  Existing tests now cover actions across both levels, the layout's new entries, the fight's retry point being optional and the hostile's target.
- Rendered Simulator runs, in a Debug build:
  - The final `ambush` run passed 35 of 35 steps in 62.5 s. Frames averaged 16.7 ms, with a longest of 33.4 ms, and the party update averaged 0.42 ms, with a longest of 2.0 ms. These are Simulator figures, not phone performance.
  - While moving, Tom stayed within 0.6 m of his slot 93% of the time and never overlapped Miki. The widest gap, 6.1 m, was where he stood when he joined.
  - An earlier round, with Tom placed on the left, also passed `ambush` and `bridge-walk` (37 of 37 steps). Its longest frames, 143 and 149 ms, came at the start of each run.
- The first round's stills showed Tom under the HUD's panel, so he moved to the right. The final stills show the attacker down short of Miki, Tom standing past the van and the HUD showing Miki and Tom, then Tom beside her through the tower's arch.
- In Blender 5.3, Load shows the layout's new area and markers, and Save with no edits finds nothing to change.

## Limits

- The attacker's strike is not built. Tom always drops him first and the scene holds Miki, so it never comes up.
- Tom appears in place rather than stepping into view, and nobody walks during the scene.
- The scene holds Miki for 3.4 s before the exchange. That is deliberate, for a beat that must play the same way every time, but a player may find it long; it is a starting value.
- The medical kit is carried but not used until M4.
- Companions do not fight on their own; Tom's shot is scripted, as ADR 0004 sets out.
- The lines are provisional.
- The checks ran in the Simulator. How the scene reads on the phone, and Tom's following there, are untested.
