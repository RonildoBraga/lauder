# Stage 1 — device and asset workflow

**Current status:** Stage 1 is complete and merged in [PR #8](https://github.com/RonildoBraga/lauder/pull/8). The session below records the original diagnostic preview and its handoff; subsequent movement and controller work is recorded in [Stage 2](stage-2.md).

## Exit criterion

Run a small scene and one representative rigged character with idle and walk animation on the baseline iPhone. Verify the import, composition and app workflow before producing further content. See the [prototype plan](prototype-plan.md#1-establish-the-device-and-asset-path) and [three-session stop criterion](decisions/0001-engine.md#stage-1-stop-criterion).

## Session 1 — 16 November 2026

**Status at this session's handoff:** The device/rig/idle-walk criterion and latest diagnostic-panel layout had been confirmed on the baseline iPhone. PR #8 was awaiting merge at that point.

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
- Created an original 18-joint skinned stand-in, separate idle/walk USDZ exports, editable USDA layers and a standard-library Python generator. [Provenance and regeneration](../sources/content/character/README.md)
- `./scripts/check` passed with Xcode 27.2 on an iPhone 17 simulator running iOS 27.0: formatting, build and the one hosted Swift Testing import test. Result bundle and detailed logs are retained locally outside Git.
- Built a signed iPhone app with Xcode 27.2, installed and launched it on the baseline phone. A device screenshot showed the character, floor, landmark and loaded 18-joint rig. The maintainer then confirmed that both Walk and Idle visibly work when selected.
- Moved the diagnostic panel to the upper-left after that observation so it does not cover the character's legs. The updated build and simulator import test pass, and the update is installed on the phone. Its automatic relaunch was initially blocked when the phone locked. The maintainer subsequently reopened the preview and confirmed that the panel is readable, both animations work and the character's legs are unobstructed.
- Fixed the initial import-test failure: RealityKit adds aggregate animation resources alongside the authored joint clip. The loader now validates the unique authored joint animation, its duration and the actual compatible skinned rigs.

### Review and handoff

- Track review findings and responses in [PR #8](https://github.com/RonildoBraga/lauder/pull/8). Claude's [review at `ebb0e9f`](https://github.com/RonildoBraga/lauder/pull/8#issuecomment-6907436791) found no blockers and reproduced the simulator build/import test; follow-up changes need review as well.
- Source-group evaluation, separating shared character loading and additional rejection-path tests are tracked for Stage 2 in [issue #10](https://github.com/RonildoBraga/lauder/issues/10), as recommended in that review.
- Merging PR #8 or starting another stage remains the maintainer's decision. The confirmed device checks do not authorise either action.

### Deferred work and limits

- Record interruption/resume and repeated-run checks when they are exercised. They have not been established by the import test or the maintainer's animation confirmation.
- Gameplay, movement, controls and measured 60 fps belong to later prototype stages. No sustained performance, thermal or save-reliability claim is made here.

Simulator success, animation metadata and a connected phone alone do not satisfy the device criterion. This session includes the physical scene observation and the maintainer's idle/walk confirmation. Keep recording actual attempts and results; the [three-session stop criterion](decisions/0001-engine.md#stage-1-stop-criterion) still governs an unproven character/device path.
