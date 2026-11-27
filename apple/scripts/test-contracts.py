#!/usr/bin/env python3
"""Mutation checks for declarations that several project tools consume."""

from pathlib import Path
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
            "apple/sources/world/Playtest.swift", "apple/sources/interface/CombatFeedback.swift",
            "apple/sources/world/SceneStyle.swift", "apple/sources/gameplay/PartyMember.swift",
            "blender/extensions/lauder_levels/common.py", "blender/level-exports.json",
        ):
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(contracts.ROOT / name, target)
        for source in (contracts.ROOT / "apple/sources/content").rglob("*"):
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
        self.change("apple/scripts/playtest", '"bridge-walk", "first-fight"',
                    '"first-fight", "bridge-walk"')
        self.refuses("Python playtest scenarios/order")
        self.change("apple/scripts/playtest", '"orders",', '"new-orders",')
        self.refuses("Python playtest scenarios/order")

    def test_missing_preflight_registration_is_rejected(self):
        self.change("apple/scripts/preflight.py", "models/miki.usdz", "models/missing.usdz")
        self.refuses("Preflight assets")

    def test_unregistered_packaged_resource_is_rejected(self):
        (self.root / "apple/sources/content/sounds/unregistered.wav").touch()
        self.refuses("Preflight assets")
        self.refuses("CombatSound raw names")
        self.refuses("Generated sounds")

    def test_swift_sound_raw_name_must_match_its_file(self):
        self.change("apple/sources/interface/CombatFeedback.swift", 'case rifle\n',
                    'case rifle = "different-rifle"\n')
        self.refuses("CombatSound raw names")

    def test_missing_model_export_registration_is_rejected(self):
        self.change("blender/extensions/lauder_levels/common.py",
                    'SPAWNED = ("crawler", "hostile", "laura", "miki", "scout-drone", "spider-bot-heavy", "tom")',
                    'SPAWNED = ("hostile", "laura", "miki")')
        self.refuses("Blender SPAWNED models")
        self.refuses("Export manifest record names")

    def test_swift_figure_reference_must_have_an_exported_model(self):
        self.change("apple/sources/world/SceneStyle.swift", 'figure("hostile")',
                    'figure("unknown-hostile")')
        self.refuses("Game figure names")

    def test_export_manifest_output_paths_must_match_the_exporter(self):
        self.change("blender/level-exports.json", "models/miki.usdz", "models/old-miki.usdz")
        self.refuses("Export manifest output paths")

    def test_changed_swift_declaration_shape_fails_closed(self):
        self.change("apple/sources/world/Playtest.swift", "static let scenarios:",
                    "static let renamedScenarios:")
        with self.assertRaisesRegex(ValueError, "expected named scenarios"):
            contracts.problems(self.root)

    def test_unread_scenario_expression_fails_closed(self):
        self.change("apple/sources/world/Playtest.swift", '("orders", orders)',
                    '("orders", Routes.orders)')
        with self.assertRaisesRegex(ValueError, "expected named scenarios"):
            contracts.problems(self.root)

    def test_late_swift_enum_case_cannot_escape_resource_validation(self):
        self.change("apple/sources/gameplay/PartyMember.swift", '\n}', '\n  case newMember\n}')
        self.refuses("Game figure names")

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
