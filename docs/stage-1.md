# Stage 1 — device and asset workflow

## Exit criterion

Run a small scene and one representative rigged character with idle and walk animation on the baseline iPhone. Verify the import, composition and app workflow before producing further content. See the [prototype plan](prototype-plan.md#1-establish-the-device-and-asset-path) and [three-session stop criterion](decisions/0001-engine.md#stage-1-stop-criterion).

## Session 1 — 16 November 2026

**Status:** The device/rig/idle-walk criterion has been demonstrated with direct USDZ loading. The latest diagnostic-panel layout check and PR review remain open.

The maintainer [confirmed the code-first workflow](https://github.com/RonildoBraga/lauder/issues/9#issuecomment-6907224023): Swift scene construction and direct USDZ loading. The three-session stop criterion is unchanged.

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

Personal account information, signing identifiers and device identifiers are intentionally excluded.

### Work and limits

- Preparation PR #7 was merged after Claude confirmed that its findings were addressed. The maintainer explicitly authorised Stage 1.
- Installed stable Xcode 27.2 after the maintainer signed in to Apple Developer. It was selected for these commands through `DEVELOPER_DIR`; the existing global Xcode selection was preserved.
- Created one iPhone app target, one hosted Swift Testing target, a fixed virtual camera and diagnostic Idle/Walk buttons. No movement, mission, inventory or persistence implementation is included.
- Created an original 18-joint skinned stand-in, separate idle/walk USDZ exports, editable USDA layers and a standard-library Python generator. [Provenance and regeneration](../Lauder/Content/Character/README.md)
- `./scripts/check` passed with Xcode 27.2 on an iPhone 17 simulator running iOS 27.0: formatting, build and the one hosted Swift Testing import test. Result bundle and detailed logs are retained locally outside Git.
- Built a signed iPhone app with Xcode 27.2, installed and launched it on the baseline phone. A device screenshot showed the character, floor, landmark and loaded 18-joint rig. The maintainer then confirmed that both Walk and Idle visibly work when selected.
- Moved the diagnostic panel to the upper-left after that observation so it does not cover the character's legs. The updated build and simulator import test pass, and the update is installed on the phone. Its automatic relaunch was blocked when the phone locked; that layout change has not been visually rechecked on the device.
- Fixed the initial import-test failure: RealityKit adds aggregate animation resources alongside the authored joint clip. The loader now validates the unique authored joint animation, its duration and the actual compatible skinned rigs.

### Remaining Stage 1 review

- Visually recheck the latest upper-left diagnostic-panel placement on the baseline phone; its installation and build/test checks have passed.
- Review PR #8 before merging or starting another stage. Approval of the authoring direction does not authorise either action.

### Deferred work and limits

- Record interruption/resume and repeated-run checks when they are exercised. They have not been established by the import test or the maintainer's animation confirmation.
- Gameplay, movement, controls and measured 60 fps belong to later prototype stages. No sustained performance, thermal or save-reliability claim is made here.

Simulator success, animation metadata and a connected phone alone do not satisfy the device criterion. This session includes the physical scene observation and the maintainer's idle/walk confirmation. Keep recording actual attempts and results; the [three-session stop criterion](decisions/0001-engine.md#stage-1-stop-criterion) still governs an unproven character/device path.
