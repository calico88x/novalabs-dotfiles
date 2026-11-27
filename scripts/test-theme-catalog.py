#!/usr/bin/env python3
"""Validate NovaLabs infrastructure TUI theme rendering.

Requirements:
    Python 3.11+
    PyYAML
    ChezMoi available on PATH

This test renders configuration without applying it.
No applications are installed and no hosts are modified.
"""

import json
import re
import subprocess
import sys
import tomllib
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[1]

IGNORE_TEMPLATE = ".chezmoiignore.tmpl"
MISE_TEMPLATE = "private_dot_config/mise/config.toml.tmpl"

TUI_KIT_TEMPLATE = (
    "private_dot_config/novalab/themes/tui-kit.toml.tmpl"
)
K9S_TEMPLATE = (
    "private_dot_config/k9s/skins/novalab.yaml.tmpl"
)
LAZYJOURNAL_TEMPLATE = (
    "private_dot_config/lazyjournal/create_config.yml.tmpl"
)
NETDOC_TEMPLATE = (
    "private_dot_config/netdoc/create_theme.tmpl"
)

TUI_KIT_APPS = (
    "tui-cert",
    "tui-disk",
    "tui-systemd",
    "tui-traffic",
    "tui-cron",
    "tui-ssh",
)

K9S_PROFILES = frozenset({"any", "lovelace", "worker1"})

LAZYJOURNAL_ACCENTS = {
    "any": "magenta",
    "proxmox": "yellow",
    "docker": "cyan",
    "pihole": "red",
    "ubuntulab": "yellow",
    "lovelace": "magenta",
    "worker1": "yellow",
    "zgx": "green",
}

ANSI_COLORS = frozenset({
    "default", "black", "white", "red", "green",
    "yellow", "blue", "magenta", "cyan",
})

NETDOC_THEMES = frozenset({
    "terminal", "harbor", "ember", "contrast", "monochrome",
})

HEX_COLOR = re.compile(r"#[0-9a-fA-F]{6}")


def require(condition, message):
    """Fail explicitly, even with Python optimization enabled."""

    if not condition:
        raise AssertionError(message)


def load_toml(path):
    """Load a repository TOML document."""

    with (ROOT / path).open("rb") as file:
        return tomllib.load(file)


def render(template, profile, with_docker=False):
    """Render a template using simulated enrollment data."""

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


def render_checked(template, profile, with_docker):
    """Validate deterministic output and file formatting."""

    output = render(template, profile, with_docker)
    label = f"{profile}: {template}"

    require(
        output == render(template, profile, with_docker),
        f"{label}: non-deterministic rendering",
    )

    require(
        output.endswith("\n"),
        f"{label}: missing trailing newline",
    )

    require(
        all(line == line.rstrip() for line in output.splitlines()),
        f"{label}: trailing whitespace",
    )

    return output


def check_colors(palette, keys, label):
    """Validate required RGB properties."""

    for key in keys:
        value = palette.get(key)

        require(
            isinstance(value, str)
            and HEX_COLOR.fullmatch(value) is not None,
            f"{label}: invalid or missing color {key}",
        )


def test_catalog(theme, hosts):
    """Validate centralized theme data."""

    check_colors(
        theme["shared"],
        (
            "text_light", "text_dark", "success",
            "error", "warning", "root",
        ),
        "Shared palette",
    )

    check_colors(
        theme["tui"],
        (
            "surface", "surface_dark", "selection",
            "muted", "cyan", "orange",
        ),
        "TUI palette",
    )

    require(
        set(theme["hosts"]) == set(hosts),
        "Host and theme catalogs contain different profiles",
    )

    for profile, palette in theme["hosts"].items():
        check_colors(
            palette,
            ("shade_1", "shade_2", "shade_3", "shade_4"),
            profile,
        )

        managed_linux = (
            hosts[profile]["kernel"] == "linux"
            and hosts[profile]["mutation"] == "managed"
        )

        if managed_linux:
            accent = palette.get("lazyjournal_accent")

            require(
                accent in ANSI_COLORS,
                f"{profile}: unsupported LazyJournal accent",
            )

            require(
                accent == LAZYJOURNAL_ACCENTS.get(profile),
                f"{profile}: unexpected LazyJournal accent",
            )

    preference = theme["preferences"]["network_doctor"]

    require(
        preference in NETDOC_THEMES,
        "Unsupported Network Doctor theme",
    )

    require(
        preference == "contrast",
        "Network Doctor must default to contrast",
    )

    print("PASS  Centralized theme catalog")


def test_tui_kit(theme, profile, with_docker):
    """Validate the shared tui-kit RGB palette."""

    actual = tomllib.loads(
        render_checked(TUI_KIT_TEMPLATE, profile, with_docker)
    )

    host = theme["hosts"][profile]
    shared = theme["shared"]
    tui = theme["tui"]

    expected = {
        "mode": "dark",
        "background": shared["text_dark"],
        "foreground": shared["text_light"],
        "bright_foreground": shared["text_light"],
        "lighter_background": tui["surface"],
        "dark_background": tui["surface_dark"],
        "selection": tui["selection"],
        "muted": tui["muted"],
        "accent": host["shade_4"],
        "blue": host["shade_3"],
        "magenta": host["shade_4"],
        "red": shared["error"],
        "green": shared["success"],
        "yellow": shared["warning"],
        "cyan": tui["cyan"],
        "orange": tui["orange"],
    }

    require(
        actual == expected,
        f"{profile}: tui-kit palette mismatch",
    )


def test_k9s(theme, profile, with_docker):
    """Validate native K9s skin structure and key colors."""

    actual = yaml.safe_load(
        render_checked(K9S_TEMPLATE, profile, with_docker)
    )

    skin = actual["k9s"]
    host = theme["hosts"][profile]
    shared = theme["shared"]

    require(
        {"body", "prompt", "info", "dialog", "frame", "views"}
        <= set(skin),
        f"{profile}: incomplete K9s skin structure",
    )

    expected = {
        "fgColor": shared["text_light"],
        "bgColor": shared["text_dark"],
        "logoColor": host["shade_4"],
    }

    for key, value in expected.items():
        require(
            skin["body"].get(key) == value,
            f"{profile}: K9s body color mismatch: {key}",
        )

    require(
        skin["frame"]["status"]["errorColor"] == shared["error"],
        f"{profile}: K9s error color mismatch",
    )

    require(
        skin["frame"]["status"]["addColor"] == shared["success"],
        f"{profile}: K9s success color mismatch",
    )
    # Protect application-specific contrast refinements.
    accent = host["shade_4"]
    foreground = shared["text_light"]
    muted = theme["tui"]["muted"]

    color_roles = (
        ("dialog.labelFgColor",
         skin["dialog"]["labelFgColor"], accent),

        ("frame.border.fgColor",
         skin["frame"]["border"]["fgColor"], muted),

        ("frame.border.focusColor",
         skin["frame"]["border"]["focusColor"], accent),

        ("frame.title.counterColor",
         skin["frame"]["title"]["counterColor"], foreground),

        ("frame.title.filterColor",
         skin["frame"]["title"]["filterColor"], foreground),

        ("views.table.header.fgColor",
         skin["views"]["table"]["header"]["fgColor"], accent),

        ("views.yaml.colonColor",
         skin["views"]["yaml"]["colonColor"], muted),

        ("views.table.cursorFgColor",
         skin["views"]["table"]["cursorFgColor"],
         shared["text_dark"]),

        ("views.table.cursorBgColor",
         skin["views"]["table"]["cursorBgColor"], accent),

        ("frame.status.newColor",
         skin["frame"]["status"]["newColor"], accent),

        ("frame.status.pendingColor",
         skin["frame"]["status"]["pendingColor"],
         shared["warning"]),
    )

    for role, actual_color, expected_color in color_roles:
        require(
            actual_color == expected_color,
            f"{profile}: K9s color role mismatch: {role}",
        )

def test_lazyjournal(theme, profile, with_docker):
    """Validate the minimal create-only LazyJournal configuration."""

    actual = yaml.safe_load(
        render_checked(
            LAZYJOURNAL_TEMPLATE, profile, with_docker
        )
    )

    accent = theme["hosts"][profile]["lazyjournal_accent"]

    expected = {
        "interface": {
            "foregroundColor": "default",
            "backgroundColor": "default",
            "selectedForegroundColor": "black",
            "selectedBackgroundColor": accent,
            "frameColor": "default",
            "titleColor": "default",
            "selectedFrameColor": accent,
            "selectedTitleColor": accent,
            "errorColor": "red",
        },
    }

    require(
        actual == expected,
        f"{profile}: LazyJournal configuration mismatch",
    )


def test_netdoc(theme, profile, with_docker):
    """Validate the single-line native theme preference."""

    actual = render_checked(
        NETDOC_TEMPLATE, profile, with_docker
    )

    expected = theme["preferences"]["network_doctor"]

    require(
        actual == expected + "\n",
        f"{profile}: invalid Network Doctor preference",
    )


def test_profile(theme, apps, hosts, profile, with_docker=False):
    """Validate configuration eligibility and theme rendering."""

    label = profile

    if profile == "ubuntulab":
        label += f" (withDocker={str(with_docker).lower()})"

    managed_linux = (
        hosts[profile]["kernel"] == "linux"
        and hosts[profile]["mutation"] == "managed"
    )

    installed = tomllib.loads(
        render(MISE_TEMPLATE, profile, with_docker)
    )["tools"]

    ignored = {
        line.strip()
        for line in render(
            IGNORE_TEMPLATE, profile, with_docker
        ).splitlines()
        if line.strip() and not line.startswith("#")
    }

    # Independent expected configuration policies.
    expected = {
        ".config/novalab/themes/tui-kit.toml": managed_linux,
        ".config/k9s/skins/novalab.yaml": (
            managed_linux and profile in K9S_PROFILES
        ),
        ".config/lazyjournal/config.yml": managed_linux,
        ".config/netdoc/theme": managed_linux,
    }

    # Cross-check configuration eligibility against rendered
    # application installation state.
    actual = {
        ".config/novalab/themes/tui-kit.toml": any(
            apps[name]["backend"] in installed
            for name in TUI_KIT_APPS
        ),
        ".config/k9s/skins/novalab.yaml": (
            apps["k9s"]["backend"] in installed
        ),
        ".config/lazyjournal/config.yml": (
            apps["lazyjournal"]["backend"] in installed
        ),
        ".config/netdoc/theme": (
            apps["network-doctor"]["backend"] in installed
        ),
    }

    require(
        actual == expected,
        f"{label}: application theme enrollment mismatch",
    )

    for path, enabled in expected.items():
        require(
            (path not in ignored) == enabled,
            f"{label}: configuration eligibility mismatch: {path}",
        )

    count = 0

    if expected[".config/novalab/themes/tui-kit.toml"]:
        test_tui_kit(theme, profile, with_docker)
        count += 1

    if expected[".config/k9s/skins/novalab.yaml"]:
        test_k9s(theme, profile, with_docker)
        count += 1

    if expected[".config/lazyjournal/config.yml"]:
        test_lazyjournal(theme, profile, with_docker)
        count += 1

    if expected[".config/netdoc/theme"]:
        test_netdoc(theme, profile, with_docker)
        count += 1

    print(f"PASS  {label:<32} {count} theme configurations")

    return count


def main():
    """Validate the theme catalog and every enrollment scenario."""

    theme = load_toml(".chezmoidata/theme.toml")["theme"]
    apps = load_toml(".chezmoidata/apps.toml")["apps"]
    hosts = load_toml(".chezmoidata/hosts.toml")["hosts"]

    print("NovaLabs theme catalog validation")
    print("=" * 60)

    test_catalog(theme, hosts)

    scenarios = 0
    configurations = 0

    for profile in hosts:
        configurations += test_profile(
            theme, apps, hosts, profile
        )
        scenarios += 1

        if profile == "ubuntulab":
            configurations += test_profile(
                theme, apps, hosts, profile, with_docker=True
            )
            scenarios += 1

    print("=" * 60)
    print(f"PASS: {scenarios} profile scenarios validated")
    print(f"PASS: {configurations} theme configurations validated")

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except subprocess.CalledProcessError as error:
        print(
            f"FAIL: ChezMoi execution failed\n{error.stderr}",
            file=sys.stderr,
        )
        sys.exit(1)
    except Exception as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
