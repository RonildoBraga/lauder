# Simulator PosterBoard startup crash

## Observed failure — 17 November 2026

With Xcode 27.2 and the iOS 27.0 runtime, the original iPhone 17 Simulator repeatedly displayed **PosterBoard quit unexpectedly**. The 23 inspected reports from that device shared a `SIGTRAP` in Apple's `PRPosterDescriptor` initializer, while its ambient-role poster store was loading.

The Simulator log supplied the assertion **“descriptors must have descriptorIdentifiers”**, referring to Apple's clock-poster extension. The failure occurred during wallpaper/poster initialization, including before Lauder launched. This is consistent with invalid persisted poster state in that Simulator; the original trigger for that state is unknown. No Apple-confirmed diagnosis of this exact assertion was found.

## Recovery

Created **iPhone 17 — Lauder**, using the same hardware profile and iOS 27.0 runtime. The original iPhone 17 device retains its apps and data and is shut down. Use the dedicated Lauder device for everyday testing.

Three standalone boot/reboot cycles completed with Home rendering and display power off/on. No new PosterBoard report or matching descriptor assertion occurred on the new device during those checks. Display power cycling does not establish lock/unlock behaviour.

`./scripts/check` then passed on the dedicated device with Xcode 27.2, including formatting, build and Swift Testing. Lauder runtime `b592e22` launched and rendered, followed by a 20-second observation with no new PosterBoard crash or matching assertion. Both PosterBoard and Lauder remained running. Device Hub was left on the new device in landscape with touch controls visible and keyboard capture off.

These bounded checks establish a working replacement testing environment; they do not establish why the original descriptor became invalid or guarantee that Apple's runtime cannot fail again.

Raw reports, assertion extracts and diagnostic receipts remain private. The [touch validation record](touch-controls.md#validation) separately identifies the tested app revision and physical-phone observations.
