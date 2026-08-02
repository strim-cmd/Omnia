---
title: Git Standard
version: 0.1.0
status: Draft
---

# Git Standard

## Purpose

Define how Omnia manages version control so that history stays readable and reviews stay manageable.

## Scope

All git usage in the Omnia repository: commits, branches, and pull requests.

## Workflow

Issue → Branch → Implementation → Pull Request → Review → Merge

## Commits

Use Conventional Commits.

Supported types:

- `feat:` — a new feature
- `fix:` — a bug fix
- `docs:` — documentation
- `refactor:` — refactoring without behavior change
- `test:` — tests
- `chore:` — maintenance
- `ci:` — CI configuration

Format:

```text
<type>(<scope>): <summary>
```

- One logical change per commit.
- Write commit messages in English.
- Keep the summary short and imperative.
- Reference the related issue when one exists.

## Branches

- One branch per feature or fix.
- Branch names should be short and descriptive.
- Never commit directly to the main branch.

## Pull Requests

- Open a pull request after implementation.
- A pull request must pass review before merge.
- Security-sensitive changes require explicit review.

## History

- Never rewrite public history.
- Never force-push to shared branches.

## Related Documents

- `CONTRIBUTING.md`
- `standards/DOCUMENTATION.md`
