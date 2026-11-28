# Bridge prototype checkpoints

**Recorded:** 28 November 2026. **Agent:** Codex, researcher and repository auditor.

The maintainer asked to keep this repository and mark the old project so it remains a reference while an Eitr-inspired direction is researched. These annotated tags preserve distinct sources; they do not approve a replacement, merge an experiment or publish a new build.

| Reference | Source | Meaning |
| --- | --- | --- |
| [milestone/bridge-main-2026-11-28](https://github.com/RonildoBraga/lauder/tree/milestone/bridge-main-2026-11-28) | 0f4eb819ae2b794f713ca67b2211bc53766a28ee | Merged bridge prototype, including Claude's fixes in PRs #229–#233. |
| [milestone/two-leader-pilot-2026-11-28](https://github.com/RonildoBraga/lauder/tree/milestone/two-leader-pilot-2026-11-28) | 99131065a388cf3cf655b816ec60697d15691b61 | Unmerged [PR #228](https://github.com/RonildoBraga/lauder/pull/228), implementing the two-leader/support experiment. It does not contain the subsequent main cleanup. |
| Delivered TestFlight 0.1.0 (46) | e025cc6c938ea72fbd8f1143c86a3ef46c6b5ece | Last delivery recorded in the [prototype plan](../bridge-prototype-plan.md#build-46-maintenance-testflight-preview). Neither checkpoint is a claim that a new binary has shipped. |

Main and the pilot diverge. Neither tag is the combined tree of both branches. Both tags preserve authored source, story/design documents, art provenance, Blender sources and runtime resources tracked at their respective commits. The tags are named references, not access-controlled immutable backups; do not move them when new work lands.

## Verification and limits

- The original main worktree was clean when its source was captured. No application source or asset was edited by this preservation task.
- Git LFS object verification passed for both checkpoint commits. Current main lists 40 downloaded LFS payloads. Both annotated tags were pushed together, and remote tag readback confirmed the exact commit targets above. This verifies published references and local payloads, not an independent offline asset backup.
- PR #228's [CI 213](https://github.com/RonildoBraga/lauder/actions/runs/46095812456) succeeded at its exact head. Its PR and [issue #225](https://github.com/RonildoBraga/lauder/issues/225) retain source-bound local/rendered results, review history and remaining phone/merge gates. No new gameplay tests were performed for this documentation-only task.
- Main's [PR #233](https://github.com/RonildoBraga/lauder/pull/233) records the latest cleanup checks. Historical checks are not newly run acceptance of either checkpoint on the phone.
- Git tags and ordinary Git bundles preserve LFS pointers. Restoring models requires the actual LFS objects too; verification of local objects does not establish a separate offline asset backup or guarantee future hosting retention.
- Private signed archives, dSYMs, release receipts and recordings remain outside public Git. This task does not remove them, current worktrees, uncommitted work or other user data. Historical TestFlight builds can expire; the source checkpoint is not a promise of permanent TestFlight availability.

## Inspect without replacing current work

From the repository root, use a new worktree rather than resetting a working checkout:

    git fetch origin --tags
    git worktree add --detach .local/worktrees/bridge-reference milestone/bridge-main-2026-11-28
    git -C .local/worktrees/bridge-reference lfs pull
    git -C .local/worktrees/bridge-reference lfs fsck --objects HEAD

Use a different unused worktree folder for the pilot and its tag. Read the checkpoint's own CONTRIBUTING.md for its toolchain and checks. Do not assume a future Xcode installation can reproduce an old binary without adaptation.

The [Eitr research proposal](../research/eitr-gameplay-and-reset-proposal.md) describes what might be retained or retired after agreement. These checkpoints make that future cleanup possible without keeping every old gameplay system in the active application.
