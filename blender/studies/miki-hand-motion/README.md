# Miki — articulated hands in motion

**25 November 2026 — Blender review before game integration.** After accepting the [hand-rig pilot](../miki-hand-rig/README.md), the maintainer assigned exported skin-deformation verification and running, sneaking and shooting with the new rig. This study retains Miki's appearance and 47-bone skeleton, with the rifle kept separate.

## Watch in Blender

Open [miki-hand-motion-review.blend](miki-hand-motion-review.blend), keeping `character` beside it. The scene selector provides **01 Running**, **02 Sneaking**, **03 Shooting** and **04 Neutral appearance**. Play each scene's timeline. Front, Side, Back and Three quarter cameras show the complete motion; Shooting hands shows the grip in detail.

[Native movie](motion-preview.mp4) · [Running](running.png) · [Running side](running-side.png) · [Sneaking](sneaking.png) · [Sneaking side](sneaking-side.png) · [Shooting](shooting.png) · [Hands](shooting-hands.png) · [Recoil](recoil.png) · [Neutral](appearance.png)

| Character Action | Frames at 120 fps | Motion |
| --- | --- | --- |
| `miki.hand-motion.run` | 1–79 | 0.65-second loop, inward-facing palms and loose fingers |
| `miki.hand-motion.sneak` | 1–145 | 1.2-second loop with relaxed articulated hands |
| `miki.hand-motion.shoot` | 1–361 | Three seconds: low ready, raise, one shot/recoil, recover and lower |

The eight-second movie shows four Run cycles, two Sneak cycles and one Shoot cycle at 30 fps. These are actual Blender renders, without generated or retouched appearance. Cuts between takes are editorial; no gameplay transition or combined moving-fire system is demonstrated.

## Appearance, motion and equipment

The [character source](character/miki-hand-motion.blend) owns the mesh, skeleton and three editable Actions. Original mesh coordinates/topology, face/hair, UVs, packed JPEG, material, all skin weights, 47 rest joints and four garment targets remain unchanged from the accepted hand pilot. Neutral appearance is retained. Review scenes own separate mesh/Key data and rig objects; each garment driver targets its own instance.

Run and Sneak reuse the [existing fitted project body/leg motion](../miki-option-a-motion/README.md), derived from the original shared `party.run` and `party.sneak`. These are **not Quaternius motion capture**. The [downloaded comparison](../miki-quaternius-motion/README.md) remains preserved with its known deep-crouch clothing intersections. This review corrects palm orientation and finger poses; Run also fits wrist clearance and uses the original elbow as its pole reference. It does not reshape the dress to hide contact.

Shooting is a new original review Action using measured left/right palm frames. Its stock sits at 1.4 m; the rifle raises from 10 degrees low ready, recoils by 3 degrees/2 cm after frame 181, then recovers. The unchanged [precision rifle](../equipment/rifle-precision/README.md) is linked only into the shooting scene, with its own ordinary transform keys. A small original muzzle flash is a review cue, with no shot, damage, light or gameplay authority. The prop has no modelled trigger gap: index flex stays outside the solid grip. Scoped aim, trigger actuation, reload and weapon variants are not demonstrated.

## Export verification

The original hand source uses Blender's Preserve Volume skinning. Its earlier scratch test accidentally deleted the alignment parent and lost the mesh's scale. Correcting that test resolved the large coordinate discrepancy; it was not evidence of a RealityKit defect.

A separate comparison identified a real method mismatch: OpenUSD dual-quaternion skinning matches that Blender source closely, while classic linear skinning differs at mixed-weight shoulders. In the tested macOS RealityKit renderer, switching the USD declaration between those methods produces identical images. Consequently, **only this new motion derivative disables Preserve Volume**, making its Blender deformation use the same linear method as the verified export path. The accepted hand-pilot file remains unchanged. This changes the animated blending method, while preserving neutral appearance, geometry, weights and rest joints.

The isolated export helper retains the full source hierarchy, including the alignment parent. The verified exports preserve original local mesh coordinates; reconstruction applies the geometry bind transform before skinning. An optional scratch world-bake probe also exists, but is not required or used for these final exports. Neither path edits the character source or canonical exporter. [OpenUSD's binding reference](https://openusd.org/dev/api/_usd_skel__schemas.html) explains the geometry bind transform; its [skinning-method schema](https://openusd.org/release/api/class_usd_skel_binding_a_p_i.html) defines the two methods tested here.

| Native imported-buffer comparison | Poses | Maximum vertex difference |
| --- | ---: | ---: |
| Run | 5 | 6.206 micrometres |
| Sneak | 5 | 4.102 micrometres |
| Shoot | 5 | 1.270 micrometres |

Every case covers all 10,269 original vertices and 47 imported joints, including the four garment offset targets and sampled weights. Garment weights match exactly. All cases pass the declared **10-micrometre** bound; Run exceeds the retained stricter 5-micrometre diagnostic. This is a numerical reconstruction from actual RealityKit-imported position, influence, morph-offset and pose buffers, not GPU vertex readback. Separate actual `ARView.snapshot` captures show [native running](native-running.png), [sneaking](native-sneaking.png) and [shooting](native-shooting.png). Lighting differs from the Blender studio. [native-verification.json](native-verification.json) retains the source/export hashes, exact sample frames, results and limits.

## Reproduce and validate

[build-motions.py](build-motions.py) regenerates the three Actions from the accepted hand source, existing body motion and measured palm data. Pass `--character`, `--body-motion`, `--palm-frames`, `--hand-helper`, `--output` and `--report` after Blender's `--`. Use the files linked above and the [existing palm data/helper](../miki-hand-rig/README.md#reproduction-and-validation); output and report must be new scratch destinations. [motion-record.json](motion-record.json) records source hashes, parameters, clip bounds and separate rifle bookmarks.

The helper reproduces 26 evaluated skin poses exactly, restores action/slot/pose/frame/subframe/FPS context and rejects unsafe or incompatible inputs. Eight actual Blender CLI rejection cases preserve the supplied inputs and existing files. Public review transfer matches 39 skin/bone/garment poses exactly; nine neutral-after-motion checks establish isolation. Source and review have separate mesh/Key data, own-rig drivers, resolving relative libraries and clean decoded paths.

The [native verification guide](verification/README.md) gives exact commands for the isolated export, Swift 6 import/buffer dump, comparison and actual ARView snapshots. Helpers use fresh scratch outputs and reject existing destinations, symlinks and authored-source folders. Compiled tools, full vertex dumps, scratch exports and diagnostic intermediates remain outside source control. The comparison retains an explicit transform round-trip tolerance; it does not attribute the measured residual to unproven morph quantization.

Fresh motion checks cover **157 Run + 289 Sneak poses at 240 Hz**, plus **17 shooting phases**, with no tested dress/pants or glove/dress crossings. Fifteen shooting phases have no tested digit/palm/rifle triangle crossings or glove vertices inside the rifle. Loop endpoints match exactly; wrist/finger-chain gaps remain zero. Evaluated neutral world positions differ by at most 0.358 micrometres. These are bounded checks, not continuous/global collision certification. All **62 existing Blender/export tests pass**. All 240 movie frames decode successfully. [delivery.json](delivery.json) binds the final character, review and movie sizes/hashes.

## Editing and next gate

Open the character source for persistent pose edits. Each digit still has three direct FK controls in **Fingers L** and **Fingers R**, such as `index.01.L`; the original wrist and forearm controls remain. Source skin or Action changes require refreshing review copies, media and export checks.

The mesh/JPEG retain their [Tripo provenance](../miki-option-a-tripo/README.md#provenance-and-licence). Original project motion, hand fitting, helpers, shooting, review and media are [MIT](../../../LICENSE) contributions. No new generation, purchase or installation was used.

**Next gate:** visual review of these complete motions before an integration assignment. Canonical characters, shared animation, the deliberate 17-bone export contract, runtime grip fitting/masks, gameplay and TestFlight remain unchanged. No Simulator or physical-phone performance claim is made. Extreme poses, additional clips, continuous/global self-collision quality and scoped aim remain unverified.
