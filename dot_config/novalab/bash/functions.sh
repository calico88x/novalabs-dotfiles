# shellcheck shell=bash

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

mkcd() {
  if (( $# != 1 )); then
    printf 'Usage: mkcd DIRECTORY\n' >&2
    return 2
  fi

  mkdir -p -- "$1" && cd -- "$1"
}

reload_shell() {
  if [[ -r "${HOME}/.bashrc" ]]; then
    # shellcheck disable=SC1091
    source "${HOME}/.bashrc"
  else
    printf 'No readable Bash configuration found at %s\n' "${HOME}/.bashrc" >&2
    return 1
  fi
}
