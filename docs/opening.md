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

## M4 — Laura and the end of the opening

The maintainer assigned the fourth milestone, **“Yes, start M4”**, and after the cleanup in #46 started it: **“Yes, merge and start”**.

- **Laura lies hurt in view.** As ADR 0004 set out, her body is in the scene from the start, lying face down beside the car just past the gap in the divider, across the camera's view so the pose reads from above. She stays out of movement and the squad until she joins; M1 had hidden her.
- **Found.** Once Tom has joined, walking onto the west roadway near her starts the *Laura found* beat. She calls out, "Please. Over here.", the camera leans most of the way towards her so that she shows clear of the HUD's panel, and Miki answers. The objective becomes "Help the woman between the cars." The first rendered run had her calling out from under the panel, lying along the camera's view where she looked as if she were standing; the camera's lean and the turned pose fixed both.
- **Help.** Beside her the action reads **Help**, for whoever leads; a press while she is still calling out does nothing. It uses the medical kit from the stranger's body and begins a short scene that holds the party, whoever leads: she stands, she and Miki turn to each other, and a four-line exchange gives her name. When it ends she joins, and Tom and Laura follow in the Close formation.
- **The end of the opening.** Reaching the Manhattan end with all three stops the party for a three-line closing exchange, and the objective then reads "Manhattan, together." Without Laura the end does not start, and the objective keeps pointing to her.
- **How it is built.**
  - Four beats join the story: Laura found, helping her, with Laura, and arrived.
  - A level can have members lying hurt where they wait, objectives that change from a beat on, and encounters with no hostiles, which end after their last cue. A scene can name a focus for the camera.
  - A new cue stands a member up, and the cue that turns two people to each other now names both.
  - Help is an interaction like Search; the session owns the kit, the beats and Laura joining.
  - Restart puts Laura back on the deck, hurt, and resets everything else without adding entities.
  - The `laura` and `opening` playtests join the others. A conversation that starts during a scripted walk ends that walk step, as the closing exchange does.

**Checks.** `./scripts/check` passes with 108 Swift tests in 17 suites on the iPhone 17 / iOS 27 Simulator, and the layout script's 22 tests, including all six scenarios driven without rendering. The new tests cover:

- Help offered only after Tom joins and Laura is found, doing nothing while she calls out, using the kit once;
- the end starting only with all three;
- Laura lying in view at the start;
- the whole sequence in play: the call-out with the camera's lean and its return, the Help prompt, the scene holding the party, Laura standing, the exchange, both companions following, the closing exchange, and Restart putting her back without adding entities;
- after Copilot's review, Help with Tom leading, and the lead passing to Tom during the scene: everyone keeps their place, and Miki and Laura face each other for the exchange.

The final rendered Simulator runs, in a Debug build, passed: `laura` 52 of 52 steps in 92.9 s and `opening` 58 of 58 in 112.4 s. Frames averaged 16.7 ms, and the only frames over 34 ms were each run's first. While moving, the companions stayed within 0.6 m of their slots 88% and 93% of the time and never overlapped. The stills show Laura lying across the lane as she calls out, clear of the panel, then standing to face Miki, then the three together and “Manhattan, together.”. In Blender 5.3, Load shows Laura's two new areas, and Save with no edits finds nothing to change.

**First phone sample.** TestFlight build 0.1.0 (3), archived at `c6af7c1`, which differs from `b7cb98f` only in its build number, was installed from TestFlight on the baseline iPhone 13 Pro Max (iOS 27.2.1). When the maintainer asked for it (**“Record now”**), Claude recorded two minutes with Instruments' Game Performance Overview. After the first 15 s, Lauder held **60.00 fps** over 102.8 s: every frame took one 60 Hz interval (16.67 ms), with none longer and none skipped. The thermal state was Fair for the first 96 s, then Nominal. It is a single short sample: it shows neither sustained nor thermal performance, and it does not record which part of the opening was played or with which input. A first attempt stopped after 1.4 s, when the phone's connection dropped.

**Phone checkpoint.** For a full run on the final code, Claude installed a Release build of `097ac67`, which includes the fix after Copilot's review, directly on the same phone over a cable. When the maintainer asked for it (**“Record now”**), Lauder restarted from the beginning and Claude recorded five minutes of the maintainer's play. After the first 15 s, Lauder held **59.97 fps** over 277 s, with frames averaging 16.67 ms. Four frames ran long, two of 50.0 ms and two of 33.3 ms, about 30, 43, 47 and 90 s into the run; their cause is unknown. The thermal state stayed Fair. The maintainer then reported: **“I did not noticed any stutters and everything worked as expected”**. The report does not say which inputs were used, how far the run went, or whether Pause and Restart were tried; Codex's automatic review of `b7cb98f` found nothing, and Copilot's one finding, on `3427d21`, was fixed before this run.

## Open across the opening

- **On the phone,** the maintainer's report does not say which inputs were used, so a new player's first unaided try with touch and with a controller is still worth confirming. The full run's four long frames are unexplained, and sustained play over 15 to 20 minutes, with thermals, is unmeasured.
- **The timings and distances** — the 1.5 s wind-up, the 1.4 s pause, the 14 m reach, the camera's leans, the 0.35 s draw, 0.4 s between shots, 12 rounds, the loot, and how long the scenes hold the party — are starting values for playtests. The lines are provisional.
- **The stranger stands still** once he has stepped out, and bodies do not block movement. Nothing holsters the carbine after a fight. If Miki walks on without fighting, the stranger's fight stays open, and the story cannot move on without it.
- **The attacker's strike is not built:** Tom always drops him first. Tom appears in place rather than stepping into view, and nobody walks during the scenes. Laura lies still rather than crawling, and stands up in place. Companions do not fight on their own; Tom's shot is scripted.
- There is no sound, muzzle flash, hit reaction or animation.
- The towers' upper parts and the cables' high sections are above the camera, so the bridge reads mostly at deck level.
