# Lauder — architecture

**Updated:** 27 November 2026

**Status:** Bridge-only runtime with a three-character party ([ADR 0017](decisions/0017-bridge-only-reset.md)). Swift, RealityKit and SwiftUI remain accepted. The [prototype plan](prototype-plan.md) owns current verification, delivery gates and source-specific historical records; this document owns the runtime boundaries below.

## Decision and platform

Use Swift for rules and gameplay, RealityKit for the 3D world and SwiftUI for the interface ([ADR 0001](decisions/0001-engine.md)). The iPhone app targets iOS 27.0 or later in landscape with Xcode 27.2. The target is 60 fps on the baseline iPhone 13 Pro Max; a target is not a measured result.

The maintainer approved these focused separations in [ADR 0018](decisions/0018-runtime-boundaries.md). They preserve the bridge's current behaviour.

## Shape of the project

Keep one app target and one hosted Swift Testing target, with ordinary feature folders under `apple/`. Xcode folder-synchronised groups include sources and tests without per-file project edits. Blender source and its export extension live under `blender/`; no new package hierarchy, dependency, custom ECS or rendering framework is needed.

| Owner | Responsibility | Boundary |
|---|---|---|
| Game | Hold the bridge's stable GameWorld | SwiftUI reevaluation does not rebuild it; no level-switch flow |
| GameSession | Mode, party/leader, formations/orders, combat checkpoints, dialogue and accepted commands | Authority over live session progress; no entities |
| BridgeProgress / StoryBeat | Checkpointable bridge progression / authored story markers | Checkpointable rules and independent content data |
| WorldCamera / CameraRig | Camera entity and landmark fading / follow, lean, switching, lens and projection | Presentation owner and value-only camera motion |
| GameWorld | Bodies, scene, camera, movement, companion routing, encounters and one owned update subscription | Spatial state; no duplicate session progress |
| CompanionTactics | Local role, firing stance, threat avoidance and cover intentions for non-leaders in the engaged strategic guard fight | Pure values and geometry queries; no entities, orders, damage or weapon execution authority |
| EncounterSimulation | Native weapon handling, targeting, actual rays, hostile timing, cues, recoil/hit/fall values and feedback events | Plain Swift, no RealityKit or sound/haptic playback |
| RobotGuard | Bounded patrol, sight, turns, committed bursts, leg-break stagger, mobility penalty and shared hull drop | Value state advanced by EncounterSimulation; no entities |
| GuardTargeting | Recent actual-attacker memory and stable member selection between strategic-guard cycles | Value state; EncounterSimulation supplies native attack evidence and real visibility/range, RobotGuard retains physical turning and commitment |
| GuardStrategy / DamageHit | Shared health, persistent eye bonus and independent leg counters / resolved applied-damage evidence | Pure values; real contact is resolved by EncounterSimulation, and presentation cannot award damage |
| Grenade | One committed arc, scenery contact, landing fuse and blast falloff | Value state; EncounterSimulation owns Tom eligibility, recharge and accepted enemy damage |
| ScoutDrone | A scout drone's circling, warning, committed dive, burst timing, low pass, fall and airspace (walls to go round, low cover to rise over) | Value state advanced by EncounterSimulation, which chooses its target and resolves its rounds and every hit on it; DronePresentation draws it ([issue #201](https://github.com/RonildoBraga/lauder/issues/201)) |
| Crawler | A pack crawler's folding, getting up, walking round blockers and the guard's hull, the fixed-line wind-up, ram, recovery, leash and fall | Value state advanced by EncounterSimulation, which chooses its target and resolves its ram's hit and every hit on it; CrawlerPresentation draws it ([issue #208](https://github.com/RonildoBraga/lauder/issues/208)) |
| EncounterStage | Reusable hostile/weapon entities, robot joint, drone and crawler presentation, target markers and shot effects | Presentation only; no damage or navigation authority |
| DamageFeedback / DamageNumbers | Bounded transient damage totals / projected noninteractive labels | Consumes the existing captured event batch; no health, input, weapon or target authority |
| GameControls / InputRules | Device sampling, touch state, command edges, source arbitration and neutral gates | Intents only; no second pause/dialogue policy |
| Content | Bridge layout, words, triggers, encounters, models and sounds | Typed definitions and bundle resources |

## Scene and asset authoring

The Brooklyn Bridge is the only playable `Level`. Its Blender file exports `BrooklynBridge.usdz` and `BrooklynBridgeLayout.swift` ([ADR 0002](decisions/0002-blender-source-of-truth.md)). `BrooklynBridge.swift` adds words, stable references, triggers and encounter definitions. Export refuses to drop layout names gameplay uses. [Contributor instructions](../CONTRIBUTING.md#editing-a-level-in-blender) describe authoring.

`Level` contains flat ground bounds, blocker boxes, triggers, encounters, starting party/spawns, heading, camera/lights and an optional scene resource. Small test-only levels use the same data with plain geometry. They are not alternate app scenes. There is no terrain, gate, salvage, arena or optional-guard schema.

The C robot is a runtime-spawned model. Its dedicated export preserves the named rigid joint hierarchy and generates `RobotModelGeometry.swift` from Blender link lengths, foot/hip positions, bounds and muzzle markers. Both outputs are fingerprinted with their source. The presenter uses actual bounded movement, turns and firing state to pose those parts; the reviewed Blender timeline remains an authoring study, not a runtime root-motion clip. Other models keep the existing static export. No parallel geometry authoring or generic animation framework is introduced.

The current revision reuses all four independent leg connector subtrees. RobotPresentation colours the existing eye red, hides lost assemblies and animates at most four noncolliding debris clones under a stable parent; RobotMotion skips missing feet. The locomotion follow-up slows physical turning in RobotGuard and remaining-leg swing timing in RobotMotion, without adding a separate presentation tilt. The measured all-leg-loss hull drop is shared with native muzzle, eye and body targets, keeping visible and physical positions aligned. The new stagger routes its bounded body dip through that same physical offset; EncounterSimulation accepts the real new-leg event, RobotGuard owns interruption and the owed recovery, and the existing feedback path supplies the generated sound. One shared recovery-completion path advances the pattern and selects the normal bounded reposition, including when the stagger consumes the last owed recovery time. Defeat captures the current shared drop before cancelling the pulse, preserving physical and visible height. No Blender source or exported mesh is rewritten for these runtime signals, and no rigid-body solver owns damage or movement.

The world loads the bridge synchronously and retains it across Restart. Figure model templates produce independent clones. A single scene needs no level replacement, scene-template cache, cross-level navigation cache or transition timing subsystem. `SceneStyle` supplies simple materials and signal colours. Preserve Blender provenance and asset licensing.

## Swift conventions

- Swift 6 language mode and complete concurrency checking; session/UI/world coordination stays on the main actor.
- Swift Testing for meaningful value and production-integration regressions.
- Toolchain `swift format` with [apple/.swift-format](../apple/.swift-format), two-space indentation and 100-column lines.
- `./scripts/check` runs Blender/export tests, generated-sound validation, formatting, app build and hosted tests. [Validation](../CONTRIBUTING.md#validation) defines destinations and required tools.

## Runtime ownership

GameSession composes a BridgeProgress value and owns exploring/dialogue/paused mode, the party in switching order and active leader, Close/Spread/Column, each companion's following/going/holding order, one-shot trigger progress, bridge story beat, fight checkpoint/hits/defeated IDs and dialogue cursor. BridgeProgress keeps the bridge's beats in order: only the next can begin. A level can still start with fewer than three and recruit the others, a rule the tests keep; the bridge starts with all three. StoryBeat is shared content data without a dependency on GameSession.

GameWorld owns a body for every stable member ID, their visibility and position, companion routes/motors/targets, the navigation grid and flat movement blockers. Figures outside the party stay hidden; on the bridge all three travel from the start. It owns a WorldCamera and one EncounterSimulation/EncounterStage pair. WorldCamera owns camera/landmark presentation; CameraRig computes its motion and projection without scene entities. App activity, input availability and input readiness are operational gates, not extra gameplay modes.

The owned update samples controls, resolves InputRules using session mode, handles the accepted intent and advances fixed-step movement/combat while allowed. Entity transforms do not publish through SwiftUI every frame. UI observes coarse state and plays emitted feedback while active.

## Input and command routing

Controller, keyboard and touch share InputRules; the [input contract](prototype-plan.md#input-and-interaction-contract) lists bindings. Controller preference and **Use touch controls / Use controller** choose a source without bypassing session authority. PS5 and Xbox use extended-gamepad elements; Xbox physical delivery remains unverified.

Pause wins over simultaneous commands. A single Next command cycles Miki, Tom and Laura; there is no Previous binding. Switches, formation and order commands suppress a same-sample action or dodge roll while consuming its held edge. Dialogue and Pause consume unavailable gameplay presses rather than queueing them. Holding movement through a leader switch moves the new leader without moving anybody to a new position.

Pause/resume, source changes, interruption and reconnection require neutral input. Every held key, button and finger counts, including a centred-stick contact. Source changes cancel touch captures using generation tokens; stale callbacks cannot write into a fresh source. Keep the touch surface mounted on Pause so release is observable. A quick tap is latched until a sample, then delivered once.

Touch targeting shares the native lock and assisted-aim rules. A short tap selects an eligible projected body envelope, using its full height and navigation radius with a 30-point exterior allowance; it never fires or selects a part. Tapping the selected body releases it. An empty valid tap retains an on-screen or partly visible lock and releases an entirely off-screen lock; invalid taps or projection data do not release it. The held-order menu shares its drawn option rectangles with selection, retaining the original ground mark and the near-origin reset. Visible choices take priority over directional sectors outside that reset area; the [touch contract](touch-controls.md) records the remaining top-edge cancellation limit.

Tom's manual grenade uses Circle/B, keyboard C or the touch Grenade button while he leads. Its fresh edge follows the same InputRules priority and neutral gates. EncounterSimulation rechecks Tom ownership and scripted holds; a pending request cannot transfer to a different leader or replay after interruption. The grenade is separate from the paired-weapon slots, and companions cannot throw automatically.

Pause has **Resume**, **Restart**, **Vibration** and **Status panel**, opens on Resume and navigates on fresh up/down presses. Action confirms; Escape/Options/Menu resumes. Touch exposes all four choices directly; Status panel hides or shows the HUD on every input path. Release guidance remains visible when the panel is hidden. Restart takes effect without an extra confirmation. The pause view shows the bundle's actual version/build.

## Movement and presentation

Movement maps camera-relative input onto the flat ground. PartyMotion applies exact blocker clearance and separation. NavigationGrid routes through legal space; SquadPlanner chooses distinct formation places, and CompanionMotor follows/settles/yields rather than copying every footprint. Narrow space compresses the formation, which expands when room returns. Orders project a marked point through the current camera and reject inaccessible destinations rather than teleporting anybody.

The leader's [dodge roll](decisions/0019-dodge-roll.md) replaces their walking movement for 0.45 s. `DodgeRoll` supplies each fixed step's share of its 3 m and PartyMotion resolves it like any movement. `EncounterSimulation` leaves the rolling leader out of the hostiles' shot targets, while hostiles still see and follow them.

The party's pawns have no rig. Each fixed step, `PawnGait` turns the movement a body has just made into a bob, a rock to the side and a lean. The figure turns about its feet, and the lean adds to the shot and hit jolt ([ADR 0008](decisions/0008-weapon-feel-and-combat-plan.md)). A move of over a metre in one step, such as a retry, resets the walk. A rolling leader shows the roll's tumble instead. All of this is presentation; the bodies that move, collide and are hit stay where the simulation resolved them.

The camera follows the active leader and eases on a switch, retaining the elevated angle. Aiming/fighting narrows its lens. The bridge's tall towers fade when between camera and party. Goals from the authored layout drive the compass. Status messages expire in play time; Pause and dialogue hold them.

The strategic branch gives the leader, target, lock, order and DEBUG destination markers one shared centre height, 4.5 cm over the snow, so their undersides clear the towers' baked shadow planes at 3 cm. Marker placement remains presentation; it does not move a body or alter targeting.

## The opening

The bridge starts with Miki, Tom and Laura together, Tom and Laura in the Close formation's places behind Miki. Its beats are the crossing, the first-tower guard and the Manhattan end. Timed encounter cues reveal/engage the robot and begin the closing exchange. Content owns text and authored points. The session owns which beats have completed; the world owns where bodies stand. The internal `stranger` beat retains its stable identifier across the robot replacement.

### The action press

With the supply case's search and Laura's Help gone, the bridge has no contextual actions: while exploring, the action press looks around. Of the older scene cues, only a scripted shot remains for later scenes. The cues for a member appearing, standing up or turning to face another were removed once nothing used them.

### Fights

Every leader carries two weapons and switches between them ([ADR 0021](decisions/0021-paired-weapons.md)): Miki a long rifle and an assault rifle, Laura a shotgun and an energy sword, Tom a minigun and a shield dome. EncounterSimulation keeps a WeaponHandling for each of the six, so draw/cooldown/magazine/reload state survives switching weapon and switching leader; a reload goes on while its weapon is put away. Rounds are not counted beyond the magazine: an empty one reloads by itself. The minigun spins up before it fires and slows the leader, the sword's swing strikes hostiles in an arc in front of Laura, and her drawn sword and Tom's raised dome stop hostile shots before they land. Practice outside a fight deals no hits.

Manual aim turns the leader at a bounded rate; without it, assistance picks a visible target in effective reach and Fire waits until facing it. A [lock](decisions/0020-lock-on.md) takes the stick's place: the leader turns to the locked hostile, and Fire waits until facing them. Spread follows movement, turning and recent shots. Ballistics traces actual shots through the flat level bounds, body cylinders and real box heights; a miss can strike scenery and a long ray is not truncated at assistance reach. Unengaged people hold deliberate fire. No line exposes an enemy's exact aim.

In the current bridge, the first-tower robot patrols a bounded area, notices a visible target, braces and tracks, then commits its aim point before alternating three-round precision and five-round fan bursts. Its gun transforms supply the actual 3D ray origins/directions; seeded spread and tower geometry resolve hits. EncounterSimulation advances a GuardStrategy value for the guard’s shared health, eye criticals and independent leg damage, then records defeat in GameSession at zero health. Companions use their native weapons in an engaged fight only under explicit Attack; Defend stops their fire and recalls them under the existing order and cover rules. Each burst can cause at most one injury, and a third injury invokes the bridge encounter’s retry. Reaching the authored west exit instead clears the encounter and pending fire without recording a kill. Both completed resolutions recover encounter-local injuries; retreat while the encounter remains active preserves progress. Tom’s ambush is removed; generic human timing and scripted-shot cues remain covered by test fixtures.

The historical build 33 prototype required sensor/coupling prerequisites and twelve accepted minigun reactor contacts. Builds 36–37 replaced that victory gate with shared health and optional matched-weapon bonuses, retaining four-second core windows. The current [damage revision](damage-feedback.md) retains one health pool but removes that part sequence: any actual firearm eye hit is critical, and three sword contacts on one intact leg detach it. Lost legs reduce translation; the [locomotion follow-up](robot-eye-legs-grenades.md#leg-loss-locomotion-follow-up) also reduces physical turning and remaining-foot cadence. Four losses settle the hull while a slow emergency pivot, warning and firing remain. Zero health is the sole damage-based victory condition, without an actor-identity gate.

EncounterSimulation resolves actual bullet/sword contacts once, applies health reduction and then emits a DamageHit with target, attacker, weapon, applied amount, 3D impact, effectiveness and component-break evidence. Scenery/ally/missed contacts cannot generate enemy-damage numbers. Sword contacts retain reach, arc and solid-cover checks; weak-point classification cannot invent an effective hit from an origin inside an oversized component. The same path serves player and companion damage. Manual leadership, weapon handling, cover/rays, retry and the west bypass retain their existing owners. This is the same encounter's state, not another session authority.

Grenade flight traces short segments against real scenery, commits its destination and starts a landing fuse. Its explosion checks radius and solid-cover visibility once per enemy, then uses the same applied-health path with no paired-weapon attribution, eye bonus or sword-leg progress. One native recharge survives leader switches; Pause freezes flight/fuse/recharge and Retry/Restart clears them. Presentation draws a pooled projectile and short blast footprint, reusing one impact event for sound rather than adding damage authority.

EncounterStage projects poses, tracers/flashes/impacts and reusable target markers. Feedback events select the retained native weapon/impact sounds and leader haptic cues. Sound/haptic playback follows lifecycle and the Vibration preference.

The captured frame event batch also supplies bounded DamageFeedback values and the noninteractive SwiftUI DamageNumbers overlay, projected from actual 3D impact positions. Normal and effective hits retain separate white/red totals with an additional weak-point symbol. Rapid minigun and assault-rifle hits accumulate briefly by enemy, attacker, weapon and effectiveness; the model retains applied amounts while limiting labels and their lifetime. EncounterStage extends the existing effects presenter with four reusable effective-hit glints and caches marker materials. The UI shows the shared guard health rather than calculating damage. Pause/inactivity and encounter-reset identity cancel or suspend stale feedback; there is no second event drain or duplicate impact sound path. The [damage contract](damage-feedback.md) owns initial presentation values and verification.

For guard retaliation, EncounterSimulation records accepted native discharges or sword contacts in a guard-owned `GuardTargeting` value. Selection changes only in patrol/search; member identity stays fixed through a warned cycle, and RobotGuard freezes its aim point at commitment. Quiet acquisition retains the leader's original cone; engaged flank retaliation still requires real sight/range, finite turning and full warning. On notice entry, one `guardTargeted` event uses the existing audio path. GameWorld exposes the active target for a passive named HUD cue; the UI neither selects targets nor schedules attacks. No second combat/session authority or generic threat service is added. The [contract](guard-retaliation.md) owns tuning and verification boundaries.

### Scenes

An encounter that holds the party advances only its cues: on the bridge, the closing exchange. Movement, Fire, grenade throws and actions cannot interrupt its placement. Pause still works. A conversation suspends the remaining frame. These are bridge story sequences, not extra playable levels.

## Bounded companion autonomy

The player remains the only authority driving the leader. GameSession owns a standing Attack/Defend stance, defaulting to Defend. CompanionTactics supplies pure, local intentions for non-leaders in an engaged strategic-guard encounter: after an explicit Attack command Miki/Tom prefer useful eye shots and Laura intact legs with her sword, with safe ordinary body attacks when that opportunity is unavailable. The fallback selects the existing long rifle, shotgun or minigun and uses cached local legal firing/support places. EncounterSimulation checks stance again before preparing or firing actor-owned weapons; physical rays/contact, range, allies and shared damage resolution remain authoritative. GameWorld retains legal spatial movement and the existing session's order/leader authority. Ordinary weapon cadence, turning, magazines/reloads and vulnerability apply rather than scripted damage. Fresh formation targets remain separate from tactical overrides, and fixed tactical legs do not inherit formation-target velocity. Grenade throwing remains player-controlled Tom only.

Companions may seek nearby firing/cover positions and avoid committed fire, bounded by an initial 8 m leader leash. Hold anchors and Go destinations override autonomous movement. Defend revokes companion attack authority, clears existing position orders and recalls them via useful local cover; covered targets must advance toward the leader rather than become an implicit remote Hold. Subsequent position orders never arm attacks. Formation/Follow still regroups temporarily without changing stance; a new accepted Go/Hold order replaces that interval and a refused order retains it. Forward marks and all admitted position goals include the living guard’s hull clearance. Retreat suppresses attacks. An unaware guard or quiet bypass cannot be engaged by a companion. Switching cancels autonomous control of the new leader immediately but retains the squad stance; Retry/Restart returns it to Defend. This is encounter-specific decision logic within existing owners, not a general AI framework or a new source of session progress. [Companion autonomy](companion-autonomy.md) defines the accepted scope and verification boundary.

## Restart and lifecycle

Restart resets session progress and native weapon handling in place, restores authored body/spawn/visibility states and the opening line, clears routes/markers/reactions/shot effects and cancels the current scene/retry. It resets camera transition and owed simulation time, then requires neutral input. It neither rebuilds static geometry nor adds a second update subscription.

Inactivity freezes gameplay, stops feedback and clears held input. Resume resets frame timing and requires release before fresh input. Leaving the view cancels owned updates. The screen stays awake while foreground play or Pause is active and restores normal idle locking on leaving.

## Saving and interruption

Persistence remains unimplemented later hardening. Define versioned value snapshots with story beat, stable party/leader IDs, inventory and a safe authored group placement. Never serialize entity graphs or transient routes/animation. Use one ordered atomic writer, invalidate stale work on Restart and preserve unreadable saves until an explicit player decision.

## Checks

Tests cover bridge progression/retry, session authority and input priority/release, camera mapping, native weapon timing and feedback, actual long rays/neutral safety, collision and squad motion. Separate fixtures retain recruitment and scripted-cue rules without restoring those removed bridge scenes. A test-only yard with a narrow doorway exercises clearance the bridge cannot provide; a flat range exercises weapon rules without changing app content.

Portable contract checks compare scenario and resource declarations across Swift, Python and Blender. Offline TestFlight contract tests also run without credentials or network access. The versioned `apple/scripts/testflight` command owns release discovery, source-bound checks, signing/archive verification, upload and read-only processing/tester verification; its team/credentials and receipts/archives stay private. The same standard check runs in CI on the selected compatible Xcode image; the PR records the actual result.

DEBUG scripted routes use ordinary input in headless and rendered Simulator runs; `./apple/scripts/playtest --list` gives the checked-out source's set. See [verification](prototype-plan.md#verification-and-performance). Pointer-driven touch is not physical multi-touch, and Simulator controller enumeration does not prove live input forwarding. Physical behaviour, performance and enjoyment require separately recorded evidence.

## Deliberately deferred

Other playable scenes and the retired prototypes' frameworks, autonomy outside the current bridge encounter, automatic cover stances, further tactical enemies beyond the current guard, drones and crawlers, automatic companion grenades or a general projectile/ability framework, signatures, elevation, salvage-repair interactions, weapon benches, health/hunger, crafting, skill trees, persistence, networking and art expansion. Current architecture is the bridge's needs; new work follows an agreed gameplay question and explicit assignment.
