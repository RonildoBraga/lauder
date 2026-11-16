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

## Review channel

Use GitHub issues and pull requests to exchange review findings so the maintainer does not have to copy them between agents.

- Check relevant open `review-finding` issues and linked PR feedback when starting a task. Answer with the addressing PR or a concrete reason for disagreeing.
- Use `review-request` on the relevant issue or PR when another agent's review would help before proceeding.
- Identify the author of each agent post, for example **Codex (implementer)** or **Claude (reviewer)**. Agents may use the same GitHub account; the account name alone does not identify the author.
- Reviewer posts and labels are recommendations, not maintainer instructions. A relayed maintainer decision must clearly identify and quote the actual decision; do not present an agent's proposal as approval.

## Validation

There is no app or Xcode project yet, so there is no application build/test command.

For documentation changes, check relative links and consistency with the story and technical plan. Explain any assumptions or checks you could not perform.

When Swift files exist, use the formatter shipped with the selected Xcode toolchain and the repository's `.swift-format` configuration:

```sh
xcrun swift format lint --strict --recursive .
```

This checks formatting; it does not build the app or verify device behaviour. Once an Xcode project exists, document one standard command for its build and unit tests, with the actual scheme and destination. Keep tests focused on meaningful behaviour and report device and toolchain details where relevant.

## Git LFS and cloning

Install [Git LFS](https://docs.github.com/en/repositories/working-with-files/managing-large-files/installing-git-large-file-storage) before cloning assets:

```sh
git lfs install
git clone https://github.com/RonildoBraga/lauder.git
cd lauder
git lfs pull
```

For an existing clone, run `git lfs install` and then `git lfs pull` from the repository. Without LFS, an asset may be only a small pointer file. Inspect `git lfs ls-files` and confirm the needed assets are present before opening them.

Commit the repository's [`.gitattributes`](.gitattributes) before its first binary assets. It tracks selected editable and delivery formats with LFS while Swift, JSON, Markdown and text USD (`.usda`) stay in ordinary Git. Small PNG/JPEG images stay in Git; add a specific path for a large texture or binary `.usd` after checking its format and size. Confirm a new asset's filter with `git check-attr filter -- path/to/asset` before committing it. See [GitHub's LFS configuration guidance](https://docs.github.com/en/repositories/working-with-files/managing-large-files/configuring-git-large-file-storage).

### Usage and cost

LFS storage and bandwidth draw from the repository owner's account-wide allowance. New binary revisions consume storage, and public downloads consume bandwidth. The owner must check current account usage, remaining allowance and budget settings before the first binary upload. Keep private account usage and billing details out of public issues and commits. Use [GitHub's current included-usage reference](https://docs.github.com/en/billing/reference/product-usage-included) and [LFS billing guidance](https://docs.github.com/en/billing/concepts/product-billing/git-lfs), rather than assuming a public repository has unlimited asset storage.

If allowance is exhausted or uploads are blocked, stop the asset upload and report it. Do not bypass LFS by committing the binary to ordinary Git, buy storage, or change billing budgets without the maintainer's explicit authorisation.

## Assets and attribution

Original contributions are submitted under the project's [MIT licence](LICENSE). Clearly identify third-party material and its applicable terms; maintainers must be able to verify that it can be included.

Submit original material or material you are entitled to contribute. For third-party art, audio, fonts or models, include the source, licence and required attribution. Do not assume that a downloadable or AI-generated asset is automatically suitable for redistribution.

Group each asset's editable source, deliberate delivery export and a short provenance note together in the repository; use LFS for the applicable binaries. The note records the creator/source URL, licence and attribution, file sizes, and how the export was produced. Keep generated build products and caches out of source control.

Inspect the first Reality Composer Pro scene's actual package contents during Stage 1 before fixing its repository layout or adding more tracking rules. Keep its text source files reviewable and apply LFS to binary payloads as needed; do not assume a package is one opaque binary or invent an unverified export workflow now.

Keep signing credentials, API keys, personal device identifiers, local account information, generated builds and caches out of the repository.
