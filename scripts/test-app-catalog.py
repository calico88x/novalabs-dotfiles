#!/usr/bin/env python3
"""Validate NovaLabs application catalog rendering.

Requirements:
    Python 3.11+
    ChezMoi available on PATH

This test renders configuration without applying it.
No applications are installed and no hosts are modified.
"""

import json
import subprocess
import sys
import tomllib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

MISE_TEMPLATE = "private_dot_config/mise/config.toml.tmpl"
IGNORE_TEMPLATE = ".chezmoiignore.tmpl"

LAZYDOCKER = "aqua:jesseduffield/lazydocker"
BTOP = "aqua:aristocratos/btop"


def render(template, profile, with_docker=False):
    """Render a ChezMoi template using simulated enrollment data."""

    data = json.dumps({
        "profile": profile,
        "withDocker": with_docker,
    })

    result = subprocess.run(
        [
            "chezmoi",
            "--source", str(ROOT),
            "--override-data", data,
            "execute-template",
            "--file", str(ROOT / template),
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        check=True,
    )

    return result.stdout


def require(condition, message):
    """Fail explicitly, even when Python optimization is enabled."""

    if not condition:
        raise AssertionError(message)


def expected_apps(catalog, host, profile, with_docker):
    """Resolve expected application state from the catalog."""

    tools = {}

    if host["kernel"] != "linux" or host["mutation"] != "managed":
        return tools

    enrollment = {"withDocker": with_docker}

    for name, app in catalog.items():

        if profile in app.get("exclude_profiles", []):
            continue

        profiles = app["profiles"]

        enabled = (
            "all-linux" in profiles
            or profile in profiles
        )

        optional_flag = app.get("optional_profiles", {}).get(profile)

        if optional_flag:
            require(
                optional_flag in enrollment,
                f"{name}: unknown enrollment flag {optional_flag}",
            )

            enabled = enabled or enrollment[optional_flag]

        if not enabled:
            continue

        backend = app["backend"]

        require(
            backend not in tools,
            f"Duplicate Mise identifier: {backend}",
        )

        if "options" in app:
            tools[backend] = {
                **app["options"],
                "version": app["version"],
            }
        else:
            tools[backend] = app["version"]

    return tools


def test_profile(catalog, hosts, profile, with_docker=False):
    """Validate one simulated host enrollment."""

    label = profile

    if profile == "ubuntulab":
        label += f" (withDocker={str(with_docker).lower()})"

    rendered = render(MISE_TEMPLATE, profile, with_docker)
    parsed = tomllib.loads(rendered)

    actual = parsed["tools"]

    expected = expected_apps(
        catalog,
        hosts[profile],
        profile,
        with_docker,
    )

    require(
        actual == expected,
        f"{label}: rendered applications differ from catalog",
    )

    # Repeated rendering must be deterministic.
    require(
        rendered == render(MISE_TEMPLATE, profile, with_docker),
        f"{label}: non-deterministic Mise rendering",
    )

    # Existing GPU-enabled btop on ZGX must remain external.
    if profile == "zgx":
        require(BTOP not in actual, "ZGX btop ownership violation")

    # OPNsense must never receive Mise-managed applications.
    if profile == "opnsense":
        require(not actual, "OPNsense must remain unmanaged")

    # Verify LazyDocker configuration and installation agree.
    ignored = render(IGNORE_TEMPLATE, profile, with_docker)

    ignore_paths = {
        line.strip()
        for line in ignored.splitlines()
        if line.strip() and not line.startswith("#")
    }

    expected_ignored = LAZYDOCKER not in actual

    for path in (
        ".config/lazydocker/",
        ".config/lazydocker/**",
    ):
        require(
            (path in ignore_paths) == expected_ignored,
            f"{label}: LazyDocker configuration policy mismatch",
        )

    print(f"PASS  {label:<32} {len(actual):>2} applications")


def main():
    """Validate every declared host profile."""

    with (ROOT / ".chezmoidata/apps.toml").open("rb") as file:
        catalog = tomllib.load(file)["apps"]

    with (ROOT / ".chezmoidata/hosts.toml").open("rb") as file:
        hosts = tomllib.load(file)["hosts"]

    require(bool(catalog), "Application catalog is empty")

    # Validate globally unique Mise identifiers.
    backends = [app["backend"] for app in catalog.values()]

    require(
        len(backends) == len(set(backends)),
        "Duplicate Mise identifiers in application catalog",
    )

    print("NovaLabs application catalog validation")
    print("=" * 60)

    count = 0

    for profile in hosts:
        test_profile(catalog, hosts, profile)
        count += 1

        if profile == "ubuntulab":
            test_profile(catalog, hosts, profile, with_docker=True)
            count += 1

    print("=" * 60)
    print(f"PASS: {count} profile scenarios validated")

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except subprocess.CalledProcessError as error:
        print(f"FAIL: ChezMoi execution failed\n{error.stderr}", file=sys.stderr)
        sys.exit(1)
    except Exception as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
