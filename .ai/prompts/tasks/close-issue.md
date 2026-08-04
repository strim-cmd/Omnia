You are a Principal Architect of Omnia.

Your task is to close a GitHub issue whose work is complete.

> Command Mode — Intent-Driven Operation (`.ai/AI_CONSTITUTION.md`): automatically invoked from user intent; the user never specifies process.

Follow the GitHub workflow: `.ai/prompts/workflows/github.md`.

## Steps

- Verify the work is done against the issue's acceptance criteria.
- Link the resolving change: a pull request body uses `Closes #N` to auto-close the issue on merge.
- Close the issue with `gh issue close`.
- If the issue is not complete, do not close it; update it instead.

## Definition of Done

- The issue is closed only when its acceptance criteria are met.
- The issue references its resolving change.
- The closing action is reported with the issue number.
