# ADR-0001: Use Swift and RealityKit for the iPhone prototype

**Status:** Accepted\
**Date:** 16 November 2026\
**Decider:** Project owner

## Context

Lauder is Apple-only, with iPhone first, an elevated perspective camera and a small exploration-and-salvage prototype. The priorities are a lean codebase, maintainability and a practical workflow for a solo maintainer. Cross-platform reach is not a requirement. The [architecture](../architecture.md) records the deployment target and responsibility boundaries.

## Decision

Use Swift and RealityKit for gameplay and the 3D world, SwiftUI for the interface, and Xcode to build, sign, test and profile the iPhone app. The project is **code-first**, as [confirmed by the maintainer](https://github.com/RonildoBraga/lauder/issues/9#issuecomment-6907224023).

Assemble scenes in Swift. For planned Stages 2–3, use one small typed Swift layout definition for spawn, obstacles and interaction placements with stable IDs. GameWorld constructs the scene and validates bindings; mission rules remain separate.

Load the USDZ character assets directly and construct the named idle/walk animation library in Swift. Apple supports [programmatic animation-library construction](https://developer.apple.com/documentation/realitykit/animationlibrarycomponent). The [asset pipeline](../../Lauder/Content/Character/README.md) records editable sources, regeneration and provenance; [Stage 1 evidence](../stage-1.md) records the performed import and device checks.

RealityKit supports a fully virtual world with a perspective camera; this game does not need an AR session. Its existing rendering, animation, collision and character-controller capabilities suit the proposed scope without owning a rendering engine. Apple's [native game sample](https://developer.apple.com/documentation/realitykit/bringing-your-scenekit-projects-to-realitykit) demonstrates camera, character, touch-input and SwiftUI integration.

Reality Composer Pro is excluded from the project by maintainer decision.

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
- Code-based placement still needs inspection in the running app for readable routes, framing, occlusion and comfortable controls. Source review and asset-import tests cannot establish those qualities.
- Individual RealityKit runtime APIs must fit the agreed deployment target.
- The USD asset workflow must preserve the representative character's rig, idle/walk animation, materials and scale. Verify that pipeline before producing content. [Apple asset guidance](https://developer.apple.com/documentation/usd/creating-usd-files-for-apple-devices)
- Framework choice does not prove control usability, sustained performance or reliable saves. Those remain physical-device exit criteria in the [prototype plan](../prototype-plan.md).

## Stage 1 stop criterion

If a rigged character with idle and walk animation is not running in a scene on the baseline iPhone after **three focused work sessions**, stop, document the blocker and the attempts made, and reassess with the maintainer before building anything else. Record each session's attempt and outcome so the limit is visible. This is a review checkpoint, not automatic permission to switch engines or expand scope.

The three-session limit is the [recorded maintainer decision](https://github.com/RonildoBraga/lauder/issues/2#issuecomment-6905646208). This decision record and the prototype plan do not themselves authorise starting Stage 1.
