
#!/bin/sh
# Preview NovaLabs bootstrap branding without performing installation.

set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

usage() {
    printf 'Usage: %s [--plain] [--no-animation] [--help]\n' "$0"
}

NL_UI_PLAIN=false
NL_UI_NO_ANIMATION=false

while [ "$#" -gt 0 ]; do
    case "$1" in
        --plain)
            NL_UI_PLAIN=true
            ;;
        --no-animation)
            NL_UI_NO_ANIMATION=true
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit 2
            ;;
    esac

    shift
done

# shellcheck source=scripts/lib/bootstrap-ui.sh
. "$repo_root/scripts/lib/bootstrap-ui.sh"

nl_ui_init "$repo_root"

# Reset presentation attributes on exit or interruption.
trap 'nl_ui_reset' 0
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

nl_ui_animate_logo

printf '\n'

nl_ui_text "${NL_UI_HEADER:-}" 35 "PRESENTATION PREVIEW"
printf '\n\n'

printf '  %-18s %s\n' \
    "Color mode" "$NL_UI_COLOR_MODE" \
    "Animation enabled" "$NL_UI_ANIMATE" \
    "Terminal columns" "$NL_UI_COLUMNS" \
    "Palette ready" "$NL_UI_PALETTE_READY"

printf '\n'

nl_ui_text "${NL_UI_SUCCESS:-}" 32 "  ✓ Branding preview complete"
printf '\n'

nl_ui_text "${NL_UI_MUTED:-}" 37 "    No installation operations performed."
printf '\n\n'
