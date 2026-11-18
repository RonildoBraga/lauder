# The Brooklyn Bridge opening — milestone record

**Updated:** 18 November 2026

[ADR 0004](decisions/0004-brooklyn-bridge-opening.md) builds the opening in five milestones, each assigned separately. This record keeps what each one built, how it was checked and what it leaves open; each new milestone adds a section. The [README](../README.md) and the [prototype plan](prototype-plan.md#opening--the-brooklyn-bridge) own stage and review status.

Claude implemented and checked each milestone, so nothing here is an independent review. The full records as they were merged are in [docs at `a6b23a9`](https://github.com/RonildoBraga/lauder/tree/a6b23a9/docs). Simulator figures below come from Debug builds and are not phone performance.

## M1 — the bridge, Miki alone

The maintainer accepted ADR 0004 (**“Accept as recommended”**), then assigned its first milestone: **“Yes, start M1”**.

- **Levels are values.** A `Level` holds a place's floor, blocker boxes, points of interest, interactions, trigger areas, starting party, spawn points, starting heading and camera. The world, the session, the navigation grid and the scene dressing take the level they are given. The app opens on the bridge.
- **The bridge.** A flat deck about 250 m long and 24 m wide, Brooklyn at +z and Manhattan at −z. Two roadways run either side of the raised walkway's base, which has collapsed in a 12 m gap at mid-span. Two granite towers stand 100 m and 200 m from the start, with arches 14 m high so the camera, 10 m up, passes through behind Miki. The walkway on posts, the cables with suspenders and stays, the lane lines and the river 30 m below are decoration that blocks nothing. Cars, a van, a truck and debris stand where the later scenes need them. A bus jammed across the east roadway sends the route through the gap, and barricades close both ends. A checkpoint booth, the bus and the Manhattan barricade can be looked at.
- **Lines that show once.** Six trigger areas each show a line the first time Miki enters them in a run: cars ahead, the first tower, mid-span, the blocked lanes, the second tower and the Manhattan end. They do not fire while paused, and Restart clears them.
- **A party of one.** The session holds who has joined, in switching order. **Next** stays hidden until there is someone to switch to. Tom's and Laura's bodies are created at load but stay hidden, out of movement and out of the squad, at the places their scenes use.
- **Camera.** The bridge keeps the accepted height and distance but looks straight along the deck, so pushing up walks towards Manhattan.
- **Navigation grid.** Each obstacle checks only the cells within its reach, which gives exactly the grid that checking every cell would. The bridge's grid has about 150,000 cells and is built once at load.
- **Names.** Tom and Laura replace Tomas and Lara in code and in the living documents; dated records and accepted ADRs keep the names they were written with.

**Checks.** `./scripts/check` passed with 97 tests. The rendered `bridge-walk` run passed 31 of 31 steps in 99.6 s, with frames averaging 16.7 ms and a longest of 33.4 ms.

**Merge.** The build was installed on the baseline iPhone, and the maintainer [authorised the merge](https://github.com/RonildoBraga/lauder/pull/41#issuecomment-6971880003): **“Yes, merge both”**. No observations from playing it were reported, so whether the camera reads well, part of M1's exit, is unrecorded.

## M2 — the first fight

The maintainer assigned the second milestone: **“Yes, start M2”**.

- **Fire.** R2 or RT, **F** in the Simulator, and a touch **Fire** button that appears when the fight begins. It passes through `InputRules` like every other intent: a fresh press, a hold, consumed while paused or in a conversation, and part of the release gate. The first press draws Miki's carbine, which takes 0.35 s, so a quiet walk never starts a fight. Held, it fires every 0.4 s.
- **Assisted aim.** Fire shoots at the nearest hostile within 14 m and in sight, preferring one within 75° of where Miki faces, and a red disc marks the target. There is no manual aiming. A hostile becomes a target only once it has opened fire, so Miki cannot shoot the man she has just called out to; that is an implementation choice for playtesting, not part of the ADR.
- **Line of sight and cover.** A shot is a straight line against the same blocker footprints that movement uses, so cars give cover to both sides.
- **The stranger.** He waits unseen behind the car turned across the east roadway, before the first tower. When Miki comes within about 10 m he steps out, she calls “Friendly!”, and a second later he starts to aim. Before each shot a red line runs from him to her for 1.5 s and the HUD warns of it; after it he pauses for 1.4 s. His first shot misses on purpose, and the HUD then says “He opened fire. Fire back, or take cover.” He stands his ground.
- **Keeping the fight on screen.** The first rendered runs showed the stranger above the top of the screen. Now the fight begins nearer, and while a hostile stands in the open the camera's target leans up to 3 m towards him. Both weapons reach 14 m, about what the camera shows ahead, so nobody is shot from off screen.
- **Hits and rounds.** The [placeholder hit rule](encounters/the-quiet-yard.md#placeholder-hit-rule): Miki can take three hits, shown as pips, and the stranger two. The carbine starts with 12 rounds. When the stranger is down the fight ends and Miki's hits recover.
- **The retry.** On the third hit the screen fades out over 0.6 s, the fight is put back as it began with Miki just short of the cars and “Try again.”, and the screen fades in over 0.4 s. Pause holds both the fight and the fade.
- **Ownership.** The session owns the beat, the hits, the rounds, who is down and the retry's checkpoint. `EncounterStage` holds the hostiles' bodies and moment-to-moment state, `StoryDirector` plays the timed cues, and the combat rules are plain Swift.

**Checks.** `./scripts/check` passed with 115 tests, including the `first-fight`, `fight-retry` and `bridge-walk` scenarios driven without rendering. The final rendered runs passed: `first-fight` 23 of 23 steps, `fight-retry` 19 of 19 and `bridge-walk` 37 of 37, with frames averaging 16.7 ms.

**Phone playtest.** Claude installed a Release build of `3cb982c` on the baseline iPhone 13 Pro Max. After playing it, the maintainer reported **“It read well”** and [authorised the merge](https://github.com/RonildoBraga/lauder/pull/42#issuecomment-6973249055): **“Yes, merge it”**. That summary does not say who played or which inputs were used, so a new player's first unaided try with touch and with a controller, M2's exit, is still worth confirming. No frame pacing was measured.

## M3 — the search, the ambush and Tom

The maintainer assigned the third milestone: **“Yes, start M3”**.

- **Searching.** Once the stranger is down and his fight is over, standing at his body offers **Search**. The search takes 1.5 s and adds 6 rounds and a medical kit to the party's small shared inventory; the HUD then shows the medical kit under the objective. Searching again says “Nothing more on him.”
- **The ambush.** The search begins a short scene that plays the same way every time and holds Miki where she stands, though Pause still works. The attacker steps out from behind the van and runs at her at 5 m/s; Tom appears just past the van, to the right of Miki's lane, and drops him with one shot about 8 m short of her; they turn to each other, and a four-line exchange gives their names.
- **Tom joining.** When the exchange ends, the session adds Tom to the party, **Next** appears, and he follows in the Close formation. A Restart during the exchange leaves Miki alone. His waiting spot is just past the van; the first rendered run had him to the left of the lane, under the HUD's panel, so he moved to the right.
- **Only Miki carries the carbine.** While Tom leads, Fire does nothing.
- **Timelines.** New cues take a body's loot, show a member, fire a member's scripted shot, turn two members to each other and start a conversation. An encounter can begin with an action as well as an area, needs no retry when the leader cannot be hurt, and as a scene ends only after its last cue. A hostile can charge as well as shoot.

**Checks.** `./scripts/check` passed with 123 tests, including the `ambush` scenario driven without rendering. The final rendered `ambush` run passed 35 of 35 steps in 62.5 s, with frames averaging 16.7 ms; while moving, Tom stayed within 0.6 m of his slot 93% of the time and never overlapped Miki. In Blender, Load showed the new markers and area, and Save with no edits changed nothing.

**Phone playtest.** Claude installed a Release build of `95bf857` on the baseline iPhone and uploaded TestFlight build 0.1.0 (2) from `ecb1031`, which differs only in its build number. After playing M3, the maintainer reported **“It played well”**, then [authorised the merge](https://github.com/RonildoBraga/lauder/pull/44#issuecomment-6975896955): **“Yes, merge both”**. Codex's automatic review found nothing; no independent review was requested. The summary does not say how often the scene was played or which inputs were used, and no frame pacing was measured.

## Open across the opening

- **The phone checkpoint** for controls, combat feel and frame pacing comes with M4. The bridge's frame pacing on the phone, with the fight and with Tom following, is unmeasured.
- **The timings and distances** — the 1.5 s wind-up, the 1.4 s pause, the 14 m reach, the 3 m camera lean, the 0.35 s draw, 0.4 s between shots, 12 rounds, the loot and the 3.4 s the ambush holds Miki — are starting values for playtests. The lines are provisional.
- **The stranger stands still** once he has stepped out, and bodies do not block movement. Nothing holsters the carbine after a fight. If Miki walks on without fighting, the stranger's fight stays open, and the story cannot move on without it.
- **The attacker's strike is not built:** Tom always drops him first. Tom appears in place rather than stepping into view, and nobody walks during the scene. Companions do not fight on their own; Tom's shot is scripted.
- There is no sound, muzzle flash, hit reaction or animation.
- The towers' upper parts and the cables' high sections are above the camera, so the bridge reads mostly at deck level.
