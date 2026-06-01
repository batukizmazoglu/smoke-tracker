## Summary

<!-- What does this PR do and why? -->

## Related issue

<!-- e.g. Closes #12 -->

## Type of change

- [ ] Bug fix
- [ ] New feature
- [ ] Refactor / cleanup
- [ ] Docs
- [ ] Tests / CI

## Checklist

- [ ] I followed the layering rule (App → Data → Core); no upward imports.
- [ ] Logic changes in Core/Data come with tests (written test‑first where possible).
- [ ] `cd SmokeTrackerCore && swift test` passes.
- [ ] `cd SmokeTrackerData && swift test` passes.
- [ ] App changes build via `xcodegen generate` + Xcode.
- [ ] No build artifacts, generated project, secrets, or personal signing config committed.
- [ ] Commits follow Conventional Commits.
- [ ] Docs updated if behavior or setup changed (README / README.tr / docs/).
