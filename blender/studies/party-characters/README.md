# Party character and animation study

**Status:** Blender asset review, 23 November 2026. The maintainer assigned playable-character models and animations and selected **more stylised proportions with larger heads**. These are original candidates for Miki, Laura and Tom. Clothing, faces and motion remain proposals for visual review; the game's canonical party sources and runtime avatars are unchanged.

![Actual Blender render of Miki, Laura and Tom](lineup.png)

Open [character-study.blend](character-study.blend) and play the timeline, or watch the [motion reel](motion-preview.mp4). The file opens in its camera view at frame 1. Timeline markers identify each take. The nine named source Actions remain editable independently of the repeated review timeline.

- **Source:** Original geometry, skin weights, shared humanoid skeleton and motion authored for Lauder by Codex in Blender 5.3. No third-party character, rig, animation, model or texture was imported. These previews are renders of the actual meshes, not generated concept images.
- **Licence:** The repository's [MIT licence](../../../LICENSE). The linked bridge lighting is also original Lauder material under MIT.
- **Context:** The [story bible](../../../docs/story/story-bible.md) supplies the three travellers and proposed roles; the [visual direction](../../../docs/visual-direction.md) supplies the frozen low-poly setting and colours. The designs add no confirmed biography, enhancement history, relationship or uniform affiliation.

## Silhouettes and shared construction

| Character | Working appearance | Vertices | Triangles |
|---|---|---:|---:|
| Miki | Teal work parka, cream collar, square tool pouch | 187 | 348 |
| Laura | Short orange jacket and cap, compact backpack | 187 | 348 |
| Tom | Broader blue coat, larger sleeves and boots | 179 | 336 |

All three use the same 17-bone rest skeleton, rest height **1.74 m**, metre units, Blender Z up and front towards −Y. Their exterior remains human, without exposed mechanical enhancements. Larger heads, simplified faces and coat shapes are intended to read from the high camera; gameplay-camera readability still needs integration testing.

There is one skinned Mesh Object per character. The torso, shoulders, arms, head, legs and boots form a continuous body core, with small attached eyes, nose and equipment. Flat faces and five material slots per mesh use seven shared family materials overall: three coat accents plus ink, stone skin, weathered-stone trousers and cream. All are matte Principled materials with no textures or emission. The per-character triangle target is met; these source counts do not establish whole-scene material/draw-call budgets or phone performance.

The three Armature Objects share **one Armature datablock** and the same source Actions. Each has its own pose, animation binding and mesh modifier target, so runtime instances can animate independently. The skeleton contains ROOT, pelvis, spine, chest, head, and paired upper arm, forearm, hand, thigh, shin and foot joints. ROOT is a nondeforming parent and must survive export. Hands and feet are simple forms; there are no finger or facial rigs, cloth simulation, shape keys or runtime IK dependencies.

`miki`, `laura` and `tom` collections hold their rigs and bodies. Separate review-placement parents space the trio apart. The **Review context - never exported** collection holds those placements, camera, floor, labels and weapon proxies; the bridge's Lights collection is linked with a relative path. This multi-character file lives under `blender/studies`, outside the canonical `blender/assets/<model>/<model>.blend` convention, and is not a spawned model. Saving it does not replace party exports or export the review floor and cameras to the game.

## Reusable animation set

[clips.json](clips.json) records the source Action names, inclusive review ranges at **120 fps**, cycle durations, repetitions and nominal speeds in metres/second. Source Actions are named `party.<clip>` and kept with fake users so they survive saving even while the rigs select the combined timeline.

| Source clip | One cycle | Review frames | Intent |
|---|---:|---|---|
| idle | 2.0 s | 1–241 | Grounded breathing and slight weight shift |
| walk | 0.8 s | 242–626 | Alternating planted feet and relaxed arms; four cycles |
| jog | 0.6 s | 627–915 | Deeper leg bend and stronger arm swing; four cycles |
| backward | 0.6 s | 916–1132 | Facing forward while stepping back; three cycles |
| strafe_left | 0.5 s | 1133–1313 | Sideways travel with separated foot lanes; three cycles |
| strafe_right | 0.5 s | 1314–1494 | Matching opposite direction; three cycles |
| aim | 1.5 s | 1495–1675 | Two-hand ready pose and restrained breathing |
| fire | 0.6 s | 1676–1964 | Recoil and recovery; four separate demonstrations |
| hit | 0.6 s | 1965–2109 | Small impact reaction and recovery; two demonstrations |

The source locomotion is **in place**, with no horizontal entity-root travel. Feet are authored to cancel virtual travel during stance; nominal speeds are approximately **1.013 m/s** walk, **2.133 m/s** jog/backward and **2.0 m/s** strafe. Runtime playback must later follow actual local movement speed rather than stretching the body or changing gameplay movement. Tom uses the same ordinary travel speed as the others.

Source transforms are baked at 120 Hz with additional exact contact-event keys, linear interpolation and continuous quaternion signs. Two-link arm/leg solutions are baked into ordinary joint keys; no solver needs to run in the game. Bone ROOT supplies vertical body compression but no horizontal root motion. This is an animation study, not an implementation of movement, damage or timing authority.

The roughly **17.6-second reel** samples the full source timeline at 30 fps in real time. Takes have explicit cuts; fire and hit are replayed for review and are not runtime loops. Abrupt boundaries do not demonstrate animation blending. The figures stay in place so poses can be compared.

![Aiming poses with simple review weapon proxies](aim.png)

The dark weapon boxes are unexported review proxies sized from the current native weapon presentation. They allow hand-contact review without adding new weapon art. Firing includes a small proxy kick, but the final runtime hands, upper-body layers and authoritative weapon/muzzle transforms still need to be bound together. No new weapon, ammunition or damage rules are introduced.

## Verification and export findings

The final source motion was sampled at **240 Hz** for all three characters: zero joint gaps, maximum ankle interpolation error **0.624 mm**, sole penetration at most **0.250 mm** and foot-up error below **0.012°**. Every vertex is weighted and weights normalize within floating-point tolerance. Saved-file inspection checks shared data, retained Actions, frame ranges, relative lighting links and public-path hygiene.

A separate scratch export of the same three meshes and nine one-cycle motions passed a **native macOS RealityKit** proof: **3,267 poses**, 1,089 per character. This checked actual joint evaluation and reconstructed skinned vertices, not just animation enumeration. All 17 joints survive, all nine clips trim to their intended duration, entity roots stay fixed and cloned figures have independent animation state while sharing immutable mesh resources. Maximum loop seam is **0.033 mm**; lowest sole is **−0.250 mm**. This is an import/deformation proof, not a rendered Simulator run, physical-phone test or performance measurement. The one-cycle export timeline is separate from this longer repeated review timeline.

The current registered party exporter remains static. Future integration needs a focused animated-party path, leaving the bridge and rigid robot paths intact. The scratch proof established these Blender USD options:

```python
dict(export_animation=True, export_armatures=True, only_deform_bones=False,
     export_materials=True, generate_preview_surface=True,
     generate_materialx_network=False, export_lights=False, export_cameras=False,
     export_custom_properties=False, author_blender_name=False,
     merge_parent_xform=False, convert_orientation=True,
     export_global_forward_selection='NEGATIVE_Z',
     export_global_up_selection='Y', evaluation_mode='RENDER',
     use_instancing=False)
```

Blender exports the active scene timeline, not the nine Actions as separate named resources. Select the imported `SampledAnimation<JointTransforms>` on the skinned model and trim it with RealityKit `AnimationView`; avoid duplicate ancestor animation groups. Trim seconds are `(frame - 1) / fps`. USD sanitizes `.L` and `.R` joint suffixes as `_L` and `_R`; bindings should use verified imported paths.

**Preserve the final sample:** Blender 5.3's sparse USD output can omit a held final rotation/translation sample. In the proof, this shortened the imported resource and broke the last hit recovery. Author an identical held sample at the intended final time on the animated `UsdSkel.Animation` attributes before packaging USDZ. Verify imported duration covers every clip. Padding preserved the intended pose and timing and restored the full **7.766667-second** one-cycle resource. Unpadded scratch exports are not delivery assets. Runtime joint evaluation in the proof used an entity attached to `RealityRenderer` and explicit updates; a detached playback controller alone did not establish animation delivery.

## Review and next integration gate

Review the larger-head proportions, silhouette differences, arm swing and recoil in Blender first. The playable characters still use their existing canonical files; no Swift, registered exporter, bridge layout or runtime asset changed in this pass.

After visual review, a focused integration can promote each accepted character to its canonical source, add animated-party export and clip metadata, and drive presentation from existing authoritative movement/combat state. It must handle actual-speed playback, directional motion, upper-body aim/fire, weapon contact, pause/restart and independent party instances. Validate feet, navigation clearance, camera readability, whole-scene budgets and rendered Simulator routes before the next agreed phone checkpoint. Simulation retains command, movement, shot-origin and damage authority; animation does not introduce gameplay root motion or event timing.

## Files and storage

- `character-study.blend`: editable source and review scene, about 3.0 MiB, Git LFS.
- `clips.json`: review metadata, ordinary Git text.
- `lineup.png` and `aim.png`: actual Blender renders, about 1.35 MiB each, explicit-path Git LFS. Text metadata is removed without changing pixels.
- `motion-preview.mp4`: deliberate H.264 review reel, explicit-path Git LFS, outside app resources.

Build products, scratch USDZs, native proof executables and private audit logs remain outside Git.
