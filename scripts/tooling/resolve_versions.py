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
        return explicit
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
        return explicit
    moment = now or datetime.now(UTC)
    if github_release_tag(environment) is not None and environment.get(
        "GITHUB_RUN_NUMBER"
    ):
        run_number = environment["GITHUB_RUN_NUMBER"]
        attempt = environment.get("GITHUB_RUN_ATTEMPT", "1")
        return f"{moment:%Y%m%d}.{run_number}.{attempt}"
    return f"{moment:%Y%m%d}.{moment:%H%M%S}.0"


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
    resolved = resolve_versions(os.environ, REPO_ROOT)
    if args.format == "shell":
        print(shell_exports(resolved))
    elif args.format == "github-env":
        print(github_env_exports(resolved))
    else:
        print(json_exports(resolved))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
