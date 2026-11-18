# ADR 0004 — the Brooklyn Bridge opening

**Status:** Accepted by the maintainer on 18 November 2026 ([“Accept as recommended”](https://github.com/RonildoBraga/lauder/pull/40#issuecomment-6971154778)), including the nine recommendations at the end. Each milestone is a separate assignment. M1 is [implemented](../opening-m1.md) and merged; later milestones are not assigned.\
**Date:** 18 November 2026\
**Deciders:** Maintainer\
**Author:** Claude

## Context

On 18 November 2026 the maintainer asked to change how the game begins: **“I want the game to begin with Miki alone on the Brooklyn Bridge, trying to cross into Manhattan in a post-apocalyptic New York.”** The requested sequence:

1. Miki crosses alone from the Brooklyn side, among abandoned vehicles and debris, learning to move and explore.
2. A stranger ignores her call of "Friendly!" and opens fire. The player draws and returns fire, which introduces combat.
3. She searches the body. A second attacker comes at her from behind with a knife and is shot by Tom, who then joins her.
4. Further on, the two help an injured woman, Laura, who joins them.
5. The three continue towards Manhattan, which introduces squad movement and formations.

The request asks for greybox geometry only, and for the level layout, narrative triggers, combat, scavenging, recruitment and squad movement to come first. The characters meet as strangers, and their backgrounds unfold gradually. Before anything is built, it asks for **“how we can adapt it to this new opening sequence while keeping the architecture simple, reusable, and consistent with good software engineering standards.”**

### What exists

The current build is the Relay House slice, Parties A to C. Most of it carries over:

| Part today | What it does | In the new opening |
|---|---|---|
| `GameSession` | Sole authority for mode (exploring, dialogue, paused), leader, mission phase, flags, conversation and pause menu | Kept. Gains party membership, story beats, combat facts and a small shared inventory |
| `InputRules`, `GameControls`, touch | One intent path for controller, touch and keyboard, with priority and release rules | Kept. Gains **Fire** |
| `PartyMotion` | Plain-Swift collision of round bodies against axis-aligned boxes | Kept, and reused for line of sight |
| `NavigationGrid`, `SquadPlanner`, `CompanionMotor` | Squad following ([ADR 0003](0003-squad-movement.md) phase S1) | Kept. Work with one or two companions instead of always two |
| `PrototypeLayout` | One hard-coded 28 m × 20 m layout: boxes, points, interactions and spawns | Becomes one instance of a level value; the bridge is another |
| Interactions | Authored approach areas, eligibility and prompts, rechecked on every press | Kept for searching and helping. Gains entries that appear during play, such as a body to search |
| `MissionScript` | Short speaker-labelled lines and objectives | Kept as the pattern; the bridge gets its own script |
| `GameWorld` | Bodies, camera, update loop, prompts and Restart, in 645 lines | Kept as the owner of spatial state, with story and combat in separate types |
| Playtests | Scripted Debug runs through the real controls, headless and rendered | Kept; each beat gets a scenario |

### What conflicts with agreed documents

The opening changes things the maintainer agreed earlier, so it needs an explicit decision rather than a quiet rewrite:

- The story bible's agreed direction says **“Three playable characters are present together”** and **“Chapter One centres on restoring a transmitter through exploration and purposeful salvage.”** The opening starts with Miki alone and recruits two strangers; the transmitter story would move later or go.
- Its premise has Miki and Lara already trusting each other. The opening makes all three strangers.
- Its places (the Basin, East Span, Relay House, Old Lock) are fictional working names. The opening is set in New York.
- It says **“Combat is occasional and light.”** The opening has two hostile encounters in its first minutes. That still fits if combat stays occasional afterwards.
- The request names **Tom** and **Laura**; the documents and code use **Tomas** and **Lara**.
- The agreed [combat identities](../story/story-bible.md#combat-identities) give Tomas a close-range scatter weapon, so his rescue shot comes from close by, unless his identity changes. Miki's precision carbine suits her first fight.
- The prototype plan lists combat and health as outside the first playable, and its [combat design review gate](../prototype-plan.md#combat-design-review-gate) requires settled design choices and an explicit assignment before combat is built. This record settles those choices; each milestone still needs its own assignment.

## Decision

**Extend the existing structure: one owner for each fact, content as typed data, and systems in plain Swift that tests can run without rendering.** No engine change, ECS, third-party package, scripting language or level editor.

### 1. Levels become values

The static `PrototypeLayout` becomes a `Level` value with the same contents (bounds, blocker boxes with their sizes, points of interest, interactions and spawn points) plus **trigger areas**, **enemy placements** and **recruit positions**. `Level.relayHouse` keeps today's content and `Level.brooklynBridge` is new. `GameWorld`, `NavigationGrid` and the scene dressing take a level instead of reading the enum, so tests can also build small levels.

**The bridge greybox** is a flat, compressed deck about 240 m long and 24 m wide; the real crossing is about 1.8 km. Grey blocks give the recognisable shapes: two stone towers whose paired arches the roadway passes through, cables as thin lines that do not collide, and the raised central walkway, shown but not walkable because the floor stays flat and slopes and climbing remain out of scope. Lanes of abandoned cars, a bus and debris shape the routes and give cover. Each beat has its own stretch, so the player walks between them:

| Stretch | From the start | Beat |
|---|---|---|
| Brooklyn approach | 0–50 m | Alone: movement, camera, looking around |
| Before the first tower | 50–90 m | The stranger: "Friendly!" and the first fight |
| First tower | 90–110 m | Searching the body, the knife attack, Tom |
| Mid-span | 110–190 m | Laura on the ground; helping her |
| Second tower to Manhattan | 190–240 m | Three together; formations; the end of the slice |

At today's 0.2 m cells, the navigation grid for this deck has about 144,000 cells, ten times the current layout. It is built once at load. If that proves slow on the phone, the fallbacks are coarser cells or one grid per stretch.

### 2. The party grows during play

`GameSession` gains the **recruited members**, starting with Miki alone, and a `recruit` command. Switching cycles only through recruited members, and the HUD hides **Next** until there are two. All three bodies are still created at load, so Restart keeps its rule of adding no entities: Tom waits out of sight until his beat, and Laura lies at her spot. `SquadPlanner` and `GameWorld` take the recruited companions instead of assuming two, so Tom follows alone in the Close formation until Laura joins.

### 3. A story director runs the beats

`GameSession` owns the opening's progress as ordered beats, as it owns Party C's phases:

**Alone → Stranger → Searching → Ambushed → With Tom → Laura found → With Laura → Onwards**

- **Triggers.** Each beat has a trigger area on the deck. Each step, the world checks the leader against the next beat's area and asks the session to start it. The session accepts beats only in order, so none fires twice or out of sequence.
- **Timelines.** A beat can run a short timeline: lines of dialogue, an enemy waking, a scripted shot, a turn of the camera. A `StoryDirector` beside `GameWorld` plays it in the fixed simulation step, so tests can play a beat deterministically.
- **Dialogue.** The bridge gets its own script in the existing style: short speaker-labelled lines, a step taking effect when its conversation ends, and no branching. Lines stay provisional and brief, and reveal nothing about anyone's past beyond what the moment needs.

| Beat | Starts when | Timeline |
|---|---|---|
| Stranger | Miki nears the first tower's approach | The stranger steps out. Miki calls "Friendly!" He aims and fires, a scripted near miss, and the HUD shows how to fire |
| Ambushed | Miki starts searching the body | An attacker runs at her from behind a van. Tom, close by, drops him before he reaches her. Miki turns; a short exchange; Tom joins |
| Laura found | The party nears mid-span | Laura crawls beside a car, and Miki can **Help**. The exchange gives only her name. With the medical kit from the first body she can stand, and she joins |

### 4. Combat, small and plain

A new `combat` folder holds plain-Swift types that the world drives each step:

- **Assisted aim.** **Fire** shoots at the assisted target, the nearest hostile ahead within range and in sight, marked on screen. The first press draws the weapon, which is holstered while exploring, so a quiet walk never starts a fight by accident. There is no manual aiming on a phone.
- **Line of sight and cover.** A shot is a ray against the same blocker boxes that collision uses, so cars give real cover to both sides.
- **Enemies.** A small state machine for each enemy, defined as data: hidden, alert, attacking (a visible wind-up, then a shot) and down. The knife attacker approaches and strikes. The stranger's wind-up is long enough to teach the player to answer it.
- **Damage.** The [placeholder hit rule](../encounters/the-quiet-yard.md#placeholder-hit-rule) from The Quiet Yard: Miki can take three hits, shown beside her name, and enemies two. On a third hit the screen fades and the encounter starts again, with nothing lost. This is a short retry in memory, not a save.
- **Ammunition.** One count for Miki's carbine, shown on the HUD. Firing spends it and searching bodies refills it. No reloading, weapon changes or upgrades yet.
- **Ownership.** Health, ammunition, which enemies are down and which bodies have been searched are facts the session owns. Enemy positions and shots belong to the world, which keeps no second copy of progress.
- **Companions.** Tom's rescue shot is scripted. Companions fighting on their own, signature abilities and seeking cover (ADR 0003 phase S4) come with a later encounter.

### 5. Searching and helping are interactions

A downed enemy adds a **Search** interaction around the body: an entry in the existing interaction list, added during play, with the same approach, prompt and recheck rules. Searching takes about a second and a half and adds its loot, ammunition and a medical kit, to a **small shared inventory** in the session. It is also where the ambush begins. Laura's **Help** works the same way. There are still no per-character inventories.

### 6. Input

**Fire** joins the intents: R2 or RT, a touch **Fire** button that appears once the weapon can be used, and a Simulator key. It passes through `InputRules` with the existing priority, fresh-press and release rules. The touch layout stays within the five buttons of the [proposed input budget](../gameplay-script.md#future-squad-and-combat-design).

### 7. Restart, tests and playtests

Restart returns to the Brooklyn end with Miki alone and every beat, enemy and piece of loot reset, without adding entities. Each milestone adds unit tests (beat order, triggers firing once, targeting, line of sight, hits, loot, recruitment and Restart) and a playtest scenario through the real controls: `bridge-walk`, `first-fight`, `ambush`, `laura`, and `opening` for the whole sequence. The Relay House scenarios keep running against that level.

### 8. Keeping `GameWorld` manageable

At 645 lines, `GameWorld` should not absorb the story and combat as well. It keeps the bodies, camera, update loop and prompts. `StoryDirector` (triggers and timelines), `Combat` (enemies, shots and targeting) and level building become separate types that it owns, each in plain Swift with its own tests.

## Options considered

| Option | Why not |
|---|---|
| A second app target or a new project for the bridge | Duplicates input, session and movement code that already works |
| A general quest or scripting system, or levels in JSON | More machinery than five beats need; typed Swift data is checked by the compiler, as the architecture already decided |
| Manual aiming with a second stick | Hard on a phone; the agreed combat identities ask for assisted aiming |
| Creating companions when they are recruited | Breaks Restart's guarantee of adding no entities, for little gain |
| A bridge at real length | 1.8 km of walking adds nothing to a greybox and multiplies the navigation grid |

## Consequences

- The game starts on the bridge, and the Relay House slice stops being the opening.
- With M1, the story bible, the Chapter One outline, the gameplay walkthrough, the prototype plan and the architecture change to match the decisions below. Until then they describe the Relay House slice.
- Combat enters the first playable, which the prototype plan now excludes.
- ADR 0003 continues unchanged: phase S1 already moves companions independently, and S2 follows once Laura joins.

## Milestones

Each is a separate assignment and pull request, with `./scripts/check`, Simulator playtests and a maintainer playtest:

| Milestone | Adds | Exit check |
|---|---|---|
| **M1** The bridge, Miki alone | `Level` values, the bridge greybox, a party of one, trigger areas, Restart | Miki walks the whole deck without snagging and the camera reads well; each trigger fires once; Relay House still passes its tests |
| **M2** The first fight | Fire, assisted aim, line of sight, hits, the stranger, the retry | A new player answers the stranger without help, with touch and with a controller; cover works for both sides |
| **M3** Search, ambush, Tom | Searching and loot, the ambush timeline, Tom's shot, recruitment, following with one companion | The beat plays the same way every time; Tom follows along the deck without snagging |
| **M4** Laura and onwards | Helping, the medical kit, the third member, the end of the slice | The whole opening plays through; a phone checkpoint for controls, combat feel and frame pacing |
| **M5** Formations | ADR 0003 phase S2 on the open deck | As ADR 0003 sets out |

Stop rule: if the first fight is not readable on the phone after three focused work sessions on M2, stop and reassess with the maintainer.

## What this does not settle

Final art and animation, the characters' backgrounds and relationships, final dialogue, signature abilities, companion combat, enemy variety, saving, and what follows the bridge.

## Decisions

The maintainer [accepted these as recommended](https://github.com/RonildoBraga/lauder/pull/40#issuecomment-6971154778) on 18 November 2026. They are kept here as proposed.

1. **Names.** Are Tom and Laura renames of Tomas and Lara? Recommended: yes, renamed in code and documents with M1.
2. **Story foundations.** Replace the agreed opening (three travellers together, Chapter One's transmitter and the fictional places) with the bridge, strangers meeting and New York, and update the story bible and Chapter One outline with M1. Recommended.
3. **The Relay House slice.** Keep it as a second level that the tests still cover, and decide later whether the transmitter returns after the bridge. Recommended; the alternative is to retire it.
4. **The bridge.** A compressed, flat greybox about 240 m long, with each beat in its own stretch. Recommended.
5. **The first fight.** Assisted aim with one Fire control that draws on the first press, cover by line of sight, telegraphed enemy shots, the placeholder hit rule with a retry of the encounter, and one ammunition count. Recommended.
6. **"Friendly!"** Spoken automatically as Miki nears the stranger. Recommended, rather than a button.
7. **Tom's rescue.** Fully scripted, from close by. Recommended, rather than a timed challenge.
8. **Searching and Laura.** One shared inventory, with the medical kit from the first body used to help Laura. Recommended.
9. **Order of work.** M1 to M5 as above, each assigned separately. Recommended.
