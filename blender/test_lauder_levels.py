#!/usr/bin/env python3
"""Tests for the Lauder extension (extensions/lauder_levels) that need no Blender: writing and
checking a level's layout file, the record of what each export was made from, and the order of the
work it runs in the background.

./scripts/check runs them. Blender's own part, reading the level's Blender file and exporting it,
runs in blender/scripts/export-level.py, as CONTRIBUTING describes.
"""

from dataclasses import replace
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "extensions"))
sys.dont_write_bytecode = True

import lauder_levels as L  # noqa: E402

ROOT = HERE.parent
BRIDGE = L.LEVELS["brooklyn-bridge"]

#: A small level, with a light of each kind the game has and names that the story uses.
SAMPLE = L.Layout(
    L.Box("deck", (0, -0.15, 0), (24, 0.3, 250)),
    [
        L.Box("railing-west", (-11.8, 0.55, 0), (0.4, 1.1, 250)),
        L.Box("car-a1", (9.6, 0.75, 100), (2, 1.5, 4.6)),
        L.Box("brooklyn-tower-pier", (0, 7, 20), (6, 14, 10)),
    ],
    [L.Landmark("bridge.booth", (4, 0, 110), (2, 2.4, 2))],
    [L.Area("manhattan-end", (-12, -125), (12, -110))],
    [L.Marker("spawn.miki", (6.8, 118))],
    L.Camera((0, 10, 9.9), 42),
    [
        L.Light("sun-key", (-6, 8, 0), (1, 0.91, 0.74), 4500, 25),
        L.Light("sky-fill", (0, 6, -8), (0.67, 0.81, 0.85), 600),
    ],
)


def shapes_for(layout):
    """What Export reads from a level file holding this layout, in Blender's coordinates."""
    shapes = []

    def block(name, role, centre, size):
        cx, cy, cz = L.to_blender(centre)
        sx, sy, sz = L.size_to_blender(size)
        shapes.append(L.Shape(name, role, (cx - sx / 2, cy - sy / 2, cz - sz / 2),
                              (cx + sx / 2, cy + sy / 2, cz + sz / 2)))

    block(layout.ground.name, "ground", layout.ground.position, layout.ground.size)
    for box in layout.boxes:
        block(box.name, "box", box.position, box.size)
    for landmark in layout.landmarks:
        x, y, z = landmark.position
        block(landmark.name, "landmark", (x, y + landmark.size[1] / 2, z), landmark.size)
    for area in layout.areas:
        (x0, z0), (x1, z1) = area.minimum, area.maximum
        block(area.name, "area", ((x0 + x1) / 2, 0.025, (z0 + z1) / 2), (x1 - x0, 0.05, z1 - z0))
    for marker in layout.markers:
        x, z = marker.position
        shapes.append(L.Shape(marker.name, "marker", (x, -z, 0), (x, -z, 0)))
    return shapes


def camera_for(layout):
    return L.CameraShape(L.to_blender(layout.camera.offset), layout.camera.field_of_view)


def lights_for(layout):
    return [
        L.LightShape(light.name, "SUN", L._unit(L.to_blender(light.source)), L._linear(*light.color),
                     light.intensity * L.SUN_STRENGTH_PER_LUX, light.shadow_distance is not None,
                     light.shadow_distance)
        for light in layout.lights
    ]


def read(shapes=None, camera=None, lights=None, required=()):
    """The layout Export would write from what Blender holds, starting from the sample."""
    return L.layout_from_shapes(
        shapes if shapes is not None else shapes_for(SAMPLE), BRIDGE,
        camera if camera is not None else camera_for(SAMPLE),
        lights if lights is not None else lights_for(SAMPLE), required)


def without(shapes, name):
    return [shape for shape in shapes if shape.name != name]


class LayoutTests(unittest.TestCase):
    """Writing the layout file from what the level's Blender file holds, after the game's rules."""

    def refused(self, *words, **changes):
        with self.assertRaises(L.LayoutError) as refusal:
            read(**changes)
        for word in words:
            self.assertIn(word, str(refusal.exception))

    def test_the_layout_file_says_it_is_written_from_the_level_file(self):
        header = L.layout_header(BRIDGE)
        text = " ".join(line.removeprefix("// ") for line in header)
        for words in (BRIDGE.blend, "Do not edit it here", L.EXPORT_SCRIPT, "./scripts/check"):
            self.assertIn(words, text)
        self.assertTrue(all(line.startswith("// ") and len(line) <= 100 for line in header))
        self.assertTrue((ROOT / BRIDGE.layout).read_text().startswith("\n".join(header)))

    def test_what_blender_holds_is_written_as_it_stands(self):
        self.assertEqual(L.emit_layout(read(), BRIDGE), L.emit_layout(SAMPLE, BRIDGE))

    def test_entries_are_written_briefly_and_hold_no_looks(self):
        text = L.emit_layout(SAMPLE, BRIDGE)
        self.assertIn('      .box("car-a1", at: [9.6, 0.75, 100], size: [2, 1.5, 4.6]),\n', text)
        self.assertIn('    ground: .box("deck", at: [0, -0.15, 0], size: [24, 0.3, 250]),\n', text)
        for word in ("surface", "pieces", "turn:"):
            self.assertNotIn(word, text)

    def test_long_entries_wrap_as_swift_format_does(self):
        text = L.emit_layout(SAMPLE, BRIDGE)
        self.assertIn(
            '      .sun(\n'
            '        "sun-key", from: [-6, 8, 0], color: [1, 0.91, 0.74], intensity: 4500, '
            'shadowDistance: 25),\n', text)
        self.assertTrue(all(len(line) <= 100 for line in text.splitlines()))

    def test_a_moved_box_is_written_where_it_was_put(self):
        shapes = shapes_for(SAMPLE)
        car = next(shape for shape in shapes if shape.name == "car-a1")
        car.minimum = (car.minimum[0], car.minimum[1] + 2, car.minimum[2])
        car.maximum = (car.maximum[0], car.maximum[1] + 2, car.maximum[2])
        moved = next(box for box in read(shapes).boxes if box.name == "car-a1")
        self.assertAlmostEqual(moved.position[2], 98)

    def test_a_box_turned_at_an_angle_or_no_longer_a_box_is_refused(self):
        shapes = shapes_for(SAMPLE)
        shapes[1].square = False
        self.refused("railing-west", "quarter turns", shapes=shapes)
        shapes = shapes_for(SAMPLE)
        shapes[2].cuboid = False
        self.refused("car-a1", "no longer a box", shapes=shapes)

    def test_boxes_and_landmarks_stand_on_the_deck(self):
        for name in ("car-a1", "bridge.booth"):
            shapes = shapes_for(SAMPLE)
            raised = next(shape for shape in shapes if shape.name == name)
            raised.minimum = raised.minimum[:2] + (0.3,)
            self.refused(name, "should stand on the deck", shapes=shapes)
        shapes = shapes_for(SAMPLE)
        shapes[0].maximum = shapes[0].maximum[:2] + (0.2,)
        self.refused("The deck's top should be at height 0", shapes=shapes)

    def test_one_ground_and_names_of_their_own(self):
        shapes = shapes_for(SAMPLE)
        self.refused("exactly one ground", shapes=shapes + [replace(shapes[0], name="deck-2")])
        self.refused("Two boxes are named car-a1", shapes=shapes + [replace(shapes[2])])
        self.refused("duplicate suffix", shapes=shapes + [replace(shapes[2], name="car-a1.001")])

    def test_a_name_the_story_uses_cannot_disappear(self):
        shapes = without(shapes_for(SAMPLE), "spawn.miki")
        self.refused("spawn.miki", "BrooklynBridge.swift", shapes=shapes,
                     required={("marker", "spawn.miki")})
        read(without(shapes_for(SAMPLE), "car-a1"), required={("marker", "spawn.miki")})

    def test_names_the_story_uses_are_the_layouts_it_quotes(self):
        story = 'let start = layout.marker(named: "spawn.miki")\npoint("bridge.booth", "Booth")\n'
        self.assertEqual(L.required_names(L.emit_layout(SAMPLE, BRIDGE), story),
                         {("marker", "spawn.miki"), ("landmark", "bridge.booth")})
        bridge = L.required_names((ROOT / BRIDGE.layout).read_text(),
                                  (ROOT / BRIDGE.story).read_text())
        self.assertLessEqual({("marker", "spawn.miki"), ("area", "manhattan-end"),
                              ("box", "brooklyn-tower-pier")}, bridge)

    def test_without_its_layout_file_export_cannot_tell_the_storys_names(self):
        with tempfile.TemporaryDirectory() as folder:
            repository = Path(folder)
            (repository / BRIDGE.story).parent.mkdir(parents=True)
            shutil.copyfile(ROOT / BRIDGE.story, repository / BRIDGE.story)
            with self.assertRaises(L.LayoutError) as refusal:
                L.names_the_story_uses(repository, BRIDGE)
            self.assertIn(f"git restore {BRIDGE.layout}", str(refusal.exception))
            shutil.copyfile(ROOT / BRIDGE.layout, repository / BRIDGE.layout)
            self.assertIn(("marker", "spawn.miki"), L.names_the_story_uses(repository, BRIDGE))

    def test_the_level_needs_its_camera_within_reason(self):
        with self.assertRaises(L.LayoutError) as refusal:
            L.layout_from_shapes(shapes_for(SAMPLE), BRIDGE, None, lights_for(SAMPLE))
        self.assertIn("game camera", str(refusal.exception))
        self.refused("field of view", camera=L.CameraShape((0, -9.9, 10), 150))

    def test_a_sun_turned_brightened_or_recoloured_is_written(self):
        lights = lights_for(SAMPLE)
        lights[0].direction = (0, 0, 1)
        lights[1].energy *= 2
        lights[1].color = L._linear(0.5, 0.6, 0.7)
        key, fill = read(lights=lights).lights
        self.assertEqual(key.source, (0, 10, 0))
        self.assertEqual(fill.intensity, 1200)
        self.assertEqual(fill.color, (0.5, 0.6, 0.7))

    def test_shadows_follow_each_suns_shadow_setting(self):
        lights = lights_for(SAMPLE)
        lights[0].shadow, lights[0].shadow_distance = False, None
        lights[1].shadow = True
        key, fill = read(lights=lights).lights
        self.assertIsNone(key.shadow_distance)
        self.assertEqual(fill.shadow_distance, L.DEFAULT_SHADOW_DISTANCE)

    def test_lights_beyond_the_visual_direction_or_the_game_are_refused(self):
        lights = lights_for(SAMPLE)
        self.refused("at most 2 lights", lights=lights + [replace(lights[1], name="third")])
        self.refused("1 light with shadows", lights=[lights[0], replace(lights[1], shadow=True)])
        self.refused("point light", lights=[replace(lights[0], kind="POINT"), lights[1]])
        self.refused("needs a light", lights=[])
        self.refused("needs some intensity", lights=[replace(lights[0], energy=0), lights[1]])


class ExportRecordTests(unittest.TestCase):
    """The record of what each export was made from, which ./scripts/check holds the exports to."""

    def scratch(self, folder):
        """A copy of the bridge's level file, its exports and their record."""
        repository = Path(folder)
        for name in (BRIDGE.blend, BRIDGE.layout, BRIDGE.scene, L.EXPORT_RECORD):
            (repository / name).parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, repository / name)
        return repository

    def test_the_bridges_exports_match_its_level_file(self):
        reason = L.stale_exports(ROOT)
        self.assertIsNone(reason, f"{reason} Export it again with {L.EXPORT_SCRIPT}, as "
                                  "CONTRIBUTING describes.")

    def test_exports_go_stale_when_the_level_file_changes(self):
        with tempfile.TemporaryDirectory() as folder:
            repository = self.scratch(folder)
            self.assertIsNone(L.stale_exports(repository))
            with (repository / BRIDGE.blend).open("ab") as stream:
                stream.write(b"saved again")
            self.assertEqual(L.stale_exports(repository),
                             f"{BRIDGE.blend} changed since {BRIDGE.title} was exported.")

    def test_an_export_edited_by_hand_goes_stale(self):
        with tempfile.TemporaryDirectory() as folder:
            repository = self.scratch(folder)
            layout = repository / BRIDGE.layout
            layout.write_text(layout.read_text().replace("fieldOfView: 42", "fieldOfView: 45"))
            reason = L.stale_exports(repository)
            self.assertIn(BRIDGE.layout, reason)
            self.assertIn("change the level in Blender", reason)

    def test_a_missing_export_or_record_counts_as_stale(self):
        with tempfile.TemporaryDirectory() as folder:
            repository = self.scratch(folder)
            (repository / BRIDGE.scene).unlink()
            self.assertEqual(L.stale_exports(repository), f"{BRIDGE.scene} is missing.")
            (repository / L.EXPORT_RECORD).unlink()
            self.assertEqual(L.stale_exports(repository), f"{BRIDGE.title} has not been exported.")

    def test_an_export_by_an_earlier_extension_counts_as_stale(self):
        with tempfile.TemporaryDirectory() as folder:
            repository = self.scratch(folder)
            record = repository / L.EXPORT_RECORD
            record.write_text(record.read_text().replace(
                f'"format": {L.EXPORT_FORMAT}', f'"format": {L.EXPORT_FORMAT - 1}'))
            self.assertIn("earlier version", L.stale_exports(repository))

    def test_a_git_lfs_pointer_stands_for_its_file(self):
        with tempfile.TemporaryDirectory() as folder:
            pointer = Path(folder) / "level.blend"
            oid = "ab" * 32
            pointer.write_text(f"version https://git-lfs.github.com/spec/v1\noid sha256:{oid}\n"
                               "size 9\n")
            self.assertEqual(L.file_fingerprint(pointer), oid)
            self.assertTrue(L.is_lfs_pointer(pointer))
            self.assertFalse(L.is_lfs_pointer(ROOT / BRIDGE.layout))


class BackgroundTests(unittest.TestCase):
    """The order of what saving and Play run in the background."""

    def test_saving_and_play_export_only_a_stale_level(self):
        with tempfile.TemporaryDirectory() as folder:
            repository = ExportRecordTests.scratch(None, folder)
            self.assertEqual(L.background_steps(repository, BRIDGE.key, play=False), [])
            self.assertEqual([name for name, _, _ in
                              L.background_steps(repository, BRIDGE.key, play=True)], ["play"])
            (repository / L.EXPORT_RECORD).unlink()
            steps = L.background_steps(repository, BRIDGE.key, play=True)
            self.assertEqual([(name, log) for name, _, log in steps],
                             [("export", "export.log"), ("play", "play.log")])
            command = steps[0][1]
            self.assertIn(str(repository / L.EXPORT_SCRIPT), command)
            self.assertEqual(command[-2:], ["--", BRIDGE.key])
            self.assertIn("--factory-startup", command)

    def test_an_export_running_or_waiting_stands_in_for_a_new_one(self):
        export = ("export", ["blender"], "export.log")
        play = ("play", ["python"], "play.log")
        # Play just after a save started an export: only the build is added, after that export.
        self.assertEqual(L.queue_steps("export", [], [export, play]), [play])
        # A save while the game builds: its export waits for the build.
        self.assertEqual(L.queue_steps("play", [], [export]), [export])
        # Another save while that export waits: nothing more.
        self.assertEqual(L.queue_steps("play", [export], [export]), [])
        self.assertEqual(L.queue_steps(None, [], [export, play]), [export, play])

    def test_a_level_saved_again_meanwhile_is_exported_again(self):
        export = ("export", ["blender"], "export.log")
        play = ("play", ["python"], "play.log")
        self.assertTrue(L.refresh_needed([], stale=True, refreshes=0))
        self.assertTrue(L.refresh_needed([play], stale=True, refreshes=0))
        self.assertFalse(L.refresh_needed([export], stale=True, refreshes=0))
        self.assertFalse(L.refresh_needed([], stale=False, refreshes=0))
        self.assertFalse(L.refresh_needed([], stale=True, refreshes=L.MOST_REFRESHES))


class ToolingTests(unittest.TestCase):
    """Finding the repository and the level, and the extension's manifest."""

    def test_the_extension_finds_the_repository_it_was_installed_from(self):
        self.assertEqual(Path(L._guess_repository()), ROOT)
        for script in (L.PLAY_SCRIPT, L.EXPORT_SCRIPT):
            self.assertTrue((ROOT / script).is_file(), script)

    def test_a_level_file_is_known_by_its_place_in_the_repository(self):
        self.assertEqual(L.level_of_file(str(ROOT / BRIDGE.blend)), (str(ROOT), BRIDGE))
        self.assertIsNone(L.level_of_file(str(ROOT / ".local/blender/brooklyn-bridge.blend")))
        self.assertIsNone(L.level_of_file(""))

    def test_the_extension_manifest_has_what_blender_needs(self):
        try:
            import tomllib
        except ImportError:
            self.skipTest("tomllib needs Python 3.11")
        manifest = tomllib.loads((HERE / "extensions/lauder_levels/blender_manifest.toml").read_text())
        for key in ("schema_version", "id", "version", "name", "tagline", "maintainer", "type",
                    "blender_version_min", "license"):
            self.assertIn(key, manifest)
        self.assertEqual((manifest["id"], manifest["type"]), ("lauder_levels", "add-on"))
        self.assertLessEqual(len(manifest["tagline"]), 64)
        self.assertNotIn(manifest["tagline"][-1], ".!?")
        self.assertEqual(manifest["license"], ["SPDX:MIT"])
        self.assertIn("files", manifest["permissions"])


if __name__ == "__main__":
    result = unittest.main(exit=False, verbosity=1).result
    sys.exit(0 if result.wasSuccessful() else 1)
