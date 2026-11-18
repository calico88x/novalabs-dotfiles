#!/bin/sh
set -eu

MISE_VERSION="2026.8.9"
CHEZMOI_VERSION="2.72.1"

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
mode="preview"
prune=false

usage() {
    printf 'Usage: %s [--apply] [--prune]\n' "$0"
}

die() {
    printf 'novalabs-dotfiles: %s\n' "$*" >&2
    exit 1
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --apply)
            mode="apply"
            ;;
        --prune)
            prune=true
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

Native packages (named Debian-family profiles only; 'any' skips):
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

# Generic Linux hosts retain ownership of their OS packages.
# Named hosts continue using the existing Debian-family baseline.
case "$profile" in
    any)
        printf '==> Skipping native packages (generic Linux profile)\n'
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
