# tom

The accepted original low-poly Tom model: broader blue coat, sleeves and boots, larger-head proportions and a human exterior. The game loads `apple/sources/content/models/tom.usdz`; saving this canonical source triggers the existing model export workflow ([ADR 0002](../../../docs/decisions/0002-blender-source-of-truth.md)).

- **Source:** Original geometry, manual skin weights and motion authored for Lauder by Codex in Blender 5.3, promoted on 24 November 2026 from the accepted [party study](../../studies/party-characters/README.md). The later run and sneak Actions were authored for the assigned locomotion extension on the same date. No third-party model, texture, rig or animation was imported.
- **Licence:** The repository's [MIT licence](../../../LICENSE).
- **Size:** Rest height 1.74 m, metres, Z up, front −Y; 179 source vertices and 336 triangles; one skinned mesh, five matte material slots, no textures or emission. Source and USDZ are Git LFS assets.

The exact `tom` collection contains its local rig Object and body mesh. Its 17-bone Armature and eleven source Actions link relatively from [the shared party animation library](../../animations/README.md). Every model has independent pose state; skeleton and motion edits happen in that one library, while appearance edits remain in this model. The original study remains a separate review scene.

Export reconstructs a one-cycle timeline from the saved shared Actions and preserves a held final USD skeletal sample. Miki's export also generates the single `PartyModelClips.swift` table; the export ledger fingerprints each model, the shared library and the generator. Use `blender/scripts/export-model.py -- tom` in a background Blender after editing. Do not edit USDZs or Swift timings by hand. Source animation is in place; gameplay remains authoritative for movement, shots and damage. The static hostile and articulated robot use their existing separate paths.
