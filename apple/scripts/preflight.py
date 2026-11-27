"""What the Apple scripts share before they build: the app's downloaded assets, an iPhone
simulator to run on, and output with private device identifiers masked. scripts/check,
apple/scripts/playtest and apple/scripts/play use it."""

import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
#: The Git LFS files the app and its tests need: the Brooklyn Bridge's scene file, the models the
#: game creates and its combat sounds (ADR 0008).
ASSETS = (
    "apple/sources/content/BrooklynBridge.usdz",
    "apple/sources/content/models/hostile.usdz",
    "apple/sources/content/models/laura.usdz",
    "apple/sources/content/models/miki.usdz",
    "apple/sources/content/models/scout-drone.usdz",
    "apple/sources/content/models/spider-bot-heavy.usdz",
    "apple/sources/content/models/tom.usdz",
    "apple/sources/content/sounds/assault-rifle.wav",
    "apple/sources/content/sounds/dome-break.wav",
    "apple/sources/content/sounds/dome-down.wav",
    "apple/sources/content/sounds/dome-low.wav",
    "apple/sources/content/sounds/dome-ready.wav",
    "apple/sources/content/sounds/dome-up.wav",
    "apple/sources/content/sounds/empty-click.wav",
    "apple/sources/content/sounds/guard-warning.wav",
    "apple/sources/content/sounds/long-rifle.wav",
    "apple/sources/content/sounds/minigun-spin.wav",
    "apple/sources/content/sounds/minigun.wav",
    "apple/sources/content/sounds/rifle.wav",
    "apple/sources/content/sounds/shotgun.wav",
    "apple/sources/content/sounds/strike-block.wav",
    "apple/sources/content/sounds/strike-body.wav",
    "apple/sources/content/sounds/sword-swing.wav",
)
PRIVATE_IDENTIFIER = re.compile(
    r"\b(?:[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}|[0-9a-f]{8}-[0-9a-f]{16})\b",
    re.IGNORECASE,
)
_RUNTIME = re.compile(r"com\.apple\.CoreSimulator\.SimRuntime\.iOS-(\d+)-(\d+)(?:-(\d+))?")
_LFS_POINTER = b"version https://git-lfs.github.com/spec/v1"


def mask(text):
    """The text with device and session identifiers masked."""
    return PRIVATE_IDENTIFIER.sub("<device-id>", text)


def check_assets():
    """Stop unless every asset is downloaded: neither missing nor a Git LFS pointer."""
    problems = []
    for name in ASSETS:
        path = ROOT / name
        if not path.is_file():
            problems.append(f"{name} (missing)")
            continue
        with path.open("rb") as stream:
            if stream.read(128).startswith(_LFS_POINTER):
                problems.append(f"{name} (Git LFS pointer)")
    if problems:
        raise SystemExit(
            "Git LFS assets are not downloaded:\n"
            + "\n".join(f"- {problem}" for problem in problems)
            + "\nInstall Git LFS, then run 'git lfs install' and 'git lfs pull' from the "
            "repository root.")


def iphone_simulator():
    """The available iPhone simulator to use: a booted one first, then the newest iOS 27 or later
    runtime, then by name."""
    result = subprocess.run(["xcrun", "simctl", "list", "devices", "available", "--json"],
                            capture_output=True, text=True)
    if result.returncode:
        raise SystemExit(f"Unable to list available iPhone simulators.\n{mask(result.stderr)}")
    candidates = []
    for runtime, devices in json.loads(result.stdout)["devices"].items():
        match = _RUNTIME.fullmatch(runtime)
        if not match:
            continue
        version = tuple(int(value or 0) for value in match.groups())
        if version < (27, 0, 0):
            continue
        for device in devices:
            if device.get("isAvailable") and device["name"].startswith("iPhone"):
                rank = (device["state"] != "Booted", tuple(-value for value in version),
                        device["name"], device["udid"])
                candidates.append((rank, device))
    if not candidates:
        raise SystemExit("Install an iOS 27 or later iPhone simulator runtime in Xcode first.")
    return min(candidates, key=lambda candidate: candidate[0])[1]
