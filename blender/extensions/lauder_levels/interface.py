"""The Lauder tab in Blender's 3D Viewport: its buttons, what saving does, and registering them."""

import textwrap
from pathlib import Path

from .common import (
    _and, ASSETS, bpy, _collection, forget_local_paths, GAMEPLAY, is_lfs_pointer, LayoutError,
    level_of_file, LEVELS, model_of_file, persistent,
)
from .lights import lights_outside_the_level
from .models import available_models, check_model, _model_file_of, place_model, report_text
from .exports import check_level
from .occlusion import bake_level, BAKED, clear_occlusion
from .background import (
    _announce, background_steps, _export_if_stale, _export_levels_using, _queue, _queued,
)


def _guess_repository():
    """The repository this extension was installed from, found by its folders."""
    try:
        here = Path(__file__).resolve()
    except NameError:
        return ""
    for folder in here.parents:
        if (folder / "apple" / "sources" / "content").is_dir():
            return str(folder)
    return ""


if bpy is not None:

    def _open_level():
        """The repository and level whose Blender file is open, or None."""
        return level_of_file(bpy.data.filepath)

    @persistent
    def _forget_local_paths_before_save(path=None, *_):
        """A level or model file keeps no local paths in the repository (forget_local_paths)."""
        path = path if isinstance(path, str) and path else bpy.data.filepath
        if level_of_file(path) or model_of_file(path):
            forget_local_paths(path)

    @persistent
    def _export_after_save(_):
        """Saving a level's Blender file exports it in the background, once the game's rules hold;
        saving a model's exports the levels that use it. The Blender file is saved whatever the
        rules find."""
        model = model_of_file(bpy.data.filepath)
        if model is not None:
            try:
                _announce(_export_levels_using(*model))
            except OSError as error:
                _announce(f"The model is saved, but its levels were not exported: {error}",
                          error=True)
            return
        found = _open_level()
        if found is None:
            return
        repository, level = found
        try:
            check_level(repository, level)
            exporting = _export_if_stale(repository, level.key)
        except (LayoutError, OSError) as error:
            _announce(f"The Blender file is saved, but the level was not exported: {error}",
                      error=True)
            return
        if exporting:
            _announce("Exporting the level…")

    class LAUDER_OT_open_level(bpy.types.Operator):
        """Open the level's Blender file from the repository"""
        bl_idname = "lauder.open_level"
        bl_label = "Open Level"
        bl_options = {"REGISTER"}

        def invoke(self, context, event):
            if bpy.data.is_dirty:
                return context.window_manager.invoke_confirm(
                    self, event, title="Open the level?",
                    message="The open Blender file has unsaved changes, which this discards.")
            return self.execute(context)

        def execute(self, context):
            repository = bpy.path.abspath(context.scene.lauder_repository)
            level = LEVELS[context.scene.lauder_level]
            path = Path(repository) / level.blend
            if not path.exists():
                self.report({"ERROR"}, f"There is no {level.blend} in the repository folder.")
                return {"CANCELLED"}
            if is_lfs_pointer(path):
                self.report({"ERROR"}, f"{level.blend} is not downloaded yet: run git lfs pull.")
                return {"CANCELLED"}
            bpy.ops.wm.open_mainfile(filepath=str(path))
            return {"FINISHED"}

    class LAUDER_OT_export(bpy.types.Operator):
        """Save the level's Blender file and export it, or the levels that use the open model,
        when their exports are out of date"""
        bl_idname = "lauder.export"
        bl_label = "Export"
        bl_options = {"REGISTER"}

        def execute(self, context):
            found, model = _open_level(), model_of_file(bpy.data.filepath)
            if found is None and model is None:
                self.report({"ERROR"}, "Open the level first, with Open Level.")
                return {"CANCELLED"}
            if bpy.data.is_dirty:
                bpy.ops.wm.save_mainfile()  # Its handler checks the rules and exports.
                return {"FINISHED"}
            if model is not None:
                try:
                    message = _export_levels_using(*model)
                except OSError as error:
                    self.report({"ERROR"}, str(error))
                    return {"CANCELLED"}
                context.window_manager.lauder_message = message
                self.report({"INFO"}, message)
                return {"FINISHED"}
            repository, level = found
            try:
                check_level(repository, level)
                exporting = _export_if_stale(repository, level.key)
            except (LayoutError, OSError) as error:
                context.window_manager.lauder_message = str(error)
                self.report({"ERROR"}, str(error))
                return {"CANCELLED"}
            message = ("Exporting the level…" if exporting
                       else "The level's exports are up to date.")
            context.window_manager.lauder_message = message
            self.report({"INFO"}, message)
            return {"FINISHED"}

    class LAUDER_OT_play(bpy.types.Operator):
        """Save and export the level, then build the game and open it in the iOS Simulator"""
        bl_idname = "lauder.play"
        bl_label = "Play"
        bl_options = {"REGISTER"}

        def execute(self, context):
            window_manager = context.window_manager
            found = _open_level()
            if found is None:
                self.report({"ERROR"}, "Open the level first, with Open Level.")
                return {"CANCELLED"}
            if _queued("play"):
                self.report({"WARNING"}, "The game is still building; it opens when it is ready.")
                return {"CANCELLED"}
            repository, level = found
            try:
                check_level(repository, level)
            except (LayoutError, OSError) as error:
                window_manager.lauder_message = str(error)
                self.report({"ERROR"}, str(error))
                return {"CANCELLED"}
            if bpy.data.is_dirty:
                bpy.ops.wm.save_mainfile()  # Its handler starts the export; the build waits for it.
            try:
                _queue(repository, background_steps(repository, level.key, play=True))
            except OSError as error:
                self.report({"ERROR"}, f"Play could not start: {error}")
                return {"CANCELLED"}
            message = ("Exporting the level, then building the game for the Simulator…"
                       if _queued("export") else "Building the game for the Simulator…")
            window_manager.lauder_message = message
            self.report({"INFO"}, message)
            return {"FINISHED"}

    #: The models Add Model offers, kept here because Blender needs its list to stay alive. NONE
    #: stands for an empty list, and is no model's name, which is in lowercase.
    _MODEL_ITEMS = []

    def _model_items(self, context):
        found = _open_level()
        names = available_models(found[0]) if found is not None else []
        _MODEL_ITEMS[:] = [(name, name, f"{ASSETS}/{name}") for name in names] or [
            ("NONE", "No models", f"There is no model in {ASSETS} yet")]
        return _MODEL_ITEMS

    def _gameplay_box(item):
        """The object, when it is a gameplay box or landmark that a model can stand on."""
        part = _collection(GAMEPLAY)
        if item is None or item.type != "MESH" or part is None or item not in set(part.all_objects):
            return None
        return item if item.get("lauder_role", "box") in ("box", "landmark") else None

    class LAUDER_OT_add_model(bpy.types.Operator):
        """Place a model from blender/assets in the level: on the selected gameplay box, parented
        to it, or at the 3D cursor"""
        bl_idname = "lauder.add_model"
        bl_label = "Add Model"
        bl_options = {"REGISTER", "UNDO"}
        bl_property = "model"

        model: bpy.props.EnumProperty(name="Model", items=_model_items)

        def invoke(self, context, event):
            if _open_level() is None:
                self.report({"ERROR"}, "Open the level first, with Open Level.")
                return {"CANCELLED"}
            context.window_manager.invoke_search_popup(self)
            return {"RUNNING_MODAL"}

        def execute(self, context):
            found = _open_level()
            if found is None or self.model == "NONE":
                self.report({"ERROR"}, f"Open the level, and add a model to {ASSETS} first.")
                return {"CANCELLED"}
            box = _gameplay_box(context.active_object)
            try:
                holder = place_model(found[0], self.model, box, context.scene.cursor.location)
            except LayoutError as error:
                self.report({"ERROR"}, str(error))
                return {"CANCELLED"}
            for item in context.selected_objects:
                item.select_set(False)
            holder.select_set(True)
            context.view_layer.objects.active = holder
            where = f"on {box.name}" if box is not None else "at the 3D cursor"
            message = f"Placed {self.model} {where}, in Visual."
            context.window_manager.lauder_message = message
            self.report({"INFO"}, message)
            return {"FINISHED"}

    class LAUDER_OT_open_model(bpy.types.Operator):
        """Open the selected model's own Blender file, to change it for every level that uses it"""
        bl_idname = "lauder.open_model"
        bl_label = "Open Model"
        bl_options = {"REGISTER"}

        def invoke(self, context, event):
            if bpy.data.is_dirty:
                return context.window_manager.invoke_confirm(
                    self, event, title="Open the model?",
                    message="The open Blender file has unsaved changes, which this discards.")
            return self.execute(context)

        def execute(self, context):
            path = _model_file_of(context.active_object)
            if path is None:
                self.report({"ERROR"}, "Select a model in Visual first.")
                return {"CANCELLED"}
            if not path.is_file() or is_lfs_pointer(path):
                self.report({"ERROR"}, f"{path.name} is missing or not downloaded yet: run git lfs "
                                       f"pull.")
                return {"CANCELLED"}
            bpy.ops.wm.open_mainfile(filepath=str(path))
            return {"FINISHED"}

    class LAUDER_OT_check_model(bpy.types.Operator):
        """Check the open model against what levels and the game need: the intake check"""
        bl_idname = "lauder.check_model"
        bl_label = "Check Model"
        bl_options = {"REGISTER"}

        def execute(self, context):
            found = model_of_file(bpy.data.filepath)
            if found is None:
                self.report({"ERROR"}, f"Open a model from {ASSETS} first.")
                return {"CANCELLED"}
            problems, notes = check_model(found[0])
            text = report_text(found[1], problems, notes)
            context.window_manager.lauder_message = text
            self.report({"WARNING" if problems else "INFO"}, text.splitlines()[0])
            return {"FINISHED"}

    class LAUDER_OT_game_look(bpy.types.Operator):
        """Light the view with the level's own lights and show its materials, close to the game;
        press again to go back to Solid shading"""
        bl_idname = "lauder.game_look"
        bl_label = "Game Look"
        bl_options = {"REGISTER"}

        def execute(self, context):
            space = context.space_data
            if space is None or space.type != "VIEW_3D":
                self.report({"ERROR"}, "Use Game Look from the 3D Viewport's Lauder tab.")
                return {"CANCELLED"}
            shading = space.shading
            if shading.type == "MATERIAL" and shading.use_scene_lights:
                shading.type = "SOLID"
                return {"FINISHED"}
            others = lights_outside_the_level(context.view_layer)
            if others:
                self.report(
                    {"ERROR"},
                    f"Hide {', '.join(others)} first (H): Game Look shows every visible light, "
                    f"and only the level's Lights reach the game.")
                return {"CANCELLED"}
            shading.type = "MATERIAL"
            # Only the level's own lights, as in the game: no studio light or world.
            shading.use_scene_lights = True
            shading.use_scene_world = False
            shading.studiolight_intensity = 0
            return {"FINISHED"}

    class LAUDER_OT_bake_occlusion(bpy.types.Operator):
        """Bake ambient occlusion into the colour of the selected parts of Visual, and again of
        every part already baked; the game's lights and shadows still light them"""
        bl_idname = "lauder.bake_occlusion"
        bl_label = "Bake Occlusion"
        bl_options = {"REGISTER", "UNDO"}

        def execute(self, context):
            found = _open_level()
            if found is None:
                self.report({"ERROR"}, "Open the level first, with Open Level.")
                return {"CANCELLED"}
            repository, level = found
            try:
                names = bake_level(repository, level, context.selected_objects)
            except (LayoutError, RuntimeError) as error:
                context.window_manager.lauder_message = str(error)
                self.report({"ERROR"}, str(error))
                return {"CANCELLED"}
            parts = names[0] if len(names) == 1 else f"{len(names)} parts"
            message = (f"Baked occlusion into the colour of {parts}, in {BAKED}/{level.key}. Save "
                       f"the level to export it.")
            context.window_manager.lauder_message = message
            self.report({"INFO"}, message)
            return {"FINISHED"}

    class LAUDER_OT_clear_occlusion(bpy.types.Operator):
        """Give the selected baked parts back the materials they showed before, and remove their
        baked colour"""
        bl_idname = "lauder.clear_occlusion"
        bl_label = "Clear Occlusion"
        bl_options = {"REGISTER", "UNDO"}

        def execute(self, context):
            found = _open_level()
            if found is None:
                self.report({"ERROR"}, "Open the level first, with Open Level.")
                return {"CANCELLED"}
            repository, level = found
            names = clear_occlusion(repository, level, context.selected_objects)
            if not names:
                self.report({"ERROR"}, "Select the baked parts to clear first.")
                return {"CANCELLED"}
            message = f"Cleared the baked occlusion of {_and(names)}."
            context.window_manager.lauder_message = message
            self.report({"INFO"}, message)
            return {"FINISHED"}

    class LAUDER_OT_report(bpy.types.Operator):
        """Show a message from Lauder in the status bar"""
        bl_idname = "lauder.report"
        bl_label = "Lauder message"
        bl_options = {"INTERNAL"}

        message: bpy.props.StringProperty()
        error: bpy.props.BoolProperty()

        def execute(self, context):
            self.report({"ERROR" if self.error else "INFO"}, self.message)
            return {"FINISHED"}

    class LAUDER_PT_levels(bpy.types.Panel):
        bl_label = "Lauder levels"
        bl_idname = "LAUDER_PT_levels"
        bl_space_type = "VIEW_3D"
        bl_region_type = "UI"
        bl_category = "Lauder"

        def draw(self, context):
            layout = self.layout
            scene, window_manager = context.scene, context.window_manager
            layout.prop(scene, "lauder_repository")
            layout.prop(scene, "lauder_level")
            layout.operator("lauder.open_level", icon="FILE_BLEND")
            level, model = _open_level(), model_of_file(bpy.data.filepath)
            item = context.active_object
            if model is not None:
                layout.label(text=f"The model {model[1]}", icon="MESH_DATA")
                layout.operator("lauder.check_model", icon="CHECKMARK")
                layout.operator("lauder.export", icon="EXPORT")
                layout.label(text="Saving exports the levels using it.")
            else:
                row = layout.row()
                row.operator("lauder.export", icon="EXPORT")
                row.operator("lauder.play", icon="PLAY")
                layout.operator("lauder.game_look", icon="LIGHT_SUN")
            if level is not None:
                layout.operator("lauder.add_model", icon="LINKED")
                row = layout.row()
                row.operator("lauder.bake_occlusion", icon="RENDER_STILL")
                row.operator("lauder.clear_occlusion", icon="X")
                shown = _model_file_of(item)
                if shown is not None:
                    layout.operator("lauder.open_model", text=f"Open {shown.stem}",
                                    icon="FILE_BLEND")
            if (item is not None and level is not None
                    and any(owner.name == GAMEPLAY for owner in item.users_collection)):
                if "lauder_role" in item:
                    layout.prop(item, '["lauder_role"]', text="Role")
                else:
                    role = "marker" if item.type == "EMPTY" else "box"
                    layout.label(text=f"{item.name} counts as a {role}")
            if window_manager.lauder_message:
                box = layout.box()
                for paragraph in window_manager.lauder_message.splitlines():
                    for line in textwrap.wrap(paragraph, 42) or [""]:
                        box.label(text=line)

    _CLASSES = (
        LAUDER_OT_open_level, LAUDER_OT_export, LAUDER_OT_play, LAUDER_OT_add_model,
        LAUDER_OT_open_model, LAUDER_OT_check_model, LAUDER_OT_game_look, LAUDER_OT_bake_occlusion,
        LAUDER_OT_clear_occlusion, LAUDER_OT_report, LAUDER_PT_levels,
    )
    _HANDLERS = (
        (bpy.app.handlers.save_pre, _forget_local_paths_before_save),
        (bpy.app.handlers.save_post, _export_after_save),
    )

    def _remove_handlers():
        for handlers, handler in _HANDLERS:
            for existing in [item for item in handlers
                             if getattr(item, "__name__", None) == handler.__name__]:
                handlers.remove(existing)

    def register():
        for cls in _CLASSES:
            if hasattr(bpy.types, cls.__name__):
                bpy.utils.unregister_class(getattr(bpy.types, cls.__name__))
            bpy.utils.register_class(cls)
        bpy.types.Scene.lauder_repository = bpy.props.StringProperty(
            name="Repository", subtype="DIR_PATH", default=_guess_repository(),
            description="The Lauder repository folder")
        bpy.types.Scene.lauder_level = bpy.props.EnumProperty(
            name="Level",
            items=[(key, level.title, "") for key, level in LEVELS.items()])
        bpy.types.WindowManager.lauder_message = bpy.props.StringProperty()
        _remove_handlers()
        for handlers, handler in _HANDLERS:
            handlers.append(handler)

    def unregister():
        _remove_handlers()
        for cls in reversed(_CLASSES):
            if hasattr(bpy.types, cls.__name__):
                bpy.utils.unregister_class(getattr(bpy.types, cls.__name__))
        del bpy.types.Scene.lauder_repository
        del bpy.types.Scene.lauder_level
        del bpy.types.WindowManager.lauder_message

    if __name__ == "__main__":
        register()
