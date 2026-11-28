# Lauder architecture

**Updated:** 28 November 2026. **Scope:** the single-hero graybox duel tracked in [issue #236](https://github.com/RonildoBraga/lauder/issues/236). [ADR 0022](decisions/0022-single-hero-graybox-duel.md) records the authorised experiment; the [bridge checkpoints](milestones/bridge-prototype.md) preserve the previous runtime.

## Platform and boundaries

Swift 6 language mode, RealityKit rendering, SwiftUI interface and Swift Testing remain accepted. Keep one app/module and one hosted test target, with ordinary lowercase folders. There are no third-party runtime dependencies, new packages, generic combat framework or custom ECS. The iPhone target remains iOS 27 or later with Xcode 27.2; 60 fps on the baseline iPhone is a target, not a verified result.

| Owner | Responsibility | Boundary |
| --- | --- | --- |
| Game / LauderApp | Stable world, app scene phase and foreground idle-timer policy | SwiftUI updates do not recreate gameplay |
| GameSession | Exploring/paused mode, Resume/Restart choice | No spatial or damage state |
| GameControls / InputRules | Source selection, touch generations, neutral gates, fresh edges and Pause priority | Input intents; no stamina, damage or action legality |
| TouchInput / TouchControls | Independent finger capture, held/pending taps and UIKit surface | Mounted during Pause; no gameplay authority |
| GameWorld | One scene subscription, fixed-step accumulator, accepted pending edges, interruption/reset and presentation coordination | Does not duplicate combat rules |
| DuelSimulation | Hero/enemy positions, facing/focus, health/stamina, action timelines, enemy decisions, collision and outcomes | Plain Swift values; no entities, UI or audio |
| DuelAction | Preparation/contact/recovery, committed direction and shared blade pose | One timing source for contact and rendering |
| PartyMotion / Movement | Swept flat collision and camera-relative ground directions | Retained geometry; party naming does not imply companions |
| CameraRig / WorldCamera / CameraProjection | Fixed diagonal orientation, smooth hero/pair framing and shared projection / camera entity | Consumes focus state; no combat or input authority |
| DuelStage | Primitive models, resolved poses, wind-up warning meshes and three sound effects | Consumes state/events; cannot award damage |
| PlaytestRunner | DEBUG-only command routes and evidence | Uses ordinary input; cannot inject health, attacks or outcomes |

## Swift conventions

Use Swift 6 language mode and complete concurrency checking. Session, UI and scene owners stay on the main actor; combat and geometry use plain Sendable values. Use Swift Testing and toolchain swift format with the committed apple/.swift-format (two-space indentation, 100-column lines). The standard check verifies formatting, build and hosted tests.

## Rules and presentation

The world samples controls once, preserves fresh Attack/Dodge/Focus edges until a simulation tick, and advances at 120 Hz. Slow frames have bounded catch-up. Simulation subdivides a direct slow caller too, so an active interval is not skipped. Inputs are not replayed on every substep.

The hero moves in the input direction. A free slash records valid movement direction at the request, falling back to current facing without movement; a queued slash keeps that requested direction through recovery. Acceptance aligns the visible facing and commits the action once. A small late-recovery buffer accepts at most one next attack/dodge; it is cleared on interruption. Without focus, Guard keeps facing while permitting slower movement. Focus is authoritative simulation state: while idle, moving or guarding, the hero turns towards the one living opponent at a bounded rate. A focused slash takes that bounded facing when accepted, rather than its travel direction. Focus cannot redirect or cancel an accepted slash or dodge. Combat owns simultaneous action priority, eligibility and one-time stamina expenditure.

Damage uses a target disc, range, scenery clearance and the blade's swept angular interval. Thrust reach and blade yaw come from the same action values the presenter uses. A target is resolved once per action. Dodge protection covers only its active interval. Directional blocks spend stamina; insufficient stamina breaks guard and leaves a recovery. Health/stamina and hit/guard/evasion events have one authority.

The enemy approaches inside a local engagement area. Near attack range it briefly seeks a screen-lateral position, preferring the nearer collision-clear side and retaining that side for the attempt. Blocked routes and a 1.25 s attempt limit fall back to direct engagement rather than extending an orbit indefinitely. The same swept collision, occupied fighter disc and local leash remain authoritative. Once accepted, a warned sweep/thrust keeps its origin and direction, then owes its recovery before another choice. Retreat beyond the local leash sends the enemy towards its start. No navmesh, random criticals, weak-point sequence, companion AI, projectile system or physics-driven damage is required.

DuelStage caches one broad sweep mesh and one narrow thrust mesh, each with a restrained amber fill and outline. During a living enemy's committed wind-up it places the relevant mesh at that action's origin and orientation. The footprint uses DuelAction's reach/half-angle and contact's target-disc radius/angular padding, with a 0.6 m central cutout inside ordinary body separation to keep feet and the focus ring visible. It previews the full action's possible target-centre envelope, not an exact hit map: active timing, target motion and scenery still decide contact. It never tracks the hero independently, creates damage or generates meshes per frame. Active/recovery, outcome and reset hide it; stopFeedback hides it on Pause/interruption and a resumed presentation restores only the current wind-up.

## Input and interruption

All input uses the retained GameControls/InputRules path. Keyboard, touch and PS5/Xbox controls share policy. Simultaneous command priority is Pause → fresh Focus → Dodge → Guard → Attack; suppressed edges are consumed. A fresh Focus consumes simultaneous Attack/Dodge requests without dropping held Guard, which remains defensive state. Source/controller/activity changes cancel pending captures using generations and require neutral input. R3/right-stick click, Tab and the touch toggle request the same focus edge.

The world freezes the existing action clock during Pause or input unavailability. It clears buffered future actions and pending frame commands without resetting an enemy's wind-up, owed recovery or focus selection. Captured touch zones stay mounted during Pause; even a centred-stick contact must lift. Retry resets rule state, counters, poses, camera composition and session mode, then requires released controls. Retry or either fighter's defeat clears focus.

The app stays awake while foreground-active, Pause included, and restores normal idle behaviour when leaving the app. One owned scene subscription is replaced/cancelled on reattachment/disappearance. Feedback is drained once and stopped on interruption.

## Camera and focus presentation

The maintainer selected a 35° downward pitch and 45° yaw in the [issue #238](https://github.com/RonildoBraga/lauder/issues/238) follow-up. [PR #242](https://github.com/RonildoBraga/lauder/pull/242), tracked by [issue #241](https://github.com/RonildoBraga/lauder/issues/241), compares projection modes at that orientation. Orthographic is the working preview, including its Release configuration, after passing checks and six recorded runs with visual comparison. Its full vertical world span is approximately 14.998 m at 35°, matched to the preceding perspective view's approximately 10.1% centred 1.85 m actor height. The Debug perspective comparison retains its 24° vertical FOV. These are our 3D adaptations of the [Eitr reference](research/eitr-gameplay-and-reset-proposal.md), not measurements of that game's camera. The [prototype plan](prototype-plan.md#duel-readability-follow-up--in-progress) records the verified source and pending CI, review and physical acceptance gates.

CameraRig owns a value-only target and exponentially damped translation towards the hero when free or the fighters' midpoint when focused. Eye and target translate together, preserving camera-relative movement axes; no orbit or zoom system is introduced. WorldCamera applies that same rig to one RealityKit camera entity, using the orthographic or perspective camera component selected for the candidate/comparison. CameraProjection supplies the matching transform and projection to screen-space consumers, including parallel orthographic rays. Reset snaps instead of carrying motion from the previous duel. DuelStage consumes focus state for an enemy ground ring; neither camera nor marker selects targets or changes combat.

Debug-only launch arguments permit `--camera-projection perspective|orthographic` and the retained `--camera-pitch 30.5|35|40` controls in the [Simulator scripts](../CONTRIBUTING.md#scripted-simulator-playtests). The [earlier comparison record](prototype-plan.md#camera-pitch-comparison--verified-in-simulator) preserves the calibrated perspective offsets; the [readability follow-up](prototype-plan.md#duel-readability-follow-up--in-progress) owns current validation. Release ignores these arguments and keeps the fixed working-preview view. Playtest summaries record actual projection, optional orthographic span, pitch, offset and observed warning kinds. Comparisons reuse ordinary command routes without injecting poses or outcomes.

## Content and authoring

The duel is a flat arena with boundary collision and two edge pillars, rendered from primitive boxes. The two foreground boundaries use low visual curbs to keep feet visible from the diagonal camera; the collision boxes remain unchanged. No historical character, bridge or robot USDZ is loaded or packaged. Three deterministic generated WAVs are active. Resource/scenario/sound drift tests validate actual packaged files.

Authored Blender assets and their byte-preserved [reference exports](../blender/reference-exports/README.md) remain available, with source fingerprints and licences. The exporter now targets that reference folder. Retaining an authored model is distinct from shipping it in the app.

## Validation and next gates

Run the full [check](../scripts/check) and the four [scripted Simulator routes](../CONTRIBUTING.md#scripted-simulator-playtests), including the focus follow-up. Native tests cover combat, shared input, lifecycle/reset, collision and camera projection. Portable tests cover authoring/export, active resource declarations, sound generation, recording and release contracts. The [prototype plan](prototype-plan.md) owns exact source/results and remaining physical acceptance gates.

Human readability/fun and physical control/performance acceptance remain separate. Parrying, charged attacks, a second enemy, exploration/progression and new art follow the [research roadmap](research/eitr-gameplay-and-reset-proposal.md) only after their gates. TestFlight source/signing/Apple-processing/tester verification remains required for a separately authorised release.
