#!/usr/bin/env python3
"""Tests for the Lauder extension (extensions/lauder_levels) that need no Blender: reading, writing and checking layouts and the
surface palette.

./scripts/check runs them. Blender's own part, building and reading objects, is checked by
loading and saving a level in Blender (CONTRIBUTING).
"""

import math
from pathlib import Path
import re
import struct
import sys
import unittest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "extensions"))
sys.dont_write_bytecode = True

import lauder_levels as L  # noqa: E402

ROOT = HERE.parent
BRIDGE = L.LEVELS["brooklyn-bridge"]


def single(value):
    """A number as Blender stores it, in single precision."""
    return struct.unpack("f", struct.pack("f", value))[0]


def singles(values):
    return tuple(single(value) for value in values)


def shapes_for(layout):
    """What Save would read from Blender after a Load of this layout, with no edits."""
    shapes = []

    def block(name, role, centre, size, surface=None):
        cx, cy, cz = L.to_blender(centre)
        sx, sy, sz = L.size_to_blender(size)
        low = singles((cx - sx / 2, cy - sy / 2, cz - sz / 2))
        high = singles((cx + sx / 2, cy + sy / 2, cz + sz / 2))
        shapes.append(L.Shape(name, role, low, high, surface))

    block(layout.ground.name, "ground", layout.ground.position, layout.ground.size,
          layout.ground.surface)
    for box in layout.boxes:
        block(box.name, "box", box.position, box.size, box.surface)
    for item in layout.landmarks:
        x, y, z = item.position
        block(item.name, "landmark", (x, y + item.size[1] / 2, z), item.size)
    for area in layout.areas:
        (x0, z0), (x1, z1) = area.minimum, area.maximum
        shapes.append(L.Shape(area.name, "area", (single(x0), single(-z1), 0),
                              (single(x1), single(-z0), 0.05)))
    for marker in layout.markers:
        point = (single(marker.position[0]), single(-marker.position[1]), 0)
        shapes.append(L.Shape(marker.name, "marker", point, point))
    for piece in layout.pieces:
        centre = singles(L.to_blender(piece.position))
        shapes.append(L.Shape(
            piece.name, "piece", centre, centre, piece.surface, centre=centre,
            size=singles(L.size_to_blender(piece.size)),
            rotation=singles(L.rotation_to_blender(piece.rotation))))
    return shapes


def camera_for(layout):
    """What Save would read from the game camera's rig after a Load, with no edits: the camera
    hangs from its target, which starts at Miki's spawn."""
    spawn = next(m.position for m in layout.markers if m.name == BRIDGE.camera_target)
    target = singles((spawn[0], -spawn[1], L.CAMERA_TARGET_HEIGHT))
    hanging = singles(L.to_blender(layout.camera.offset))
    camera = singles(t + h for t, h in zip(target, hanging))
    offset = singles(c - t for c, t in zip(camera, target))
    return L.CameraShape(offset, math.degrees(single(math.radians(layout.camera.field_of_view))))


def lights_for(layout):
    """What Save would read from the level's suns after a Load, with no edits: each turned to
    shine from its source, in Blender's units and single precision."""
    return [
        L.LightShape(
            light.name, "SUN", singles(L._unit(L.to_blender(light.source))),
            singles(L._linear(*light.color)[:3]), single(light.intensity * L.SUN_STRENGTH_PER_LUX),
            light.shadow_distance is not None, light.shadow_distance)
        for light in layout.lights
    ]


def turn(axis, degrees):
    """A quaternion (w, x, y, z) turning by the angle about the axis."""
    half = math.radians(degrees) / 2
    length = math.sqrt(sum(value * value for value in axis))
    return (math.cos(half),) + tuple(math.sin(half) * value / length for value in axis)


def rotate(q, vector):
    _, x, y, z = L._multiply(L._multiply(q, (0,) + tuple(vector)), L._conjugate(q))
    return (x, y, z)


def same_turn(a, b, tolerance=1e-7):
    a, b = L._canonical(a), L._canonical(b)
    return abs(sum(x * y for x, y in zip(a, b))) > 1 - tolerance


class BridgeLayoutTests(unittest.TestCase):
    def setUp(self):
        self.surfaces = set(L.parse_palette((ROOT / L.PALETTE_PATH).read_text()))
        self.text = (ROOT / BRIDGE.path).read_text()
        self.layout = L.parse_layout(self.text, self.surfaces)

    def save(self, shapes, camera=None, lights=None):
        return L.layout_from_shapes(shapes, BRIDGE, self.layout, camera, lights, self.surfaces)

    def test_the_bridge_file_reads_and_writes_back_unchanged(self):
        self.assertEqual(L.emit_layout(self.layout, BRIDGE, self.surfaces), self.text)
        self.assertEqual(self.layout.ground.name, "deck")
        self.assertIn("car-b4", [box.name for box in self.layout.boxes])
        self.assertTrue(any(not L.is_identity(piece.rotation) for piece in self.layout.pieces))
        self.assertTrue(any(L.is_identity(piece.rotation) for piece in self.layout.pieces))
        self.assertIsNotNone(self.layout.camera)
        self.assertEqual([light.name for light in self.layout.lights], ["sun-key", "sky-fill"])

    def test_a_load_and_save_with_no_edits_changes_nothing(self):
        saved = self.save(shapes_for(self.layout), camera_for(self.layout), lights_for(self.layout))
        self.assertEqual(L.emit_layout(saved, BRIDGE), self.text)

    def test_a_quarter_turn_swaps_the_footprint(self):
        shapes = shapes_for(self.layout)
        car = next(shape for shape in shapes if shape.name == "car-a1")
        (x0, y0, z0), (x1, y1, z1) = car.minimum, car.maximum
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        hx, hy = (x1 - x0) / 2, (y1 - y0) / 2
        car.minimum, car.maximum = (cx - hy, cy - hx, z0), (cx + hy, cy + hx, z1)
        turned = next(box for box in self.save(shapes).boxes if box.name == "car-a1")
        self.assertAlmostEqual(turned.size[0], 4.6, places=4)
        self.assertAlmostEqual(turned.size[2], 2, places=4)

    def test_a_moved_car_is_saved_where_it_was_put(self):
        shapes = shapes_for(self.layout)
        car = next(shape for shape in shapes if shape.name == "car-b3")
        car.minimum = (car.minimum[0] + 1, car.minimum[1] - 2, car.minimum[2])
        car.maximum = (car.maximum[0] + 1, car.maximum[1] - 2, car.maximum[2])
        text = L.emit_layout(self.save(shapes), BRIDGE)
        self.assertIn('.box("car-b3", at: [5.6, 0.75, 50], size: [2, 1.5, 4.6]', text)

    def check_refused(self, shapes, words, camera=None, lights=None):
        with self.assertRaises(L.LayoutError) as caught:
            self.save(shapes, camera, lights)
        self.assertIn(words, str(caught.exception))

    def test_an_angled_or_mirrored_box_is_refused(self):
        shapes = shapes_for(self.layout)
        next(shape for shape in shapes if shape.name == "car-a1").square = False
        self.check_refused(shapes, "quarter turns")

    def test_a_box_that_is_no_longer_a_box_is_refused(self):
        shapes = shapes_for(self.layout)
        next(shape for shape in shapes if shape.name == "car-a1").cuboid = False
        self.check_refused(shapes, "no longer a box")

    def test_a_box_off_the_deck_is_refused(self):
        shapes = shapes_for(self.layout)
        car = next(shape for shape in shapes if shape.name == "car-a1")
        car.minimum = car.minimum[:2] + (0.2,)
        self.check_refused(shapes, "should stand on the deck")

    def test_a_box_without_a_lauder_material_is_refused(self):
        shapes = shapes_for(self.layout)
        next(shape for shape in shapes if shape.name == "car-a1").surface = None
        self.check_refused(shapes, "no Lauder surface")

    def test_blender_duplicate_names_are_refused(self):
        shapes = shapes_for(self.layout)
        next(shape for shape in shapes if shape.name == "car-a1").name = "car-a1.001"
        self.check_refused(shapes, "duplicate suffix")

    def test_named_parts_cannot_disappear(self):
        shapes = [shape for shape in shapes_for(self.layout) if shape.name != "stranger"]
        self.check_refused(shapes, "The area stranger is missing")
        shapes = [s for s in shapes_for(self.layout) if s.name != "brooklyn-tower-pier"]
        self.check_refused(shapes, "brooklyn-tower-pier is missing")

    def test_new_boxes_are_added_and_cars_can_be_removed(self):
        shapes = [shape for shape in shapes_for(self.layout) if shape.name != "car-e2"]
        shapes.append(L.Shape("car-z1", "box", (1, 2, 0), (3, 6.6, 1.5), "vehicle"))
        saved = self.save(shapes)
        names = [box.name for box in saved.boxes]
        self.assertNotIn("car-e2", names)
        self.assertEqual(names[-1], "car-z1")
        self.assertEqual(saved.boxes[-1].position, (2, 0.75, -4.3))

    def test_an_entry_the_script_cannot_read_stops_the_load(self):
        for broken in (
            self.text.replace('.box("car-a1", at:', '.box(name: "car-a1", at:'),
            self.text.replace("at: [9.6, 0.75, 100]", "at: [9.6, 100]"),
            self.text.replace("turn: [", "turn: [0, ", 1),
            self.text.replace("camera: .camera(", "", 1),
            self.text.replace('.sun("sky-fill", from:', '.sun("sky-fill", towards:'),
            self.text.replace("    lights: [", "    lamps: ["),
            # Entries in another form, which the count of known entries alone would miss.
            re.sub(r'\.sun\("sky-fill"[^)]*\)',
                   '.init(name: "sky-fill", source: [3, 5, -4], color: [0.67, 0.81, 0.85], '
                   'intensity: 600, shadowDistance: nil)', self.text),
            self.text.replace('.box("car-a1", at:', 'Level.Box(name: "car-a1", at:', 1),
            self.text.replace("  static let layout", "  static let spare = 1\n  static let layout"),
        ):
            with self.subTest(broken=broken[:0]), self.assertRaises(L.LayoutError):
                L.parse_layout(broken)

    def test_long_entries_wrap_as_swift_format_does(self):
        box = L.Box("a-very-long-name-for-a-box-on-the-bridge", (-123.456, 0.75, 101.234),
                    (2.345, 1.5, 4.678), "vehicle")
        piece = L.Piece("a-very-long-name-for-a-piece-of-the-bridge", (-123.456, 7.25, 101.234),
                        (0.22, 0.22, 35.616), "metal", (0.9933, 0.1154, 0, 0))
        camera = L.Camera((0, 10, 9.9), 42)
        light = L.Light("a-very-long-name-for-a-sun-over-the-bridge", (-3.25, 8.5, 5.75),
                        (0.987, 0.912, 0.745), 4567.5, 33.5)
        layout = L.Layout(self.layout.ground, [box], [], [], [], [piece], camera, [light])
        text = L.emit_layout(layout, BRIDGE)
        self.assertTrue(all(len(line) <= 100 for line in text.splitlines()))
        read = L.parse_layout(text)
        self.assertEqual(read.boxes[0], box)
        self.assertEqual(read.pieces[0], piece)
        self.assertEqual(read.lights, [light])
        self.assertIn("    landmarks: [],", text)
        self.assertIn("    markers: [],", text)
        self.assertIn("    camera: .camera(offset: [0, 10, 9.9], fieldOfView: 42),\n", text)
        self.assertTrue(text.endswith(
            "    lights: [\n      .sun(\n"
            '        "a-very-long-name-for-a-sun-over-the-bridge", from: [-3.25, 8.5, 5.75],\n'
            "        color: [0.987, 0.912, 0.745], intensity: 4567.5, shadowDistance: 33.5),\n"
            "    ])\n}\n"))

    def test_a_call_and_its_comma_stay_on_one_line_up_to_98_columns(self):
        # As swift format does: a longer call followed by a comma is wrapped.
        def piece(name):
            return L.Piece(name, (12.4, 3.89, -10), (0.05, 5.58, 0.05), "metal")

        layout = L.Layout(self.layout.ground, [], [], [], [],
                          [piece("s" * 15), piece("s" * 16)], self.layout.camera,
                          self.layout.lights)
        lines = L.emit_layout(layout, BRIDGE).splitlines()
        one = next(line for line in lines if '"' + "s" * 15 + '"' in line)
        self.assertEqual((len(one), one.strip()[:7]), (98, '.piece('))
        wrapped = lines.index(next(line for line in lines if '"' + "s" * 16 + '"' in line))
        self.assertEqual(lines[wrapped - 1], "      .piece(")

    # MARK: - Pieces

    def test_rotations_convert_between_the_game_and_blender(self):
        for q in (turn((0, 1, 0), 30), turn((1, 0, 0), -6.6), turn((0.3, -1, 2), 123)):
            in_blender = L.rotation_to_blender(q)
            self.assertTrue(same_turn(L.rotation_from_blender(in_blender), q))
            for vector in ((1, 0, 0), (0, 1, 0), (0.2, -0.5, 3)):
                expected = L.to_blender(rotate(q, vector))
                for want, got in zip(expected, rotate(in_blender, L.to_blender(vector))):
                    self.assertAlmostEqual(want, got, places=9)
        # The game's vertical is Blender's: a turn about one is the same turn about the other.
        self.assertTrue(same_turn(L.rotation_to_blender(turn((0, 1, 0), 30)), turn((0, 0, 1), 30)))

    def test_a_turned_piece_is_saved_at_its_new_angle(self):
        piece = next(p for p in self.layout.pieces if not L.is_identity(p.rotation))
        shapes = shapes_for(self.layout)
        shape = next(s for s in shapes if s.name == piece.name)
        # Turned 30 degrees about Blender's vertical, as R Z 30 does.
        shape.rotation = L._multiply(turn((0, 0, 1), 30), shape.rotation)
        text = L.emit_layout(self.save(shapes, camera_for(self.layout)), BRIDGE)
        saved = next(p for p in L.parse_layout(text).pieces if p.name == piece.name)
        expected = L._multiply(turn((0, 1, 0), 30), L._canonical(piece.rotation))
        self.assertTrue(same_turn(saved.rotation, expected))
        self.assertEqual((saved.position, saved.size), (piece.position, piece.size))

        def without(text):
            return re.sub(r'\s*\.piece\(\s*"' + re.escape(piece.name) + r'"[^)]*\),', "", text)

        self.assertEqual(without(text), without(self.text))

    def test_a_small_turn_is_saved_and_kept(self):
        # Half a degree about the vertical swings the ends of a long piece by metres.
        piece = next(p for p in self.layout.pieces if L.is_identity(p.rotation))
        shapes = shapes_for(self.layout)
        shape = next(s for s in shapes if s.name == piece.name)
        shape.rotation = L._multiply(turn((0, 0, 1), 0.5), shape.rotation)
        text = L.emit_layout(self.save(shapes, camera_for(self.layout)), BRIDGE)
        saved = next(p for p in L.parse_layout(text).pieces if p.name == piece.name)
        self.assertFalse(L.is_identity(saved.rotation))
        self.assertTrue(same_turn(saved.rotation, turn((0, 1, 0), 0.5)))
        # Read and written again, as after editing the file by hand, the small turn stays.
        self.assertEqual(L.emit_layout(L.parse_layout(text), BRIDGE), text)
        # Only a turn too small for the file's four places is written as none.
        self.assertFalse(L.is_identity(turn((1, 0, 0), 0.02)))
        self.assertTrue(L.is_identity(turn((1, 0, 0), 0.005)))

    def test_a_turn_is_written_only_for_a_turned_piece(self):
        flat = L.Piece("slab", (1, 0.1, 2), (3, 0.2, 4), "concrete")
        tilted = L.Piece("beam", (0, 3, -5), (0.2, 0.2, 6), "metal", (-0.5, 0.5, 0.5, 0.5))
        layout = L.Layout(self.layout.ground, [], [], [], [], [flat, tilted], self.layout.camera,
                          self.layout.lights)
        text = L.emit_layout(layout, BRIDGE)
        self.assertIn(
            '.piece("slab", at: [1, 0.1, 2], size: [3, 0.2, 4], surface: .concrete),', text)
        # Written as Swift's simd_quatf takes it, (x, y, z, w), and with w positive.
        self.assertIn("turn: [-0.5, -0.5, -0.5, 0.5]", text)
        read = L.parse_layout(text).pieces
        self.assertEqual(read[0].rotation, L.IDENTITY)
        self.assertEqual(read[1].rotation, (0.5, -0.5, -0.5, -0.5))

    def test_a_turn_written_by_hand_survives_a_save_without_edits(self):
        # Not unit length: the game normalises it, and Save leaves it as written.
        beam = L.Piece("beam", (0, 3, -5), (0.2, 0.2, 6), "metal", (0.7, 0, 0.7, 0))
        layout = L.Layout(self.layout.ground, self.layout.boxes, self.layout.landmarks,
                          self.layout.areas, self.layout.markers, [beam], self.layout.camera,
                          self.layout.lights)
        text = L.emit_layout(layout, BRIDGE)
        self.assertIn("turn: [0, 0.7, 0, 0.7]", text)
        previous = L.parse_layout(text)
        saved = L.layout_from_shapes(shapes_for(previous), BRIDGE, previous, camera_for(previous))
        self.assertEqual(L.emit_layout(saved, BRIDGE), text)

    def test_pieces_are_checked_like_boxes(self):
        for change, words in (
            (lambda shape: setattr(shape, "mirrored", True), "mirrored"),
            (lambda shape: setattr(shape, "cuboid", False), "no longer a box"),
            (lambda shape: setattr(shape, "surface", None), "no Lauder surface"),
            (lambda shape: setattr(shape, "size", (0.2, 0, 6)), "flat"),
            (lambda shape: setattr(shape, "name", shape.name + ".001"), "duplicate suffix"),
        ):
            with self.subTest(words=words):
                shapes = shapes_for(self.layout)
                change(next(shape for shape in shapes if shape.role == "piece"))
                self.check_refused(shapes, words)

    # MARK: - The game camera

    def test_the_camera_is_saved_from_its_rig(self):
        text = L.emit_layout(self.save(shapes_for(self.layout), L.CameraShape((0, -12, 8), 50)),
                             BRIDGE)
        self.assertIn("camera: .camera(offset: [0, 8, 12], fieldOfView: 50),", text)
        # Without the rig, Save keeps the camera that the file has.
        self.assertEqual(self.save(shapes_for(self.layout)).camera, self.layout.camera)
        self.check_refused(shapes_for(self.layout), "field of view",
                           L.CameraShape((0, -12, 8), 150))

    # MARK: - The game's details

    def check_parts(self, parts, expected):
        self.assertEqual([part[0] for part in parts], [part[0] for part in expected])
        for (_, centre, size, look), (_, want_centre, want_size, want_look) in zip(parts, expected):
            self.assertEqual(look, want_look)
            for got, want in zip(centre + size, want_centre + want_size):
                self.assertAlmostEqual(got, want, places=6)

    def test_vehicles_and_landmarks_get_the_games_details(self):
        car = L.Box("car", (0, 0.75, 0), (2, 1.5, 4.6), "vehicle")
        self.check_parts(L.details(car, "vehicle"), [
            ("body", (0, -0.3375, 0), (2, 0.825, 4.6), "vehicle"),
            ("cabin", (0, 0.4125, 0), (1.8, 0.675, 2.3), "glass"),
        ])
        truck = L.Box("truck", (0, 1.4, 0), (7, 2.8, 2.4), "vehicle")
        self.check_parts(L.details(truck, "vehicle"), [
            ("body", (0, 0, 0), (7, 2.8, 2.4), "vehicle"),
            ("windows", (0, 0.7, 0), (6.3, 0.5, 2.42), "glass"),
        ])
        sign = L.Landmark("sign", (0, 0, 0), (1, 2, 0.5))
        self.check_parts(L.details(sign, "landmark"), [
            ("band", (0, -0.54, 0), (0.85, 0.3, 0.515), "paint"),
        ])

    # MARK: - Lights

    def save_lights(self, lights):
        return L.emit_layout(
            self.save(shapes_for(self.layout), camera_for(self.layout), lights), BRIDGE)

    def test_a_sun_turned_brightened_or_recoloured_in_blender_is_saved(self):
        lights = lights_for(self.layout)
        key = next(light for light in lights if light.name == "sun-key")
        # Turned to shine from straight above, brighter and warmer.
        key.direction = (0.0, 0.0, 1.0)
        key.energy = single(6000 * L.SUN_STRENGTH_PER_LUX)
        key.color = singles(L._linear(1, 0.8, 0.6)[:3])
        text = self.save_lights(lights)
        # Written at the length that the file had, 9.9 m, so that the numbers stay readable.
        self.assertIn(
            '"sun-key", from: [0, 9.9, 0], color: [1, 0.8, 0.6], intensity: 6000, '
            "shadowDistance: 25),", text)
        self.assertIn(
            '.sun("sky-fill", from: [3, 5, -4], color: [0.67, 0.81, 0.85], intensity: 600),', text)

    def test_shadows_follow_each_suns_shadow_setting(self):
        lights = lights_for(self.layout)
        for light in lights:
            light.shadow = not light.shadow
        saved = {light.name: light for light in self.save(
            shapes_for(self.layout), camera_for(self.layout), lights).lights}
        self.assertIsNone(saved["sun-key"].shadow_distance)
        # A sun with no distance of its own gets the default.
        self.assertEqual(saved["sky-fill"].shadow_distance, L.DEFAULT_SHADOW_DISTANCE)

    def test_lights_beyond_the_visual_direction_or_the_game_are_refused(self):
        shapes, camera = shapes_for(self.layout), camera_for(self.layout)
        both = lights_for(self.layout)
        next(light for light in both if light.name == "sky-fill").shadow = True
        self.check_refused(shapes, "1 light with shadows, but 2 cast them", camera, both)
        moon = L.LightShape("moon", "SUN", (0, 0, 1), (1, 1, 1), 0.1, False)
        self.check_refused(shapes, "at most 2 lights", camera, lights_for(self.layout) + [moon])
        lamp = L.LightShape("lamp", "POINT", (0, 0, 1), (1, 1, 1), 100, False)
        self.check_refused(shapes, "only sun lights", camera, lights_for(self.layout)[:1] + [lamp])
        self.check_refused(shapes, "needs a light", camera, [])
        dark = lights_for(self.layout)
        dark[0].energy = 0
        self.check_refused(shapes, "needs some intensity", camera, dark)
        copy = lights_for(self.layout)
        copy[1].name = "sun-key.001"
        self.check_refused(shapes, "duplicate suffix", camera, copy)
        # Without the Lights collection, Save keeps the lights that the file has.
        self.assertEqual(self.save(shapes, camera).lights, self.layout.lights)


class PaletteTests(unittest.TestCase):
    def setUp(self):
        self.text = (ROOT / L.PALETTE_PATH).read_text()
        self.palette = L.parse_palette(self.text)

    def readings(self):
        """What Save would read from the Lauder materials after a Load, with no edits: the same
        finish in the material's own settings and in its viewport display."""
        shapes = []
        for name, finish in self.palette.items():
            reading = (singles(L._linear(*finish.color)[:3]), single(finish.roughness),
                       single(finish.metallic))
            shapes.append(L.MaterialShape(name, reading, reading))
        return shapes

    def test_the_palette_reads_and_writes_back_unchanged(self):
        self.assertEqual(L.emit_palette(self.palette), self.text)
        layout = L.parse_layout((ROOT / BRIDGE.path).read_text())
        used = {item.surface for item in [layout.ground] + layout.boxes + layout.pieces}
        self.assertLessEqual(used | set(L.GAME_LOOKS), set(self.palette))

    def test_materials_unchanged_in_blender_leave_the_palette_alone(self):
        self.assertEqual(L.emit_palette(L.palette_from_shapes(self.readings(), self.palette)),
                         self.text)
        # A surface whose material is gone keeps its finish.
        self.assertEqual(
            L.emit_palette(L.palette_from_shapes(self.readings()[1:], self.palette)), self.text)

    def test_a_material_changed_in_blender_is_saved(self):
        shapes = self.readings()
        steel = next(shape for shape in shapes if shape.name == "steel")
        # In the material's own settings, which Material Preview shows...
        steel.node = (singles(L._linear(0.5, 0.52, 0.55)[:3]), single(0.35), single(1.0))
        text = L.emit_palette(L.palette_from_shapes(shapes, self.palette))
        self.assertIn(
            ".steel: .finish(color: [0.5, 0.52, 0.55], roughness: 0.35, metallic: 1),", text)
        # ...or in its viewport display, which Solid shading shows.
        shapes = self.readings()
        river = next(shape for shape in shapes if shape.name == "river")
        river.viewport = (singles(L._linear(0.1, 0.25, 0.3)[:3]),) + river.viewport[1:]
        text = L.emit_palette(L.palette_from_shapes(shapes, self.palette))
        self.assertIn(".river: .finish(color: [0.1, 0.25, 0.3], roughness: 0.8),", text)
        others = [line for line in text.splitlines() if ".river:" not in line]
        self.assertEqual(others, [line for line in self.text.splitlines() if ".river:" not in line])

    def test_a_saved_material_change_survives_the_next_save(self):
        shapes = self.readings()
        steel = next(shape for shape in shapes if shape.name == "steel")
        steel.node = steel.node[:1] + (single(0.4),) + steel.node[2:]
        saved = L.palette_from_shapes(shapes, self.palette)
        self.assertEqual(saved["steel"].roughness, 0.4)
        # The viewport setting still says 0.9 until Save sets both settings to what it wrote, as
        # Load does. Left stale, it would look like a new edit and undo the change.
        steel.node = steel.viewport = L.finish_reading(saved["steel"])
        self.assertEqual(L.palette_from_shapes(shapes, saved), saved)

    def test_a_palette_the_game_cannot_use_is_refused(self):
        for broken, words in (
            (self.text.replace("roughness: 0.9),", "roughness: 1.5),", 1), "roughness should be"),
            (self.text.replace("[0.56, 0.57, 0.45]", "[0.56, 0.57]"), "expected 3 numbers"),
            (self.text.replace(".concrete: .finish(color:", ".concrete: .finish(colour:"),
             "could not be read"),
            (self.text.replace("    .glass:", "    // .glass:"), "needs glass"),
            (self.text.replace("    .river:", "    .steel:"), "two finishes for steel"),
            # An entry in another form, which the count of known entries alone would miss.
            (self.text.replace(".glass: .finish(", ".glass: Level.Finish("), "cannot read"),
            (self.text.replace("enum Surfaces {", "enum Surfaces {\n  static let spare = 1"),
             "cannot read"),
        ):
            with self.subTest(words=words):
                with self.assertRaises(L.LayoutError) as caught:
                    L.parse_palette(broken)
                self.assertIn(words, str(caught.exception))

    def test_every_box_and_piece_needs_one_of_the_palettes_surfaces(self):
        text = (ROOT / BRIDGE.path).read_text().replace("surface: .hazard", "surface: .marble", 1)
        with self.assertRaises(L.LayoutError) as caught:
            L.parse_layout(text, set(self.palette))
        self.assertIn("unknown surface, marble", str(caught.exception))


class ToolingTests(unittest.TestCase):
    """Save's guard against overwriting other changes, the working file, the party's figures and
    the extension's manifest."""

    def setUp(self):
        self.layout = (ROOT / BRIDGE.path).read_text()
        self.palette = (ROOT / L.PALETTE_PATH).read_text()

    def changes(self, layout=None, palette=None):
        return L.changes_since(self.layout, self.palette, layout or self.layout,
                               palette or self.palette)

    def test_files_unchanged_since_the_last_load_or_save_let_save_go_ahead(self):
        self.assertEqual(self.changes(), [])

    def test_changes_made_since_are_named(self):
        moved = self.layout.replace('.box("car-b4", at: [9.4, 0.75, 44]',
                                    '.box("car-b4", at: [9.4, 0.75, 42]')
        self.assertEqual(self.changes(moved), ["car-b4 changed"])
        edited = moved.replace('      .marker("attacker.stand", at: [7.6, 26.6]),\n', "").replace(
            "    pieces: [\n",
            '    pieces: [\n      .piece("crate", at: [1, 0.5, 2], size: [1, 1, 1], surface: .hazard),\n')
        edited = edited.replace("fieldOfView: 42)", "fieldOfView: 45)").replace(
            "intensity: 600)", "intensity: 900)")
        self.assertEqual(self.changes(edited), [
            "car-b4 changed", "attacker.stand removed", "the camera changed", "sky-fill changed",
            "crate added",
        ])
        recoloured = self.palette.replace("[0.42, 0.48, 0.5]", "[0.5, 0.5, 0.5]")
        self.assertEqual(self.changes(palette=recoloured), ["the steel surface changed"])
        self.assertEqual(self.changes(self.layout + "\n// A note.\n"),
                         ["the layout file's comments or spacing"])
        self.assertEqual(self.changes(self.layout.replace("lights: [", "lamps: [")),
                         ["the layout file, in a form the script cannot read"])

    def test_the_refusal_says_what_changed_and_how_to_go_on(self):
        message = str(L.FilesChanged(["car-b4 changed", "the steel surface changed"]))
        for words in ("car-b4 changed, the steel surface changed", "Load", "Save Anyway"):
            self.assertIn(words, message)
        self.assertIn("and more", str(L.FilesChanged([f"box-{n} changed" for n in range(9)])))

    def test_the_working_file_lives_in_local_where_git_ignores_it(self):
        self.assertEqual(L.working_file(Path("/repo"), BRIDGE),
                         Path("/repo/.local/blender/brooklyn-bridge.blend"))
        self.assertIn(".local/", (ROOT / ".gitignore").read_text().splitlines())

    def test_the_script_finds_the_repository_it_was_installed_from(self):
        self.assertEqual(Path(L._guess_repository()), ROOT)
        self.assertTrue((ROOT / L.PLAY_SCRIPT).is_file())

    def test_each_figure_stands_on_the_floor_as_the_game_draws_it(self):
        for member, (_, width) in L.PARTY.items():
            parts = {name: (centre, size) for name, centre, size, _ in L.figure(member)}
            bottom = min(centre[1] - size[1] / 2 for centre, size in parts.values())
            self.assertAlmostEqual(bottom, 0, places=6)
            self.assertEqual(parts["body"][1][0], width)
            # The head's top, and the front mark on the side facing Manhattan, at -z.
            head, head_size = parts["head"]
            self.assertAlmostEqual(head[1] + head_size[1] / 2, L.FIGURE_CENTRE + 0.73, places=6)
            self.assertLess(parts["front"][0][2], 0)

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
