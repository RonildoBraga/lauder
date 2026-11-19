#!/usr/bin/env python3
"""Tests for the Lauder extension (extensions/lauder_levels) that need no Blender: writing and
checking a level's layout file, the record of what each export was made from, the order of the work
it runs in the background, the rules for what a scene file can show, and the models' intake check.

./scripts/check runs them. Blender's own part, reading the level's and models' Blender files and
exporting them, runs in the scripts in blender/scripts, as CONTRIBUTING describes.
"""

from dataclasses import replace
import json
import math
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
        # 30 W and 60 W in Blender.
        L.Light("lamp", None, (1, 0.8, 0.6), 20490, kind="point", position=(3, 2.5, 100), radius=12),
        L.Light("searchlight", None, (0.9, 0.95, 1), 40980, kind="spot", position=(-6, 8, 90),
                target=(-6, 2, 82), radius=30, angles=(30, 45)),
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
    """What Export reads from the Blender lights that give this layout's lights."""
    shapes = []
    for light in layout.lights:
        colour = L._linear(*light.color)
        if light.kind == "sun":
            shapes.append(L.LightShape(
                light.name, "SUN", L._unit(L.to_blender(light.source)), colour,
                light.intensity * L.SUN_STRENGTH_PER_LUX, light.shadow_distance is not None,
                light.shadow_distance))
            continue
        energy, position = light.intensity / L.LUMENS_PER_WATT, L.to_blender(light.position)
        if light.kind == "point":
            shapes.append(L.LightShape(light.name, "POINT", (0, 0, 1), colour, energy, False,
                                       position=position, custom_distance=True, cutoff=light.radius))
            continue
        beam = L._unit(L.to_blender(tuple(t - p for t, p in zip(light.target, light.position))))
        inner, outer = (math.radians(angle) for angle in light.angles)
        edge = math.cos(outer / 2)
        shapes.append(L.LightShape(
            light.name, "SPOT", tuple(-value for value in beam), colour, energy, light.shadow,
            position=position, custom_distance=True, cutoff=light.radius, spot_size=outer,
            spot_blend=(math.cos(inner / 2) - edge) / (1 - edge)))
    return shapes


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
        key, fill, *_ = read(lights=lights).lights
        self.assertEqual(key.source, (0, 10, 0))
        self.assertEqual(fill.intensity, 1200)
        self.assertEqual(fill.color, (0.5, 0.6, 0.7))

    def test_shadows_follow_each_suns_shadow_setting(self):
        lights = lights_for(SAMPLE)
        lights[0].shadow, lights[0].shadow_distance = False, None
        lights[1].shadow = True
        key, fill, *_ = read(lights=lights).lights
        self.assertIsNone(key.shadow_distance)
        self.assertEqual(fill.shadow_distance, L.DEFAULT_SHADOW_DISTANCE)

    def test_point_and_spot_lights_are_written_where_blender_holds_them(self):
        lamp, searchlight = read().lights[2:]
        self.assertEqual((lamp.kind, lamp.position, lamp.radius, lamp.intensity),
                         ("point", (3, 2.5, 100), 12, 20490))
        self.assertEqual((searchlight.kind, searchlight.position, searchlight.target),
                         ("spot", (-6, 8, 90), (-6, 2, 82)))
        self.assertEqual((searchlight.radius, searchlight.angles, searchlight.shadow), (30, (30, 45), False))
        text = L.emit_layout(read(), BRIDGE)
        self.assertIn('.point("lamp", at: [3, 2.5, 100], color: [1, 0.8, 0.6], intensity: 20490, '
                      'radius: 12)', text)
        self.assertIn('.spot(\n        "searchlight", at: [-6, 8, 90], toward: [-6, 2, 82]', text)
        # Blender softens a spot light's edge over the outer part of its cone.
        self.assertAlmostEqual(L.spot_inner_angle(math.radians(45), 0), 45)
        self.assertAlmostEqual(L.spot_inner_angle(math.radians(45), 1), 0)

    def test_lights_beyond_the_visual_direction_or_the_game_are_refused(self):
        lights = lights_for(SAMPLE)
        self.refused("at most 4 lights", lights=lights + [replace(lights[1], name="fifth")])
        self.refused("1 light with shadows", lights=lights[:3] + [replace(lights[3], shadow=True)])
        self.refused("area light", lights=[replace(lights[0], kind="AREA"), lights[1]])
        self.refused("no shadows from point lights", lights=[lights[0], replace(lights[2], shadow=True)])
        self.refused("Custom Distance", lights=[lights[0], replace(lights[3], custom_distance=False)])
        self.refused("needs a light", lights=[])
        self.refused("needs some intensity", lights=[replace(lights[0], energy=0), lights[1]])
        # Blender would preview these lights in a colour or brightness that the game cannot read.
        self.refused("Temperature", lights=[replace(lights[0], temperature=True), lights[1]])
        self.refused("Normalize on", lights=[lights[0], replace(lights[2], normalize=False)])

    def test_exposure_multiplies_a_lights_strength_as_in_blender(self):
        lights = lights_for(SAMPLE)
        brighter = read(lights=[replace(light, exposure=1) for light in lights]).lights
        for light, doubled in zip(read().lights, brighter):
            self.assertAlmostEqual(doubled.intensity, 2 * light.intensity, delta=0.2)
        dimmer = read(lights=[lights[0], lights[1], replace(lights[2], exposure=-2)]).lights
        self.assertAlmostEqual(dimmer[2].intensity, 20490 / 4, delta=0.2)


class ExportRecordTests(unittest.TestCase):
    """The record of what each export was made from, which ./scripts/check holds the exports to."""

    def scratch(self, folder):
        """A copy of the bridge's level file, the files it uses, its exports and their record."""
        repository = Path(folder)
        made_from = json.loads((ROOT / L.EXPORT_RECORD).read_text())[BRIDGE.key]["made from"]
        for name in (BRIDGE.layout, BRIDGE.scene, L.EXPORT_RECORD, *made_from):
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

    def test_exports_go_stale_when_a_model_they_use_changes(self):
        with tempfile.TemporaryDirectory() as folder:
            repository = self.scratch(folder)
            made_from = json.loads((repository / L.EXPORT_RECORD).read_text())[BRIDGE.key]
            models = [name for name in made_from["made from"]
                      if L.model_of_path(repository, repository / name)]
            self.assertTrue(models, "the bridge uses models")
            with (repository / models[0]).open("ab") as stream:
                stream.write(b"saved again")
            self.assertEqual(L.stale_exports(repository),
                             f"{models[0]} changed since {BRIDGE.title} was exported.")
            (repository / models[0]).unlink()
            self.assertEqual(L.stale_exports(repository), f"{models[0]} is missing.")

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
            self.assertEqual([step[0] for step in
                              L.background_steps(repository, BRIDGE.key, play=True)], ["play"])
            (repository / L.EXPORT_RECORD).unlink()
            steps = L.background_steps(repository, BRIDGE.key, play=True)
            self.assertEqual([(name, log, key) for name, _, log, key in steps], [
                ("export", "export.log", BRIDGE.key), ("play", "play.log", BRIDGE.key)])
            command = steps[0][1]
            self.assertIn(str(repository / L.EXPORT_SCRIPT), command)
            self.assertEqual(command[-2:], ["--", BRIDGE.key])
            self.assertIn("--factory-startup", command)

    def test_an_export_running_or_waiting_stands_in_for_a_new_one(self):
        export = ("export", ["blender"], "export.log", "bridge")
        play = ("play", ["python"], "play.log", "bridge")
        other = ("export", ["blender"], "export.log", "tunnel")
        # Play just after a save started an export: only the build is added, after that export.
        self.assertEqual(L.queue_steps(export, [], [export, play]), [play])
        # A save while the game builds: its export waits for the build.
        self.assertEqual(L.queue_steps(play, [], [export]), [export])
        # Another save while that export waits: nothing more.
        self.assertEqual(L.queue_steps(play, [export], [export]), [])
        self.assertEqual(L.queue_steps(None, [], [export, play]), [export, play])
        # A model that two levels use: each level's export stands only for its own.
        self.assertEqual(L.queue_steps(export, [], [export, other]), [other])

    def test_a_level_saved_again_meanwhile_is_exported_again(self):
        export = ("export", ["blender"], "export.log", "bridge")
        play = ("play", ["python"], "play.log", "bridge")
        other = ("export", ["blender"], "export.log", "tunnel")
        self.assertTrue(L.refresh_needed(export, [], stale=True, refreshes=0))
        self.assertTrue(L.refresh_needed(export, [play], stale=True, refreshes=0))
        self.assertTrue(L.refresh_needed(export, [other], stale=True, refreshes=0))
        self.assertFalse(L.refresh_needed(play, [export], stale=True, refreshes=0))
        self.assertFalse(L.refresh_needed(export, [], stale=False, refreshes=0))
        self.assertFalse(L.refresh_needed(export, [], stale=True, refreshes=L.MOST_REFRESHES))

    def test_saving_a_model_exports_the_levels_that_used_it(self):
        with tempfile.TemporaryDirectory() as folder:
            repository = ExportRecordTests.scratch(None, folder)
            record = repository / L.EXPORT_RECORD
            records = json.loads(record.read_text())
            used = records[BRIDGE.key]["made from"]
            self.assertEqual(L.levels_using(repository, BRIDGE.blend), [BRIDGE.key])
            for name in used:
                if L.model_of_path(repository, repository / name):
                    self.assertEqual(L.levels_using(repository, name), [BRIDGE.key])
            self.assertEqual(L.levels_using(repository, f"{L.ASSETS}/kite/kite.blend"), [])


class SceneRuleTests(unittest.TestCase):
    """What a scene file can show as Blender does (ADR 0006, decision 8)."""

    PAINT = L.MaterialShape("car paint", "blender/assets/car/car.blend", "BSDF_PRINCIPLED", (
        ("Base Color", (("TEX_IMAGE", "Image Texture"), ("UVMAP", "UV Map"))),
        ("Normal", (("NORMAL_MAP", "Normal Map"), ("TEX_IMAGE", "Image Texture"))),
        ("Alpha", (("MATH", "Math"), ("TEX_IMAGE", "Image Texture"))),
    ))

    def test_names_become_usds_as_blender_writes_them(self):
        self.assertEqual(L.usd_name("car-a1 model"), "car_a1_model")
        self.assertEqual(L.usd_name("bridge.booth"), "bridge_booth")
        self.assertEqual(L.usd_name("2nd car"), "_nd_car")
        self.assertEqual(L.usd_name("café"), "caf__")
        self.assertEqual(L.name_clashes(["car body", "car-body", "car cabin"], "parts"), [
            "The parts car body and car-body would all be car_body in the scene file: give each "
            "a name of its own."])

    def test_a_principled_bsdf_with_image_textures_reaches_the_game(self):
        self.assertEqual(L.material_problems([self.PAINT, L.MaterialShape(
            "Lauder metal", None, "BSDF_PRINCIPLED")]), [])

    def test_other_surfaces_and_nodes_must_be_baked_first(self):
        noisy = replace(self.PAINT, name="rust", feeds=(
            ("Base Color", (("TEX_NOISE", "Noise Texture"), ("MIX", "Mix"))),
            ("Roughness", (("MATH", "Math"),)),
        ))
        problems = L.material_problems([noisy, L.MaterialShape("glow", None, "EMISSION"),
                                        L.MaterialShape("bare")])
        self.assertEqual(len(problems), 4)
        self.assertIn("rust (from blender/assets/car/car.blend) makes its Base Color with Mix and "
                      "Noise Texture", problems[0])
        self.assertIn("its Roughness with Math", problems[1])
        self.assertIn("glow needs a Principled BSDF", problems[2])
        self.assertIn("bare needs a Principled BSDF", problems[3])

    def test_maps_that_the_game_would_show_differently_are_refused(self):
        packed = replace(self.PAINT, name="packed", feeds=(
            ("Roughness", (("SEPARATE_COLOR", "Separate Color"), ("TEX_IMAGE", "Image Texture"))),
        ))
        sign = replace(self.PAINT, name="sign", feeds=self.PAINT.feeds + (
            ("Emission Color", (("TEX_IMAGE", "Image Texture"),)),), emission_strength=4)
        unlit = replace(sign, name="unlit sign", emission_strength=0)
        gentle = replace(self.PAINT, name="gentle", normal_strengths=(0.25,))
        coated = replace(self.PAINT, name="coated", feeds=(
            ("Coat Weight", (("TEX_IMAGE", "Image Texture"),)),))
        problems = L.material_problems([packed, sign, unlit, gentle, coated])
        self.assertEqual(len(problems), 5)
        self.assertIn("packed (from blender/assets/car/car.blend) reads its Roughness from one "
                      "channel of an image with Separate Color", problems[0])
        self.assertIn("sign (from blender/assets/car/car.blend) has an Emission Strength of 4",
                      problems[1])
        self.assertIn("an Emission Strength of 0", problems[2])
        self.assertIn("a Normal Map Strength of 0.25", problems[3])
        self.assertIn("coated (from blender/assets/car/car.blend) feeds its Coat Weight with nodes, "
                      "and the game takes images only on Base Color, Roughness, Metallic, Normal, "
                      "Emission Color and Alpha", problems[4])
        # At strength 1, with roughness from an image's alpha, the game shows them as Blender does.
        lit = replace(sign, name="lit sign", emission_strength=1, normal_strengths=(1.0,), feeds=(
            *sign.feeds, ("Roughness", (("TEX_IMAGE", "Image Texture"),))))
        self.assertEqual(L.material_problems([lit]), [])

    def test_materials_that_usd_would_merge_are_refused(self):
        # Blender's USD export writes one material for two of the same name, so one model would
        # show the other's look.
        van = replace(self.PAINT, source="blender/assets/van/van.blend")
        problems = L.material_problems([self.PAINT, van])
        self.assertEqual(len(problems), 1)
        self.assertIn("would all be car_paint", problems[0])

    def test_textures_are_image_files_of_their_own_in_the_repository(self):
        good = L.TextureShape("paint", "blender/assets/car/textures/paint.png", bytes=900)
        self.assertEqual(L.texture_problems([good], "blender/assets/car"), [])
        cases = {
            "packed": L.TextureShape("a", packed=True),
            "missing": L.TextureShape("b", "//textures/b.png", exists=False),
            "outside the repository": L.TextureShape("c", "/elsewhere/c.png"),
            "copy it into blender/assets/car": L.TextureShape("d", "blender/levels/d.png"),
            "PNG and JPEG": L.TextureShape("e", "blender/assets/car/textures/e.exr"),
            "generated": L.TextureShape("f", source="GENERATED"),
            "add a rule": L.TextureShape("g", "blender/assets/car/textures/g.png",
                                         bytes=L.LFS_IMAGE_BYTES + 1, lfs=False),
            "makes it relative": L.TextureShape("h", "blender/assets/car/textures/h.png",
                                                full_path=True),
            "not downloaded yet": L.TextureShape("i", "blender/assets/car/textures/i.png",
                                                 pointer=True),
        }
        for words, texture in cases.items():
            problems = L.texture_problems([texture], "blender/assets/car")
            self.assertEqual(len(problems), 1, words)
            self.assertIn(words, problems[0])
        stored = replace(cases["add a rule"], lfs=True)
        self.assertEqual(L.texture_problems([stored], "blender/assets/car"), [])


class ModelTests(unittest.TestCase):
    """The models in blender/assets, and the intake check (ADR 0006, decision 7)."""

    README = "# kite\n\n- **Source:** Made for Lauder.\n- **Licence:** MIT, as the repository.\n"

    def kite(self, **changes):
        shape = L.ModelShape(
            "kite", collections=("kite",), names=("kite body", "kite tail"),
            shown=("kite body", "kite tail"), bounds=((-0.5, -1, 0), (0.5, 1, 0.4)),
            triangles=24, materials=(L.MaterialShape("kite paint", None, "BSDF_PRINCIPLED"),),
            readme=self.README)
        return replace(shape, **changes)

    def test_a_model_is_known_by_its_place_in_the_repository(self):
        self.assertEqual(L.model_of_path(ROOT, ROOT / "blender/assets/car/car.blend"), "car")
        for other in ("blender/assets/car/van.blend", "blender/assets/Car/Car.blend",
                      "blender/levels/brooklyn-bridge.blend", "blender/assets/car.blend"):
            self.assertIsNone(L.model_of_path(ROOT, ROOT / other), other)
        self.assertEqual(L.model_of_file(str(ROOT / "blender/assets/car/car.blend")),
                         (str(ROOT), "car"))

    def test_a_model_ready_for_levels_has_nothing_to_fix(self):
        problems, notes = L.model_report(self.kite())
        self.assertEqual(problems, [])
        self.assertEqual(notes, ["It measures 1 m across, 2 m long and 0.4 m high."])
        self.assertEqual(L.report_text("kite", problems, notes).splitlines()[0],
                         "kite is ready for levels to use.")

    def test_the_intake_check_says_what_to_fix_first(self):
        cases = {
            "a collection named kite": self.kite(collections=("Collection",)),
            "holds nothing with a shape": self.kite(shown=()),
            "Metric, with a Unit Scale of 1": self.kite(units=("IMPERIAL", 1.0)),
            "Remove kite light": self.kite(lights=("kite light",)),
            "needs a Principled BSDF": self.kite(materials=(L.MaterialShape("kite paint"),)),
            "unpack it into blender/assets/kite": self.kite(
                textures=(L.TextureShape("cloth", packed=True),)),
            "would all be kite_body": self.kite(names=("kite body", "kite-body")),
            "blender/assets/kite/README.md is missing": self.kite(readme=None),
        }
        for words, model in cases.items():
            problems, _ = L.model_report(model)
            self.assertEqual(len(problems), 1, f"{words}: {problems}")
            self.assertIn(words, problems[0])
        self.assertIn("lowercase letters", L.model_report(L.ModelShape(None))[0][0])

    def test_the_readme_names_the_source_and_licence(self):
        unfilled = "- **Source:** ? Where it comes from.\n- **Licence:** ? Its licence.\n"
        self.assertEqual(L.provenance_problems("kite", unfilled), [
            "blender/assets/kite/README.md needs its **Source:** line filled in.",
            "blender/assets/kite/README.md needs its **Licence:** line filled in."])
        self.assertEqual(L.provenance_problems("kite", self.README), [])

    def test_the_intake_check_notes_what_is_worth_a_look(self):
        _, notes = L.model_report(self.kite(
            bounds=((-50, -230, 0.2), (150, 230, 150)), triangles=L.MOST_TRIANGLES + 1,
            textures=(L.TextureShape("cloth", "blender/assets/kite/textures/cloth.png",
                                     pixels=(4096, 4096)),),
            hidden=("kite string",), names=("kite body", "kite tail.001")))
        text = " ".join(notes)
        for words in ("made in metres", "lowest point is at a height of 0.2 m", "centre it",
                      "10,001 triangles", "no new textures", "cloth is more than 2048 pixels",
                      "kite string is hidden from renders", "kite tail.001 has Blender's"):
            self.assertIn(words, text)


class AssetTests(unittest.TestCase):
    """The models in the repository: each in its folder, with its source and licence."""

    def test_every_model_has_its_file_and_names_its_source_and_licence(self):
        folder = ROOT / L.ASSETS
        self.assertTrue((folder / "README.md").is_file())
        for item in sorted(folder.iterdir()):
            if item.name == "README.md":
                continue
            self.assertTrue(item.is_dir() and L.MODEL_NAME.fullmatch(item.name),
                            f"{item.name}: keep each model in a folder named after it")
            self.assertTrue((item / f"{item.name}.blend").is_file(), f"{item.name} has its file")
            readme = item / "README.md"
            text = readme.read_text() if readme.is_file() else None
            self.assertEqual(L.provenance_problems(item.name, text), [])
        self.assertEqual(L.available_models(ROOT), sorted(
            item.name for item in folder.iterdir() if item.is_dir()))


class PrivacyTests(unittest.TestCase):
    """The public repository's Blender files hold no paths from the computer they were saved on."""

    def test_blender_files_hold_no_part_of_a_local_path(self):
        try:
            from compression import zstd
        except ImportError:
            self.skipTest("Reading Blender's compressed files needs Python 3.14 or later")
        home = Path.home()
        # Blender keeps a path's tail behind a shorter one, so a folder's name between slashes
        # finds what the full path would miss.
        markers = {str(home), str(ROOT), f"/{home.name}/", "/Users/", "/home/", "/private/",
                   "/var/folders/", "C:\\Users"}
        for path in sorted((ROOT / "blender").rglob("*.blend")):
            if L.is_lfs_pointer(path):
                continue
            data = path.read_bytes()
            if data.startswith(b"\x28\xb5\x2f\xfd"):
                data = zstd.decompress(data)
            for marker in markers:
                self.assertNotIn(marker.encode(), data,
                                 f"{path.relative_to(ROOT)} holds part of a local path")


class ToolingTests(unittest.TestCase):
    """Finding the repository and the level, and the extension's manifest."""

    def test_the_extension_finds_the_repository_it_was_installed_from(self):
        self.assertEqual(Path(L._guess_repository()), ROOT)
        for script in (L.PLAY_SCRIPT, L.EXPORT_SCRIPT, L.CHECK_MODEL_SCRIPT, L.ADD_MODEL_SCRIPT):
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
        for reason in manifest["permissions"].values():
            self.assertLessEqual(len(reason), 64)
            self.assertNotIn(reason[-1], ".!?")


if __name__ == "__main__":
    result = unittest.main(exit=False, verbosity=1).result
    sys.exit(0 if result.wasSuccessful() else 1)
