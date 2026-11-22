# Lauder — architecture

**Updated:** 22 November 2026

**Status:** Bridge-only runtime before a gameplay revamp ([ADR 0017](decisions/0017-bridge-only-reset.md)). Swift, RealityKit and SwiftUI remain accepted. Historical experiment records describe retired code, not the current architecture.

## Decision and platform

Use Swift for rules and gameplay, RealityKit for the 3D world and SwiftUI for the interface ([ADR 0001](decisions/0001-engine.md)). The iPhone app targets iOS 27.0 or later in landscape with Xcode 27.2. The target is 60 fps on the baseline iPhone 13 Pro Max; a target is not a measured result.

The maintainer approved these focused separations in [ADR 0018](decisions/0018-runtime-boundaries.md). They preserve the bridge's current behaviour.

## Shape of the project

Keep one app target and one hosted Swift Testing target, with ordinary feature folders under `apple/`. Xcode folder-synchronised groups include sources and tests without per-file project edits. Blender source and its export extension live under `blender/`; no new package hierarchy, dependency, custom ECS or rendering framework is needed.

| Owner | Responsibility | Boundary |
|---|---|---|
| Game | Hold the bridge's stable GameWorld | SwiftUI reevaluation does not rebuild it; no level-switch flow |
| GameSession | Mode, party/leader, formations/orders, inventory, combat checkpoints, dialogue and accepted commands | Authority over live session progress; no entities |
| BridgeProgress / StoryBeat | Bridge progression, action eligibility/costs and recruitment policy / authored story markers | Checkpointable rules and independent content data |
| WorldCamera / CameraRig | Camera entity and landmark fading / follow, lean, switching, lens and projection | Presentation owner and value-only camera motion |
| GameWorld | Bodies, scene, camera, movement, companion routing, encounters and one owned update subscription | Spatial state; no duplicate session progress |
| EncounterSimulation | Native weapon handling, targeting, actual rays, hostile timing, cues, recoil/hit/fall values and feedback events | Plain Swift, no RealityKit or sound/haptic playback |
| EncounterStage | Reusable hostile/weapon entities, target markers and shot effects | Presentation only |
| GameControls / InputRules | Device sampling, touch state, command edges, source arbitration and neutral gates | Intents only; no second pause/dialogue policy |
| Content | Bridge layout, words, encounters, interactions, models and sounds | Typed definitions and bundle resources |

## Scene and asset authoring

The Brooklyn Bridge is the only playable `Level`. Its Blender file exports `BrooklynBridge.usdz` and `BrooklynBridgeLayout.swift` ([ADR 0002](decisions/0002-blender-source-of-truth.md)). `BrooklynBridge.swift` adds words, stable references, encounter definitions and interactions. Export refuses to drop layout names gameplay uses. [Contributor instructions](../CONTRIBUTING.md#editing-a-level-in-blender) describe authoring.

`Level` contains flat ground bounds, blocker boxes, triggers, interactions, encounters, starting party/spawns, heading, camera/lights and an optional scene resource. Small test-only levels use the same data with plain geometry. They are not alternate app scenes. There is no terrain, gate, salvage, arena or optional-guard schema.

The world loads the bridge synchronously and retains it across Restart. Figure model templates produce independent clones. A single scene needs no level replacement, scene-template cache, cross-level navigation cache or transition timing subsystem. `SceneStyle` supplies simple materials and signal colours. Preserve Blender provenance and asset licensing.

## Swift conventions

- Swift 6 language mode and complete concurrency checking; session/UI/world coordination stays on the main actor.
- Swift Testing for meaningful value and production-integration regressions.
- Toolchain `swift format` with [apple/.swift-format](../apple/.swift-format), two-space indentation and 100-column lines.
- `./scripts/check` runs Blender/export tests, generated-sound validation, formatting, app build and hosted tests. [Validation](../CONTRIBUTING.md#validation) defines destinations and required tools.

## Runtime ownership

GameSession composes a BridgeProgress value and owns exploring/dialogue/paused mode, the recruited party in switching order and active leader, Close/Spread/Column, each companion's following/going/holding order, one-shot trigger progress, bridge story beat, shared ammunition/medical kits, fight checkpoint/hits/defeated IDs and dialogue cursor. BridgeProgress plans concrete bridge actions and recruitment; the session validates mode, creates checkpoints before costs, and applies accepted effects. Recruiting takes effect after the corresponding exchange. StoryBeat is shared content data without a dependency on GameSession.

GameWorld owns a body for every stable member ID, their visibility and position, companion routes/motors/targets, the navigation grid and flat movement blockers. Unrecruited figures stay hidden except Laura lying where the bridge places her. It owns a WorldCamera and one EncounterSimulation/EncounterStage pair. WorldCamera owns camera/landmark presentation; CameraRig computes its motion and projection without scene entities. App activity, input availability and input readiness are operational gates, not extra gameplay modes.

The owned update samples controls, resolves InputRules using session mode, handles the accepted intent and advances fixed-step movement/combat while allowed. Entity transforms do not publish through SwiftUI every frame. UI observes coarse state and plays emitted feedback while active.

## Input and command routing

Controller, keyboard and touch share InputRules; the [input contract](prototype-plan.md#input-and-interaction-contract) lists bindings. Controller preference and **Use touch controls / Use controller** choose a source without bypassing session authority. PS5 and Xbox use extended-gamepad elements; Xbox physical delivery remains unverified.

Pause wins over simultaneous commands. Next wins over Previous, and switches, formation and order commands suppress a same-sample action while consuming its held edge. Dialogue and Pause consume unavailable gameplay presses rather than queueing them. Holding movement through a leader switch moves the new leader without moving anybody to a new position.

Pause/resume, source changes, interruption and reconnection require neutral input. Every held key, button and finger counts, including a centred-stick contact. Source changes cancel touch captures using generation tokens; stale callbacks cannot write into a fresh source. Keep the touch surface mounted on Pause so release is observable. A quick tap is latched until a sample, then delivered once.

Pause has **Resume**, **Restart** and **Vibration**, opens on Resume and navigates on fresh up/down presses. Action confirms; Escape/Options/Menu resumes. Touch exposes the same intents directly. Restart takes effect without an extra confirmation. The pause view shows the bundle's actual version/build.

## Movement and presentation

Movement maps camera-relative input onto the flat ground. PartyMotion applies exact blocker clearance and separation. NavigationGrid routes through legal space; SquadPlanner chooses distinct formation places, and CompanionMotor follows/settles/yields rather than copying every footprint. Narrow space compresses the formation, which expands when room returns. Orders project a marked point through the current camera and reject inaccessible destinations rather than teleporting anybody.

The camera follows the active leader and eases on a switch, retaining the elevated angle. Aiming/fighting narrows its lens. The bridge's tall towers fade when between camera and party. Goals from the authored layout drive the compass. Status messages expire in play time; Pause and dialogue hold them.

## The opening

The bridge starts with Miki alone. Timed encounter cues reveal/engage the stranger, script the ambush and Tom's shot, help Laura stand and begin brief conversations. Content owns text and authored points. The session owns which beats have completed; the world owns where bodies stand.

### Interactions

Search and Help check the leader's accessible approach and session progress again on press. Search takes the downed stranger's rounds/kit once and begins the ambush. Help spends the shared kit and begins Laura's scene. These rules need no generic quest or inventory framework.

### Fights

Every recruited leader carries their native weapon: Miki's precision carbine, Laura's three-shot burst or Tom's close scatter shot. WeaponHandling preserves draw/cooldown/burst/magazine/reload state across switches. Switching cancels unspent burst shots without refilling or completing reloads. Automatic reload adds no control or ammunition. During a fight each actual leader discharge spends one shared round; practice outside a fight is free.

Manual aim turns the leader at a bounded rate; without it, assistance picks a visible target in effective reach and Fire waits until facing it. Spread follows movement, turning and recent shots. Ballistics traces actual shots through the flat level bounds, body cylinders and real box heights; a miss can strike scenery and a long ray is not truncated at assistance reach. Unengaged people hold deliberate fire. No line exposes an enemy's exact aim.

The bridge's shooter reveals, winds up, fires a deliberate first miss, then recovers and fires again. Finite barrel tracking and seeded spread resolve actual rays. A nonlethal hit briefly delays a wind-up; downed figures fall. The tower's geometry supplies cover without a proximity stance/shield system. A third hit invokes the bridge encounter's retry. Companions have no autonomous combat or signature ability in this scene; Tom's ambush shot is an authored cue.

EncounterStage projects poses, tracers/flashes/impacts and reusable target markers. Feedback events select the retained native weapon/impact sounds and leader haptic cues. Sound/haptic playback follows lifecycle and the Vibration preference.

### Scenes

An encounter that holds the party advances only its cues: the ambush, helping Laura and the closing exchange. Movement, Fire and actions cannot interrupt its placement. Pause still works. A conversation suspends the remaining frame; its final line settles recruitment. These are bridge story sequences, not extra playable levels.

## Restart and lifecycle

Restart resets session progress and native weapon handling in place, restores authored body/spawn/visibility states and the opening line, clears routes/markers/reactions/shot effects and cancels the current scene/retry. It resets camera transition and owed simulation time, then requires neutral input. It neither rebuilds static geometry nor adds a second update subscription.

Inactivity freezes gameplay, stops feedback and clears held input. Resume resets frame timing and requires release before fresh input. Leaving the view cancels owned updates. The screen stays awake while foreground play or Pause is active and restores normal idle locking on leaving.

## Saving and interruption

Persistence remains unimplemented later hardening. Define versioned value snapshots with story beat, stable party/leader IDs, inventory and a safe authored group placement. Never serialize entity graphs or transient routes/animation. Use one ordered atomic writer, invalidate stale work on Restart and preserve unreadable saves until an explicit player decision.

## Checks

Tests cover bridge beats/interactions/recruitment/retry, session authority and input priority/release, camera mapping, native weapon timing and feedback, actual long rays/neutral safety, collision and squad motion. A test-only yard with a narrow doorway exercises clearance the bridge cannot provide; a flat range exercises weapon rules without changing app content.

Portable contract checks compare scenario and resource declarations across Swift, Python and Blender. Offline TestFlight contract tests also run without credentials or network access. The versioned `apple/scripts/testflight` command owns release discovery, source-bound checks, signing/archive verification, upload and read-only processing/tester verification; its team/credentials and receipts/archives stay private. The same standard check runs in CI on the selected compatible Xcode image; the PR records the actual result.

Eight DEBUG scripted routes use ordinary input in headless and rendered Simulator runs. See [verification](prototype-plan.md#verification-and-performance). Pointer-driven touch is not physical multi-touch, and Simulator controller enumeration does not prove live input forwarding. Physical behaviour, performance and enjoyment require separately recorded evidence.

## Deliberately deferred

Other playable scenes and the retired prototypes' frameworks, autonomous combat, cover stances, tactical enemies, grenades, signatures, elevation, salvage-repair interactions, weapon benches, health/hunger, crafting, skill trees, persistence, networking and art expansion. Current architecture is the bridge's needs; new work follows an agreed gameplay question and explicit assignment.
