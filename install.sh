#!/bin/sh
set -eu

MISE_VERSION="2026.8.9"
CHEZMOI_VERSION="2.72.1"

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
mode="preview"
prune=false

# Presentation is optional and must not control bootstrap execution.
NL_UI_PLAIN=false
NL_UI_NO_ANIMATION=false
bootstrap_ui_available=false

usage() {
    cat <<EOF
Usage: $0 [options]

Execution:
  --apply           Execute the bootstrap workflow
  --prune           Prune unused Mise versions (requires --apply)

Presentation:
  --plain           Disable presentation colors and animation
  --no-animation    Disable startup animation
  -h, --help        Display this help

Without --apply, the bootstrap runs in non-mutating preview mode.
EOF
}

die() {
    printf 'novalabs-dotfiles: %s\n' "$*" >&2
    exit 1
}

# Initialize the optional bootstrap presentation library.
#
# Presentation failures must not prevent infrastructure execution.
# The original installer output remains available as a fallback.
bootstrap_ui_init() {
    bootstrap_ui_available=false
    bootstrap_ui_library="$repo_root/scripts/lib/bootstrap-ui.sh"

    # A missing or unreadable library is not a bootstrap failure.
    [ -f "$bootstrap_ui_library" ] &&
        [ -r "$bootstrap_ui_library" ] ||
        return 0

    # Reject syntax errors before sourcing the library.
    if ! sh -n "$bootstrap_ui_library" >/dev/null 2>&1; then
        return 0
    fi

    # Probe the trusted library in a subshell before loading it
    # into the installer. Ordinary loading and initialization
    # failures remain isolated from the execution workflow.
    if ! (
        . "$bootstrap_ui_library" || exit 1

        for bootstrap_ui_function in \
            nl_ui_init \
            nl_ui_reset \
            nl_ui_animate_logo \
            nl_ui_heading \
            nl_ui_status \
            nl_ui_system_identity \
            nl_ui_runtime_identity \
            nl_ui_host_identity \
            nl_ui_catalog_value \
            nl_ui_tracker_init \
            nl_ui_stage_begin \
            nl_ui_stage_pass \
            nl_ui_stage_skip \
            nl_ui_stage_fail \
            nl_ui_summary
        do
            command -v "$bootstrap_ui_function" >/dev/null 2>&1 ||
                exit 1
        done

        nl_ui_init "$repo_root" || exit 1
    ) >/dev/null 2>&1
    then
        return 0
    fi

    # Load the validated, repository-owned presentation library.
    # shellcheck source=scripts/lib/bootstrap-ui.sh
    . "$bootstrap_ui_library" || return 0

    if nl_ui_init "$repo_root"; then
        bootstrap_ui_available=true
    fi

    return 0
}

# Invoke presentation functions without allowing ordinary
# presentation errors to determine the bootstrap exit status.
#
# Only presentation functions may be passed to this adapter.
# Never use it to execute infrastructure commands.
bootstrap_ui_call() {
    [ "$bootstrap_ui_available" = true ] ||
        return 0

    [ "$#" -gt 0 ] ||
        return 0

    case "$1" in
        nl_ui_*)
            ;;
        *)
            return 0
            ;;
    esac

    if ! "$@"; then
        bootstrap_ui_available=false
        nl_ui_reset || true
    fi

    return 0
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --apply)
            mode="apply"
            ;;
        --prune)
            prune=true
            ;;
        --plain)
            NL_UI_PLAIN=true
            NL_UI_NO_ANIMATION=true
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

if [ "$prune" = true ] && [ "$mode" != "apply" ]; then
    die "--prune requires --apply"
fi

if [ "$(id -u)" -eq 0 ]; then
    die "bootstrap must run as a normal user, not root"
fi

kernel=$(uname -s 2>/dev/null || true)

case "$kernel" in
    Linux)
        ;;
    FreeBSD)
        cat <<EOF
NovaLabs bootstrap preview

Platform:          FreeBSD
Repository:        $repo_root
Mutation policy:   stage-only

OPNsense is not modified by the generic bootstrap.
EOF
        exit 0
        ;;
    *)
        die "unsupported kernel: $kernel"
        ;;
esac

[ -r /etc/os-release ] ||
    die "/etc/os-release is unavailable"

# shellcheck disable=SC1091
. /etc/os-release

# Initialize optional presentation only after argument, privilege
# and platform validation have completed.
bootstrap_ui_init

native_packages="
build-essential
ca-certificates
curl
git
gzip
libatomic1
htop
openssh-server
procps
sudo
tar
tmux
vim
"

if [ "$mode" = "preview" ]; then
    cat <<EOF
NovaLabs bootstrap preview

Platform:          $kernel
Distribution:      ${ID:-unknown}
Repository:        $repo_root

Bootstrap:
  Mise              $MISE_VERSION
  ChezMoi           $CHEZMOI_VERSION

Native package policies:
  Named Debian-family profiles: full package baseline below
  any on Debian-family Linux:   build-essential, libatomic1
  any on other Linux:           externally managed

Named-profile package baseline:
$(printf '%s\n' "$native_packages" | sed '/^[[:space:]]*$/d;s/^/  - /')

Portable tools:
  Managed by the pinned Mise configuration after ChezMoi enrollment.

No changes were made.

Apply with:
  ./install.sh --apply
EOF
    exit 0
fi

# A fetcher is required before system packages can be converged.
if command -v curl >/dev/null 2>&1; then
    fetch_installer() {
        curl -fsSL https://mise.run
    }
elif command -v wget >/dev/null 2>&1; then
    fetch_installer() {
        wget -qO- https://mise.run
    }
else
    die "curl or wget is required for the initial Mise bootstrap"
fi

mise_bin="${HOME}/.local/bin/mise"

if [ -x "$mise_bin" ] &&
   "$mise_bin" --version 2>/dev/null | grep -F "$MISE_VERSION" >/dev/null
then
    printf '==> Mise %s already installed\n' "$MISE_VERSION"
else
    printf '==> Installing pinned Mise %s\n' "$MISE_VERSION"

    fetch_installer |
        MISE_VERSION="v${MISE_VERSION}" \
        MISE_INSTALL_PATH="$mise_bin" \
        sh
fi

[ -x "$mise_bin" ] ||
    die "Mise installer did not create $mise_bin"

"$mise_bin" --version | grep -F "$MISE_VERSION" >/dev/null ||
    die "installed Mise version does not match $MISE_VERSION"

chezmoi() {
    "$mise_bin" x "aqua:twpayne/chezmoi@${CHEZMOI_VERSION}" -- chezmoi "$@"
}

printf '==> Enrolling ChezMoi from %s\n' "$repo_root"
chezmoi -S "$repo_root" init

# Render and execute the validator before any sudo/system mutation.
validator=$(mktemp)
trap 'rm -f "$validator" "${chronytop_tmp:-}"' EXIT HUP INT TERM

chezmoi -S "$repo_root" execute-template \
    < "$repo_root/.chezmoiscripts/run_before_10-validate-host.sh.tmpl" \
    > "$validator"

sh "$validator"

profile="$(
    printf '{{ .profile }}' |
        chezmoi -S "$repo_root" execute-template
)"

with_docker="$(
    printf '{{ .withDocker }}' |
        chezmoi -S "$repo_root" execute-template
)"

chronytop_policy="$(
    printf '{{ with (index (index .hosts .profile) "chronytop") }}{{ . }}{{ else }}skip{{ end }}' |
        chezmoi -S "$repo_root" execute-template
)"

case "$profile" in
    docker)
        command -v docker >/dev/null 2>&1 ||
            die "Docker profile requires an existing Docker installation"

        docker info >/dev/null 2>&1 ||
            die "Docker profile requires Docker to be usable by the current user"
        ;;
    zgx)
        command -v docker >/dev/null 2>&1 ||
            die "ZGX profile requires the existing NVIDIA-managed Docker installation"

        docker info >/dev/null 2>&1 ||
            die "ZGX profile requires Docker to be usable by the current user"
        ;;
    ubuntulab)
        if [ "$with_docker" = "true" ]; then
            command -v docker >/dev/null 2>&1 ||
                die "UbuntuLab Docker mode requires an existing Docker installation"

            docker info >/dev/null 2>&1 ||
                die "UbuntuLab Docker mode requires Docker to be usable by the current user"
        fi
        ;;
esac

# Generic Linux hosts install only required toolchain prerequisites.
# Named hosts continue using the existing Debian-family baseline.
case "$profile" in
any)
    # Manage only prerequisites required by the shared Mise toolchain.
    # Do not install the full infrastructure package baseline.
    case "${ID:-}" in
        debian|ubuntu|raspbian)
            command -v sudo >/dev/null 2>&1 ||
                die "sudo is required to install toolchain prerequisites"

            command -v apt-get >/dev/null 2>&1 ||
                die "apt-get is unavailable on this Debian-family host"

            printf '==> Installing generic Linux toolchain prerequisites\n'
            sudo apt-get update
            sudo apt-get install -y --no-install-recommends \
                build-essential \
                libatomic1
            ;;
        *)
            command -v cc >/dev/null 2>&1 ||
                die "C compiler missing; install your distribution's build toolchain"

            printf '==> Generic Linux: native prerequisites externally managed\n'
            printf '    Ensure libatomic.so.1 is available before installing Node.js.\n'
            ;;
    esac
    ;;

    *)
        case "${ID:-}" in
            debian|ubuntu|raspbian)
                ;;
            *)
                die "unsupported Linux distribution for profile '$profile': ${ID:-unknown}"
                ;;
        esac

        command -v sudo >/dev/null 2>&1 ||
            die "sudo is required for native package convergence"

        command -v apt-get >/dev/null 2>&1 ||
            die "apt-get is required for Debian-family native package convergence"

        printf '==> Installing native packages\n'
        sudo apt-get update
        # shellcheck disable=SC2086
        sudo apt-get install -y $native_packages
        ;;
esac

printf '==> Applying ChezMoi configuration\n'
chezmoi apply

printf '==> Installing pinned Mise toolchain\n'
"$mise_bin" install

# Chronytop is managed only on the Proxmox time server.
case "$chronytop_policy" in
    managed)
        [ "$profile" = "proxmox" ] ||
            die "chronytop is only supported on Proxmox"

        [ -x /usr/bin/chronyc ] ||
            die "chronytop requires the existing Chrony installation"

        chronytop_bin="/usr/local/bin/chronytop"
        chronytop_url="https://github.com/geerlingguy/chronytop/releases/latest/download"

        printf '==> Checking latest Chronytop release\n'

        checksums="$(curl -fsSL "$chronytop_url/SHA256SUMS")" ||
            die "failed to retrieve Chronytop checksums"

        expected_sha="$(
            printf '%s\n' "$checksums" |
                awk '$2 == "chronytop-linux-amd64" {print $1}'
        )"

        printf '%s\n' "$expected_sha" |
            grep -Eq '^[0-9a-fA-F]{64}$' ||
            die "invalid Chronytop release checksum"

        if [ -f "$chronytop_bin" ] &&
           [ ! -L "$chronytop_bin" ] &&
           printf '%s  %s\n' "$expected_sha" "$chronytop_bin" |
               sha256sum --check --status &&
           [ "$(stat -c '%U:%G %a' "$chronytop_bin")" = "root:root 755" ]
        then
            printf '==> Chronytop already current\n'
        else
            printf '==> Installing latest Chronytop release\n'

            chronytop_tmp="$(mktemp)"

            curl -fsSL \
                -o "$chronytop_tmp" \
                "$chronytop_url/chronytop-linux-amd64" ||
                die "Chronytop download failed"

            printf '%s  %s\n' "$expected_sha" "$chronytop_tmp" |
                sha256sum --check --status ||
                die "Chronytop checksum verification failed"

            chronytop_stage="/usr/local/bin/.chronytop.$$"

            if ! sudo install -o root -g root -m 0755 \
                "$chronytop_tmp" "$chronytop_stage"
            then
                sudo rm -f -- "$chronytop_stage"
                die "Chronytop staging failed"
            fi

            if ! sudo mv -f -- "$chronytop_stage" "$chronytop_bin"
            then
                sudo rm -f -- "$chronytop_stage"
                die "Chronytop installation failed"
            fi
        fi

        "$chronytop_bin" -version
        ;;
    skip)
        ;;
    *)
        die "unsupported chronytop policy: $chronytop_policy"
        ;;
esac

printf '==> Auditing unused Mise tool versions\n'
"$mise_bin" ls --prunable

if [ "$prune" = true ]; then
    printf '==> Pruning unused Mise installations\n'
    "$mise_bin" prune
fi

printf '%s\n' "NovaLabs bootstrap completed successfully."
