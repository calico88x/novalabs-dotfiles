#!/bin/sh
set -eu

MISE_VERSION="2026.8.5"
CHEZMOI_VERSION="2.72.1"

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
mode="preview"

usage() {
    printf 'Usage: %s [--apply]\n' "$0"
}

die() {
    printf 'novalabs-dotfiles: %s\n' "$*" >&2
    exit 1
}

case "${1:-}" in
    "")
        ;;
    --apply)
        mode="apply"
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

case "${ID:-}" in
    debian|ubuntu|raspbian)
        ;;
    *)
        die "unsupported Linux distribution: ${ID:-unknown}"
        ;;
esac

native_packages="
ca-certificates
curl
git
gzip
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

Native packages:
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
trap 'rm -f "$validator"' EXIT HUP INT TERM

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

case "$profile" in
    docker|zgx)
        die "Docker-role bootstrap is not enabled yet; Docker vendor handling must be implemented first"
        ;;
    ubuntulab)
        if [ "$with_docker" = "true" ]; then
            die "UbuntuLab Docker bootstrap is not enabled yet; Docker vendor handling must be implemented first"
        fi
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

printf '==> Applying ChezMoi configuration\n'
chezmoi apply

printf '==> Installing pinned Mise toolchain\n'
"$mise_bin" install

printf '%s\n' "NovaLabs bootstrap completed successfully."
