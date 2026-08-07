# Interactive Execution Workflow

Reusable process for completing a GitHub issue end to end: implement the change, open the pull request, review it, resolve the review outcome, merge, and close the issue.

> Command Mode — Intent-Driven Operation (`.ai/AI_CONSTITUTION.md`): automatically invoked from user intent; the user never specifies process.

## Preconditions

1. The command has been resolved against the Workflow Registry (`.ai/orchestrator/REGISTRY.md`).
2. The GitHub issue is open and its acceptance criteria are the authoritative task definition.
3. The Implementation workflow preconditions are satisfied (`implementation.md`).
4. `gh` is installed and authenticated (`github.md`).

## Orchestrator Resolution

The Workflow Orchestrator resolves `Complete Issue #N` against the registry before executing this lifecycle. The registry determines the workflow, task prompt, checklist, and decision gates. Project state is loaded from `.ai/context/PROJECT_STATE.md` and the GitHub issue artifact. If execution is interrupted at any point, the agent re-reads the registry and project state to resume.

## Steps

1. **Implement.** Follow the Implementation workflow (`implementation.md`) against the issue's acceptance criteria. Keep every engineering artifact — commit messages, pull request text, issue updates, and documentation — in English.
2. **Open the pull request.** Create the branch, commit, push, and open the pull request with `gh pr create`, linking the issue with `Closes #N` in the pull request body.
3. **Review.** Follow the Review workflow (`review.md`) against the Code Review checklist (`checklists/code-review.md`).
4. **Resolve the review outcome.** Branch on the verdict:
   - **Approve** — the review passes cleanly. Merge automatically without asking.
   - **Approve with Recommendations** — only non-blocking recommendations remain. Summarize them in the user's preferred language and ask whether to address them before merging. Merge only after the user decides.
   - **Needs Revision or Reject** — blocking issues remain. Fix them automatically without asking, then repeat the review until no blocking issues remain.
5. **Merge.** Merge the pull request (`gh pr merge --squash --delete-branch`), then sync the base branch.
6. **Close the issue and update GitHub state.** Verify the issue's acceptance criteria are met, close it with `gh issue close` (manually when a squash merge does not auto-close), and move the project item to Done following the GitHub workflow (`github.md`).

## Interaction and Language

1. All engineering artifacts are written in English: commits, pull requests, issues, milestones, and documentation.
2. All user interaction is in the user's preferred language, inferred from how the user communicates. Every summary of review recommendations and every question is written in that language.
3. Pause for the user only at the interactive decision gates (non-blocking recommendations); blocking fixes and clean-pass merges never pause.

## Exit Criteria

- The issue's acceptance criteria are met and the issue is closed.
- The pull request is merged and its branch is deleted.
- GitHub state is updated (project item moved to Done).
- The outcome — merge commit, closed issue, and any deferred recommendations — is reported to the user in their preferred language.
