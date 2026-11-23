# spider-bot-heavy

**Status:** The maintainer accepted C's form and assigned Blender walking, turning and visual shooting studies before bridge placement. Those studies and reusable symmetric components are built and technically checked, with a rendered motion reel ready for maintainer review. A remains a possible later different-weapon variant, outside this task. Camera B remains approved.

![Actual Blender render of the C heavy walker](preview.png)

- **Source:** New geometry and rigid-part motion authored for Lauder by Codex in Blender on 23 November 2026, following the selected [C — Heavy walker](../../../art/robot/bulk-studies/c-heavy-walker.png) and its [exact prompt](../../../art/robot/bulk-studies/prompts.md). This retains the [reference chain](../../../art/robot/attribution.md) to **Low-poly Spider Bot (Rigged)** by **rznn7**, from the [creator's asset page](https://rznn7.itch.io/low-poly-spider-bot). No creator model, rig, animation or texture was downloaded or imported. No endorsement is implied.
- **Licence:** This reference-derived model, its authored motion and rendered previews are shared under [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/), with credit to rznn7 and the Lauder concept studies. Changes include new faceted geometry, a connected torso, substantial hip housings and legs, twin guns, square sensor, linked components and new walking, turning, bracing and recoil motion. This file-level notice does not replace the repository's licence for code or unrelated assets.

The earlier [spider-bot](../spider-bot/README.md) remains a rejected historical study. C is not registered as spawned, exported into the app or placed in a playable encounter. The app still has the human encounter. Runtime movement, AI, attacks and encounter rules remain separate work.

## Reusable components and symmetry

The self-contained `spider-bot-heavy` collection uses metres, stands on z = 0 at its centred origin and faces Blender −y. Its **41 mesh Objects share 17 unique Mesh datablocks**, with **2,428 evaluated triangles and five materials**. Reuse is an authoring property, not measured runtime instancing or draw calls.

All four legs use the same six shared meshes: socket armour, hip hinge, upper armour, knee hinge, lower link and foot. Editing a component's Mesh in Edit Mode updates its four instances. Moving or posing an Object affects that instance only. Neutral left/right geometry mirrors across x = 0, including material assignments. Proper rotations place each assembly; object scales stay positive and unit. Independently posed legs during a step do not alter this shared geometry.

```text
root
  front-left connector          Also front-right, rear-left, rear-right
    socket mesh                 Shared socket Mesh
    hip pivot
      hip mesh                  Shared hip Mesh
      upper pivot
        upper armour mesh       Shared upper Mesh
        knee pivot
          knee mesh             Shared knee Mesh
          lower pivot
            lower mesh          Shared lower Mesh
            ankle pivot
              foot mesh         Shared foot Mesh; stays level
  gun-left recoil               Matching gun-right recoil
    housing, top plate, barrel   Shared corresponding Mesh data
    muzzle-left                 Moves with its barrel
```

Connectors sit at `(±0.58, ±0.42, 1.28)` m. Joint pivots meet at their link endpoints; the upper/lower links measure **1.01 / 0.57 m**. Opening the knees slightly gives the accepted shape room to step: neutral vertex bounds are about **3.00 × 2.53 × 2.35 m**, versus the static study's 2.83 × 2.51 × 2.35 m. Intake's conservative transformed-box bounds are slightly larger. These are provisional authoring dimensions, not approved collision or clearance measurements.

To attach another assembly, select its connector and descendants, duplicate with linked data and place the new connector. Preserve the hierarchy, joint-local origins and unit scales. Make mesh data single-user only for a deliberate new component. Paired roof ridges, antennae, mounts and gun parts also share data. Each gun's separate recoil root carries its housing, plate, barrel and muzzle marker together, providing an attachment point for later variants without building those variants now.

There are no textures, lights, cameras, armatures, constraints, shape keys or runtime solvers in the source. Its five matte Principled materials retain the robot palette: armour `#30343E`, slate `#4B5260`, joints `#151D24`, face `#662E30`, sensor `#E9DFCA`, converted from sRGB to scene-linear, with roughness 1, metallic 0 and emission 0.

## Motion studies

The scene is **30 fps**, with a **120 Hz transform bake** and linear interpolation, saved at neutral **frame 1**. Timeline markers identify separate takes:

| Frames | Study | Review intent |
|---|---|---|
| 2–242 | Walk, 8 s | Start, advance 1.55 m one leg at a time, then settle |
| 244–484 | Turn left, 8 s | Step through 90° while stance feet keep position and yaw |
| 486–726 | Turn right, 8 s | Mirror the left turn's placement, cadence and range |
| 728–908 | Brace and fire, 6 s | Step wider, lower the body, alternate recoil, fire both, recover |

Frames 243, 485, 727 and 909 reset to neutral between independent takes. These are editorial resets, not continuous movement or seamless loops. Each take starts and stops cleanly; travel and turning end in a neutral stance at their new position or heading.

Walking uses a four-beat crawl with at least three feet supporting the body. Feet lift 12 cm, travel and plant before taking load. During turns each stance foot keeps its world-space position and yaw until its next step. A two-link solve was used during authoring, then baked into ordinary object-transform keys; the hierarchy keeps joint endpoints connected and foot pivots compensate for leg pitch.

Firing plants all four feet before recoil starts. Both guns use matching stroke/recovery curves; their alternating timing is an authoring candidate. No muzzle flash, projectile, aim line, damage, warning or ammunition logic is implemented. This is visual shooting, not approved combat balance.

## Review and validation

The [30-second motion reel](motion-preview.mp4) presents separate labelled shots: walk at 0–8 s, turn left at 8–16 s, turn right at 16–24 s, brace/fire/recover at 24–30 s. It is H.264, 960 × 720, 24 fps, with 720 decoded frames. Recoil is restrained; judge its strength in playback before adding gameplay cues. [Beside Miki](scale-preview.png) shows current provisional size; the [camera B study](camera-b-preview.png) uses the approved offset `[0, 56, 44]` and 22° lens. These are Blender renders, not game screenshots.

They use the bridge's two suns and an authoring exposure of +0.7. Ground, Miki, lights and cameras exist only in unsaved render copies. Public PNG metadata is removed without changing pixels. The Blender source and movie use Git LFS; PNGs below 1 MiB use ordinary Git under the [storage policy](../../../CONTRIBUTING.md#git-lfs-and-cloning).

The standard `./scripts/check` passes contracts, 51 Blender tests, sound fingerprints, Swift formatting, the shared app build and hosted Simulator tests on this source-only pass. Final independent saved-file inspection sampled 7,204 poses at 240 Hz, including half-key subframes: stance drift stays below 0.029 mm, stance yaw drift below 0.000060°, foot tilt below 0.0053° and sole penetration below 0.012 mm. Joint gaps are zero; link-length error is below 0.00000023 m. Neutral geometry/material symmetry error is below 0.00000029 m and mirrored-turn error below 0.0000036 m. These are floating-point residuals, not visible intended sliding. Shared-data identity, positive unit scales, topology, part contact, materials, muzzle placement, intake and privacy checks pass. Sampled rendered poses were inspected; all 720 movie frames decode successfully. Prior static checks remain historical in the [prototype plan](../../../docs/prototype-plan.md#concept-c-proportion-study). The exporter still writes a selected frame and disables animation/instancing. Runtime clip delivery, hierarchy/muzzle preservation after export, integration and phone performance remain unverified.

Review this movement before assigning bridge integration. The [first-tower proposal](../../../docs/encounters/bridge-spider-bot.md) retains its separate gate for AI, attacks, damage and encounter progression.

| File | Size in bytes | Storage |
|---|---:|---|
| `spider-bot-heavy.blend` | 1,714,534 | Git LFS |
| `motion-preview.mp4` | 1,274,401 | Git LFS |
| `preview.png` | 375,158 | Ordinary Git |
| `scale-preview.png` | 436,880 | Ordinary Git |
| `camera-b-preview.png` | 91,715 | Ordinary Git |
