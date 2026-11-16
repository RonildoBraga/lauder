# Stage 2 project groups

**Decision and verification:** 16 November 2026, following [issue #10](https://github.com/RonildoBraga/lauder/issues/10).

Use Xcode folder-synchronised roots for `Sources/` (app target `Lauder`) and `tests/` (test target `LauderTests`). The folder names do not change the target or module names. New Swift files in those folders no longer require individual project-file references or build-phase entries. This uses Xcode's built-in support without adding a project generator or dependency. Apple describes the reduced project-file changes in [Managing files and folders](https://developer.apple.com/documentation/xcode/managing-files-and-folders-in-your-xcode-project) and [Xcode 16 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-16-release-notes).

The project uses `PBXFileSystemSynchronizedRootGroup`, target `fileSystemSynchronizedGroups`, and project object version 77. These were checked against the installed Xcode 27.2 project model and validated with Xcode's command-line tools. The existing flattened `Content/Character` group prevented a direct UI conversion because its path spans two directory levels; the final roots follow the actual directory structure.

## Target membership

The app-target paths below are relative to `Sources/`.

- Exclude `Content/Character/README.md` from the app target.
- Exclude `App/Info.plist` from copied resources. Both app configurations use it as the typed input to the generated bundle plist, including the declared Extended Gamepad support.
- Treat `Content/Character/source` as an explicit opaque folder and exclude it from the app target. A membership exception for the directory alone did not exclude its descendants in the scratch check; both settings are deliberate.
- Discover Swift sources and the two runtime USDZ resources automatically. Sources and Resources build phases have no manually enumerated files.

Review target membership when adding other non-runtime files beneath either root. The present app resources remain `Idle.usdz` and `Walk.usdz`.

## Verification

An isolated copy of the merged Stage 1 source and actual LFS payloads was checked with **Xcode 27.2 (27B52), SDK 27.2**:

- `xcodebuild -list -json` recognised both targets and the shared Lauder scheme.
- `xcodebuild -scheme Lauder -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build-for-testing` succeeded for arm64 and x86_64 with isolated build output.
- A newly added app Swift file and a newly added test Swift file both appeared in compilation. The test file referenced the new app type, proving inclusion in their respective targets without project-file edits.
- A deliberate `#error` Swift file and a text resource inside the excluded editable-source folder were neither compiled nor copied.
- Exactly two resource-copy tasks ran: `Idle.usdz` and `Walk.usdz`. Their bundled SHA-256 hashes matched the input payloads. The app contained no README, USDA source, editable-source folder or sentinel resource.
- The final project passed `plutil -lint` and `git diff --check`.

The temporary probes are not repository files. This was a build-for-testing membership check, not a test run or validation of the integrated Stage 2 gameplay. The normal validation command and physical-device checks remain separate.
