# spider-bot-heavy

**Status:** Concept C selected and built as a Blender proportion study, awaiting maintainer visual review. The maintainer retained A as a possible later variant with different guns; that variant is not assigned. Camera B remains approved.

![Actual Blender render of the C heavy-walker form study](preview.png)

- **Source:** New geometry authored for Lauder by Codex in Blender on 23 November 2026, following the selected [C — Heavy walker](../../../art/robot/bulk-studies/c-heavy-walker.png) and its [exact prompt](../../../art/robot/bulk-studies/prompts.md). This retains the [reference chain](../../../art/robot/attribution.md) to **Low-poly Spider Bot (Rigged)** by **rznn7**, from the [creator's asset page](https://rznn7.itch.io/low-poly-spider-bot). No creator model, rig or texture was downloaded or imported. No endorsement is implied.
- **Licence:** This reference-derived model and its rendered previews are shared under [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/), with credit to rznn7 and the Lauder concept studies. Changes include new faceted geometry, a larger connected torso, substantial hip housings and legs, compact twin guns and a square sensor. This file-level notice does not replace the repository's licence for code or unrelated assets.

The earlier [spider-bot](../spider-bot/README.md) is retained as a rejected proportion study. This new source is a static form review before animation or runtime work. It is not registered as spawned, exported into the app or placed in a playable encounter. The current app still uses the human encounter; combat rules remain proposed.

## Shape and source structure

The `spider-bot-heavy` collection uses metres, stands on z = 0 at its centred origin and faces Blender −y. A root Empty holds a connected faceted torso and pelvis, four thick upper-leg assemblies, stout lower links and flat feet. Two side gun housings each have one recessed barrel and a muzzle marker at its tip. The front has a burgundy mask and pale square sensor; two short antennae sit on the roof.

The source has **2,428 triangles, 41 separate mesh parts and five materials**, with no textures, lights, cameras, armatures, constraints, shape keys or animation. These are authoring counts, not measured runtime draw calls. The saved timeline contains only the neutral frame 1. Separate parts allow a later motion pass; this model includes no walking or firing animation.

Exact vertex bounds measure **2.83 m across × 2.51 m long × 2.35 m high**, including antennae. The main torso reaches 2.00 m. This is a provisional modelling scale for review beside Miki, not an agreed enemy size or collision footprint. The concept image's human inset was illustrative and is not a metric source. Gameplay placement and passage clearance still need validation before integration.

Five matte Principled materials use the earlier robot palette, with sRGB values converted to scene-linear: armour `#30343E`, slate `#4B5260`, joints `#151D24`, face `#662E30` and sensor `#E9DFCA`. Roughness is 1, metallic and emission are 0. This does not recolour party or bridge assets.

## Rendered review

[Beside Miki](scale-preview.png) shows the actual model and existing Miki stand-in at their authored sizes. The [camera B scale study](camera-b-preview.png) uses the approved offset `[0, 56, 44]` in game coordinates and 22° vertical lens. Both are Blender review renders on a snow plane, not game screenshots or runtime integration.

The previews use the bridge's two suns and an authoring exposure of +0.7. Ground, Miki, lights and cameras were added only in an unsaved review copy and are absent from the model source. PNG metadata was removed without changing rendered pixels, keeping local source paths out of public files.

| File | Dimensions | Size in bytes | Storage |
|---|---|---:|---|
| `spider-bot-heavy.blend` | 2.83 × 2.51 × 2.35 m | 110,451 | Git LFS |
| `preview.png` | 1600 × 1100 | 370,175 | Ordinary Git |
| `scale-preview.png` | 1800 × 1100 | 433,672 | Ordinary Git |
| `camera-b-preview.png` | 2622 × 1206 | 89,376 | Ordinary Git |

Standalone intake reports zero problems. Final independent saved-file inspection verifies closed manifold solids with positive volume, no degenerate faces, connected parts, four flat feet on the ground, bilateral symmetry and muzzle markers exactly at barrel tips. The decompressed source and public PNGs contain no private-path markers. The rejected model, live Blender session, bridge source and runtime exports remain unchanged. The standard `./scripts/check` passed the application build and Simulator tests during this authoring pass. These technical results do not replace maintainer visual approval, runtime compatibility checks or phone performance evidence.

Review the torso-to-leg balance and size before animation. The [first-tower encounter proposal](../../../docs/encounters/bridge-spider-bot.md) remains a separate design gate; no new weapon type, AI, shots, damage or encounter handoff is implemented here.
