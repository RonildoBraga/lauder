# First tower — C robot guard

**Updated:** 23 November 2026.

**Status:** The original C replacement shipped in build 29. The maintainer subsequently assigned heavier walking using the referenced video’s second-order response and enhanced pursuit/cover behaviour. This focused runtime pass is implemented; its standard check and three rendered Simulator routes pass. Earlier checks below remain historical. This is one prototype encounter, with initial tuning rather than settled balance. A’s different-weapon variant remains future reference, and camera B is unchanged.

## Goal and placement

Use one short encounter to test **observe → bait the aim → move or use stone cover → return fire during recovery → advance**. Exploration and salvage still lead the game. The guard replaces the first shooter while Miki is alone; the later knife attacker, Tom's intervention and Laura's medical-kit scene remain.

C starts planted at the existing first-shooter stand marker on the outgoing east side of the first tower. Its old hidden marker is not a path for sliding the large model through stone. Three local patrol goals remain, with a larger bounded first-tower area for pursuit and tower cover: home + `[-7, -5]` to home + `[6, 8]`. It is a local guard envelope, not permission to follow the party across the bridge. Blender supplies a conservative navigation radius covering the animated legs; movement uses that full footprint against existing tower blockers and avoids the party.

Internal beat, marker and interaction IDs retain `stranger` / `searchStranger` for continuity with the opening's progression. These identifiers do not describe the visible character or a body search: the player sees a robot guard and a supply case.

## Movement and source boundary

The accepted [C model](../../blender/assets/spider-bot-heavy/README.md) has four assemblies sharing six leg-component meshes, matching mirrored rest geometry and independent joints. The runtime USDZ preserves those named joints. Generated `RobotModelGeometry.swift` supplies their authored measurements, gun mounts/muzzles and body/navigation sizes from the same fingerprinted Blender source.

Swift combat owns position, facing, sight, attack timing and actual rays. RobotGuard also advances RobotMotion at the fixed step: world-space planted feet and two-link IK use a bounded body pose from a second-order spring/damper. Longer swings, planted dwell and restrained contact settling give weight; acceleration and deceleration affect body lean. The same body pose is included in barrel transforms, so animation cannot move the visible gun away from its shot origin. RobotPresentation only applies the computed pose. It does not advance a second gait or play the authoring reel’s fixed travel and editorial resets. This applies the response principle from [t3ssel8r’s video](https://www.youtube.com/watch?v=KPoeNZZ6H4s), with a focused Swift implementation rather than a general animation framework. The separate keyframed [dormant study](../../blender/assets/spider-bot-heavy/README.md#dormant-to-pursuit-blender-study) remains authoring reference; proximity-triggered waking is not part of this pass. Runtime movement starts at **0.55 m/s**, with **0.8 rad/s** body turning, matching the heavy gait better than the earlier 1.6 m/s proposal.

Initial acquisition uses a **100°** front cone within **14 m**; attack initiation is within **12 m**. After acquisition, unobstructed contact stays known while the body turns along its route. Losing actual line of sight or exceeding detection range returns it to last-seen search; it does not learn hidden positions. A detected opponent outside attack reach invites a bounded pursuit. Losing sight before commitment cancels the attempt; search uses the last seen point, never the opponent’s hidden current position, before patrol resumes. While the encounter remains unresolved, retreat preserves the robot's damage, Miki's injuries and spent ammunition; only an actual encounter retry restores its checkpoint.

## Prototype attack cycle

| Phase | Behaviour | Initial timing |
|---|---|---:|
| Notice | Stop, turn towards Miki and announce the threat | 0.5 s |
| Track and brace | Plant the feet and track at a finite rate | 1.0 s |
| Commit | Freeze a world-space aim point; stop following Miki | 0.35 s |
| Burst | Three rounds total, alternating the two guns | 0.2 s apart |
| Recover | Settle and allow Miki to move or return fire | 1.8 s |
| Pursue/search | Approach the visible opponent or inspect its last-seen position inside the guard area | 8 s lost-contact search |
| Take cover/hold/peek | After damage, reach real occluding tower cover, hold briefly, then emerge and begin a fresh warning | 30 s travel bound, 1.25 s hold, 15 s peek bound |

Cover candidates must fit the whole animated footprint, have a traversable route and block three-dimensional sight to the robot’s body. Low scenery is not sufficient merely because its footprint lies between actors. A cover request cannot redirect a committed burst; repeated hits during retreat, hold and peek do not restart the cycle. A six-second cooldown after emerging gives a return-fire window before another retreat. Without a valid cover route the robot keeps its ordinary combat behaviour, and cover never restores damage or ammunition.

The two guns toe in towards the same committed point, within limited mount yaw, with pitch matching their real muzzle height. Each ray begins at its visible barrel, including brace and recoil offsets. Tower geometry can block either gun independently. Shared map-length ballistics still determine the ray's end; attack range does not truncate a fired shot.

There is **no red aim line or warning cone**. Stance, facing, the commit pause and status feedback announce the attempt; existing muzzle flashes, tracers and impacts describe shots after firing. The initial robot spread is tight, not the human rifle's broad cone. Hits do not restart every wind-up. A burst can cost Miki at most **one injury**, and defeat cancels pending fire immediately.

Start with **six carbine hits** against Miki's **12 starting rounds**. This is a tuning candidate. It must be challenged if standing still and holding Fire is more useful than reading the pattern. There is one ranged pattern; no lunge, melee, grenades, destructible limbs, hidden weak point or extra gun type is added.

## Bypass, supply case and story handoff

The west arch offers a zero-ammunition route. The authored safe exit is `robot.exit`, game coordinates **[-12, -12] to [-7.5, -7.5]**. The enlarged pursuit/cover envelope no longer relies on every exit point being beyond acquisition range. The explicit exit check runs before the next combat step and resolves this first encounter once, without recording a defeated machine, restoring ammunition or resetting the robot's recorded damage. Both defeat and completed bypass recover Miki's encounter-local injuries under the existing bridge rules; unresolved retreat does not. Pending attacks are cancelled before the case/ambush can begin. The bypassed machine stops tracking and cannot reactivate this encounter until Restart.

A small **nonblocking supply case** at **[-8.5, -8]** replaces searching the stranger. It is authored in the bridge's Visual collection, with its marker and interaction area in Gameplay; it adds no cover or collision box. Search becomes available after defeat or safe bypass, grants **six rounds and one medical kit once**, and starts the existing ambush. Tom's arrival marker is closer at **[2, -3]** so his intervention and Miki remain in view. The attacker and recruitment sequence remain otherwise intact, and Laura receives the same kit later.

Robot loot is nil. A distinct one-shot supply cue owns the case contents; a bypass does not impersonate a dead human. Player-facing lines describe the machine and case rather than “Friendly!”, a deliberate human warning miss or searching a corpse.

## Verification and playtest questions

For the original build-29 integration, the standard check passed, including source/export contracts, the app build and Swift Testing. Its rendered Simulator routes passed: first fight **35/35**, retry **15/15** and the full opening **56/56**, with no failures or companion warnings. First-fight marks record actual phases and six emitted enemy shots across two bursts before defeat. [Verification details](../prototype-plan.md#c-robot-on-the-bridge) distinguish these results from phone evidence. Coverage includes:

- Loaded model joints, grounded feet, mirrored components and barrel/ray alignment through movement, turning, bracing and recoil.
- Full-footprint movement around the existing piers, finite facing and no banked or through-stone shots.
- Committed bursts that can be sidestepped, at most one injury per burst and immediate cancellation on defeat/bypass.
- Pause, interruption, neutral-input recovery, retry and Restart without stale shots or sliding animation.
- Zero-ammunition west bypass, one-shot case supplies, Tom/Laura progression and no attacks during the handoff.

For the current assignment, the same eight routes are retained. `first-fight` is extended to observe approach into range, the committed burst, a damage-triggered retreat, independent 3D cover/clearance checks, a peek, reengagement and Restart. Shared routes use a bounded fire-until-defeat step instead of assuming a four-second kill, releasing Fire while stone blocks the robot. The full standard check passes. Fresh rendered runs pass `first-fight` **50/50**, `fight-retry` **15/15** and `opening` **56/56**, with zero failures and companion warnings. The [prototype plan](../prototype-plan.md#c-runtime-walking-pursuit-and-cover) records timings and source scope. These results do not establish phone behaviour, performance, balance or visual acceptance.

Then judge the experience: can a player read the commitment after two cycles, does cover matter, and is repeating this small encounter enjoyable? Simulator correctness does not answer those questions or establish phone performance. Controller/touch feel and sustained physical-device measurements remain for an agreed milestone. Additional enemies, A's variant, new scenes and TestFlight delivery are outside this assignment.
