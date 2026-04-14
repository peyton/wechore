from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
import json
from pathlib import Path
import re
import shlex
import subprocess
from typing import Mapping


REPO_ROOT = Path(__file__).resolve().parents[2]
SEMVER_TAG_PATTERN = re.compile(r"^v(?P<version>\d+\.\d+\.\d+)$")
MARKETING_VERSION_PATTERN = re.compile(r"^\d+\.\d+\.\d+$")
BUILD_NUMBER_PATTERN = re.compile(r"^[1-9]\d{0,17}$")


class VersionResolutionError(ValueError):
    """Raised when a git tag does not match the expected release format."""


@dataclass(frozen=True)
class ResolvedVersions:
    marketing_version: str
    build_number: str


def parse_release_tag(tag: str) -> str:
    match = SEMVER_TAG_PATTERN.fullmatch(tag)
    if match is None:
        raise VersionResolutionError(
            f"Release tag must match vX.Y.Z; received {tag!r}."
        )
    return match.group("version")


def validate_marketing_version(version: str) -> str:
    if MARKETING_VERSION_PATTERN.fullmatch(version) is None:
        raise VersionResolutionError(
            f"Marketing version must match X.Y.Z; received {version!r}."
        )
    return version


def validate_build_number(build_number: str) -> str:
    if BUILD_NUMBER_PATTERN.fullmatch(build_number) is None:
        raise VersionResolutionError(
            "Build number must be a positive integer string with at most 18 digits; "
            f"received {build_number!r}."
        )
    return build_number


def github_release_tag(environment: Mapping[str, str]) -> str | None:
    direct_tag = environment.get("WECHORE_RELEASE_TAG")
    if direct_tag:
        return direct_tag

    if environment.get("GITHUB_REF_TYPE") == "tag" and environment.get(
        "GITHUB_REF_NAME"
    ):
        return environment["GITHUB_REF_NAME"]

    github_ref = environment.get("GITHUB_REF", "")
    prefix = "refs/tags/"
    if github_ref.startswith(prefix):
        return github_ref[len(prefix) :]
    return None


def latest_reachable_release_tag(repo_root: Path = REPO_ROOT) -> str | None:
    try:
        result = subprocess.run(
            [
                "git",
                "describe",
                "--tags",
                "--abbrev=0",
                "--match",
                "v[0-9]*.[0-9]*.[0-9]*",
            ],
            cwd=repo_root,
            check=True,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError, subprocess.CalledProcessError:
        return None
    return result.stdout.strip() or None


def resolve_marketing_version(
    environment: Mapping[str, str], repo_root: Path = REPO_ROOT
) -> str:
    explicit = environment.get("WECHORE_MARKETING_VERSION")
    if explicit:
        return validate_marketing_version(explicit)
    release_tag = github_release_tag(environment)
    if release_tag is not None:
        return parse_release_tag(release_tag)
    latest_tag = latest_reachable_release_tag(repo_root)
    if latest_tag is not None:
        return parse_release_tag(latest_tag)
    return "1.0.0"


def resolve_build_number(
    environment: Mapping[str, str], *, now: datetime | None = None
) -> str:
    explicit = environment.get("WECHORE_BUILD_NUMBER")
    if explicit:
        return validate_build_number(explicit)
    moment = now or datetime.now(UTC)
    if environment.get("GITHUB_RUN_NUMBER"):
        try:
            run_number = int(environment["GITHUB_RUN_NUMBER"])
            attempt = int(environment.get("GITHUB_RUN_ATTEMPT", "1"))
        except ValueError as error:
            raise VersionResolutionError(
                "GITHUB_RUN_NUMBER and GITHUB_RUN_ATTEMPT must be integers."
            ) from error
        if run_number < 1 or attempt < 1:
            raise VersionResolutionError(
                "GITHUB_RUN_NUMBER and GITHUB_RUN_ATTEMPT must be positive integers."
            )
        return validate_build_number(str((run_number * 100) + min(attempt, 99)))
    return validate_build_number(f"{moment:%y%m%d%H%M}")


def resolve_versions(
    environment: Mapping[str, str],
    repo_root: Path = REPO_ROOT,
    *,
    now: datetime | None = None,
) -> ResolvedVersions:
    return ResolvedVersions(
        marketing_version=resolve_marketing_version(environment, repo_root),
        build_number=resolve_build_number(environment, now=now),
    )


def shell_exports(versions: ResolvedVersions) -> str:
    values = {
        "WECHORE_MARKETING_VERSION": versions.marketing_version,
        "WECHORE_BUILD_NUMBER": versions.build_number,
    }
    return "\n".join(
        f"export {key}={shlex.quote(value)}" for key, value in values.items()
    )


def github_env_exports(versions: ResolvedVersions) -> str:
    values = {
        "WECHORE_MARKETING_VERSION": versions.marketing_version,
        "WECHORE_BUILD_NUMBER": versions.build_number,
    }
    return "\n".join(f"{key}={value}" for key, value in values.items())


def json_exports(versions: ResolvedVersions) -> str:
    return json.dumps(
        {
            "WECHORE_MARKETING_VERSION": versions.marketing_version,
            "WECHORE_BUILD_NUMBER": versions.build_number,
        }
    )


def main() -> int:
    import argparse
    import os

    parser = argparse.ArgumentParser(
        description="Resolve WeChore marketing/build versions."
    )
    parser.add_argument(
        "--format",
        choices=("shell", "github-env", "json"),
        default="shell",
        help="Output format.",
    )
    args = parser.parse_args()
    try:
        resolved = resolve_versions(os.environ, REPO_ROOT)
    except VersionResolutionError as error:
        print(f"Error: {error}")
        return 2
    if args.format == "shell":
        print(shell_exports(resolved))
    elif args.format == "github-env":
        print(github_env_exports(resolved))
    else:
        print(json_exports(resolved))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
