# Lauder architecture

**Updated:** 29 November 2026. **Scope:** the basic-rig dungeon tracked in [issue #243](https://github.com/RonildoBraga/lauder/issues/243). [ADR 0023](decisions/0023-basic-rig-dungeon-prototype.md) records the assigned extension of the earlier [duel](decisions/0022-single-hero-graybox-duel.md); the [bridge checkpoints](milestones/bridge-prototype.md) preserve the previous runtime.

## Platform and boundaries

Swift 6 language mode, RealityKit rendering, SwiftUI interface and Swift Testing remain accepted. Keep one app/module and one hosted test target, with ordinary lowercase folders. There are no third-party runtime dependencies, new packages, generic combat framework or custom ECS. The iPhone target remains iOS 27 or later with Xcode 27.2; 60 fps on the baseline iPhone is a target, not a verified result.

| Owner | Responsibility | Boundary |
| --- | --- | --- |
| Game / LauderApp | Stable world, app scene phase and foreground idle-timer policy | SwiftUI updates do not recreate gameplay |
| GameSession | Exploring/paused mode, Resume/Restart choice | No spatial or damage state |
| GameControls / InputRules | Source selection, touch generations, neutral gates, fresh edges and Pause priority | Input intents; no stamina, damage or action legality |
| TouchInput / TouchControls | Independent finger capture, held/pending taps and UIKit surface | Mounted during Pause; no gameplay authority |
| GameWorld | One scene subscription, fixed-step accumulator, accepted pending edges, interruption/reset and presentation coordination | Does not duplicate combat rules |
| DungeonLayout / DungeonRun | Shared flat route geometry/triggers and encounter/checkpoint/cache/shortcut progress | Delegates to one combat owner; no duplicate hero or clock |
| DuelSimulation | Hero/enemy positions, facing/focus, health/stamina, action timelines, enemy decisions, collision and outcomes | Plain Swift values; no entities, UI or audio |
| DuelAction | Preparation/contact/recovery, committed direction and shared blade pose | One timing source for contact and rendering |
| PartyMotion / Movement | Swept flat collision and camera-relative ground directions | Retained geometry; party naming does not imply companions |
| CameraRig / WorldCamera / CameraProjection | Fixed diagonal orientation, smooth hero/pair framing and shared projection / camera entity | Consumes focus state; no combat or input authority |
| MannequinLibrary / Mannequin | Checked Blender body poses and matching 17-joint hierarchy with plain rigid limb proxies | Animation consumes accepted phases/displacement; cannot schedule damage |
| DuelStage | Shared dungeon terrain, separate weapons, resolved mannequin poses, conditional wind-up warnings and three sound effects | Consumes state/events; cannot award damage |
| PlaytestRunner | DEBUG-only command routes and evidence | Uses ordinary input; cannot inject health, attacks or outcomes |

## Swift conventions

Use Swift 6 language mode and complete concurrency checking. Session, UI and scene owners stay on the main actor; combat and geometry use plain Sendable values. Use Swift Testing and toolchain swift format with the committed apple/.swift-format (two-space indentation, 100-column lines). The standard check verifies formatting, build and hosted tests.

## Dungeon and combat ownership

DungeonRun owns one DuelSimulation and route progress. The combat owner retains the hero, action clock, collision, health/stamina and contact counters during exploration and both encounters. A room kill clears only that encounter; reaching the exit after both rooms completes the run. DungeonLayout supplies floor patches, solid wall/gate footprints, encounter homes/activation regions, checkpoint, recovery find and exit to both rules and scene presentation. Route transitions are checked after every authoritative fixed substep, including when a slow direct caller crosses and leaves a trigger in one outer frame. There is no navmesh, terrain height or alternate playable arena.

Only an active guard attacks or receives Focus. A bounded scenery-clear idle preview can reveal the next guard through a doorway; preview presentation grants no combat authority. Encounter-local home/leash prevents pursuit into unrelated rooms. Health/stamina carry between fights. Recovery is capped at 40 health, once per life outside combat; healthy heroes leave it available. Retry restores encounters/find and preserves an opened shortcut; full Restart resets the route. Proximity supplies these interactions without a new input action.

## Rules and presentation

The world samples controls once, preserves fresh Attack/Dodge/Focus edges until a simulation tick, and advances at 120 Hz. Slow frames have bounded catch-up. Simulation subdivides a direct slow caller too, so an active interval is not skipped. Inputs are not replayed on every substep.

The hero moves in the input direction. A free slash records valid movement direction at the request, falling back to current facing without movement; a queued slash keeps that requested direction through recovery. Acceptance aligns the visible facing and commits the action once. A small late-recovery buffer accepts at most one next attack/dodge; it is cleared on interruption. Without focus, Guard keeps facing while permitting slower movement. Focus is authoritative simulation state: while idle, moving or guarding, the hero turns towards the one living opponent at a bounded rate. A focused slash takes that bounded facing when accepted, rather than its travel direction. Focus cannot redirect or cancel an accepted slash or dodge. Combat owns simultaneous action priority, eligibility and one-time stamina expenditure.

Damage uses a target disc, range, scenery clearance and the blade's swept angular interval. Thrust reach and blade yaw come from the same action values the presenter uses. A target is resolved once per action. Dodge protection covers only its active interval. Directional blocks spend stamina; insufficient stamina breaks guard and leaves a recovery. Health/stamina and hit/guard/evasion events have one authority.

The enemy approaches inside a local engagement area. Near attack range it briefly seeks a screen-lateral position, preferring the nearer collision-clear side and retaining that side for the attempt. Blocked routes and a 1.25 s attempt limit fall back to direct engagement rather than extending an orbit indefinitely. The same swept collision, occupied fighter disc and local leash remain authoritative. Once accepted, a warned sweep/thrust keeps its origin and direction, then owes its recovery before another choice. Retreat beyond the local leash sends the enemy towards its start. No navmesh, random criticals, weak-point sequence, companion AI, projectile system or physics-driven damage is required.

The [mannequin source](../blender/animations/mannequin/README.md) preserves the original project armature and useful locomotion. A derivative owns basic melee/defence/evasion poses, exported as checked local joint samples. RealityKit mirrors the 17-joint hierarchy using rigid limb proxies; simple hand sockets and separate props avoid an external character mesh or detailed fingers. Displacement advances locomotion, and accepted action phase/progress maps onto authored clip markers. The visible weapon follows the same committed blade geometry used by contact; animation never independently triggers damage. Fresh-run presentation resets its motion baselines. Grip fitting checks natural arm reach and wrist position, not detailed palm/finger grasp; clip changes currently have no transition blend. These are basic-mannequin presentation limits, not new gameplay authority.

DuelStage caches one broad sweep mesh and one narrow thrust mesh, each with a restrained amber fill and outline. During a living enemy's committed wind-up it places the relevant mesh at that action's origin and orientation. The footprint uses DuelAction's reach/half-angle and contact's target-disc radius/angular padding, with a 0.6 m central cutout inside ordinary body separation to keep feet and the focus ring visible. It previews the full action's possible target-centre envelope, not an exact hit map: active timing, target motion and scenery still decide contact. It never tracks the hero independently, creates damage or generates meshes per frame. A full envelope is omitted when scenery blocks its footprint, avoiding a through-wall danger cue; the committed body/weapon pose remains visible. Active/recovery, outcome and reset hide it; stopFeedback hides it on Pause/interruption and a resumed presentation restores only the current wind-up.

## Input and interruption

All input uses the retained GameControls/InputRules path. Keyboard, touch and PS5/Xbox controls share policy. Simultaneous command priority is Pause → fresh Focus → Dodge → Guard → Attack; suppressed edges are consumed. A fresh Focus consumes simultaneous Attack/Dodge requests without dropping held Guard, which remains defensive state. Source/controller/activity changes cancel pending captures using generations and require neutral input. R3/right-stick click, Tab and the touch toggle request the same focus edge.

The world freezes the existing action clock during Pause or input unavailability. It clears buffered future actions and pending frame commands without resetting an enemy's wind-up, owed recovery or focus selection. Captured touch zones stay mounted during Pause; even a centred-stick contact must lift. Retry resets rule state, counters, poses, camera composition and session mode, then requires released controls. Retry or either fighter's defeat clears focus.

The app stays awake while foreground-active, Pause included, and restores normal idle behaviour when leaving the app. One owned scene subscription is replaced/cancelled on reattachment/disappearance. Feedback is drained once and stopped on interruption.

## Camera and focus presentation

The maintainer selected a 35° downward pitch and 45° yaw in the [issue #238](https://github.com/RonildoBraga/lauder/issues/238) follow-up. [PR #242](https://github.com/RonildoBraga/lauder/pull/242), tracked by [issue #241](https://github.com/RonildoBraga/lauder/issues/241), compares projection modes at that orientation. Orthographic is the working preview, including its Release configuration, after passing checks and six recorded runs with visual comparison. Its full vertical world span is approximately 14.998 m at 35°, matched to the preceding perspective view's approximately 10.1% centred 1.85 m actor height. The Debug perspective comparison retains its 24° vertical FOV. These are our 3D adaptations of the [Eitr reference](research/eitr-gameplay-and-reset-proposal.md), not measurements of that game's camera. The [prototype plan](prototype-plan.md#duel-readability-follow-up--in-progress) records source-bound CI/review, verified TestFlight build 48 availability and remaining human feedback/physical acceptance.

CameraRig owns a value-only target and exponentially damped translation towards the hero when free or the fighters' midpoint when focused. Eye and target translate together, preserving camera-relative movement axes; no orbit or zoom system is introduced. WorldCamera applies that same rig to one RealityKit camera entity, using the orthographic or perspective camera component selected for the candidate/comparison. CameraProjection supplies the matching transform and projection to screen-space consumers, including parallel orthographic rays. Reset snaps instead of carrying motion from the previous duel. DuelStage consumes focus state for an enemy ground ring; neither camera nor marker selects targets or changes combat.

Debug-only launch arguments permit `--camera-projection perspective|orthographic` and the retained `--camera-pitch 30.5|35|40` controls in the [Simulator scripts](../CONTRIBUTING.md#scripted-simulator-playtests). The [earlier comparison record](prototype-plan.md#camera-pitch-comparison--verified-in-simulator) preserves the calibrated perspective offsets; the [readability follow-up](prototype-plan.md#duel-readability-follow-up--in-progress) owns current validation. Release ignores these arguments and keeps the fixed working-preview view. Playtest summaries record actual projection, optional orthographic span, pitch, offset and observed warning kinds. Comparisons reuse ordinary command routes without injecting poses or outcomes.

## Content and authoring

The active route is flat connected corridors, two rooms, an alcove, return connection and exit, rendered from shared boxes/doorframes with deliberate camera-near cutaways. Visual wall heights do not remove their solid footprints. No historical character, bridge or robot USDZ is loaded or packaged. Three deterministic WAVs and one checked mannequin JSON resource are active. Source/export hashes and structure/pose tests validate animation provenance and payloads alongside the existing resource/scenario/sound checks.

Authored Blender assets and their byte-preserved [reference exports](../blender/reference-exports/README.md) remain available, with source fingerprints and licences. The exporter now targets that reference folder. Retaining an authored model is distinct from shipping it in the app.

## Validation and next gates

Run the full [check](../scripts/check) and the four [scripted Simulator routes](../CONTRIBUTING.md#scripted-simulator-playtests), including the complete journey, defence, recovery and focus routes. Native tests cover combat, shared input, lifecycle/reset, collision and camera projection. Portable tests cover authoring/export, active resource declarations, sound generation, recording and release contracts. The [prototype plan](prototype-plan.md) owns exact source/results and remaining physical acceptance gates.

Human readability/fun and physical control/performance acceptance remain separate from the [verified TestFlight delivery](prototype-plan.md#internal-testflight-build-48--available). Parrying, charged attacks, simultaneous enemy groups, progression and new art follow the [research roadmap](research/eitr-gameplay-and-reset-proposal.md) only after their gates. Future deliveries follow the same source/signing/Apple-processing/tester checks within the maintainer's authorised scope.
