#!/usr/bin/env python3
"""Synchronize Fastfetch palettes from Starship shade_1."""

import argparse
import json
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

HOSTS = (
    "any",
    "proxmox",
    "docker",
    "pihole",
    "ubuntulab",
    "opnsense",
    "zgx",
    "lovelace",
    "worker1",
)


def sgr(rgb):
    return "38;2;" + ";".join(str(v) for v in rgb)


def blend(rgb, target, fraction):
    return tuple(
        round(v + (target - v) * fraction)
        for v in rgb
    )


def build_palette(hex_color):
    if not re.fullmatch(r"#[0-9a-fA-F]{6}", hex_color):
        raise ValueError(f"Invalid RGB colour: {hex_color}")

    rgb = tuple(
        int(hex_color[i:i + 2], 16)
        for i in (1, 3, 5)
    )

    return {
        "1": sgr(blend(rgb, 0, 0.20)),
        "2": sgr(rgb),
        "3": sgr(blend(rgb, 255, 0.22)),
        "4": sgr(blend(rgb, 255, 0.44)),
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--write",
        action="store_true",
        help="Write generated palettes",
    )
    args = parser.parse_args()

    try:
        import tomllib
    except ImportError as exc:
        raise SystemExit("Python 3.11+ is required") from exc

    changes = []

    for host in HOSTS:
        starship_path = (
            ROOT / ".chezmoitemplates/starship"
            / f"{host}.toml"
        )
        fastfetch_path = (
            ROOT / ".chezmoitemplates/fastfetch"
            / f"{host}.jsonc"
        )

        starship = tomllib.loads(
            starship_path.read_text(encoding="utf-8")
        )
        palette_name = starship["palette"]
        base = starship["palettes"][palette_name]["shade_1"]
        if host == "any":
            # Use exact Dracula colours from the Starship palette.
            shades = starship["palettes"][palette_name]
            palette = {
                str(slot): sgr(tuple(
                    int(shades[f"shade_{slot}"][i:i + 2], 16)
                    for i in (1, 3, 5)
                ))
                for slot in range(1, 5)
            }
        else:
            palette = build_palette(base)

        current = fastfetch_path.read_text(encoding="utf-8")
        config = json.loads(current)

        if set(config["logo"]["color"]) != set(palette):
            raise ValueError(
                f"Unexpected logo colour slots: {host}"
            )

        if set(config["display"]["color"]) != {
            "keys", "title", "separator"
        }:
            raise ValueError(
                f"Unexpected display colour slots: {host}"
            )

        config["logo"]["color"].update(palette)
        config["display"]["color"].update({
            "keys": palette["4"],
            "title": palette["4"],
            "separator": palette["2"],
        })

        desired = json.dumps(
            config,
            ensure_ascii=False,
            indent=4,
        ) + "\n"

        if desired != current:
            changes.append((fastfetch_path, desired))

        print(
            f"{host:12} "
            f"base={base:9} "
            f"changed={desired != current}"
        )

    if args.write:
        for path, content in changes:
            temp = path.with_name(path.name + ".novalabs-tmp")
            if temp.exists():
                raise FileExistsError(temp)

            with temp.open(
                "w", encoding="utf-8", newline="\n"
            ) as file:
                file.write(content)

            os.replace(temp, path)

        print(f"Updated {len(changes)} templates.")
    else:
        print(f"Preview: {len(changes)} templates would change.")


if __name__ == "__main__":
    main()
