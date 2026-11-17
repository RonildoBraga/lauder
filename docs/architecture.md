# Lauder — architecture

**Date:** 16 November 2026\
**Status:** Swift and RealityKit accepted. The party design was consolidated through [PR #22](https://github.com/RonildoBraga/lauder/pull/22); the maintainer has now assigned Party A regardless of Claude's response.\
**Scope:** Party A implements primitive bodies, leadership/Pause, switching and camera follow. Companions follow as a squad under [ADR 0003](https://github.com/RonildoBraga/lauder/blob/a5437e5/docs/decisions/0003-squad-movement.md) phase S1, which replaced Party A's recorded trails. Its [session record](party-a.md) distinguishes verification from remaining work. Specialist interactions, mission rules, dialogue, Restart and persistence remain later stages; this design does not settle open relationships.

## Decision and platform

Use **Swift + RealityKit** for gameplay and the 3D world, and **SwiftUI** for the interface. Build scenes in Swift and load USDZ assets directly, following the [maintainer's code-first decision](https://github.com/RonildoBraga/lauder/issues/9#issuecomment-6907224023). The accepted rationale, alternatives and unchanged three-session Stage 1 stop criterion are in [ADR 0001](decisions/0001-engine.md).

The project targets **iOS 27.0 or later**, iPhone first, in landscape. Use stable Xcode 27.2 / SDK 27.2 and record the actual toolchain, OS and build with validation results. The initial performance baseline is **iPhone 13 Pro Max**, with a measured 60 fps target. Broader Apple-device support follows a working iPhone prototype. See the [recorded toolchain and device evidence](stage-1.md); a target is not a performance result.

## Shape of the project

Keep **one app target**, one Swift Testing target and ordinary feature folders. No package hierarchy, third-party dependency, custom ECS or new rendering layer is needed.

| Part | Proposed responsibility | Boundary |
|---|---|---|
| App composition | Own stable session/world instances and launch/teardown | SwiftUI reevaluation does not recreate them |
| GameSession | Mode, active leader and shared mission facts; accept/reject commands | Plain Swift values and rules, no entities or views |
| GameWorld | Three bodies, camera, collision, following, scene effects and owned update/load work | Owns entity state; uses plain Swift motion, routes and formation rules |
| Interface/input | Poll hardware, hold input-rule state, present coarse session/world state | Supplies intents; does not own a second gameplay mode |
| Content | Typed layout, character/interaction IDs, approaches, prompts and delivery assets | Small authored definitions within the app |
| Persistence, later | Versioned checkpoints and an ordered writer | Values, never entity graphs |

These are responsibilities, not new frameworks or a requirement to create every folder immediately. Party A adds GameSession with exploring/paused modes and leadership only. Add dialogue/interaction/progress rules with B/C and SaveStore during later hardening.

## Scene and asset authoring

Compose the graybox using generated meshes, simple materials, lights and camera. Keep authored positions, collision dimensions and stable IDs in the existing small typed layout, rather than adding JSON, a parser or an editor framework.

Party A uses three named, differently coloured primitive stand-ins. Replace the stationary Tomas landmark with his party body; the keeper briefing is text-only, without a fourth character rig. No new character models or animation are required. The completed rig/idle/walk proof remains recorded in [Stage 1](stage-1.md). Preserve editable sources, deliberate exports and provenance together; the [stand-in generator](../sources/content/character/README.md) is a prototype asset tool, not a finished-art pipeline.

Scene composition remains Swift code. The preserved [test-only asset fixture](../tests/support/CharacterAsset.swift) validates the named animation library; Party A does not ship its loader in the app target. Do not add per-frame visual work, publish character transforms to SwiftUI, or require art production before evaluating the party.

## Swift conventions

- Use **Swift 6 language mode** and complete data-race checking. Keep session/UI/world coordination main-actor isolated; concurrency boundaries must be explicit. [Swift migration guidance](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/enabledataracesafety/)
- Use **Swift Testing** for rules and value-based movement tests. [Swift Testing](https://developer.apple.com/xcode/swift-testing/)
- Use toolchain **`swift format`** with the committed [`.swift-format`](../.swift-format): two-space indentation, 100-column length and otherwise tool defaults.
- Run **`./scripts/check`** for formatting, the shared scheme's build and tests. [Validation requirements](../CONTRIBUTING.md#validation)

## Runtime ownership

**GameSession is the sole authority** for:

- Mode: exploring, dialogue or paused. Pausing records whether to resume exploring or the current dialogue; pauses do not nest or lose the dialogue cursor.
- Active leader: one stable member ID, with proposed order Miki → Lara → Tomas.
- Mission phase, introduced with Party C.
- A separate `passageOpen` flag, introduced with Party B. Opening access is not a mission phase and either solution sets the same flag.

Use plain Swift session state and rules on the main actor, exposing only coarse changes to the interface. The carried-regulator indicator is derived from the mission phase, not stored on a leader or duplicated in the world. There are no separate member inventories.

**GameWorld owns spatial state:** a body reference for each stable member ID, their actual positions, companion routes and formation state, one camera, scene bindings and one owned scene-update subscription. It reads the active leader from the session. Operational facts such as loading, app activity and hardware availability are not another exploring/dialogue/paused mode.

**GameControls owns device attachment and raw sampling.** Pure InputRules owns the transformation of raw values plus prior input-rule state into intents and next rule state. Neither keeps an independent pause/dialogue policy. `GameSession` now owns the exploring/Pause mode; `GameWorld` reads it and `GameControls` receives it when resolving input. Planned dialogue extends that same authority.

```mermaid
flowchart LR
    H[GameControls hardware/touch sample] --> R[InputRules: values and edge history]
    S[GameSession: mode, leader, progress] -->|current mode| R
    R -->|intents| S
    W[GameWorld: bodies, squad, camera] -->|validated interaction request| S
    S -->|leader and accepted state| W
    S --> U[SwiftUI presentation]
    C[Typed layout and content] --> W
```

The owned world update coordinates this sequence. Rules do not retain RealityKit entities, and the world does not keep a second leader, inventory or passage-open truth.

## Input and command routing

Keep the shared GameController extended-gamepad path for PS5 DualSense/Xbox and the Simulator keyboard path. Existing mappings are left stick/WASD movement, Cross/A/E action and Options/Menu/Escape Pause. **Initial switching defaults:** R1/RB, read through the [right shoulder element](https://developer.apple.com/documentation/gamecontroller/gcextendedgamepad/rightshoulder), or **Q** in Simulator. Q replaces the earlier Tab proposal. Q delivery was checked in Simulator; R1 and the switching camera/HUD were confirmed in the short baseline phone check. Xbox RB hardware delivery remains unverified. The maintainer subsequently authorised [touch controls](touch-controls.md), superseding the no-touch decision. A fixed bottom-left analog stick, **Look**, **Next: name** and **Pause/Resume** supply the same intents. Touch is automatic without an extended controller; an attached controller is preferred unless **Use touch controls** is selected, and **Use controller** returns to it. The preference is in memory, not persisted.

GameControls samples hardware and TouchInput state; InputRules resolves all sources with the same mode, priority and fresh-edge history. Touch controls do not call GameSession or world actions directly. Independent zones support a stick finger alongside button fingers. Source changes and inactivity cancel captures through a generation token so stale callbacks cannot affect the new source. Pause leaves capture mounted and preserves held contacts: all fingers must lift, including a centred-stick finger, before the neutral gate clears. The foreground idle-timer policy is unchanged.

Keep explicit previous-button/edge state in InputRules instead of adding another edge detector in GameWorld. Tests cover:

1. Pause takes priority over other commands in the same sample. The session stores the resume mode and routes subsequent inputs accordingly.
2. While exploring, a fresh switch edge cycles leadership and suppresses the same-sample action. Record that action's held state even when suppressed: it requires release and a fresh press before use.
3. Held movement may continue on the new leader. Switching alone does not close the neutral-input gate.
4. While in dialogue or Pause, switch edges are ignored and consumed, not queued. Action advances text or confirms the pause-menu choice; it cannot also interact with the world. Movement can navigate a menu only where explicitly defined, never move the bodies.
5. Inactivity, input-source changes and Pause/Resume retain the release gate. All gameplay buttons, including switch, must be released and the stick centred before fresh input. Opposing held movement keys do not count as neutral.

GameSession decides what an allowed intent means for the current mode. World movement/following runs only when exploring, presented, active, ready, supplied with an available input source and past the neutral-input gate. This does not require nonzero movement: followers may settle along their routes while the leader stands still. Dialogue, Pause, input loss or a closed release gate freezes the whole party; input sampling needed for dialogue/menu/Pause remains available.

## Movement and presentation

Continue using one owned RealityKit scene update with elapsed time. **RealityView.update is for state-driven scene changes, not the simulation loop.** Do not add a timer or per-input tasks. Keep the existing cancellation, first-step timing reset and late-load protection.

Party A samples input and advances plain body transforms through one owned `SceneEvents.Update` subscription. Movement does not require rigid-body simulation; the earlier physics-only subscription stopped delivering input updates when the all-static scene idled.

Inside that update, party movement advances in **fixed 1/120-second steps**. Each frame adds its elapsed time, capped at 1/30 second, runs as many whole steps as fit and carries the remainder; the first step after an interruption discards any remainder. Equal steps record equal trail edges for a given stick input, which follower spacing depends on: with variable steps, followers lost distance they could not regain while the leader kept running ([#28](https://github.com/RonildoBraga/lauder/issues/28), fixed as [authorised by the maintainer](https://github.com/RonildoBraga/lauder/issues/28#issuecomment-6942750650)). Camera easing uses the frame's elapsed time. Bodies move in whole steps without interpolation, so a frame can show up to one step (about 2 cm at full speed) more or less than its elapsed time; that is accepted for the graybox. This is still the single owned update, with no timer.

All three stand-ins use the same circular footprint. The assigned [#25 correction](wall-contact.md) resolves continuous horizontal movement in plain Swift against the axis-aligned rectangles derived from `PrototypeLayout`'s visible blocker dimensions. Offset faces and exact rounded corners use the body radius plus a **2 mm normal skin**, including unobstructed endpoints. A body starting inside that clearance may move outward or tangentially, while inward movement stays blocked; idle input never snaps its position. Resolve the initial leg and at most one wall-slide leg, then check the final start-to-end chord so the recorded trail cannot cut through another blocker.

RealityKit renders the bodies and scenery; movement no longer uses engine shape queries or static physics components. Ground, decorations and party members are excluded from the authored blocker list. Body height stays fixed on the existing flat floor; slopes, steps, vertical traversal and a new physics/navigation system are outside this correction. Trail spacing remains best-effort, with temporary overlap on reversals accepted for the graybox. Earlier [Party A route results](party-a.md) apply to the old implementation, not this fix.

Companions move as a squad under [ADR 0003](https://github.com/RonildoBraga/lauder/blob/a5437e5/docs/decisions/0003-squad-movement.md), [accepted by the maintainer](https://github.com/RonildoBraga/lauder/pull/32#issuecomment-6944093756); phase S1 replaced the recorded trail of [ADR 0002](decisions/0002-party-following.md). Each step:

1. The leader moves from the stick as before, and a short **route memory** records their last 6 m.
2. **SquadPlanner** places a **Close** formation slot for each companion, 0.9 m to the side and 0.9 m behind, turned towards the leader's heading at up to 180° per second. A slot is used only where a body fits outside doorway-like passages and the straight line from the leader is clear. Otherwise it is pulled halfway in, then moved onto the leader's route; it spreads out again once it has fitted for 0.3 s. A waiting companion stands clear of doorways.
3. **CompanionMotor** steers each companion: straight to the slot when the line is clear, matching the leader's movement and closing the gap; otherwise along an A* route on **NavigationGrid**, a 0.2 m grid over the authored rectangles, straightened against the same footprints. Companions may reach 1.25× the leader's speed to catch up, accelerate and turn at limited rates, settle without shuffling and keep about 0.75 m of personal space. Lara reacts first and Tomas last, by a fraction of a second.
4. Every movement, the leader's included, is resolved by PartyMotion.

A companion that stalls for a second re-plans; after three stalls they wait, the HUD names them, and they retry by themselves. The leader and the other companion keep moving, and nobody teleports.

The camera keeps the accepted elevated offset and field of view and follows the session's selected leader. On switching, ease the target from the current camera target to the new leader over **0.25 seconds**, tunable in playtests. Preserve the offset/orientation and world positions; another switch starts from the current interpolated target. Freeze transition progress when the world is frozen. The short Simulator and baseline phone checks confirmed readable leader changes and camera/HUD framing; longer-session comfort and other layouts remain unverified.

## The prototype's state

Proposed Party C mission phase:

**Briefing → Seeking regulator → Carrying regulator → Radio repaired → Meeting agreed**

The keeper's briefing starts the search with all three travellers present. Miki identifies/takes the regulator and later consumes it in the repair. Any leader can start the coastal water-crew call or use **Read plan** after completion. Finishing the call secures the appointment. Lara is local; no Nina-specific dialogue is required while relationships remain undecided.

The separate passage flag survives every leader switch. Lara's latch and Tomas's panel action are alternative transitions from closed to open; after either succeeds, both requests are harmless. No second obstacle or skill tree is needed.

### One interaction

Before Party B, extend the typed layout's interaction definitions with stable action IDs, eligible member IDs, an authored accessible approach area, prompt/role-feedback text and the relevant collision dimensions. Put per-object collision data there instead of selecting it by ID in GameWorld; this absorbs [#19 L4](https://github.com/RonildoBraga/lauder/issues/19). Required IDs must exist once at load.

1. GameWorld evaluates the actual active body's position against the interaction's approach area and current world accessibility.
2. The HUD presents the active character's action or a suggestion to switch. No remote companion acts automatically.
3. A fresh action rechecks active identity, approach, range, accessibility and relevant progress. An approach must be authored on the usable side of a wall; proximity alone is insufficient.
4. GameSession validates mode, eligibility and phase/flag and accepts or rejects the named command.
5. Accepted state changes project onto the static world: the barrier opens, the regulator disappears or the transmitter changes state. The world retains no independent progress flags.

Tests cover stale prompts after movement/switching, both alternative methods independently, duplicate actions and repair without the part. Read plan leaves secured progress unchanged. Keep short ordered speaker-labelled text in content; no branching dialogue framework is required.

## Restart and lifecycle

Party C implements the proposed **in-place Restart** of the existing session/world. Reset mode to exploring, active leader to Miki, mission to briefing and passage to closed. Restore all three authored spawn positions, body motion state, regulator visibility, unrepaired transmitter, dialogue/objective state and observation/prompt state. Clear/reseed trails, camera transition and input edge history; require neutral input before movement resumes.

Restart does not attach a second simulation callback, rebuild the static scene or reload already available stand-ins. Invalidate unfinished run-specific effects or loads so late results cannot alter the reset run. Verify a single owned subscription and exactly three members across repeated restarts.

Normal inactivity freezes the current scene and preserves session/dialogue progress. Clear held input and reset frame timing when returning. The foreground app remains awake, including Pause; restore the idle timer when inactive. Leaving the view cancels owned updates and unfinished loads. These rules extend the current lifecycle to all three bodies rather than creating a separate party lifecycle manager.

## Saving and interruption

**Persistence is later hardening, not a first-playable dependency.** Create SaveStore then, rather than alongside Party A.

Use a versioned Codable checkpoint with mission phase, the independent passage flag, active member ID and an authored safe group-spawn ID. Derive the carried part from phase. Restore all three to a validated group placement on the correct reachable side of any closed barrier; define the checkpoint mapping before implementing saves. Do not serialise arbitrary transforms, trails, physics or animation state.

Save meaningful changes with one ordered atomic writer. Restart invalidates older writes. Report failures; a corrupt/unsupported save remains intact until the player explicitly chooses Restart. Termination during dialogue replays its checkpoint; ordinary Pause preserves the live line. Do not rely on a shutdown callback.

## Assets and checks

Party A adds pure tests for input precedence and session modes/leadership; S1 adds grid, route-memory and whole-party formation, stillness, switching and service-opening tests. The #25 correction adds exact collision regressions and fixed-seed whole-party route tests using the authored blockers; [its record](wall-contact.md) separates pending validation from earlier results. Manual Simulator checks still cover the rendered route, turns, reversals, camera easing and switching to each separated member. B adds layout eligibility/approach and shared-gate checks. C adds the full progression, dialogue and repeated in-place Restart checks. Unit tests do not prove the rendered route. Debug builds also contain scripted playtests that `scripts/playtest` runs in the rendered Simulator app; they feed scripted input through the normal controls and record traces, and are compiled out of Release builds.

Use Simulator keyboard and single-pointer touch input for everyday iteration. The [touch-control validation record](touch-controls.md#validation) distinguishes those checks, the maintainer's physical multi-touch/Pause/recovery observations and remaining controller/performance gaps. Live PS5 input did not work in the tested Simulator setup; enumeration does not prove delivery. The accepted checkpoint schedule is after **Party A** and **Party C**, with B checked alongside C. It preserves [#18's earlier deferral](https://github.com/RonildoBraga/lauder/issues/18). Record controller/lifecycle observations and measured frame pacing; neither the solo phone checks nor Simulator timing prove party performance. Sustained 15–20 minute thermal/memory checks remain later hardening.

## Deliberately deferred

Finished character art/animation, free jumping/climbing, formation orders, separate inventories, generic navigation/ECS/inventory/quest frameworks, additional packages, networking, cloud saves, monetisation and scene streaming. Ordinary following and switching are part of Party A, not deferred companion features.

The [future squad/combat design](gameplay-script.md#future-squad-and-combat-design) and [The Quiet Yard](encounters/the-quiet-yard.md) describe intended experiences for review. Their [design gate](prototype-plan.md#combat-design-review-gate) precedes an implementation assignment; they do not replace the current trail/collision design or define a new navigation or combat architecture.

## Revisit after the first playable

Use the plan's Party A stop review if following is unreliable. First reconsider the squad movement's tuning and the bounded layout; an automatic regroup requires a deliberate review. Add the next survival pressure, combat encounter or visual requirement only when a concrete playtest need warrants it.
