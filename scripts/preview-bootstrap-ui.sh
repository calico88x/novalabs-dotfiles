
#!/bin/sh
# Preview the NovaLabs bootstrap presentation.
# All execution stages are simulated.
# No enrollment, installation or system mutation is performed.

set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

NL_UI_PLAIN=false
NL_UI_NO_ANIMATION=false

preview_profile=any
simulate_failure=false

usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  --profile NAME       Select a simulated host profile
  --simulate-failure   Demonstrate bootstrap failure reporting
  --no-animation       Disable startup animation
  --plain              Disable colors and animation
  -h, --help           Display this help

Profiles:
  any, proxmox, docker, pihole, ubuntulab,
  lovelace, worker1, zgx, opnsense

This utility performs no installation operations.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --profile)
            if [ "$#" -lt 2 ]; then
                usage >&2
                exit 2
            fi

            preview_profile="$2"
            shift
            ;;
        --simulate-failure)
            simulate_failure=true
            ;;
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

case "$preview_profile" in
    any|proxmox|docker|pihole|ubuntulab|lovelace|worker1|zgx|opnsense)
        ;;
    *)
        printf 'Unknown preview profile: %s\n' \
            "$preview_profile" >&2
        exit 2
        ;;
esac

# shellcheck source=scripts/lib/bootstrap-ui.sh
. "$repo_root/scripts/lib/bootstrap-ui.sh"

nl_ui_init "$repo_root"

trap 'nl_ui_reset' 0
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

# Load local platform information for display only.
if [ -r /etc/os-release ]; then
    . /etc/os-release
fi

nl_ui_animate_logo

nl_ui_heading "PRESENTATION PREVIEW"

nl_ui_status info "All execution stages are simulated."
nl_ui_status info "No installation operations performed."

nl_ui_system_identity \
    "$repo_root" \
    "${PRETTY_NAME:-unknown}" \
    preview

nl_ui_runtime_identity 2026.8.9 2.72.1

# Resolve the selected demonstration profile from the theme catalog.
# This does not change or initialize the actual enrolled profile.
section="theme.hosts.$preview_profile"

if [ "$NL_UI_PALETTE_READY" = true ]; then
    nl_ui_host_identity \
        "$preview_profile" \
        "$(nl_ui_catalog_value "$NL_UI_CATALOG" "$section" display_name)" \
        "$(nl_ui_catalog_value "$NL_UI_CATALOG" "$section" family)" \
        "$(nl_ui_catalog_value "$NL_UI_CATALOG" "$section" shade_1)" \
        "$(nl_ui_catalog_value "$NL_UI_CATALOG" "$section" shade_2)" \
        "$(nl_ui_catalog_value "$NL_UI_CATALOG" "$section" shade_3)" \
        "$(nl_ui_catalog_value "$NL_UI_CATALOG" "$section" shade_4)"
else
    nl_ui_heading "HOST PROFILE"
    nl_ui_field "Profile" "$preview_profile" highlight
    nl_ui_status warning "Host palette unavailable"
fi

nl_ui_separator
nl_ui_heading "TERMINAL CAPABILITIES"

nl_ui_field "Color mode" "$NL_UI_COLOR_MODE" highlight
nl_ui_field "Animation" "$NL_UI_ANIMATE"
nl_ui_field "Columns" "$NL_UI_COLUMNS"
nl_ui_field "Palette ready" "$NL_UI_PALETTE_READY"

# OPNsense remains stage-only.
if [ "$preview_profile" = opnsense ]; then
    nl_ui_separator
    nl_ui_heading "PLATFORM POLICY"

    nl_ui_status skipped \
        "OPNsense is excluded from generic bootstrap mutation."

    nl_ui_status success "Branding preview complete"
    exit 0
fi

# Optional presentation delay.
# Non-interactive previews should complete without artificial delays.
preview_pause() {
    if [ "$NL_UI_ANIMATE" = true ]; then
        sleep 0.25 2>/dev/null || true
    fi

    return 0
}

nl_ui_tracker_init 8

nl_ui_stage_begin "BOOTSTRAP RUNTIME"
nl_ui_status running "Checking pinned Mise runtime..."
preview_pause
nl_ui_stage_pass "Simulated runtime verification"

nl_ui_stage_begin "CONFIGURATION ENROLLMENT"
nl_ui_status running "Resolving ChezMoi enrollment..."
preview_pause
nl_ui_stage_pass "Simulated enrollment complete"

nl_ui_stage_begin "HOST VALIDATION"
nl_ui_status running "Checking selected host policy..."
preview_pause
nl_ui_stage_pass "Simulated host policy validation"

nl_ui_stage_begin "NATIVE PREREQUISITES"
nl_ui_status running "Checking native package requirements..."
preview_pause
nl_ui_stage_pass "Simulated native prerequisite verification"

nl_ui_stage_begin "CONFIGURATION"
nl_ui_status running "Reconciling managed configuration..."
preview_pause

if [ "$simulate_failure" = true ]; then
    nl_ui_stage_fail 42 "Simulated configuration failure"
    nl_ui_summary 42

    nl_ui_status info \
        "Simulation complete; no actual installation failed."

    printf '\n'

    # The preview itself completed successfully.
    exit 0
fi

nl_ui_stage_pass "Simulated configuration reconciliation"

nl_ui_stage_begin "APPLICATIONS"
nl_ui_status running "Installing declared application versions..."
preview_pause
nl_ui_stage_pass "Simulated application installation"

nl_ui_stage_begin "CHRONYTOP"

if [ "$preview_profile" = proxmox ]; then
    nl_ui_status running "Checking Chronytop release..."
    preview_pause
    nl_ui_stage_pass "Simulated Chronytop verification"
else
    nl_ui_stage_skip "Not required by selected profile"
fi

nl_ui_stage_begin "APPLICATION AUDIT"
nl_ui_status running "Checking unused application versions..."
preview_pause
nl_ui_stage_pass "Simulated application audit"

nl_ui_summary 0

nl_ui_status success "Branding preview complete"
nl_ui_status info "No installation operations performed."

printf '\n'
