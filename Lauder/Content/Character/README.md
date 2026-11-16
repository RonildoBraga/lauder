# Stage 1 mannequin

An original, deliberately simple humanoid for proving the character asset pipeline. It is a stand-in, not Miki's final design.

## Provenance and licence

Created for Lauder with Codex assistance on 16 November 2026. The geometry, joint layout, colours and animation keyframes are original to this repository. No downloaded models, motion capture, textures, third-party art or legacy game assets were used. These original contributions use the repository's [MIT licence](../../../LICENSE).

The editable authoring source is [generate-character.py](../../../scripts/generate-character.py), using only Python's standard library. The `source/` directory contains reviewable USDA layers. Make persistent changes in the generator: regeneration replaces its emitted USDA and USDZ files.

Technical references describe file formats and APIs; they are not sources of copied art:

- [OpenUSD skeletal schema](https://openusd.org/release/api/_usd_skel__schema_overview.html)
- [Apple USD asset guidance](https://developer.apple.com/documentation/usd/creating-usd-files-for-apple-devices)
- [RealityKit animation libraries](https://developer.apple.com/documentation/realitykit/animationlibrarycomponent)

## Contents

| File | Purpose | Bytes |
|---|---|---:|
| `source/Character.usda` | Shared geometry, rig, bind pose, skinning and materials | 21,359 |
| `source/Idle.usda` | References the character and binds the idle clip | 11,066 |
| `source/Walk.usda` | References the same character and binds the walk clip | 7,436 |
| `Idle.usdz` | Self-contained delivery asset, containing `Idle.usdc` | 21,799 |
| `Walk.usdz` | Self-contained delivery asset, containing `Walk.usdc` | 19,075 |

USDA stays in ordinary Git; USDZ follows the repository's Git LFS rules. File sizes above describe the exports made with Apple USD Tools 0.25.11 and may change after an intentional regeneration.

## Geometry and animation contract

- Y-up, one unit equals one metre; the mannequin faces negative Z. Feet rest at Y = 0 in the bind pose. Rest height is 1.77 metres.
- Identical default prim `/Character`, skeleton `/Character/Rig` and single skinned mesh `/Character/Body` in both clips.
- 18 joints, 168 mesh vertices, 126 quads (252 triangles), five flat-colour metallic-workflow materials. Subdivision is disabled. There are no textures.
- All vertices have one normalised skeleton influence. The segmented shape uses rigid weights within a real skinned mesh; it does not simulate soft skin or animate separate box entities.
- Hierarchy: `Root/Hips/Spine/Chest/Neck/Head`, arms below `Chest`, and legs below `Hips`. Left/right arms have upper-arm, forearm and hand joints; legs have upper-leg, shin and foot joints. `Root` precedes `Hips` in the joint array.
- Both files bind one `/Character/Motion` animation to the rig. Idle lasts two seconds with 17 authored poses; walk lasts one second with nine. Both use 24 time codes per second, matching loop endpoints and a stationary root. Walk is in place; moving the character through the level is separate work.

Load both delivery assets and verify their actual imported skeletons and animation resources before reusing the walk resource on the idle entity. Do not assume that two USD animation prims in one file become two runtime clips. Apple's animation-library workflow supports separate files sharing a skeleton.

A macOS RealityKit import probe found the authored `/Character/Motion[0]` resource on the `Character` entity in each file. Its definition is `SampledAnimation<JointTransforms>`, lasting two seconds for idle and one for walk. RealityKit also exposes generated scene/subtree `AnimationGroup` resources, so the total `availableAnimations` count is not the authored clip count. Select and validate the unique authored joint clip instead of requiring one resource across the entire hierarchy. Import inspection does not prove visible playback.

## Regeneration and checks

From the repository root on macOS, with the system USD tools available:

```sh
python3 scripts/generate-character.py
```

The script loads and validates each source with `usdcat --loadOnly` and `usdchecker --strict`, then packages it with `usdzip --arkitAsset` and checks the USDZ with `usdchecker --arkit --strict`. The packaging tool flattens the shared layer into each delivery asset; its composition-arc warning is expected. Each resulting package has one USDC entry and no external dependencies.

Initial checks passed for both sources and exports. An independent check of the exported data also confirmed the bind/rest hierarchy, joint/weight array sizes, normalised weights and quaternions, outward face winding, stationary root, matching loop endpoints and sampled skinned bounds within the declared extent. The hosted Swift Testing import test also passes under Xcode 27.2. The maintainer confirmed visible idle/walk switching on the baseline iPhone; see the [session evidence](../../../docs/stage-1.md).

## Approved code-first path

The preview bundles the validated USDZ files directly. Its gray floor, landmark and camera are composed in Swift. All editable inputs needed to reproduce those runtime assets are in this directory and the generator; no Composer project is required to build this preview.

This follows the [approved code-first direction](https://github.com/RonildoBraga/lauder/issues/9#issuecomment-6907080643) and [engine decision](../../../docs/decisions/0001-engine.md). Reality Composer Pro is optional and deferred, so its authoring workflow is not a build dependency or Stage 1 exit requirement.

### Historical Composer investigation

Reality Composer Pro 3.1 successfully imported both USDZ files, and the character was placed in an editor scene. A test `.reality` export preserved the 18-joint rig, skin and materials but exposed no playable animations in a RealityKit probe. That specific model export is not used by the app; the result does not establish that Composer cannot export animations. A complete Composer animation-library workflow is deferred and would need verification if adopted later.

The exploratory `.realitycomposerpro` package and static export are retained locally under the ignored `.local/authoring/Content/` directory. Its generated Apple factory `core.lib` is not published or relicensed as original MIT material. This is a local investigation, not a portable Composer workflow claim.
