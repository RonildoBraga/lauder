# Preserved bridge exports

These are the bridge prototype's exported assets and content references, moved outside the active iPhone source/resource tree for the [single-hero graybox task](https://github.com/RonildoBraga/lauder/issues/236). The duel renders Swift primitives and loads no USDZ models. Moving the files preserves their bytes; no Blender source, model geometry, mesh credit or historical sound was modified.

- `BrooklynBridge.usdz` and `BrooklynBridgeLayout.swift` are the [bridge source](../levels/README.md)'s scene and generated layout. `BrooklynBridge.swift` preserves the content references used by export validation; it is not compiled into the current app.
- `models/` holds the seven preserved model exports. `RobotModelGeometry.swift` and `acknowledgements.txt` accompany the heavy walker. Its canonical [credit](../assets/spider-bot-heavy/CREDIT.txt), embedded USDZ notice and reference acknowledgement are retained under their existing licence. The project's MIT licence does not override third-party attribution.
- `sounds/` holds thirteen retired weapon/robot WAVs. The three unchanged sounds still used by the duel remain in [the active sound folder](../../apple/sources/content/sounds). Their original generator/history is available at the bridge checkpoint; the active generator makes only the current three sounds.

The retained Blender registrations now target this folder. [level-exports.json](../level-exports.json) keeps the same source/output hashes under relocated output paths, and the exporter tests still verify them. No `.blend` file was edited or re-exported for the relocation. Future authoring changes require their own assignment and export verification.

Saving a registered source refreshes its reference outputs here. **Play** builds the current duel; it does not load these references. To run the historical bridge, follow the [checkpoint instructions](../../docs/milestones/bridge-prototype.md) in a separate worktree. Do not copy these files back into the active source tree as a way to select a level.

The app's source/resource folder is synchronised by Xcode, so keeping these files there would continue to package unused assets. The active resource contract checks all USDZ/WAV paths under `apple/sources`; the separate reference/export contract prevents the preserved exporter from writing back into that tree.
