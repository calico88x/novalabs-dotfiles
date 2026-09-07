#!/bin/sh
set -eu

config="${XDG_CONFIG_HOME:-${HOME}/.config}/btop/btop.conf"

# Modern NovaLabs hosts already use a regular writable file.
if [ ! -L "${config}" ]; then
  exit 0
fi

target="$(readlink -f "${config}" 2>/dev/null || true)"

if [ -z "${target}" ] || [ ! -f "${target}" ]; then
  printf 'novalabs-dotfiles: refusing to replace broken btop config symlink: %s\n' \
    "${config}" >&2
  exit 1
fi

tempfile="$(mktemp)"
trap 'rm -f "${tempfile}"' EXIT HUP INT TERM

cat "${target}" > "${tempfile}"

rm -- "${config}"
cat "${tempfile}" > "${config}"

printf 'NovaLabs btop migration: converted %s to a writable regular file\n' \
  "${config}"
