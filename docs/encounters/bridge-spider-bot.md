# First tower — C robot guard

**Updated:** 23 November 2026.

**Status:** The maintainer accepted C's form and motion, then assigned replacing the first human shooter and testing movement/shooting in Simulator. Runtime integration is implemented; the standard check and three rendered Simulator routes pass. This is one prototype encounter, with initial tuning rather than settled balance. A's different-weapon variant remains future reference, and camera B is unchanged.

## Goal and placement

Use one short encounter to test **observe → bait the aim → move or use stone cover → return fire during recovery → advance**. Exploration and salvage still lead the game. The guard replaces the first shooter while Miki is alone; the later knife attacker, Tom's intervention and Laura's medical-kit scene remain.

C starts planted at the existing first-shooter stand marker on the outgoing east side of the first tower. Its old hidden marker is not a path for sliding the large model through stone. Three local patrol goals and a bounded east-side guard area keep the machine away from the far crossing. Blender supplies a conservative navigation radius covering the animated legs; movement uses that full footprint against existing tower blockers and avoids the party.

Internal beat, marker and interaction IDs retain `stranger` / `searchStranger` for continuity with the opening's progression. These identifiers do not describe the visible character or a body search: the player sees a robot guard and a supply case.

## Movement and source boundary

The accepted [C model](../../blender/assets/spider-bot-heavy/README.md) has four assemblies sharing six leg-component meshes, matching mirrored rest geometry and independent joints. The runtime USDZ preserves those named joints. Generated `RobotModelGeometry.swift` supplies their authored measurements, gun mounts/muzzles and body/navigation sizes from the same fingerprinted Blender source.

Swift combat owns position, facing, sight, attack timing and actual rays. A focused presenter poses the loaded parts from actual movement and turns, with a four-beat crawl and planted-foot step turns. It does not play the authoring reel's fixed travel or editorial resets. Runtime movement starts at **0.55 m/s**, with **0.8 rad/s** body turning, matching the heavy gait better than the earlier 1.6 m/s proposal. No new animation framework or geometry authored in Swift is needed.

The front-facing sight cone is **100°**, with detection within **14 m** and attack initiation within **12 m**. Losing sight before commitment cancels the attempt. Brief search uses the last seen point within the guard bounds, then patrol resumes. While the encounter remains unresolved, retreat preserves the robot's damage, Miki's injuries and spent ammunition; only an actual encounter retry restores its checkpoint.

## Prototype attack cycle

| Phase | Behaviour | Initial timing |
|---|---|---:|
| Notice | Stop, turn towards Miki and announce the threat | 0.5 s |
| Track and brace | Plant the feet and track at a finite rate | 1.0 s |
| Commit | Freeze a world-space aim point; stop following Miki | 0.35 s |
| Burst | Three rounds total, alternating the two guns | 0.2 s apart |
| Recover | Settle and allow Miki to move or return fire | 1.8 s |
| Reposition/search | A short reachable move inside the east guard area, then a fresh warned cycle | Bounded movement |

The two guns toe in towards the same committed point, within limited mount yaw, with pitch matching their real muzzle height. Each ray begins at its visible barrel, including brace and recoil offsets. Tower geometry can block either gun independently. Shared map-length ballistics still determine the ray's end; attack range does not truncate a fired shot.

There is **no red aim line or warning cone**. Stance, facing, the commit pause and status feedback announce the attempt; existing muzzle flashes, tracers and impacts describe shots after firing. The initial robot spread is tight, not the human rifle's broad cone. Hits do not restart every wind-up. A burst can cost Miki at most **one injury**, and defeat cancels pending fire immediately.

Start with **six carbine hits** against Miki's **12 starting rounds**. This is a tuning candidate. It must be challenged if standing still and holding Fire is more useful than reading the pattern. There is one ranged pattern; no lunge, melee, grenades, destructible limbs, hidden weak point or extra gun type is added.

## Bypass, supply case and story handoff

The west arch offers a zero-ammunition route. The authored safe exit is `robot.exit`, game coordinates **[-12, -12] to [-7.5, -7.5]**. Every point in it is beyond the guard's 14 m acquisition radius for its entire allowed position envelope. Reaching it resolves this first encounter once, without recording a defeated machine, restoring ammunition or resetting the robot's recorded damage. Both defeat and completed bypass recover Miki's encounter-local injuries under the existing bridge rules; unresolved retreat does not. Pending attacks are cancelled before the case/ambush can begin. The bypassed machine stops tracking and cannot reactivate this encounter until Restart.

A small **nonblocking supply case** at **[-8.5, -8]** replaces searching the stranger. It is authored in the bridge's Visual collection, with its marker and interaction area in Gameplay; it adds no cover or collision box. Search becomes available after defeat or safe bypass, grants **six rounds and one medical kit once**, and starts the existing ambush. Tom's arrival marker is closer at **[2, -3]** so his intervention and Miki remain in view. The attacker and recruitment sequence remain otherwise intact, and Laura receives the same kit later.

Robot loot is nil. A distinct one-shot supply cue owns the case contents; a bypass does not impersonate a dead human. Player-facing lines describe the machine and case rather than “Friendly!”, a deliberate human warning miss or searching a corpse.

## Verification and playtest questions

The standard check passes, including source/export contracts, the app build and Swift Testing. Rendered Simulator routes pass: first fight **35/35**, retry **15/15** and the full opening **56/56**, with no failures or companion warnings. First-fight marks record actual phases and six emitted enemy shots across two bursts before defeat. [Verification details](../prototype-plan.md#c-robot-on-the-bridge) distinguish these results from phone evidence. Coverage includes:

- Loaded model joints, grounded feet, mirrored components and barrel/ray alignment through movement, turning, bracing and recoil.
- Full-footprint movement around the existing piers, finite facing and no banked or through-stone shots.
- Committed bursts that can be sidestepped, at most one injury per burst and immediate cancellation on defeat/bypass.
- Pause, interruption, neutral-input recovery, retry and Restart without stale shots or sliding animation.
- Zero-ammunition west bypass, one-shot case supplies, Tom/Laura progression and no attacks during the handoff.

Then judge the experience: can a player read the commitment after two cycles, does cover matter, and is repeating this small encounter enjoyable? Simulator correctness does not answer those questions or establish phone performance. Controller/touch feel and sustained physical-device measurements remain for an agreed milestone. Additional enemies, A's variant, new scenes and TestFlight delivery are outside this assignment.
