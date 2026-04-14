# CI

GitHub Actions should call the same repo-local commands used by developers.

## Local Commands

```text
just bootstrap
just generate
just appstore-preflight
just appstore-check
just testflight-archive
just testflight-upload
just lint
just test-python
just test-unit
just test-integration
just test-ui
just test-ui-ipad
just build
just web-check
just cloudflare-setup
just cloudflare-deploy
just ci
```

## Jobs

- `lint` runs `mise exec -- just ci-lint` on Ubuntu.
- `test-python` runs `mise exec -- just ci-python` on Ubuntu.
- `test-ios` runs unit, integration, iPhone UI, and iPad UI tests on macOS.
- `build` runs `mise exec -- just ci-build` on macOS.
- `preview-release` creates non-semver GitHub prereleases from every push to
  `master`.
- `testflight` runs `mise exec -- just appstore-preflight`, verifies App Store
  Connect app visibility through `asc`, and uploads production iOS archives to
  TestFlight for app or release-tooling changes on `master` when the `testflight`
  environment has the required App Store Connect values. If those values are not
  configured, it emits a notice and skips the upload.
- `deploy-web` validates and builds `web/`, then deploys to Cloudflare Pages
  production from `master` and same-repo preview URLs from pull requests when
  the matching Cloudflare environment values are configured. If those values are
  missing, it emits a notice and skips the external deploy.

The workflows pin action versions by SHA, install tools through
`jdx/mise-action`, set explicit job timeouts, and select Xcode `26.3.0` instead of
floating to the runner's latest Xcode.
