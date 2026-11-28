# Original-17-bone plain mannequin

A plain rigid mannequin for the dungeon combat prototype ([issue #243](https://github.com/RonildoBraga/lauder/issues/243)). This implements the maintainer's basic armature/body request: no external character mesh, detailed hands, skin weights or new animation framework.

## Source and licence

- **Source:** The original Lauder `Party humanoid skeleton` and project motion from commit `f80fa1391824432726f45c69d51e13a2f0f49334`, historical path `blender/animations/party.blend`. The preserved `original-party.blend` is byte-identical to that Git LFS payload: SHA-256 `7abc47d922621f1685522083afee445927f3625f86b2c19eb7077f437703a4b8`, 4,861,849 bytes.
- **Derived work:** `mannequin.blend` links that original 17-bone Armature data and retains all eleven original source Actions in muted `SOURCE ONLY` tracks. Its local `mannequin.*` Actions derive locomotion/hit poses from the project source and add original melee/guard/quickstep poses authored by Codex. Seventeen rigid box proxies attach to the bones; the head has a separate plain neck proxy and ROOT has no geometry. No canonical 47-bone Miki rig, Tripo model or third-party mesh is used.
- **Licence:** Original Lauder source and this contribution use the project's [MIT licence](../../../LICENSE).

`original-party.blend` is an immutable input. `mannequin.blend` is the editable derivative; saving it does not automatically export the runtime JSON. The source files are stored using Git LFS. There are no missing relative libraries or character textures.

## Runtime boundary

The app packages only [mannequin.json](../../../apple/sources/content/mannequin.json), a compact table of bone hierarchy/rest poses, rigid-box descriptors, clip samples, phase markers and hand-socket conventions. No Blender file, USDZ, image or movie from this folder is packaged.

`Mannequin` creates a real 17-entity joint hierarchy and uses the same box descriptors as Blender. `DuelStage` places/yaws the actor and owns the separate sword/shield. Gameplay state owns movement, facing, action phases and contacts; the body does not award damage or move the gameplay actor.

- Resolved displacement advances the gait. Idle and blocked travel do not advance walking distance. Pause's zero-time presentation stays frozen, and Retry resets the motion baseline.
- Slash, sweep, thrust and dodge sample their authored `windup`, `active`, `recovery` and `end` markers using the simulation's phase/progress. The authoring clips deliberately use independent one-second beats; changing a rule's preparation length does not move the body's first-contact pose into another segment.
- Guard supplies an upper-body brace while locomotion can keep moving the legs. Ordinary arm fitting uses the original bone lengths and exposes any remaining wrist/prop gap. The relaxed shield follows its hand socket; guard fits the hand to the authoritative shield grip.
- Dodge is a direction-neutral compression/quickstep, not an authored forward/backward roll. Simulation supplies its actual travel, including focused sideways/backward movement.
- The historical hit source supplies a full reaction when free and a restrained spine/head recoil over an owed action. Named rule hit-flash/stagger durations normalize the reaction; it neither cancels the action nor redirects its authoritative blade.

There are thirteen exported clips: idle, walk, jog, run, backward, left/right strafe, hit, slash, sweep, thrust, guard and dodge. Historical rifle aim/fire remain only in the preserved source; they are not presented as melee motion.

ROOT carries the right-handed conversion from the original Blender convention to game +Y up / -Z forward. Other joints retain their original bone-local axes. Hand sockets are -Z through the palm and +Y up in the neutral rest pose. Grip fitting is deliberately basic: there are no finger bones or detailed hand-contact claims.

## Rebuild and verify

Normal CI needs Python's standard library, not Blender:

```sh
python3 -I -B blender/animations/mannequin/verify.py
```

It checks the original/derivative source and generated JSON hashes, `build.py`/`export.py` hashes, hierarchy, finite normalized samples, ordered phase markers, loop boundaries, joint continuity and foot bounds at exported samples. [manifest.json](manifest.json) binds the checked inputs and output. A missing LFS payload fails the hashes instead of silently accepting a pointer.

With Blender installed, intentionally regenerate the derivative source and JSON:

```sh
blender --background --factory-startup --python-exit-code 1 --python blender/animations/mannequin/build.py
```

`build.py` overwrites the generated derivative from the immutable input. For a manual edit to `mannequin.blend`'s local Actions, export the saved file instead of rebuilding it:

```sh
blender --background --factory-startup --python-exit-code 1 --python blender/animations/mannequin/export.py
blender --background --factory-startup --python-exit-code 1 --python blender/animations/mannequin/audit.py
```

The exporter resamples the actual saved Actions with no interval longer than 1/30 second; it does not export a separate animation formula. Re-exporting the same source reproduces byte-identical JSON. Source actions, metadata and relative links remain available for inspection in Blender.

## Evidence and limitations

The portable check covers **351 exported poses**, 17 bones and 13 clips. Exported-sample joint gaps are at most approximately **0.0011 mm**, normalized quaternion and loop differences remain within the documented numeric tolerances, and the lowest exported foot corner is approximately **-0.0036 mm** from rounding.

A separate read-only **240 Hz Blender audit covers 2,713 poses**, retains the source files unchanged and finds no bone-joint gap. Bone-proxy centres match their runtime descriptors within **0.000134 mm**. Raw local-rotation interpolation can dip a foot corner by **7.079 mm** between keyed poses. The runtime derives a small vertical visual lift from the actual interpolated foot boxes before fitting the arms; it does not change the actor/collider. Native tests require that lift to remain below 15 mm and the corrected corners to stay above the flat floor. This is flat-ground presentation, not terrain adaptation or a claim of physically planted feet at every intermediate raw Blender pose.

The authored key poses reach the agreed fixed sword grip without stretching their arm bones. Actual runtime grip, moving guard, cardinal focused quicksteps, reaction layering, pause and reset have dedicated native tests; their successful execution is recorded with the complete source check rather than inferred from this authoring audit.

[preview.png](preview.png) and [the motion reel](mannequin-preview.mp4) show the actual source rig/proxies. The reel uses labelled authoring beats and a matching flat-floor review lift; it is not a Simulator recording or an exact replay of current gameplay durations. The camera, lights, floor, blade and shield in that render are review context. Parent-bone visibility, plain rigid hands and box-shaped joints remain intentionally simple. No phone controls, performance or enjoyment result is established by these Blender checks.
