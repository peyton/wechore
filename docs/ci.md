# CI

GitHub Actions should call the same repo-local commands used by developers.

## Local Commands

```text
just bootstrap
just generate
just lint
just test-python
just test-unit
just test-integration
just test-ui
just test-ui-ipad
just build
just web-check
just ci
```

## Jobs

- `lint` runs `mise exec -- just ci-lint` on Ubuntu.
- `test-python` runs `mise exec -- just ci-python` on Ubuntu.
- `test-ios` runs unit, integration, iPhone UI, and iPad UI tests on macOS.
- `build` runs `mise exec -- just ci-build` on macOS.

The workflows pin action versions by SHA and install tools through `jdx/mise-action`.
