# Release And Distribution

This runbook starts from a clean checkout and ends with WeChore ready for
TestFlight, release preparation, and Cloudflare Pages hosting at
`https://wechore.peyton.app`.

## What Is Automated

- Version metadata starts at `1.0.0`. Until a real semver tag exists, app builds
  use marketing version `1.0.0`.
- Integer build numbers are generated automatically and remain unique for
  TestFlight.
- Pushes to `master` create GitHub prereleases tagged as
  `preview/master-<run-number>-<short-sha>`. These are intentionally not semver
  tags and do not move the shipping version.
- Pushes to `master` run a macOS GitHub Actions job that archives the production
  app and uploads it to App Store Connect/TestFlight.
- Web-related pushes to `master` deploy `web/` to the Cloudflare Pages
  production branch. Same-repo pull requests deploy Cloudflare Pages preview
  branches instead of touching `wechore.peyton.app`.
- Cloudflare Pages, the custom domain, DNS, and feasible Email Routing variants
  are exposed through `just` commands.

Apple does not currently expose an official public `POST /v1/apps` App Store
Connect API endpoint. The one manual step is creating the App Store Connect app
record. The repo automates the check before upload and everything after the app
record exists.

## One-Time App Store Connect Setup

1. Bootstrap repo tooling:

   ```text
   mise exec -- just bootstrap
   ```

2. Create the App Store Connect app record:

   ```text
   mise exec -- just appstore-create-app
   ```

   Enter these values in App Store Connect:

   ```text
   Name: WeChore
   Bundle ID: app.peyton.wechore
   SKU: WECHORE-IOS
   Primary locale: en-US
   Platform: iOS
   Version: 1.0.0
   ```

3. Create an App Store Connect API key.

   Required permissions:

   ```text
   Role: Admin
   App access: All apps
   Certificates, Identifiers & Profiles access: enabled
   ```

   The Admin role is intentionally broad because Xcode's
   `-allowProvisioningUpdates` path can create or update App IDs, certificates,
   and provisioning profiles for automatic signing.

4. Add these GitHub environment secrets to the `testflight` environment:

   ```text
   APP_STORE_CONNECT_API_KEY_ID
   APP_STORE_CONNECT_API_ISSUER_ID
   APP_STORE_CONNECT_API_KEY_P8_BASE64
   ```

   Encode the `.p8` key as one line:

   ```text
   base64 -i AuthKey_<KEY_ID>.p8 | tr -d '\n'
   ```

5. Add this GitHub environment variable to `testflight`:

   ```text
   APPLE_TEAM_ID=3VDQ4656LX
   ```

   The repo defaults to this team id, but keeping it as an environment variable
   makes future team changes explicit.

6. Verify the App Store Connect app is visible through `asc`:

   ```text
   export APP_STORE_CONNECT_API_KEY_ID=<key id>
   export APP_STORE_CONNECT_API_ISSUER_ID=<issuer id>
   export APP_STORE_CONNECT_API_KEY_PATH=/absolute/path/AuthKey_<KEY_ID>.p8
   export TEAM_ID=3VDQ4656LX
   mise exec -- just appstore-preflight
   mise exec -- just appstore-check
   ```

   Expected results:

   ```text
   Release metadata preflight passed.
   Found App Store Connect app with asc: WeChore (app.peyton.wechore, sku WECHORE-IOS, id ...)
   ```

   `appstore-check` also supports an authenticated local `asc` profile, but CI
   uses the App Store Connect environment variables above.

7. Ensure signing resources exist before the first TestFlight archive:

   ```text
   mise exec -- just appstore-provisioning-plan
   mise exec -- just appstore-ensure-provisioning
   ```

   The ensure command creates or verifies the production app and widget bundle
   identifiers, enables the app-group, associated-domains, and iCloud/CloudKit
   capabilities required by the entitlements, and creates missing
   `IOS_APP_STORE` provisioning profiles when an active Apple Distribution
   certificate is available. It does not revoke, delete, or replace existing
   certificates or profiles.

   If the command reports that no distribution certificate exists, create or
   renew an Apple Distribution certificate in the Developer portal, then rerun
   the command. The archive still uses Xcode's `-allowProvisioningUpdates` path,
   but this command catches missing identifiers and stale profile setup before
   the slower archive step.

## TestFlight Upload

Local upload uses the same scripts as GitHub Actions:

```text
export APP_STORE_CONNECT_API_KEY_ID=<key id>
export APP_STORE_CONNECT_API_ISSUER_ID=<issuer id>
export APP_STORE_CONNECT_API_KEY_PATH=/absolute/path/AuthKey_<KEY_ID>.p8
export TEAM_ID=3VDQ4656LX
mise exec -- just appstore-preflight
mise exec -- just appstore-ensure-provisioning
mise exec -- just testflight-upload
```

The command archives the `WeChore` production scheme, exports with
`method=app-store-connect`, uploads to App Store Connect, and leaves build
artifacts under `.build/` and `.DerivedData/archive/`.

GitHub Actions runs the same upload from `.github/workflows/testflight.yml` on
app or release-tooling pushes to `master` and on manual dispatch. Documentation
or website-only pushes do not create a new TestFlight build. New builds appear in
App Store Connect under TestFlight after Apple processing completes.

If the `testflight` GitHub environment is missing any required App Store Connect
value, the workflow emits a notice and skips the upload instead of failing the
push. Run `mise exec -- just appstore-preflight` locally or configure the
environment values above to enable uploads.

## Versioning

Shipping releases use semver tags:

```text
v1.0.0
v1.0.1
v1.1.0
```

`scripts.tooling.resolve_versions` reads the newest reachable `vX.Y.Z` tag and
uses that as `CFBundleShortVersionString`. If no semver tag exists, it uses
`1.0.0`.

`CFBundleVersion` is always an integer string. In GitHub Actions it is
`<run-number><two-digit-attempt>`, so run `123` attempt `2` becomes `12302`.
Local builds use a UTC timestamp integer such as `2604141130`.

Preview GitHub releases use tags like:

```text
preview/master-42-1a2b3c4d5e6f
```

Those preview tags are prereleases, are not marked as latest, and never affect
the app marketing version.

## Cloudflare Setup

Cloudflare account and zone defaults:

```text
CLOUDFLARE_ACCOUNT_ID=0e32ee7804b102bea6b9d3056d60f980
CLOUDFLARE_ZONE_ID=a004f01ed99de3582152debde5a96a08
CLOUDFLARE_ZONE_NAME=peyton.app
CLOUDFLARE_PAGES_PROJECT=wechore
WECHORE_WEB_DOMAIN=wechore.peyton.app
WECHORE_EMAIL_DOMAIN=wechore.peyton.app
```

Create a Cloudflare API token for setup with these permissions:

```text
Account - Cloudflare Pages: Edit
Account - Email Routing Addresses: Edit
Zone - Zone: Read
Zone - DNS: Edit
Zone - Email Routing Rules: Edit
```

Token resources:

```text
Account Resources: Include - Personal
Zone Resources: Include - Specific zone - peyton.app
```

Run the full setup:

```text
export CLOUDFLARE_API_TOKEN=<setup token>
export CLOUDFLARE_ACCOUNT_ID=0e32ee7804b102bea6b9d3056d60f980
export CLOUDFLARE_ZONE_ID=a004f01ed99de3582152debde5a96a08
mise exec -- just cloudflare-setup EMAIL_ROUTING_DESTINATION=you@example.com
```

That exact command will stop before configuring email because the requested
address domain conflicts with the website hostname. `wechore.peyton.app` must
have a CNAME record to serve Cloudflare Pages, while email delivery for
`support@wechore.peyton.app` requires MX records at `wechore.peyton.app`. DNS
does not allow a CNAME and MX records at the same hostname.

The Pages and DNS setup still creates or reuses:

```text
Pages project: wechore
Production branch: master
Custom domain: wechore.peyton.app
DNS CNAME: wechore.peyton.app -> wechore.pages.dev
```

Choose one of these changes before enabling email:

```text
Option A: Keep the website at wechore.peyton.app and use support@peyton.app,
privacy@peyton.app, security@peyton.app, and contact@peyton.app.

Option B: Move the website to www.wechore.peyton.app and use MX records at
wechore.peyton.app for the requested support@wechore.peyton.app-style addresses.
```

For Option A, run:

```text
export WECHORE_EMAIL_DOMAIN=peyton.app
mise exec -- just cloudflare-email-setup EMAIL_ROUTING_DESTINATION=you@example.com
```

Cloudflare may email `EMAIL_ROUTING_DESTINATION` a verification link. Click it
and rerun the same command if routing rule creation is blocked. For Option B,
set `WECHORE_WEB_DOMAIN=www.wechore.peyton.app`, rerun the Pages/DNS setup, and
then run email setup with `WECHORE_EMAIL_DOMAIN=wechore.peyton.app`.

Separate setup targets are also available:

```text
mise exec -- just cloudflare-pages-setup
mise exec -- just cloudflare-dns-setup
mise exec -- just cloudflare-email-setup EMAIL_ROUTING_DESTINATION=you@example.com
```

## Cloudflare Deploy

Create a narrower Cloudflare API token for GitHub deploys with:

```text
Account - Cloudflare Pages: Edit
```

Token resources:

```text
Account Resources: Include - Personal
```

Add these GitHub environment secrets to both `web-production` and `web-preview`:

```text
CLOUDFLARE_API_TOKEN
CLOUDFLARE_ACCOUNT_ID
```

Production deploy:

```text
mise exec -- just cloudflare-deploy BRANCH=master
```

Preview deploy:

```text
mise exec -- just cloudflare-deploy BRANCH=pr-123
```

The GitHub workflow deploys production only from `master`. Pull requests use a
branch-specific Cloudflare Pages URL such as `https://pr-123.wechore.pages.dev`
when the pull request branch is in the same repository and can access secrets.
If the matching GitHub environment is missing `CLOUDFLARE_API_TOKEN` or
`CLOUDFLARE_ACCOUNT_ID`, the workflow still validates the static site, emits a
notice, and skips the external deploy.

## Final Verification

Run repository validation before merging release automation changes:

```text
mise exec -- just lint
```

Then verify live services:

```text
curl -I https://wechore.peyton.app
mise exec -- just appstore-check
```

In App Store Connect, confirm that the uploaded build appears under TestFlight
for `WeChore` after Apple processing completes.
