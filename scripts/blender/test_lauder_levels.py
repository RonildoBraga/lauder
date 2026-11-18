#!/usr/bin/env python3
"""Tests for lauder_levels.py that need no Blender: reading, writing and checking layouts.

./scripts/check runs them. Blender's own part, building and reading objects, is checked by
loading and saving a level in Blender (CONTRIBUTING).
"""

from pathlib import Path
import struct
import sys
import unittest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.dont_write_bytecode = True

import lauder_levels as L  # noqa: E402

ROOT = HERE.parent.parent
BRIDGE = L.LEVELS["brooklyn-bridge"]


def single(value):
    """A number as Blender stores it, in single precision."""
    return struct.unpack("f", struct.pack("f", value))[0]


def shapes_for(layout):
    """What Save would read from Blender after a Load of this layout, with no edits."""
    shapes = []

    def block(name, role, centre, size, surface=None):
        cx, cy, cz = L.to_blender(centre)
        sx, sy, sz = L.size_to_blender(size)
        low = tuple(single(value) for value in (cx - sx / 2, cy - sy / 2, cz - sz / 2))
        high = tuple(single(value) for value in (cx + sx / 2, cy + sy / 2, cz + sz / 2))
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
    return shapes


class BridgeLayoutTests(unittest.TestCase):
    def setUp(self):
        self.text = (ROOT / BRIDGE.path).read_text()
        self.layout = L.parse_layout(self.text)

    def test_the_bridge_file_reads_and_writes_back_unchanged(self):
        self.assertEqual(L.emit_layout(self.layout, BRIDGE), self.text)
        self.assertEqual(self.layout.ground.name, "deck")
        self.assertIn("car-b4", [box.name for box in self.layout.boxes])

    def test_a_load_and_save_with_no_edits_changes_nothing(self):
        saved = L.layout_from_shapes(shapes_for(self.layout), BRIDGE, self.layout)
        self.assertEqual(L.emit_layout(saved, BRIDGE), self.text)

    def test_a_quarter_turn_swaps_the_footprint(self):
        shapes = shapes_for(self.layout)
        car = next(shape for shape in shapes if shape.name == "car-a1")
        (x0, y0, z0), (x1, y1, z1) = car.minimum, car.maximum
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        hx, hy = (x1 - x0) / 2, (y1 - y0) / 2
        car.minimum, car.maximum = (cx - hy, cy - hx, z0), (cx + hy, cy + hx, z1)
        saved = L.layout_from_shapes(shapes, BRIDGE, self.layout)
        turned = next(box for box in saved.boxes if box.name == "car-a1")
        self.assertAlmostEqual(turned.size[0], 4.6, places=4)
        self.assertAlmostEqual(turned.size[2], 2, places=4)

    def test_a_moved_car_is_saved_where_it_was_put(self):
        shapes = shapes_for(self.layout)
        car = next(shape for shape in shapes if shape.name == "car-b3")
        car.minimum = (car.minimum[0] + 1, car.minimum[1] - 2, car.minimum[2])
        car.maximum = (car.maximum[0] + 1, car.maximum[1] - 2, car.maximum[2])
        text = L.emit_layout(L.layout_from_shapes(shapes, BRIDGE, self.layout), BRIDGE)
        self.assertIn('.box("car-b3", at: [5.6, 0.75, 50], size: [2, 1.5, 4.6]', text)

    def check_refused(self, shapes, words):
        with self.assertRaises(L.LayoutError) as caught:
            L.layout_from_shapes(shapes, BRIDGE, self.layout)
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
        saved = L.layout_from_shapes(shapes, BRIDGE, self.layout)
        names = [box.name for box in saved.boxes]
        self.assertNotIn("car-e2", names)
        self.assertEqual(names[-1], "car-z1")
        self.assertEqual(saved.boxes[-1].position, (2, 0.75, -4.3))

    def test_an_entry_the_script_cannot_read_stops_the_load(self):
        broken = self.text.replace('.box("car-a1", at:', '.box(name: "car-a1", at:')
        with self.assertRaises(L.LayoutError):
            L.parse_layout(broken)
        short = self.text.replace("at: [9.6, 0.75, 100]", "at: [9.6, 100]")
        with self.assertRaises(L.LayoutError):
            L.parse_layout(short)

    def test_long_entries_wrap_as_swift_format_does(self):
        box = L.Box("a-very-long-name-for-a-box-on-the-bridge", (-123.456, 0.75, 101.234),
                    (2.345, 1.5, 4.678), "vehicle")
        layout = L.Layout(self.layout.ground, [box], [], [], [])
        text = L.emit_layout(layout, BRIDGE)
        self.assertTrue(all(len(line) <= 100 for line in text.splitlines()))
        self.assertEqual(L.parse_layout(text).boxes[0], box)
        self.assertIn("    landmarks: [],", text)
        self.assertIn("    markers: [])", text)


if __name__ == "__main__":
    result = unittest.main(exit=False, verbosity=1).result
    sys.exit(0 if result.wasSuccessful() else 1)
