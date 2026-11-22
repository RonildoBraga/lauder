# Lauder — bridge-only prototype

**Updated:** 23 November 2026

**Status:** The maintainer requested a smaller starting point before a gameplay revamp: keep the Brooklyn Bridge and delete the other playable scenes and their unused systems. [ADR 0017](decisions/0017-bridge-only-reset.md) records the boundary. New mechanics and scenes await a design decision.

The high bridge concept and dark armed v3 robot look are now selected. The maintainer chose the robot to **replace the first human shooter**, with Miki alone. The [first-tower behaviour proposal](encounters/bridge-spider-bot.md) is the current design discussion; its rules and tuning are not approved or implemented.

## Structural preparation

The approved structural preparation is merged: [PR #125](https://github.com/RonildoBraga/lauder/pull/125) separates camera motion and bridge progression, clarifies encounter naming, splits combat values into cohesive files and adds narrow declaration checks with CI. [PR #126](https://github.com/RonildoBraga/lauder/pull/126) adds reproducible TestFlight tooling. [ADR 0018](decisions/0018-runtime-boundaries.md) records the boundaries. Gameplay and story are unchanged; the next gameplay task is the design gate below.

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

### Architecture checks

Integrated source `7158f29a44738cfd0188292ef3839d0338bd7c73` has the exact tree of reviewed source `c01dd03f6532063c959f2da9fcd663b3f9d393f3`. On `c01dd03`, `./scripts/check` passed formatting, the shared app build and hosted Swift suite, including all eight retained headless routes and six new camera/progression regression tests, plus **13 declaration-contract tests**, **28 offline release-contract tests**, **51 Blender tests** and **seven generated sounds**. [GitHub Actions run 45002053969](https://github.com/RonildoBraga/lauder/actions/runs/45002053969) passed on that reviewed source. Source review completed with no outstanding findings.

The retained headless routes are `bridge-walk`, `first-fight`, `fight-retry`, `ambush`, `laura`, `opening`, `formations` and `orders`.

Rendered Simulator checks on `b533e2ff8ee210eb030737293e47524ed008f47e` passed with no route failures or companion warning frames:

| Source | Route | Result |
|---|---|---:|
| `b533e2f` | `opening` | 56/56 |
| `b533e2f` | `orders` | 130/130 |

The app, Swift-test and Blender sources in those recordings are unchanged in integrated source `7158f29`; the recordings are not exact-head repository captures.

### TestFlight delivery

The source-bound standard check also passed on app/archive source `7158f29`. Its signed **0.1.0 (28)** Release archive passed bundle, signing-team, signature and matching-dSYM verification. At **2026-11-22 08:38:25 UTC**, Apple's read-only verification confirmed Lauder's identity, upload **COMPLETE** with **zero errors**, processing **VALID**, **IN_BETA_TESTING**, **INTERNAL_ONLY**, an unexpired build and availability to the existing internal testers. Existing internal groups contain the build; group and tester membership are unchanged. Private archives, symbols and full processing evidence are preserved. Availability does not establish phone installation, physical behaviour, performance or enjoyment.

### Simulator and physical evidence

Simulator is the everyday validation environment. The script drives ordinary input through shared rules, saves screenshots/video and reports frame time, simulation cost, companion spacing and route failures. DEBUG instrumentation and route helpers are absent from Release builds. Test-only flat ranges and a narrow doorway fixture remain outside the app target because they exercise bridge weapons and navigation boundaries.

The target remains 60 fps on the baseline iPhone 13 Pro Max. Simulator measurements do not establish phone frame pacing, haptics, thermals, multi-touch, hardware input or enjoyment. The user deferred frequent phone checks; do not claim a new physical result without one.

### Deferred phone and playtest checks

- Verify the retained bridge's current controller/touch controls, release gates, Pause, interruption recovery and camera on a physical phone at the next agreed checkpoint.
- Measure representative Release frame pacing and sustained performance before making baseline-device claims.
- Ask what is enjoyable and what should change before adding another scene or complex mechanic. TestFlight availability supplies no answer to that question.

### Historical delivery

Build **0.1.0 (27)** delivered the bridge-only reset ([PR #122](https://github.com/RonildoBraga/lauder/pull/122), [delivery record in PR #123](https://github.com/RonildoBraga/lauder/pull/123)) from app/archive source `de4d0db566a546217f3c3ca095cdf1b3944a21e3`, matching the exact tree of checked/reviewed `feabb43f10f3708bc6fef4f940f26c2d8b7b462d`. The standard check passed **255 Swift tests**, **51 Blender tests** and **seven generated sounds**; the signed archive passed bundle/team/signature/dSYM verification. At **2026-11-22 07:14:36 UTC**, Apple confirmed upload **COMPLETE** with **zero errors**, processing **VALID**, **IN_BETA_TESTING**, **INTERNAL_ONLY**, an unexpired build and existing internal tester availability with membership unchanged. Earlier recording details and review history remain in the original PRs and Git history; private archives, symbols and full processing evidence are preserved.

Build **0.1.0 (26)**, source `25195e8`, was verified as processed and available before the reset. It contains the removed scenes; [ADR 0016](decisions/0016-combat-balance-and-readability.md) and Git history preserve its historical decisions and delivery evidence. Private archives, symbols and full processing evidence remain preserved.

## Combat balance and readability

The build 26 tuning and measurements in [ADR 0016](decisions/0016-combat-balance-and-readability.md) are historical. Native weapon handling, shot effects, ballistics and companion yielding still serve the bridge. The arena, extra weapons, tactical enemies and preparation displays are retired; their old measurements do not assign a new implementation pass.

## Combat design review gate

Review the [first-tower robot proposal](encounters/bridge-spider-bot.md) before assigning modelling or gameplay work. It proposes a readable brace/commit/burst/recovery pattern using existing tower cover, and a supply-case handoff that preserves Tom's introduction and Laura's medical kit. The bypass route, handoff, hit allowance and tuning still require agreement and geometry validation. The existing app, source checks and TestFlight build 28 continue to describe the human encounter.

The requested coordinated-squad direction and the trio's [combat identities](story/story-bible.md#combat-identities) remain design context. The bridge keeps formations and orders from [ADR 0003](decisions/0003-squad-movement.md), phases S1–S3. Its removed S4 experiments are not a current assignment. [The Quiet Yard](encounters/the-quiet-yard.md) and the Relay House screenplay remain unimplemented story proposals.

Next, agree on that small tower loop and its concrete playtest questions, then assign a bounded prototype. A plan, historical assignment or review recommendation does not independently authorise implementation or bringing retired systems back.

## Outside the first playable

Additional playable scenes, tactical combat AI, signature abilities, salvage-repair machinery, extra equipment, elevation, skill trees, health/hunger systems, multiplayer, crafting, branching dialogue, finished art, persistence, cloud services and App Store submission. The reset does not assign any replacement for them.

## Later hardening

Before persistence, define a versioned snapshot of session progress, inventory, stable member IDs and a safe group spawn. Keep entity graphs, routes and transient animation out of it. Use ordered atomic writes and explicit error handling; preserve an unreadable save until the player chooses Restart. Sustained physical-phone thermal and memory checks follow a loop worth keeping.
