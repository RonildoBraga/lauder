# ADR-0001: Use Swift and RealityKit for the iPhone prototype

**Status:** Accepted\
**Date:** 16 November 2026\
**Decider:** Project owner

## Context

Lauder is Apple-only, with iPhone first, an elevated perspective camera and a small exploration-and-salvage prototype. The priorities are a lean codebase, maintainability and a practical workflow for a solo maintainer. Cross-platform reach is not a requirement. The [architecture](../architecture.md) records the deployment target and responsibility boundaries.

## Decision

Use Swift and RealityKit for gameplay and the 3D world, SwiftUI for the interface, and Reality Composer Pro for scene and asset authoring. Use Xcode to build, sign, test and profile the iPhone app.

RealityKit supports a fully virtual world with a perspective camera; this game does not need an AR session. Its existing rendering, animation, collision and character-controller capabilities suit the proposed scope without owning a rendering engine. Apple's [native game sample](https://developer.apple.com/documentation/realitykit/bringing-your-scenekit-projects-to-realitykit) demonstrates camera, character, touch-input and SwiftUI integration.

Reality Composer Pro 3 provides scene composition and simulation, animation graphs, visual scripting, navigation meshes and behavior trees. Use only the features the prototype needs, and keep mission rules in Swift. [Current authoring tools](https://developer.apple.com/documentation/realitycomposerpro)

## Alternatives considered

| Alternative | Why it was not selected |
|---|---|
| Godot | A credible compact game engine, but its separate scripting/editor/export workflow is not needed to obtain cross-platform support for this Apple-only project. Reconsider if the native workflow fails the prototype's requirements. |
| Unity | A credible 3D mobile engine with extensive game tooling, but its editor/package workflow adds a larger toolchain than this prototype currently needs. |
| SpriteKit | Appropriate for 2D games; reproducing this 3D world with sprites would add art and depth-management work. |
| SceneKit | Apple deprecated it and recommends RealityKit for new projects. |
| Direct Metal | Would make the project own rendering pipelines and GPU resource handling without a demonstrated gameplay requirement. |

These are scope and workflow judgments, not comparative performance benchmarks. References: [Godot iOS workflow](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html), [Unity iOS workflow](https://docs.unity.com/en-us/engine/6000.3/manual/platform-specific/iphone/ios-building-and-delivering/build-process), [SpriteKit](https://developer.apple.com/documentation/spritekit), [SceneKit deprecation](https://developer.apple.com/videos/play/wwdc2025/288/), [Metal responsibilities](https://developer.apple.com/documentation/metal/setting-up-a-command-structure).

## Costs and validation

- The project is tied to Apple platforms and Apple's toolchain. A later non-Apple release would require substantial adaptation.
- Current authoring features have toolchain and OS requirements. Reality Composer Pro 3 requires an Apple-silicon Mac with macOS 26.5 or later; its Xcode integration requires Xcode 27 or later. Individual runtime APIs must fit the agreed deployment target. [Release requirements](https://developer.apple.com/documentation/realitycomposerpro/reality-composer-pro-3-release-notes), [Xcode integration](https://developer.apple.com/documentation/realitycomposerpro/realitycomposerpro-essentials-linkingxcodeproject)
- The USD asset workflow must preserve the representative character's rig, idle/walk animation, materials and scale. Verify that pipeline before producing content. [Apple asset guidance](https://developer.apple.com/documentation/usd/creating-usd-files-for-apple-devices)
- Framework choice does not prove touch usability, sustained performance or reliable saves. Those remain physical-device exit criteria in the [prototype plan](../prototype-plan.md).

## Stage 1 stop criterion

If a rigged character with idle and walk animation is not running in a scene on the baseline iPhone after **three focused work sessions**, stop, document the blocker and the attempts made, and reassess with the maintainer before building anything else. Record each session's attempt and outcome so the limit is visible. This is a review checkpoint, not automatic permission to switch engines or expand scope.

The three-session limit is the [recorded maintainer decision](https://github.com/RonildoBraga/lauder/issues/2#issuecomment-6905646208). This decision record and the prototype plan do not themselves authorise starting Stage 1.
