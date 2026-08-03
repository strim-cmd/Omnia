# Release Workflow

Reusable process for preparing a release.

## Steps

1. Read `.ai/standards/DOCUMENTATION.md`.
2. Read the current version in `.ai/context/PROJECT_STATE.md`.
3. Follow Semantic Versioning.
4. Update `CHANGELOG.md` following Keep a Changelog.
5. Ensure all tests pass and the change is reviewed.
6. Confirm security-sensitive changes received explicit review.
7. Verify no secrets or credentials are committed.
8. Tag the release commit with the version number.
9. Update the version and release status in `.ai/context/PROJECT_STATE.md`.

## Exit Criteria

- Version is bumped correctly.
- Changelog is updated.
- Tests pass.
- Release notes describe the changes for users.
