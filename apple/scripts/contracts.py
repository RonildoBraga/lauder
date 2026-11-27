#!/usr/bin/env python3
"""Check the small declarations shared by Swift, Python and the asset exporter.

This reads source declarations only; it does not import app code, execute scripts or need
Blender/Xcode. Asset payloads and export fingerprints have their own existing checks.
"""

import ast
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]


def assignment(root, path, name):
    """A named top-level Python assignment, without executing its module."""
    declarations = []
    for node in ast.parse((root / path).read_text(), filename=path).body:
        if isinstance(node, ast.Assign) and any(
                isinstance(target, ast.Name) and target.id == name for target in node.targets):
            declarations.append(node.value)
    if len(declarations) != 1:
        raise ValueError(f"{path}: expected one {name} declaration; update its contract reader.")
    return declarations[0]


def literal(root, path, name):
    return ast.literal_eval(assignment(root, path, name))


def swift_cases(root, path, name):
    """Raw strings of the top-level cases in a toolchain-formatted enum."""
    source = (root / path).read_text()
    match = re.search(rf"^enum {name}\b[^{{]*\{{(.*?)^\}}", source, re.DOTALL | re.MULTILINE)
    if not match:
        raise ValueError(f"{path}: expected enum {name}; update its contract reader.")
    values = []
    for line in re.findall(r"^  case ([^\n]+)", match[1], re.MULTILINE):
        for item in line.split(","):
            case = re.fullmatch(r'\s*(\w+)(?:\s*=\s*"([^"]+)")?\s*', item)
            if not case:
                raise ValueError(f"{path}: unsupported {name} case; update its contract reader.")
            values.append(case[2] or case[1])
    if not values:
        raise ValueError(f"{path}: no {name} cases found; update its contract reader.")
    return values


def swift_scenarios(root):
    path = "apple/sources/world/Playtest.swift"
    source = (root / path).read_text()
    match = re.search(r"static let scenarios:[^=]+?=\s*\[(.*?)\n\s*\]", source, re.DOTALL)
    entries = re.sub(r"//[^\n]*", "", match[1]) if match else ""
    pattern = r'\(\s*"([^"]+)"\s*,\s*\w+\s*\)'
    names = re.findall(pattern, entries)
    remaining = re.sub(pattern, "", entries).strip(" \n\t,")
    if not names or remaining:
        raise ValueError(f"{path}: expected named scenarios; update its contract reader.")
    return names


def problems(root=ROOT):
    failures = []

    def same(label, actual, expected, ordered=False):
        if len(actual) != len(set(actual)):
            failures.append(f"{label}: duplicate entries.")
        different = list(actual) != list(expected) if ordered else set(actual) != set(expected)
        if different:
            found, wanted = (list(actual), list(expected)) if ordered else (sorted(actual), sorted(expected))
            failures.append(f"{label}: found {found}; expected {wanted}.")

    python_scenarios = literal(root, "apple/scripts/playtest", "SCENARIOS")
    same("Python playtest scenarios/order versus Swift", python_scenarios, swift_scenarios(root),
         ordered=True)

    content = root / "apple/sources/content"
    packaged = [str(path.relative_to(root)) for path in content.rglob("*")
                if path.is_file() and path.suffix in (".usdz", ".wav")]
    same("Preflight assets versus packaged resources",
         literal(root, "apple/scripts/preflight.py", "ASSETS"), packaged)

    wavs = [path.stem for path in (content / "sounds").glob("*.wav")]
    same("CombatSound raw names versus WAV resources",
         swift_cases(root, "apple/sources/interface/CombatFeedback.swift", "CombatSound"), wavs)
    sounds = assignment(root, "apple/scripts/make-sounds.py", "SOUNDS")
    if not isinstance(sounds, ast.Dict):
        raise ValueError("make-sounds.py: expected the SOUNDS dictionary; update its contract reader.")
    same("Generated sounds versus WAV resources", [ast.literal_eval(key) for key in sounds.keys],
         wavs)

    common = "blender/extensions/lauder_levels/common.py"
    spawned = literal(root, common, "SPAWNED")
    models = [path.stem for path in (content / "models").glob("*.usdz")]
    same("Blender SPAWNED models versus model resources", spawned, models)
    figures = re.findall(r'\bfigure\("([^"]+)"\)',
                         (root / "apple/sources/world/SceneStyle.swift").read_text())
    party = swift_cases(root, "apple/sources/gameplay/PartyMember.swift", "PartyMember")
    same("Game figure names versus exported models", set(party + figures), models)

    levels = assignment(root, common, "LEVELS")
    if not isinstance(levels, ast.Dict):
        raise ValueError(f"{common}: expected LEVELS dictionary; update its contract reader.")
    level_keys = [ast.literal_eval(key) for key in levels.keys]
    level_outputs = []
    for level in levels.values:
        if not isinstance(level, ast.Call):
            raise ValueError(f"{common}: expected LevelFile entries; update its contract reader.")
        outputs = {kw.arg: ast.literal_eval(kw.value) for kw in level.keywords
                   if kw.arg in ("scene", "layout")}
        if set(outputs) != {"scene", "layout"}:
            raise ValueError(f"{common}: each LevelFile needs scene and layout output paths.")
        level_outputs.extend(outputs.values())
    model_folder = literal(root, common, "SPAWNED_SCENES")
    metadata = literal(root, common, "MODEL_METADATA")
    acknowledgements = literal(root, common, "MODEL_ACKNOWLEDGEMENTS")
    exports = (level_outputs + [f"{model_folder}/{name}.usdz" for name in spawned]
               + list(metadata.values()) + list(acknowledgements.values()))
    records = json.loads((root / "blender/level-exports.json").read_text())
    same("Export manifest record names", list(records), level_keys + [f"models/{n}" for n in spawned])
    recorded = [path for record in records.values() for path in record.get("wrote", {})]
    same("Export manifest output paths", recorded, exports)
    same("Blender USDZ outputs versus packaged resources",
         [path for path in exports if path.endswith(".usdz")],
         [path for path in packaged if path.endswith(".usdz")])
    return failures


def main():
    try:
        failures = problems()
    except (OSError, ValueError, SyntaxError, TypeError) as error:
        print(f"Source contract check could not read a declaration: {error}", file=sys.stderr)
        return 1
    if failures:
        print("Source contracts drifted; update the related declarations together:", file=sys.stderr)
        print("\n".join(f"- {failure}" for failure in failures), file=sys.stderr)
        return 1
    print("Playtest, runtime asset, sound and Blender export declarations agree.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
