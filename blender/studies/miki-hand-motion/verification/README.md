# Isolated native skin verification

Run from the repository root. These are study-only helpers; they do not save Blender source files, update the game exporter or integrate an asset into the game. Existing output destinations and aliases are rejected. Use a new scratch directory for each rerun.

The installed Blender must provide `pxr` and NumPy. Native helpers require a macOS RealityKit SDK, Swift 6 and an interactive macOS desktop for ARView snapshots. No additional dependency installation is required on the verified machine.

```sh
mkdir -p .local/miki-native-verification
xcrun swiftc -parse-as-library -swift-version 6 blender/studies/miki-hand-motion/verification/DumpNative.swift -o .local/miki-native-verification/native-dump
xcrun swiftc -parse-as-library -swift-version 6 blender/studies/miki-hand-motion/verification/RenderNative.swift -o .local/miki-native-verification/native-render
```

Replace `blender` with the installed Blender executable if it is not on PATH:

```sh
blender -b --factory-startup --python-exit-code 1 --python blender/studies/miki-hand-motion/verification/export-skin.py -- --source blender/studies/miki-hand-motion/character/miki-hand-motion.blend --output .local/miki-native-verification/run --action miki.hand-motion.run --frames 1,25,49,73,79 --materials
.local/miki-native-verification/native-dump .local/miki-native-verification/run/character.usdz .local/miki-native-verification/run/reference.json .local/miki-native-verification/run/native.json
blender -b --factory-startup --python-exit-code 1 --python blender/studies/miki-hand-motion/verification/compare-skin.py -- .local/miki-native-verification/run
.local/miki-native-verification/native-render .local/miki-native-verification/run/character.usdz .local/miki-native-verification/run/render .local/miki-native-verification/run/reference.json
```

Repeat using these arguments and distinct new folders:

| Action | Frames | Output folder |
| --- | --- | --- |
| `miki.hand-motion.sneak` | `1,37,73,109,145` | `.local/miki-native-verification/sneak` |
| `miki.hand-motion.shoot` | `1,121,186,241,361` | `.local/miki-native-verification/shoot` |

For the shooting image, first export the separate rifle into the sibling `rifle` folder, and add `--rifle-report blender/studies/miki-hand-motion/motion-record.json` to the character export. The record contains the selected prop world matrices, including all five tested shooting frames. The character asset itself remains weapon-free.

```sh
blender -b --factory-startup --python-exit-code 1 --python blender/studies/miki-hand-motion/verification/export-rifle.py -- --source blender/studies/equipment/rifle-precision/rifle-precision.blend --output .local/miki-native-verification/rifle
```

Optional bounded digit isolation: export the unchanged approved hand source `blender/studies/miki-hand-rig/character/miki-hand-rig.blend` with `--action miki.hands.controls --frames 1,61,181 --materials` into a fresh folder. The original Preserve Volume binding differs from native classicLinear at mixed-weight shoulders. Its whole-body comparison intentionally fails the 10µm threshold; the distal left-index cohort demonstrates 42.176 mm deformation with the other nine cohorts restored at the two endpoint samples. Do not represent this DQS source as an exact full-body native export.

Numeric comparison reconstructs imported native buffer deformation against Blender world references, including geomBindTransform and four corrective morphs. It is distinct from the independent ARView GPU-render snapshots. The comparison explicitly records 10µm tolerance, the stricter 5µm diagnostic, full original vertex coverage, imported joint/morph state and independent clone/reset checks. The verified Run maximum 6.206µm passes 10µm and fails 5µm. No iPhone/runtime integration, animation performance or all-time GPU vertex-capture claim is made.
