# shellcheck shell=bash

# Compatibility aliases for distributions that rename executables.
if command -v batcat >/dev/null 2>&1 &&
  ! command -v bat >/dev/null 2>&1
then
  alias bat='batcat'
fi

if command -v fdfind >/dev/null 2>&1 &&
  ! command -v fd >/dev/null 2>&1
then
  alias fd='fdfind'
fi

# Short names for the shared terminal interfaces.
if command -v lazygit >/dev/null 2>&1; then
  alias lzg='lazygit'
fi

if command -v lazydocker >/dev/null 2>&1; then
  alias lzd='lazydocker'
fi

# LSD for LS
if command -v lsd >/dev/null 2>&1; then
  alias ls='lsd -lah --group-dirs=first'
fi