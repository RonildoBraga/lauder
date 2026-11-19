# ADR 0001 — Swift and RealityKit for the iPhone game

**Status:** Accepted\
**Date:** 16 November 2026

## Context

Lauder is Apple-only, with the iPhone first, an elevated perspective camera and a small party exploring a ruined world. The priorities are a lean codebase, maintainability and a workflow that one maintainer can keep up. Reaching other platforms is not a requirement. The [architecture](../architecture.md) records the deployment target and who owns what.

## Decision

Use Swift and RealityKit for gameplay and the 3D world, SwiftUI for the interface, and Xcode to build, sign, test and profile the iPhone app.

The project is **code-first**. The game composes its scenes in Swift: it loads the scene files that Blender exports for each level and for each model the game creates ([ADR 0002](0002-blender-source-of-truth.md)), and builds what plays from typed Swift data. Reality Composer Pro is not used.

The world is fully virtual, with a perspective camera, and the game runs no AR session. RealityKit's rendering, lights, shadows and image-based light suit the scope without the project owning a rendering engine. Apple's [native game sample](https://developer.apple.com/documentation/realitykit/bringing-your-scenekit-projects-to-realitykit) shows camera, character, touch-input and SwiftUI integration.

## Alternatives considered

| Alternative | Why it was not selected |
|---|---|
| Godot | A credible compact game engine, but its separate scripting, editor and export workflow is not needed for cross-platform support in an Apple-only project. |
| Unity | A credible 3D mobile engine with extensive game tooling, but its editor and package workflow adds a larger toolchain than the game needs. |
| SpriteKit | Suited to 2D games; reproducing this 3D world with sprites would add art and depth-management work. |
| SceneKit | Apple deprecated it and recommends RealityKit for new projects. |
| Direct Metal | Would make the project own rendering pipelines and GPU resource handling without a gameplay need. |

These are scope and workflow judgements, not performance benchmarks. References: [Godot iOS workflow](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html), [Unity iOS workflow](https://docs.unity.com/en-us/engine/6000.3/manual/platform-specific/iphone/ios-building-and-delivering/build-process), [SpriteKit](https://developer.apple.com/documentation/spritekit), [SceneKit deprecation](https://developer.apple.com/videos/play/wwdc2025/288/), [Metal responsibilities](https://developer.apple.com/documentation/metal/setting-up-a-command-structure).

## Costs

- The project is tied to Apple platforms and Apple's toolchain. A release elsewhere would need substantial adaptation.
- How the game reads and feels still needs checking in the running app and on the phone: readable routes, framing, comfortable controls and sustained performance. Tests cannot establish those.
- RealityKit's APIs must fit the deployment target, iOS 27.
