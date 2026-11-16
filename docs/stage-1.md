# Stage 1 — device and asset workflow

## Exit criterion

Run a small scene and one representative rigged character with idle and walk animation on the baseline iPhone. Verify the import, composition and app workflow before producing further content. See the [prototype plan](prototype-plan.md#1-establish-the-device-and-asset-path) and [three-session stop criterion](decisions/0001-engine.md#stage-1-stop-criterion).

## Session 1 — 16 November 2026

**Status:** In progress; Stage 1 has not passed its exit criterion.

### Verified preflight

| Item | Observed |
|---|---|
| Mac | Apple silicon, macOS 27.2.1 (26B131) |
| Xcode used for passing checks | 27.2 (27B52), installed alongside the existing 27.1 |
| iPhone SDK used for passing checks | 27.2 |
| Swift | Apple Swift 6.4 |
| Baseline phone | iPhone 13 Pro Max, iOS 27.2.1 (24B156) |
| Device connection | Paired, wired, connected; Developer Mode enabled |
| Code signing | An Apple Development identity is available locally |
| Reality Composer Pro | 3.1 (80.40.7.0.1), installed from Apple Developer |

Personal account information, signing identifiers and device identifiers are intentionally excluded.

### Work and limits

- Preparation PR #7 was merged after Claude confirmed that its findings were addressed. The maintainer explicitly authorised Stage 1.
- Installed the stable tools after the maintainer signed in to Apple Developer. Xcode 27.2 was selected for these commands through `DEVELOPER_DIR`; the existing global Xcode selection was preserved.
- Created one iPhone app target, one hosted Swift Testing target, a fixed virtual camera and diagnostic Idle/Walk buttons. No movement, mission, inventory or persistence implementation is included.
- Created an original 18-joint skinned stand-in, separate idle/walk USDZ exports, editable USDA layers and a standard-library Python generator. [Provenance and regeneration](../Lauder/Content/Character/README.md)
- `./scripts/check` passed with Xcode 27.2 on an iPhone 17 simulator running iOS 27.0: formatting, build and the one hosted Swift Testing import test. Result bundle and detailed logs are retained locally outside Git.
- Built a signed iPhone app with Xcode 27.2, installed and launched it on the baseline phone. A device screenshot showed the character, floor, landmark and loaded 18-joint rig. The maintainer then confirmed that both Walk and Idle visibly work when selected.
- Moved the diagnostic panel to the upper-left after that observation so it does not cover the character's legs. The updated build and simulator import test pass, and the update is installed on the phone. Its automatic relaunch was blocked when the phone locked; that layout change has not been visually rechecked on the device.
- Fixed the initial import-test failure: RealityKit adds aggregate animation resources alongside the authored joint clip. The loader now validates the unique authored joint animation, its duration and the actual compatible skinned rigs.
- The preview currently consumes USDZ directly. Reality Composer Pro 3.1 import and rig export were inspected; its initial `.reality` export omitted playable clips. The app does not depend on that unverified animation export path.
- The actual authoring package is `.realitycomposerpro`, with text scene/import definitions and binary buffers. A new project also copies an Apple factory `core.lib`. The experimental package and static export are preserved under the ignored `.local/authoring/Content/` directory; they are excluded from the public contribution. No claim is made that the factory library can safely be omitted from a portable Composer project.

### Remaining evidence

- Complete a reproducible Composer animation-library/export workflow before adopting `.reality` runtime assets or publishing that authoring package.
- Record interruption/resume and repeated-run checks when they are exercised. They have not been established by the import test or the maintainer's animation confirmation.
- Gameplay, movement, controls and measured 60 fps belong to later prototype stages. No sustained performance, thermal or save-reliability claim is made here.

Simulator success, animation metadata and a connected phone alone do not satisfy the exit criterion. Record blockers and attempts in this log; stop and reassess if the representative character is not running after three focused sessions.
