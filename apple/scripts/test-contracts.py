#!/usr/bin/env python3
"""Mutation checks for declarations that several project tools consume."""

from pathlib import Path
import json
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.dont_write_bytecode = True

import contracts  # noqa: E402


class ContractTests(unittest.TestCase):
    def setUp(self):
        folder = tempfile.TemporaryDirectory(prefix="lauder-contracts-")
        self.addCleanup(folder.cleanup)
        self.root = Path(folder.name)
        for name in (
            "apple/scripts/playtest", "apple/scripts/preflight.py", "apple/scripts/make-sounds.py",
            "apple/sources/world/Playtest.swift", "apple/sources/world/DuelStage.swift",
            "blender/extensions/lauder_levels/common.py", "blender/level-exports.json",
        ):
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(contracts.ROOT / name, target)
        for folder in ("apple/sources", "blender/reference-exports"):
            for source in (contracts.ROOT / folder).rglob("*"):
                if source.is_file() and source.suffix in (".usdz", ".wav"):
                    target = self.root / source.relative_to(contracts.ROOT)
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.touch()  # These tests check declarations; preflight checks payloads.

    def change(self, path, before, after):
        file = self.root / path
        source = file.read_text()
        self.assertIn(before, source)
        file.write_text(source.replace(before, after, 1))

    def refuses(self, message):
        self.assertTrue(any(message in problem for problem in contracts.problems(self.root)))

    def test_current_project_contracts_agree(self):
        self.assertEqual(contracts.problems(contracts.ROOT), [])

    def test_renamed_and_reordered_script_scenarios_are_rejected(self):
        self.change("apple/scripts/playtest", '"duel-attack", "duel-defence"',
                    '"duel-defence", "duel-attack"')
        self.refuses("Python playtest scenarios/order")
        self.change("apple/scripts/playtest", '"duel-recovery"', '"unknown-recovery"')
        self.refuses("Python playtest scenarios/order")

    def test_missing_preflight_registration_is_rejected(self):
        self.change("apple/scripts/preflight.py", "sounds/sword-swing.wav", "sounds/missing.wav")
        self.refuses("Preflight assets")

    def test_unregistered_packaged_resource_is_rejected(self):
        (self.root / "apple/sources/content/sounds/unregistered.wav").touch()
        self.refuses("Preflight assets")
        self.refuses("CombatSound raw names")
        self.refuses("Generated sounds")

    def test_swift_sound_raw_name_must_match_its_file(self):
        self.change("apple/sources/world/DuelStage.swift", 'case strikeBody = "strike-body"',
                    'case strikeBody = "different-body"')
        self.refuses("CombatSound raw names")

    def test_missing_model_export_registration_is_rejected(self):
        self.change("blender/extensions/lauder_levels/common.py",
                    'SPAWNED = ("crawler", "hostile", "laura", "miki", "scout-drone", "spider-bot-heavy", "tom")',
                    'SPAWNED = ("hostile", "laura", "miki")')
        self.refuses("Blender SPAWNED models")
        self.refuses("Export manifest record names")

    def test_reference_exports_cannot_write_back_into_the_active_app(self):
        self.change("blender/extensions/lauder_levels/common.py",
                    'SPAWNED_SCENES = "blender/reference-exports/models"',
                    'SPAWNED_SCENES = "apple/sources/content/models"')
        self.refuses("Preserved Blender exports")

    def test_reference_export_path_traversal_is_rejected(self):
        self.change("blender/extensions/lauder_levels/common.py",
                    'SPAWNED_SCENES = "blender/reference-exports/models"',
                    'SPAWNED_SCENES = "blender/reference-exports/../../apple/sources/content/models"')
        self.refuses("Preserved Blender exports")

    def test_unregistered_runtime_model_outside_content_is_rejected(self):
        (self.root / "apple/sources/world/retired.usdz").touch()
        self.refuses("Preflight assets")

    def test_missing_reference_model_is_rejected(self):
        (self.root / "blender/reference-exports/models/miki.usdz").unlink()
        self.refuses("Blender SPAWNED models")
        self.refuses("Blender USDZ outputs")

    def test_export_manifest_output_paths_must_match_the_exporter(self):
        self.change("blender/level-exports.json", "models/miki.usdz", "models/old-miki.usdz")
        self.refuses("Export manifest output paths")

    def test_model_acknowledgement_declaration_must_match_the_export_manifest(self):
        self.change("blender/extensions/lauder_levels/common.py",
                    "blender/reference-exports/acknowledgements.txt",
                    "blender/reference-exports/other-acknowledgements.txt")
        self.refuses("Export manifest output paths")

    def test_model_acknowledgement_cannot_be_omitted_from_the_export_manifest(self):
        path = self.root / "blender/level-exports.json"
        records = json.loads(path.read_text())
        acknowledgements = contracts.literal(
            self.root, "blender/extensions/lauder_levels/common.py", "MODEL_ACKNOWLEDGEMENTS")
        del records["models/spider-bot-heavy"]["wrote"][acknowledgements["spider-bot-heavy"]]
        path.write_text(json.dumps(records))
        self.refuses("Export manifest output paths")

    def test_changed_swift_declaration_shape_fails_closed(self):
        self.change("apple/sources/world/Playtest.swift", "static let scenarios:",
                    "static let renamedScenarios:")
        with self.assertRaisesRegex(ValueError, "expected named scenarios"):
            contracts.problems(self.root)

    def test_unread_scenario_expression_fails_closed(self):
        self.change("apple/sources/world/Playtest.swift", '("duel-defence", defence)',
                    '("duel-defence", Routes.defence)')
        with self.assertRaisesRegex(ValueError, "expected named scenarios"):
            contracts.problems(self.root)

    def test_extra_swift_sound_case_cannot_escape_resource_validation(self):
        self.change("apple/sources/world/DuelStage.swift", 'case strikeBody = "strike-body"',
                    'case strikeBody = "strike-body"\n  case extraSound')
        self.refuses("CombatSound raw names")

    def test_duplicate_python_registry_definition_fails_closed(self):
        path = self.root / "apple/scripts/playtest"
        path.write_text(path.read_text() + '\nSCENARIOS = ["new-route"]\n')
        with self.assertRaisesRegex(ValueError, "expected one SCENARIOS declaration"):
            contracts.problems(self.root)

    def test_python_declarations_are_read_without_executing_modules(self):
        path = self.root / "apple/scripts/playtest"
        path.write_text('raise RuntimeError("do not execute")\n' + path.read_text())
        self.assertEqual(contracts.problems(self.root), [])


if __name__ == "__main__":
    unittest.main()
