#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from typing import Any


def run_json(*args: str) -> dict[str, Any]:
    result = subprocess.run(
        ["xcrun", "simctl", *args, "--json"],
        check=True,
        text=True,
        capture_output=True,
    )
    return json.loads(result.stdout)


def parse_version(version: str) -> tuple[int, ...]:
    return tuple(int(part) for part in version.split("."))


def preferred_sdk_runtime_version(platform: str) -> str | None:
    sdk_names = {
        "iOS": "iphonesimulator",
        "tvOS": "appletvsimulator",
        "watchOS": "watchsimulator",
        "visionOS": "xrsimulator",
    }
    sdk_name = sdk_names.get(platform)
    if sdk_name is None:
        return None
    try:
        result = subprocess.run(
            ["xcrun", "--sdk", sdk_name, "--show-sdk-version"],
            check=True,
            text=True,
            capture_output=True,
        )
    except subprocess.CalledProcessError:
        return None
    return result.stdout.strip() or None


def latest_runtime(
    runtimes: list[dict[str, Any]],
    *,
    platform: str,
    device_type_name: str,
) -> dict[str, Any]:
    candidates = [
        runtime
        for runtime in runtimes
        if runtime.get("isAvailable")
        and runtime.get("platform") == platform
        and any(
            device_type.get("name") == device_type_name
            for device_type in runtime.get("supportedDeviceTypes", [])
        )
    ]
    if not candidates:
        raise RuntimeError(
            f"No available {platform} runtime supports {device_type_name!r}."
        )

    preferred_version = preferred_sdk_runtime_version(platform)
    if preferred_version is not None:
        preferred_matches = [
            runtime
            for runtime in candidates
            if str(runtime.get("version")) == preferred_version
        ]
        if preferred_matches:
            return max(
                preferred_matches,
                key=lambda runtime: parse_version(str(runtime["version"])),
            )
    return max(candidates, key=lambda runtime: parse_version(str(runtime["version"])))


def find_device_type_identifier(
    device_types: list[dict[str, Any]],
    *,
    device_type_name: str,
) -> str:
    for device_type in device_types:
        if device_type.get("name") == device_type_name:
            return str(device_type["identifier"])
    raise RuntimeError(
        f"Unable to find simulator device type named {device_type_name!r}."
    )


def find_existing_device(
    devices: dict[str, list[dict[str, Any]]],
    *,
    runtime_identifier: str,
    simulator_name: str,
    device_type_identifier: str,
) -> str | None:
    for device in devices.get(runtime_identifier, []):
        if (
            device.get("isAvailable")
            and device.get("name") == simulator_name
            and device.get("deviceTypeIdentifier") == device_type_identifier
        ):
            return str(device["udid"])
    return None


def create_device(
    *,
    simulator_name: str,
    device_type_identifier: str,
    runtime_identifier: str,
) -> str:
    result = subprocess.run(
        [
            "xcrun",
            "simctl",
            "create",
            simulator_name,
            device_type_identifier,
            runtime_identifier,
        ],
        check=True,
        text=True,
        capture_output=True,
    )
    return result.stdout.strip()


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Resolve or create a dedicated simulator device."
    )
    parser.add_argument("--name", required=True, help="Simulator name.")
    parser.add_argument(
        "--device-type-name",
        default="iPhone 17 Pro",
        help="Human-readable simulator device type name.",
    )
    parser.add_argument("--platform", default="iOS", help="Simulator platform.")
    args = parser.parse_args()

    try:
        runtimes_json = run_json("list", "runtimes", "available")
        devices_json = run_json("list", "devices", "available")
        device_types_json = run_json("list", "devicetypes")

        runtime = latest_runtime(
            list(runtimes_json["runtimes"]),
            platform=args.platform,
            device_type_name=args.device_type_name,
        )
        device_type_identifier = find_device_type_identifier(
            list(device_types_json["devicetypes"]),
            device_type_name=args.device_type_name,
        )
        runtime_identifier = str(runtime["identifier"])
        existing_udid = find_existing_device(
            dict(devices_json["devices"]),
            runtime_identifier=runtime_identifier,
            simulator_name=args.name,
            device_type_identifier=device_type_identifier,
        )
        udid = existing_udid or create_device(
            simulator_name=args.name,
            device_type_identifier=device_type_identifier,
            runtime_identifier=runtime_identifier,
        )
    except (RuntimeError, KeyError, subprocess.CalledProcessError) as exc:
        print(str(exc), file=sys.stderr)
        return 1

    print(udid)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
