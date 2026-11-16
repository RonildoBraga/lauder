# Lauder

An open-source, Apple-only survival exploration game about a homecoming through the ruins of a futuristic world.

Miki is travelling with her father to reunite with her daughter, Nina. Exploration and purposeful salvage help them find a viable way across a world devastated by war and infrastructure failure. The full cause of the collapse remains uncertain.

## Project status

**Stage 1 is merged. Stage 2 is in progress: a walkable graybox, collision, camera follow and controls.**

The technical direction is Swift, RealityKit and SwiftUI, targeting the current stable iOS generation, with iPhone first. Scenes are built in Swift, with USDZ assets loaded directly. Controls are PS5 DualSense or Xbox: left stick to move, Cross/A to act, Options/Menu to pause/resume, with no touch controls or clickable screen actions. The salvage-and-repair gameplay loop has not been implemented.

## Start here

- [Story bible](story/story-bible.md): agreed foundations, characters, world and working timeline.
- [Chapter One — A Place to Meet](story/chapter-01.md): the current scene and dialogue draft.
- [Architecture](docs/architecture.md): responsibilities, state, saving and the Apple toolchain.
- [First playable prototype](docs/prototype-plan.md): a small Relay House salvage-and-repair loop with staged acceptance criteria.
- [Stage 1 evidence](docs/stage-1.md): toolchain, device checks, session outcomes and remaining work.
- [Stage 2 evidence](docs/stage-2.md): controller decisions, simulator iteration and physical-device checks.

Names, ages and details marked as proposals remain open for discussion. Miki is widowed; Nina is her daughter; Lara is a trusted friend; Tomas is the working name for Miki's father.

## First prototype

One short round trip: talk to Tomas, explore the depot, recover a regulator, repair the transmitter and contact Lara and Nina. Start with a small graybox environment and one representative animated character. The initial performance target is 60 fps on an iPhone 13 Pro Max.

## Contribute

People and AI-assisted contributors are welcome. Useful contributions now include story feedback, prototype-scope review, level-layout proposals, technical research and improvements to the documentation.

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a focused pull request. Coding agents should also read [AGENTS.md](AGENTS.md). Use issues for proposals and questions; maintainers review changes before merging. The project plans alone are not an assignment to start implementation.

With Xcode 27.2 selected and LFS assets downloaded, run `./scripts/check` for formatting, build and unit tests. Open `Lauder.xcodeproj` and the shared `Lauder` scheme for the route prototype. Use Simulator for everyday iteration, with iPhone 13 Pro Max checks at milestones before merging playable features. The app keeps the screen awake while active, including when paused. See [validation and local signing](CONTRIBUTING.md#validation) for the testing workflow.

## Licence

[MIT](LICENSE) applies to the repository's original code, story and documentation unless a file or directory explicitly states another licence. Third-party material retains its own licence and attribution notices.
