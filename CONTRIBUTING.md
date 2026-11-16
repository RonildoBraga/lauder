# Contributing to Lauder

People and AI-assisted contributors are welcome. The project is currently planning its story and first Swift/RealityKit prototype.

## Before working

Read the [README](README.md) and the documents relevant to the change:
- [Story bible](story/story-bible.md) and [Chapter One](story/chapter-01.md) for narrative work.
- [Architecture](docs/architecture.md) and [prototype plan](docs/prototype-plan.md) for technical work.
- [AGENTS.md](AGENTS.md) when using a coding agent.

Distinguish agreed foundations from working proposals. For changes to the story foundations, engine, architecture or prototype scope, explain the proposal in an issue before investing in a large rewrite, unless an existing issue or maintainer assignment already describes that work.

An explicit maintainer assignment or instruction authorises that task. Avoid asking again for permission already supplied by that assignment. Implementation should begin from a task that explicitly starts the prototype, rather than from the existence of its plan.

## Pull requests

Use a branch or fork and open a small, focused pull request. Describe the problem, the resulting change and the validation performed. Keep related documents consistent and avoid unrelated cleanup.

Maintainers review and merge contributions. Be respectful and specific in feedback. AI-assisted work has the same expectations for correctness and provenance as any other contribution; the person submitting it remains responsible for reviewing it.

## Validation

There is no app or Xcode project yet, so there is no application build/test command.

For documentation changes, check relative links and consistency with the story and technical plan. Explain any assumptions or checks you could not perform. Once implementation begins, add meaningful build/test automation with the app and report actual device and toolchain details only where they are relevant.

## Assets and attribution

Original contributions are submitted under the project's [MIT licence](LICENSE). Clearly identify third-party material and its applicable terms; maintainers must be able to verify that it can be included.

Submit original material or material you are entitled to contribute. For third-party art, audio, fonts or models, include the source, licence and required attribution. Do not assume that a downloadable or AI-generated asset is automatically suitable for redistribution.

Keep signing credentials, API keys, personal device identifiers, local account information, generated builds and caches out of the repository.
