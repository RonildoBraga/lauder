"""Lauder's retained level/model authoring extension (ADR 0002).

The graybox duel uses Swift primitives. The registered bridge sources and their standalone
models now export to blender/reference-exports, outside the app's sources and resource bundle.
They remain available for reuse and provenance, without restoring bridge gameplay to the app.

A level's Visual collection supplies meshes/materials; Gameplay supplies ground, collision,
areas and markers; Lights and Camera supply its lighting/view; Preview is never exported.
Models live in blender/assets with their own collection, real scale, textures and licence.
Layout conversion, model intake, export fingerprints and baking remain tested by scripts/check.

Saving/exporting refreshes preserved outputs. Play builds the current app through
apple/scripts/play; it does not make those historical exports playable in the duel. Restore a
named bridge checkpoint in a separate worktree to play that prototype.

Modules keep their existing ownership: common, lights, layouts, looks, models, robot_geometry,
exports, occlusion, shadows, background and interface. Plain-function tests need no Blender;
actual .blend editing/export requires Blender and its own authoring assignment.
"""

from . import (
    common, lights, layouts, looks, models, robot_geometry, exports, occlusion, shadows, background, interface,
)

# The package keeps every name that its modules define, so that the scripts and the tests
# can use lauder_levels.<name> wherever it lives.
for _module in (common, lights, layouts, looks, models, robot_geometry, exports, occlusion, shadows, background,
                interface):
    globals().update({name: value for name, value in vars(_module).items()
                      if not (name.startswith("__") and name.endswith("__"))})
del _module


def register():
    interface.register()


def unregister():
    interface.unregister()
