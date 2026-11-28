"""Work in the background: exporting, and Play's build, each in a process of its own, after saving
or pressing a button."""

import subprocess
import sys
from pathlib import Path

from .common import (
    _and, bpy, EXPORT_MODEL_SCRIPT, EXPORT_SCRIPT, LEVELS, model_file, PLAY_SCRIPT, SPAWNED,
)
from .exports import levels_using, stale_exports, stale_model_export


#: Work running in the background, one step after another, so that Blender stays usable: the
#: steps still to run; the running step, its process, log and log's path; the repository the work
#: is for; and how often it exported again because a level's files changed while it ran.
_JOB = {"steps": [], "step": None, "process": None, "log": None, "path": None,
        "repository": None, "refreshes": 0}
#: How often one run of background work exports again while a level's files keep changing, so
#: that it cannot go on for ever.
MOST_REFRESHES = 3


def _export_step(repository, key):
    """The background step that exports the level in a Blender of its own: (name, command, log,
    level)."""
    blender = bpy.app.binary_path if bpy is not None else "blender"
    return ("export", [
        blender, "-b", "--factory-startup", "--python-exit-code", "1",
        "--python", str(Path(repository) / EXPORT_SCRIPT), "--", key,
    ], "export.log", key)


def _export_model_step(repository, name):
    """The background step that exports a model that the game creates (SPAWNED) in a Blender of
    its own: (name, command, log, model)."""
    blender = bpy.app.binary_path if bpy is not None else "blender"
    return ("export model", [
        blender, "-b", "--factory-startup", "--python-exit-code", "1",
        "--python", str(Path(repository) / EXPORT_MODEL_SCRIPT), "--", name,
    ], "export-model.log", name)


def background_steps(repository, key, play):
    """The background steps that saving (play=False) or Play needs: exporting the level when its
    exports no longer match its files, then, for Play, exporting each model that the game creates
    whose scene file no longer matches, and building and opening the game. Each is (name, command,
    log, level or model)."""
    steps = [_export_step(repository, key)] if stale_exports(repository, key) is not None else []
    if play:
        steps += [_export_model_step(repository, name) for name in SPAWNED
                  if stale_model_export(repository, name) is not None]
        steps.append(("play", [sys.executable, "-I", str(Path(repository) / PLAY_SCRIPT)],
                      "play.log", key))
    return steps


#: The background steps that export, a level or a model that the game creates.
EXPORTS = ("export", "export model")


def queue_steps(running, waiting, steps):
    """The steps to add after the background step running, if any, and those waiting. An export
    of the same level or model already running or waiting stands in for a new one, which could
    only race it for the same files: when it finishes, the exports' freshness is checked again
    (refresh_needed)."""
    exporting = {(step[0], step[3]) for step in ([running] if running else []) + list(waiting)
                 if step[0] in EXPORTS}
    return [step for step in steps if step[0] not in EXPORTS or (step[0], step[3]) not in exporting]


def _export_kind(step):
    """The export that brings a finished step's files up to date again: its model's for a model's
    export, and otherwise its level's."""
    return "export model" if step[0] == "export model" else "export"


def refresh_needed(finished, waiting, stale, refreshes):
    """Whether to export the finished step's level or model again before going on, once the step
    has finished well: when its files changed while it ran, such as by a second save, and its
    export is not next anyway."""
    upcoming = waiting[0] if waiting else None
    exporting_next = (upcoming is not None and upcoming[0] == _export_kind(finished)
                      and upcoming[3] == finished[3])
    return stale and not exporting_next and refreshes < MOST_REFRESHES


def _step_stale(repository, step):
    """Whether the files of a finished step's level or model changed since they were exported."""
    if step[0] == "export model":
        return stale_model_export(repository, step[3]) is not None
    return stale_exports(repository, step[3]) is not None


def _again(repository, step):
    """The step that exports a finished step's level or model again (_export_kind)."""
    if step[0] == "export model":
        return _export_model_step(repository, step[3])
    return _export_step(repository, step[3])


def _finished(step):
    """What a background step says when it finishes well."""
    if step[0] == "export":
        return f"Exported {LEVELS[step[3]].title}. The preserved reference export is up to date."
    if step[0] == "export model":
        return f"Exported the {step[3]} model. The preserved reference export is up to date."
    return "The game is running in the Simulator."


def _start_job(repository, steps):
    """Run the steps in the background, in order, stopping at the first that fails."""
    _JOB.update(steps=list(steps), repository=repository, refreshes=0)
    _next_step()
    # Persistent, so that opening another Blender file keeps watching.
    bpy.app.timers.register(_watch_job, first_interval=1.0, persistent=True)


def _next_step():
    step = _JOB["steps"].pop(0)
    path = Path(_JOB["repository"]) / ".local/play" / step[2]
    path.parent.mkdir(parents=True, exist_ok=True)
    log = path.open("w")
    process = subprocess.Popen(step[1], cwd=_JOB["repository"], stdout=log,
                               stderr=subprocess.STDOUT)
    _JOB.update(step=step, process=process, log=log, path=path)


def _job_running():
    """Whether background work is still running. Work that stopped while nothing watched it is
    finished off here, so that saving and Play are never stuck."""
    if _JOB["process"] is None:
        return False
    if _JOB["process"].poll() is None:
        return True
    _watch_job()
    return _JOB["process"] is not None


def _watch_job():
    process = _JOB["process"]
    if process is None:
        return None
    if process.poll() is None:
        return 0.5
    _JOB["log"].close()
    _JOB["process"] = None
    step, path = _JOB["step"], _JOB["path"]
    if process.returncode == 0:
        try:
            stale = _step_stale(_JOB["repository"], step)
        except (OSError, ValueError):
            stale = False
        if refresh_needed(step, _JOB["steps"], stale, _JOB["refreshes"]):
            _JOB["steps"].insert(0, _again(_JOB["repository"], step))
            _JOB["refreshes"] += 1
        if _JOB["steps"]:
            try:
                _next_step()
            except OSError as error:
                _JOB["steps"] = []
                _announce(f"The next step could not start: {error}", error=True)
                return None
            return 0.5
        _announce(_finished(step))
        return None
    _JOB["steps"] = []
    lines = [line.strip() for line in path.read_text().splitlines() if line.strip()]
    # The export says why it refused in one line; otherwise the log's last lines tell.
    detail = next((line for line in reversed(lines)
                   if line.startswith(("The level was not", "The model was not"))),
                  " ".join(lines[-3:]))
    if step[0] == "export":
        what = f"Exporting {LEVELS[step[3]].title}"
    elif step[0] == "export model":
        what = f"Exporting the {step[3]} model"
    else:
        what = "Play"
    _announce(f"{what} failed{': ' + detail if detail else '.'} The log is "
              f".local/play/{path.name}.", error=True)
    return None


def _queued(name):
    """Whether a background step of this name is running or waiting to run."""
    if not _job_running():
        return False
    return _JOB["step"][0] == name or any(step[0] == name for step in _JOB["steps"])


def _queue(repository, steps):
    """Run the steps in the background, after the work already running, if any (queue_steps)."""
    if _job_running():
        _JOB["steps"].extend(queue_steps(_JOB["step"], _JOB["steps"], steps))
    elif steps:
        _start_job(repository, steps)


def _export_if_stale(repository, key):
    """Export the level in the background when its exports no longer match its files, after the
    work already running. Returns whether an export is running or waiting."""
    _queue(repository, background_steps(repository, key, play=False))
    return _queued("export")


def _export_levels_using(repository, name):
    """Export, in the background, the model's own scene file when the game creates it (SPAWNED),
    and each level whose last export used the model, when they no longer match their files.
    Returns the message to show."""
    keys = levels_using(repository, model_file(name))
    own = ""
    if name in SPAWNED:
        if stale_model_export(repository, name) is not None:
            _queue(repository, [_export_model_step(repository, name)])
            own = f"Exporting the {name} model for the game…"
        else:
            own = f"The {name} model's scene file is up to date."
        if not keys:
            return own
    if not keys:
        return f"No level uses {name} yet: place it in one with Add Model."
    exporting = [LEVELS[key].title for key in keys if stale_exports(repository, key) is not None]
    for key in keys:
        _export_if_stale(repository, key)
    if not exporting:
        return f"{own} The exports of the levels that use {name} are up to date.".strip()
    verb = "uses" if len(exporting) == 1 else "use"
    return f"{own} Exporting {_and(exporting)}, which {verb} {name}…".strip()


def _announce(message, error=False):
    """Tell the person from a handler or a timer, which cannot report: in the Lauder tab, and in
    Blender's status bar."""
    bpy.context.window_manager.lauder_message = message
    print(f"Lauder: {message}")

    def report():
        try:
            bpy.ops.lauder.report(message=message, error=error)
        except (AttributeError, RuntimeError):
            pass

    bpy.app.timers.register(report, first_interval=0.1)
