# Automate WeChore TestFlight And Web Release Operations

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This plan follows the ExecPlan rules in `~/.agents/PLANS.md`, which require the document to remain self-contained and current.

## Purpose / Big Picture

After this work, a maintainer can start from a clean checkout and use `just` commands to prepare the App Store Connect release path, upload signed iOS builds to TestFlight from GitHub Actions, deploy the static website to Cloudflare Pages, and configure Cloudflare Email Routing once the email hostname no longer conflicts with the web hostname. The visible outcome is that `wechore.peyton.app` serves the committed `web/` site, pushes to `master` create clear preview GitHub releases without changing semantic version tags, and pushes to `master` upload the current `1.0.0` app build to TestFlight.

## Progress

- [x] (2026-04-14T11:15:55Z) Audited the repo layout, current Tuist versioning, CI workflows, static site tooling, and existing App Store encryption plist metadata.
- [x] (2026-04-14T11:15:55Z) Verified current platform constraints from local Xcode help, Apple's App Store Connect OpenAPI spec, and Cloudflare's API schema.
- [x] (2026-04-14T11:29:43Z) Added repo-local release scripts for App Store Connect checks, TestFlight archive/upload, and Cloudflare setup/deploy.
- [x] (2026-04-14T11:29:43Z) Added `justfile` targets for App Store Connect, TestFlight, preview packages/releases, Cloudflare setup, Cloudflare DNS, Cloudflare email, and Cloudflare deploy.
- [x] (2026-04-14T11:29:43Z) Added GitHub Actions for preview GitHub releases, TestFlight uploads, and Cloudflare Pages production/preview deploys.
- [x] (2026-04-14T11:29:43Z) Added release runbook docs naming every required API key, permission, GitHub secret, GitHub environment, and end-to-end bootstrap step.
- [x] (2026-04-14T11:29:43Z) Provisioned the Cloudflare Pages project `wechore` and attached the pending custom domain `wechore.peyton.app` with the available token.
- [ ] Provision Cloudflare DNS and Email Routing after receiving a Cloudflare token with DNS/Edit and Email Routing permissions and after choosing a non-conflicting email hostname.
- [x] (2026-04-14T11:29:43Z) Ran focused Python tests and `mise exec -- just lint`; both passed after fixing shellcheck path-variable annotations.

## Surprises & Discoveries

- Observation: The app already declares `ITSAppUsesNonExemptEncryption` as `false` in `app/WeChore/Info.plist`.
  Evidence: `plutil -p app/WeChore/Info.plist` includes `"ITSAppUsesNonExemptEncryption" => false`.
- Observation: Apple’s public App Store Connect API cannot create the App Store Connect app record itself.
  Evidence: The downloaded current Apple OpenAPI spec lists only `get apps_getCollection` for `/v1/apps`; no `post` operation exists. It does expose `POST /v1/bundleIds` and `POST /v1/appStoreVersions`.
- Observation: Current Xcode supports API-key authenticated signing and upload without a logged-in Xcode account.
  Evidence: `xcodebuild -help` documents `-allowProvisioningUpdates`, `-authenticationKeyPath`, `-authenticationKeyID`, and `-authenticationKeyIssuerID`, and says the flag can create/update profiles, app IDs, and certificates for automatically signed targets.
- Observation: Distributed builds should use integer build numbers rather than timestamp strings with punctuation.
  Evidence: Apple's Xcode Cloud build-number documentation describes build numbers as integer values and says hash values, timestamps, or other strings cannot be used for Xcode Cloud-distributed builds. The release helper now emits integer strings for both GitHub and local builds.
- Observation: Cloudflare exposes public API endpoints for Pages projects, Pages custom domains, DNS records, Email Routing destination addresses, Email Routing DNS enablement, and routing rules.
  Evidence: The Cloudflare OpenAPI schema lists `POST /accounts/{account_id}/pages/projects`, `POST /accounts/{account_id}/pages/projects/{project_name}/domains`, `POST /zones/{zone_id}/dns_records`, `POST /accounts/{account_id}/email/routing/addresses`, and `POST /zones/{zone_id}/email/routing/rules`.
- Observation: The exact requested hostname cannot simultaneously be the Pages CNAME target and the email domain for `support@wechore.peyton.app`.
  Evidence: Pages custom domain verification reports that a CNAME record is required for `wechore.peyton.app`; email delivery to `support@wechore.peyton.app` requires MX records at `wechore.peyton.app`; DNS does not allow CNAME and MX records at the same owner name.
- Observation: The available Cloudflare token can create Pages resources but cannot edit DNS or Email Routing for `peyton.app`.
  Evidence: Creating the Pages project succeeded, adding the Pages custom domain succeeded, and attempts to call DNS or Email Routing endpoints returned Cloudflare API authentication error `10000`.

## Decision Log

- Decision: Keep the shipping app semantic version at `1.0.0` until a human creates a real semver tag such as `v1.0.1`; preview GitHub releases will use non-semver tags under `preview/`.
  Rationale: The user asked for previews on every `master` change that do not increment semver but remain clearly identifiable.
  Date/Author: 2026-04-14 / Codex
- Decision: Generate App Store build numbers as integers.
  Rationale: This avoids TestFlight/App Store validation ambiguity while preserving semantic marketing versions.
  Date/Author: 2026-04-14 / Codex
- Decision: Use native `xcodebuild archive` and `xcodebuild -exportArchive` for TestFlight upload instead of adding Fastlane.
  Rationale: Current Xcode directly supports App Store Connect API key authentication and automatic provisioning. Avoiding Fastlane keeps dependencies lean and avoids relying on private App Store Connect web automation.
  Date/Author: 2026-04-14 / Codex
- Decision: Do not pretend the App Store Connect app record can be created with the public App Store Connect API.
  Rationale: Apple's current OpenAPI spec does not expose `POST /v1/apps`. The runbook will make the one manual App Store Connect creation step explicit and still automate validation, signing, upload, and Cloudflare setup.
  Date/Author: 2026-04-14 / Codex
- Decision: Use Cloudflare Pages Direct Uploads from GitHub Actions through Wrangler and configure `master` as the production branch.
  Rationale: The repo already builds static assets locally under `.build/web`; direct upload keeps Cloudflare Git integration unnecessary and gives PR branches Pages preview URLs without deploying them to the production custom domain.
  Date/Author: 2026-04-14 / Codex
- Decision: Make the Pages/email hostname conflict explicit in tooling and docs rather than silently creating non-working Email Routing rules.
  Rationale: The user asked to double check that everything is possible. Creating rules for `support@wechore.peyton.app` while the same hostname is a Pages CNAME would produce configuration that appears automated but cannot receive SMTP mail.
  Date/Author: 2026-04-14 / Codex

## Outcomes & Retrospective

The repo now has repeatable release and hosting automation wired through `justfile`, GitHub Actions, and docs. The implemented paths cover App Store Connect validation, native Xcode TestFlight archive/upload, non-semver preview GitHub releases, Cloudflare Pages direct deploys, and idempotent Cloudflare setup scripts. Focused Python tests and the required `mise exec -- just lint` pass.

Two gaps are external to the repo. First, App Store Connect app record creation still needs a one-time human App Store Connect session because Apple's official API does not provide that create operation. Second, DNS/email cannot both use `wechore.peyton.app`: Pages needs a CNAME at that hostname, while `support@wechore.peyton.app`-style email needs MX records at that hostname. The Cloudflare Pages project and custom domain were created with the available token, but the custom domain remains pending until DNS can be changed with a token that has DNS edit permission.

## Context and Orientation

The repository root is the working directory for all commands. The iOS app lives under `app/` and uses Tuist to generate `app/WeChore.xcworkspace`. The production app target is `WeChore`, its bundle identifier is `app.peyton.wechore`, and the Apple Developer team id currently defaults to `3VDQ4656LX` in `app/WeChore/Project.swift` and `scripts/tooling/wechore.env`. Tuist reads `WECHORE_MARKETING_VERSION` and `WECHORE_BUILD_NUMBER` from the environment, so release scripts can set version metadata without editing Xcode project files.

The static website lives in `web/`. The current `just web-build` target validates the committed HTML/CSS and copies it into `.build/web`. Cloudflare Pages should publish that directory. `wechore.peyton.app` is a subdomain of the Cloudflare zone `peyton.app`.

The repo uses `mise` for tools and the root `justfile` for workflows. The project-specific rule in `AGENTS.md` requires `mise exec -- just lint` before any development task is reported complete.

## Plan of Work

First, add small release scripts that follow existing shell and Python tooling patterns. A shell script will archive the production iOS app with automatic signing and API-key authentication when provided. Another shell script will export and upload the archive to App Store Connect/TestFlight using an export options plist generated in `.build/`. A Python App Store Connect checker will create an ES256 JWT from the `.p8` key and verify that `app.peyton.wechore` exists in App Store Connect; if it does not, it will print the exact manual creation values and explain the public API limitation.

Second, add Cloudflare tooling under `scripts/cloudflare/`. The setup script will be idempotent: create or reuse the Pages project `wechore`, add the custom domain `wechore.peyton.app`, upsert the CNAME record, and configure Email Routing only when `WECHORE_EMAIL_DOMAIN` is not the same hostname as the Pages CNAME. The deploy path will use Wrangler through a `just` target so GitHub Actions and local developers run the same command.

Third, extend the `justfile` so each user-requested operation has a named target: App Store Connect check/manual-open, TestFlight archive/upload, preview release packaging, Cloudflare setup, Cloudflare DNS setup, Cloudflare email setup, Cloudflare web deploy, and CI-facing variants.

Fourth, add GitHub Actions. The preview release workflow will run on every push to `master`, build/package the static site as a clear artifact, and create a prerelease with a tag like `preview/master-<run_number>-<short_sha>`. The TestFlight workflow will run on every push to `master` and can also be manually dispatched. The Pages workflow will deploy production only from `master`; pull requests will deploy only a preview branch URL.

Fifth, document every required credential, exact permission, GitHub secret name, GitHub environment name, and end-to-end command sequence in a release runbook. Update tests to assert the new commands, workflows, and metadata remain present.

## Concrete Steps

Run commands from the repository root unless a command says otherwise. After the implementation is complete, use:

    mise exec -- just appstore-check
    mise exec -- just testflight-upload
    mise exec -- just cloudflare-setup EMAIL_ROUTING_DESTINATION=you@example.com
    mise exec -- just cloudflare-deploy BRANCH=master
    mise exec -- just lint

`appstore-check` requires App Store Connect API key environment variables. `testflight-upload` requires those variables plus Apple signing permissions. `cloudflare-setup` requires a Cloudflare API token and account/zone identifiers. `cloudflare-deploy` requires the Cloudflare API token and account id.

## Validation and Acceptance

The repository-level acceptance is that `mise exec -- just lint` passes and focused Python tests cover the new scripts/workflows. The App Store Connect acceptance is that `just appstore-check` finds the `app.peyton.wechore` app record and `just testflight-upload` finishes with Xcode uploading the archive. The Cloudflare acceptance is that `just cloudflare-pages-setup`, `just cloudflare-dns-setup`, and `just cloudflare-deploy BRANCH=master` produce a working site at `https://wechore.peyton.app`; email acceptance requires choosing a non-conflicting `WECHORE_EMAIL_DOMAIN` or moving the web hostname, then rerunning `just cloudflare-email-setup EMAIL_ROUTING_DESTINATION=<address>`.

## Idempotence and Recovery

All setup scripts should be safe to rerun. Cloudflare setup will read existing resources first and update or reuse them instead of creating duplicates, and it will refuse to configure Email Routing for the same hostname that Pages uses as a CNAME. App Store Connect checks will never create or mutate the app record. TestFlight uploads cannot be undone by the repo; if an uploaded build is wrong, expire or remove the build from App Store Connect and rerun with a new build number. Cloudflare Email Routing destination verification may require clicking a verification link in the destination mailbox before rules can forward mail.

## Artifacts and Notes

Important verified snippets:

    /v1/apps supports get apps_getCollection only in Apple's current OpenAPI spec.
    xcodebuild -help says -allowProvisioningUpdates can create and update profiles, app IDs, and certificates with an App Store Connect authentication key.
    Cloudflare API includes Pages project/domain, DNS record, Email Routing destination, and Email Routing rule endpoints.
    uv run pytest tests -v: 28 passed.
    mise exec -- just lint: completed with 0 SwiftLint violations and all hk checks passing.

## Interfaces and Dependencies

Use Python standard library for Cloudflare HTTP calls. Use `cryptography` only for App Store Connect ES256 JWT signing, declared in `pyproject.toml`. Use Xcode command-line tools for archive and upload. Use Wrangler, declared in `mise.toml` as an npm tool, for Cloudflare Pages direct uploads.

At completion, new or updated interfaces should include:

- `scripts.app_store_connect.check`: CLI module that validates App Store Connect credentials and confirms the production app record exists.
- `scripts.cloudflare.setup`: CLI module that idempotently configures Cloudflare Pages, DNS, and Email Routing.
- `scripts/tooling/archive.sh`: Archives the production iOS app for distribution.
- `scripts/tooling/upload_testflight.sh`: Exports/uploads the archive to App Store Connect/TestFlight.
- Root `justfile` targets for every user-facing setup and release step.

Revision note, 2026-04-14: Created the ExecPlan after auditing the repository and external platform constraints so the remaining implementation can be resumed from this file alone.

Revision note, 2026-04-14: Updated the plan after implementing release scripts, GitHub Actions, Cloudflare setup tooling, documentation, focused tests, and required lint. Added the discovered DNS conflict between the requested Pages hostname and requested email addresses.
