# Lauder — bridge-only prototype

**Updated:** 22 November 2026

**Status:** The maintainer requested a smaller starting point before a gameplay revamp: keep the Brooklyn Bridge and delete the other playable scenes and their unused systems. [ADR 0017](decisions/0017-bridge-only-reset.md) records the boundary. New mechanics and scenes await a design decision.

## Purpose and scope

Use the retained bridge to decide what is enjoyable before expanding again. This cleanup preserves its existing opening, party movement, native weapons and input paths. It does not redesign the story or author a replacement core loop.

The story's foundations remain in the [story bible](story/story-bible.md). Exploration and salvage lead the intended game, with occasional combat; the current opening only samples movement, a small fight, a body search and recruitment. Later narrative proposals are reference material, not playable content or assignments.

## The opening

The [walkthrough](gameplay-script.md#the-brooklyn-bridge-opening) follows Miki from the Brooklyn end to Manhattan:

1. Move and look while alone on the snowbound bridge.
2. Meet the stranger at the first tower. His first shot deliberately misses; fight using the tower as cover. A third hit retries that fight.
3. Search the body for rounds and a medical kit. A scripted ambush introduces Tom, who joins afterwards.
4. Find Laura, help her with the kit and hear her name. She joins after the short exchange.
5. Cross the second tower with both companions. Switch leaders, try Close/Spread/Column and move/hold orders, then gather at the Manhattan end.

Only the bridge is available. Pause has Resume, Restart and Vibration. There is no alternate-scene selector, weapon bench, endless spawn, automatic combat cover, companion auto-fire, grenade, signature, elevation or salvage-repair system.

## Input and interaction contract

| Intent | PS5 / Xbox | Touch | Keyboard |
|---|---|---|---|
| Move active character | Left stick | Bottom-left analog stick | WASD |
| Contextual action, advance dialogue or confirm menu | Cross / A | Look, Search, Help, Continue, or Restart while paused | E |
| Next leader, after someone joins | R1 / RB | Next: name | Q |
| Previous leader | L1 / LB | Next cycles | Z |
| Change formation with two companions; call ordered companions back first | Triangle / Y | Formation / Follow | R |
| Both go / left member / right member / both hold | D-pad up / left / right / down | Hold on ground, then Both / a name / Hold | Arrow keys |
| Draw and fire the leader's native weapon; hold to fire, automatic reload | R2 / RT | Fire with assisted aim | F |
| Aim apart from movement | Right stick | Assisted aim | I, K, J, L |
| Pause / Resume | Options / Menu | Pause / Resume | Escape |
| Choose Resume, Restart or Vibration while paused | Stick or D-pad up/down, then Cross / A | Resume, Restart or Vibration | W/S or up/down, then E |
| Hide/show status panel | Circle / B | Always shown | H |

Touch is automatic without an extended controller. An attached controller is preferred unless **Use touch controls** is chosen; **Use controller** returns to it. Keyboard remains available. These sources share InputRules and session authority. Xbox uses the shared extended-gamepad path; hardware delivery remains unverified.

Switching preserves positions and progress; held movement can continue on the new leader. Next wins over Previous in one sample. Switch, formation and order commands consume a simultaneous action. Dialogue and Pause consume gameplay edges rather than queueing them. Pause, interruptions, reconnection and source changes require neutral input; every button, key and finger must release, including a finger resting at stick centre.

Search and Help are revalidated on press against the leader's position and current progress. Searching the downed stranger happens once and starts the ambush. Helping Laura uses the shared medical kit and starts her recruitment exchange.

## Verification and performance

The bridge-only reset must pass `./scripts/check` and the eight retained scenarios: `bridge-walk`, `first-fight`, `fight-retry`, `ambush`, `laura`, `opening`, `formations` and `orders`. The implementation PR records the actual source, results and rendered Simulator evidence. Do not inherit the retired scenes' checks as proof for this reset.

Simulator is the everyday validation environment. The script drives ordinary input through shared rules, saves screenshots/video and reports frame time, simulation cost, companion spacing and route failures. DEBUG instrumentation and route helpers are absent from Release builds. Test-only flat ranges and a narrow doorway fixture remain outside the app target because they exercise bridge weapons and navigation boundaries.

The target remains 60 fps on the baseline iPhone 13 Pro Max. Simulator measurements do not establish phone frame pacing, haptics, thermals, multi-touch, hardware input or enjoyment. The user deferred frequent phone checks; do not claim a new physical result without one.

### Deferred phone and playtest checks

- Verify the retained bridge's current controller/touch controls, release gates, Pause, interruption recovery and camera on a physical phone at the next agreed checkpoint.
- Measure representative Release frame pacing and sustained performance before making baseline-device claims.
- Ask what is enjoyable and what should change before adding another scene or complex mechanic. TestFlight availability supplies no answer to that question.

### Historical delivery

The last verified pre-reset release is **0.1.0 (26)**, app/archive source `25195e8e21efabccf76008f1b4306a622c6adf67`, tree-identical to checked/reviewed `c80a7ac77a09ab2a754673016cad9dce37ea6b34`. The standard check passed 51 Blender tests, ten generated sounds, formatting, app build, Swift Testing, eighteen headless scenarios and thirty-wave integration. Four exact-source rendered routes passed: arsenal-bench 167/167, combat-yard 101/101, enemy-arsenal 35/35 and relay-run-retreat 104/104.

At **2026-11-22 06:19:36 UTC**, Apple confirmed upload COMPLETE with zero errors, processing VALID, IN_BETA_TESTING, INTERNAL_ONLY and availability to existing internal testers, with group/tester membership unchanged. Private archives, symbols and full evidence are preserved. This historical release includes the removed scenes and is not delivery evidence for the reset. Earlier delivery records remain in Git history and the decision records.

## Combat balance and readability

The build 26 tuning and measurements in [ADR 0016](decisions/0016-combat-balance-and-readability.md) are historical. Native weapon handling, shot effects, ballistics and companion yielding still serve the bridge. The arena, extra weapons, tactical enemies and preparation displays are retired; their old measurements do not assign a new implementation pass.

## Combat design review gate

The requested coordinated-squad direction and the trio's [combat identities](story/story-bible.md#combat-identities) remain design context. The bridge keeps formations and orders from [ADR 0003](decisions/0003-squad-movement.md), phases S1–S3. Its removed S4 experiments are not a current assignment. [The Quiet Yard](encounters/the-quiet-yard.md) and the Relay House screenplay remain unimplemented story proposals.

Next, agree on one small, enjoyable loop and concrete playtest questions using the bridge. Then assign a bounded prototype. A plan, historical assignment or review recommendation does not independently authorise bringing retired systems back.

## Outside the first playable

Additional playable scenes, tactical combat AI, signature abilities, salvage-repair machinery, extra equipment, elevation, skill trees, health/hunger systems, multiplayer, crafting, branching dialogue, finished art, persistence, cloud services and App Store submission. The reset does not assign any replacement for them.

## Later hardening

Before persistence, define a versioned snapshot of session progress, inventory, stable member IDs and a safe group spawn. Keep entity graphs, routes and transient animation out of it. Use ordered atomic writes and explicit error handling; preserve an unreadable save until the player chooses Restart. Sustained physical-phone thermal and memory checks follow a loop worth keeping.
