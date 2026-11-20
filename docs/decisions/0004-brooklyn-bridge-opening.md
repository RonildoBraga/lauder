# ADR 0004 — The Brooklyn Bridge opening

**Status:** Accepted\
**Date:** 18 November 2026\
**Amended:** 20 November 2026, when the maintainer chose to bury the road and everything on it in snow, leaving only the towers ([visual direction](../visual-direction.md#the-bridge-in-the-frozen-world))

## Context

The game begins with Miki alone on the Brooklyn Bridge, trying to cross into Manhattan in a post-apocalyptic New York:

1. Miki crosses alone from the Brooklyn side, among abandoned vehicles and debris, learning to move and explore.
2. A stranger ignores her call of "Friendly!" and opens fire. The player draws and returns fire, which introduces combat.
3. She searches the body. A second attacker comes at her from behind with a knife and is shot by Tom, who then joins her.
4. Further on, the two help an injured woman, Laura, who joins them.
5. The three continue towards Manhattan, which introduces squad movement and formations.

Gameplay comes first: the layout, the story's triggers, combat, scavenging, recruitment and squad movement were built on a greybox before art. The look then moves to the [visual direction](../visual-direction.md)'s frozen low-poly world. The three meet as strangers, and their backgrounds unfold gradually. The architecture should stay simple, reusable and consistent with good engineering practice.

## Decision

**One owner for each fact, content as typed data, and systems in plain Swift that tests can run without rendering.** No ECS, third-party package, scripting language or engine change.

### 1. The bridge

The bridge's road and towers are at their published sizes, from Wikipedia, Structurae and STRUCTURE magazine; the 1.8 km crossing as a whole is compressed to the stretch the player walks.

- **The deck** is 644 m long and 25.9 m wide, as wide as the two roadways of 10.3 m, each as wide as a tower's arch, and the 5.3 m median between them. Snow has buried it, with the frozen river below, under a plain level with it, and an invisible edge at its width keeps the party on it.
- **The towers** stand 486.3 m apart. Each is 43 m wide, 18 m deep and 47 m above the road, with arches 10.3 m wide and 35.7 m tall.
- **Only the road and the towers** mimic the real bridge: there are no cables, suspenders or raised walkway. The floor is flat; slopes and climbing are out of scope.
- **Only the towers** stand above the snow, and they are the only cover: the first fight and the ambush happen at the first tower, around its pier.

Each beat has its own stretch, so the player walks between them:

| Stretch | From the Brooklyn end | Beat |
|---|---|---|
| Brooklyn approach | 0–90 m | Alone: movement, the camera, looking around |
| First tower | 90–125 m | The stranger: "Friendly!" and the first fight; searching the body, the knife attack, Tom |
| Mid-span | 125–586 m | Laura on the ground, at about 360 m; helping her |
| Second tower to Manhattan | 586–644 m | Three together; the end of the opening |

At the party's 2.6 m/s, the walks from the first tower to Laura and from Laura to the second tower each take about 90 s, and the whole crossing about four minutes. The navigation grid covers about 420,000 cells, built once at load.

A position is a Float, whose spacing grows with its distance from the origin: about 30 µm at the Manhattan end. The check of a straight move allows one Float spacing at its points, never less than a micrometre, well inside the 2 mm collision skin, so a body stopped against the edge far from the origin can still move away.

### 2. Levels are values

A `Level` value holds a place's floor, blocker boxes, points of interest, interactions, trigger areas, encounters, starting party, spawn points, heading, camera and lights, and the name of its scene file. The bridge's look and layout come from its Blender file ([ADR 0002](0002-blender-source-of-truth.md)); `BrooklynBridge.swift` adds the words and refers to the layout's entries by name. `GameWorld`, `NavigationGrid` and the session take the level they are given, so tests can build small levels of their own.

### 3. The party grows during play

`GameSession` holds the recruited members, starting with Miki alone, and a `recruit` command. Switching cycles only through recruited members, and the HUD hides **Next** until there are two. All three bodies are created at load, so Restart adds no entities: Tom waits out of sight until his beat, and Laura lies at her spot. `SquadPlanner` and `GameWorld` take the recruited companions, so Tom follows alone in the Close formation until Laura joins ([ADR 0003](0003-squad-movement.md)). From then on the formation button cycles Close, Spread and Column (M5), and squad orders send companions to a point or hold them there ([ADR 0003](0003-squad-movement.md)'s phase S3).

### 4. A story director runs the beats

`GameSession` owns the opening's progress as ordered beats:

**Alone → Stranger → Searching → Ambushed → With Tom → Laura found → With Laura → Onwards**

- **Triggers.** Each beat has a trigger area. Each step, the world checks the leader against the next beat's area and asks the session to start it. The session accepts beats only in order, so none fires twice or out of sequence.
- **Timelines.** A beat can run a short timeline: lines of dialogue, an enemy waking, a scripted shot, a turn of the camera. `StoryDirector` plays it in the fixed simulation step, so tests play a beat deterministically.
- **Dialogue.** Short speaker-labelled lines; a step takes effect when its conversation ends, and nothing branches. The lines are provisional and brief, and reveal nothing about anyone's past beyond what the moment needs.

| Beat | Starts when | Timeline |
|---|---|---|
| Stranger | Miki comes through the first tower's arches | The stranger steps out from behind the pier. Miki calls "Friendly!" He aims and fires a scripted near miss, and the HUD shows how to fire |
| Ambushed | Miki starts searching the body | An attacker runs at her out of the tower's west arch. Tom, coming out of the east arch, drops him before he reaches her. Miki turns; a short exchange; Tom joins |
| Laura found | The party nears her, beyond mid-span | Laura lies in the snow, and Miki can **Help**. The exchange gives only her name. With the medical kit from the first body she can stand, and she joins |
| Onwards | The three reach the Manhattan end | The party stops for a short closing exchange. It waits until both companions are within 5 m of the leader, so companions left holding must be called back first |

### 5. Combat, small and plain

The `combat` folder holds plain-Swift types that the world drives each step:

- **Assisted aim.** **Fire** shoots at the assisted target, the nearest hostile ahead within range and in sight, marked on screen. The first press draws the weapon, which is holstered while exploring, so a quiet walk never starts a fight by accident. There is no manual aiming on a phone.
- **Line of sight and cover.** A shot is a ray against the same blocker boxes that collision uses, so the towers give real cover to both sides.
- **Enemies.** A small state machine for each enemy, defined as data: hidden, alert, attacking (a visible wind-up, then a shot) and down. The knife attacker approaches and strikes. The stranger's wind-up is long enough to teach the player to answer it.
- **Damage.** The [placeholder hit rule](../encounters/the-quiet-yard.md#placeholder-hit-rule): Miki can take three hits, shown beside her name, and enemies two. On a third hit the screen fades and the encounter starts again, with nothing lost. It is a short retry in memory, not a save.
- **Ammunition.** One count for Miki's carbine, shown on the HUD. Firing spends it, and searching bodies refills it. No reloading, weapon changes or upgrades.
- **Ownership.** Health, ammunition, which enemies are down and which bodies have been searched are the session's facts. Enemy positions and shots belong to the world, which keeps no second copy of progress.
- **Companions.** Tom's rescue shot is scripted. Companions fighting on their own, signature abilities and taking cover come with a later encounter.

### 6. Searching and helping are interactions

A downed enemy adds a **Search** interaction around the body: an entry in the level's interactions, added during play, with the same approach, prompt and recheck rules. Searching takes about a second and a half and puts its loot, ammunition and a medical kit, into a **small shared inventory** in the session, and it is where the ambush begins. **Help** beside Laura works the same way. There are no per-character inventories.

### 7. Input

**Fire** joins the intents: R2 or RT, a touch **Fire** button that appears once the weapon can be used, and F in the Simulator. It passes through `InputRules` with the shared priority, fresh-press and release rules.

### 8. Restart, tests and playtests

Restart returns to the Brooklyn end with Miki alone, the Close formation with no orders and every beat, enemy and piece of loot reset, without adding entities. Unit tests cover beat order, triggers firing once, targeting, line of sight, hits, loot, recruitment, formations, orders and Restart. Scripted playtests run through the real controls: `bridge-walk`, `first-fight`, `fight-retry`, `ambush`, `laura`, `opening` for the whole sequence, `formations` and `orders`.

### 9. `GameWorld` stays manageable

`GameWorld` keeps the bodies, camera, update loop and prompts. `StoryDirector` (triggers and timelines), the combat types (enemies, shots and targeting) and `EncounterStage` are separate types that it owns, each in plain Swift with its own tests.

## Options considered

| Option | Why not |
|---|---|
| A general quest or scripting system, or levels in JSON | More machinery than five beats need; typed Swift data is checked by the compiler |
| Manual aiming with a second stick | Hard on a phone; the agreed combat identities ask for assisted aim |
| Creating companions when they are recruited | Breaks Restart's guarantee of adding no entities, for little gain |
| The whole 1.8 km crossing at real length | Long walks with nothing in them; the main span alone gives the towers their real distance |

## Milestones

| Milestone | Adds | State |
|---|---|---|
| **M1** The bridge, Miki alone | Levels as values, the bridge, a party of one, trigger areas, Restart | Built |
| **M2** The first fight | Fire, assisted aim, line of sight, hits, the stranger, the retry | Built |
| **M3** Search, ambush, Tom | Searching and loot, the ambush, Tom's shot, recruitment, following with one companion | Built |
| **M4** Laura and onwards | Helping, the medical kit, the third member, the end of the opening | Built |
| **M5** Formations | [ADR 0003](0003-squad-movement.md)'s phase S2 on the open deck | Built |

## What this does not settle

Final art and animation, the characters' backgrounds and relationships, final dialogue, signature abilities, companion combat, enemy variety, saving, and what follows the bridge.
