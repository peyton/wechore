#!/usr/bin/env -S just --working-directory . --justfile

[private]
@default:
    just --list

bootstrap:
    bash scripts/tooling/bootstrap.sh

[group('app')]
icons:
    bash scripts/generate-app-icons.sh

[group('app')]
generate-icons: icons

[group('app')]
generate:
    bash scripts/tooling/generate.sh

[group('app')]
build:
    bash scripts/tooling/build.sh

[group('app')]
run:
    bash scripts/tooling/run.sh

[group('appstore')]
appstore-create-app:
    @printf '%s\n' 'Apple does not expose an official POST /v1/apps App Store Connect API endpoint.'
    @printf '%s\n' 'Create the app record once in App Store Connect with:'
    @printf '%s\n' '  Name: WeChore'
    @printf '%s\n' '  Bundle ID: app.peyton.wechore'
    @printf '%s\n' '  SKU: app.peyton.wechore'
    @printf '%s\n' '  Primary locale: en-US'
    @printf '%s\n' '  Platform: iOS'
    @printf '%s\n' '  Version: 1.0.0'
    @if command -v open >/dev/null 2>&1; then open 'https://appstoreconnect.apple.com/apps'; fi

[group('appstore')]
appstore-api-key:
    bash scripts/tooling/appstore_api_key.sh

[group('appstore')]
appstore-check:
    WECHORE_FLAVOR=prod mise exec -- uv run python -m scripts.app_store_connect.check_asc

[group('appstore')]
appstore-preflight:
    WECHORE_FLAVOR=prod WECHORE_CLOUD_KIT_ENVIRONMENT=Production mise exec -- uv run python -m scripts.app_store_connect.preflight --require-credentials

[group('appstore')]
appstore-provisioning-plan:
    WECHORE_FLAVOR=prod WECHORE_CLOUD_KIT_ENVIRONMENT=Production mise exec -- uv run python -m scripts.app_store_connect.provisioning --dry-run

[group('appstore')]
appstore-ensure-provisioning:
    WECHORE_FLAVOR=prod WECHORE_CLOUD_KIT_ENVIRONMENT=Production mise exec -- uv run python -m scripts.app_store_connect.provisioning

[group('release')]
testflight-archive:
    WECHORE_FLAVOR=prod WECHORE_CLOUD_KIT_ENVIRONMENT=Production bash scripts/tooling/archive_release.sh

[group('release')]
testflight-upload:
    WECHORE_FLAVOR=prod WECHORE_CLOUD_KIT_ENVIRONMENT=Production bash scripts/tooling/upload_testflight.sh

[group('release')]
preview-package VERSION='':
    version="{{VERSION}}"; version="${version#VERSION=}"; if [ -z "$version" ]; then version="preview-$(git rev-parse --short=12 HEAD)"; fi; \
        mise exec -- just web-build; \
        mise exec -- uv run python -m scripts.web.package_static_site --version "$version"

[group('release')]
preview-release VERSION='':
    version="{{VERSION}}"; version="${version#VERSION=}"; if [ -z "$version" ]; then version="preview-master-$(git rev-parse --short=12 HEAD)"; fi; \
        tag="preview/$version"; \
        mise exec -- just preview-package VERSION="$version"; \
        gh release create "$tag" .build/releases/wechore-web-"$version".tar.gz .build/releases/wechore-web-"$version".tar.gz.sha256 \
            --generate-notes --latest=false --prerelease --target "$(git rev-parse HEAD)" --title "WeChore preview $version"

[group('web')]
web-serve PORT='8000':
    port="{{PORT}}"; port="${port#PORT=}"; cd web && uv run python -m http.server "$port"

[group('web')]
web-check:
    mise exec -- prettier --check "web/**/*.{html,css}"
    uv run python -m scripts.web.validate_static_site web

[group('web')]
web-fmt:
    mise exec -- prettier --write "web/**/*.{html,css}"

[group('web')]
web-build: web-check
    rm -rf .build/web
    mkdir -p .build/web
    cp -R web/. .build/web/

[group('cloudflare')]
cloudflare-setup EMAIL_ROUTING_DESTINATION='':
    dest="{{EMAIL_ROUTING_DESTINATION}}"; dest="${dest#EMAIL_ROUTING_DESTINATION=}"; if [ -n "$dest" ]; then export EMAIL_ROUTING_DESTINATION="$dest"; fi; \
        mise exec -- uv run python -m scripts.cloudflare.setup

[group('cloudflare')]
cloudflare-pages-setup:
    mise exec -- uv run python -m scripts.cloudflare.setup --skip-dns --skip-email

[group('cloudflare')]
cloudflare-dns-setup:
    mise exec -- uv run python -m scripts.cloudflare.setup --skip-pages --skip-email

[group('cloudflare')]
cloudflare-email-setup EMAIL_ROUTING_DESTINATION='':
    dest="{{EMAIL_ROUTING_DESTINATION}}"; dest="${dest#EMAIL_ROUTING_DESTINATION=}"; if [ -n "$dest" ]; then export EMAIL_ROUTING_DESTINATION="$dest"; fi; \
        mise exec -- uv run python -m scripts.cloudflare.setup --skip-pages --skip-dns

[group('cloudflare')]
cloudflare-deploy BRANCH='master':
    branch="{{BRANCH}}"; branch="${branch#BRANCH=}"; \
        mise exec -- just web-build; \
        mise exec -- wrangler pages deploy .build/web --project-name "${CLOUDFLARE_PAGES_PROJECT:-wechore}" --branch "$branch"

[group('doctor')]
doctor:
    bash scripts/tooling/doctor_signing.sh

[group('cloudkit')]
cloudkit-doctor:
    bash scripts/cloudkit/doctor.sh

[group('cloudkit')]
cloudkit-export-schema:
    bash scripts/cloudkit/export-schema.sh

[group('cloudkit')]
cloudkit-validate-schema:
    bash scripts/cloudkit/validate-schema.sh

[group('maintenance')]
clean-build:
    rm -rf .build .DerivedData app/build app/WeChore.xcworkspace

[group('maintenance')]
clean-generated: clean-build
    rm -rf .state .venv .ruff_cache .rumdl_cache .pytest_cache .cache .mise .config
    find . -type d -name '__pycache__' -prune -exec rm -rf {} +

[group('maintenance')]
clean: clean-generated

test-unit:
    bash scripts/tooling/test_ios.sh --suite unit

test-integration:
    bash scripts/tooling/test_ios.sh --suite integration

test-ui:
    bash scripts/tooling/test_ios.sh --suite ui --device iphone

test-ui-ipad:
    bash scripts/tooling/test_ios.sh --suite ui --device ipad

test-python:
    uv run pytest tests -v

test: test-unit test-integration test-ui test-ui-ipad test-python

lint: web-check
    bash scripts/tooling/lint.sh

fmt: web-fmt
    bash scripts/tooling/fmt.sh

ci-lint: lint

ci-python: test-python

ci-build:
    bash scripts/tooling/ci_build.sh

ci: ci-lint ci-python test-unit test-integration test-ui test-ui-ipad ci-build
