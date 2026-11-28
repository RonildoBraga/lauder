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
| DuelStage | Primitive models, resolved poses and three sound effects | Consumes state/events; cannot award damage |
| PlaytestRunner | DEBUG-only command routes and evidence | Uses ordinary input; cannot inject health, attacks or outcomes |

## Swift conventions

Use Swift 6 language mode and complete concurrency checking. Session, UI and scene owners stay on the main actor; combat and geometry use plain Sendable values. Use Swift Testing and toolchain swift format with the committed apple/.swift-format (two-space indentation, 100-column lines). The standard check verifies formatting, build and hosted tests.

## Rules and presentation

The world samples controls once, preserves fresh Attack/Dodge/Focus edges until a simulation tick, and advances at 120 Hz. Slow frames have bounded catch-up. Simulation subdivides a direct slow caller too, so an active interval is not skipped. Inputs are not replayed on every substep.

The hero moves in the input direction and commits facing for a slash. A small late-recovery buffer accepts at most one next attack/dodge; it is cleared on interruption. Without focus, Guard keeps facing while permitting slower movement. Focus is authoritative simulation state: while idle, moving or guarding, the hero turns towards the one living opponent at a bounded rate. It cannot redirect or cancel an accepted slash or dodge. Combat owns simultaneous action priority, eligibility and one-time stamina expenditure.

Damage uses a target disc, range, scenery clearance and the blade's swept angular interval. Thrust reach and blade yaw come from the same action values the presenter uses. A target is resolved once per action. Dodge protection covers only its active interval. Directional blocks spend stamina; insufficient stamina breaks guard and leaves a recovery. Health/stamina and hit/guard/evasion events have one authority.

The enemy approaches inside a local engagement area, commits to a warned sweep/thrust, and leaves a recovery before choosing again. It returns towards its start when the hero retreats beyond the local leash. No navmesh, random criticals, weak-point sequence, companion AI, projectile system or physics-driven damage is required.

## Input and interruption

All input uses the retained GameControls/InputRules path. Keyboard, touch and PS5/Xbox controls share policy. Simultaneous command priority is Pause → fresh Focus → Dodge → Guard → Attack; suppressed edges are consumed. A fresh Focus consumes simultaneous Attack/Dodge requests without dropping held Guard, which remains defensive state. Source/controller/activity changes cancel pending captures using generations and require neutral input. R3/right-stick click, Tab and the touch toggle request the same focus edge.

The world freezes the existing action clock during Pause or input unavailability. It clears buffered future actions and pending frame commands without resetting an enemy's wind-up, owed recovery or focus selection. Captured touch zones stay mounted during Pause; even a centred-stick contact must lift. Retry resets rule state, counters, poses, camera composition and session mode, then requires released controls. Retry or either fighter's defeat clears focus.

The app stays awake while foreground-active, Pause included, and restores normal idle behaviour when leaving the app. One owned scene subscription is replaced/cancelled on reattachment/disappearance. Feedback is drained once and stopped on interruption.

## Camera and focus presentation

The [issue #238](https://github.com/RonildoBraga/lauder/issues/238) follow-up uses a fixed 45° yaw, approximately 30.5° downward pitch and 24° vertical field of view. This is our perspective 3D approximation of the [Eitr reference](research/eitr-gameplay-and-reset-proposal.md), not a claim about that game's exact projection.

CameraRig owns a value-only target and exponentially damped translation towards the hero when free or the fighters' midpoint when focused. Eye and target translate together, preserving camera-relative movement axes; no orbit or zoom system is introduced. WorldCamera applies that same rig to the RealityKit camera, and CameraProjection supplies its matching transform/lens to screen-space consumers. Reset snaps instead of carrying motion from the previous duel. DuelStage consumes focus state for an enemy ground ring; neither camera nor marker selects targets or changes combat.

## Content and authoring

The duel is a flat arena with boundary collision and two edge pillars, rendered from primitive boxes. The two foreground boundaries use low visual curbs to keep feet visible from the diagonal camera; the collision boxes remain unchanged. No historical character, bridge or robot USDZ is loaded or packaged. Three deterministic generated WAVs are active. Resource/scenario/sound drift tests validate actual packaged files.

Authored Blender assets and their byte-preserved [reference exports](../blender/reference-exports/README.md) remain available, with source fingerprints and licences. The exporter now targets that reference folder. Retaining an authored model is distinct from shipping it in the app.

## Validation and next gates

Run the full [check](../scripts/check) and the four [scripted Simulator routes](../CONTRIBUTING.md#scripted-simulator-playtests), including the focus follow-up. Native tests cover combat, shared input, lifecycle/reset, collision and camera projection. Portable tests cover authoring/export, active resource declarations, sound generation, recording and release contracts. The [prototype plan](prototype-plan.md) owns exact source/results and remaining physical acceptance gates.

Human readability/fun and physical control/performance acceptance remain separate. Parrying, charged attacks, a second enemy, exploration/progression and new art follow the [research roadmap](research/eitr-gameplay-and-reset-proposal.md) only after their gates. TestFlight source/signing/Apple-processing/tester verification remains required for a separately authorised release.
