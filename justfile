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
