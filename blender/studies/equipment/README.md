# Independent equipment studies

These original static authoring assets are separate from Miki's [character source](../miki-angular/character/README.md). The [Miki review composition](../miki-angular/README.md) links them and owns their placement. They are unregistered studies, with no runtime export, equipment interface or new gameplay rule.

| Asset | Source | Native convention |
|---|---|---|
| Scout rifle | [README](rifle-scout/README.md), [Blender source](rifle-scout/rifle-scout.blend) | +Y forward, Z up |
| Precision rifle | [README](rifle-precision/README.md), [Blender source](rifle-precision/rifle-precision.blend) | +Y forward, Z up |
| Heavy rifle | [README](rifle-heavy/README.md), [Blender source](rifle-heavy/rifle-heavy.blend) | +Y forward, Z up |
| Field slate | [README](field-slate/README.md), [Blender source](field-slate/field-slate.blend) | Wide X, screen +Y, Z up |

Each file opens with directly editable geometry at its native origin and uses metres. Each owns its mesh data, materials and local contact/reference markers, with no character, bridge or review-file dependency. Save the relevant asset, then reopen the review composition to reload its linked data. Edit geometry in its source file; edit carry/hold placement in the review file. Do not append another maintained copy into Miki's character file.

The three rifle designs share interface conventions. Only Precision has been fitted in Miki's four static poses. Scout and Heavy remain visual alternatives; common marker positions do not prove grip, shoulder, animation or runtime compatibility. Source material datablocks are local to each asset even where palette values match. Their eventual import budget remains a separate gate.

**Source:** Original Lauder geometry authored by Codex, extracted without redesign from the Miki study at `7d0e79b`. No third-party equipment mesh or texture was imported. **Licence:** Project [MIT licence](../../../LICENSE).
